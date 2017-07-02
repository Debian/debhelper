#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(__FILE__);
# Need Test::More to set PERL5LIB
use Test::DH;

my @progs=grep { -x $_ } glob("dh_*"), "dh";
my @libs=(glob("Debian/Debhelper/*.pm"), glob("Debian/Debhelper/*/*.pm"));

plan(tests => (@progs + @libs));

foreach my $file (@progs, @libs) {
	is(system("perl -c $file >/dev/null 2>&1"), 0)
	  or diag("$file failed syntax check");
}

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
