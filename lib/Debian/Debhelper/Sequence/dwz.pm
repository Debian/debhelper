#!/usr/bin/perl
# Enable dh_dwz

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(warning);

warning('The "dwz"-sequence is experimental and may change (or be retired) without any notice');

insert_before('dh_strip', 'dh_dwz');

1;
