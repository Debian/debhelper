#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
plan(tests => 1);

use File::Path qw(remove_tree);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;

each_compat_subtest {

	remove_tree('debian/debhelper');

	# Check links to the current directory and below, they used to be
	# unnecessarily long (#346405).
	ok(run_dh_tool('dh_link', 'usr/lib/geant4', 'usr/lib/geant4/a'));
	ok(readlink("debian/debhelper/usr/lib/geant4/a"), ".");
	ok(run_dh_tool('dh_link', 'usr/lib', 'usr/lib/geant4/b'));
	ok(readlink("debian/debhelper/usr/lib/geant4/b"), "..");
	ok(run_dh_tool('dh_link', 'usr', 'usr/lib/geant4/c'));
	ok(readlink("debian/debhelper/usr/lib/geant4/c"), "../..");
	ok(run_dh_tool('dh_link', '/', 'usr/lib/geant4/d'));
	ok(readlink("debian/debhelper/usr/lib/geant4/d"), "/");
};

