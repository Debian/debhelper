#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 1);

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    manpage-uncompressed.pod
    manpage-compressed.pod
));

each_compat_subtest {
    my ($compat) = @_;
	if (! -d 'generated-manpages') {
		# Static data that can be reused.  Generate only in the first test
		make_path('generated-manpages');
		for my $basename (qw(manpage-uncompressed manpage-compressed)) {
			doit('pod2man', '--utf8', '-c', 'Debhelper', '-r', '1.0', "${basename}.pod",
				 "generated-manpages/${basename}.1");
		}
		doit('gzip', '-9n', 'generated-manpages/manpage-compressed.1');
	}
    ok(run_dh_tool('dh_installman', 'generated-manpages/manpage-uncompressed.1',
				   'generated-manpages/manpage-compressed.1.gz'));
    ok(-e 'debian/debhelper/usr/share/man/man1/manpage-uncompressed.1');
    ok(-e 'debian/debhelper/usr/share/man/man1/manpage-compressed.1');
    remove_tree('debian/debhelper', 'debian/tmp', 'debian/.debhelper');
};

