#!/usr/bin/perl
#
# Debhelper option processing library.
#
# Joey Hess GPL copyright 1998-2002

package Debian::Debhelper::Dh_Getopt;
use strict;
use warnings;

use Debian::Debhelper::Dh_Lib;
use Getopt::Long;

my %exclude_package;

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
		push @{$dh{DOPACKAGES}}, getpackages('indep');
		$dh{DOINDEP}=1;
	}
	elsif ($option eq 'a' or $option eq 'arch' or
	       $option eq 's' or $option eq 'same-arch') {
		push @{$dh{DOPACKAGES}}, getpackages('arch');
		$dh{DOARCH}=1;
		if ($option eq 's' or $option eq 'same-arch') {
			if (compat(10)) {
				warning('-s/--same-arch is deprecated; please use -a/--arch instead');
			} else {
				error('-s/--same-arch is removed in compat 11; please use -a/--arch instead');
			}
		}
	}
	elsif ($option eq 'p' or $option eq 'package') {
		push @{$dh{DOPACKAGES}}, $value;
	}
	else {
		error("bad option $option - should never happen!\n");
	}
}

# Sets a package as the debug package.
sub SetDebugPackage { my($option,$value)=@_;
	$dh{DEBUGPACKAGE} = $value;
	# For backwards compatibility
	$dh{DEBUGPACKAGES} = [$value];
}

# Add a package to a list of packages that should not be acted on.
sub ExcludePackage { my($option,$value)=@_;
	$exclude_package{$value}=1;
}

# Add another item to the exclude list.
sub AddExclude { my($option,$value)=@_;
	push @{$dh{EXCLUDE}},$value;
}

# Add a file to the ignore list.
sub AddIgnore { my($option,$file)=@_;
	$dh{IGNORE}->{$file}=1;
}

# This collects non-options values.
sub NonOption {
	push @{$dh{ARGV}}, @_;
}

sub getoptions {
	my $array=shift;
	my %params=@_;

	if (! exists $params{bundling} || $params{bundling}) {
		Getopt::Long::config("bundling");
	}

	my @test;
	my %options=(	
		"v" => \$dh{VERBOSE},
		"verbose" => \$dh{VERBOSE},

		"no-act" => \$dh{NO_ACT},
	
		"i" => \&AddPackage,
		"indep" => \&AddPackage,
	
		"a" => \&AddPackage,
		"arch" => \&AddPackage,
	
		"p=s" => \&AddPackage,
	        "package=s" => \&AddPackage,
		
		"N=s" => \&ExcludePackage,
		"no-package=s" => \&ExcludePackage,
	
		"remaining-packages" => \$dh{EXCLUDE_LOGGED},
	
		"dbg-package=s" => \&SetDebugPackage,
		
		"s" => \&AddPackage,
		"same-arch" => \&AddPackage,
	
		"n" => \$dh{NOSCRIPTS},
		"noscripts" => \$dh{NOSCRIPTS},
		"no-scripts" => \$dh{NOSCRIPTS},
		"o" => \$dh{ONLYSCRIPTS},
		"onlyscripts" => \$dh{ONLYSCRIPTS},
		"only-scripts" => \$dh{ONLYSCRIPTS},

		"X=s" => \&AddExclude,
		"exclude=s" => \&AddExclude,
		
		"d" => \$dh{D_FLAG},
	
		"k" => \$dh{K_FLAG},
		"keep" => \$dh{K_FLAG},

		"P=s" => \$dh{TMPDIR},
		"tmpdir=s" => \$dh{TMPDIR},

		"u=s", => \$dh{U_PARAMS},

		"V:s", => \$dh{V_FLAG},

		"A" => \$dh{PARAMS_ALL},
		"all" => \$dh{PARAMS_ALL},
	
		"priority=s" => \$dh{PRIORITY},
		
		"h|help" => \&showhelp,

		"mainpackage=s" => \$dh{MAINPACKAGE},

		"name=s" => \$dh{NAME},

		"error-handler=s" => \$dh{ERROR_HANDLER},
		
		"ignore=s" => \&AddIgnore,

		"O=s" => sub { push @test, $_[1] },
	      
		(ref $params{options} ? %{$params{options}} : ()) ,

		"<>" => \&NonOption,
	);

	if ($params{test}) {
		foreach my $key (keys %options) {
			$options{$key}=sub {};
		}
	}

	my $oldwarn;
	if ($params{test} || $params{ignore_unknown_options}) {
		$oldwarn=$SIG{__WARN__};
		$SIG{__WARN__}=sub {};
	}
	my $ret=Getopt::Long::GetOptionsFromArray($array, %options);
	if ($oldwarn) {
		$SIG{__WARN__}=$oldwarn;
	}

	foreach my $opt (@test) {
		# Try to parse an option, and skip it
		# if it is not known.
		if (getoptions([$opt], %params,
				ignore_unknown_options => 0,
				test => 1)) {
			getoptions([$opt], %params);
		}
	}

	return 1 if $params{ignore_unknown_options};
	return $ret;
}

sub split_options_string {
	my $str=shift;
	$str=~s/^\s+//;
	return split(/\s+/,$str);
}

# Parse options and set %dh values.
sub parseopts {
	my %params=@_;
	
	my @ARGV_extra;

	# DH_INTERNAL_OPTIONS is used to pass additional options from
	# dh through an override target to a command.
	if (defined $ENV{DH_INTERNAL_OPTIONS}) {
		@ARGV_extra=split(/\x1e/, $ENV{DH_INTERNAL_OPTIONS});
		getoptions(\@ARGV_extra, %params);

		# Avoid forcing acting on packages specified in
		# DH_INTERNAL_OPTIONS. This way, -p can be specified
		# at the command line to act on a specific package, but when
		# nothing is specified, the excludes will cause the set of
		# packages DH_INTERNAL_OPTIONS specifies to be acted on.
		if (defined $dh{DOPACKAGES}) {
			foreach my $package (getpackages()) {
				if (! grep { $_ eq $package } @{$dh{DOPACKAGES}}) {
					$exclude_package{$package}=1;
				}
			}
		}
		delete $dh{DOPACKAGES};
		delete $dh{DOINDEP};
		delete $dh{DOARCH};
	}
	
	# DH_OPTIONS can contain additional options to be parsed like @ARGV
	if (defined $ENV{DH_OPTIONS}) {
		@ARGV_extra=split_options_string($ENV{DH_OPTIONS});
		my $ret=getoptions(\@ARGV_extra, %params);
		if (!$ret) {
			warning("warning: ignored unknown options in DH_OPTIONS");
		}
	}

	my $ret=getoptions(\@ARGV, %params);
	if (!$ret) {
		if (! compat(7)) {
			error("unknown option; aborting");
		}
	}

	# Check to see if -V was specified. If so, but no parameters were
	# passed, the variable will be defined but empty.
	if (defined($dh{V_FLAG})) {
		$dh{V_FLAG_SET}=1;
	}
	
	# If we have not been given any packages to act on, assume they
	# want us to act on them all. Note we have to do this before excluding
	# packages out, below.
	if (! defined $dh{DOPACKAGES} || ! @{$dh{DOPACKAGES}}) {
		if ($dh{DOINDEP} || $dh{DOARCH}) {
			# User specified that all arch (in)dep package be
			# built, and there are none of that type.
			if (! $dh{BLOCK_NOOP_WARNINGS}) {
				warning("You asked that all arch in(dep) packages be built, but there are none of that type.");
			}
			exit(0);
		}
		push @{$dh{DOPACKAGES}},getpackages("both");
	}

	# Remove excluded packages from the list of packages to act on.
	# Also unique the list, in case some options were specified that
	# added a package to it twice.
	my @package_list;
	my $package;
	my %packages_seen;
	foreach $package (@{$dh{DOPACKAGES}}) {
		if (defined($dh{EXCLUDE_LOGGED}) &&
		    grep { $_ eq basename($0) } load_log($package)) {
			$exclude_package{$package}=1;
		}
		if (! $exclude_package{$package}) {
			if (! exists $packages_seen{$package}) {
				$packages_seen{$package}=1;
				push @package_list, $package;	
			}
		}
	}
	@{$dh{DOPACKAGES}}=@package_list;

	if (! defined $dh{DOPACKAGES} || ! @{$dh{DOPACKAGES}}) {
		if (! $dh{BLOCK_NOOP_WARNINGS}) {
			warning("No packages to build.");
		}
		exit(0);
	}

	if (defined $dh{U_PARAMS}) {
	        # Split the U_PARAMS up into an array.
        	my $u=$dh{U_PARAMS};
        	undef $dh{U_PARAMS};
                push @{$dh{U_PARAMS}}, split(/\s+/,$u);
        }

	# Anything left in @ARGV is options that appeared after a --
	# These options are added to the U_PARAMS array, while the
	# non-option values we collected replace them in @ARGV;
	push @{$dh{U_PARAMS}}, @ARGV, @ARGV_extra;
	@ARGV=@{$dh{ARGV}} if exists $dh{ARGV};
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
