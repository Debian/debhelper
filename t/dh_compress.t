#!/usr/bin/perl

use strict;
use warnings;
use File::Basename qw(dirname);
use lib dirname(__FILE__).'/..';
use File::Path qw(make_path remove_tree);
use Test::More;

chdir dirname(__FILE__).'/..';
$ENV{PERL5OPT} = '-I'.dirname(__FILE__).'/..';
my $PREFIX = 'debian/debhelper/usr/share/doc/debhelper';

# we are testing compressing doc txt files
# foo.txt is 2k and bar.txt is 5k
mk_test_dir();

# default operation, bar.txt becomes bar.txt.gz and foo.txt is unchanged
dh_compress();

is_deeply(
    [map { s{${PREFIX}/}{}; $_ } sort glob "$PREFIX/*"],
    [qw|bar.txt.gz foo.txt|],
    '5k txt doc compressed, 2k txt doc not compressed'
);

mk_test_dir();

# now if I want to pass both on the command line to dh_compress, it should
# compress both
dh_compress(qw|
    --
    usr/share/doc/debhelper/foo.txt
    usr/share/doc/debhelper/bar.txt
|);

is_deeply(
    [map { s{${PREFIX}/}{}; $_ } sort glob "$PREFIX/*"],
    [qw|bar.txt.gz foo.txt.gz|],
    'both 5k and 2k txt docs compressed'
);

mk_test_dir();

# absolute paths should also work
dh_compress(qw|
    --
    /usr/share/doc/debhelper/foo.txt
    /usr/share/doc/debhelper/bar.txt
|);

is_deeply(
    [map { s{${PREFIX}/}{}; $_ } sort glob "$PREFIX/*"],
    [qw|bar.txt.gz foo.txt.gz|],
    'both 5k and 2k txt docs compressed by absolute path args'
);

rm_test_dir();

done_testing;

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

    unlink 'debian/debhelper.debhelper.log'; # ignore error, it may not exist
}

sub dh_compress {
    system('./dh_compress', @_) == 0
	or fail("Could not run ./dh_compress @_: $?");
}
