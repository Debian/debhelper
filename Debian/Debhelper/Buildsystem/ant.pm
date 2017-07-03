# A debhelper build system class for handling Ant based projects.
#
# Copyright: © 2009 Joey Hess
# License: GPL-2+

package Debian::Debhelper::Buildsystem::ant;

use strict;
use warnings;
use parent qw(Debian::Debhelper::Buildsystem);

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
	my $d_ant_prop = $this->get_sourcepath('debian/ant.properties');
	my @args;
	if ( -f $d_ant_prop ) {
		push(@args, '-propertyfile', $d_ant_prop);
	}

	# Set the username to improve the reproducibility
	push(@args, "-Duser.name", "debian");

	$this->doit_in_sourcedir("ant", @args, @_);
}

sub clean {
	my $this=shift;
	my $d_ant_prop = $this->get_sourcepath('debian/ant.properties');
	my @args;
	if ( -f $d_ant_prop ) {
		push(@args, '-propertyfile', $d_ant_prop);
	}
	$this->doit_in_sourcedir("ant", @args, "clean", @_);
}

1
