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

sub is_auto_buildable {
	my ($self, $action)=@_;

	# Handles configure, install; the rest - next class
	if ($action eq "install") {
		# This hack is needed to keep full 100% compatibility with previous
		# debhelper versions.
		# XXX JEH perl_makemaker comes before makefile, so
		# couldn't it instead just test for Makefile.PL?
		if (-e "Makefile" &&
		    system('grep -q "generated automatically by MakeMaker" Makefile') == 0) {
			return 1;
		}
	}
	# XXX JEH why test for configure here? If building or cleaning, and
	# a Makefile.PL exists, we know this class can handle those
	# actions -- it does so by inheriting from the makefile class.
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
	# XXX JEH this test seems redundant with the one in
	# is_auto_buildable, if we get here we know that one succeeded.
	if (-e "Makefile" &&
	    system('grep -q "generated automatically by MakeMaker" Makefile') == 0) {
		$self->SUPER::install($destdir, "PREFIX=/usr", @_);
	}
	else {
		$self->SUPER::install($destdir, @_);
	}
}

1;
