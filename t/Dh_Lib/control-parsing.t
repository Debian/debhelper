#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Cwd qw(abs_path);
use File::Basename qw(dirname);

BEGIN {
	my $dir = dirname(abs_path(__FILE__));
	unshift(@INC, dirname($dir));
	chdir($dir) or error("chdir($dir) failed: $!");
};

use Test::DH;

use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 10);

is_deeply([getpackages()], [qw(foo-any foo-all)], 'packages list correct and in order');
is_deeply([getpackages('both')], [qw(foo-any foo-all)], 'packages list correct and in order');
is_deeply([getpackages('arch')], [qw(foo-any)], 'arch:linux-any');
is_deeply([getpackages('indep')], [qw(foo-all)], 'arch:all');


is(package_section('foo-any'), 'devel', 'binary section');
is(package_section('foo-all'), 'misc', 'binary section (inherit from source)');

	
is(package_declared_arch('foo-any'), 'linux-any', 'binary architecture (linux-any');
is(package_declared_arch('foo-all'), 'all', 'binary architecture (all)');

ok(! package_is_arch_all('foo-any'), 'foo-any is not arch:all');
ok(package_is_arch_all('foo-all'), 'foo-all is arch:all');
