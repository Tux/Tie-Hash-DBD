#!/pro/bin/perl

use 5.14.2;
use warnings;

our $VERSION = "0.12";
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

    "a|array!"		=> \ my $opt_a,
    "f|s|fast|short!"	=> \ my $opt_f,
    "l|long|slow!"	=> \ my $opt_l,

    "v|verbose:2"	=> \(my $opt_v = 1),
    ) or usage (1);

use Data::Peek;
use Text::CSV_XS qw( csv );
use DB_File;
use CDB_File;
use Tie::Hash::DBD;
use Tie::Array::DBD;
eval "use $_" for qw( GDBM_File NDBM_File ODBM_File SDBM_File
		      Redis::Hash Redis::Fast::Hash
		      KyotoCabinet );
my $DB_CREATE = eval "use BerkeleyDB; DB_CREATE;";

use Time::HiRes qw( gettimeofday tv_interval );

my $u = $ENV{LOGNAME} || $ENV{USER} || getpwuid $<;

my %t;

my @conf = (
    [ "perl",      undef,              undef				],

    [ "GDBM",      "GDBM_File",        "db.8", O_RDWR|O_CREAT, 0666	],
    [ "NDBM",      "NDBM_File",        "db.7", O_RDWR|O_CREAT, 0666	],
    [ "ODBM",      "ODBM_File",        "db.6", O_RDWR|O_CREAT, 0666	],
    [ "SDBM",      "SDBM_File",        "db.5", O_RDWR|O_CREAT, 0666	],
    [ "DB_File",   "DB_File",          "db.2", O_RDWR|O_CREAT, 0666	],
    [ "CDB_File",  "CDB_File",         "db.3"				],
    [ "BerkeleyDB","BerkeleyDB::Hash", -Filename => "db.4",
				       -Flags    => $DB_CREATE,		],
    [ "KyotoCab",  "KyotoCabinet::DB", "casket.kch"	],
    [ "Redis",     "Redis::Hash",      "dbd_"				],
    [ "Redis2",    "Redis::Hash",      "dbd2_",  encoding => undef	],
    [ "RedisFast", "Redis::Fast::Hash","dbdf_"				],
    [ "RedisFast2","Redis::Fast::Hash","dbdf2_", encoding => undef	],
    [ "SQLite",    "Tie::Hash::DBD",   "dbi:SQLite:dbname=db.1"		],
    [ "Pg",        "Tie::Hash::DBD",   "dbi:Pg:"			],
    [ "mysql",     "Tie::Hash::DBD",   "dbi:mysql:database=$u;user=$u"	],
    [ "MariaDB",   "Tie::Hash::DBD",   "dbi:MariaDB:database=$u;user=$u"],
    [ "CSV",       "Tie::Hash::DBD",   "dbi:CSV:f_ext=.csv/r;csv_null=1"],
    [ "Oracle",    "Tie::Hash::DBD",   "dbi:Oracle:"			],
    [ "Unify",     "Tie::Hash::DBD",   "dbi:Unify:"			],
    );

unlink $_ for glob ("db.[0-9]*"), glob ("t_tie*.csv"), "casket.kch";

my @csv = ([qw( method module version direction size speed )]);

foreach my $r (@conf) {
    my ($name, $pkg, @args, %hash, @array, $rv) = @$r;

    local $ENV{DBI_USER} = $ENV{DBI_USER};
    local $ENV{DBI_PASS} = $ENV{DBI_PASS};

    if ($opt_a && $pkg) {
	$pkg =~ s/::Hash::/::Array::/    or next;
	}

    if ($name eq "Oracle") {
	-d ($ENV{ORACLE_HOME} || "\x01") or next;
	@ENV{qw( DBI_USER DBI_PASS )} = split m{/} => $ENV{ORACLE_USERID};
	}
    if ($name eq "Unify") {
	-d ($ENV{UNIFY}  || "\x01")      or next;
	-d ($ENV{DBPATH} || "\x01")      or next;
	}
    if ($name eq "mysql" || $name eq "MariaDB") {
	$args[0] =~ s/;user=([^;]+)// and $ENV{DBI_USER} = $1;
	}

    if ($pkg) {
	eval { $opt_a
	    ? tie @array, $pkg, @args
	    : tie %hash,  $pkg, @args
	    };
	if ($@) {
	    warn "$name:", $@;
	    next;
	    }
	}

    my $vsn = $pkg ? $pkg =~ m/DBD$/ ? "DBD::${name}"->VERSION
				     : ${pkg}->VERSION || $name->VERSION : $];
    my @tag = ($name, $pkg || "perl", $vsn || "");
    my $tag = join "|" => @tag;
    #say $tag; next;

    foreach my $size (10, 100, 300, 1000, 10000, 100000) {

	$opt_f && $size >   300 and next;
	$opt_l || $size < 50000 or  next;

	print STDERR " $name $size                \r";

	my ($t0, $s_size);
	if ($opt_a) {
	    my @plain = -($size - 1) .. $size;

	    @array = ();
	    $s_size = 2 * $size;

	    $t0 = [ gettimeofday ];
	    @array = @plain;
	    my $wv = $s_size / tv_interval ($t0);
	    $t{$s_size}{wr}{$name} = $wv;
	    push @csv, [ @tag, "wr", $s_size, $wv ];

	    $t0 = [ gettimeofday ];
	    my @x = @array;
	    }
	else {
	    my %plain = map { ( $_ => $_ ) }
			map { ( $_, pack "l", $_ ) }
			-($size - 1) .. $size;

	    %hash = ();
	    $s_size = 2 * $size;

	    $t0 = [ gettimeofday ];
	    %hash = %plain;
	    my $wv = $s_size / tv_interval ($t0);
	    $t{$s_size}{wr}{$name} = $wv;
	    push @csv, [ @tag, "wr", $s_size, $wv ];

	    $t0 = [ gettimeofday ];
	    my %x = %hash;
	    }
	my $rv = $s_size / tv_interval ($t0);
	$t{$s_size}{rd}{$name} = $rv;
	push @csv, [ @tag, "rd", $s_size, $rv ];
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

csv (in => \@csv, out => $opt_a ? "disk-a.csv" : "disk.csv");
