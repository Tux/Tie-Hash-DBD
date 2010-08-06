#!/pro/bin/perl

use strict;
use warnings;

use Test::More;
use Tie::Hash::DBD;

my %hash;
my @id = split m{/} => ($ENV{ORACLE_USERID} || "/");
$ENV{DBI_USER} ||= $id[0];
$ENV{DBI_PASS} ||= $id[1];

($ENV{ORACLE_SID} || $ENV{TWO_TASK}) && -d ($ENV{ORACLE_HOME} || "/-..\x03") &&
   $ENV{DBI_USER}    &&  $ENV{DBI_PASS} or
    plan skip_all => "Not a testable ORACLE env";

eval { tie %hash, "Tie::Hash::DBD", "dbi:Oracle:" };

unless (tied %hash) {
    my $reason = DBI->errstr;
    $reason or ($reason = $@) =~ s/:.*//s;
    $reason and substr $reason, 0, 0, " - ";
    plan skip_all => "Cannot tie using DBD::mysql$reason";
    }

ok (tied %hash,			"Hash tied");

foreach my $size (10, 100) {
    my %plain = map { ( $_ => $_ ) }
		map { ( $_, pack "l", $_ ) }
		-($size - 1) .. $size;

    my $s_size = 2 * $size;

    ok (%hash = %plain,		"Assign hash $s_size elements");
    is_deeply (\%hash, \%plain,	"Content $s_size");
    }

untie %hash;

done_testing;
