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
		if (-e "Makefile" &&
		    system('grep -q "generated automatically by MakeMaker" Makefile') == 0) {
			return 1;
		}
	}
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
	# XXX JEH This is a really unfortunate breaking of the
	# encapsulation of the perl_makefile module. Perhaps it would be
	# better for that module to contain some hack that injects that
	# test into this one?
	# XXX MDX Solved. perl_makemaker will need come before makefile in
	# @BUILDSYSTEMS. See also hack in is_auto_buildable().
	# This is a safety check needed to keep 100% compatibility with
	# earlier debhelper behaviour. This if is very unlikely to be false.
	if (-e "Makefile" &&
	    system('grep -q "generated automatically by MakeMaker" Makefile') == 0) {
		$self->SUPER::install($destdir, "PREFIX=/usr", @_);
	} else {
		$self->SUPER::install($destdir, @_);
	}
}

1;
