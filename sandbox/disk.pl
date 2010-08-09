#!/pro/bin/perl

use strict;
use warnings;

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
#   [ "Oracle",  "Tie::Hash::DBD", "dbi:Oracle:"			],
    );

unlink $_ for glob ("db.[23]*"), glob ("t_tie*.csv");

foreach my $r (@conf) {
    my ($name, $pkg, @args, %hash) = @$r;

    $ENV{DBI_USER} = "PROLEP" if $name eq "Oracle";
    $ENV{DBI_PASS} = "PROLEP" if $name eq "Oracle";

    tie %hash, $pkg, @args;

    foreach my $size (10, 100, 1000, 10000) {#, 100000) {

	$name eq "CSV"    && $size >  100 and next;
	$name eq "mysql"  && $size > 1000 and next;
	$name eq "Oracle" && $size >  100 and next;

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
