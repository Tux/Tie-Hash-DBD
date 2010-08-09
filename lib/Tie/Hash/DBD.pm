package Tie::Hash::DBD;

our $VERSION = "0.04";

use strict;
use warnings;

use Carp;

use DBI;
use Storable qw( freeze thaw );

my $dbdx = 0;

my %DB = (
    Pg		=> {
	temp	=> "temp",
	t_key	=> "bytea primary key",
	t_val	=> "bytea",
	clear	=> "truncate table",
	autoc	=> 0,
	},
    Unify	=> {	# Doesn't work: needs commit between create and use
	temp	=> "",
	t_key	=> "binary",
	t_val	=> "binary",
	clear	=> "truncate table",
	autoc	=> 0,
	},
    Oracle	=> {
	# Oracle does not allow where clauses on BLOB's nor does it allow
	# BLOB's to be primary keys
	temp	=> "global temporary",	# Only as of Ora-9
	t_key	=> "varchar2 (4000) primary key",
	t_val	=> "blob",
	clear	=> "truncate table",
	autoc	=> 1,
	k_asc	=> 1,		# Does not allow where on BLOB
	},
    mysql	=> {
	temp	=> "temporary",
	t_key	=> "blob",	# Does not allow binary to be primary key
	t_val	=> "blob",
	clear	=> "truncate table",
	autoc	=> 1,
	},
    SQLite	=> {
	temp	=> "temporary",
	t_key	=> "text primary key",
	t_val	=> "text",
	clear	=> "delete from",
	pbind	=> 0, # TYPEs in SQLite are text, bind_param () needs int
	autoc	=> 0,
	},
    CSV		=> {
	temp	=> "temporary",
	t_key	=> "text primary key",
	t_val	=> "text",
	clear	=> "delete from",
	},
    );

sub _create_table
{
    my ($cnf, $tmp) = shift;
    $cnf->{tmp} = $tmp;
    local $cnf->{dbh}->{PrintWarn} = 0;
    my ($temp, $t_key, $t_val) = @{$DB{$cnf->{dbt}}}{qw( temp t_key t_val )};
    $tmp or $temp = "";
    $cnf->{dbh}->do (
	"create $temp table $cnf->{tbl} (".
	    "$cnf->{f_k} $t_key,".
	    "$cnf->{f_v} $t_val)"
	);
    } # create table

sub TIEHASH
{
    my $pkg = shift;
    my $usg = qq{usage: tie %h, "$pkg", \$dbh [, { tbl => "tbl", key => "f_key", fld => "f_value" }];};
    my $dbh = shift or croak $usg;
    my $opt = shift;

    ref $dbh or
	$dbh = DBI->connect ($dbh, undef, undef, {
	    PrintError       => 1,
	    RaiseError       => 1,
	    PrintWarn        => 1,
	    FetchHashKeyName => "NAME_lc",
	    }) || croak DBI->errstr;

    my $dbt = $dbh->{Driver}{Name} || "no DBI handle";
    my $cnf = $DB{$dbt} or croak "I don't support database '$dbt'";
    my $f_k = "h_key";
    my $f_v = "h_value";
    my $tmp = 0;

    my $h = {
	dbt => $dbt,
	dbh => $dbh,
	tbl => undef,
	tmp => $tmp,
	str => undef,
	asc => $cnf->{k_asc} || 0,
	};

    if ($opt) {
	ref $opt eq "HASH" or croak $usg;

	$opt->{key} and $f_k      = $opt->{key};
	$opt->{fld} and $f_v      = $opt->{fld};
	$opt->{tbl} and $h->{tbl} = $opt->{tbl};
	$opt->{str} and $h->{str} = $opt->{str};
	}

    $h->{f_k} = $f_k;
    $h->{f_v} = $f_v;

    unless ($h->{tbl}) {	# Create a temporary table
	$tmp = ++$dbdx;
	$h->{tbl} = "t_tie_dbd_$$" . "_$tmp";
	_create_table ($h, $tmp);
	}

    my $tbl = $h->{tbl};

    local $dbh->{AutoCommit} = $cnf->{autoc} if exists $cnf->{autoc};

    $h->{ins} = $dbh->prepare ("insert into $tbl values (?, ?)");
    $h->{del} = $dbh->prepare ("delete from $tbl where $f_k = ?");
    $h->{upd} = $dbh->prepare ("update $tbl set $f_v = ? where $f_k = ?");
    $h->{sel} = $dbh->prepare ("select $f_v from $tbl where $f_k = ?");
    $h->{cnt} = $dbh->prepare ("select count(*) from $tbl");
    $h->{ctv} = $dbh->prepare ("select count(*) from $tbl where $f_k = ?");

    unless (exists $cnf->{pbind} && !$cnf->{pbind}) {
	my $sth = $dbh->prepare ("select $f_k, $f_v from $tbl");
	$sth->execute;
	my @typ = @{$sth->{TYPE}};

	$h->{ins}->bind_param (1, undef, $typ[0]);
	$h->{ins}->bind_param (2, undef, $typ[1]);
	$h->{del}->bind_param (1, undef, $typ[0]);
	$h->{upd}->bind_param (1, undef, $typ[1]);
	$h->{upd}->bind_param (2, undef, $typ[0]);
	$h->{sel}->bind_param (1, undef, $typ[0]);
	$h->{ctv}->bind_param (1, undef, $typ[0]);
	}

    bless $h, $pkg;
    } # TIEHASH

sub _stream
{
    my ($self, $val) = @_;
    defined $val or return undef;
    $self->{str} or return $val;

    $self->{str} eq "Storable" and return freeze ({ val => $val });
    } # _stream

sub _unstream
{
    my ($self, $val) = @_;
    defined $val or return undef;
    $self->{str} or return $val;

    $self->{str} eq "Storable" and return thaw ($val)->{val};
    } # _unstream

sub STORE
{
    my ($self, $key, $value) = @_;
    my $k = $self->{asc} ? unpack "H*", $key : $key;
    my $v = $self->_stream ($value);
    $self->EXISTS ($key)
	? $self->{upd}->execute ($v, $k)
	: $self->{ins}->execute ($k, $v);
    } # STORE

sub DELETE
{
    my ($self, $key) = @_;
    $self->{asc} and $key = unpack "H*", $key;
    $self->{sel}->execute ($key);
    my $r = $self->{sel}->fetch or return;
    $self->{del}->execute ($key);
    $self->_unstream ($r->[0]);
    } # DELETE

sub CLEAR
{
    my $self = shift;
    $self->{dbh}->do ("$DB{$self->{dbt}}{clear} $self->{tbl}");
    } # CLEAR

sub EXISTS
{
    my ($self, $key) = @_;
    $self->{asc} and $key = unpack "H*", $key;
    $self->{sel}->execute ($key);
    return $self->{sel}->fetch ? 1 : 0;
    } # EXISTS

sub FETCH
{
    my ($self, $key) = @_;
    $self->{asc} and $key = unpack "H*", $key;
    $self->{sel}->execute ($key);
    my $r = $self->{sel}->fetch or return;
    $self->_unstream ($r->[0]);
    } # STORE

sub FIRSTKEY
{
    my $self = shift;
    $self->{key} = $self->{dbh}->selectcol_arrayref ("select $self->{f_k} from $self->{tbl}");
    @{$self->{key}} or return;
    if ($self->{asc}) {
	 $_ = pack "H*", $_ for @{$self->{key}};
	 }
    pop @{$self->{key}};
    } # FIRSTKEY

sub NEXTKEY
{
    my $self = shift;
    @{$self->{key}} or return;
    pop @{$self->{key}};
    } # FIRSTKEY

sub SCALAR
{
    my $self = shift;
    $self->{cnt}->execute;
    my $r = $self->{cnt}->fetch or return 0;
    $r->[0];
    } # SCALAR

sub DESTROY
{
    my $self = shift;
    $self->{$_}->finish for qw( sel ins upd del cnt ctv );
    $self->{tmp} and $self->{dbh}->do ("drop table ".$self->{tbl});
    } # DESTROY

1;

__END__

=head1 NAME

Tie::Hash::DBD, tie a plain hash to a database table

=head1 SYNOPSIS

  use DBI;
  use Tie::Hash::DBD;

  my $dbh = DBI->connect ("dbi:Pg:", ...);

  tie my %hash, "Tie::Hash::DBD", "dbi:SQLite:dbname=db.tie";
  tie my %hash, "Tie::Hash::DBD", $dbh;
  tie my %hash, "Tie::Hash::DBD", $dbh, {
      tbl => "t_tie_analysis",
      key => "h_key",
      fld => "h_value",
      str => "Storable,
      };

  $hash{key} = $value;  # INSERT
  $hash{key} = 3;       # UPDATE
  delete $hash{key};    # DELETE
  $value = $hash{key};  # SELECT

=head1 DESCRIPTION

This module has been created to act as a drop-in replacement for modules
that tie straight perl hashes to disk, like C<DB_File>. When the running
system does not have enough memory to hold large hashes, and disk-tieing
won't work because there is not enough space, it works quite well to tie
the hash to a database, which preferable runs on a different server.

This module ties a hash to a database table using B<only> a C<key> and a
C<value> field. If no tables specification is passed, this will create a
temporary table with C<h_key> for the key field and a C<h_value> for the
value field.

=head1 tie

The tie call accepts two arguments:

=head2 Database

The first argument is the connection specifier.  This is either and open
database handle or a C<DBI_DSN> string.

If this argument is a valid handle, this module does not open a database
all by itself, but uses the connection provided in the handle.

If the first argument is a scalar, it is used as DSN for DBI->connect ().

Supported DBD drivers include DBD::Pg, DBD::SQLite, DBD::CSV, DBD::mysql,
DBD::Oracle, and DBD::Unify.

DBD::Pg and DBD::SQLite have an unexpected great performance when server
is the local system.

The current implementation appears to be extremely slow for both CSV, as
expected, and mysql. Patches welcome

=head2 Options

The second argument is optional and should - if passed - be a hashref to
options. The following options are recognized:

=over 2

=item tbl

Defines the name of the table to be used. If none is passed, a new table
is created with a unique name like C<t_tie_dbd_422531_1>. When possible,
the table is created as I<temporary>. After the session, this table will
be dropped.

If a table name is provided, it will be checked for existence. If found,
it will be used with the specified C<key> and C<fld>.  Otherwise it will
be created with C<key> and <fld>,  but it will not be dropped at the end
of the session.

=item key

Defines the name of the key field in the database table.  The default is
C<h_key>.

=item fld

Defines the name of the value field in the database table.   The default
is C<h_value>.

=item str

Defines the required persistence module. Currently only supports the use
of C<Storable>. The default is undefined.

Note that C<Storable> does not support persistence of perl types C<CODE>, 
C<REGEXP>, C<IO>, C<FORMAT>, and C<GLOB>.

If you want to preserve Encoding on the hash values, you should use this
feature.

=back

=head1 PREREQUISITES

The only real prerequisite is DBI but of course that uses the DBD driver
of your choice. Some drivers are (very) actively maintained.  Be sure to
to use recent Modules.  DBD::SQLite for example seems to require version
1.29 or up.

=head1 RESTRICTIONS and LIMITATIONS

=over 2

=item *

As Oracle does not allow BLOB, CLOB or LONG to be indexed or selected on,
the keys will be converted to ASCII for Oracle. The maximum length for a
converted key in Oracle is 4000 characters. The fact that the key has to
be converted to ASCII representation,  also excludes C<undef> as a valid
key value.

=item *

This module does not preserve magic on data.

=back

=head1 TODO

=over 2

=item Documentation

Better document what the implications are of storing  I<data> content in
a database and restoring that. It will not be fool proof.

=item Mixins

Maybe: implement a feature that would enable plugins or mixins to do the
streaming or preservation of other data attributes.

=back

=head1 AUTHOR

H.Merijn Brand <h.m.brand@xs4all.nl>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2010 H.Merijn Brand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

DBI, Tie::DBI, Tie::Hash

=cut
