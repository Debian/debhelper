# A buildsystem plugin for building Python Distutils based
# projects.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::python_distutils;

use strict;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Dh_Buildsystem';

sub DESCRIPTION {
	"support for building Python distutils based packages"
}

sub check_auto_buildable {
	return -e "setup.py";
}

sub setup_py {
	my $self=shift;
	my $act=shift;

	if ($self->get_builddir()) {
		unshift @_, "--build-base=" . $self->get_builddir();
	}
	doit("python", "setup.py", $act, @_);
}

sub build {
	my $self=shift;
	$self->setup_py("build", @_);
}

sub install {
	my $self=shift;
	my $destdir=shift;
	$self->setup_py("install", "--root=$destdir", "--no-compile", "-O0", @_);
}

sub clean {
	my $self=shift;
	$self->setup_py("clean", "-a", @_);
	# The setup.py might import files, leading to python creating pyc
	# files.
	doit('find', '.', '-name', '*.pyc', '-exec', 'rm', '{}', ';');
}

1;
