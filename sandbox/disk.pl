#!/pro/bin/perl

use strict;
use warnings;

sub usage
{
    my $err = shift and select STDERR;
    print "usage: $0 [--verbose[=<level>]] [--fast | --long]\n";
    exit $err;
    } # usage

use Getopt::Long qw(:config bundling nopermute);
my $opt_v = 1;
my $opt_f = 0;
my $opt_l = 0;
GetOptions (
    "help|?"	=> sub { usage (0); },

    "v|verbose:2"	=> \$opt_v,
    "f|s|fast|short!"	=> \$opt_f,
    "l|long|slow!"	=> \$opt_l,
    ) or usage (1);

use Data::Peek;
use DB_File;
use Tie::Hash::DBD;

use Time::HiRes qw( gettimeofday tv_interval );

my %t;

my @conf = (
    [ "DB_File", "DB_File",        "db.2", O_RDWR|O_CREAT, 0666		],
    [ "SQLite",  "Tie::Hash::DBD", "dbi:SQLite:dbname=db.3"		],
    [ "Pg",      "Tie::Hash::DBD", "dbi:Pg:"				],
    [ "mysql",   "Tie::Hash::DBD", "dbi:mysql:database=merijn"		],
    [ "CSV",     "Tie::Hash::DBD", "dbi:CSV:f_ext=.csv/r;csv_null=1"	],
    [ "Oracle",  "Tie::Hash::DBD", "dbi:Oracle:"			],
    [ "Unify",   "Tie::Hash::DBD", "dbi:Unify:"				],
    );

unlink $_ for glob ("db.[23]*"), glob ("t_tie*.csv");

foreach my $r (@conf) {
    my ($name, $pkg, @args, %hash) = @$r;

    if ($name eq "Oracle") {
	-d ($ENV{ORACLE_HOME} || "\x01") or next;
	$ENV{DBI_USER} = "PROLEP";
	$ENV{DBI_PASS} = "PROLEP";
	}
    if ($name eq "Unify") {
	-d ($ENV{UNIFY}  || "\x01") or next;
	-d ($ENV{DBPATH} || "\x01") or next;
	$ENV{USCHEMA}  = "PROLEP";
	$ENV{DBI_USER} = "PROLEP";
	$ENV{DBI_PASS} = undef;
	}

    eval { tie %hash, $pkg, @args };
    $@ and next;

    foreach my $size (10, 100, 300, 1000, 10000, 100000) {

	$opt_f            && $size >   300 and next;
	$opt_l		  || $size < 50000 or  next;

	print STDERR " $name $size                \r";

	my %plain = map { ( $_ => $_ ) }
		    map { ( $_, pack "l", $_ ) }
		    -($size - 1) .. $size;

	%hash = ();
	my $s_size = 2 * $size;

	my $t0 = [ gettimeofday ];
	%hash = %plain;
	my $elapsed = tv_interval ($t0);
	$t{$s_size}{wr}{$name} = $s_size / $elapsed;
	$t0 = [ gettimeofday ];
	my %x = %hash;
	$elapsed = tv_interval ($t0);
	$t{$s_size}{rd}{$name} = $s_size / $elapsed;

	$t{$s_size}{rd}{$name} < 275 and last; # Next size will take too long
	}

    untie %hash;
    }

my @name = map { $_->[0] } @conf;
print "  Size op", (map { sprintf " %10s", $_ } @name), "\n",
      "------ --", (map { " ----------"       } @name), "\n";
foreach my $size (sort { $a <=> $b } keys %t) {
    my %o = %{$t{$size}};
    foreach my $op (sort keys %o) {
	printf "%6d %s", $size, $op;
	for (@name) {
	    if (my $x = $o{$op}{$_}) {
		printf " %10.1f", $x;
		}
	    else {
		print "          -";
		}
	    }
	print "\n";
	}
    }
