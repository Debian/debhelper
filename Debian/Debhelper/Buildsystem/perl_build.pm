# A buildsystem plugin for handling Perl Build based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_build;

use strict;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Dh_Buildsystem_Basic';

sub DESCRIPTION {
	"support for building Perl Build.PL based packages (in-source only)"
}

sub is_auto_buildable {
	my ($self, $action) = @_;

	# Handles everything
	my $ret = -e "Build.PL";
	if ($action ne "configure") {
		$ret &&= -e "Build";
	}
	return $ret;
}

sub do_perl {
	my $self=shift;
	$ENV{MODULEBUILDRC} = "/dev/null";
	doit("perl", @_);
}

sub new {
	my $cls=shift;
	my $self= $cls->SUPER::new(@_);
	$self->enforce_in_source_building();
	return $self;
}

sub configure {
	my $self=shift;
	$ENV{PERL_MM_USE_DEFAULT}=1;
	$self->do_perl("Build.PL", "installdirs=vendor", @_);
}

sub build {
	my $self=shift;
	$self->do_perl("Build", @_);
}

sub test {
	my $self=shift;
	$self->do_perl("Build", "test", @_);
}

sub install {
	my $self=shift;
	my $destdir=shift;
	$self->do_perl("Build", "install", "destdir=$destdir", "create_packlist=0", @_);
}

sub clean {
	my $self=shift;
	$self->do_perl("Build", "--allow_mb_mismatch", 1, "distclean", @_);
}

1;
