#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 187;

use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);
use Debian::Debhelper::Dh_Buildsystems;

my @STEPS = qw(configure build test install clean);

### Test check_auto_buildable() of each buildsystem
sub test_check_auto_buildable {
	my ($bs, $config, $expected) = @_;

	if (! ref $expected) {
		my %all_steps;
		$all_steps{$_} = $expected foreach (@STEPS);
		$expected = \%all_steps;
	}
	for my $step (@STEPS) {
		my $e = 0;
		if (exists $expected->{$step}) {
			$e = $expected->{$step};
		} elsif (exists $expected->{default}) {
			$e = $expected->{default};
		}
		is( $bs->check_auto_buildable($step), $e,
			$bs->NAME() . "($config): check_auto_buildable($step) == $e" );
	}
}

sub test_autoselection {
	my ($testname, $expected, %args) = @_;
	for my $step (@STEPS) {
		my $bs = load_buildsystem({'enable-thirdparty' => 0}, $step, @_);
		my $e = $expected;
		$e = $expected->{$step} if ref $expected;
		if (defined $bs) {
			is( $bs->NAME(), $e, "autoselection($testname): $step=".((defined $e)?$e:'undef') );
		}
		else {
			is ( undef, $e, "autoselection($testname): $step=".((defined $e)?$e:'undef') );
		}
		&{$args{"code_$step"}}() if exists $args{"code_$step"};
	}
}

my $TEMP_DIR = tempdir('tmp.XXXXXXX', CLEANUP => 1);
my $sourcedir = "${TEMP_DIR}/source";
my $builddir = "${TEMP_DIR}/build";
my %options = (
	'builddir'  => $builddir,
	'sourcedir' => $sourcedir,
);
make_path($sourcedir, $builddir);
use Config;
my $libpath = $ENV{AUTOPKGTEST_TMP} ? $Config{vendorlib} : "$Test::DH::ROOT_DIR/lib";
my @bs = load_all_buildsystems([ $libpath ], %options);
my %bs;
my @names = map { $_->NAME() } @bs;

ok(@Debian::Debhelper::Dh_Buildsystems::BUILDSYSTEMS >= 1, "some build systems are built in" );
is_deeply( \@names, \@Debian::Debhelper::Dh_Buildsystems::BUILDSYSTEMS, "load_all_buildsystems() loads all built-in buildsystems" );

# check_auto_buildable() fails with numeric 0
for my $bs (@bs) {
    test_check_auto_buildable($bs, "fails with numeric 0", 0);
	$bs{$bs->NAME()} = $bs;
}

run_auto_buildable_tests();

remove_tree($sourcedir, $builddir);
make_path($sourcedir, $builddir);

run_autoselection_tests();


#### Bulk of test code ####

sub run_auto_buildable_tests {
	create_empty_file("${sourcedir}/configure", 0755);
	test_check_auto_buildable($bs{autoconf}, "configure", { configure => 1, clean => 1 });
	rm_files("${sourcedir}/configure");

	create_empty_file("${sourcedir}/CMakeLists.txt");
	test_check_auto_buildable($bs{'cmake+makefile'}, "CMakeLists.txt", { configure => 1, clean => 1 });
	rm_files("${sourcedir}/CMakeLists.txt");

	create_empty_file("${sourcedir}/Makefile.PL");
	test_check_auto_buildable($bs{perl_makemaker}, "Makefile.PL", { configure => 1 });
	rm_files("${sourcedir}/Makefile.PL");

	create_empty_file("${sourcedir}/meson.build");
	test_check_auto_buildable($bs{'meson+ninja'}, "meson.build", { configure => 1, clean => 1 });
	# Leave meson.build

	create_empty_file("${builddir}/build.ninja");
	test_check_auto_buildable($bs{ninja}, "build.ninja", { configure => 1, build => 1, clean => 1, install => 1, test => 1 });
	# Leave ninja.build

	# Meson + ninja
	test_check_auto_buildable($bs{'meson+ninja'}, "meson.build+build.ninja", { configure => 1, build => 1, clean => 1, install => 1, test => 1 });
	rm_files("${sourcedir}/meson.build", "${builddir}/build.ninja");

	# With Makefile
	create_empty_file("$builddir/Makefile");
	test_check_auto_buildable($bs{makefile}, "Makefile", 1);

	# ... +autoconf
	create_empty_file("${sourcedir}/configure", 0755);
	test_check_auto_buildable($bs{autoconf}, "configure+Makefile", { configure => 1, test => 1, build => 1, install => 1, clean => 1 });
	rm_files("${sourcedir}/configure");

	# ... +cmake
	create_empty_file("${sourcedir}/CMakeLists.txt");
	test_check_auto_buildable($bs{'cmake+makefile'}, "CMakeLists.txt+Makefile", 1);
	create_empty_file("$builddir/CMakeCache.txt"); # strong evidence that cmake was run
	test_check_auto_buildable($bs{'cmake+makefile'}, "CMakeCache.txt+Makefile", 2);
	rm_files("${builddir}/Makefile", "${sourcedir}/CMakeLists.txt");

	# Makefile.PL forces in-source
	#(see note in check_auto_buildable() why always 1 here)
	create_empty_file("${sourcedir}/Makefile.PL");
	create_empty_file("${sourcedir}/Makefile");
	test_check_auto_buildable($bs{perl_makemaker}, "Makefile.PL+Makefile", 1);
	rm_files("${sourcedir}/Makefile.PL", "${sourcedir}/Makefile");

	# Perl Build.PL - handles always
	test_check_auto_buildable($bs{perl_build}, "no Build.PL", 0);
	create_empty_file("${sourcedir}/Build.PL");
	test_check_auto_buildable($bs{perl_build}, "Build.PL", { configure => 1 });
	create_empty_file("${sourcedir}/Build"); # forced in source
	test_check_auto_buildable($bs{perl_build}, "Build.PL+Build", 1);
	rm_files("${sourcedir}/Build.PL", "${sourcedir}/Build");

	# Python Distutils
	test_check_auto_buildable($bs{python_distutils}, "no setup.py", 0);
	create_empty_file("${sourcedir}/setup.py");
	test_check_auto_buildable($bs{python_distutils}, "setup.py", 1);
	rm_files("${sourcedir}/setup.py");
}

sub run_autoselection_tests {
	# Auto-select nothing when no supported build system can be found
	# (see #557006).
	test_autoselection("auto-selects nothing", undef, %options);

	# Autoconf
	create_empty_file("${sourcedir}/configure", 0755);
	create_empty_file("${builddir}/Makefile");
	test_autoselection("autoconf",
					   { configure => "autoconf", build => "autoconf",
						 test => "autoconf", install => "autoconf",
						 clean => "autoconf"
					   }, %options);
	rm_files("${sourcedir}/configure", "${builddir}/Makefile");


	# Perl Makemaker (build, test, clean fail with builddir set [not supported])
	create_empty_file("${sourcedir}/Makefile.PL");
	create_empty_file("${sourcedir}/Makefile");
	test_autoselection("perl_makemaker", "perl_makemaker", %options);
	rm_files("${sourcedir}/Makefile.PL", "${sourcedir}/Makefile");


	# Makefile
	create_empty_file("$builddir/Makefile");
	test_autoselection("makefile", "makefile", %options);
	rm_files("$builddir/Makefile");

	# Python Distutils
	create_empty_file("${sourcedir}/setup.py");
	test_autoselection("python_distutils", "python_distutils", %options);
	rm_files("${sourcedir}/setup.py");

	# Perl Build
	create_empty_file("${sourcedir}/Build.PL");
	create_empty_file("${sourcedir}/Build");
	test_autoselection("perl_build", "perl_build", %options);
	rm_files("${sourcedir}/Build.PL", "${sourcedir}/Build");

	# CMake
	create_empty_file("${sourcedir}/CMakeLists.txt");
	test_autoselection("cmake without CMakeCache.txt",
					   { configure => "cmake+makefile", build => "makefile",
						 test => "makefile", install => "makefile",
						 clean => "makefile"
					   },
					   %options,
					   code_configure =>  sub {
						   create_empty_file("$builddir/Makefile");
					   });
	rm_files("${sourcedir}/CMakeLists.txt", "$builddir/Makefile");

	create_empty_file("${sourcedir}/CMakeLists.txt");
	test_autoselection("cmake with CMakeCache.txt",
					   "cmake+makefile",
					   %options,
					   code_configure => sub {
						   create_empty_file("$builddir/Makefile");
						   create_empty_file("$builddir/CMakeCache.txt");
					   });
	rm_files("${sourcedir}/CMakeLists.txt", "$builddir/Makefile", "$builddir/CMakeCache.txt");

	create_empty_file("${sourcedir}/CMakeLists.txt");
	create_empty_file("$builddir/Makefile");
	test_autoselection("cmake and existing Makefile", "makefile", %options);
	rm_files("${sourcedir}/CMakeLists.txt", "$builddir/Makefile");

};

