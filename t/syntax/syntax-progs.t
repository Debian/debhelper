#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
# Need Test::More to set PERL5LIB
use Test::DH;

my @targets;
if ($0 =~ m{syntax-progs\.t$}) {
	@targets = grep { -x $_ } glob("dh_*"), "dh";
} else {
	@targets = (glob("Debian/Debhelper/*.pm"), glob("Debian/Debhelper/*/*.pm"));
}

plan(tests => scalar(@targets));

foreach my $file (@targets) {
	is(system("perl -c $file >/dev/null 2>&1"), 0)
	  or diag("$file failed syntax check");
}

