#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 6);


each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # debian/tmp explicitly specified in filenames in older compat level
    make_path('debian/tmp/usr/bin');
    create_empty_file('debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'debian/tmp/usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(!-e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # --sourcedir=debian/tmp in older compat level
    make_path('debian/tmp/usr/bin');
    create_empty_file('debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', '--sourcedir=debian/tmp', 'usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(! -e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # redundant --sourcedir=debian/tmp in v7+
    make_path('debian/tmp/usr/bin');
    create_empty_file('debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', '--sourcedir=debian/tmp', 'usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(! -e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #534565: fallback use of debian/tmp in v7+
    make_path('debian/tmp/usr/bin');
    create_empty_file('debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'usr'));
    ok(-e "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # no fallback to debian/tmp before v7
    make_path('debian/tmp/usr/bin');
    create_empty_file('debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(!run_dh_tool({ 'quiet' => 1 }, 'dh_install', 'usr'));
    ok(!-e "debian/debhelper/usr/bin/foo");
    ok(!-e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});


each_compat_subtest {
    my ($compat) = @_;
    # specification of file in source directory not in debian/tmp
    make_path('bar/usr/bin');
    create_empty_file('bar/usr/bin/foo');
    ok(run_dh_tool('dh_install', '--sourcedir=bar', 'usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    remove_tree('debian/debhelper', 'debian/tmp');
};
