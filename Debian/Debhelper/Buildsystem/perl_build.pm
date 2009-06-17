# A build system class for handling Perl Build based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_build;

=head1 NAME

B<perl_build> - Perl Module::Build (Build.PL)

=head1 SYNOPSIS

B<dh_auto_*> [B<--buildsystem>=I<perl_build>] ...

=head1 DESCRIPTION

Module::Build is a system for building, testing, and installing Perl modules.
It does not require a C<make> on your system - most of the Module::Build code is
pure-perl and written in a very cross-platform way. Its only prerequisites are
modules that are included with perl 5.6.0. Typically, Module::Build build system
can be identified by presence of the F<Build.PL> script in the source
directory.

=head1 DH_AUTO NOTES

Out of source tree building is not supported. C<MODULEBUILDRC=/dev/null>
environment variable is exported in each building step.

=head1 BUILD PROCESS

=cut

use strict;
use base 'Debian::Debhelper::Buildsystem';

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
	return $ret;
}

sub do_perl {
	my $this=shift;
	$ENV{MODULEBUILDRC} = "/dev/null";
	$this->doit_in_sourcedir("perl", @_);
}

sub new {
	my $class=shift;
	my $this= $class->SUPER::new(@_);
	$this->enforce_in_source_building();
	return $this;
}

=head2 Configure step

=over 4

=item I<Behaviour>

Execute C<perl Build.PL> passing C<installdirs=vendor> parameter by default.
Environment variable C<PERL_MM_USE_DEFAULT> is set before running the script.

=item I<Auto-selection>

If F<configure>, F<Makefile.PL>, F<setup.py> do not exist, but F<Build.PL>
exists in the source directory.

=back

=cut
sub configure {
	my $this=shift;
	$ENV{PERL_MM_USE_DEFAULT}=1;
	$this->do_perl("Build.PL", "installdirs=vendor", @_);
}

=head2 Build step

=over 4

=item I<Behaviour>

Execute C<perl Build>.

=item I<Auto-selection>

If F<Makefile>, F<makefile>, F<GNUmakefile> (build directory) and F<setup.py>
(source directory) do not exist, but F<Build.PL> and F<Build> files exist in
the source directory.

=back

=cut
sub build {
	my $this=shift;
	$this->do_perl("Build", @_);
}

=head2 Test step

=over 4

=item I<Behaviour>

Execute C<perl Build test>.

=item I<Auto-selection>

If F<Makefile>, F<makefile>, F<GNUmakefile> (build directory) and F<setup.py>
(source directory) do not exist, but F<Build.PL> and F<Build> files exist in
the source directory.

=back

=cut
sub test {
	my $this=shift;
	$this->do_perl("Build", "test", @_);
}

=head2 Install step

=over 4

=item I<Behaviour>

Execute C<perl Build install destdir=$destdir create_packlist=0>. $destdir is
the path to the temporary installation directory (see L<dh_auto_install(1)>).

=item I<Auto-selection>

If F<Makefile>, F<makefile>, F<GNUmakefile> (build directory) and F<setup.py>
(source directory) do not exist, but F<Build.PL> and F<Build> files exist in
the source directory.

=back

=cut
sub install {
	my $this=shift;
	my $destdir=shift;
	$this->do_perl("Build", "install", "destdir=$destdir", "create_packlist=0", @_);
}

=head2 Clean step

=over 4

=item I<Behaviour>

Execute C<perl Build --allow_mb_mismatch 1 distclean>.

=item I<Auto-selection>

If F<Makefile>, F<makefile>, F<GNUmakefile> (build directory) and F<setup.py>
(source directory) do not exist, but F<Build.PL> and F<Build> files exist in
the source directory.

=back

=cut
sub clean {
	my $this=shift;
	$this->do_perl("Build", "--allow_mb_mismatch", 1, "distclean", @_);
}

=head1 SEE ALSO

L<dh_auto(7)>

=head1 AUTHORS

 Joey Hess <joeyh@debian.org>
 Modestas Vainius <modestas@vainius.eu>

=cut

1;
