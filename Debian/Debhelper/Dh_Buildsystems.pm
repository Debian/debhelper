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
	# XXX JEH the $system param is never passed
	# by any call to this function
	# XXX MDX Yes, it was sort of redudant. But see buildsystems_do() now.
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

	# XXX JEH AFAICS, these 2 env variables are never used or documented
	# XXX MDX They are used (see below), not documented though.
	# TODO: Not documented in the manual pages yet.
	# Initialize options from environment variables
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

	# XXX JEH does this if ever not fire?
	# XXX MDX See dh_auto_install. I'm removing this anyway
	# and making buildsystem_init() call in dh_auto_* mandatory.

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

# XXX JEH generally, why does this need to be an OO object at all?
# The entire state stored in this object is o_dir and o_system;
# and the object is used as a singleton. So why not have a single sub
# that parses the command line, loads the specified system, and uses it,
# passing it the build directory. It would be both shorter and easier to
# understand.
# XXX I refactored this into a module rather than OO class. I do not agree
# about a single sub though as it is more complicated than that and
# I think it is more clear to have the code segmented a bit. See also
# dh_auto_install why both buildsystems_init() and buildsystems_do()
# are needed.

1;
