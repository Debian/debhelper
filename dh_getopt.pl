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

use Getopt::Long;

# Enable bundling of short command line options.
Getopt::Long::config("bundling");

# Parse options.
GetOptions(
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
);

# Check to see if -V was specified. If so, but no parameters were passed,
# the variable will be defined but empty.
if (defined($version_info)) {
	$version_info_set=1;
}

# Now output everything, in a format suitable for a shell to eval it. 
# Note the last line sets $@ in the shell to whatever arguements remain.
print qq{
DH_VERBOSE='$verbose'
DH_DOPACKAGES='@packages'
DH_DOINDEP='$indep'
DH_DOARCH='$arch'
DH_NOSCRIPTS='$noscripts'
DH_EXCLUDE='$include'
DH_D_FLAG='$d_flag'
DH_R_FLAG='$r_flag'
DH_K_FLAG='$k_flag'
DH_TMPDIR='$tmpdir'
DH_U_PARAMS='$u_params'
DH_M_PARAMS='$major'
DH_V_FLAG='$version_info'
DH_V_FLAG_SET='$version_info_set'
DH_PARAMS_ALL='$all'
DH_PARSE_ERROR='$parse_error'
set -- @ARGV
};
