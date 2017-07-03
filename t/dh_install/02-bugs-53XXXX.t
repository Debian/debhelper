#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 4);

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #537140: debian/tmp is explcitly specified despite being searched by
    # default in v7+

    make_path('debian/tmp/usr/bin');
    create_empty_file('debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'debian/tmp/usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo", "#537140 [${compat}]");
    ok(! -e "debian/debhelper/usr/bin/bar", "#537140 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #534565: glob expands to dangling symlink -> should install the dangling link
    make_path('debian/tmp/usr/bin');
    make_symlink_raw_target('broken', 'debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'usr/bin/*'));
    ok(-l "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(!-e "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    ok(!-l "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_subtest {
    my ($compat) = @_;
    # #537017: --sourcedir=debian/tmp/foo is used
    make_path('debian/tmp/foo/usr/bin');
    create_empty_file('debian/tmp/foo/usr/bin/foo');
    create_empty_file('debian/tmp/foo/usr/bin/bar');
    ok(run_dh_tool('dh_install', '--sourcedir=debian/tmp/foo', 'usr/bin/bar'));
    ok(-e "debian/debhelper/usr/bin/bar", "#537017 [${compat}]");
    ok(!-e "debian/debhelper/usr/bin/foo", "#537017 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
};

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #535367: installation of entire top-level directory from debian/tmp
    make_path('debian/tmp/usr/bin');
    create_empty_file('debian/tmp/usr/bin/foo');
    create_empty_file('debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'usr'));
    ok(-e "debian/debhelper/usr/bin/foo", "#535367 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#535367 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

