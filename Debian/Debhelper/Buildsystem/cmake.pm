# A debhelper build system class for handling CMake based projects.
# It prefers out of source tree building.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::cmake;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(compat dpkg_architecture_value error is_cross_compiling);
use parent qw(Debian::Debhelper::Buildsystem::makefile);

my @STANDARD_CMAKE_FLAGS = qw(
  -DCMAKE_INSTALL_PREFIX=/usr
  -DCMAKE_VERBOSE_MAKEFILE=ON
  -DCMAKE_BUILD_TYPE=None
  -DCMAKE_INSTALL_SYSCONFDIR=/etc
  -DCMAKE_INSTALL_LOCALSTATEDIR=/var
);

my %DEB_HOST2CMAKE_SYSTEM = (
	'linux'    => 'Linux',
	'kfreebsd' => 'FreeBSD',
	'hurd'     => 'GNU',
);

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
	# Standard set of cmake flags
	my @flags = @STANDARD_CMAKE_FLAGS;

	if (is_cross_compiling()) {
		my $deb_host = dpkg_architecture_value("DEB_HOST_ARCH_OS");
		if (my $cmake_system = $DEB_HOST2CMAKE_SYSTEM{$deb_host}) {
			push(@flags, "-DCMAKE_SYSTEM_NAME=${cmake_system}");
		} else {
			error("Cannot cross-compile - CMAKE_SYSTEM_NAME not known for ${deb_host}");
		}
		push @flags, "-DCMAKE_SYSTEM_PROCESSOR=" . dpkg_architecture_value("DEB_HOST_GNU_CPU");
		if ($ENV{CC}) {
			push @flags, "-DCMAKE_C_COMPILER=" . $ENV{CC};
		} else {
			push @flags, "-DCMAKE_C_COMPILER=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-gcc";
		}
		if ($ENV{CXX}) {
			push @flags, "-DCMAKE_CXX_COMPILER=" . $ENV{CXX};
		} else {
			push @flags, "-DCMAKE_CXX_COMPILER=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-g++";
		}
		push(@flags, "-DPKG_CONFIG_EXECUTABLE=/usr/bin/" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-pkg-config");
		push(@flags, "-DCMAKE_INSTALL_LIBDIR=lib/" . dpkg_architecture_value("DEB_HOST_MULTIARCH"));
	}

	# CMake doesn't respect CPPFLAGS, see #653916.
	if ($ENV{CPPFLAGS} && ! compat(8)) {
		$ENV{CFLAGS}   .= ' ' . $ENV{CPPFLAGS};
		$ENV{CXXFLAGS} .= ' ' . $ENV{CPPFLAGS};
	}

	$this->mkdir_builddir();
	eval { 
		$this->doit_in_builddir("cmake", $this->get_source_rel2builddir(), @flags, @_);
	};
	if (my $err = $@) {
		if (-e $this->get_buildpath("CMakeCache.txt")) {
			$this->doit_in_builddir("tail -v -n +0 CMakeCache.txt");
		}
		if (-e $this->get_buildpath('CMakeFiles/CMakeOutput.log')) {
			$this->doit_in_builddir('tail -v -n +0 CMakeFiles/CMakeOutput.log');
		}
		if (-e $this->get_buildpath('CMakeFiles/CMakeError.log')) {
			$this->doit_in_builddir('tail -v -n +0 CMakeFiles/CMakeError.log');
		}
		die $err;
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

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
