#!/usr/bin/perl
use strict;
use warnings;
use Test::More;


use File::Path qw(remove_tree);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/docfile
    debian/copyright
));

plan(tests => 5);


my $NODOC_PROFILE = {
	'env' => {
		'DEB_BUILD_PROFILES' => 'nodoc',
	},
};

my $doc = "debian/docfile";

each_compat_subtest {
	ok(run_dh_tool('dh_installdocs', '-pbar', $doc));
	ok(-e "debian/bar/usr/share/doc/bar/docfile");
	remove_tree(qw(debian/foo debian/bar debian/baz));
};

each_compat_subtest {
	#regression in debhelper 9.20160702 (#830309)
	ok(run_dh_tool('dh_installdocs', '-pbaz', '--link-doc=foo', $doc));

	ok(-l "debian/baz/usr/share/doc/baz");
	ok(readlink("debian/baz/usr/share/doc/baz") eq 'foo');
	ok(-e "debian/baz/usr/share/doc/foo/docfile");
	remove_tree(qw(debian/foo debian/bar debian/baz));
};

each_compat_subtest {
	ok(run_dh_tool('dh_installdocs', '-pfoo', '--link-doc=bar', $doc));

	ok(-l "debian/foo/usr/share/doc/foo");
	ok(readlink("debian/foo/usr/share/doc/foo") eq 'bar');
	ok(-e "debian/foo/usr/share/doc/bar/docfile");
	remove_tree(qw(debian/foo debian/bar debian/baz));
};

# ... and with nodoc

each_compat_subtest {
	# docs are ignored, but copyright file is still there
	ok(run_dh_tool($NODOC_PROFILE, 'dh_installdocs', $doc));
	for my $pkg (qw(foo bar baz)) {
		ok(! -e "debian/$pkg/usr/share/doc/$pkg/docfile");
		ok(-e "debian/$pkg/usr/share/doc/$pkg/copyright");
	}
	remove_tree(qw(debian/foo debian/bar debian/baz));
};

each_compat_subtest {
	# docs are ignored, but symlinked doc dir is still there
	ok(run_dh_tool($NODOC_PROFILE, 'dh_installdocs', '-pfoo', '--link-doc=bar',  $doc));
	ok(-l "debian/foo/usr/share/doc/foo");
	ok(readlink("debian/foo/usr/share/doc/foo") eq 'bar');
	ok(! -e "debian/foo/usr/share/doc/bar/docfile");
	remove_tree(qw(debian/foo debian/bar debian/baz));
};

