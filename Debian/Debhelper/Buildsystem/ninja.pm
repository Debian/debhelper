# A debhelper build system class for handling ninja based projects.
#
# Copyright: © 2017 Michael Biebl
# License: GPL-2+

package Debian::Debhelper::Buildsystem::ninja;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(%dh dpkg_architecture_value);
use parent qw(Debian::Debhelper::Buildsystem);

sub DESCRIPTION {
	"Ninja (build.ninja)"
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->{buildcmd} = "ninja";
	return $this;
}

sub check_auto_buildable {
	my $this=shift;
	my ($step) = @_;

	if (-e $this->get_buildpath("build.ninja"))
	{
		# This is always called in the source directory, but generally
		# Ninja files are created (or live) in the build directory.
		return 1;
	} elsif ($step eq "clean" && defined $this->get_builddir() &&
	         $this->check_auto_buildable("configure"))
	{
		# Assume that the package can be cleaned (i.e. the build directory can
		# be removed) as long as it is built out-of-source tree and can be
		# configured. This is useful for derivative buildsystems which
		# generate Ninja files.
		return 1;
	}
	return 0;
}

sub build {
	my $this=shift;

	if (!$dh{QUIET}) {
		unshift @_, "-v";
	}
	if ($this->get_parallel() > 0) {
		unshift @_, "-j" . $this->get_parallel();
	}
	$this->doit_in_builddir($this->{buildcmd}, @_);
}

sub test {
	my $this=shift;

	if ($this->get_parallel() > 0) {
		$ENV{MESON_TESTTHREADS}=$this->get_parallel();
	}
	$this->doit_in_builddir($this->{buildcmd}, "test", @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;

	$ENV{DESTDIR}=$destdir;
	$this->doit_in_builddir($this->{buildcmd}, "install", @_);
}

sub clean {
	my $this=shift;

	if (!$this->rmdir_builddir()) {
		$this->doit_in_builddir($this->{buildcmd}, "clean", @_);
	}
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
