#!/usr/bin/perl
use Test;

my @progs=grep { -x $_ } glob("dh_*"), "dh";
my @libs=(glob("Debian/Debhelper/*.pm"), glob("Debian/Debhelper/*/*.pm"));

plan(tests => (@progs + @libs));

foreach my $file (@progs, @libs) {
	print "# Testing $file\n";
	ok(system("perl -c $file >/dev/null 2>&1"), 0)
	  or print STDERR "# Testing $file is broken\n";
}

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
