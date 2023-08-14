#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 2);


each_compat_subtest {
    my ($compat) = @_;
    # regular specification of file not in debian/tmp
    create_empty_file('dh_install');
    ok(run_dh_tool('dh_install', 'dh_install', 'usr/bin'));
    ok(-e "debian/debhelper/usr/bin/dh_install");
    remove_tree('debian/debhelper', 'debian/tmp');
};

each_compat_subtest {
    my ($compat) = @_;
    # specification of file in subdir, not in debian/tmp
    make_path('bar/usr/bin');
    create_empty_file('bar/usr/bin/foo');
    ok(run_dh_tool('dh_install', 'bar/usr/bin/foo'));
    ok(-e "debian/debhelper/bar/usr/bin/foo");
    remove_tree('debian/debhelper', 'debian/tmp');
};

