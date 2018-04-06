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
	}
	return 0;
}

sub build {
	my $this=shift;
	my %options = (
		update_env => {
			'LC_ALL' => 'C.UTF-8',
		}
	);
	if (!$dh{QUIET}) {
		unshift @_, "-v";
	}
	if ($this->get_parallel() > 0) {
		unshift @_, "-j" . $this->get_parallel();
	}
	$this->doit_in_builddir(\%options, $this->{buildcmd}, @_);
}

sub test {
	my $this=shift;
	my %options = (
		update_env => {
			'LC_ALL' => 'C.UTF-8',
		}
	);
	if ($this->get_parallel() > 0) {
		$options{update_env}{MESON_TESTTHREADS} = $this->get_parallel();
	}
	$this->doit_in_builddir(\%options, $this->{buildcmd}, "test", @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	my %options = (
		update_env => {
			'LC_ALL'  => 'C.UTF-8',
			'DESTDIR' => $destdir,
		}
	);
	$this->doit_in_builddir(\%options, $this->{buildcmd}, "install", @_);
}

sub clean {
	my $this=shift;
	if (!$this->rmdir_builddir()) {
		my %options = (
			update_env => {
				'LC_ALL'  => 'C.UTF-8',
			}
		);
		$this->doit_in_builddir(\%options, $this->{buildcmd}, "clean", @_);
	}
}

1
