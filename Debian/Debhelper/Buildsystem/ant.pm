# A debhelper build system class for handling Ant based projects.
#
# Copyright: © 2009 Joey Hess
# License: GPL-2+

package Debian::Debhelper::Buildsystem::ant;

use strict;
use base 'Debian::Debhelper::Buildsystem';

sub DESCRIPTION {
	"Ant (build.xml)"
}

sub check_auto_buildable {
	my $this=shift;
	return (-e $this->get_sourcepath("build.xml")) ? 1 : 0;
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->enforce_in_source_building();
	return $this;
}

sub build {
	my $this=shift;
	$this->doit_in_sourcedir("ant", @_);
}

sub clean {
	my $this=shift;
	$this->doit_in_sourcedir("ant", "clean", @_);
}

1
