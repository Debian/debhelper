# A buildsystem plugin for handling Perl MakeMaker based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_makemaker;

use strict;
use base 'Debian::Debhelper::Buildsystem::makefile';

sub DESCRIPTION {
	"Perl ExtUtils::MakeMaker (Makefile.PL)"
}

sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;

	# Handles configure, install; the rest - next class
	if ($step eq "install" || $step eq "configure") {
		return -e $this->get_sourcepath("Makefile.PL");
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
	# This prevents  Module::Install from interactive behavior.
	$ENV{PERL_AUTOINSTALL}="--skipdeps";

	$this->doit_in_sourcedir("perl", "Makefile.PL", "INSTALLDIRS=vendor",
	    "create_packlist=0",
	    @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	$this->SUPER::install($destdir, "PREFIX=/usr", @_);
}

1;
