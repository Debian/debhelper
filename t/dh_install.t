#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Test::DH;

plan(tests => 13);

system("rm -rf debian/debhelper debian/tmp");

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #537140: debian/tmp is explcitly specified despite being searched by
    # default in v7+
    system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install debian/tmp/usr/bin/foo 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/foo", "#537140 [${compat}]");
    ok(! -e "debian/debhelper/usr/bin/bar", "#537140 [${compat}]");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # debian/tmp explicitly specified in filenames in older compat level
    system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install debian/tmp/usr/bin/foo 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(!-e "debian/debhelper/usr/bin/bar");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # --sourcedir=debian/tmp in older compat level
    system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install --sourcedir=debian/tmp usr/bin/foo 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(! -e "debian/debhelper/usr/bin/bar");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # redundant --sourcedir=debian/tmp in v7+
    system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install --sourcedir=debian/tmp usr/bin/foo 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/foo");
    ok(! -e "debian/debhelper/usr/bin/bar");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_subtest {
    my ($compat) = @_;
    # #537017: --sourcedir=debian/tmp/foo is used
    system("mkdir -p debian/tmp/foo/usr/bin; touch debian/tmp/foo/usr/bin/foo; touch debian/tmp/foo/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install --sourcedir=debian/tmp/foo usr/bin/bar 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/bar", "#537017 [${compat}]");
    ok(!-e "debian/debhelper/usr/bin/foo", "#537017 [${compat}]");
    system("rm -rf debian/debhelper debian/tmp");
};

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #535367: installation of entire top-level directory from debian/tmp
    system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install usr 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/foo", "#535367 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#535367 [${compat}]");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #534565: fallback use of debian/tmp in v7+
    system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install usr/bin 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_up_to_and_incl_subtest(6, sub {
    my ($compat) = @_;
    # no fallback to debian/tmp before v7
    system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install usr/bin 2>/dev/null");
    ok(!-e "debian/debhelper/usr/bin/foo");
    ok(!-e "debian/debhelper/usr/bin/bar");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_from_and_above_subtest(7, sub {
    my ($compat) = @_;
    # #534565: glob expands to dangling symlink -> should install the dangling link
    system("mkdir -p debian/tmp/usr/bin; ln -s broken debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
    system("DH_COMPAT=${compat} dh_install 'usr/bin/*' 2>/dev/null");
    ok(-l "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(!-e "debian/debhelper/usr/bin/foo", "#534565 [${compat}]");
    ok(-e "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    ok(!-l "debian/debhelper/usr/bin/bar", "#534565 [${compat}]");
    system("rm -rf debian/debhelper debian/tmp");
});

each_compat_subtest {
    my ($compat) = @_;
    # regular specification of file not in debian/tmp
    system("DH_COMPAT=${compat} dh_install dh_install usr/bin 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/dh_install");
    system("rm -rf debian/debhelper debian/tmp");
};

each_compat_subtest {
    my ($compat) = @_;
    # specification of file in source directory not in debian/tmp
    system("mkdir -p bar/usr/bin; touch bar/usr/bin/foo");
    system("DH_COMPAT=${compat} dh_install --sourcedir=bar usr/bin/foo 2>/dev/null");
    ok(-e "debian/debhelper/usr/bin/foo");
    system("rm -rf debian/debhelper bar");
};

each_compat_subtest {
    my ($compat) = @_;
    # specification of file in subdir, not in debian/tmp
    system("mkdir -p bar/usr/bin; touch bar/usr/bin/foo");
    system("DH_COMPAT=${compat} dh_install bar/usr/bin/foo 2>/dev/null");
    ok(-e "debian/debhelper/bar/usr/bin/foo");
    system("rm -rf debian/debhelper bar");
};

each_compat_subtest {
    my ($compat) = @_;
    # #866570 - leading slashes must *not* pull things from the root FS.
    system("mkdir -p bin; touch bin/grep-i-licious");
    system("DH_COMPAT=${compat} dh_install '/bin/grep*' 2>/dev/null");
    ok(-e "debian/debhelper/bin/grep-i-licious", "#866570 [${compat}]");
    ok(!-e "debian/debhelper/bin/grep", "#866570 [${compat}]");
    system("rm -rf debian/debhelper bin");
};

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
