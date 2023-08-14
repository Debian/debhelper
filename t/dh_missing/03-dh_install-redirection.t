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

each_compat_up_to_and_incl_subtest(10, sub {
	# Verify that dh_install -X --fail-missing is passed through to dh_missing (#863447)
	# dh_install -Xfile makes file-for-foo not be installed. Then we shouldn't
	# complain about it not being missing.
	ok(run_dh_tool('dh_clean'));
	is(system('make', 'install'), 0);
	ok(run_dh_tool({ 'quiet' => 1 }, 'dh_install', '--sourcedir', 'debian/tmp',
				   '-X', 'more', '--exclude', 'lots', '--fail-missing'));
});

