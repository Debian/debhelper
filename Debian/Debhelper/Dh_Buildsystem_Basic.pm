# Defines basic debhelper buildsystem class interface.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Dh_Buildsystem_Basic;

use strict;
use warnings;
use Cwd;
use File::Spec;
use Debian::Debhelper::Dh_Lib;

# Build system name. Defaults to the last component of the class
# name. Do not override this method unless you know what you are
# doing.
sub NAME {
	my $self=shift;
	my $cls = ref($self) || $self;
	if ($cls =~ m/^.+::([^:]+)$/) {
		return $1;
	}
	else {
		error("ınvalid buildsystem class name: $cls");
	}
}

# Description of the build system to be shown to the users.
sub DESCRIPTION {
	"basic debhelper build system class (please provide description)";
}

# Default build directory. Can be overriden in the derived
# class if really needed.
sub DEFAULT_BUILD_DIRECTORY {
	"obj-" . dpkg_architecture_value("DEB_BUILD_GNU_TYPE");
}

# Constructs a new build system object. Named parameters:
# - builddir - specifies build directory to use. If not specified,
#              in-source build will be performed. If undef or empty,
#              default DEFAULT_BUILD_DIRECTORY will be used.
# - is_auto -  might be used by the derived classes to determine if
#              the build system has been picked up automatically.
# Derived class can override the constructor to initialize common parameters.
# Constructor SHOULD NOT be used to initialize build environment because
# constructed class may not be eventually used to build the package (if e.g.
# is_auto_buildable() returns 0).
#
# XXX JEH the above comment begs the question: Why not test
# is_auto_buildable in the constructor, and only have the constructor
# succeed if it can handle the source? That would also eliminate the 
# delayed warning mess in enforce_in_source_building.
# AFAICS, there is only one reason you need an instance of the object
# if it can't build -- to list build systems. But that only needs
# DESCRIPTION and NAME, which could be considered to be class methods,
# rather than object methods -- no need to construct an instance of the
# class before calling those.
# I see that if --buildsystem is manually specified to override,
# the is_auto_buildable test is completely skipped. So if this change were
# made, you'd not be able to skip the test, and some --buildsystem choices
# might cause an error. OTOH, those seem to be cases where it would later
# fail anyway. The real use cases for --buildsystem, such as forcing use of
# cmake when there are both a CMakeLists.txt and a Makefile, would still
# work.
sub new {
	my ($cls, %opts)=@_;

	my $self = bless({ builddir => undef, is_auto => $opts{is_auto} }, $cls);
	if (exists $opts{builddir}) {
		if ($opts{builddir}) {
			$self->{builddir} = $opts{builddir};
		}
		else {
			$self->{builddir} = $self->DEFAULT_BUILD_DIRECTORY();
		}
	}
	return $self;
}

# This instance method is called to check if the build system is capable
# to auto build a source package. Additional argument $action describes
# which operation the caller is going to perform (either configure,
# build, test, install or clean). You must override this method for the
# build system module to be ever picked up automatically. This method is
# used in conjuction with @Dh_Buildsystems::BUILDSYSTEMS.
#
# This method is supposed to be called with source root directory being
# working directory. Use $self->get_buildpath($path) method to get full
# path to the files in the build directory.
sub is_auto_buildable {
	my $self=shift;
	my ($action) = @_;
	return 0;
}

# Derived class can call this method in its constructor
# to enforce in-source building even if the user requested otherwise.
sub enforce_in_source_building {
	my $self=shift;
	if ($self->{builddir}) {
		# Since this method is called in the constructor, emitting
		# warnings immediatelly may cause too much noise when
		# scanning for auto buildsystems or listing them.
		push @{$self->{warnings}},
		    $self->NAME()." buildsystem does not support building outside-source. In-source build enforced.";
		$self->{builddir} = undef;
	}
}

# Derived class can call this method in its constructor to enforce
# outside-source building even if the user didn't request it.
sub enforce_outside_source_building {
	my ($self, $builddir) = @_;
	if (!defined $self->{builddir}) {
		$self->{builddir} = ($builddir && $builddir ne ".") ? $builddir : $self->DEFAULT_BUILD_DIRECTORY();
	}
}

# Get path to the specified build directory
sub get_builddir {
	my $self=shift;
	return $self->{builddir};
}

# Construct absolute path to the file from the given path that is relative
# to the build directory.
sub get_buildpath {
	my ($self, $path) = @_;
	if ($self->get_builddir()) {
		return File::Spec->catfile($self->get_builddir(), $path);
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
	my $self=shift;
	my $path=shift;

	if (defined $path) {
		$path = File::Spec->catfile(Cwd::getcwd(), $path);
	}
	else {
		$path = Cwd::getcwd();
	}
	if ($self->get_builddir()) {
		return File::Spec->abs2rel($path, Cwd::abs_path($self->get_builddir()));
	}
	return $path;
}

sub _mkdir {
	my ($cls, $dir)=@_;
	if (-e $dir && ! -d $dir) {
		error("error: unable to create '$dir': object already exists and is not a directory");
	}
	elsif (! -d $dir) {
		verbose_print("mkdir '$dir'");
		if (! $dh{NO_ACT}) {
			mkdir($dir, 0755) or error("error: unable to create '$dir': $!");
		}
		return 1;
	}
	return 0;
}

sub _cd {
	my ($cls, $dir)=@_;
	if (! $dh{NO_ACT}) {
		chdir $dir or error("error: unable to chdir to $dir");
	}
}

# Creates a build directory. Returns 1 if the directory was created
# or 0 if it already exists or there is no need to create it.
sub mkdir_builddir {
	my $self=shift;
	if ($self->get_builddir()) {
		return $self->_mkdir($self->get_builddir());
	}
	return 0;
}

# Changes working directory the build directory (if needed), calls doit(@_)
# and changes working directory back to the source directory.
sub doit_in_builddir {
	my $self=shift;
	if ($self->get_builddir()) {
		my $builddir = $self->get_builddir();
		my $sourcedir = $self->get_rel2builddir_path();
		verbose_print("cd to the build directory: $builddir");
		$self->_cd($builddir);
		doit(@_);
		verbose_print("cd back to the source directory: $sourcedir");
		$self->_cd($sourcedir);
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
	my $self=shift;
	if ($self->get_builddir()) {
		if (-d $self->get_builddir()) {
			doit("rm", "-rf", $self->get_builddir());
		}
		return 1;
	}
	return 0;
}


# Instance method that is called before performing any action (see below).
# Action name is passed as an argument. Derived classes overriding this
# method should also call SUPER implementation of it.
sub pre_action {
	my $self=shift;
	my $action=shift;

	# Emit warnings pre action.
	if (exists $self->{warnings}) {
		for my $msg (@{$self->{warnings}}) {
			warning("warning: " . $msg);
		}
	}
}

# Instance method that is called after performing any action (see below).
# Action name is passed as an argument. Derived classes overriding this
# method should also call SUPER implementation of it.
sub post_action {
	my $self=shift;
	my $action=shift;
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
	my $self=shift;
}

sub build {
	my $self=shift;
}

sub test {
	my $self=shift;
}

# destdir parameter specifies where to install files.
sub install {
	my $self=shift;
	my $destdir=shift;
}

sub clean {
	my $self=shift;
}

1;
