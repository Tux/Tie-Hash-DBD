#!/pro/bin/perl

use 5.016002;
use warnings;

use DBI;
use Data::Peek;
use Time::HiRes qw( gettimeofday tv_interval );

sub time_this
{
    my ($dbh, $sql, $how) = @_;
    my $t0  = [ gettimeofday ];
    my $sth = $dbh->prepare ($sql);
    printf "%s   %7.5f", $how, tv_interval ($t0, [ gettimeofday ]);
    $t0 = [ gettimeofday ];
    $sth->execute;
    printf "  %7.5f", tv_interval ($t0, [ gettimeofday ]);
    my @fld = @{$sth->{NAME}};
    $t0 = [ gettimeofday ];
    $sth->finish;
    printf "  %7.5f\n", tv_interval ($t0, [ gettimeofday ]);
    } # time_this

for (   [ Pg            => ""                                           ],
        [ mysql         => "database=merijn"                            ],
        [ CSV           => "f_ext=.csv/r"                               ],
        [ Oracle        => "", split m{/} => $ENV{ORACLE_USERID}        ],
        [ Firebird      => "db=$ENV{ISC_USER}", $ENV{ISC_USER}, $ENV{ISC_PASSWORD}       ],
        ) {
    my ($dbd, $dsn, $user, $pass) = @$_;
    $dsn = join ":" => "dbi", $dbd, $dsn;
    my $dbh = DBI->connect ($dsn, $user, $pass, {
	RaiseError         => 0,
	PrintError         => 1,
	AutoCommit         => 1,
	ChopBlanks         => 1,
	ShowErrorStatement => 1,
	FetchHashKeyName   => "NAME_lc",
	}) or do { warn DBI->errstr; next; };

    say "DBI-", DBI->VERSION, ", DBD::$dbd-", "DBD::$dbd"->VERSION;

    my $tbl = "test_$$";
    my $sth = $dbh->do ("create table $tbl (k integer, v varchar (20))") or
	do { warn $dbh->errstr; next; };

    my $sti = $dbh->prepare ("insert into $tbl values (?, ?)");
    $sti->execute ($_, "value$_") for 1 .. 10000;

    my $sql1 = "select * from $tbl";
    my $sql2 = "select * from $tbl where 0 = 1";

    say "              prepare  execute  finish";
    say "------------- -------  -------  -------";
    for (1 .. 3) {
	time_this ($dbh, $sql1, "   no where");
	time_this ($dbh, $sql2, "where 0 = 1");
	}
    say "";

    $dbh->do ("drop table $tbl");
    }
