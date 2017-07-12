#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Test::More tests => 3;

use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);
use Debian::Debhelper::Buildsystem;

my $DIR = dirname($0);
my $SCRIPT = './load-bs.pl'; # relative to $DIR
my $BS_CWD = Cwd::realpath($DIR) or error("cannot resolve ${DIR}: $!");
my $BS_CLASS = 'Debian::Debhelper::Buildsystem';
my $bs = $BS_CLASS->new();
my $default_builddir = $bs->DEFAULT_BUILD_DIRECTORY();
delete($ENV{'TEST_DH_SYSTEM'});
delete($ENV{'TEST_DH_STEP'});

# NOTE: disabling parallel building explicitly (it might get automatically
# enabled if run under dpkg-buildpackage -jX) to make output deterministic.
is_deeply( try_load_bs(undef, 'configure', '--builddirectory=autoconf/bld dir', '--sourcedirectory',
                       'autoconf', '--max-parallel=1'),
    [ 'NAME=autoconf', 'builddir=autoconf/bld dir', "cwd=$BS_CWD",  'makecmd=make', 'parallel=1', 'sourcedir=autoconf' ],
    "autoconf autoselection and sourcedir/builddir" );

is_deeply( try_load_bs('autoconf', 'build', '-Sautoconf', '-D', 'autoconf', '--max-parallel=1'),
    [ 'NAME=autoconf', 'builddir=undef', "cwd=$BS_CWD", 'makecmd=make', 'parallel=1', 'sourcedir=autoconf' ],
    "forced autoconf and sourcedir" );

is_deeply( try_load_bs('autoconf', 'build', '-B', '-Sautoconf', '--max-parallel=1'),
    [ 'NAME=autoconf', "builddir=$default_builddir", "cwd=$BS_CWD", 'makecmd=make', 'parallel=1', 'sourcedir=.' ],
    "forced autoconf and default build directory" );

sub try_load_bs {
    my ($system, $step, @params) = @_;
    my @lines;
    my $pid = open(my $fd, '-|') // die("fork: $!");

    if (not $pid) {
        chdir($DIR) or die("chdir($DIR): $!");
        $ENV{'TEST_DH_SYSTEM'} = $system if defined($system);
        $ENV{'TEST_DH_STEP'} = $step if defined($step);
        exec($^X, $SCRIPT, @params);
    }
    @lines = map { chomp; $_ } <$fd>;
    close($fd); # Ignore error
    return \@lines;
}

