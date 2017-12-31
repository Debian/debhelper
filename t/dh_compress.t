#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Test::DH;

use File::Path qw(make_path remove_tree);
use Test::More;
use Debian::Debhelper::Dh_Lib qw(!dirname);

my $PREFIX = 'debian/debhelper/usr/share/doc/debhelper';

plan tests => 2;

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

	mk_test_dir();

	is(system('cp', '-la', "${PREFIX}/bar.txt", "${PREFIX}/hardlink.txt"), 0,
	   'create hardlink');

	ok(run_dh_tool('dh_compress'));

    is_deeply(
        [map { s{${PREFIX}/}{}; $_ } sort glob "$PREFIX/*"],
        [qw|bar.txt.gz foo.txt hardlink.txt.gz|],
        'the 5k and its hardlink txt docs compressed'
    );

	# Verify that the hardlink is preserved.
	my ($dev1, $inode1) = stat("${PREFIX}/bar.txt.gz") // error("stat ${PREFIX}/bar.txt.gz: $!");
	my ($dev2, $inode2) = stat("${PREFIX}/hardlink.txt.gz") // error("stat ${PREFIX}/hardlink.txt.gz: $!");

	is($dev1, $dev2, 'Still hardlinked');
	is($inode1, $inode2, 'Still hardlinked');

	rm_test_dir();
};

each_compat_from_and_above_subtest(12, sub {
	make_path("${PREFIX}/examples");
	create_file_of_size("${PREFIX}/examples/foo.py", 5120);
	ok(run_dh_tool('dh_compress'));
	ok(-f "${PREFIX}/examples/foo.py", "${PREFIX}/examples/foo.py is not compressed");
	ok(! -f "${PREFIX}/examples/foo.py.gz", "${PREFIX}/examples/foo.py is not compressed");
});

sub create_file_of_size {
	my ($filename, $size) = @_;
	open(my $fh, '>', $filename) or error("open($filename) failed: $!");
	print {$fh} 'X' x $size;
	close($fh) or error("close($filename) failed: $!");
}

sub mk_test_dir {
    rm_test_dir();

	make_path($PREFIX);

	create_file_of_size("${PREFIX}/foo.txt", 2048);
	create_file_of_size("${PREFIX}/bar.txt", 5120);
}

sub rm_test_dir {
    remove_tree('debian/debhelper');

    rm_files('debian/debhelper.debhelper.log');
}

