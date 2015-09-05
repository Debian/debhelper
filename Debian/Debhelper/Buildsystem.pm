# Defines debhelper build system class interface and implementation
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
		error("ınvalid build system class name: $class");
	}
}

# Description of the build system to be shown to the users.
sub DESCRIPTION {
	error("class lacking a DESCRIPTION");
}

# Default build directory. Can be overriden in the derived
# class if really needed.
sub DEFAULT_BUILD_DIRECTORY {
	"obj-" . dpkg_architecture_value("DEB_HOST_GNU_TYPE");
}

# Constructs a new build system object. Named parameters:
# - sourcedir-     specifies source directory (relative to the current (top)
#                  directory) where the sources to be built live. If not
#                  specified or empty, defaults to the current directory.
# - builddir -     specifies build directory to use. Path is relative to the
#                  current (top) directory. If undef or empty,
#                  DEFAULT_BUILD_DIRECTORY directory will be used.
# - parallel -     max number of parallel processes to be spawned for building
#                  sources (-1 = unlimited; 1 = no parallel)
# Derived class can override the constructor to initialize common object
# parameters. Do NOT use constructor to execute commands or otherwise
# configure/setup build environment. There is absolutely no guarantee the
# constructed object will be used to build something. Use pre_building_step(),
# $build_step() or post_building_step() methods for this.
sub new {
	my ($class, %opts)=@_;

	my $this = bless({ sourcedir => '.',
	                   builddir => undef,
	                   parallel => undef,
	                   cwd => Cwd::getcwd() }, $class);

	if (exists $opts{sourcedir}) {
		# Get relative sourcedir abs_path (without symlinks)
		my $abspath = Cwd::abs_path($opts{sourcedir});
		if (! -d $abspath || $abspath !~ /^\Q$this->{cwd}\E/) {
			error("invalid or non-existing path to the source directory: ".$opts{sourcedir});
		}
		$this->{sourcedir} = File::Spec->abs2rel($abspath, $this->{cwd});
	}
	if (exists $opts{builddir}) {
		$this->_set_builddir($opts{builddir});
	}
	if (defined $opts{parallel}) {
		$this->{parallel} = $opts{parallel};
	}
	return $this;
}

# Private method to set a build directory. If undef, use default.
# Do $this->{builddir} = undef or pass $this->get_sourcedir() to
# unset the build directory.
sub _set_builddir {
	my $this=shift;
	my $builddir=shift || $this->DEFAULT_BUILD_DIRECTORY;

	if (defined $builddir) {
		$builddir = $this->canonpath($builddir); # Canonicalize

		# Sanitize $builddir
		if ($builddir =~ m#^\.\./#) {
			# We can't handle those as relative. Make them absolute
			$builddir = File::Spec->catdir($this->{cwd}, $builddir);
		}
		elsif ($builddir =~ /\Q$this->{cwd}\E/) {
			$builddir = File::Spec->abs2rel($builddir, $this->{cwd});
		}

		# If build directory ends up the same as source directory, drop it
		if ($builddir eq $this->get_sourcedir()) {
			$builddir = undef;
		}
	}
	$this->{builddir} = $builddir;
	return $builddir;
}

# This instance method is called to check if the build system is able
# to build a source package. It will be called during the build
# system auto-selection process, inside the root directory of the debian
# source package. The current build step is passed as an argument.
# Return 0 if the source is not buildable, or a positive integer
# otherwise.
#
# Generally, it is enough to look for invariant unique build system
# files shipped with clean source to determine if the source might
# be buildable or not. However, if the build system is derived from
# another other auto-buildable build system, this method
# may also check if the source has already been built with this build
# system partitially by looking for temporary files or other common
# results the build system produces during the build process. The
# latter checks must be unique to the current build system and must
# be very unlikely to be true for either its parent or other build
# systems. If it is determined that the source has already built
# partitially with this build system, the value returned must be
# greater than the one of the SUPER call.
sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;
	return 0;
}

# Derived class can call this method in its constructor
# to enforce in source building even if the user requested otherwise.
sub enforce_in_source_building {
	my $this=shift;
	if ($this->get_builddir()) {
		$this->{warn_insource} = 1;
		$this->{builddir} = undef;
	}
}

# Derived class can call this method in its constructor to *prefer*
# out of source building. Unless build directory has already been
# specified building will proceed in the DEFAULT_BUILD_DIRECTORY or
# the one specified in the 'builddir' named parameter (which may
# match the source directory). Typically you should pass @_ from
# the constructor to this call.
sub prefer_out_of_source_building {
	my $this=shift;
	my %args=@_;
	if (!defined $this->get_builddir()) {
		if (!$this->_set_builddir($args{builddir}) && !$args{builddir}) {
			# If we are here, DEFAULT_BUILD_DIRECTORY matches
			# the source directory, building might fail.
			error("default build directory is the same as the source directory." .
			      " Please specify a custom build directory");
		}
	}
}

# Enhanced version of File::Spec::canonpath. It collapses ..
# too so it may return invalid path if symlinks are involved.
# On the other hand, it does not need for the path to exist.
sub canonpath {
	my ($this, $path)=@_;
	my @canon;
	my $back=0;
	foreach my $comp (split(m%/+%, $path)) {
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

# Given both $path and $base are relative to the $root, converts and
# returns path of $path being relative to the $base. If either $path or
# $base is absolute, returns another $path (converted to) absolute.
sub _rel2rel {
	my ($this, $path, $base, $root)=@_;
	$root = $this->{cwd} unless defined $root;

	if (File::Spec->file_name_is_absolute($path)) {
		return $path;
	}
	elsif (File::Spec->file_name_is_absolute($base)) {
		return File::Spec->rel2abs($path, $root);
	}
	else {
		return File::Spec->abs2rel(
			File::Spec->rel2abs($path, $root),
			File::Spec->rel2abs($base, $root)
		);
	}
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
# (relative to the current (top) directory). undef if the same
# as the source directory.
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

sub get_parallel {
	my $this=shift;
	return $this->{parallel};
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
	verbose_print("cd $dir");
	if (! $dh{NO_ACT}) {
		chdir $dir or error("error: unable to chdir to $dir");
	}
}

# Changes working directory to the source directory (if needed),
# calls print_and_doit(@_) and changes working directory back to the
# top directory.
sub doit_in_sourcedir {
	my $this=shift;
	if ($this->get_sourcedir() ne '.') {
		my $sourcedir = $this->get_sourcedir();
		$this->_cd($sourcedir);
		eval {
			print_and_doit(@_);
		};
		my $saved_exception = $@;
		$this->_cd($this->_rel2rel($this->{cwd}, $sourcedir));
		die $saved_exception if $saved_exception;
	}
	else {
		print_and_doit(@_);
	}
	return 1;
}

# Changes working directory to the source directory (if needed),
# calls print_and_doit(@_) and changes working directory back to the
# top directory. Errors are ignored.
sub doit_in_sourcedir_noerror {
        my $this=shift;
        my $ret;
        if ($this->get_sourcedir() ne '.') {
                my $sourcedir = $this->get_sourcedir();
                $this->_cd($sourcedir);
                $ret = print_and_doit_noerror(@_);
                $this->_cd($this->_rel2rel($this->{cwd}, $sourcedir));
        }
        else {
                $ret = print_and_doit_noerror(@_);
        }
        return $ret;
}

# Changes working directory to the build directory (if needed),
# calls print_and_doit(@_) and changes working directory back to the
# top directory.
sub doit_in_builddir {
	my $this=shift;
	if ($this->get_buildpath() ne '.') {
		my $buildpath = $this->get_buildpath();
		$this->_cd($buildpath);
		eval {
			print_and_doit(@_);
		};
		my $saved_exception = $@;
		$this->_cd($this->_rel2rel($this->{cwd}, $buildpath));
		die $saved_exception if $saved_exception;
	}
	else {
		print_and_doit(@_);
	}
	return 1;
}

# Changes working directory to the build directory (if needed),
# calls print_and_doit(@_) and changes working directory back to the
# top directory. Errors are ignored.
sub doit_in_builddir_noerror {
        my $this=shift;
        my $ret;
        if ($this->get_buildpath() ne '.') {
                my $buildpath = $this->get_buildpath();
                $this->_cd($buildpath);
                $ret = print_and_doit_noerror(@_);
                $this->_cd($this->_rel2rel($this->{cwd}, $buildpath));
        }
        else {
                $ret = print_and_doit_noerror(@_);
        }
        return $ret;
}

# In case of out of source tree building, whole build directory
# gets wiped (if it exists) and 1 is returned. If build directory
# had 2 or more levels, empty parent directories are also deleted.
# If build directory does not exist, nothing is done and 0 is returned.
sub rmdir_builddir {
	my $this=shift;
	my $only_empty=shift;
	if ($this->get_builddir()) {
		my $buildpath = $this->get_buildpath();
		if (-d $buildpath) {
			my @dir = File::Spec->splitdir($this->get_build_rel2sourcedir());
			my $peek;
			if (not $only_empty) {
				doit("rm", "-rf", $buildpath);
				pop @dir;
			}
			# If build directory is relative and had 2 or more levels, delete
			# empty parent directories until the source or top directory level.
			if (not File::Spec->file_name_is_absolute($buildpath)) {
				while (($peek=pop @dir) && $peek ne '.' && $peek ne '..') {
					my $dir = $this->get_sourcepath(File::Spec->catdir(@dir, $peek));
					doit("rmdir", "--ignore-fail-on-non-empty", $dir);
					last if -d $dir;
				}
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

	# Warn if in source building was enforced but build directory was
	# specified. See enforce_in_source_building().
	if ($this->{warn_insource}) {
		warning("warning: " . $this->NAME() .
		    " does not support building out of source tree. In source building enforced.");
		delete $this->{warn_insource};
	}
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
# implement build system specific steps needed to build the
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

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
