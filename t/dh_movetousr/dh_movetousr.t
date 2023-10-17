#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(make_symlink_raw_target);

plan(tests => 1);

each_compat_subtest {
	my ($compat) = @_;
	make_path('debian/debhelper/lib/foo');
	make_path('debian/debhelper/lib/bar');
	make_path('debian/debhelper/usr/lib/bar');
	make_path('debian/debhelper/sbin');
	create_empty_file('debian/debhelper/lib/foo/bar');
	create_empty_file('debian/debhelper/lib/bar/foo');
	create_empty_file('debian/debhelper/usr/lib/bar/bar');
	make_symlink_raw_target('/foo', 'debian/debhelper/lib/foo/abs1');
	make_symlink_raw_target('/sbin/foo', 'debian/debhelper/lib/foo/abs2');
	make_symlink_raw_target('bar', 'debian/debhelper/lib/foo/rel1');
	make_symlink_raw_target('../bar', 'debian/debhelper/lib/foo/rel2');
	make_symlink_raw_target('../../bar', 'debian/debhelper/lib/foo/rel3');
	make_symlink_raw_target('../../../bar', 'debian/debhelper/lib/foo/rel4');
	make_symlink_raw_target('/usr/bin/bar', 'debian/debhelper/sbin/foo');
	ok(run_dh_tool('dh_movetousr', '--fail-noop'));
	# Files get moved.
	ok(! -e 'debian/debhelper/lib');
	ok(! -e 'debian/debhelper/sbin');
	ok(-d 'debian/debhelper/usr/lib/foo');
	ok(-d 'debian/debhelper/usr/lib/bar');
	ok(-d 'debian/debhelper/usr/sbin');
	# Preexisting file is not clobbered.
	ok(-e 'debian/debhelper/usr/lib/bar/bar');
	# Other entry is moved.
	ok(-e 'debian/debhelper/usr/lib/bar/foo');
	# Absolute link is moved as absolute.
	ok(-l 'debian/debhelper/usr/lib/foo/abs1');
	ok(readlink('debian/debhelper/usr/lib/foo/abs1') eq '/foo');
	# ... unless the target is aliased.
	ok (-l 'debian/debhelper/usr/lib/foo/abs2');
	ok(readlink('debian/debhelper/usr/lib/foo/abs2') eq '../../sbin/foo');
	# A contained relative symlink shall remain relative.
	ok(-l 'debian/debhelper/usr/lib/foo/rel1');
	ok(readlink('debian/debhelper/usr/lib/foo/rel1') eq 'bar');
	# A relative symlink not crossing / shall remain relative.
	ok(-l 'debian/debhelper/usr/lib/foo/rel2');
	ok(readlink('debian/debhelper/usr/lib/foo/rel2') eq '../bar');
	# A relative symlink hitting / shall become absolute.
	ok(-l 'debian/debhelper/usr/lib/foo/rel3');
	ok(readlink('debian/debhelper/usr/lib/foo/rel3') eq '/bar');
	# A relative symlink going through /.. shall also become absolute.
	ok(-l 'debian/debhelper/usr/lib/foo/rel4');
	ok(readlink('debian/debhelper/usr/lib/foo/rel4') eq '/bar');
	# An absolute link pointing into /usr has to become relative due to
	# policy 10.5.
	ok(-l 'debian/debhelper/usr/sbin/foo');
	ok(readlink('debian/debhelper/usr/sbin/foo') eq '../bin/bar');
	ok(!run_dh_tool({ quiet => 1 }, 'dh_movetousr', '--fail-noop'));
	ok(run_dh_tool('dh_movetousr'));
	remove_tree('debian/debhelper');
};
