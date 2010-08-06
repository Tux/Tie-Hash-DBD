package Tie::Hash::DBD;

our $VERSION = "0.03";

use strict;
use warnings;

use Carp;

=head1 NAME

Tie::Hash::DBD, tie a plain hash to a database table

=head1 SYNOPSIS

  use DBI;
  use Tie::Hash::DBD;

  my $dbh = DBI->connect ("dbi:Pg:", ...);

  tie my %hash, "Tie::Hash::DBD", "dbi:SQLite:dbname=db.tie";
  tie my %hash, "Tie::Hash::DBD", $dbh;
  tie my %hash, "Tie::Hash::DBD", $dbh, {
      tbl => "t_tie_dbd_123_1", key => "h_key", fld => "h_value" };

  $hash{key} = $value;  # INSERT
  $hash{key} = 3;       # UPDATE
  delete $hash{key};    # DELETE
  $value = $hash{key};  # SELECT

=cut

use DBI;

my $dbdx = 0;

my %DB = (
    Pg		=> {
	temp	=> "temp",
	t_key	=> "bytea primary key",
	t_val	=> "bytea",
	clear	=> "truncate table",
	pbind	=> 1,
	autoc	=> 0,
	},
    Unify	=> {	# Doesn't work: needs commit between create and use
	temp	=> "",
	t_key	=> "binary",
	t_val	=> "binary",
	clear	=> "truncate table",
	pbind	=> 1,
	autoc	=> 0,
	},
    Oracle	=> {
	temp	=> "global temporary",	# Only as of Ora-9
	t_key	=> "blob",	# Does not allow binary to be primary key
	t_val	=> "blob",
	clear	=> "truncate table",
	pbind	=> 1,
	autoc	=> 1,
	},
    mysql	=> {
	temp	=> "temporary",
	t_key	=> "blob",	# Does not allow binary to be primary key
	t_val	=> "blob",
	clear	=> "truncate table",
	pbind	=> 1,
	autoc	=> 1,
	},
    SQLite	=> {
	temp	=> "temporary",
	t_key	=> "text primary key",
	t_val	=> "text",
	clear	=> "delete from",
	pbind	=> 0,
	autoc	=> 0,
	},
    CSV		=> {
	temp	=> "temporary",
	t_key	=> "text primary key",
	t_val	=> "text",
	clear	=> "delete from",
	pbind	=> 1,
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
    my $tbl = shift;

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
	tbl => $tbl,
	f_k => $f_k,
	f_v => $f_v,
	tmp => $tmp,
	};

    if ($tbl) {	# Use existing table
	ref $tbl eq "HASH" or croak $usg;

	$tbl->{key} and $f_k = $tbl->{key};
	$tbl->{fld} and $f_v = $tbl->{fld};

	$tbl->{tbl} or croak $usg;
	$tbl = $tbl->{tbl};
	}
    else {	# Create a temporary table
	$tmp = ++$dbdx;
	$tbl = $h->{tbl} = "t_tie_dbd_$$" . "_$tmp";
	_create_table ($h, $tmp);
	}

    local $dbh->{AutoCommit} = $cnf->{autoc} if exists $cnf->{autoc};
    $h->{ins} = $dbh->prepare ("insert into $tbl values (?, ?)");
    $h->{del} = $dbh->prepare ("delete from $tbl where $f_k = ?");
    $h->{upd} = $dbh->prepare ("update $tbl set $f_v = ? where $f_k = ?");
    $h->{sel} = $dbh->prepare ("select $f_v from $tbl where $f_k = ?");
    $h->{cnt} = $dbh->prepare ("select count(*) from $tbl");
    $h->{ctv} = $dbh->prepare ("select count(*) from $tbl where $f_k = ?");

    if ($cnf->{pbind}) {
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

sub STORE
{
    my ($self, $key, $value) = @_;
    $self->EXISTS ($key)
	? $self->{upd}->execute ($value, $key)
	: $self->{ins}->execute ($key, $value);
    } # STORE

sub DELETE
{
    my ($self, $key) = @_;
    $self->{sel}->execute ($key);
    my $r = $self->{sel}->fetch or return;
    $self->{del}->execute ($key);
    $r->[0];
    } # DELETE

sub CLEAR
{
    my $self = shift;
    $self->{dbh}->do ("$DB{$self->{dbt}}{clear} $self->{tbl}");
    } # CLEAR

sub EXISTS
{
    my ($self, $key) = @_;
    $self->{sel}->execute ($key);
    return $self->{sel}->fetch ? 1 : 0;
    } # EXISTS

sub FETCH
{
    my ($self, $key) = @_;
    $self->{sel}->execute ($key);
    my $r = $self->{sel}->fetch or return;
    $r->[0];
    } # STORE

sub FIRSTKEY
{
    my $self = shift;
    $self->{key} = $self->{dbh}->selectcol_arrayref ("select $self->{f_k} from $self->{tbl}");
    @{$self->{key}} or return;
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

=head2 tie

This module does not connect to the database itself, but expects an open
database handle to be passed as first argument (if the first argument is
a database handle).

If the first argument is a scalar, it is used as DSN for DBI->connect ().

If the second argument is a hashref, that should at least define a table
name to be used.  Default key field is  C<h_key> and default value field
is C<h_value>.

=head1 Database

Supported DBD drivers include DBD::Pg, DBD::SQLite, DBD::CSV, DBD::mysql,
DBD::Oracle, and DBD::Unify.

DBD::Pg and DBD::SQLite have an unexpected great performance when server
is the local system.

The current implementation appears to be extremely slow for both CSV, as
expected, and mysql. Patches welcome

=head1 PREREQUISITES

The only real prerequisite is DBI but of course that uses the DBD driver
of your choice. Some drivers are (very) actively maintained.  Be sure to
to use recent Modules.  DBD::SQLite for example seems to require version
1.29 or up.

=head1 Restrictions

This module does not preserve magic on data.

=head1 TODO

=over 2

=item Documentation

Better document what the implications are of storing  I<data> content in
a database and restoring that. It will not be fool proof.

=item Preserve encoding

Currently data is stored as binary.  I'm convinced that any encoding and
magic is lost. Restoring encoding would be great.

=item Feature streaming

Implement features that would enable nested data structures by streaming
using standard perl tools like Data::Dumper, Storable, or FreezeThaw.

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
