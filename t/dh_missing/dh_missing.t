#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.install
    file-for-foo
    Makefile
));

plan(tests => 3);

each_compat_subtest {
	# Verify dh_missing does not fail when all files are installed.
	ok(run_dh_tool('dh_clean'));
	is(system('make', 'install'), 0);
	ok(run_dh_tool('dh_install', '--sourcedir', 'debian/tmp'));
	ok(run_dh_tool('dh_missing', '--fail-missing'), 'dh_missing failed');
};

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

each_compat_up_to_and_incl_subtest(10, sub {
	# Verify that dh_install -X --fail-missing is passed through to dh_missing (#863447)
	# dh_install -Xfile makes file-for-foo not be installed. Then we shouldn't
	# complain about it not being missing.
	ok(run_dh_tool('dh_clean'));
	is(system('make', 'install'), 0);
	ok(run_dh_tool({ 'quiet' => 1 }, 'dh_install', '--sourcedir', 'debian/tmp',
				   '-X', 'more', '--exclude', 'lots', '--fail-missing'));
});

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
