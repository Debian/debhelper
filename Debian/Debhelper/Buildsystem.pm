# Defines debhelper buildsystem class interface and implementation
# of common functionality.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem;

use strict;
use warnings;
use Cwd ();
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
# - sourcedir-     specifies source directory (relative to the current (top)
#                  directory) where the sources to be built live. If not
#                  specified or empty, defaults to the current directory.
# - builddir -     specifies build directory to use. Path is relative to the
#                  source directory unless it starts with ./, then it is
#                  assumed to be relative to the top directory. If undef or
#                  empty, DEFAULT_BUILD_DIRECTORY relative to the source
#                  directory will be used. If not specified, in source build
#                  will be attempted.
# - build_step -   set this parameter to the name of the build step
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

	my $this = bless({ sourcedir => '.',
	                   builddir => undef,
	                   is_buildable => 1 }, $class);

	if (exists $opts{sourcedir}) {
		# Get relative sourcedir abs_path (without symlinks)
		my $curdir = Cwd::getcwd();
		my $abspath = Cwd::abs_path($opts{sourcedir});
		if (! -d $abspath || $abspath !~ /^\Q$curdir\E/) {
			error("Invalid or non-existing path to the source directory: ".$opts{sourcedir});
		}
		$this->{sourcedir} = File::Spec->abs2rel($abspath, $curdir);
	}
	if (exists $opts{builddir}) {
		if ($opts{builddir}) {
			if ($opts{builddir} =~ m!^\./(.*)!) {
				# Specified as relative to the current directory
				$this->{builddir} = $1;
			}
			else {
				# Specified as relative to the source directory
				$this->{builddir} = $this->_canonpath($this->get_sourcepath($opts{builddir}));
			}
		}
		else {
			# Relative to the source directory by default
			$this->{builddir} = $this->get_sourcepath($this->DEFAULT_BUILD_DIRECTORY());
		}
	}
	if (exists $opts{build_step}) {
		if (defined $opts{build_step}) {
			$this->{is_buildable} = $this->check_auto_buildable($opts{build_step});
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
# to auto build a source package. Additional argument $step describes
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
	my ($step) = @_;
	return 0;
}

# Derived class can call this method in its constructor
# to enforce in source building even if the user requested otherwise.
sub enforce_in_source_building {
	my $this=shift;
	if ($this->{builddir}) {
		# Do not emit warning unless the object is buildable.
		if ($this->is_buildable()) {
			warning("warning: " . $this->NAME() .
			    " does not support building out of source tree. In source building enforced.");
		}
		$this->{builddir} = undef;
	}
}

# Derived class can call this method in its constructor to enforce
# out of source building even if the user didn't request it.
sub enforce_out_of_source_building {
	my ($this, $builddir) = @_;
	if (!defined $this->{builddir}) {
		$this->{builddir} = ($builddir && $builddir ne ".") ? $builddir : $this->DEFAULT_BUILD_DIRECTORY();
	}
}

# Enhanced version of File::Spec::canonpath. It collapses ..
# too so it may return invalid path if symlinks are involved.
# On the other hand, it does not need for the path to exist.
sub _canonpath {
	my ($this, $path)=@_;
	my @canon;
	my $back=0;
	for my $comp (split(m%/+%, $path)) {
		if ($comp eq '.') {
			next;
		}
		elsif ($comp eq '..') {
			if (@canon > 0) { pop @canon; }  else { $back++; }
		}
		else {
			push @canon, $comp;
		}
	}
	return (@canon + $back > 0) ? join('/', ('..')x$back, @canon) : '.';
}

# Given both $path and $base are relative to the same directory,
# converts and returns path of $path being relative the $base.
sub _rel2rel {
	my ($this, $path, $base, $root)=@_;
	$root = File::Spec->rootdir() if !defined $root;
	
	return File::Spec->abs2rel(
	    File::Spec->rel2abs($path, $root),
	    File::Spec->rel2abs($base, $root)
	);
}

# Get path to the source directory
# (relative to the current (top) directory)
sub get_sourcedir {
	my $this=shift;
	return $this->{sourcedir};
}

# Convert path relative to the source directory to the path relative
# to the current (top) directory.
sub get_sourcepath {
	my ($this, $path)=@_;
	return File::Spec->catfile($this->get_sourcedir(), $path);
}

# Get path to the build directory if it was specified
# (relative to the current (top) directory). undef otherwise.
sub get_builddir {
	my $this=shift;
	return $this->{builddir};
}

# Convert path that is relative to the build directory to the path
# that is relative to the current (top) directory.
# If $path is not specified, always returns build directory path
# relative to the current (top) directory regardless if builddir was
# specified or not.
sub get_buildpath {
	my ($this, $path)=@_;
	my $builddir = $this->get_builddir() || $this->get_sourcedir();
	if (defined $path) {
		return File::Spec->catfile($builddir, $path);
	}
	return $builddir;
}

# When given a relative path to the source directory, converts it
# to the path that is relative to the build directory. If $path is
# not given, returns a path to the source directory that is relative
# to the build directory.
sub get_source_rel2builddir {
	my $this=shift;
	my $path=shift;

	my $dir = '.';
	if ($this->get_builddir()) {
		$dir = $this->_rel2rel($this->get_sourcedir(), $this->get_builddir());
	}
	if (defined $path) {
		return File::Spec->catfile($dir, $path);
	}
	return $dir;
}

# When given a relative path to the build directory, converts it
# to the path that is relative to the source directory. If $path is
# not given, returns a path to the build directory that is relative
# to the source directory.
sub get_build_rel2sourcedir {
	my $this=shift;
	my $path=shift;

	my $dir = '.';
	if ($this->get_builddir()) {
		$dir = $this->_rel2rel($this->get_builddir(), $this->get_sourcedir());
	}
	if (defined $path) {
		return File::Spec->catfile($dir, $path);
	}
	return $dir;
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

# Changes working directory to the source directory (if needed)
# calls doit(@_) and changes working directory back to the top
# directory.
sub doit_in_sourcedir {
	my $this=shift;
	if ($this->get_sourcedir() ne '.') {
		my $sourcedir = get_sourcedir();
		my $curdir = Cwd::getcwd();
		$this->_cd($sourcedir);
		doit(@_);
		$this->_cd($this->_rel2rel($curdir, $sourcedir, $curdir));
	}
	else {
		doit(@_);
	}
	return 1;
}

# Changes working directory to the build directory (if needed),
# calls doit(@_) and changes working directory back to the top
# directory.
sub doit_in_builddir {
	my $this=shift;
	if ($this->get_buildpath() ne '.') {
		my $buildpath = $this->get_buildpath();
		my $curdir = Cwd::getcwd();
		$this->_cd($buildpath);
		doit(@_);
		$this->_cd($this->_rel2rel($curdir, $buildpath, $curdir));
	}
	else {
		doit(@_);
	}
	return 1;
}

# In case of out of source tree building, whole build directory
# gets wiped (if it exists) and 1 is returned. If build directory
# had 2 or more levels, empty parent directories are also deleted.
# If build directory does not exist, nothing is done and 0 is returned.
sub rmdir_builddir {
	my $this=shift;
	if ($this->get_builddir()) {
		my $buildpath = $this->get_buildpath();
		if (-d $buildpath && ! $dh{NO_ACT}) {
			doit("rm", "-rf", $buildpath);
			# If build directory had 2 or more levels, delete empty
			# parent directories until the source directory level.
			my @spdir = File::Spec->splitdir($this->get_build_rel2sourcedir());
			my $peek;
			pop @spdir;
			while (($peek=pop(@spdir)) && $peek ne '.' && $peek ne '..') {
				last if ! rmdir($this->get_sourcepath(File::Spec->catdir(@spdir, $peek)));
			}
		}
		return 1;
	}
	return 0;
}

# Instance method that is called before performing any step (see below).
# Action name is passed as an argument. Derived classes overriding this
# method should also call SUPER implementation of it.
sub pre_building_step {
	my $this=shift;
	my ($step)=@_;
}

# Instance method that is called after performing any step (see below).
# Action name is passed as an argument. Derived classes overriding this
# method should also call SUPER implementation of it.
sub post_building_step {
	my $this=shift;
	my ($step)=@_;
}

# The instance methods below provide support for configuring,
# building, testing, install and cleaning source packages.
# In case of failure, the method may just error() out.
#
# These methods should be overriden by derived classes to
# implement buildsystem specific steps needed to build the
# source. Arbitary number of custom step arguments might be
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
