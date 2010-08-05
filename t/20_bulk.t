#!/pro/bin/perl

use strict;
use warnings;

use PROCURA::DBD;
use Tie::Hash::DBD;
use Data::Peek;
use Test::More;

my $dbh = DBDlogon (1);

tie my %hash, "Tie::Hash::DBD", $dbh;

ok (tied %hash,			"Hash tied");

my %plain = map { ( $_ => $_ ) } map { ( $_, pack "l", $_ ) } -10000 .. 10000;

ok (%hash = %plain,		"Assign big hash");
is_deeply (\%hash, \%plain,	"Content");

untie %hash;

done_testing;
