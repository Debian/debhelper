#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 9;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);

# Test clean_jobserver_makeflags.

test_clean_jobserver_makeflags('--jobserver-fds=103,104 -j',
                               undef,
                               'unset makeflags');

test_clean_jobserver_makeflags('-a --jobserver-fds=103,104 -j -b',
                               '-a -b',
                               'clean makeflags');

test_clean_jobserver_makeflags(' --jobserver-fds=1,2 -j  ',
                               undef,
                               'unset makeflags');

test_clean_jobserver_makeflags('-a -j -b',
                               '-a -j -b',
                               'clean makeflags does not remove -j');

test_clean_jobserver_makeflags('-a --jobs -b',
                               '-a --jobs -b',
                               'clean makeflags does not remove --jobs');

test_clean_jobserver_makeflags('-j6',
                               '-j6',
                               'clean makeflags does not remove -j6');

test_clean_jobserver_makeflags('-a -j6 --jobs=7',
                               '-a -j6 --jobs=7',
                               'clean makeflags does not remove -j or --jobs');

test_clean_jobserver_makeflags('-j6 --jobserver-fds=103,104 --jobs=8',
                               '-j6 --jobs=8',
                               'jobserver options removed');

test_clean_jobserver_makeflags('-j6 --jobserver-auth=103,104 --jobs=8',
                               '-j6 --jobs=8',
                               'jobserver options removed');

sub test_clean_jobserver_makeflags {
    my ($orig, $expected, $test) = @_;

    local $ENV{MAKEFLAGS} = $orig;
    clean_jobserver_makeflags();
    is($ENV{MAKEFLAGS}, $expected, $test);
}

