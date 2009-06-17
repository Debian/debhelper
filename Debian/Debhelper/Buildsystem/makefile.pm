# A debhelper build system class for handling simple Makefile based projects.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::makefile;

=head1 NAME

B<makefile> - make (Makefile)

=head1 SYNOPSIS

B<dh_auto_*> [B<--buildsystem>=I<makefile>] ...

=head1 DESCRIPTION

Makefile based projects use C<make> to control build process. C<make> utility
is the most popular tool on *NIX for building & installing packages from
source. It is also a basis for most other popular build systems. For example,
GNU Autoconf (autoconf) or CMake (cmake) generate F<Makefile>s during I<configure>
step and leave the rest of build process for C<make> to handle.

=head1 DH_AUTO NOTES

Since C<make> itself does not strictly define standard target names, a couple
of the most popular targets are tried for each building step. Whichever first
of them is discovered to exist, it is run. If neither of the tried targets
exist in the actual, the building step is assumed to have completed
successfully. However, if executed C<make> target fails, the respective dh_auto
program will fail too.

If MAKE environment variable is set, its value is executed rather than default
C<make> command.

Both in source (default) and out of source tree building modes are supported.
Either F<Makefile>, F<makefile> or F<GNUmakefile> file should be present in the
build directory for this debhelper build system to work.

=head1 BUILD PROCESS

=head2 Configure step

=over 4

=item I<Behaviour>

Do nothing (auto-selection continues).

=item I<Auto-selection>

It will never be auto-selected at this step.

=back

=cut

use strict;
use Debian::Debhelper::Dh_Lib qw(escape_shell);
use base 'Debian::Debhelper::Buildsystem';

sub get_makecmd_C {
	my $this=shift;
	my $buildpath = $this->get_buildpath();
	if ($buildpath ne '.') {
		return $this->{makecmd} . " -C " . escape_shell($buildpath);
	}
	return $this->{makecmd};
}

sub exists_make_target {
	my ($this, $target) = @_;
	my $makecmd=$this->get_makecmd_C();

	# Use make -n to check to see if the target would do
	# anything. There's no good way to test if a target exists.
	my $ret=`$makecmd -s -n --no-print-directory $target 2>/dev/null`;
	chomp $ret;
	return length($ret);
}

sub make_first_existing_target {
	my $this=shift;
	my $targets=shift;

	foreach my $target (@$targets) {
		if ($this->exists_make_target($target)) {
			$this->doit_in_builddir($this->{makecmd}, $target, @_);
			return $target;
		}
	}
	return undef;
}

sub DESCRIPTION {
	"simple Makefile"
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->{makecmd} = (exists $ENV{MAKE}) ? $ENV{MAKE} : "make";
	return $this;
}

sub check_auto_buildable {
	my $this=shift;
	my ($step) = @_;

	# Handles build, test, install, clean; configure - next class
	if (grep /^\Q$step\E$/, qw{build test install clean}) {
		# This is always called in the source directory, but generally
		# Makefiles are created (or live) in the the build directory.
		return -e $this->get_buildpath("Makefile") ||
		       -e $this->get_buildpath("makefile") ||
		       -e $this->get_buildpath("GNUmakefile");
	}
	return 0;
}

=head2 Build step

=over 4

=item I<Behaviour>

Execute C<make> (without arguments) with working directory changed to the build
directory.

=item I<Auto-selection>

If either F<Makefile>, F<makefile> or F<GNUmakefile> exists in the build
directory, but F<Makefile.PL> does not exist in the source directory.

=back

=cut
sub build {
	my $this=shift;
	$this->doit_in_builddir($this->{makecmd}, @_);
}

=head2 Test step

=over 4

=item I<Behaviour>

Try to C<make> either I<test> or I<check> target (the first existing one) with
working directory changed to the build directory.

=item I<Auto-selection>

If either F<Makefile>, F<makefile> or F<GNUmakefile> exists in the build
directory, but F<Makefile.PL> does not exist in the source directory.

=back

=cut
sub test {
	my $this=shift;
	$this->make_first_existing_target(['test', 'check'], @_);
}

=head2 Install step

=over 4

=item I<Behaviour>

Try to run C<make install DESTDIR=$destdir> with working directory changed to
the build directory. $desdir is the path to the appropriate temporary
installation directory under debian/ (see L<dh_auto_install(1)>).

=item I<Auto-selection>

If either F<Makefile>, F<makefile> or F<GNUmakefile> exists in the build
directory, but F<Makefile.PL> does not exist in the source directory.

=back

=cut
sub install {
	my $this=shift;
	my $destdir=shift;
	$this->make_first_existing_target(['install'], "DESTDIR=$destdir", @_);
}

=head2 Clean step

=over 4

=item I<Behaviour>

When building in source, try to C<make> either I<distclean>, I<realclean> or
I<clean> target (the first existing one) in the source directory. When building
out of source tree, recursively remove the whole build directory.

=item I<Auto-selection>

If either F<Makefile>, F<makefile> or F<GNUmakefile> exists in the build
directory, but F<Makefile.PL> does not exist in the source directory.

=back

=cut
sub clean {
	my $this=shift;
	if (!$this->rmdir_builddir()) {
		$this->make_first_existing_target(['distclean', 'realclean', 'clean'], @_);
	}
}

=head1 SEE ALSO

L<dh_auto(7)>

=head1 AUTHORS

 Joey Hess <joeyh@debian.org>
 Modestas Vainius <modestas@vainius.eu>

=cut

1;
