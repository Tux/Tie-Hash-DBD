requires   "Carp";
requires   "DBI"                      => "1.613";
requires   "Storable";

recommends "DBD::CSV"                 => "0.60";
recommends "DBD::Pg"                  => "3.16.3";
recommends "DBD::SQLite"              => "1.72";
recommends "DBI"                      => "1.643";
recommends "Sereal"                   => "5.003";

on "configure" => sub {
    requires   "ExtUtils::MakeMaker";
    };

on "test" => sub {
    requires   "Test::Harness";
    requires   "Test::More"               => "0.90";
    requires   "Time::HiRes";

    recommends "Test::More"               => "1.302194";
    };
