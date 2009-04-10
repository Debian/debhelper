# A buildsystem plugin for handling autotools based projects
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::autotools;

use strict;
use File::Spec;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Buildsystem::makefile';

sub DESCRIPTION {
	"support for building GNU Autotools based packages"
}

sub is_buildable {
	my $self=shift;
	my ($action) = @_;
	if ($action eq "configure") {
		return -x "configure";
	} else {
		return $self->SUPER::is_buildable(@_);
	}
}

sub configure_impl {
	my $self=shift;

	# Standard set of options for configure.
	my @opts;
	push @opts, "--build=" . dpkg_architecture_value("DEB_BUILD_GNU_TYPE");
	push @opts, "--prefix=/usr";
	push @opts, "--includedir=\${prefix}/include";
	push @opts, "--mandir=\${prefix}/share/man";
	push @opts, "--infodir=\${prefix}/share/info";
	push @opts, "--sysconfdir=/etc";
	push @opts, "--localstatedir=/var";
	# XXX JEH this is where the sheer evil of Dh_Buildsystem_Chdir
	# becomes evident. Why is exec_in_topdir needed here?
	# Because:
	# - The parent class happens to be derived from Dh_Buildsystem_Chdir.
	# - sourcepage() happens to, like many other parts of debhelper's
	#   library, assume it's being run in the top of the source tree,
	#   and fails if it's not.
	# Having to worry about interactions like that for every line of
	# every derived method is simply not acceptable.
	# Dh_Buildsystem_Chdir must die! -- JEH
	push @opts, "--libexecdir=\${prefix}/lib/" . $self->exec_in_topdir(\&sourcepackage);
	push @opts, "--disable-maintainer-mode";
	push @opts, "--disable-dependency-tracking";
	# Provide --host only if different from --build, as recommended in
	# autotools-dev README.Debian: When provided (even if equal) autotools
	# 2.52+ switches to cross-compiling mode.
	if (dpkg_architecture_value("DEB_BUILD_GNU_TYPE")
	    ne dpkg_architecture_value("DEB_HOST_GNU_TYPE")) {
		push @opts, "--host=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE");
	}

	# XXX JEH the reason it needs to use get_toppath here,
	# but does not need to in the is_buildable method is not clear,
	# unless one is familiar with the implementation of its parent
	# class. I think that speaks to a bad design..
	doit($self->get_toppath("configure"), @opts, @_);
}

1;
