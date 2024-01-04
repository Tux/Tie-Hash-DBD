# NAME

Tie::Hash::DBD - tie a plain hash to a database table

# SYNOPSIS

    use DBI;
    use Tie::Hash::DBD;

    my $dbh = DBI->connect ("dbi:Pg:", ...);

    tie my %hash, "Tie::Hash::DBD", "dbi:SQLite:dbname=db.tie";
    tie my %hash, "Tie::Hash::DBD", $dbh;
    tie my %hash, "Tie::Hash::DBD", $dbh, {
        tbl => "t_tie_analysis",
        key => "h_key",
        fld => "h_value",
        str => "Storable",
        trh => 0,
        ro  => 0,
        };

    $hash{key} = $value;  # INSERT
    $hash{key} = 3;       # UPDATE
    delete $hash{key};    # DELETE
    $value = $hash{key};  # SELECT
    %hash = ();           # CLEAR

    my $readonly = tied (%hash)->readonly ();
    tied (%hash)->readonly (1);
    $hash{foo} = 42; # FAIL

# DESCRIPTION

This module has been created to act as a drop-in replacement for modules
that tie straight perl hashes to disk, like `DB_File`. When the running
system does not have enough memory to hold large hashes, and disk-tieing
won't work because there is not enough space, it works quite well to tie
the hash to a database, which preferable runs on a different server.

This module ties a hash to a database table using **only** a `key` and a
`value` field. If no tables specification is passed, this will create a
temporary table with `h_key` for the key field and a `h_value` for the
value field.

I think it would make sense  to merge the functionality that this module
provides into `Tie::DBI`.

# tie

The tie call accepts two arguments:

## Database

The first argument is the connection specifier.  This is either and open
database handle or a `DBI_DSN` string.

If this argument is a valid handle, this module does not open a database
all by itself, but uses the connection provided in the handle.

If the first argument is a scalar, it is used as DSN for DBI->connect ().

Supported DBD drivers include DBD::Pg, DBD::SQLite, DBD::CSV, DBD::MariaDB,
DBD::mysql, DBD::Oracle, DBD::Unify, and DBD::Firebird.  Note that due to
limitations they won't all perform equally well. Firebird is not tested
anymore.

DBD::Pg and DBD::SQLite have an unexpected great performance when server
is the local system. DBD::SQLite is even almost as fast as DB\_File.

The current implementation appears to be extremely slow for CSV, as
expected, MariaDB/mysql, and Unify. For Unify and MariaDB/mysql that is
because these do not allow indexing on the key field so they cannot be
set to be primary key.

When using DBD::CSV with Text::CSV\_XS version 1.02 or newer, it might be
wise to disable utf8 encoding (only supported as of DBD::CSV-0.48):

    "dbi:CSV:f_ext=.csv/r;csv_null=1;csv_decode_utf8=0"

## Options

The second argument is optional and should - if passed - be a hashref to
options. The following options are recognized:

- tbl

    Defines the name of the table to be used. If none is passed, a new table
    is created with a unique name like `t_tie_dbdh_42253_1`. When possible,
    the table is created as _temporary_. After the session, this table will
    be dropped.

    If a table name is provided, it will be checked for existence. If found,
    it will be used with the specified `key` and `fld`.  Otherwise it will
    be created with `key` and `fld`, but it will not be dropped at the end
    of the session.

    If a table name is provided, `AutoCommit` will be "On" for persistence,
    unless you provide a true `trh` attribute.

- key

    Defines the name of the key field in the database table.  The default is
    `h_key`.

- ktp

    Defines the type of the key field in the database table.  The default is
    depending on the underlying database. Probably unwise to change.

    If the database allows the type to be indexed, the key field is defined
    as primary key.

    Note that if your data conflicts with internal (database)limits, like
    having a key that is longer than what the index on a primary key permits,
    you should probably want to create the table yourself with a different
    index or field type.

- fld

    Defines the name of the value field in the database table.   The default
    is `h_value`.

- vtp

    Defines the type of the fld field in the database table.  The default is
    depending on the underlying database and most likely some kind of BLOB.

- ro

    Set handle to read-only for this tie. Useful when using existing tables or
    views than cannot be updated.

    When attempting to alter data (add, delete, change) a warning is issued
    and the action is ignored.

- str

    Defines the required persistence module.   Currently supports the use of
    `Storable`, `Sereal`, `JSON`, `JSON::MaybeXS`, `JSON::SIMD`, `JSON::Syck`,
    `JSON::XS`, `YAML`, `YAML::Syck` and `XML::Dumper`.

    The default is undefined.

    Passing any other value will cause a `croak`.

    If you want to preserve Encoding on the hash values, you should use this
    feature. (except where `PV8` has a `-` in the table below)

    Here is a table of supported data types given a data structure like this:

           my %deep = (
               UND => undef,
               IV  => 1,
               NV  => 3.14159265358979,
               PV  => "string",
               PV8 => "ab\ncd\x{20ac}\t",
               PVM => $!,
               RV  => \$DBD,
               AR  => [ 1..2 ],
               HR  => { key => "value" },
               OBJ => ( bless { auto_diag => 1 }, "Text::CSV_XS" ),
               RX  => qr{^re[gG]e?x},
               FMT => *{$::{STDOUT}}{FORMAT},
               CR  => sub { "code"; },
               GLB => *STDERR,
               IO  => *{$::{STDERR}}{IO},
               );

                     UND  IV  NV  PV PV8 PVM  RV  AR  HR OBJ  RX FMT  CR GLB  IO
        No streamer   x   x   x   x   x   x   x   x   x   x   -   -   -   -   -
        Storable      x   x   x   x   x   x   x   x   x   x   -   -   -   -   -
        Sereal        x   x   x   x   x   x   x   x   x   x   x   x   -   -   -
        JSON          x   x   x   x   x   x   -   x   x   -   -   -   -   -   -
        JSON::MaybeXS x   x   x   x   x   x   -   x   x   -   -   -   -   -   -
        JSON::SIMD    x   x   x   x   x   x   -   x   x   -   -   -   -   -   -
        JSON::Syck    x   x   x   x   -   x   -   x   x   x   -   x   -   -   -
        JSON::XS      x   x   x   x   x   x   -   x   x   -   -   -   -   -   -
        YAML          x   x   x   x   x   -   x   x   x   x   x   x   -   -   -
        YAML::Syck    x   x   x   x   x   -   x   x   x   x   -   x   -   -   -
        XML::Dumper   x   x   x   x   x   x   x   x   x   x   -   x   -   -   -
        FreezeThaw    x   x   x   x   -   x   x   x   x   x   -   x   -   x   -
        Bencode       -   x   x   x   -   x   -   x   x   -   -   -   -   x   -

    So, `Storable` does not support persistence of types `CODE`, `REGEXP`,
    `FORMAT`, `IO`, and `GLOB`. Be sure to test if all of your data types
    are supported by the serializer you choose. YMMV.

    "No streamer"  might work inside the current process if reference values
    are stored, but it is highly unlikely they are persistent.

    Also note that this module does not yet support dynamic deep structures.
    See [Nesting and deep structures](#nesting).

- trh

    Use transaction Handles. By default none of the operations is guarded by
    transaction handling for speed reasons. Set `trh` to a true value cause
    all actions to be surrounded by  `begin_work` and `commit`.  Note that
    this may have a big impact on speed.

## Encoding

`Tie::Hash::DBD` stores keys and values as binary data. This means that
all Encoding and magic is lost when the data is stored, and thus is also
not available when the data is restored,  hence all internal information
about the data is also lost, which includes the `UTF8` flag.

If you want to preserve the `UTF8` flag you will need to store internal
flags and use the streamer option:

    tie my %hash, "Tie::Hash::DBD", "dbi:Pg:", { str => "Storable" };

If you do not want the performance impact of Storable just to be able to
store and retrieve UTF-8 values, there are two ways to do so:

    # Use utf-8 from database
    tie my %hash, "Tie::Hash::DBD", "dbi:Pg:", { vtp => "text" };
    $hash{foo} = "The teddybear costs \x{20ac} 45.95";

    # use Encode
    tie my %hash, "Tie::Hash::DBD", "dbi:Pg:";
    $hash{foo} = encode "UTF-8", "The teddybear costs \x{20ac} 45.95";

Note  that using Encode will allow other binary data too where using the
database encoding does not:

    $hash{foo} = pack "L>A*", time, encode "UTF-8", "Price: \x{20ac} 45.95";

## Nesting and deep structures


`Tie::Hash::DBD` stores keys and values as binary data. This means that
all structure is lost when the data is stored and not available when the
data is restored. To maintain deep structures, use the streamer option:

    tie my %hash, "Tie::Hash::DBD", "dbi:Pg:", { str => "Storable" };

Note that changes inside deep structures do not work. See ["TODO"](#todo).

# METHODS

## drop ()

If a table was used with persistence, the table will not be dropped when
the `untie` is called.  Dropping can be forced using the `drop` method
at any moment while the hash is tied:

    tied (%hash)->drop;

## readonly

You can inquire or set the readonly status of the bound hash. Note that
setting read-only also forbids to delete generated temporary table.

    my $readonly = tied (%hash)->readonly ();
    tied (%hash)->readonly (1);

Setting read-only accepts 3 states:

- false (`undef`, `""`, `0`)

    This will (re)set the hash to read-write.

- `1`

    This will set read-only. When attempting to make changes, a warning is given.

- `2`

    This will set read-only. When attempting to make changes, the process will die.

# PREREQUISITES

The only real prerequisite is DBI but of course that uses the DBD driver
of your choice. Some drivers are (very) actively maintained.  Be sure to
to use recent Modules.  DBD::SQLite for example seems to require version
1.29 or up.

# RESTRICTIONS and LIMITATIONS

- As Oracle does not allow BLOB, CLOB or LONG to be indexed or selected on,
the keys will be converted to ASCII for Oracle. The maximum length for a
converted key in Oracle is 4000 characters. The fact that the key has to
be converted to ASCII representation,  also excludes `undef` as a valid
key value.

    `DBD::Oracle` limits the size of BLOB-reads to 4kb by default, which is
    too small for reasonable data structures.  Tie::Hash::DBD locally raises
    this value to 4Mb, which is still an arbitrary limit.

- `Storable` does not support persistence of perl types `IO`, `REGEXP`,
`CODE`, `FORMAT`, and `GLOB`.  Future extensions might implement some
alternative streaming modules, like `Data::Dump::Streamer` or use mixin
approaches that enable you to fit in your own.
- Note that neither DBD::CSV nor DBD::Unify support `AutoCommit`.
- For now, Firebird does not support `TEXT` (or `CLOB`) in DBD::Firebird
at a level required by Tie::Hash::DBD. Neither does it support arbitrary
length index on `VARCHAR` fields so it can neither be a primary key nor
can it be the subject of a (unique) index hence large sets will be slow.

    Firebird support is stalled.

# TODO

- Update on deep changes

    Currently,  nested structures do not get updated when it is an change in
    a deeper part.

        tie my %hash, "Tie::Hash::DBD", $dbh, { str => "Storable" };

        $hash{deep} = {
            int  => 1,
            str  => "foo",
            };

        $hash{deep}{int}++; # No effect :(

- Documentation

    Better document what the implications are of storing  _data_ content in
    a database and restoring that. It will not be fool proof.

- Mixins

    Maybe: implement a feature that would enable plugins or mixins to do the
    streaming or preservation of other data attributes.

# AUTHOR

H.Merijn Brand <h.m.brand@xs4all.nl>

# COPYRIGHT AND LICENSE

Copyright (C) 2010-2024 H.Merijn Brand

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

# SEE ALSO

DBI, Tie::DBI, Tie::Hash, Tie::Array::DBD, Tie::Hash::RedisDB, Redis::Hash,
DBM::Deep, Storable, Sereal, JSON, JSON::MaybeXS, JSON::SIMD, JSON::Syck,
YAML, YAML::Syck, XML::Dumper, Bencode, FreezeThaw
