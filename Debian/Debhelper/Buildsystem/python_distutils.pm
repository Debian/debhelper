# A debhelper build system class for building Python Distutils based
# projects. It prefers out of source tree building.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::python_distutils;

use strict;
use warnings;
use Cwd ();
use Debian::Debhelper::Dh_Lib qw(error);
use parent qw(Debian::Debhelper::Buildsystem);

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
	# Out of source tree building is preferred.
	$this->prefer_out_of_source_building(@_);
	return $this;
}

sub check_auto_buildable {
	my $this=shift;
	return -e $this->get_sourcepath("setup.py") ? 1 : 0;
}

sub not_our_cfg {
	my $this=shift;
	my $ret;
	if (open(my $cfg, '<', $this->get_buildpath(".pydistutils.cfg"))) {
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

sub dbg_build_needed {
	my $this=shift;
	my $act=shift;

	# Return a list of python-dbg package which are listed
	# in the build-dependencies. This is kinda ugly, but building
	# dbg extensions without checking if they're supposed to be
	# built may result in various FTBFS if the package is not
	# built in a clean chroot.

	my @dbg;
	open (my $fd, '<', 'debian/control') ||
		error("cannot read debian/control: $!\n");
	foreach my $builddeps (join('', <$fd>) =~
			/^Build-Depends[^:]*:.*\n(?:^[^\w\n].*\n)*/gmi) {
		while ($builddeps =~ /(python[^, ]*-dbg)/g) {
			push @dbg, $1;
		}
	}

	close($fd);
	return @dbg;

}

sub setup_py {
	my $this=shift;
	my $act=shift;

	# We need to to run setup.py with the default python last
	# as distutils/setuptools modifies the shebang lines of scripts.
	# This ensures that #!/usr/bin/python is installed last and
	# not pythonX.Y
	# Take into account that the default Python must not be in
	# the requested Python versions.
	# Then, run setup.py with each available python, to build
	# extensions for each.

	my $python_default = `pyversions -d`;
	if ($? == -1) {
		error("failed to run pyversions")
	}
	my $ecode = $? >> 8;
	if ($ecode != 0) {
		error("pyversions -d failed [$ecode]")
	}
	$python_default =~ s/^\s+//;
	$python_default =~ s/\s+$//;
	my @python_requested = split ' ', `pyversions -r`;
	if ($? == -1) {
		error("failed to run pyversions")
	}
	$ecode = $? >> 8;
	if ($ecode != 0) {
		error("pyversions -r failed [$ecode]")
	}
	if (grep /^\Q$python_default\E/, @python_requested) {
		@python_requested = (
			grep(!/^\Q$python_default\E/, @python_requested),
			"python",
		);
	}

	my @python_dbg;
	my @dbg_build_needed = $this->dbg_build_needed();
	foreach my $python (map { $_."-dbg" } @python_requested) {
		if (grep /^(python-all-dbg|\Q$python\E)/, @dbg_build_needed) {
			push @python_dbg, $python;
		}
		elsif (($python eq "python-dbg")
		       and (grep /^\Q$python_default\E/, @dbg_build_needed)) {
			push @python_dbg, $python_default."-dbg";
		}
	}

	foreach my $python (@python_dbg, @python_requested) {
		if (-x "/usr/bin/".$python) {
			# To allow backports of debhelper we don't pass
			# --install-layout=deb to 'setup.py install` for
			# those Python versions where the option is
			# ignored by distutils/setuptools.
			if ( $act eq "install" and not
			     ( ($python =~ /^python(?:-dbg)?$/
			         and $python_default =~ /^python2\.[2345]$/)
			      or $python =~ /^python2\.[2345](?:-dbg)?$/ )) {
				$this->doit_in_sourcedir($python, "setup.py",
						$act, @_, "--install-layout=deb");
			}
			else {
				$this->doit_in_sourcedir($python, "setup.py",
						$act, @_);
			}
		}
	}
}

sub build {
	my $this=shift;
	$this->setup_py("build",
		"--force",
		@_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	$this->setup_py("install",
		"--force",
		"--root=$destdir",
		"--no-compile",
		"-O0",
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
	$this->doit_in_sourcedir('find', '.', '-name', '*.pyc', '-exec', 'rm', '{}', '+');
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
