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
	my $ret = -e $this->get_sourcepath("CMakeLists.txt");
	$ret &&= $this->SUPER::check_auto_buildable(@_) if $step ne "configure";
	return $ret;
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	my %args=@_;
	# Prefer out of source tree building.
	$this->enforce_out_of_source_building($args{builddir});
	return $this;
}

sub configure {
	my $this=shift;
	my @flags;

	# Standard set of cmake flags
	push @flags, "-DCMAKE_INSTALL_PREFIX=/usr";
	push @flags, "-DCMAKE_C_FLAGS=$ENV{CFLAGS}" if (exists $ENV{CFLAGS});
	push @flags, "-DCMAKE_CXX_FLAGS=$ENV{CXXFLAGS}" if (exists $ENV{CXXFLAGS});
	push @flags, "-DCMAKE_LD_FLAGS=$ENV{LDFLAGS}" if (exists $ENV{LDFLAGS});
	push @flags, "-DCMAKE_SKIP_RPATH=ON";
	push @flags, "-DCMAKE_VERBOSE_MAKEFILE=ON";

	$this->mkdir_builddir();
	$this->doit_in_builddir("cmake", $this->get_source_rel2builddir(), @flags);
}

1;
