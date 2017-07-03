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
    # #866570 - leading slashes must *not* pull things from the root FS.
    make_path('bin');
    create_empty_file('bin/grep-i-licious');
    ok(run_dh_tool('dh_install', '/bin/grep*'));
    ok(-e "debian/debhelper/bin/grep-i-licious", "#866570 [${compat}]");
    ok(!-e "debian/debhelper/bin/grep", "#866570 [${compat}]");
    remove_tree('debian/debhelper', 'debian/tmp');
};

