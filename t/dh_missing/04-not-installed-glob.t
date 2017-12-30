#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);

our $TEST_DH_FIXTURE_DIR = 'template';
our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.install
    file-for-foo
    Makefile
));

plan(tests => 1);

each_compat_subtest {
	rm_files('debian/not-installed');
	open(my $fd, '>', 'debian/not-installed') or error("open(d/not-installed): $!");
	# Non-glob match
	print {$fd} "usr/bin/file-for-foo\n";
	# Glob match (note that it must not match the above)
	print {$fd} "usr/bin/file-for-foo-*\n";
	# Non-matches (silently ignored)
	print {$fd} "usr/bin/does-not-exist\n";
	print {$fd} "usr/bin/does-not-exist-*\n";
	close($fd) or error("close(d/not-installed: $!");
	ok(run_dh_tool('dh_clean'));
	is(system('make', 'installmore'), 0);
	ok(run_dh_tool('dh_missing', '--fail-missing'));
};

