# A buildsystem plugin for handling Perl Build based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_makefile;

use strict;
use Debian::Debhelper::Dh_Lib;
use Debian::Debhelper::Dh_Buildsystem_Bases;
use base 'Debian::Debhelper::Dh_Buildsystem_Basic';

sub DESCRIPTION {
	"support for building Perl Makefile.PL based packages (in-source only)"
}

sub is_buildable {
	my ($self, $action) = @_;
	return ($action eq "configure")  && (-e "Makefile.PL");
}

sub new {
	my $cls=shift;
	my $self=$cls->SUPER::new(@_);
	$self->enforce_in_source_building();
	return $self;
}

sub configure_impl {
	my $self=shift;
	# If set to a true value then MakeMaker's prompt function will
	# # always return the default without waiting for user input.
	$ENV{PERL_MM_USE_DEFAULT}=1;
	doit("perl", "Makefile.PL", "INSTALLDIRS=vendor", @_);
}

1;
