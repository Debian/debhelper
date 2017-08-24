#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
# Need Test::More to set PERL5LIB
use Test::DH;

use Config;
my $binpath = $ENV{AUTOPKGTEST_TMP} ? '/usr/bin' : '.';
my $libpath = $ENV{AUTOPKGTEST_TMP} ? $Config{vendorlib} : 'lib';

my @targets;
if ($0 =~ m{syntax-progs\.t$}) {
	@targets = grep { -x $_ } glob("$binpath/dh_*"), "$binpath/dh";
} else {
	@targets = (glob("$libpath/Debian/Debhelper/*.pm"), glob("$libpath/Debian/Debhelper/*/*.pm"));
}

plan(tests => scalar(@targets));

foreach my $file (@targets) {
	is(system("perl -c $file >/dev/null 2>&1"), 0)
	  or diag("$file failed syntax check");
}

