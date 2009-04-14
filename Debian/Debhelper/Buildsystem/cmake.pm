# A buildsystem plugin for handling CMake based projects.
# It enforces outside-source building.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::cmake;

use strict;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Buildsystem::makefile';

sub DESCRIPTION {
	"support for building CMake based packages (outside-source tree only)"
}

sub is_auto_buildable {
	my $self=shift;
	my ($action)=@_;
	my $ret = -e "CMakeLists.txt";
	$ret &&= $self->SUPER::is_auto_buildable(@_) if $action ne "configure";
	return $ret;
}

sub new {
	my $cls=shift;
	my $self=$cls->SUPER::new(@_);
	# Enforce outside-source tree builds.
	$self->enforce_outside_source_building();
	return $self;
}

sub configure {
	my $self=shift;
	my @flags;

	# Standard set of cmake flags
	push @flags, "-DCMAKE_INSTALL_PREFIX=/usr";
	push @flags, "-DCMAKE_C_FLAGS=$ENV{CFLAGS}" if (exists $ENV{CFLAGS});
	push @flags, "-DCMAKE_CXX_FLAGS=$ENV{CXXFLAGS}" if (exists $ENV{CXXFLAGS});
	push @flags, "-DCMAKE_LD_FLAGS=$ENV{LDFLAGS}" if (exists $ENV{LDFLAGS});
	push @flags, "-DCMAKE_SKIP_RPATH=ON";
	push @flags, "-DCMAKE_VERBOSE_MAKEFILE=ON";

	# XXX JEH again a non-sequitor get_topdir.
	# XXX MDX I cannot avoid it as I need to pass the path to the sourcedir
	# to cmake which is relative to the builddir.
	$self->mkdir_builddir();
	$self->doit_in_builddir("cmake", $self->get_rel2builddir_path(), @flags);
}

1;
