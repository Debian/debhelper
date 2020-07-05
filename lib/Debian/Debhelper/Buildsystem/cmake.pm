# A debhelper build system class for handling CMake based projects.
# It prefers out of source tree building.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::cmake;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(%dh compat dpkg_architecture_value error is_cross_compiling);
use parent qw(Debian::Debhelper::Buildsystem);

my @STANDARD_CMAKE_FLAGS = qw(
  -DCMAKE_INSTALL_PREFIX=/usr
  -DCMAKE_BUILD_TYPE=None
  -DCMAKE_INSTALL_SYSCONFDIR=/etc
  -DCMAKE_INSTALL_LOCALSTATEDIR=/var
  -DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON
  -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON
);

my %DEB_HOST2CMAKE_SYSTEM = (
	'linux'    => 'Linux',
	'kfreebsd' => 'kFreeBSD',
	'hurd'     => 'GNU',
);

my %GNU_CPU2SYSTEM_PROCESSOR = (
	'arm'         => 'armv7l',
	'mips64el'    => 'mips64',
	'powerpc64le' => 'ppc64le',
);

my %TARGET_BUILD_SYSTEM2CMAKE_GENERATOR = (
	'makefile' => 'Unix Makefiles',
	'ninja'    => 'Ninja',
);

sub DESCRIPTION {
	"CMake (CMakeLists.txt)"
}

sub IS_GENERATOR_BUILD_SYSTEM {
	return 1;
}

sub SUPPORTED_TARGET_BUILD_SYSTEMS {
	return qw(makefile ninja);
}

sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;
	if (-e $this->get_sourcepath("CMakeLists.txt")) {
		my $ret = ($step eq "configure" && 1) ||
		          $this->get_targetbuildsystem->check_auto_buildable(@_);
		if ($this->check_auto_buildable_clean_oos_buildir(@_)) {
			# Assume that the package can be cleaned (i.e. the build directory can
			# be removed) as long as it is built out-of-source tree and can be
			# configured.
			$ret++ if not $ret;
		}
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
	my $backend = $this->get_targetbuildsystem->NAME;

	push(@flags, '-DCMAKE_INSTALL_RUNSTATEDIR=/run') if not compat(10);
	# Speed up installation phase a bit.
	push(@flags, "-DCMAKE_SKIP_INSTALL_ALL_DEPENDENCY=ON") if not compat(12);
	# Reproducibility #962474
	push(@flags, "-DCMAKE_SKIP_RPATH=ON", '-DBUILD_RPATH_USE_ORIGIN=ON') if not compat(13);
	if (exists($TARGET_BUILD_SYSTEM2CMAKE_GENERATOR{$backend})) {
		my $generator = $TARGET_BUILD_SYSTEM2CMAKE_GENERATOR{$backend};
		push(@flags, "-G${generator}");
	}
	if (not $dh{QUIET}) {
		push(@flags, "-DCMAKE_VERBOSE_MAKEFILE=ON");
	}

	if ($ENV{CC}) {
		push @flags, "-DCMAKE_C_COMPILER=" . $ENV{CC};
	}
	if ($ENV{CXX}) {
		push @flags, "-DCMAKE_CXX_COMPILER=" . $ENV{CXX};
	}
	if (is_cross_compiling()) {
		my $deb_host = dpkg_architecture_value("DEB_HOST_ARCH_OS");
		if (my $cmake_system = $DEB_HOST2CMAKE_SYSTEM{$deb_host}) {
			push(@flags, "-DCMAKE_SYSTEM_NAME=${cmake_system}");
		} else {
			error("Cannot cross-compile - CMAKE_SYSTEM_NAME not known for ${deb_host}");
		}
		my $gnu_cpu = dpkg_architecture_value("DEB_HOST_GNU_CPU");
		if (exists($GNU_CPU2SYSTEM_PROCESSOR{$gnu_cpu})) {
			push @flags, "-DCMAKE_SYSTEM_PROCESSOR=" . $GNU_CPU2SYSTEM_PROCESSOR{$gnu_cpu};
		} else {
			push @flags, "-DCMAKE_SYSTEM_PROCESSOR=${gnu_cpu}";
		}
		if (not $ENV{CC}) {
			push @flags, "-DCMAKE_C_COMPILER=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-gcc";
		}
		if (not $ENV{CXX}) {
			push @flags, "-DCMAKE_CXX_COMPILER=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-g++";
		}
		push(@flags, "-DPKG_CONFIG_EXECUTABLE=/usr/bin/" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-pkg-config");
		push(@flags, "-DPKGCONFIG_EXECUTABLE=/usr/bin/" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-pkg-config");
		push(@flags, "-DQMAKE_EXECUTABLE=/usr/bin/" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-qmake");
	}
	push(@flags, "-DCMAKE_INSTALL_LIBDIR=lib/" . dpkg_architecture_value("DEB_HOST_MULTIARCH"));

	# CMake doesn't respect CPPFLAGS, see #653916.
	if ($ENV{CPPFLAGS} && ! compat(8)) {
		$ENV{CFLAGS}   .= ' ' . $ENV{CPPFLAGS};
		$ENV{CXXFLAGS} .= ' ' . $ENV{CPPFLAGS};
	}

	$this->mkdir_builddir();
	eval { 
		$this->doit_in_builddir("cmake", @flags, @_, $this->get_source_rel2builddir());
	};
	if (my $err = $@) {
		if (-e $this->get_buildpath("CMakeCache.txt")) {
			$this->doit_in_builddir('tail', '-v', '-n', '+0', 'CMakeCache.txt');
		}
		if (-e $this->get_buildpath('CMakeFiles/CMakeOutput.log')) {
			$this->doit_in_builddir('tail', '-v', '-n', '+0', 'CMakeFiles/CMakeOutput.log');
		}
		if (-e $this->get_buildpath('CMakeFiles/CMakeError.log')) {
			$this->doit_in_builddir('tail', '-v', '-n', '+0', 'CMakeFiles/CMakeError.log');
		}
		die $err;
	}
}

sub test {
	my $this=shift;
	my $target = $this->get_targetbuildsystem;
	$ENV{CTEST_OUTPUT_ON_FAILURE} = 1;
	if ($target->NAME eq 'makefile') {
		# Unlike make, CTest does not have "unlimited parallel" setting (-j implies
		# -j1). So in order to simulate unlimited parallel, allow to fork a huge
		# number of threads instead.
		my $parallel = ($this->get_parallel() > 0) ? $this->get_parallel() : 999;
		push(@_, "ARGS+=-j$parallel")
	}
	return $this->SUPER::test(@_);
}

1
