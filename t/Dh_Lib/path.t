#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);

BEGIN {
	my $dir = dirname(abs_path(__FILE__));
	unshift(@INC, dirname($dir));
	chdir($dir) or error("chdir($dir) failed: $!");
};

use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 3);

ok(!is_empty_dir(__FILE__), "is_empty_dir(file) is false");
ok(!is_empty_dir(dirname(__FILE__)), "is_empty_dir(non-empty) is false");

my $tempdir = tempdir(CLEANUP => 1);
ok(is_empty_dir($tempdir), "is_empty_dir(new-temp-dir) is true");
