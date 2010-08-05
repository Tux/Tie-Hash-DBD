package Tie::Hash::DBD;

our $VERSION = "0.02";

use strict;
use warnings;

use Carp;

=head1 NAME

Tie::Hash::DBD, tie a hash to a database table

=head1 SYNOPSIS

    use DBI;
    use Tie::Hash::DBD;

    my $dbh = DBI->connect ("dbi:Pg:", ...);

    tie my %hash, "Tie::Hash::DBD", $dbh;
    tie my %hash, "Tie::Hash::DBD", $dbh, "foo";

    $hash{key} = $value;  # INSERT
    $hash{key} = 3;       # UPDATE
    delete $hash{key};    # DELETE
    $value = $hash{key};  # SELECT

=head1 AUTHOR

H.Merijn Brand <h.m.brand@xs4all.nl>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2010 H.Merijn Brand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

DBI, Tie::DBI, Tie::Hash

=cut

my $dbdx = 0;

sub TIEHASH
{
    my $pkg = shift;
    my $dbh = shift or croak "No database handle passed";
    my $tbl = shift;

    unless ($tbl) {
	$tbl = "t_tie_dbd_$$" . "_" . ++$dbdx;
	my $type = {	# Oracle only support TEMP tables as of Ora-10
	    Oracle	=> [ "temporary", "blob",              "blob"  ],
	    Pg		=> [ "temp",      "bytea primary key", "bytea" ],
	    mysql	=> [ "temporary", "blob",              "blob"  ],
	    }->{$dbh->{Driver}{Name}} or croak "I don't support your database";
	local $dbh->{PrintWarn} = 0;
	$dbh->do (
	    "create $type->[0] table $tbl (".
		"h_key   $type->[1],".
		"h_value $type->[2])");
	}

    my $h = {
	dbh => $dbh,
	tbl => $tbl,
	ins => $dbh->prepare ("insert into $tbl values (?, ?)"),
	del => $dbh->prepare ("delete from $tbl where h_key = ?"),
	upd => $dbh->prepare ("update $tbl set h_value = ? where h_key = ?"),
	sel => $dbh->prepare ("select h_value from $tbl where h_key = ?"),
	cnt => $dbh->prepare ("select count (*) from $tbl"),
	ctv => $dbh->prepare ("select count (*) from $tbl where h_key = ?"),
	};

    my $sth = $dbh->prepare ("select h_key, h_value from $tbl");
    $sth->execute;
    my @typ = @{$sth->{TYPE}};
    $h->{ins}->bind_param (1, undef, $typ[0]);
    $h->{ins}->bind_param (2, undef, $typ[1]);
    $h->{del}->bind_param (1, undef, $typ[0]);
    $h->{upd}->bind_param (1, undef, $typ[1]);
    $h->{upd}->bind_param (2, undef, $typ[0]);
    $h->{sel}->bind_param (1, undef, $typ[0]);
    $h->{ctv}->bind_param (1, undef, $typ[0]);

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
    $self->{dbh}->do ("truncate table " . $self->{tbl});
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
    $self->{key} = $self->{dbh}->selectcol_arrayref ("select h_key from ".$self->{tbl});
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
    $self->{tbl} =~ m/^t_tie_dbd_[0-9]+_[0-9]+$/ and
	$self->{dbh}->do ("drop table ".$self->{tbl});
    } # DESTROY

1;