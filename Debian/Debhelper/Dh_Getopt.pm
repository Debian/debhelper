#!/usr/bin/perl -w
#
# Debhelper option processing library.
#
# Joey Hess GPL copyright 1998.

package Debian::Debhelper::Dh_Getopt;
use strict;

use Debian::Debhelper::Dh_Lib;
use Getopt::Long;
use Exporter;
#use vars qw{@ISA @EXPORT};
#@ISA=qw(Exporter);
#@EXPORT=qw(&aparseopts); # FIXME: for some reason, this doesn't work.

my (%options, %exclude_package);

# Passed an option name and an option value, adds packages to the list
# of packages. We need this so the list will be built up in the right
# order.
sub AddPackage { my($option,$value)=@_;
	if ($option eq 'i' or $option eq 'indep') {
		push @{$options{DOPACKAGES}}, GetPackages('indep');
		$options{DOINDEP}=1;
	}
	elsif ($option eq 'a' or $option eq 'arch') {
		push @{$options{DOPACKAGES}}, GetPackages('arch');
		$options{DOARCH}=1;
	}
	elsif ($option eq 'p' or $option eq 'package') {
		push @{$options{DOPACKAGES}}, $value;
	}
	elsif ($option eq 's' or $option eq 'same-arch') {
		push @{$options{DOPACKAGES}}, GetPackages('same');
		$options{DOSAME}=1;
	}
	else {
		error("bad option $option - should never happen!\n");
	}
}

# Add a package to a list of packages that should not be acted on.
sub ExcludePackage { my($option,$value)=@_;
	$exclude_package{$value}=1;
}

# Add another item to the exclude list.
sub AddExclude { my($option,$value)=@_;
	push @{$options{EXCLUDE}},$value;
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
	
		"s" => \&AddPackage,
		"same-arch" => \&AddPackage,
	
		"N=s" => \&ExcludePackage,
		"no-package=s" => \&ExcludePackage,
	
		"n" => \$options{NOSCRIPTS},
		"noscripts" => \$options{NOSCRIPTS},

		"x" => \$options{INCLUDE_CONFFILES}, # is -x for some unknown historical reason..
		"include-conffiles" => \$options{INCLUDE_CONFFILES},
	
		"X=s" => \&AddExclude,
		"exclude=s" => \&AddExclude,
	
		"d" => \$options{D_FLAG},
		"remove-d" => \$options{D_FLAG},
		"dirs-only" => \$options{D_FLAG},
	
		"r" => \$options{R_FLAG},
		"no-restart-on-upgrade" => \$options{R_FLAG},
	
		"k" => \$options{K_FLAG},
		"keep" => \$options{K_FLAG},

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
		
		"priority=i" => \$options{PRIORITY},
		
		"flavor=s" => \$options{FLAVOR},
		
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
			error("I have no package to build");
		}
		push @{$options{DOPACKAGES}},GetPackages();
	}
	
	# Remove excluded packages from the list of packages to act on.
	my @package_list;
	my $package;
	foreach $package (@{$options{DOPACKAGES}}) {
		if (! $exclude_package{$package}) {
			push @package_list, $package;	
		}
	}
	@{$options{DOPACKAGES}}=@package_list;

	# Generate EXCLUDE_FIND.
	$options{EXCLUDE_FIND}='';
	foreach (@{$options{EXCLUDE}}) {
		$options{EXCLUDE_FIND}.="-regex .*".quotemeta($_).".* -or ";
	}
	$options{EXCLUDE_FIND}=~s/ -or $//;

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
