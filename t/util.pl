#!/pro/bin/perl

use strict;
use warnings;

sub _dsn
{
    my $type = shift;

    $type eq "SQLite"	and return "dbi:SQLite:dbname=db.3";
    $type eq "Pg"	and return "dbi:Pg:";
    $type eq "CSV"	and return "dbi:CSV:f_ext=.csv/r;csv_null=1";

    if ($type eq "Oracle") {
	my @id = split m{/} => ($ENV{ORACLE_USERID} || "/"), -1;
	$ENV{DBI_USER} = $id[0];
	$ENV{DBI_PASS} = $id[1];

	($ENV{ORACLE_SID} || $ENV{TWO_TASK}) &&
	-d ($ENV{ORACLE_HOME} || "/-..\x03") &&
	   $ENV{DBI_USER} && $ENV{DBI_PASS} or
	    plan skip_all => "Not a testable ORACLE env";
	return "dbi:Oracle:";
	}

    if ($type eq "mysql") {
	my $db = $ENV{MYSQLDB} || $ENV{LOGNAME} || scalar getpwuid $<;
	return "dbi:mysql:database=$db";
	}

    if ($type eq "Unify") {
	$ENV{DBI_USER} = $ENV{USCHEMA} || "";
	-d ($ENV{UNIFY}  || "/-..\x03") &&
	-d ($ENV{DBPATH} || "/-..\x03") or
	    plan skip_all => "Not a testable Unify env";
	return "dbi:Unify:";
	}

    if ($type eq "Firebird") {
	my $user = $ENV{LOGNAME} || scalar getpwuid $<;
	$ENV{ISC_USER} || $user eq "merijn" or
	    plan skip_all => "Firebird has no reproducible test yet";
	$ENV{DBI_USER} = $ENV{ISC_USER}     || $user;
	$ENV{DBI_PASS} = $ENV{ISC_PASSWORD} || "";
	return "dbi:Firebird:db=$user";
	}
    } # _dsn

sub dsn
{
    my $type = shift;
    my $dsn  = _dsn ($type);
    cleanup ($type);
    return $dsn;
    } # dsn

sub plan_fail
{
    my $type = shift;

    my $reason = DBI->errstr;
    $reason or ($reason = $@) =~ s/:.*//s;

    if ($type eq "Pg") {
        # could not connect to server: No such file or directory
	# \tIs the server running locally and accepting
	# \tconnections on Unix do ...
	$reason =~ s{: No such file or directory(\n.*)?$}{}s;
	}
    if ($type eq "mysql") {
	# Can't connect to local MySQL server through socket '/var/run/mysql/mysql.sock' (2)
	$reason =~ s{(Can't connect to local MySQL server).*}{$1}s;
	}
    if ($type eq "Firebird") {
	# Unsuccessful execution caused by a system error that precludes successful execution of subsequent statements
	$reason =~ s{Unsuccessful execution caused by a system error.*}{Cannot connect}s;
	}

    $reason and substr $reason, 0, 0, " - ";
    plan skip_all => "DBD::$type$reason";
    } # plan_fail

sub cleanup
{
    my $type = shift;

    $type eq "Pg"	and return;
    $type eq "Oracle"	and return;
    $type eq "mysql"	and return;
    $type eq "Unify"	and return;
    $type eq "Firebird"	and return;

    if ($type eq "SQLite") {
	unlink $_ for glob "db.3*";
	return;
	}

    if ($type eq "CSV") {
	unlink $_ for glob "t_tie*.csv";
	return;
	}
    } # cleanup

1;
