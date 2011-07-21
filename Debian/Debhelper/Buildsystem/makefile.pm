# A debhelper build system class for handling simple Makefile based projects.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::makefile;

use strict;
use Debian::Debhelper::Dh_Lib qw(escape_shell clean_jobserver_makeflags);
use base 'Debian::Debhelper::Buildsystem';

sub exists_make_target {
	my ($this, $target) = @_;

	# Use make -n to check to see if the target would do
	# anything. There's no good way to test if a target exists.
	my @opts=("-s", "-n", "--no-print-directory");
	my $buildpath = $this->get_buildpath();
	unshift @opts, "-C", $buildpath if $buildpath ne ".";
	open(SAVEDERR, ">&STDERR");
	open(STDERR, ">/dev/null");
	open(MAKE, "-|", $this->{makecmd}, @opts, $target);
	my $output=<MAKE>;
	chomp $output;
	close MAKE;
	open(STDERR, ">&SAVEDERR");
	return defined $output && length $output;
}

sub do_make {
	my $this=shift;

	# Avoid possible warnings about unavailable jobserver,
	# and force make to start a new jobserver.
	clean_jobserver_makeflags();

	# Note that this will override any -j settings in MAKEFLAGS.
	unshift @_, "-j" . ($this->get_parallel() > 0 ? $this->get_parallel() : "");

	$this->doit_in_builddir($this->{makecmd}, @_);
}

sub make_first_existing_target {
	my $this=shift;
	my $targets=shift;

	foreach my $target (@$targets) {
		if ($this->exists_make_target($target)) {
			$this->do_make($target, @_);
			return $target;
		}
	}
	return undef;
}

sub DESCRIPTION {
	"simple Makefile"
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->{makecmd} = (exists $ENV{MAKE}) ? $ENV{MAKE} : "make";
	return $this;
}

sub check_auto_buildable {
	my $this=shift;
	my ($step) = @_;

	if (-e $this->get_buildpath("Makefile") ||
	    -e $this->get_buildpath("makefile") ||
	    -e $this->get_buildpath("GNUmakefile"))
	{
		# This is always called in the source directory, but generally
		# Makefiles are created (or live) in the the build directory.
		return 1;
	} elsif ($step eq "clean" && defined $this->get_builddir() &&
	         $this->check_auto_buildable("configure"))
	{
		# Assume that the package can be cleaned (i.e. the build directory can
		# be removed) as long as it is built out-of-source tree and can be
		# configured. This is useful for derivative buildsystems which
		# generate Makefiles.
		return 1;
	}
	return 0;
}

sub build {
	my $this=shift;
	$this->do_make(@_);
}

sub test {
	my $this=shift;
	$this->make_first_existing_target(['test', 'check'], @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;
	$this->make_first_existing_target(['install'], "DESTDIR=$destdir", @_);
}

sub clean {
	my $this=shift;
	if (!$this->rmdir_builddir()) {
		$this->make_first_existing_target(['distclean', 'realclean', 'clean'], @_);
	}
}

1
