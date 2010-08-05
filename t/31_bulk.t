#!/pro/bin/perl

use strict;
use warnings;

use Test::More;
use Tie::Hash::DBD;

my %hash;
eval { tie %hash, "Tie::Hash::DBD", "dbi:Pg:" };

unless (tied %hash) {
    my $reason = DBI->errstr;
    $reason or ($reason = $@) =~ s/:.*//s;
    $reason and substr $reason, 0, 0, " - ";
    plan skip_all => "Cannot tie using DBD::Pg$reason";
    }

ok (tied %hash,			"Hash tied");

my %plain = map { ( $_ => $_ ) } map { ( $_, pack "l", $_ ) } -10000 .. 10000;

ok (%hash = %plain,		"Assign big hash");
is_deeply (\%hash, \%plain,	"Content");

untie %hash;

done_testing;
