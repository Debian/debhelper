# A module for loading and managing debhelper build system classes.
# This module is intended to be used by all dh_auto_* programs.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Dh_Buildsystems;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib;
use File::Spec;

use Exporter qw(import);
our @EXPORT=qw(&buildsystems_init &buildsystems_do &load_buildsystem &load_all_buildsystems);

use constant BUILD_STEPS => qw(configure build test install clean);

# Historical order must be kept for backwards compatibility. New
# build systems MUST be added to the END of the list.
our @BUILDSYSTEMS = (
	"autoconf",
	(! compat(7) ? "perl_build" : ()),
	"perl_makemaker",
	"makefile",
	"python_distutils",
	(compat(7) ? "perl_build" : ()),
	"cmake",
	"ant",
	"qmake",
	"qmake_qt4",
);

our @THIRD_PARTY_BUILDSYSTEMS = (
	'maven',
	'gradle',
);

my $opt_buildsys;
my $opt_sourcedir;
my $opt_builddir;
my $opt_list;
my $opt_parallel;

sub create_buildsystem_instance {
	my ($system, $required, %bsopts) = @_;
	my $module = "Debian::Debhelper::Buildsystem::$system";

	eval "use $module";
	if ($@) {
		return if not $required;
		error("unable to load build system class '$system': $@");
	}

	if (!exists $bsopts{builddir} && defined $opt_builddir) {
		$bsopts{builddir} = ($opt_builddir eq "") ? undef : $opt_builddir;
	}
	if (!exists $bsopts{sourcedir} && defined $opt_sourcedir) {
		$bsopts{sourcedir} = ($opt_sourcedir eq "") ? undef : $opt_sourcedir;
	}
	if (!exists $bsopts{parallel}) {
		$bsopts{parallel} = $opt_parallel;
	}
	return $module->new(%bsopts);
}

# Autoselect a build system from the list of instances
sub autoselect_buildsystem {
	my $step=shift;
	my $selected;
	my $selected_level = 0;

	foreach my $inst (@_) {
		# Only derived (i.e. more specific) build system can be
		# considered beyond the currently selected one.
		next if defined $selected && !$inst->isa(ref $selected);

		# If the build system says it is auto-buildable at the current
		# step and it can provide more specific information about its
		# status than its parent (if any), auto-select it.
		my $level = $inst->check_auto_buildable($step);
		if ($level > $selected_level) {
			$selected = $inst;
			$selected_level = $level;
		}
	}
	return $selected;
}

# Similar to create_build system_instance(), but it attempts to autoselect
# a build system if none was specified. In case autoselection fails, undef
# is returned.
sub load_buildsystem {
	my $system=shift;
	my $step=shift;
	my $system_options;
	if (defined($system) && ref($system) eq 'HASH') {
		$system_options = $system;
		$system = $system_options->{'system'};
	}
	if (defined $system) {
		my $inst = create_buildsystem_instance($system, 1, @_);
		return $inst;
	}
	else {
		# Try to determine build system automatically
		my @buildsystems;
		foreach $system (@BUILDSYSTEMS) {
			push @buildsystems, create_buildsystem_instance($system, 1, @_);
		}
		if (!$system_options || $system_options->{'enable-thirdparty'}) {
			foreach $system (@THIRD_PARTY_BUILDSYSTEMS) {
				push @buildsystems, create_buildsystem_instance($system, 0, @_);
			}
		}
		return autoselect_buildsystem($step, @buildsystems);
	}
}

sub load_all_buildsystems {
	my $incs=shift || \@INC;
	my (%buildsystems, @buildsystems);

	foreach my $inc (@$incs) {
		my $path = File::Spec->catdir($inc, "Debian/Debhelper/Buildsystem");
		if (-d $path) {
			foreach my $module_path (glob "$path/*.pm") {
				my $name = basename($module_path);
				$name =~ s/\.pm$//;
				next if exists $buildsystems{$name};
				$buildsystems{$name} = create_buildsystem_instance($name, 1, @_);
			}
		}
	}

	# Standard debhelper build systems first
	foreach my $name (@BUILDSYSTEMS) {
		error("standard debhelper build system '$name' could not be found/loaded")
		    if not exists $buildsystems{$name};
		push @buildsystems, $buildsystems{$name};
		delete $buildsystems{$name};
	}

	foreach my $name (@THIRD_PARTY_BUILDSYSTEMS) {
		next if not exists $buildsystems{$name};
		my $inst = $buildsystems{$name};
		$inst->{thirdparty} = 1;
		push(@buildsystems, $inst);
		delete($buildsystems{$name});
	}

	# The rest are 3rd party build systems
	foreach my $name (sort(keys(%buildsystems))) {
		my $inst = $buildsystems{$name};
		$inst->{thirdparty} = 1;
		push @buildsystems, $inst;
	}

	return @buildsystems;
}

sub buildsystems_init {
	my %args=@_;

	# Compat 10 defaults to --parallel by default
	my $max_parallel = compat(9) ? 1 : -1;

	# Available command line options
	my %options = (
	    "D=s" => \$opt_sourcedir,
	    "sourcedirectory=s" => \$opt_sourcedir,

	    "B:s" => \$opt_builddir,
	    "builddirectory:s" => \$opt_builddir,

	    "S=s" => \$opt_buildsys,
	    "buildsystem=s" => \$opt_buildsys,

	    "l" => \$opt_list,
	    "list" => \$opt_list,

	    "parallel" => sub { $max_parallel = -1 },
	    'no-parallel' => sub { $max_parallel = 1 },
	    "max-parallel=i" => \$max_parallel,
	);
	$args{options}{$_} = $options{$_} foreach keys(%options);
	Debian::Debhelper::Dh_Lib::init(%args);
	Debian::Debhelper::Dh_Lib::set_buildflags();
	set_parallel($max_parallel);
}

sub set_parallel {
	my $max=shift;

	# Get number of processes from parallel=n option, limiting it
	# with $max if needed
	$opt_parallel=get_buildoption("parallel") || 1;

	if ($max > 0 && $opt_parallel > $max) {
		$opt_parallel = $max;
	}
}

sub buildsystems_list {
	my $step=shift;

	my @buildsystems = load_all_buildsystems();
	my %auto_selectable = map { $_ => 1 } @THIRD_PARTY_BUILDSYSTEMS;
	my $auto = autoselect_buildsystem($step, grep { ! $_->{thirdparty} || $auto_selectable{$_->NAME} } @buildsystems);
	my $specified;

	# List build systems (including auto and specified status)
	foreach my $inst (@buildsystems) {
		if (! defined $specified && defined $opt_buildsys && $opt_buildsys eq $inst->NAME()) {
			$specified = $inst;
		}
		printf("%-20s %s", $inst->NAME(), $inst->DESCRIPTION());
		print " [3rd party]" if $inst->{thirdparty};
		print "\n";
	}
	print "\n";
	print "Auto-selected: ", $auto->NAME(), "\n" if defined $auto;
	print "Specified: ", $specified->NAME(), "\n" if defined $specified;
	print "No system auto-selected or specified\n"
		if ! defined $auto && ! defined $specified;
}

sub buildsystems_do {
	my $step=shift;

	if (!defined $step) {
		$step = basename($0);
		$step =~ s/^dh_auto_//;
	}

	if (grep(/^\Q$step\E$/, BUILD_STEPS) == 0) {
		error("unrecognized build step: " . $step);
	}

	if ($opt_list) {
		buildsystems_list($step);
		exit 0;
	}

	my $buildsystem = load_buildsystem($opt_buildsys, $step);
	if (defined $buildsystem) {
		$buildsystem->pre_building_step($step);
		$buildsystem->$step(@_, @{$dh{U_PARAMS}});
		$buildsystem->post_building_step($step);
	}
	return 0;
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
