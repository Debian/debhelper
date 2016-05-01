#!/usr/bin/perl
# This may appear arbitrary, but DO NOT CHANGE IT.
# Debhelper is supposed to consist of small, simple, easy to understand
# programs. Programs growing in size and complexity without bounds is a
# bug.
use strict;
use warnings;
use Test::More;

my @progs=grep { -x $_ } glob("dh_*");

plan(tests => (@progs + @progs));

foreach my $file (@progs) {

	my $lines=0;
	my $maxlength=0;
	open(my $fd, '<', $file) || die "open($file): $!";
	my $cutting=0;
	while (<$fd>) {
		$cutting=1 if /^=/;
		$cutting=0 if /^=cut/;
		next if $cutting || /^(?:=|\s*(?:\#.*)?$)/;
		$lines++;
		$maxlength=length($_) if length($_) > $maxlength;
	}
	close($fd);
	print "# $file has $lines lines, max length is $maxlength\n";
	ok($lines < 200, $file);
	ok($maxlength < 160, $file);
}

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
