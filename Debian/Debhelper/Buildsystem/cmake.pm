# A buildsystem plugin for handling CMake based projects.
# It enforces outside-source building.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::cmake;

use strict;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Buildsystem::makefile';

sub _add_cmake_flag {
	my ($self, $name, $val) = @_;
	push @{$self->{cmake_flags}}, "-D$name=$val";
}

sub DESCRIPTION {
	"support for building CMake based packages (outside-source tree only)"
}

sub is_buildable {
	return -e "CMakeLists.txt";
}

sub new {
	my $cls=shift;
	my $self=$cls->SUPER::new(@_);
	# Enfore outside-source tree builds.
	$self->enforce_outside_source_building();
	$self->{cmake_flags} = [];
	return $self;
}

sub configure_impl {
	my $self=shift;

	# Standard set of cmake flags
	$self->_add_cmake_flag("CMAKE_INSTALL_PREFIX", "/usr");
	$self->_add_cmake_flag("CMAKE_C_FLAGS", $ENV{CFLAGS}) if (exists $ENV{CFLAGS});
	$self->_add_cmake_flag("CMAKE_CXX_FLAGS", $ENV{CXXFLAGS}) if (exists $ENV{CXXFLAGS});
	$self->_add_cmake_flag("CMAKE_SKIP_RPATH", "ON");
	$self->_add_cmake_flag("CMAKE_VERBOSE_MAKEFILE", "ON");
	# TODO: LDFLAGS
	# XXX JEH why are we using a method and an object
	# field to build up a simple one-time-use list?
	# 	my @flags;
	# 	push @flags, ... if $foo

	# XXX JEH again a non-sequitor get_topdir. 
	doit("cmake", $self->get_topdir(), @{$self->{cmake_flags}}, @_);
}

1;
