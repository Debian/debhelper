# A debhelper build system class for handling Perl MakeMaker based projects.
#
# Copyright: © 2008-2009 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::perl_makemaker;

=head1 NAME

B<perl_makemaker> - Perl ExtUtils::MakeMaker (Makefile.PL)

=head1 SYNOPSIS

B<dh_auto_*> [B<--buildsystem>=I<perl_makemaker>] ...

=head1 DESCRIPTION

Perl ExtUtils::MakeMaker utility is designed to write a Makefile for an
extension module from a Makefile.PL (at configure step). The rest of build
process is handled by C<make>. Typically, ExtUtils::MakeMaker build system can
be identified by presence of the F<Makefile.PL> script in the source directory.

=head1 DH_AUTO NOTES

Out of source tree building is not supported.

=head1 BUILD PROCESS

=cut

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

=head2 Configure step

=over

=item I<Behaviour>

Execute C<Makefile.PL> script passing C<INSTALLDIRS=vendor> and
C<create_packlist=0> parameters. Environment variables C<PERL_MM_USE_DEFAULT=1>
and C<PERL_AUTOINSTALL=--skipdeps> are exported before running the script.

=item I<Auto-selection>

If F<Makefile.PL> file exists but F<configure> does not exist in the source
directory.

=back

=cut
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

=head2 Build step

=over 4

=item I<Behaviour>

Execute C<make> in the build directory. See I<makefile> build system
documentation for more information.

=item I<Auto-selection>

Both F<Makefile.PL> and F<Makefile> exist in the source directory.

=back

=head2 Test step

=over 4

=item I<Behaviour>

Execute C<make test> in the source directory. See I<makefile> build system
documentation for more information.

=item I<Auto-selection>

Both F<Makefile.PL> and F<Makefile> exist in the source directory.

=back

=cut

=head2 Install step

=over 4

=item I<Behaviour>

Execute C<make install DESTDIR=$destdir PREFIX=/usr> in the source directory
with $destdir set to the appropriate temporary installation directory. See
I<makefile> build system documentation for more information.

=item I<Auto-selection>

Both F<Makefile.PL> and F<Makefile> exist in the source directory.

=back

=cut
sub install {
	my $this=shift;
	my $destdir=shift;
	$this->SUPER::install($destdir, "PREFIX=/usr", @_);
}

=head2 Clean step

=over 4

=item I<Behaviour>

Execute C<make distclean> in the source directory. See I<makefile> build system
documentation for more information.

=item I<Auto-selection>

Both F<Makefile.PL> and F<Makefile> exist in the source directory.

=back

=head1 SEE ALSO

L<dh_auto_makefile(7)>

L<dh_auto(7)>

=head1 AUTHORS

 Joey Hess <joeyh@debian.org>
 Modestas Vainius <modestas@vainius.eu>

=cut

1;
