# Defines base debhelper buildsystem class interface.
#
# Copyright: © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Dh_Buildsystem_Basic;

use Cwd;
use File::Spec;
use Debian::Debhelper::Dh_Lib;

# Build system name. Defaults to the last component of the package
# name. Do not override this method unless you know what you are
# doing.
sub NAME {
	my $self = shift;
	my $cls = ref($self) || $self;
	return ($cls =~ m/^.+::([^:]+)$/) ? $1 : "[invalid package name]";
}

# Description of the build system to be shown to the users.
sub DESCRIPTION {
	"basic debhelper build system class";
}

sub new {
	my ($cls, $builddir) = @_;
	my $self = bless({ builddir => $builddir }, $cls);
	if (!defined($builddir) || $builddir eq ".") {
		$self->{builddir} = undef;
	}
	return $self;
}

# This instance method is called to check if the build system is capable
# to build a source package. Additional argument $action describes which
# operation the caller is going to perform first (either configure,
# build, test, install or clean). You must override this method for the
# build system module to be ever picked up automatically.
#
# This method is supposed to be called with source root directory being
# working directory. Use $self->get_buildpath($path) method to get full
# path to the files in the build directory.
sub is_buildable {
	my $self=shift;
	my ($action) = @_;
	return 0;
}

# Derived class can call this method in its constructor
# to enforce in-source building even if the user
# requested otherwise.
sub enforce_in_source_building {
	my $self=shift;
	if ($self->{builddir}) {
		warning("warning: ".$self->NAME()." buildsystem does not support building outside-source. In-source build enforced.");
		$self->{builddir} = undef;
	}
}

sub get_builddir {
	my $self=shift;
	return $self->{builddir};
}

sub get_buildpath {
	my ($self, $path) = @_;
	if ($self->get_builddir()) {
		return File::Spec->catfile($self->get_builddir(), $path);
	}
	else {
		return File::Spec->catfile('.', $path);
	}
}

sub invoke_impl {
	my $self=shift;
	my $method=shift;

	return $self->$method(@_);
}

# The instance methods below provide support for configuring,
# building, testing, install and cleaning source packages.
# These methods are wrappers around respective *_impl() methods
# which are supposed to do real buildsystem specific work. 

sub configure {
	my $self=shift;
	return $self->invoke_impl('configure_impl', @_);
}

sub build {
	my $self=shift;
	return $self->invoke_impl('build_impl', @_);
}

sub test {
	my $self=shift;
	return $self->invoke_impl('test_impl', @_);
}

sub install {
	my $self=shift;
	return $self->invoke_impl('install_impl', @_);
}

sub clean {
	my $self=shift;
	return $self->invoke_impl('clean_impl', @_);
}

# The instance methods below should be overriden by derived classes
# to implement buildsystem specific actions needed to build the
# source. Arbitary number of custom action arguments might be passed.
# Default implementations do nothing.

sub configure_impl {
	my $self=shift;
	1;
}

sub build_impl {
	my $self=shift;
	1;
}

sub test_impl {
	my $self=shift;
	1;
}

# destdir parameter specifies where to install files.
sub install_impl {
	my $self=shift;
	my $destdir=shift;
	1;
}

sub clean_impl {
	my $self=shift;
	1;
}

package Debian::Debhelper::Dh_Buildsystem_Option;

use Debian::Debhelper::Dh_Buildsystems qw( DEFAULT_BUILD_DIRECTORY );
use base 'Debian::Debhelper::Dh_Buildsystem_Basic';

# Derived class can call this method in its constructor to enforce
# outside-source building even if the user didn't request it.
sub enforce_outside_source_building {
	my ($self, $builddir) = @_;
	if (!defined $self->{builddir}) {
		$self->{builddir} = ($builddir && $builddir ne ".") ? $builddir : DEFAULT_BUILD_DIRECTORY;
	}
}

# Constructs option to be passed to the source package buildsystem to
# change build directory. Returns nothing by default.
sub get_builddir_option {
	my $self=shift;
	return;
}

sub invoke_impl {
	my $self=shift;
	my $method=shift;

	if ($self->get_builddir_option()) {
		return $self->SUPER::invoke_impl($method, $self->get_builddir_option(), @_);
	}
	else {
		return $self->SUPER::invoke_impl($method, @_);
	}
}

package Debian::Debhelper::Dh_Buildsystem_Chdir;

use Cwd;
use File::Spec;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Dh_Buildsystem_Option';

sub new {
	my $cls=shift;
	my $self=$cls->SUPER::new(@_);
	$self->{topdir} = '.';
	return $self;
}

sub _cd {
	my ($cls, $dir) = @_;
	verbose_print("cd '$dir'");
	if (! $dh{NO_ACT}) {
		chdir $dir or error("error: unable to chdir to $dir");
	}
}

sub _mkdir {
	my ($cls, $dir) = @_;
	if (-e $dir && ! -d $dir) {
		error("error: unable to create '$dir': object already exists and is not a directory");
	}
	else {
		verbose_print("mkdir '$dir'");
		if (! $dh{NO_ACT}) {
			mkdir($dir, 0755) or error("error: unable to create '$dir': $!");
		}
		return 1;
	}
	return 0;
}

sub get_builddir {
	my $self=shift;
	if (defined $self->{builddir} && $self->{topdir} ne ".") {
		return File::Spec->catfile($self->{topdir}, $self->{builddir});
	}
	return $self->SUPER::get_builddir();
}

sub get_topdir {
	my $self=shift;
	if ($self->{topdir} ne ".") {
		return File::Spec->abs2rel($self->{topdir});
	}
	return $self->{topdir};
}

sub get_toppath {
	my ($self, $path) = @_;
	return File::Spec->catfile($self->get_topdir(), $path);
}

sub cd {
	my $self = shift;
	if ($self->get_builddir() && $self->{topdir} ne ".") {
		$self->_cd($self->get_topdir());
		$self->{topdir} = ".";
		return 1;
	}
	return 0;
}

sub cd_to_builddir {
	my $self = shift;
	if ($self->get_builddir() && $self->{topdir} eq ".") {
		$self->{topdir} = getcwd();
		$self->_cd($self->get_builddir());
		return 1;
	}
	return 0;
}

sub exec_in_topdir {
	my $self=shift;
	my $sub=shift;
	my $ret;

	if ($self->get_topdir() ne ".") {
		$self->cd();
		$ret = &$sub(@_);
		$self->cd_to_builddir();
	}
	else {
		$ret = &$sub(@_);
	}
	return $ret;
}

# *_impl() is run with current working directory changed to the
# build directory if requested.
sub invoke_impl {
	my $self=shift;
	my $method=shift;
	my $ret;

	$self->cd_to_builddir();
	$ret = $self->$method(@_);
	$self->cd();
	return $ret;
}

sub configure {
	my $self=shift;
	if ($self->get_builddir()) {
		$self->_mkdir($self->get_builddir());
	}
	return $self->SUPER::configure(@_);
}

# If outside-source tree building is done, whole build directory
# gets wiped out by default. Otherwise, clean_impl() is called.
sub clean {
	my $self=shift;
	if ($self->get_builddir()) {
		if (-d $self->get_builddir()) {
			$self->cd();
			doit("rm", "-rf", $self->get_builddir());
			return 1;
		}
	} else {
		return $self->SUPER::clean(@_);
	}
}

1;
