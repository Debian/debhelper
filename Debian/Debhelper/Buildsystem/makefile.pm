# A buildsystem plugin for handling simple Makefile based projects.
#
# Copyright: © 2008 Joey Hess
#            © 2008-2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Buildsystem::makefile;

use strict;
use Debian::Debhelper::Dh_Lib;
use Debian::Debhelper::Dh_Buildsystem_Bases;
use base 'Debian::Debhelper::Dh_Buildsystem_Chdir';

sub _exists_make_target {
	my ($cls, $target) = @_;
	# Use make -n to check to see if the target would do
	# anything. There's no good way to test if a target exists.
	my $ret=`$ENV{MAKE} -s -n $target 2>/dev/null`;
	chomp $ret;
	return length($ret);
}

sub _make_first_existing_target {
	my $cls = shift;
	my $targets = shift;

	$ENV{MAKE}="make" unless exists $ENV{MAKE};
	foreach my $target (@$targets) {
		if ($cls->_exists_make_target($target)) {
			doit($ENV{MAKE}, $target, @_);
			return $target;
		}
	}
	return undef;
}

sub DESCRIPTION {
	"support for building Makefile based packages (make && make install)"
}

sub is_buildable {
	my $self=shift;
	my ($action) = @_;
	if (grep /^\Q$action\E$/, qw{build test install clean}) {
		return -e $self->get_buildpath("Makefile") ||
		       -e $self->get_buildpath("makefile") ||
		       -e $self->get_buildpath("GNUmakefile");
	} else {
		return 1;
	}
}

sub build_impl {
	my $self=shift;
	doit(exists $ENV{MAKE} ? $ENV{MAKE} : "make", @_);
}

sub test_impl {
	my $self=shift;
	$self->_make_first_existing_target(['test', 'check'], @_);
}

sub install_impl {
	my $self=shift;
	my $destdir=shift;

	$ENV{MAKE}="make" unless exists $ENV{MAKE};
	my @params="DESTDIR=$destdir";

	# Special case for MakeMaker generated Makefiles.
	if (-e "Makefile" &&
	    system('grep -q "generated automatically by MakeMaker" Makefile') == 0) {
		push @params, "PREFIX=/usr";
	}

	$self->_make_first_existing_target(['install'], @params, @_);
}

sub clean_impl {
	my $self=shift;
	$self->_make_first_existing_target(['distclean', 'realclean', 'clean'], @_);
}

1;
