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

sub is_auto_buildable {
	my $self=shift;
	my $action=shift;

	# Handle configure; the rest - next class
	if ($action eq "configure") {
		return -x "configure";
	}
	return 0;
}

sub configure {
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
	push @opts, "--libexecdir=\${prefix}/lib/" . sourcepackage();
	push @opts, "--disable-maintainer-mode";
	push @opts, "--disable-dependency-tracking";
	# Provide --host only if different from --build, as recommended in
	# autotools-dev README.Debian: When provided (even if equal) autotools
	# 2.52+ switches to cross-compiling mode.
	if (dpkg_architecture_value("DEB_BUILD_GNU_TYPE")
	    ne dpkg_architecture_value("DEB_HOST_GNU_TYPE")) {
		push @opts, "--host=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE");
	}

	$self->mkdir_builddir();
	$self->doit_in_builddir($self->get_rel2builddir_path("configure"), @opts, @_);
}

1;
