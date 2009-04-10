# A buildsystem plugin for handling Perl Build based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_build;

use strict;
use Debian::Debhelper::Dh_Lib;
use Debian::Debhelper::Dh_Buildsystem_Bases;
use base 'Debian::Debhelper::Dh_Buildsystem_Basic';

sub DESCRIPTION {
	"support for building Perl Build.PL based packages (in-source only)"
}

sub is_buildable {
	my ($self, $action) = @_;
	my $ret = (-e "Build.PL");
	if ($action ne "configure") {
		$ret &= (-e "Build");
	}
	return $ret;
}

sub invoke_impl {
	my $self=shift;
	$ENV{MODULEBUILDRC} = "/dev/null";
	return $self->SUPER::invoke_impl(@_);
}

sub new {
	my $cls=shift;
	my $self= $cls->SUPER::new(@_);
	$self->enforce_in_source_building();
	return $self;
}

sub configure_impl {
	my $self=shift;
	# XXX JEH I think the below comment is inherited from elsewhere;
	# doesn't really make sense now.
	$ENV{PERL_MM_USE_DEFAULT}=1; # Module::Build can also use this.
	doit("perl", "Build.PL", "installdirs=vendor", @_);
}

sub build_impl {
	my $self=shift;
	doit("perl", "Build", @_);
}

sub test_impl {
	my $self=shift;
	doit(qw/perl Build test/, @_);
}

sub install_impl {
	my $self=shift;
	my $destdir=shift;
	doit("perl", "Build", "install", "destdir=$destdir", "create_packlist=0", @_);
}

sub clean_impl {
	my $self=shift;
	doit("perl", "Build", "--allow_mb_mismatch", 1, "distclean", @_);
}

1;
