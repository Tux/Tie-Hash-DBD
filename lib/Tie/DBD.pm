package Tie::DBD;

our $VERSION = "0.01";

use strict;
use warnings;

use Carp;

=head1 NAME

Tie::DBD, tie a hash to a database table

=head1 SYNOPSIS

    use DBI;
    use Tie::DBD;

    my $dbh = DBI->connect ("dbi:Pg:", ...);

    tie my %hash, "Tie::DBD", $dbh;
    tie my %hash, "Tie::DBD", $dbh, "foo";

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

DBI, Tie::Hash

=cut

my $dbdx = 0;

sub TIEHASH
{
    my $pkg = shift;
    my $dbh = shift or croak "No database handle passed";
    my $tbl = shift;

    unless ($tbl) {
	$tbl = "t_tie_dbd_$$" . "_" . ++$dbdx;
	my $type = {
	    Oracle	=> [ "text", "text"  ],
	    Pg		=> [ "text", "bytea" ],
	    }->{$dbh->{Driver}{Name}} or croak "I don't support your database";
	$dbh->do ("create temp table $tbl (key $type->[0], value $type->[1])");
	}
    bless {
	dbh => $dbh,
	tbl => $tbl,
	ins => $dbh->prepare ("insert into $tbl values (?, ?)"),
	del => $dbh->prepare ("delete from $tbl where key = ?"),
	upd => $dbh->prepare ("update $tbl set value = ? where key = ?"),
	sel => $dbh->prepare ("select value from $tbl where key = ?"),
	cnt => $dbh->prepare ("select count (*) from $tbl"),
	ctv => $dbh->prepare ("select count (*) from $tbl where key = ?"),
	}, $pkg;
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
    $self->{key} = $self->{dbh}->selectcol_arrayref ("select key from ".$self->{tbl});
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
