# A module for loading and managing debhelper build system classes.
# This module is intended to be used by all dh_auto_* programs.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Dh_Buildsystems;

use strict;
use warnings;
use Debian::Debhelper::Buildsystem;
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
	"cmake+makefile",
	"cmake+ninja",
	"ant",
	"qmake",
	"qmake_qt4",
	"meson+ninja",
	"ninja",
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

*create_buildsystem_instance = \&Debian::Debhelper::Buildsystem::_create_buildsystem_instance;

sub _insert_cmd_opts {
	my (%bsopts) = @_;
	if (!exists $bsopts{builddir} && defined $opt_builddir) {
		$bsopts{builddir} = ($opt_builddir eq "") ? undef : $opt_builddir;
	}
	if (!exists $bsopts{sourcedir} && defined $opt_sourcedir) {
		$bsopts{sourcedir} = ($opt_sourcedir eq "") ? undef : $opt_sourcedir;
	}
	if (!exists $bsopts{parallel}) {
		$bsopts{parallel} = $opt_parallel;
	}
	return %bsopts;
}

# Autoselect a build system from the list of instances
sub autoselect_buildsystem {
	my $step=shift;
	my $selected;
	my $selected_level = 0;

	foreach my $inst (@_) {
		# Only  more specific build system can be considered beyond
		# the currently selected one.
		if (defined($selected)) {
			my $ok = $inst->isa(ref($selected)) ? 1 : 0;
			if (not $ok and $inst->IS_GENERATOR_BUILD_SYSTEM) {
				$ok = 1 if $inst->get_targetbuildsystem->NAME eq $selected->NAME;
			}
			next if not $ok;
		}

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

# Similar to create_buildsystem_instance(), but it attempts to autoselect
# a build system if none was specified. In case autoselection fails or an
# explicit “none” is requested, undef is returned.
sub load_buildsystem {
	my $system=shift;
	my $step=shift;
	my %opts = _insert_cmd_opts(@_);
	my $system_options;
	if (defined($system) && ref($system) eq 'HASH') {
		$system_options = $system;
		$system = $system_options->{'system'};
	}
	if (defined $system) {
		return undef if $system eq 'none';
		my $inst = create_buildsystem_instance($system, 1, %opts);
		return $inst;
	}
	else {
		# Try to determine build system automatically
		my @buildsystems;
		foreach $system (@BUILDSYSTEMS) {
			push @buildsystems, create_buildsystem_instance($system, 1, %opts);
		}
		if (!$system_options || $system_options->{'enable-thirdparty'}) {
			foreach $system (@THIRD_PARTY_BUILDSYSTEMS) {
				push @buildsystems, create_buildsystem_instance($system, 0, %opts);
			}
		}
		return autoselect_buildsystem($step, @buildsystems);
	}
}

sub load_all_buildsystems {
	my $incs=shift || \@INC;
	my %opts = _insert_cmd_opts(@_);
	my (%buildsystems, %genbuildsystems, @buildsystems);

	foreach my $inc (@$incs) {
		my $path = File::Spec->catdir($inc, "Debian/Debhelper/Buildsystem");
		if (-d $path) {
			foreach my $module_path (glob "$path/*.pm") {
				my $name = basename($module_path);
				$name =~ s/\.pm$//;
				next if exists $buildsystems{$name} or exists $genbuildsystems{$name};
				my $system = create_buildsystem_instance($name, 1, %opts);
				if ($system->IS_GENERATOR_BUILD_SYSTEM) {
					$genbuildsystems{$name} = 1;
					for my $target_name ($system->SUPPORTED_TARGET_BUILD_SYSTEMS) {
						my $full_name = "${name}+${target_name}";
						my $full_system = create_buildsystem_instance($name, 1, %opts,
							'targetbuildsystem' => $target_name);
						$buildsystems{$full_name} = $full_system;
					}
				} else {
					$buildsystems{$name} = $system;
				}
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
	    "sourcedir=s" => \$opt_sourcedir,
	    "sourcedirectory=s" => \$opt_sourcedir,

	    "B:s" => \$opt_builddir,
	    "builddir:s" => \$opt_builddir,
	    "builddirectory:s" => \$opt_builddir,

	    "S=s" => \$opt_buildsys,
	    "buildsystem=s" => \$opt_buildsys,

	    "l" => \$opt_list,
	    "list" => \$opt_list,

	    "parallel" => sub { $max_parallel = -1 },
	    'no-parallel' => sub { $max_parallel = 1 },
	    "max-parallel=i" => \$max_parallel,

	    'reload-all-buildenv-variables' => sub { delete($ENV{'DH_INTERNAL_BUILDFLAGS'}); },
	);
	if (compat(8)) {
		# This option only works in compat 9+ where we actually set buildflags
		$options{'reload-all-buildenv-variables'} = sub {
			die("--reload-all-buildenv-variables only work reliably in compat 9+.\n");
		};
	}
	$args{options}{$_} = $options{$_} foreach keys(%options);
	Debian::Debhelper::Dh_Lib::init(%args);
	Debian::Debhelper::Dh_Lib::setup_buildenv();
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
	my $specified_text;

	if ($opt_buildsys) {
		for my $inst (@buildsystems) {
			my $full_name = $inst->NAME;
			if ($full_name eq $opt_buildsys) {
				$specified_text = $full_name;
			} elsif ($inst->IS_GENERATOR_BUILD_SYSTEM and ref($inst)->NAME eq $opt_buildsys) {
				my $default = $inst->DEFAULT_TARGET_BUILD_SYSTEM;
				$specified_text = "${opt_buildsys}+${default} (default for ${opt_buildsys})";
			}
		}
	}

	# List build systems (including auto and specified status)
	foreach my $inst (@buildsystems) {
		printf("%-20s %s", $inst->NAME(), $inst->FULL_DESCRIPTION());
		print " [3rd party]" if $inst->{thirdparty};
		print "\n";
	}
	print "\n";
	print "Auto-selected: ", $auto->NAME(), "\n" if defined $auto;
	print "Specified: ", $specified_text, "\n" if defined $specified_text;
	print "No system auto-selected or specified\n"
		if ! defined $auto && ! defined $specified_text;
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
		my ($xdg_runtime_dir, $err, $ref);
		local $SIG{'INT'} = sub { $ref = 'INT'; die(\$ref); };
		local $SIG{'TERM'} = sub { $ref = 'TERM'; die(\$ref); };
		if ($step eq 'test' and not compat(12)) {
			require File::Temp;
			$xdg_runtime_dir = File::Temp->newdir('dh-xdg-rundir-XXXXXXXX',
				TMPDIR  => 1,
				CLEANUP => 1,
			);
			$ENV{'XDG_RUNTIME_DIR'} = $xdg_runtime_dir->dirname;
		}
		eval {
			$buildsystem->pre_building_step($step);
			$buildsystem->$step(@_, @{$dh{U_PARAMS}});
			$buildsystem->post_building_step($step);
		};
		$err = $@;
		doit('rm', '-fr', '--', $xdg_runtime_dir) if $xdg_runtime_dir;
		if ($err) {
			my $sig;
			die($err) if $err ne \$ref;
			$sig = $ref;
			delete($SIG{$sig});
			kill($sig => $$);
		}
	}
	return 0;
}

1
