# Defines debhelper buildsystem class interface and implementation
# of common functionality.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem;

use strict;
use warnings;
use Cwd;
use File::Spec;
use Debian::Debhelper::Dh_Lib;

# Cache DEB_BUILD_GNU_TYPE value. Performance hit of multiple
# invocations is noticable when listing buildsystems.
our $DEB_BUILD_GNU_TYPE = dpkg_architecture_value("DEB_BUILD_GNU_TYPE");

# Build system name. Defaults to the last component of the class
# name. Do not override this method unless you know what you are
# doing.
sub NAME {
	my $this=shift;
	my $class = ref($this) || $this;
	if ($class =~ m/^.+::([^:]+)$/) {
		return $1;
	}
	else {
		error("ınvalid buildsystem class name: $class");
	}
}

# Description of the build system to be shown to the users.
sub DESCRIPTION {
	error("class lacking a DESCRIPTION");
}

# Default build directory. Can be overriden in the derived
# class if really needed.
sub DEFAULT_BUILD_DIRECTORY {
	"obj-" . $DEB_BUILD_GNU_TYPE;
}

# Constructs a new build system object. Named parameters:
# - builddir -     specifies build directory to use. If not specified,
#                  in-source build will be performed. If undef or empty,
#                  DEFAULT_BUILD_DIRECTORY will be used.
# - build_action - set this parameter to the name of the build action
#                  if you want the object to determine its is_buidable
#                  status automatically (with check_auto_buildable()).
#                  Do not pass this parameter if is_buildable flag should
#                  be forced to true or set this parameter to undef if
#                  is_buildable flag should be false.
# Derived class can override the constructor to initialize common object
# parameters and execute commands to configure build environment if
# is_buildable flag is set on the object.
sub new {
	my ($class, %opts)=@_;

	my $this = bless({ builddir => undef, is_buildable => 1 }, $class);
	if (exists $opts{builddir}) {
		if ($opts{builddir}) {
			$this->{builddir} = $opts{builddir};
		}
		else {
			$this->{builddir} = $this->DEFAULT_BUILD_DIRECTORY();
		}
	}
	if (exists $opts{build_action}) {
		if (defined $opts{build_action}) {
			$this->{is_buildable} = $this->check_auto_buildable($opts{build_action});
		}
		else {
			$this->{is_buildable} = 0;
		}
	}
	return $this;
}

# Test is_buildable flag of the object.
sub is_buildable {
	my $this=shift;
	return $this->{is_buildable};
}

# This instance method is called to check if the build system is capable
# to auto build a source package. Additional argument $action describes
# which operation the caller is going to perform (either configure,
# build, test, install or clean). You must override this method for the
# build system module to be ever picked up automatically. This method is
# used in conjuction with @Dh_Buildsystems::BUILDSYSTEMS.
#
# This method is supposed to be called with source root directory being
# working directory. Use $this->get_buildpath($path) method to get full
# path to the files in the build directory.
sub check_auto_buildable {
	my $this=shift;
	my ($action) = @_;
	return 0;
}

# Derived class can call this method in its constructor
# to enforce in-source building even if the user requested otherwise.
sub enforce_in_source_building {
	my $this=shift;
	if ($this->{builddir}) {
		# Do not emit warning unless the object is buildable.
		if ($this->is_buildable()) {
			warning("warning: " . $this->NAME() .
			    " does not support building outside-source. In-source build enforced.");
		}
		$this->{builddir} = undef;
	}
}

# Derived class can call this method in its constructor to enforce
# outside-source building even if the user didn't request it.
sub enforce_outside_source_building {
	my ($this, $builddir) = @_;
	if (!defined $this->{builddir}) {
		$this->{builddir} = ($builddir && $builddir ne ".") ? $builddir : $this->DEFAULT_BUILD_DIRECTORY();
	}
}

# Get path to the specified build directory
sub get_builddir {
	my $this=shift;
	return $this->{builddir};
}

# Construct absolute path to the file from the given path that is relative
# to the build directory.
sub get_buildpath {
	my ($this, $path) = @_;
	if ($this->get_builddir()) {
		return File::Spec->catfile($this->get_builddir(), $path);
	}
	else {
		return File::Spec->catfile('.', $path);
	}
}

# When given a relative path in the source tree, converts it
# to the path that is relative to the build directory.
# If $path is not given, returns relative path to the root of the
# source tree from the build directory.
sub get_rel2builddir_path {
	my $this=shift;
	my $path=shift;

	if (defined $path) {
		$path = File::Spec->catfile(Cwd::getcwd(), $path);
	}
	else {
		$path = Cwd::getcwd();
	}
	if ($this->get_builddir()) {
		return File::Spec->abs2rel($path, Cwd::abs_path($this->get_builddir()));
	}
	return $path;
}

# Creates a build directory.
sub mkdir_builddir {
	my $this=shift;
	if ($this->get_builddir()) {
		doit("mkdir", "-p", $this->get_builddir());
	}
}

sub _cd {
	my ($this, $dir)=@_;
	if (! $dh{NO_ACT}) {
		verbose_print("cd $dir");
		chdir $dir or error("error: unable to chdir to $dir");
	}
}

# Changes working directory the build directory (if needed), calls doit(@_)
# and changes working directory back to the source directory.
sub doit_in_builddir {
	my $this=shift;
	if ($this->get_builddir()) {
		my $builddir = $this->get_builddir();
		my $sourcedir = $this->get_rel2builddir_path();
		$this->_cd($builddir);
		doit(@_);
		$this->_cd($sourcedir);
	}
	else {
		doit(@_);
	}
	return 1;
}

# In case of outside-source tree building, whole build directory
# gets wiped (if it exists) and 1 is returned. Otherwise, nothing
# is done and 0 is returned.
sub clean_builddir {
	my $this=shift;
	if ($this->get_builddir()) {
		if (-d $this->get_builddir()) {
			doit("rm", "-rf", $this->get_builddir());
		}
		return 1;
	}
	return 0;
}


# Instance method that is called before performing any action (see below).
# Action name is passed as an argument. Derived classes overriding this
# method should also call SUPER implementation of it.
sub pre_action {
	my $this=shift;
	my ($action)=@_;
}

# Instance method that is called after performing any action (see below).
# Action name is passed as an argument. Derived classes overriding this
# method should also call SUPER implementation of it.
sub post_action {
	my $this=shift;
	my ($action)=@_;
}

# The instance methods below provide support for configuring,
# building, testing, install and cleaning source packages.
# In case of failure, the method may just error() out.
#
# These methods should be overriden by derived classes to
# implement buildsystem specific actions needed to build the
# source. Arbitary number of custom action arguments might be
# passed. Default implementations do nothing.
sub configure {
	my $this=shift;
}

sub build {
	my $this=shift;
}

sub test {
	my $this=shift;
}

# destdir parameter specifies where to install files.
sub install {
	my $this=shift;
	my $destdir=shift;
}

sub clean {
	my $this=shift;
}

1;
