#!/usr/bin/perl
#
# Because the getopt() program is so horribly broken, I wrote my own argument
# processer that uses the find Getopt::Long module. This is used by all
# debhelper scripts.
#
# Joey Hess, GPL copyright 1998.

# Returns a list of packages in the control file.
# Must pass "arch" or "indep" to specify arch-dependant or -independant
# packages.
sub GetPackages { $type=shift;
	my $package;
	my $arch;
	my @list;
	open (CONTROL,"<debian/control") || 
		( $parse_error="cannot read debian/control: $!\n" );
	while (<CONTROL>) {
		chomp;
		s/\s+$//;
		if (/^Package:\s+(.*)/) {
			$package=$1;
		}
		if (/^Architecture:\s+(.*)/) {
			$arch=$1;
		}
		if (!$_ or eof) { # end of stanza.
			if ($package &&
			    (($type eq 'indep' && $arch eq 'all') ||
				   ($type eq 'arch' && $arch ne 'all'))) {
				push @list, $package;
				undef $package, $arch;
			}
		}
	}
	close CONTROL;

	return @list;
}

# Passed an option name and an option value, adds packages to the list
# of packages. We need this so the list will be built up in the right
# order.
sub AddPackage { my($option,$value)=@_;
	if ($option eq 'i' or $option eq 'indep') {
		push @packages, GetPackages('indep');
		$indep=1;
	}
	elsif ($option eq 'a' or $option eq 'arch') {
		push @packages, GetPackages('arch');
		$arch=1;
	}
	elsif ($option eq 'p' or $option eq 'package') {
		push @packages, $value;
	}
	else {
		$parse_error="bad option $option - should never happen!\n";
	}
}

# Add another item to the exclude list.
sub AddExclude { my($option,$value)=@_;
	push @exclude,$value;
}

use Getopt::Long;

# Enable bundling of short command line options.
Getopt::Long::config("bundling");

# Parse options.
$ret=GetOptions(
	"v" => \$verbose,
	"verbose" => \$verbose,

	"i" => \&AddPackage,
	"indep" => \&AddPackage,

	"a" => \&AddPackage,
	"arch" => \&AddPackage,

	"p=s" => \&AddPackage,
  "package=s" => \&AddPackage,

	"n" => \$noscripts,
	"noscripts" => \$noscripts,

	"x" => \$include, # is -x for some unknown historical reason..
	"include-conffiles" => \$include,

	"X=s" => \&AddExclude,
	"exclude=s" => \&AddExclude,

	"d" => \$d_flag,
	"remove-d" => \$d_flag,

	"r" => \$r_flag,
	"no-restart-on-upgrade" => \$r_flag,

	"k" => \$k_flag,
	"keep" => \$k_flag,

	"P=s" => \$tmpdir,
	"tmpdir=s" => \$tmpdir,

	"u=s", => \$u_params,
	"update-rcd-params=s", => \$u_params,
  "dpkg-shlibdeps-params=s", => \$u_params,

	"m=s", => \$major,
	"major=s" => \$major,

	"V:s", => \$version_info,
	"version-info:s" => \$version_info,

	"A" => \$all,
	"all" => \$all,

	"no-act" => \$no_act,

	"init-script=s" => \$init_script,
);

if (!$ret) {
	$parse_error="exiting with unknown option.";
}

# Check to see if -V was specified. If so, but no parameters were passed,
# the variable will be defined but empty.
if (defined($version_info)) {
	$version_info_set=1;
}

# Check to see if DH_VERBOSE environment variable was set, if so, make sure
# verbose is on.
if ($ENV{DH_VERBOSE} ne undef) {
	$verbose=1;
}

# Check to see if DH_NO_ACT was set, if so, make sure no act mode is on.
if ($ENV{DH_NO_ACT} ne undef) {
	$no_act=1;
}

$exclude=join ' ', @exclude;
$exclude_grep=join '|', @exclude;

# Now output everything, in a format suitable for a shell to eval it. 
# Note the last line sets $@ in the shell to whatever arguements remain.
print qq{
DH_VERBOSE='$verbose'
DH_NO_ACT='$no_act'
DH_DOPACKAGES='@packages'
DH_DOINDEP='$indep'
DH_DOARCH='$arch'
DH_NOSCRIPTS='$noscripts'
DH_INCLUDE_CONFFILES='$include'
DH_EXCLUDE='$exclude'
DH_EXCLUDE_GREP='$exclude_grep'
DH_D_FLAG='$d_flag'
DH_R_FLAG='$r_flag'
DH_K_FLAG='$k_flag'
DH_TMPDIR='$tmpdir'
DH_U_PARAMS='$u_params'
DH_M_PARAMS='$major'
DH_V_FLAG='$version_info'
DH_V_FLAG_SET='$version_info_set'
DH_PARAMS_ALL='$all'
DH_INIT_SCRIPT='$init_script'
DH_PARSE_ERROR='$parse_error'
set -- @ARGV
};
