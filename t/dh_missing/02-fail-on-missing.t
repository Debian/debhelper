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
	# Verify dh_missing does fail when not all files are installed.
	ok(run_dh_tool('dh_clean'));
	is(system('make', 'installmore'), 0);
	ok(run_dh_tool('dh_install', '--sourcedir', 'debian/tmp'));
	ok(!run_dh_tool({ 'quiet' => 1 }, 'dh_missing', '--fail-missing'));

	isnt($?, -1, 'dh_missing was executed');
	ok(! ($? & 127), 'dh_missing did not die due to a signal');
	my $exitcode = ($? >> 8);
	is($exitcode, 2, 'dh_missing exited with exit code 2');
};

