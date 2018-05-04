#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use lib dirname(dirname(__FILE__));
use Test::DH;

use Debian::Debhelper::Dh_Lib qw(!dirname);

my $TEST_DIR = dirname(__FILE__);

sub test_build_depends {
	my ($level, $build_depends) = @_;
	my $dir = tempdir(CLEANUP => 1);
	if (not mkdir("$dir/debian", 0777)) {
			error("mkdir $dir/debian failed: $!");
	}
	open my $in, '<', "$TEST_DIR/debian/control" or
	    error("open $TEST_DIR/debian/control failed: $!");
	open my $out, '>', "$dir/debian/control" or
	    error("open $dir/debian/control failed: $!");
	while (<$in>) {
		s/BUILD_DEPENDS/$build_depends/;
		print $out $_ or
		    error("write to $dir/debian/control failed: $!");
	}
	close($out) or
	    error("close $dir/debian/control failed: $!");
	close($in);

	my $start_dir = Test::DH::cwd();
	chdir($dir) or error("chdir($dir): $!");

	plan(tests => 5);

	local $ENV{DH_INTERNAL_TESTSUITE_SILENT_WARNINGS} = 1;
	Debian::Debhelper::Dh_Lib::resetpackages;
	Debian::Debhelper::Dh_Lib::resetcompat;
	my @pkgs = getpackages;
	ok(scalar @pkgs == 1);
	ok($pkgs[0] eq 'foo');

	ok(compat($level));
	ok(compat($level + 1));
	ok(!compat($level - 1));

	chdir($start_dir) or
	    error("chdir($start_dir): $!");
}

my @levels = non_deprecated_compat_levels;
plan(tests => scalar @levels);

for my $level (@levels) {
	subtest "compat $level" => sub {
		plan(tests => 7);
		subtest 'only' => sub {
			test_build_depends($level, "debhelper-compat (= $level)");
		};
		subtest 'first' => sub {
			test_build_depends($level, "debhelper-compat (= $level), bar");
		};
		subtest 'second' => sub {
			test_build_depends($level, "bar, debhelper-compat (= $level)");
		};
		subtest 'first-nl' => sub {
			test_build_depends($level, "debhelper-compat (= $level),\n bar");
		};
		subtest 'second-nl' => sub {
			test_build_depends($level, "bar,\n debhelper-compat (= $level)");
		};
		subtest 'nl-first' => sub {
			test_build_depends($level, "\n debhelper-compat (= $level),\n bar");
		};
		subtest 'nl-second' => sub {
			test_build_depends($level, "\n bar,\n debhelper-compat (= $level)");
		};
	};
}
