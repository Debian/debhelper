# A buildsystem plugin for handling Perl MakeMaker based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_makemaker;

use strict;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Buildsystem::makefile';

sub DESCRIPTION {
	"support for building Perl MakeMaker based packages (in-source only)"
}

sub check_auto_buildable {
	my $self=shift;
	my ($action)=@_;

	# Handles configure, install; the rest - next class
	if ($action eq "install") {
		return -e "Makefile.PL";
	}
	# XXX JEH why test for configure here? If building or cleaning, and
	# a Makefile.PL exists, we know this class can handle those
	# actions -- it does so by inheriting from the makefile class.
	# XXX MDX Yes. But that's again different behaviour from current
	#         (see comment in autotools.mk). Your call.
	elsif ($action eq "configure") {
		return -e "Makefile.PL";
	}
	else {
		return 0;
	}
}

sub new {
	my $cls=shift;
	my $self=$cls->SUPER::new(@_);
	$self->enforce_in_source_building();
	return $self;
}

sub configure {
	my $self=shift;
	# If set to a true value then MakeMaker's prompt function will
	# # always return the default without waiting for user input.
	$ENV{PERL_MM_USE_DEFAULT}=1;
	doit("perl", "Makefile.PL", "INSTALLDIRS=vendor", @_);
}

sub install {
	my $self=shift;
	my $destdir=shift;
	$self->SUPER::install($destdir, "PREFIX=/usr", @_);
}

1;
