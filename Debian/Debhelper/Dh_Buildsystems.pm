# A module for loading and managing debhelper buildsystem plugins.
# This module is intended to be used by all dh_auto_* helper commands.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Dh_Buildsystems;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib;

use base 'Exporter';
our @EXPORT=qw(&buildsystems_init &buildsystems_do &load_buildsystem);

# XXX JEH as noted, this has to match historical order for back-compat
# XXX MDX Current dh_auto_* look like:
# configure: autotools, perl_makemaker, perl_build
# build:     makefile, python_distutils, perl_build
# test:      makefile, perl_build
# install:   makefile (with perl_makermaker) hack, python_distutils, perl_build
# clean:     makefile, python_distutils, perl_build
# So historical @BUILDSYSTEMS order (as per autodetection, see
# is_auto_buildable() of the respective classes):
#   autotools (+configure; the rest - next class)
#   python_distutils (+build +install +clean; the rest - next class)
#   perl_makemaker (+configure +install (special hack); the rest - next class)
#   makefile (+build +test +install +clean; configure - next class)
#   perl_build (handles everything)
# XXX JEH I think that makes sense..

# Historical order must be kept for backwards compatibility. New
# buildsystems MUST be added to the END of the list.
our @BUILDSYSTEMS = (
    "autotools",
    "python_distutils",
    "perl_makemaker",
    "makefile",
    "perl_build",
    "cmake",
);

sub create_buildsystem_instance {
	my $system=shift;
	my %bsopts=@_;
	my $module = "Debian::Debhelper::Buildsystem::$system";

	eval "use $module";
	if ($@) {
		error("unable to load buildsystem class '$system': $@");
	}

	if (!exists $bsopts{builddir} && exists $dh{BUILDDIR}) {
		$bsopts{builddir} = $dh{BUILDDIR};
	}
	return $module->new(%bsopts);
}

sub load_buildsystem {
	my ($action, $system)=@_;
	if (defined $system) {
		my $inst = create_buildsystem_instance($system);
		verbose_print("Selected buildsystem (specified): ".$inst->NAME());
		return $inst;
	}
	else {
		# Try to determine build system automatically
		for $system (@BUILDSYSTEMS) {
			my $inst = create_buildsystem_instance($system, is_auto=>1);
			if ($inst->is_auto_buildable($action)) {
				verbose_print("Selected buildsystem (auto): ". $inst->NAME());
				return $inst;
			}
		}
	}
	return;
}

sub list_buildsystems {
	for my $system (@BUILDSYSTEMS) {
		my $inst = create_buildsystem_instance($system);
		printf("%s - %s.\n", $inst->NAME(), $inst->DESCRIPTION());
	}
}

sub buildsystems_init {
	my %args=@_;

	# TODO: Not documented in the manual pages yet.
	# Initialize options from environment variables
	# XXX JEH I think these should be my variables, they are only used
	# inside this one file so putting them in the global %dh hash seems
	# unnecessary.
	if (exists $ENV{DH_AUTO_BUILDDIRECTORY}) {
		$dh{BUILDDIR} = $ENV{DH_AUTO_BUILDDIRECTORY};
	}
	if (exists $ENV{DH_AUTO_BUILDSYSTEM}) {
		$dh{BUILDSYS} = $ENV{DH_AUTO_BUILDSYSTEM};
	}

	# Available command line options
	my $list_bs = sub { list_buildsystems(); exit 0 };
	my $set_builddir = sub { $dh{BUILDDIR} = $_[1] };
	my %options = (
	    "b:s" => $set_builddir,
	    "build-directory:s" => $set_builddir,
	    "builddirectory:s" => $set_builddir,

	    "m=s" => \$dh{BUILDSYS},
	    "build-system=s" => \$dh{BUILDSYS},
	    "buildsystem=s" => \$dh{BUILDSYS},

	    "l" => $list_bs,
	    "--list" => $list_bs,
	);
	map { $args{options}{$_} = $options{$_} } keys(%options);
	Debian::Debhelper::Dh_Lib::init(%args);
}

sub buildsystems_do {
	my $action=shift;

	if (!defined $action) {
		$action = basename($0);
		$action =~ s/^dh_auto_//;
	}

	if (grep(/^\Q$action\E$/, qw{configure build test install clean}) == 0) {
		error("unrecognized auto action: ".basename($0));
	}

	my $buildsystem = load_buildsystem($action, $dh{BUILDSYS});
	if (defined $buildsystem) {
		$buildsystem->pre_action($action);
		$buildsystem->$action(@_, @{$dh{U_PARAMS}});
		$buildsystem->post_action($action);
	}
	return 0;
}

1;
