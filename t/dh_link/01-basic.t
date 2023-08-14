#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
plan(tests => 1);

use File::Path qw(remove_tree);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;

each_compat_subtest {

	remove_tree('debian/debhelper');

	# It used to not make absolute links in this situation, and it should.
	# #37774
	ok(run_dh_tool('dh_link', 'etc/foo', 'usr/lib/bar'));
	ok(readlink("debian/debhelper/usr/lib/bar"), "/etc/foo");


	# let's make sure it makes simple relative links ok.
	ok(run_dh_tool('dh_link', 'usr/bin/foo', 'usr/bin/bar'));
	ok(readlink("debian/debhelper/usr/bin/bar"), "foo");
	ok(run_dh_tool('dh_link', 'sbin/foo', 'sbin/bar'));
	ok(readlink("debian/debhelper/sbin/bar"), "foo");

	# ok, more complex relative links.
	ok(run_dh_tool('dh_link', 'usr/lib/1', 'usr/bin/2'));
	ok(readlink("debian/debhelper/usr/bin/2"),"../lib/1");

	# Check conversion of relative symlink to different top-level directory
	# into absolute symlink. (#244157)
	system("mkdir -p debian/debhelper/usr/lib; mkdir -p debian/debhelper/lib; touch debian/debhelper/lib/libm.so; cd debian/debhelper/usr/lib; ln -sf ../../lib/libm.so");
	ok(run_dh_tool('dh_link'));
	ok(readlink("debian/debhelper/usr/lib/libm.so"), "/lib/libm.so");

	# Link to self.
	ok(run_dh_tool({ 'quiet' => 1 }, 'dh_link', 'usr/lib/foo', 'usr/lib/foo'));
	ok(! -l "debian/debhelper/usr/lib/foo");

	# Make sure the link conversion didn't change any of the
	# previously made links.
	ok(readlink("debian/debhelper/usr/lib/bar"), "/etc/foo");
	ok(readlink("debian/debhelper/usr/bin/bar"), "foo");
	ok(readlink("debian/debhelper/usr/bin/2"),"../lib/1");
};

