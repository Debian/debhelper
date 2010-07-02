# A debhelper build system class for handling CMake based projects.
# It prefers out of source tree building.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::cmake;

use strict;
use base 'Debian::Debhelper::Buildsystem::makefile';

sub DESCRIPTION {
	"CMake (CMakeLists.txt)"
}

sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;
	if (-e $this->get_sourcepath("CMakeLists.txt")) {
		my $ret = ($step eq "configure" && 1) ||
		          $this->SUPER::check_auto_buildable(@_);
		# Existence of CMakeCache.txt indicates cmake has already
		# been used by a prior build step, so should be used
		# instead of the parent makefile class.
		$ret++ if ($ret && -e $this->get_buildpath("CMakeCache.txt"));
		return $ret;
	}
	return 0;
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->prefer_out_of_source_building(@_);
	return $this;
}

sub configure {
	my $this=shift;
	my @flags;

	# Standard set of cmake flags
	push @flags, "-DCMAKE_INSTALL_PREFIX=/usr";
	push @flags, "-DCMAKE_VERBOSE_MAKEFILE=ON";

	$this->mkdir_builddir();
	eval { 
		$this->doit_in_builddir("cmake", $this->get_source_rel2builddir(), @flags, @_);
	};
	if ($@) {
		if (-e $this->get_buildpath("CMakeCache.txt")) {
			$this->doit_in_builddir("tail -v -n +0 CMakeCache.txt");
		}
		die $@;
	}
}

sub test {
	my $this=shift;

	# Unlike make, CTest does not have "unlimited parallel" setting (-j implies
	# -j1). So in order to simulate unlimited parallel, allow to fork a huge
	# number of threads instead.
	my $parallel = ($this->get_parallel() > 0) ? $this->get_parallel() : 999;
	$ENV{CTEST_OUTPUT_ON_FAILURE} = 1;
	return $this->SUPER::test(@_, "ARGS+=-j$parallel");
}

1
