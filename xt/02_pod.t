#!/usr/bin/perl

use strict;
use warnings;

eval "use Test::Pod::Links";
if ($@) {
    warn "Test::Pod::Links not available\n";
    exit 0;
    }
Test::Pod::Links->new->all_pod_files_ok;
