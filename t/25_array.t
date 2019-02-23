#!/pro/bin/perl

use strict;
use warnings;

use Test::More;

require "./t/arraytest.pl";

arraytests ("SQLite");

done_testing;
