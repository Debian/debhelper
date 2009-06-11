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

	# Handles everything if Makefile.PL exists. Otherwise - next class.
	if (-e $this->get_sourcepath("Makefile.PL")) {
		if ($step eq "install" || $step eq "configure") {
			return 1;
		}
		else {
			# This is backwards compatible (with << 7.3) until build, test and
			# clean steps are not reimplemented in the backwards compatibility
			# breaking way. However, this is absolutely necessary for
			# enforce_in_source_building() to work in corner cases in build,
			# test and clean steps as the next class (makefile) does not
			# enforce it.
			return $this->SUPER::check_auto_buildable(@_);
		}
	}
	return 0;
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
