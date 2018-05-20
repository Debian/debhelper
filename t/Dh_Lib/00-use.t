#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Test::More tests => 2;

use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));

my $test_dir = tempdir(CLEANUP => 1);

chdir($test_dir);

# Packages that need to be able to (at least) load without requring
# d/control or d/compat.

use_ok('Debian::Debhelper::Dh_Lib', '!dirname');
use_ok('Debian::Debhelper::Buildsystem');
