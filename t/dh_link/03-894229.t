#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
plan(tests => 1);

use File::Path qw(remove_tree);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Debian::Debhelper::Dh_Lib qw(!dirname);
use Test::DH;


sub test_tricky {
    my ($link_name, $denoted_dest, $expected_link_target) = @_;
    my $tmpdir = 'debian/debhelper';
    my $link_path = "${tmpdir}/${link_name}";

    make_symlink($link_name, $denoted_dest, $tmpdir);
    if (ok(-l $link_path, 'Link made in correct directory')) {
        my $target = readlink($link_path);
        is($target, $expected_link_target, 'Link points correctly')
            or diag("Expected ${expected_link_target}, actual ${target}");
        rm_files($link_path);
    }
    return;
}

sub test_invalid {
    my ($link_name, $denoted_dest) = @_;
    eval {
        make_symlink($link_name, $denoted_dest);
    };
    like($@, qr{^(?:\S*:\s*)?Invalid destination/link name});
}

each_compat_subtest {

    remove_tree('debian/debhelper/a/b/c');

    install_dir('debian/debhelper/a/b/c');

    test_invalid('../../wow', 'a');
    # This is a can be made valid but at the moment we do not support
    # it.
    test_invalid('a/b/../link21', 'a');


    test_tricky('//a/b/link03', 'a/b/c', 'c');
    test_tricky('./a/link18', 'a', '.');
    test_tricky('a/./b/link19', 'a/b', '.');
};

