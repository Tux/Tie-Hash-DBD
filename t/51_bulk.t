#!/pro/bin/perl

use strict;
use warnings;

use Test::More;
use Tie::Hash::DBD;

plan skip_all => "Currently too slow to test";

my %hash;
eval {
    my $db = $ENV{MYSQLDB} || $ENV{LOGNAME} || scalar getpwuid $<;
    tie %hash, "Tie::Hash::DBD", "dbi:mysql:database=$db";
    };

unless (tied %hash) {
    my $reason = DBI->errstr;
    $reason or ($reason = $@) =~ s/:.*//s;
    $reason and substr $reason, 0, 0, " - ";
    plan skip_all => "Cannot tie using DBD::mysql$reason";
    }

ok (tied %hash,			"Hash tied");

my %plain = map { ( $_ => $_ ) } map { ( $_, pack "l", $_ ) } -10000 .. 10000;

ok (%hash = %plain,		"Assign big hash");
is_deeply (\%hash, \%plain,	"Content");

untie %hash;

done_testing;
