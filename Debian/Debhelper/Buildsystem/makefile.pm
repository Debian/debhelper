# A buildsystem plugin for handling simple Makefile based projects.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::makefile;

use strict;
use Debian::Debhelper::Dh_Lib;
use base 'Debian::Debhelper::Dh_Buildsystem_Basic';

sub get_makecmd_C {
	my $self=shift;
	if ($self->get_builddir()) {
		return $self->{makecmd} . " -C " . $self->get_builddir();
	}
	return $self->{makecmd};
}

# XXX JEH I *like* this. Yay for factoring out ugly ugly stuff!
# XXX MDX TODO: this could use dh debian/rules parser.
# XXX JEH That one checks for explicit only targets, while we want
#         implicit targets here too. I think the current code is ok;
#         it's a bonus that it checks if the target it empty.
#         Hmm, one problem is that if a target exists but will run no
#         commands since it's already built, the approach below will return
#         nothing and assume it doesn't exist.
sub exists_make_target {
	my ($self, $target) = @_;
	my $makecmd=$self->get_makecmd_C();

	# Use make -n to check to see if the target would do
	# anything. There's no good way to test if a target exists.
	my $ret=`$makecmd -s -n $target 2>/dev/null`;
	chomp $ret;
	return length($ret);
}

sub make_first_existing_target {
	my $self=shift;
	my $targets=shift;

	foreach my $target (@$targets) {
		if ($self->exists_make_target($target)) {
			$self->doit_in_builddir($self->{makecmd}, $target, @_);
			return $target;
		}
	}
	return undef;
}

sub DESCRIPTION {
	"support for building Makefile based packages (make && make install)"
}

sub new {
	my $cls=shift;
	my $self=$cls->SUPER::new(@_);
	$self->{makecmd} = (exists $ENV{MAKE}) ? $ENV{MAKE} : "make";
	return $self;
}

sub is_auto_buildable {
	my $self=shift;
	my ($action) = @_;

	# Handles build, test, install, clean; configure - next class
	if (grep /^\Q$action\E$/, qw{build test install clean}) {
		# This is always called in the source directory, but generally
		# Makefiles are created (or live) in the the build directory.
		return -e $self->get_buildpath("Makefile") ||
		       -e $self->get_buildpath("makefile") ||
		       -e $self->get_buildpath("GNUmakefile");
	}
	return 0;
}

sub build {
	my $self=shift;
	$self->doit_in_builddir($self->{makecmd}, @_);
}

sub test {
	my $self=shift;
	$self->make_first_existing_target(['test', 'check'], @_);
}

sub install {
	my $self=shift;
	my $destdir=shift;
	$self->make_first_existing_target(['install'], "DESTDIR=$destdir", @_);
}

sub clean {
	my $self=shift;
	if (!$self->clean_builddir()) {
		$self->make_first_existing_target(['distclean', 'realclean', 'clean'], @_);
	}
}

1;
