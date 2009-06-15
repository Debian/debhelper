# A module for loading and managing debhelper build system plugins.
# This module is intended to be used by all dh_auto_* helper commands.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Dh_Buildsystems;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib;
use File::Spec;

use base 'Exporter';
our @EXPORT=qw(&buildsystems_init &buildsystems_do &load_buildsystem &load_all_buildsystems);

# Historical order must be kept for backwards compatibility. New
# build systems MUST be added to the END of the list.
our @BUILDSYSTEMS = (
    "autoconf",
    "perl_makemaker",
    "makefile",
    "python_distutils",
    "perl_build",
    "cmake",
);

my $opt_buildsys;
my $opt_sourcedir;
my $opt_builddir;
my $opt_list;
my $opt_help_buildsys;

sub create_buildsystem_instance {
	my $system=shift;
	my %bsopts=@_;
	my $module = "Debian::Debhelper::Buildsystem::$system";

	eval "use $module";
	if ($@) {
		error("unable to load build system class '$system': $@");
	}

	if (!exists $bsopts{builddir} && defined $opt_builddir) {
		$bsopts{builddir} = ($opt_builddir eq "") ? undef : $opt_builddir;
	}
	if (!exists $bsopts{sourcedir} && defined $opt_sourcedir) {
		$bsopts{sourcedir} = ($opt_sourcedir eq "") ? undef : $opt_sourcedir;
	}
	return $module->new(%bsopts);
}

# Similar to create_build system_instance(), but it attempts to autoselect
# a build system if none was specified. In case autoselection fails, undef
# is returned.
sub load_buildsystem {
	my $system=shift;
	my $step=shift;
	if (defined $system) {
		my $inst = create_buildsystem_instance($system, @_);
		return $inst;
	}
	else {
		# Try to determine build system automatically
		for $system (@BUILDSYSTEMS) {
			my $inst = create_buildsystem_instance($system, @_);
			if ($inst->check_auto_buildable($step)) {
				return $inst;
			}
		}
	}
	return;
}

sub load_all_buildsystems {
	my $incs=shift || \@INC;
	my (%buildsystems, @buildsystems);

	for my $inc (@$incs) {
		my $path = File::Spec->catdir($inc, "Debian/Debhelper/Buildsystem");
		if (-d $path) {
			for my $module_path (glob "$path/*.pm") {
				my $name = basename($module_path);
				$name =~ s/\.pm$//;
				next if exists $buildsystems{$name};
				$buildsystems{$name} = create_buildsystem_instance($name, @_);
			}
		}
	}

	# Push debhelper built-in build systems first
	for my $name (@BUILDSYSTEMS) {
		error("debhelper built-in build system '$name' could not be found/loaded")
		    if not exists $buildsystems{$name};
		push @buildsystems, $buildsystems{$name};
		delete $buildsystems{$name};
	}

	# The rest are 3rd party build systems
	for my $name (keys %buildsystems) {
		my $inst = $buildsystems{$name};
		$inst->{thirdparty} = 1;
		push @buildsystems, $inst;
	}

	return @buildsystems;
}

sub buildsystems_init {
	my %args=@_;

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

	    "help-buildsystem" => \$opt_help_buildsys,
	);
	$args{options}{$_} = $options{$_} foreach keys(%options);
	Debian::Debhelper::Dh_Lib::init(%args);
}

sub buildsystems_list {
	my $step=shift;

	# List build systems (including auto and specified status)
	my ($auto, $specified);
	my @buildsystems = load_all_buildsystems();
	for my $inst (@buildsystems) {
		my $is_specified = defined $opt_buildsys && $opt_buildsys eq $inst->NAME();
		if (! defined $specified && defined $opt_buildsys && $opt_buildsys eq $inst->NAME()) {
			$specified = $inst->NAME();
		}
		elsif (! defined $auto && ! $inst->{thirdparty} && $inst->check_auto_buildable($step)) {
			$auto = $inst->NAME();
		}
		printf("%s - %s", $inst->NAME(), $inst->DESCRIPTION());
		print " [3rd party]" if $inst->{thirdparty};
		print "\n";
	}
	print "\n";
	print "Auto-selected: $auto\n" if defined $auto;
	print "Specified: $specified\n" if defined $specified;
	print "No system auto-selected or specified\n"
		if ! defined $auto && ! defined $specified;
}

sub help_buildsystem {
	my $step=shift;

	# Print build system help page to standard output

	my $inst = load_buildsystem($opt_buildsys, $step);
	if ($inst) {
		my $pmfile = ref $inst;
		$pmfile =~ s#::#/#g;
		$pmfile = $INC{"$pmfile.pm"};

		# Display help with perldoc if it is installed and output is
		# a tty
		my $perldoc;
		if (-t STDOUT) {
			eval "use Pod::Perldoc";
			$perldoc = "Pod::Perldoc" if (!$@);
		}
		if ($perldoc) {
			$perldoc = new Pod::Perldoc();
			$perldoc->{args} = [ '-oman',
			                     '-w', 'section=7" "--name=dh_auto_'.lc($inst->NAME()),
			                     '-w', 'center=Dh_auto build system documentation',
			                     '-w', 'release=',
			                     '-F', $pmfile ];
			$perldoc->process();
		}
		else {
			# No perldoc on the system. Use Pod::Usage to emit simple text
			eval "use Pod::Usage";
			pod2usage( -message => "Help page for the ".$inst->NAME()." build system\n" .
			                       '<' . '-'x74 . '>',
			           -input => $pmfile, -exitval => 'NOEXIT',
			           -verbose => 2, -noperldoc => 1 );
			print '<', '-'x74, '>', "\n";
		}
		return 0;
	}
	else {
		print STDERR "No system auto-selected or specified. Try using --buildsystem option\n";
		return 1;
	}
}

sub buildsystems_do {
	my $step=shift;

	if (!defined $step) {
		$step = basename($0);
		$step =~ s/^dh_auto_//;
	}

	if (grep(/^\Q$step\E$/, qw{configure build test install clean}) == 0) {
		error("unrecognized build step: " . $step);
	}

	if ($opt_list) {
		buildsystems_list($step);
		exit 0;
	}

	if ($opt_help_buildsys) {
		exit help_buildsystem($step);
	}

	my $buildsystem = load_buildsystem($opt_buildsys, $step);
	if (defined $buildsystem) {
		$buildsystem->pre_building_step($step);
		$buildsystem->$step(@_, @{$dh{U_PARAMS}});
		$buildsystem->post_building_step($step);
	}
	return 0;
}

1;
