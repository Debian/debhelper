#!/usr/bin/perl

use strict;
use warnings;
use Debian::Debhelper::Dh_Buildsystems;

buildsystems_init();
my $system = $ENV{'TEST_DH_SYSTEM'};
my $step = $ENV{'TEST_DH_STEP'};
my $bs = load_buildsystem($system, $step);
if (defined $bs) {
	print 'NAME=', $bs->NAME(), "\n";
	print $_, "=", (defined $bs->{$_}) ? $bs->{$_} : 'undef', "\n"
	    foreach (sort keys %$bs);
}

