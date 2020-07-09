requires   "Carp";
requires   "DBI"                      => "1.613";
requires   "Storable";

recommends "DBD::CSV"                 => "0.54";
recommends "DBD::Pg"                  => "3.13.0";
recommends "DBD::SQLite"              => "1.64";
recommends "DBI"                      => "1.643";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker";
    };

on "test" => sub {
    requires   "Test::Harness";
    requires   "Test::More"               => "0.90";
    requires   "Time::HiRes";

    recommends "Test::More"               => "1.302175";
    };
