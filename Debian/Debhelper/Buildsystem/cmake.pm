# A debhelper build system class for handling CMake based projects.
# It prefers out of source tree building.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::cmake;

=head1 NAME

B<cmake> - CMake (CMakeLists.txt)

=head1 SYNOPSIS

B<dh_auto_*> [B<--buildsystem>=I<cmake>] ...

=head1 DESCRIPTION

CMake is a family of tools designed to build, test and package software. CMake
generates F<Makefile>s and other temporary files in the build directory from
the directives present in the F<CMakeLists.txt> and a couple of other build
system source files. Then a standard set of make targets needs to be executed
in the build directory to complete source building process. CMake is available
in the cmake package that is essential throughout the whole build process.

=head1 DH_AUTO NOTES

Out of source tree building is done by default if this debhelper build system
is selected. This is due to the fact that there is no way to properly clean up
build directory from temporary files unless it is removed completely.
Therefore I<clean> step cannot be fully implemented if building is done in
source. However, the user may still enable in source building by explicitly
specifying a build directory path that is equal to the source directory path.

=head1 BUILD PROCESS

=cut

use strict;
use base 'Debian::Debhelper::Buildsystem::makefile';

sub DESCRIPTION {
	"CMake (CMakeLists.txt)"
}

sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;
	my $ret = -e $this->get_sourcepath("CMakeLists.txt");
	$ret &&= $this->SUPER::check_auto_buildable(@_) if $step ne "configure";
	return $ret;
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	# Prefer out of source tree building.
	$this->enforce_out_of_source_building(@_);
	return $this;
}

=head2 Configure step

=over 4

=item I<Behaviour>

Execute C<cmake> in the build directory passing a path to the source directory
and defining the following flags:

 -DCMAKE_INSTALL_PREFIX=/usr
 -DCMAKE_SKIP_RPATH=ON
 -DCMAKE_VERBOSE_MAKEFILE=ON

=item I<Auto-selection>

If F<CMakeLists.txt> file exists but neither F<configure>, F<Makefile.PL>,
F<setup.py> or F<Build.PL> exist in the source directory.

=back

=cut
sub configure {
	my $this=shift;
	my @flags;

	# Standard set of cmake flags
	push @flags, "-DCMAKE_INSTALL_PREFIX=/usr";
	push @flags, "-DCMAKE_SKIP_RPATH=ON";
	push @flags, "-DCMAKE_VERBOSE_MAKEFILE=ON";

	$this->mkdir_builddir();
	$this->doit_in_builddir("cmake", $this->get_source_rel2builddir(), @flags);
}

=head2 Build step

=over 4

=item I<Behaviour>

Execute C<make> in the build directory. See I<makefile> build system documentation
for more information.

=item I<Auto-selection>

It is normal for the I<makefile> build system to be auto-selected at this step.

=back

=head2 Test step

=over 4

=item I<Behaviour>

Execute C<make test> in the build directory. See I<makefile> build system
documentation for more information.

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

Remove the build directory if building out of source tree (complete clean up)
or execute C<make clean> if building in source (incomplete clean up). See
I<makefile> build system documentation for more information.

=item I<Auto-selection>

It is normal for the I<makefile> build system to be auto-selected at this step.

=back

=head1 SEE ALSO

L<dh_auto_makefile(7)>

L<dh_auto(7)>

=head1 AUTHORS

 Modestas Vainius <modestas@vainius.eu>

=cut

1;
