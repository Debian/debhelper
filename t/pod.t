#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval { require Test::Pod; Test::Pod->import; };
plan skip_all => 'Test::Pod required' if $@;

all_pod_files_ok('debhelper.pod', grep { -x $_ } 'dh', glob 'dh_*');
