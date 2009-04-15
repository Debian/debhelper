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

sub check_auto_buildable {
	my $self=shift;
	my ($action)=@_;

	# Handle configure; the rest - next class
	# XXX JEH 
	# Currently, if there is a configure script, and dh_auto_build
	# is run w/o dh_auto_configure having been run, there's no
	# Makefile, so the next class's detection routine also fails, and
	# presumably all do, resulting in dh_auto_build doing nothing
	# and silently "succeeding".
	# So, why not always test for configure? Then, for ! configure
	# actions, it would use the methods inherited from its parent
	# class. In the above example, that will try to run "make" w/o a
	# Makefile, which prints a useful error.
	# XXX MDX I'm all for it but this will differ from current dh_auto_build
	#         behaviour (which is that dh_auto_build doesn't fail if
	#         dh_auto_configure was not run). It is your call whether you are
	#         willing to break this aspect of backwards compatibility.
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
