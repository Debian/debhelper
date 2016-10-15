# A build system class for handling Perl Build based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_build;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(compat);
use parent qw(Debian::Debhelper::Buildsystem);
use Config;

sub DESCRIPTION {
	"Perl Module::Build (Build.PL)"
}

sub check_auto_buildable {
	my ($this, $step) = @_;

	# Handles everything
	my $ret = -e $this->get_sourcepath("Build.PL");
	if ($step ne "configure") {
		$ret &&= -e $this->get_sourcepath("Build");
	}
	return $ret ? 1 : 0;
}

sub do_perl {
	my $this=shift;
	$this->doit_in_sourcedir("perl", @_);
}

sub new {
	my $class=shift;
	my $this= $class->SUPER::new(@_);
	$this->enforce_in_source_building();
	return $this;
}

sub configure {
	my $this=shift;
	my @flags;
	$ENV{PERL_MM_USE_DEFAULT}=1;
	if ($ENV{CFLAGS} && ! compat(8)) {
		push @flags, "--config", "optimize=$ENV{CFLAGS} $ENV{CPPFLAGS}";
	}
	if ($ENV{LDFLAGS} && ! compat(8)) {
		push @flags, "--config", "ld=$Config{ld} $ENV{CFLAGS} $ENV{LDFLAGS}";
	}
	$this->do_perl("-I.", "Build.PL", "--installdirs", "vendor", @flags, @_);
}

sub build {
	my $this=shift;
	$this->do_perl("Build", @_);
}

sub test {
	my $this=shift;
	$this->do_perl("Build", "test", "--verbose", 1, @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	$this->do_perl("Build", "install", "--destdir", "$destdir", "--create_packlist", 0, @_);
}

sub clean {
	my $this=shift;
	if (-e $this->get_sourcepath("Build")) {
		$this->do_perl("Build", "realclean", "--allow_mb_mismatch", 1, @_);
	}
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
