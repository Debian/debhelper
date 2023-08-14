#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;

our $TEST_DH_FIXTURE_DIR = 'template';
our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.install
    file-for-foo
    Makefile
));

plan(tests => 1);

each_compat_subtest {
	# Verify dh_missing does not fail when all files are installed.
	ok(run_dh_tool('dh_clean'));
	is(system('make', 'install'), 0);
	ok(run_dh_tool('dh_install', '--sourcedir', 'debian/tmp'));
	ok(run_dh_tool('dh_missing', '--fail-missing'), 'dh_missing failed');
};

