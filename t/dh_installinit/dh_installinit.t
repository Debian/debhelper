#!/usr/bin/perl
use strict;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.service
));

plan(tests => 2);

each_compat_up_to_and_incl_subtest(10, sub {
	make_path(qw(debian/foo debian/bar debian/baz));
	ok(run_dh_tool('dh_installinit'));
	ok(-e "debian/foo/lib/systemd/system/foo.service");
	ok(find_script('foo', 'postinst'));
	ok(run_dh_tool('dh_clean'));

});

each_compat_from_and_above_subtest(11, sub {
	make_path(qw(debian/foo debian/bar debian/baz));

	ok(run_dh_tool('dh_installinit'));
	ok(! -e "debian/foo/lib/systemd/system/foo.service");
	ok(!find_script('foo', 'postinst'));
	ok(run_dh_tool('dh_clean'));

	make_path(qw(debian/foo/lib/systemd/system/ debian/bar debian/baz));
	install_file('debian/foo.service', 'debian/foo/lib/systemd/system/foo.service');
	ok(run_dh_tool('dh_installinit'));
	ok(!find_script('foo', 'postinst'));
	ok(run_dh_tool('dh_clean'));
});

