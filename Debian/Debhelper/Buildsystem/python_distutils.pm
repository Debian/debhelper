# A buildsystem plugin for building Python Distutils based
# projects.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::python_distutils;

use strict;
use Debian::Debhelper::Dh_Lib;
use Debian::Debhelper::Dh_Buildsystem_Bases;
use base 'Debian::Debhelper::Dh_Buildsystem_Option';

sub DESCRIPTION {
	"support for building Python distutils based packages"
}

sub is_buildable {
	return -e "setup.py";
}

sub get_builddir_option {
	my $self=shift;
	if ($self->get_builddir()) {
		return "--build-base=". $self->get_builddir();
	}
	return;
}

sub configure_impl {
	# Do nothing
	1;
}

sub build_impl {
	my $self=shift;
	doit("python", "setup.py", "build", @_);
}

sub test_impl {
	1;
}

sub install_impl {
	my $self=shift;
	my $destdir=shift;

	doit("python", "setup.py", "install", 
	     "--root=$destdir",
	     "--no-compile", "-O0", @_);
}

sub clean_impl {
	my $self=shift;
	doit("python", "setup.py", "clean", "-a", @_);
	# The setup.py might import files, leading to python creating pyc
	# files.
	doit('find', '.', '-name', '*.pyc', '-exec', 'rm', '{}', ';');
}

1;
