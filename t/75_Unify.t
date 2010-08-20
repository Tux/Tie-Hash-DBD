#!/pro/bin/perl

use strict;
use warnings;

use Test::More;
use Tie::Array::DBD;

require "t/util.pl";

my @array;
my $DBD = "Unify";
cleanup ($DBD);
eval { tie @array, "Tie::Array::DBD", dsn ($DBD) };

unless (tied @array) {
    my $reason = DBI->errstr;
    $reason or ($reason = $@) =~ s/:.*//s;
    $reason and substr $reason, 0, 0, " - ";
    plan skip_all => "DBD::$DBD$reason";
    }

ok (tied @array,						"Array tied");

# insert
ok ($array[1] = 1,					"1 =  1");
is ($array[1],  1,					"1 == 1");
ok ($array[2] = 1,					"2 =  1");
is ($array[2],  1,					"2 == 1");
ok ($array[3] = 3,					"3 =  3");
is ($array[3],  3,					"3 == 3");

ok ( exists $array[1],					"Exists 1");
ok (!exists $array[4],					"Exists 4");

# update
ok ($array[2] = 2,					"2 =  2");
is ($array[2],  2,					"2 == 2");

is_deeply (\@array, [ undef, 1..3 ],			"Array");

is ($array[0] = 0, 0,					"0 = 0");

# negative indices
is ($array[-1],  3,					"-1 == 3");
is ($array[-2],  2,					"-2 == 2");

# push
is (push (@array, 4), 5,				"Push single");
is_deeply (\@array, [ 0..4 ],				"Array");
is (push (@array, 5, 6), 7,				"Push multi");
is_deeply (\@array, [ 0..6 ],				"Array");

# delete
is (pop @array, 6,					"Pop 6");
is_deeply (\@array, [ 0..5 ],				"Array");

$] >= 5.011 and eval q{ # keys, values
    is_deeply ([ sort keys   @array ], [ 0..5 ],	"Keys");
    is_deeply ([ sort values @array ], [ 0..5 ],	"Values");
    };

# Scalar/count
is (      $#array, 5,					"Scalar index");
is (scalar @array, 6,					"Scalar op");

is (delete $array[4], 4,				"Delete 4");
is_deeply (\@array, [ 0..3, undef, 5 ],			"Array");

# Binary data
my $anr = pack "sss", 102, 102, 025;
ok ($array[4] = $anr,					"Binary value set");
is ($array[4], $anr,					"Binary value get");

ok ($#array = 3,					"Truncate");
is_deeply (\@array, [ 0..3 ],				"Array");

# shift/unshift
is (shift @array, 0,					"Shift");
is_deeply (\@array, [ 1..3 ],				"Array");
is (unshift (@array, "c"), 4,				"Unshift single");
is (unshift (@array, "a", "b"), 6,			"Unshift multi");
is_deeply (\@array, [ "a".."c", 1..3 ],			"Array");

# splice - NYI
# ok ((splice @array, 2, 2),				"Splice");
# is_deeply (\@array, [ "a".."b", 2..3 ],		"Array");

ok (@array = (1..3),					"Bulk");
is_deeply (\@array, [ 1..3 ],				"Array");

# clear
@array = ();
is_deeply (\@array, [],					"Clear");

untie @array;
cleanup ($DBD);

done_testing;
