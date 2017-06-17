#!/pro/bin/perl

use strict;
use warnings;

use Getopt::Long qw(:config bundling nopermute);
my $check = 0;
my $opt_v = 0;
GetOptions (
    "c|check"		=> \$check,
    "v|verbose:1"	=> \$opt_v,
    ) or die "usage: $0 [--check]\n";

use lib "sandbox";
use genMETA;
my $meta = genMETA->new (
    from    => "lib/Tie/Hash/DBD.pm",
    verbose => $opt_v,
    );

$meta->from_data (<DATA>);

if ($check) {
    $meta->check_encoding ();
    $meta->check_required ();
    $meta->check_minimum ([ "t", "xt", "examples", "lib.pm", "Makefile.PL" ]);
    $meta->done_testing ();
    }
elsif ($opt_v) {
    $meta->print_yaml ();
    }
else {
    $meta->fix_meta ();
    }

__END__
--- #YAML:1.0
name:                    Tie-Hash-DBD
version:                 VERSION
abstract:                Tie plain hashes to DBI interface
license:                 perl
author:
    - H.Merijn Brand <h.m.brand@xs4all.nl>
generated_by:            Author
distribution_type:       module
provides:
    Tie::Hash::DBD:
        file:            lib/Tie/Hash/DBD.pm
        version:         VERSION
    Tie::Array::DBD:
        file:            lib/Tie/Array/DBD.pm
        version:         VERSION
requires:
    perl:                5.008003
    Carp:                0
    DBI:                 1.613
    Storable:            0
configure_requires:
    ExtUtils::MakeMaker: 0
test_requires:
    Test::Harness:       0
    Test::More:          0.90
    Time::HiRes:         0
recommends:
    DBI:                 1.636
    DBD::SQLite:         1.54
    DBD::Pg:             3.6.2
    DBD::CSV:            0.50
test_recommends:
    Test::More:          1.302085
resources:
    license:             http://dev.perl.org/licenses/
    repository:          https://github.com/Tux/Tie-Hash-DBD
meta-spec:
    version:             1.4
    url:                 http://module-build.sourceforge.net/META-spec-v1.4.html
