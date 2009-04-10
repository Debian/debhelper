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

# XXX JEH I *like* this. Yay for factoring out ugly ugly stuff!
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

	# XXX JEH setting this env var is dodgy,
	# probably better to test if it exists with a default value.
	# (Factor out to helper function?)
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
		# XXX JEH why does get_buildpath need to be used 
		# here? is_buildable is run at the top of the source
		# directory, so -e 'Makefile' should be the same
		return -e $self->get_buildpath("Makefile") ||
		       -e $self->get_buildpath("makefile") ||
		       -e $self->get_buildpath("GNUmakefile");
	} else {
		# XXX JEH why return 1 here?
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

	# XXX JEH again with the setting the env var, see above..
	$ENV{MAKE}="make" unless exists $ENV{MAKE};
	my @params="DESTDIR=$destdir";

	# Special case for MakeMaker generated Makefiles.
	# XXX JEH This is a really unfortunate breaking of the
	# encapsulation of the perl_makefile module. Perhaps it would be
	# better for that module to contain some hack that injects that
	# test into this one?
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
