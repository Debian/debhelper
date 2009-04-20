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
	"Perl ExtUtils::MakeMaker (Makefile.PL)"
}

sub check_auto_buildable {
	my $this=shift;
	my ($action)=@_;

	# Handles configure, install; the rest - next class
	if ($action eq "install" || $action eq "configure") {
		return -e "Makefile.PL";
	}
	else {
		return 0;
	}
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->enforce_in_source_building();
	return $this;
}

sub configure {
	my $this=shift;
	# If set to a true value then MakeMaker's prompt function will
	# # always return the default without waiting for user input.
	$ENV{PERL_MM_USE_DEFAULT}=1;
	doit("perl", "Makefile.PL", "INSTALLDIRS=vendor", @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	$this->SUPER::install($destdir, "PREFIX=/usr", @_);
}

1;
