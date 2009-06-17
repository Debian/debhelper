# A debhelper build system class for handling Autoconf based projects
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::autoconf;

=head1 NAME

B<autoconf> - GNU Autoconf (configure)

=head1 SYNOPSIS

B<dh_auto_*> [B<--buildsystem>=I<autoconf>] ...

=head1 DESCRIPTION

GNU Autoconf is a popular cross-platform build system. Autoconf F<configure>
script prepares the source for building and generates necessary F<Makefile>s
and other temporary files in the build directory. Then a standard set of
make targets needs to be executed in the build directory to complete source
build process. GNU Autoconf build system can be typically identified by
presence of the F<configure> script in the source directory.

=head1 DH_AUTO NOTES

Both in source (default) and out of source tree building modes are supported.
However, please note that some original source packages might not be compatible
with out of source tree building mode of Autoconf and hence build process may
fail later even if the I<configure> step succeeds. 

=head1 BUILD PROCESS

=cut

use strict;
use Debian::Debhelper::Dh_Lib qw(dpkg_architecture_value sourcepackage);
use base 'Debian::Debhelper::Buildsystem::makefile';

sub DESCRIPTION {
	"GNU Autoconf (configure)"
}

sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;

	# Handle configure; the rest - next class
	if ($step eq "configure") {
		return -x $this->get_sourcepath("configure");
	}
	return 0;
}

=head2 Configure step

=over 4

=item I<Behaviour>

Execute F<configure> from the source directory with working directory set to
the build directory. A set of standard arguments are passed to the F<configure>
script:

 --build=`dpkg_architecture -qDEB_BUILD_GNU_TYPE`
 --prefix=/usr
 --includedir=${prefix}/include
 --mandir=${prefix}/share/man
 --infodir=${prefix}/share/info
 --sysconfdir=/etc
 --localstatedir=/var
 --libexecdir=${prefix}/lib/$name_of_debian_source_package
 --disable-maintainer-mode
 --disable-dependency-tracking
 --host=`dpkg_architecture -qDEB_HOST_GNU_TYPE` (if different from --build)

=item I<Auto-selection>

If executable file F<configure> exists in the source directory.

=back

=cut
sub configure {
	my $this=shift;

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
	# autotools-dev README.Debian: When provided (even if equal)
	# autoconf 2.52+ switches to cross-compiling mode.
	if (dpkg_architecture_value("DEB_BUILD_GNU_TYPE")
	    ne dpkg_architecture_value("DEB_HOST_GNU_TYPE")) {
		push @opts, "--host=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE");
	}

	$this->mkdir_builddir();
	$this->doit_in_builddir($this->get_source_rel2builddir("configure"), @opts, @_);
}

=head2 Build step

=over 4

=item I<Behaviour>

Execute C<make> in the build directory. See I<makefile> build system
documentation for more information.

=item I<Auto-selection>

It is normal for the I<makefile> build system to be auto-selected at this step.

=back

=head2 Test step

=over 4

=item I<Behaviour>

Execute either C<make test> or C<make check> in the build directory. See
I<makefile> build system documentation for more information.

=item I<Auto-selection>

It is normal for the I<makefile> build system to be auto-selected at this step.

=back

=head2 Install step

=over 4

=item I<Behaviour>

Execute C<make install DESTDIR=$destdir> in the build directory with $destdir
set to the appropriate temporary installation directory. See I<makefile> build
system documentation for more information.

=item I<Auto-selection>

It is normal for the I<makefile> build system to be auto-selected at this step.

=back

=head2 Clean step

=over 4

=item I<Behaviour>

Remove the build directory if building out of source tree or execute C<make
distclean> if building in source. See I<makefile> build system documentation
for more information.

=item I<Auto-selection>

It is normal for the I<makefile> build system to be auto-selected at this step.

=back

=head1 SEE ALSO

L<dh_auto_makefile(7)>

L<dh_auto(7)>

=head1 AUTHORS

 Joey Hess <joeyh@debian.org>
 Modestas Vainius <modestas@vainius.eu>

=cut

1;
