#!/pro/bin/perl

use 5.14.2;
use warnings;

our $VERSION = "0.10";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD [--verbose[=<level>]] [--fast | --long]";
    exit $err;
    } # usage

use Getopt::Long qw(:config bundling nopermute);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "f|s|fast|short!"	=> \ my $opt_f,
    "l|long|slow!"	=> \ my $opt_l,

    "v|verbose:2"	=> \(my $opt_v = 1),
    ) or usage (1);

use Data::Peek;
use DB_File;
use CDB_File;
use Tie::Hash::DBD;
eval "use $_" for qw( Redis::Hash GDBM_File NDBM_File ODBM_File SDBM_File );
my $DB_CREATE = eval "use BerkeleyDB; DB_CREATE;";

use Time::HiRes qw( gettimeofday tv_interval );

my $u = $ENV{LOGNAME} || $ENV{USER} || getpwuid $<;

my %t;

my @conf = (
    [ "perl",    undef,             undef				],

    [ "GDBM",      "GDBM_File",       "db.8", O_RDWR|O_CREAT, 0666	],
    [ "NDBM",      "NDBM_File",       "db.7", O_RDWR|O_CREAT, 0666	],
    [ "ODBM",      "ODBM_File",       "db.6", O_RDWR|O_CREAT, 0666	],
    [ "SDBM",      "SDBM_File",       "db.5", O_RDWR|O_CREAT, 0666	],
    [ "DB_File",   "DB_File",         "db.2", O_RDWR|O_CREAT, 0666	],
    [ "CDB_File",  "CDB_File",        "db.3"				],
    [ "BerkeleyDB","BerkeleyDB::Hash", -Filename => "db.4",
				       -Flags    => $DB_CREATE,		],
    [ "Redis",     "Redis::Hash",     "dbd_"				],
    [ "Redis2",    "Redis::Hash",     "dbd2_", encoding => undef	],
    [ "SQLite",    "Tie::Hash::DBD",  "dbi:SQLite:dbname=db.1"		],
    [ "Pg",        "Tie::Hash::DBD",  "dbi:Pg:"				],
    [ "mysql",     "Tie::Hash::DBD",  "dbi:mysql:database=$u;user=$u"	],
    [ "MariaDB",   "Tie::Hash::DBD",  "dbi:MariaDB:database=$u;user=$u"	],
    [ "CSV",       "Tie::Hash::DBD",  "dbi:CSV:f_ext=.csv/r;csv_null=1"	],
    [ "Oracle",    "Tie::Hash::DBD",  "dbi:Oracle:"			],
    [ "Unify",     "Tie::Hash::DBD",  "dbi:Unify:"			],
    );

tie my %results, "Tie::Hash::DBD", "dbi:CSV:f_ext=.csv;csv_null=1", {
    table => "disk",
    key   => "conf",
    fld   => "value",
    };

unlink $_ for glob ("db.[0-9]*"), glob ("t_tie*.csv");

foreach my $r (@conf) {
    my ($name, $pkg, @args, %hash) = @$r;

    local $ENV{DBI_USER} = $ENV{DBI_USER};
    local $ENV{DBI_PASS} = $ENV{DBI_PASS};

    if ($name eq "Oracle") {
	-d ($ENV{ORACLE_HOME} || "\x01") or next;
	@ENV{qw( DBI_USER DBI_PASS )} = split m{/} => $ENV{ORACLE_USERID};
	}
    if ($name eq "Unify") {
	-d ($ENV{UNIFY}  || "\x01")      or next;
	-d ($ENV{DBPATH} || "\x01")      or next;
	}

    if ($pkg) {
	eval { tie %hash, $pkg, @args };
	if ($@) {
	    warn "$name:", $@;
	    next;
	    }
	}

    my $vsn = $pkg ? $pkg =~ m/DBD$/ ? "DBD::${name}"->VERSION
				     : ${pkg}->VERSION || $name->VERSION : $];
    my $tag = join "|" => $name, $pkg || "perl", $vsn || "";
    #say $tag; next;

    foreach my $size (10, 100, 300, 1000, 10000, 100000) {

	$opt_f && $size >   300 and next;
	$opt_l || $size < 50000 or  next;

	print STDERR " $name $size                \r";

	my %plain = map { ( $_ => $_ ) }
		    map { ( $_, pack "l", $_ ) }
		    -($size - 1) .. $size;

	%hash = ();
	my $s_size = 2 * $size;

	my $t0 = [ gettimeofday ];
	%hash = %plain;
	my $wv = $s_size / tv_interval ($t0);
	$results{"$tag|wr|$s_size"} = $t{$s_size}{wr}{$name} = $wv;

	$t0 = [ gettimeofday ];
	my %x = %hash;
	my $rv = $s_size / tv_interval ($t0);
	$results{"$tag|rd|$s_size"} = $t{$s_size}{rd}{$name} = $rv;

	$rv < 275 and last; # Next size will take too long
	}

    %hash = ();
    untie %hash;
    }

my @name = map { $_->[0] } grep { $t{20}{rd}{$_->[0]} } @conf;
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
	say "";
	}
    }

untie %results;
