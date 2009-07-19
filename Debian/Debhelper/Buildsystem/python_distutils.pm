# A debhelper build system class for building Python Distutils based
# projects. It prefers out of source tree building.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::python_distutils;

use strict;
use Cwd ();
use Debian::Debhelper::Dh_Lib qw(error);
use base 'Debian::Debhelper::Buildsystem';

sub DESCRIPTION {
	"Python Distutils (setup.py)"
}

sub DEFAULT_BUILD_DIRECTORY {
	my $this=shift;
	return $this->canonpath($this->get_sourcepath("build"));
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	# Out of source tree building is prefered.
	$this->prefer_out_of_source_building(@_);
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
		close $cfg;
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

	if ($this->get_buildpath() ne $this->DEFAULT_BUILD_DIRECTORY()) {
		# --build-base can only be passed to the build command. However,
		# it is always read from the config file (really weird design).
		# Therefore create such a cfg config file.
		# See http://bugs.python.org/issue818201
		#     http://bugs.python.org/issue1011113
		not $this->not_our_cfg() or
		    error("cannot set custom build directory: .pydistutils.cfg is in use");
		$this->mkdir_builddir();
		$this->create_cfg() or
		    error("cannot set custom build directory: unwritable .pydistutils.cfg");
		# Distutils reads $HOME/.pydistutils.cfg
		$ENV{HOME} = Cwd::abs_path($this->get_buildpath());
	}

	$this->SUPER::pre_building_step($step);
}

sub setup_py {
	my $this=shift;
	my $act=shift;
	my $python_default = `pyversions -d`;
	$python_default =~ s/^\s+//;
	$python_default =~ s/\s+$//;

	# We need to to run setup.py with the default python first
	# as distutils/setuptools modifies the shebang lines of scripts.
	# This ensures that #!/usr/bin/python is used and not pythonX.Y
	$this->doit_in_sourcedir("python", "setup.py", $act, @_);
	for my $python (grep(!/^$python_default/, (split ' ', `pyversions -r 2>/dev/null`))) {
		if (-x "/usr/bin/" . $python) {
			$this->doit_in_sourcedir($python, "setup.py", $act, @_);
		}
	}
}

sub build {
	my $this=shift;
	$this->setup_py("build", @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	$this->setup_py("install",
		"--root=$destdir",
		"--no-compile",
		"-O0",
		"--install-layout=deb",
		@_);
}

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

1
