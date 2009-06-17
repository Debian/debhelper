# A debhelper build system class for building Python Distutils based
# projects. It prefers out of source tree building.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::python_distutils;

=head1 NAME

B<python_distutils> - Python Distutils (setup.py)

=head1 SYNOPSIS

B<dh_auto_*> [B<--buildsystem>=I<python_distutils>] ...

=head1 DESCRIPTION

Python Distribution Utilities (Distutils for short) is a standard Python build
system. It is used to package most of the Python modules in the source
distribution form. Typically, only two steps (build and install) are needed to
finish installation of the Distutils based Python module. This build system can
be typically identified by presence of the F<setup.py> in the source directory.

=head1 DH_AUTO NOTES

Out of source tree building is done by default but in source building is also
supported. PLEASE NOTE that B<default build directory> is B<$srcdir/build>
where $srcdir is a path to the source directory.

Due to design flaws of Distutils, it is not possible to set a B<custom> build
directory via command line arguments to F<setup.py>. Therefore, the same effect
is achieved by writing appropriate F<.pydistutils.cfg> file to the build
directory and pointing $HOME environment variable to the build directory.

=head1 BUILD PROCESS

=cut

use strict;
use Cwd ();
use Debian::Debhelper::Dh_Lib qw(error);
use base 'Debian::Debhelper::Buildsystem';

sub DESCRIPTION {
	"Python Distutils (setup.py)"
}

sub DEFAULT_BUILD_DIRECTORY {
	my $this=shift;
	return $this->_canonpath($this->get_sourcepath("build"));
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	# Out of source tree building is prefered.
	$this->enforce_out_of_source_building(@_);
	return $this;
}

sub check_auto_buildable {
	my $this=shift;
	return -e $this->get_sourcepath("setup.py");
}

sub not_our_cfg {
	my $this=shift;
	my $ret;
	if (open(my $cfg, $this->get_buildpath(".pydistutils.cfg"))) {
		$ret = not "# Created by dh_auto\n" eq <$cfg>;
		close DISTUTILSCFG;
	}
	return $ret;
}

sub create_cfg {
	my $this=shift;
	if (open(my $cfg, ">", $this->get_buildpath(".pydistutils.cfg"))) {
		print $cfg "# Created by dh_auto", "\n";
		print $cfg "[build]\nbuild-base=", $this->get_build_rel2sourcedir(), "\n";
		close $cfg;
		return 1;
	}
	return 0;
}

sub pre_building_step {
	my $this=shift;
	my $step=shift;

	return unless grep /$step/, qw(build install clean);

	# --build-base can only be passed to the build command. However,
	# it is always read from the config file (really weird design).
	# Therefore create such a cfg config file.
	if ($this->get_buildpath() ne $this->DEFAULT_BUILD_DIRECTORY()) {
		not $this->not_our_cfg() or
		    error("cannot set custom build directory: .pydistutils.cfg is in use");
		$this->mkdir_builddir();
		$this->create_cfg() or
		    error("cannot set custom build directory: unwritable .pydistutils.cfg");
		# Distutils reads $HOME/.pydistutils.cfg
		$ENV{HOME} = Cwd::abs_path($this->get_buildpath());
	}
}

sub setup_py {
	my $this=shift;
	my $act=shift;
	$this->doit_in_sourcedir("python", "setup.py", $act, @_);
}

=head2 Configure step

=over 4

=item I<Behaviour>

Do nothing but stop auto-selection process.

=item I<Auto-selection>

If neither F<configure>, F<Makefile.PL> exist, but F<setup.py> exists in the
source directory.

=back

=cut

=head2 Build step

=over 4

=item I<Behaviour>

Execute C<python setup.py build>.

=item I<Auto-selection>

If F<Makefile>, F<makefile> F<GNUmakefile> do not exist in the build directory
and F<setup.py> file exists in the source directory.

=back

=cut
sub build {
	my $this=shift;
	$this->setup_py("build", @_);
}

=head2 Test step

=over 4

=item I<Behaviour>

Do nothing but stop auto-selection process.

=item I<Auto-selection>

F<Makefile>, F<makefile>, F<GNUmakefile> do not exist in the build directory and
F<setup.py> file exists in the source directory.

=back

=cut

=head2 Install step

=over 4

=item I<Behaviour>

Execute C<python setup.py install> passing temporary installation directory via
C<--root> parameter. C<--no-compile> and C<-O0> parameters are also passed by
default. See L<dh_auto_install(1)> for more information.

=item I<Auto-selection>

F<Makefile>, F<makefile>, F<GNUmakefile> do not exist in the build directory and
F<setup.py> file exists in the source directory.

=back

=cut
sub install {
	my $this=shift;
	my $destdir=shift;
	$this->setup_py("install", "--root=$destdir", "--no-compile", "-O0", @_);
}

=head2 Clean step

=over 4

=item I<Behaviour>

Execute C<python setup.py clean -a>. Additional parameters (if specified) are
passed to the latter command. F<.pydistutils.cfg> is also removed if it was
created (together with the build directory if it is ends up empty). Finally,
recursively find and delete all *.pyc files from the source directory.

=item I<Auto-selection>

F<Makefile>, F<makefile>, F<GNUmakefile> do not exist in the build directory and
F<setup.py> file exists in the source directory.

=back

=cut
sub clean {
	my $this=shift;
	$this->setup_py("clean", "-a", @_);

	# Config file will remain if it was created by us
	if (!$this->not_our_cfg()) {
		unlink($this->get_buildpath(".pydistutils.cfg"));
		$this->rmdir_builddir(1); # only if empty
	}
	# The setup.py might import files, leading to python creating pyc
	# files.
	$this->doit_in_sourcedir('find', '.', '-name', '*.pyc', '-exec', 'rm', '{}', ';');
}

=head1 SEE ALSO

L<dh_auto(7)>

=head1 AUTHORS

 Joey Hess <joeyh@debian.org>
 Modestas Vainius <modestas@vainius.eu>

=cut

1;
