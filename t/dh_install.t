#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib;

plan(tests => 13);

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #537140: debian/tmp is explcitly specified despite being searched by
    # default in v7+

    make_path('debian/tmp/usr/bin');
    system('touch', 'debian/tmp/usr/bin/foo', 'debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'debian/tmp/usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo", "#537140 [${compat}]");
    ok(! -e "debian/debhelper/usr/bin/bar", "#537140 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # debian/tmp explicitly specified in filenames in older compat level
    make_path('debian/tmp/usr/bin');
    system('touch', 'debian/tmp/usr/bin/foo', 'debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'debian/tmp/usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(!-e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # --sourcedir=debian/tmp in older compat level
    make_path('debian/tmp/usr/bin');
	system('touch', 'debian/tmp/usr/bin/foo', 'debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', '--sourcedir=debian/tmp', 'usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(! -e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # redundant --sourcedir=debian/tmp in v7+
    make_path('debian/tmp/usr/bin');
    system('touch', 'debian/tmp/usr/bin/foo', 'debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', '--sourcedir=debian/tmp', 'usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(! -e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_subtest {
    my ($compat) = @_;
    # #537017: --sourcedir=debian/tmp/foo is used
    make_path('debian/tmp/foo/usr/bin');
    system('touch', 'debian/tmp/foo/usr/bin/foo', 'debian/tmp/foo/usr/bin/bar');
    ok(run_dh_tool('dh_install', '--sourcedir=debian/tmp/foo', 'usr/bin/bar'));
    ok(-e "debian/debhelper/usr/bin/bar", "#537017 [${compat}]");
    ok(!-e "debian/debhelper/usr/bin/foo", "#537017 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
};

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #535367: installation of entire top-level directory from debian/tmp
    make_path('debian/tmp/usr/bin');
    system('touch', 'debian/tmp/usr/bin/foo', 'debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'usr'));
    ok(-e "debian/debhelper/usr/bin/foo", "#535367 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#535367 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #534565: fallback use of debian/tmp in v7+
    make_path('debian/tmp/usr/bin');
    system('touch', 'debian/tmp/usr/bin/foo', 'debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'usr'));
    ok(-e "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # no fallback to debian/tmp before v7
    make_path('debian/tmp/usr/bin');
    system('touch', 'debian/tmp/usr/bin/foo', 'debian/tmp/usr/bin/bar');
    ok(!run_dh_tool({ 'quiet' => 1 }, 'dh_install', 'usr'));
    ok(!-e "debian/debhelper/usr/bin/foo");
    ok(!-e "debian/debhelper/usr/bin/bar");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #534565: glob expands to dangling symlink -> should install the dangling link
    make_path('debian/tmp/usr/bin');
    make_symlink_raw_target('broken', 'debian/tmp/usr/bin/foo');
    system('touch', 'debian/tmp/usr/bin/bar');
    ok(run_dh_tool('dh_install', 'usr/bin/*'));
    ok(-l "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(!-e "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    ok(!-l "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
});

each_compat_subtest {
    my ($compat) = @_;
    # regular specification of file not in debian/tmp
    system('touch', 'dh_install');
    ok(run_dh_tool('dh_install', 'dh_install', 'usr/bin'));
    ok(-e "debian/debhelper/usr/bin/dh_install");
    remove_tree('debian/debhelper', 'debian/tmp');
};

each_compat_subtest {
    my ($compat) = @_;
    # specification of file in source directory not in debian/tmp
    make_path('bar/usr/bin');
    system('touch', 'bar/usr/bin/foo');
    ok(run_dh_tool('dh_install', '--sourcedir=bar', 'usr/bin/foo'));
    ok(-e "debian/debhelper/usr/bin/foo");
    remove_tree('debian/debhelper', 'debian/tmp');
};

each_compat_subtest {
    my ($compat) = @_;
    # specification of file in subdir, not in debian/tmp
    make_path('bar/usr/bin');
    system('touch', 'bar/usr/bin/foo');
    ok(run_dh_tool('dh_install', 'bar/usr/bin/foo'));
    ok(-e "debian/debhelper/bar/usr/bin/foo");
    remove_tree('debian/debhelper', 'debian/tmp');
};

each_compat_subtest {
    my ($compat) = @_;
    # #866570 - leading slashes must *not* pull things from the root FS.
    make_path('bin');
    system('touch', 'bin/grep-i-licious');
    ok(run_dh_tool('dh_install', '/bin/grep*'));
    ok(-e "debian/debhelper/bin/grep-i-licious", "#866570 [${compat}]");
    ok(!-e "debian/debhelper/bin/grep", "#866570 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
};

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
