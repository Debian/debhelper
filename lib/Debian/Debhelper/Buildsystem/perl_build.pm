# A build system class for handling Perl Build based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_build;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(compat is_cross_compiling perl_cross_incdir);
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
	my %options;
	if (is_cross_compiling()) {
		my $cross_incdir = perl_cross_incdir();
		if (defined $cross_incdir) {
			my $perl5lib = $cross_incdir;
			$perl5lib .= $Config{path_sep} . $ENV{PERL5LIB}
				if defined $ENV{PERL5LIB};
			$options{update_env} = { PERL5LIB => $perl5lib };
		} else {
			warning("cross Config.pm does not exist (missing build dependency on perl-xs-dev?)");
		}
	}
	$this->doit_in_sourcedir(\%options, "perl", @_);
}

sub new {
	my $class=shift;
	my $this= $class->SUPER::new(@_);
	$this->enforce_in_source_building();
	return $this;
}

sub configure {
	my $this=shift;
	my (@flags, @perl_flags);
	$ENV{PERL_MM_USE_DEFAULT}=1;
	if ($ENV{CFLAGS} && ! compat(8)) {
		push @flags, "--config", "optimize=$ENV{CFLAGS} $ENV{CPPFLAGS}";
	}
	if ($ENV{LDFLAGS} && ! compat(8)) {
		my $ld = $Config{ld};
		if (is_cross_compiling()) {
			my $incdir = perl_cross_incdir();
			$ld = qx/perl -I$incdir -MConfig -e 'print \$Config{ld}'/
				if defined $incdir;
		}
		push @flags, "--config", "ld=$ld $ENV{CFLAGS} $ENV{LDFLAGS}";
	}
	push(@perl_flags, '-I.') if compat(10);
	$this->do_perl(@perl_flags, "Build.PL", "--installdirs", "vendor", @flags, @_);
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
