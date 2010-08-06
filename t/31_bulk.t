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

foreach my $size (10, 5000) {
    my %plain = map { ( $_ => $_ ) }
		map { ( $_, pack "l", $_ ) }
		-($size - 1) .. $size;

    my $s_size = 2 * $size;

    ok (%hash = %plain,		"Assign hash $s_size elements");
    is_deeply (\%hash, \%plain,	"Content $s_size");
    }

untie %hash;

done_testing;