#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 2);

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
	debian/changelog
	debian/control
	debian/foo.pam
));

each_compat_up_to_and_incl_subtest(13, sub {
	make_path(qw(debian/foo));
	ok(run_dh_tool('dh_installpam'));

	ok(-f 'debian/foo/etc/pam.d/foo');
	ok(! -f 'debian/foo/usr/lib/pam.d/foo');

	ok(run_dh_tool('dh_clean'));
});

each_compat_from_and_above_subtest(14, sub {
	make_path(qw(debian/foo));
	ok(run_dh_tool('dh_installpam'));

	ok(! -f 'debian/foo/etc/pam.d/foo');
	ok(-f 'debian/foo/usr/lib/pam.d/foo');

	ok(run_dh_tool('dh_clean'));
});
