#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Test::DH;

use File::Path qw(make_path remove_tree);
use Test::More;
use Debian::Debhelper::Dh_Lib;

my $PREFIX = 'debian/debhelper/usr/share/doc/debhelper';

plan tests => 1;

each_compat_subtest {
    # we are testing compressing doc txt files
    # foo.txt is 2k and bar.txt is 5k
    mk_test_dir();

    # default operation, bar.txt becomes bar.txt.gz and foo.txt is
    # unchanged
    ok(run_dh_tool('dh_compress'));

    is_deeply(
        [map { s{${PREFIX}/}{}; $_ } sort glob "$PREFIX/*"],
        [qw|bar.txt.gz foo.txt|],
        '5k txt doc compressed, 2k txt doc not compressed'
    );

    mk_test_dir();

    # now if I want to pass both on the command line to dh_compress,
    # it should compress both
    ok(run_dh_tool('dh_compress', '--',
                   'usr/share/doc/debhelper/foo.txt',
                   'usr/share/doc/debhelper/bar.txt'));

    is_deeply(
        [map { s{${PREFIX}/}{}; $_ } sort glob "$PREFIX/*"],
        [qw|bar.txt.gz foo.txt.gz|],
        'both 5k and 2k txt docs compressed'
    );

    mk_test_dir();

    # absolute paths should also work
    ok(run_dh_tool('dh_compress', '--',
                   '/usr/share/doc/debhelper/foo.txt',
                   '/usr/share/doc/debhelper/bar.txt'));

    is_deeply(
        [map { s{${PREFIX}/}{}; $_ } sort glob "$PREFIX/*"],
        [qw|bar.txt.gz foo.txt.gz|],
        'both 5k and 2k txt docs compressed by absolute path args'
    );

    rm_test_dir();
};


sub mk_test_dir {
    rm_test_dir();

    make_path('debian/debhelper/usr/share/doc/debhelper');

    my $fh;

    # write 2k to foo.txt
    open $fh, '>', 'debian/debhelper/usr/share/doc/debhelper/foo.txt'
	or die "Could not write to debian/debhelper/usr/share/doc/debhelper/foo.txt: $!";
    print $fh 'X' x 2048;
    close $fh
	or die "Could not write to debian/debhelper/usr/share/doc/debhelper/bar.txt: $!";

    # write 5k to bar.txt
    open $fh, '>', 'debian/debhelper/usr/share/doc/debhelper/bar.txt'
	or die "Could not write to debian/debhelper/usr/share/doc/debhelper/bar.txt: $!";
    print $fh 'X' x 5120;
    close $fh
	or die "Could not write to debian/debhelper/usr/share/doc/debhelper/bar.txt: $!";
}

sub rm_test_dir {
    remove_tree('debian/debhelper');

    rm_files('debian/debhelper.debhelper.log');
}

