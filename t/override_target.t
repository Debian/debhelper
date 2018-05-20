#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
plan(tests => 1);

# This test is here to detect breakage in
# dh's rules_explicit_target, which parses
# slightly internal make output.
system("mkdir -p t/tmp/debian");
system("cp debian/control debian/compat debian/changelog t/tmp/debian");
open (OUT, ">", "t/tmp/debian/rules") || die "$!";
my $binpath = $ENV{AUTOPKGTEST_TMP} ? '/usr/bin' : '../..';
print OUT <<EOF;
#!/usr/bin/make -f
%:
	PATH=../..:\$\$PATH PERL5LIB=../../lib $binpath/dh \$@ --without autoreconf

override_dh_update_autotools_config override_dh_strip_nondeterminism:

override_dh_auto_build:
	echo "override called"
EOF
close OUT;
system("chmod +x t/tmp/debian/rules");
my @output=`cd t/tmp && debian/rules build 2>&1`;
ok(grep { m/override called/ } @output) or do {
	diag($_) for @output;
};
system("rm -rf t/tmp");
