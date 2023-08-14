#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Test::More tests => 6;

use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use File::Path qw(make_path);
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);
use Debian::Debhelper::Buildsystem;

chdir(dirname($0)) or die("chdir: $!");
my $TEMP_DIR = tempdir('tmp.XXXXXXX', CLEANUP => 1);
my $sourcedir = $TEMP_DIR;
my $builddir = "${TEMP_DIR}/build";
my $BS_CLASS = 'Debian::Debhelper::Buildsystem';

# Tests

do_rmdir_builddir($sourcedir, $builddir);
ok ( ! -e $builddir, "testing rmdir_builddir() 1: builddir parent '$builddir' deleted" );
ok ( -d $sourcedir, "testing rmdir_builddir() 1: sourcedir '$sourcedir' remains" );

$builddir = "$sourcedir/bld";
do_rmdir_builddir($sourcedir, "$builddir/dir");
ok ( ! -e $builddir, "testing rmdir_builddir() 2: builddir parent '$builddir' deleted" );
ok ( -d $sourcedir, "testing rmdir_builddir() 2: sourcedir '$sourcedir' remains" );

$builddir = "$sourcedir/bld";

make_path($builddir, "$builddir/dir");
create_empty_file("$builddir/afile");
create_empty_file("$builddir/dir/afile2");
do_rmdir_builddir($sourcedir, "$builddir/dir");
ok ( ! -e "$builddir/dir", "testing rmdir_builddir() 3: builddir '$builddir/dir' not empty, but deleted" );
ok ( -d $builddir, "testing rmdir_builddir() 3: builddir parent '$builddir' not empty, remains" );


### Test Buildsystem::rmdir_builddir()
sub do_rmdir_builddir {
	my ($sourcedir, $builddir) = @_;
	my $system;
	$system = $BS_CLASS->new(builddir => $builddir, sourcedir => $sourcedir);
	$system->mkdir_builddir();
	$system->rmdir_builddir();
}

