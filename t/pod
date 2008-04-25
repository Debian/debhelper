#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval 'use Test::Pod';
plan skip_all => 'Test::Pod required' if $@;

all_pod_files_ok(grep { -x $_ } glob 'dh_*');
