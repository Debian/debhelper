#!/usr/bin/perl
#
# Because the getopt() program is so horribly broken, I wrote my own argument
# processer that uses the find Getopt::Long module. This is used by all
# debhelper shell scripts.
#
# Joey Hess, GPL copyright 1998.

BEGIN { push @INC, "debian", "/usr/lib/debhelper" }
use strict;
use Dh_Getopt;

# This is a tricky (and nasty) bit: override the error() function, which
# comes from Dh_Lib, with one of our own so we print out the list of errors
# to the shell, which can do what it wants with them.
sub Dh_Getopt::error { my $message=shift;
	print "DH_PARSE_ERROR='$message'\n";
	exit 1;
}

# Parse options.
my %options=Dh_Getopt::parseopts();

# Change a few lists in %options into strings,
# generate some options that only need to be visible to the
# shell scripts so Dh_Getopt doesn't bother generating.
$options{DOPACKAGES}=join " ",@{$options{DOPACKAGES}};
if ($#{$options{EXCLUDE}} > -1) {
	$options{EXCLUDE_GREP}=join '|', @{$options{EXCLUDE}};
	foreach (@{$options{EXCLUDE}}) {
		$options{EXCLUDE_FIND}.="-regex .*".quotemeta($_).".* -or ";
	}
	$options{EXCLUDE_FIND}=~s/ -or $//;
}
$options{EXCLUDE}=join " ",@{$options{EXCLUDE}};

# Check to see if DH_VERBOSE environment variable was set, if so,
# make sure verbose is on.
if (defined $main::ENV{DH_VERBOSE}) {
	if ($main::ENV{DH_VERBOSE} ne undef) {
		$options{VERBOSE}=1;
	}
}

# Check to see if DH_NO_ACT environment variable was set, if so, 
# make sure no act mode is on.
if (defined $main::ENV{DH_NO_ACT}) {
	if ($main::ENV{DH_NO_ACT} ne undef) {
		$options{NO_ACT}=1;
	}
}

# Now output everything, in a format suitable for a shell to eval it.
foreach (keys(%options)) {
	if (defined $options{$_}) {
		print "DH_$_='$options{$_}'\n";
	}
}

# This sets $@ in the shell to whatever arguements remain.
print "set -- @ARGV\n"
