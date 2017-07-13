#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 1);

each_compat_subtest {
	my ($compat) = @_;
	# #868204 - dh_installdocs did not replace dangling symlink
	make_path('debian/debhelper/usr/share/doc/debhelper');
	make_symlink_raw_target('../to/nowhere/bar',
							'debian/debhelper/usr/share/doc/debhelper/README.Debian');
	create_empty_file('debian/README.Debian');

	ok(-l 'debian/debhelper/usr/share/doc/debhelper/README.Debian');
	ok(!-e 'debian/debhelper/usr/share/doc/debhelper/README.Debian');

	ok(run_dh_tool('dh_installdocs'));
	ok(!-l 'debian/debhelper/usr/share/doc/debhelper/README.Debian', "#868204 [${compat}]");
	ok(-f 'debian/debhelper/usr/share/doc/debhelper/README.Debian', "#868204 [${compat}]");
	remove_tree('debian/debhelper', 'debian/tmp');
};

