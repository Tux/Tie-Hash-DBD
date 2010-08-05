#!/pro/bin/perl

use strict;
use warnings;

use Test::More;
use Tie::Hash::DBD;

my %hash;
unlink $_ for glob "t_tie_dbd_*.csv";
eval { tie %hash, "Tie::Hash::DBD", "dbi:CSV:f_ext=.csv/r" };

unless (tied %hash) {
    my $reason = DBI->errstr;
    $reason or ($reason = $@) =~ s/:.*//s;
    $reason and substr $reason, 0, 0, " - ";
    plan skip_all => "Cannot tie using DBD::CSV$reason";
    }

ok (tied %hash,						"Hash tied");

# insert
ok ($hash{c1} = 1,					"c1 = 1");
ok ($hash{c2} = 1,					"c2 = 1");
ok ($hash{c3} = 3,					"c3 = 3");

ok ( exists $hash{c1},					"Exists c1");
ok (!exists $hash{c4},					"Exists c4");

# update
ok ($hash{c2} = 2,					"c2 = 2");

# delete
is (delete ($hash{c3}), 3,				"Delete c3");

# select
is ($hash{c1}, 1,					"Value of c1");

# keys, values
is_deeply ([ sort keys   %hash ], [ "c1", "c2" ],	"Keys");
is_deeply ([ sort values %hash ], [ 1, 2 ],		"Values");

is_deeply (\%hash, { c1 => 1, c2 => 2 },		"Hash");

# Scalar/count
is (scalar %hash, 2,					"Scalar");

# Binary data
my $anr = pack "sss", 102, 102, 025;
ok ($hash{c4} = $anr,					"Binary value");
ok ($hash{$anr} = 42,					"Binary key");
ok ($hash{$anr} = $anr,					"Binary key and value");

# clear
%hash = ();
my $todo = $SQL::Statement::VERSION < 1.30
    ? " - TODO: Fixed in SQL::Statement 1.30" : "";
is_deeply (\%hash, {},					"Clear$todo");

untie %hash;
unlink $_ for glob "t_tie_dbd_*.csv";

done_testing;
