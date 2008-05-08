#!/usr/bin/perl -w
#
# Debhelper option processing library.
#
# Joey Hess GPL copyright 1998-2002

package Debian::Debhelper::Dh_Getopt;
use strict;

use Debian::Debhelper::Dh_Lib;
use Getopt::Long;
use Exporter;
#use vars qw{@ISA @EXPORT};
#@ISA=qw(Exporter);
#@EXPORT=qw(&aparseopts); # FIXME: for some reason, this doesn't work.

my (%options, %exclude_package);

sub showhelp {
	my $prog=basename($0);
	print "Usage: $prog [options]\n\n";
	print "  $prog is a part of debhelper. See debhelper(7)\n";
	print "  and $prog(1) for complete usage instructions.\n"; 
	exit(1);
}

# Passed an option name and an option value, adds packages to the list
# of packages. We need this so the list will be built up in the right
# order.
sub AddPackage { my($option,$value)=@_;
	if ($option eq 'i' or $option eq 'indep') {
		push @{$options{DOPACKAGES}}, getpackages('indep');
		$options{DOINDEP}=1;
	}
	elsif ($option eq 'a' or $option eq 'arch') {
		push @{$options{DOPACKAGES}}, getpackages('arch');
		$options{DOARCH}=1;
	}
	elsif ($option eq 'p' or $option eq 'package') {
		push @{$options{DOPACKAGES}}, $value;
	}
	elsif ($option eq 's' or $option eq 'same-arch') {
		push @{$options{DOPACKAGES}}, getpackages('same');
		$options{DOSAME}=1;
	}
	else {
		error("bad option $option - should never happen!\n");
	}
}

# Adds packages to the list of debug packages.
sub AddDebugPackage { my($option,$value)=@_;
	push @{$options{DEBUGPACKAGES}}, $value;
}

# Add a package to a list of packages that should not be acted on.
sub ExcludePackage { my($option,$value)=@_;
	$exclude_package{$value}=1;
}

# Add another item to the exclude list.
sub AddExclude { my($option,$value)=@_;
	push @{$options{EXCLUDE}},$value;
}

# Add a file to the ignore list.
sub AddIgnore { my($option,$file)=@_;
	$options{IGNORE}->{$file}=1;
}

# Add an item to the with list.
sub AddWith { my($option,$value)=@_;
	push @{$options{WITH}},$value;
}

# This collects non-options values.
sub NonOption {
	push @{$options{ARGV}}, @_;
}

# Parse options and return a hash of the values.
sub parseopts {
	undef %options;
	
	my $ret=GetOptions(
		"v" => \$options{VERBOSE},
		"verbose" => \$options{VERBOSE},
	
		"i" => \&AddPackage,
		"indep" => \&AddPackage,
	
		"a" => \&AddPackage,
		"arch" => \&AddPackage,
	
		"p=s" => \&AddPackage,
	        "package=s" => \&AddPackage,
	
		"dbg-package=s" => \&AddDebugPackage,
		
		"s" => \&AddPackage,
		"same-arch" => \&AddPackage,
	
		"N=s" => \&ExcludePackage,
		"no-package=s" => \&ExcludePackage,
	
		"n" => \$options{NOSCRIPTS},
		"noscripts" => \$options{NOSCRIPTS},
		"o" => \$options{ONLYSCRIPTS},
		"onlyscripts" => \$options{ONLYSCRIPTS},

		"x" => \$options{INCLUDE_CONFFILES}, # is -x for some unknown historical reason..
		"include-conffiles" => \$options{INCLUDE_CONFFILES},
	
		"X=s" => \&AddExclude,
		"exclude=s" => \&AddExclude,
		
		"ignore=s" => \&AddIgnore,
	
		"d" => \$options{D_FLAG},
		"remove-d" => \$options{D_FLAG},
		"dirs-only" => \$options{D_FLAG},
	
		"r" => \$options{R_FLAG},
		"no-restart-on-upgrade" => \$options{R_FLAG},
		"no-start" => \$options{NO_START},
		"R|restart-after-upgrade" => \$options{RESTART_AFTER_UPGRADE},
	
		"k" => \$options{K_FLAG},
		"keep" => \$options{K_FLAG},
		"keep-debug" => \$options{K_FLAG},

		"P=s" => \$options{TMPDIR},
		"tmpdir=s" => \$options{TMPDIR},

		"u=s", => \$options{U_PARAMS},
		"update-rcd-params=s", => \$options{U_PARAMS},
	        "dpkg-shlibdeps-params=s", => \$options{U_PARAMS},
		"dpkg-gencontrol-params=s", => \$options{U_PARAMS},

		"l=s", => \$options{L_PARAMS},

		"m=s", => \$options{M_PARAMS},
		"major=s" => \$options{M_PARAMS},

		"V:s", => \$options{V_FLAG},
		"version-info:s" => \$options{V_FLAG},

		"A" => \$options{PARAMS_ALL},
		"all" => \$options{PARAMS_ALL},

		"no-act" => \$options{NO_ACT},
	
		"init-script=s" => \$options{INIT_SCRIPT},
		
		"sourcedir=s" => \$options{SOURCEDIR},
		
		"destdir=s" => \$options{DESTDIR},

		"filename=s" => \$options{FILENAME},
		
		"priority=s" => \$options{PRIORITY},
		
		"flavor=s" => \$options{FLAVOR},

		"autodest" => \$options{AUTODEST},

		"h|help" => \&showhelp,

		"mainpackage=s" => \$options{MAINPACKAGE},

		"list-missing" => \$options{LIST_MISSING},

		"fail-missing" => \$options{FAIL_MISSING},
		
		"L|libpackage=s" => \$options{LIBPACKAGE},
		
		"name=s" => \$options{NAME},
		
		"error-handler=s" => \$options{ERROR_HANDLER},
		
		"add-udeb=s" => \$options{SHLIBS_UDEB},
		
		"language=s" => \$options{LANGUAGE},

		"until=s" => \$options{UNTIL},
		"after=s" => \$options{AFTER},
		"before=s" => \$options{BEFORE},
		"remaining" => \$options{REMAINING},
		"with=s" => \&AddWith,

		"<>" => \&NonOption,
	);

	if (!$ret) {
		error("unknown option; aborting");
	}
	
	# Check to see if -V was specified. If so, but no parameters were
	# passed, the variable will be defined but empty.
	if (defined($options{V_FLAG})) {
		$options{V_FLAG_SET}=1;
	}
	
	# If we have not been given any packages to act on, assume they
	# want us to act on them all. Note we have to do this before excluding
	# packages out, below.
	if (! defined $options{DOPACKAGES} || ! @{$options{DOPACKAGES}}) {
		if ($options{DOINDEP} || $options{DOARCH} || $options{DOSAME}) {
			# User specified that all arch (in)dep package be
			# built, and there are none of that type.
			warning("I have no package to build");
			exit(0);
		}
		push @{$options{DOPACKAGES}},getpackages();
	}

	# Remove excluded packages from the list of packages to act on.
	# Also unique the list, in case some options were specified that
	# added a package to it twice.
	my @package_list;
	my $package;
	my %packages_seen;
	foreach $package (@{$options{DOPACKAGES}}) {
		if (! $exclude_package{$package}) {
			if (! exists $packages_seen{$package}) {
				$packages_seen{$package}=1;
				push @package_list, $package;	
			}
		}
	}
	@{$options{DOPACKAGES}}=@package_list;

	# If there are no packages to act on now, it's an error.
	if (! defined $options{DOPACKAGES} || ! @{$options{DOPACKAGES}}) {
		error("I have no package to build");
	}

	if (defined $options{U_PARAMS}) {
	        # Split the U_PARAMS up into an array.
        	my $u=$options{U_PARAMS};
        	undef $options{U_PARAMS};
                push @{$options{U_PARAMS}}, split(/\s+/,$u);
        }

	# Anything left in @ARGV is options that appeared after a --
	# These options are added to the U_PARAMS array, while the
	# non-option values we collected replace them in @ARGV;
	push @{$options{U_PARAMS}}, @ARGV;
	@ARGV=@{$options{ARGV}} if exists $options{ARGV};

	return %options;
}

sub import {
	# Enable bundling of short command line options.
	Getopt::Long::config("bundling");
}		

1
