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
unlink $_ for glob "t_tie_dbd_*.csv";

done_testing;
