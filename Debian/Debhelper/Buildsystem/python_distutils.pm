# A buildsystem plugin for building Python Distutils based
# projects.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::python_distutils;

use strict;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Dh_Buildsystem_Basic';

sub DESCRIPTION {
	"support for building Python distutils based packages"
}

sub is_auto_buildable {
	my $self=shift;
	my $action=shift;

	# Handle build install clean; the rest - next class
	# XXX JEH shouldn't it also handle configure? It would be handled
	# by doing nothing, but that's what's appropriate for python.
	if (grep(/^\Q$action\E$/, qw{build install clean})) {
		return -e "setup.py";
	}
	return 0;
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
