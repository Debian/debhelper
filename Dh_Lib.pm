#!/usr/bin/perl -w
#
# Library functions for debhelper programs, perl version.
#
# Joey Hess, GPL copyright 1997, 1998.

package Dh_Lib;
use strict;

use Exporter;
use vars qw(@ISA @EXPORT %dh);
@ISA=qw(Exporter);
@EXPORT=qw(&init &doit &complex_doit &verbose_print &error &warning &tmpdir
	    &pkgfile &pkgext &isnative &autoscript &filearray &GetPackages
	    %dh);

sub init {
	# Check to see if an argument on the command line starts with a dash.
	# if so, we need to pass this off to the resource intensive Getopt::Long,
	# which I'd prefer to avoid loading at all if possible.
	my $parseopt=undef;
	my $arg;
	foreach $arg (@ARGV) {
		if ($arg=~m/^-/) {
			$parseopt=1;
			last;
		}       
	}
	if ($parseopt) {
		eval "use Dh_Getopt";
		error($!) if $@;
		%dh=Dh_Getopt::parseopts();
	}

	# Check to see if DH_VERBOSE environment variable was set, if so,
	# make sure verbose is on.
	if (defined $ENV{DH_VERBOSE} && $ENV{DH_VERBOSE} ne "") {
		$dh{VERBOSE}=1;
	}

	# Check to see if DH_NO_ACT environment variable was set, if so, 
	# make sure no act mode is on.
	if (defined $ENV{DH_NO_ACT} && $ENV{DH_NO_ACT} ne "") {
		$dh{NO_ACT}=1;
	}

	# Get the name of the main binary package (first one listed in
	# debian/control).
	my @allpackages=GetPackages();
	$dh{MAINPACKAGE}=$allpackages[0];

	# Check if packages to build have been specified, if not, fall back to 
	# the default, doing them all.
	if (! defined $dh{DOPACKAGES} || ! @{$dh{DOPACKAGES}}) {
		if ($dh{DOINDEP} || $dh{DOARCH}) {
			# User specified that all arch (in)dep package be 
			# built, and there are none of that type.
			error("I have no package to build");
		}
		push @{$dh{DOPACKAGES}},@allpackages;
	}

	# Check to see if -P was specified. If so, we can only act on a single
	# package.
	if ($dh{TMPDIR} && $#{$dh{DOPACKAGES}} > 0) {
		error("-P was specified, but multiple packages would be acted on (".join(",",@{$dh{DOPACKAGES}}).").");
	}

	# Figure out which package is the first one we were instructed to build.
	# This package gets special treatement: files and directories specified on
	# the command line may affect it.
	$dh{FIRSTPACKAGE}=${$dh{DOPACKAGES}}[0];

	# Split the U_PARAMS up into an array.
	my $u=$dh{U_PARAMS};
	undef $dh{U_PARAMS};
	if (defined $u) {
		push @{$dh{U_PARAMS}}, split(/\s+/,$u);
	}
}

# Escapes out shell metacharacters in a word of shell script.
sub escape_shell { my $word=shift;
	# This list is from _Unix in a Nutshell_. (except '#')
	$word=~s/([\s!"\$()*+#;<>?@\[\]\\`|~])/\\$1/g;
	return $word;
}

# Run a command, and display the command to stdout if verbose mode is on.
# All commands that modifiy files in $TMP should be ran via this 
# function.
#
# Note that this cannot handle complex commands, especially anything
# involving redirection. Use complex_doit instead.
sub doit {
	verbose_print(join(" ",map { escape_shell($_) } @_));
	
	if (! $dh{NO_ACT}) {
		system(@_) == 0
			|| error("command returned error code");
		
	}
}

# Run a command and display the command to stdout if verbose mode is on.
# Use doit() if you can, instead of this function, because this function
# forks a shell. However, this function can handle more complicated stuff
# like redirection.
sub complex_doit {
	verbose_print(join(" ",@_));
	
	if (! $dh{NO_ACT}) {
		# The join makes system get a scalar so it forks off a shell.
		system(join(" ",@_)) == 0
			|| error("command returned error code");
	}			
}

# Print something if the verbose flag is on.
sub verbose_print { my $message=shift;
	if ($dh{VERBOSE}) {
		print "\t$message\n";
	}
}

# Output an error message and exit.
sub error { my $message=shift;
	warning($message);
	exit 1;
}

# Output a warning.
sub warning { my $message=shift;
	print STDERR basename($0).": $message\n";
}

# Returns the basename of the argument passed to it.
sub basename { my $fn=shift;
	$fn=~s:.*/(.*?):$1:;
	return $fn;
}

# Pass it a name of a binary package, it returns the name of the tmp dir to
# use, for that package.
# This is for back-compatability with the debian/tmp tradition.
sub tmpdir { my $package=shift;
	if ($dh{TMPDIR}) {
		return $dh{TMPDIR};
	}
	elsif ($package eq $dh{MAINPACKAGE}) {
		return "debian/tmp";
	}
	else {
		return "debian/$package";
	}
}

# Pass this the name of a binary package, and the name of the file wanted
# for the package, and it will return the actual filename to use. For
# example if the package is foo, and the file is somefile, it will look for
# debian/somefile, and if found return that, otherwise, if the package is
# the main package, it will look for debian/foo, and if found, return that.
# Failing that, it will return nothing.
sub pkgfile { my $package=shift; my $filename=shift;
	if (-e "debian/$package.$filename") {
		return "debian/$package.$filename";
	}
	elsif ($package eq $dh{MAINPACKAGE} && -e "debian/$filename") {
		return "debian/$filename";
	}
	return "";
}

# Pass it a name of a binary package, it returns the name to prefix to files
# in debian for this package.
sub pkgext { my $package=shift;
	if ($package ne $dh{MAINPACKAGE}) {
		return "$package.";
	}
	return "";
}

# Returns 1 if the package is a native debian package, null otherwise.
# As a side effect, sets $dh{VERSION} to the version of this package.
{
	# Caches return code so it only needs to run dpkg-parsechangelog once.
	my %isnative_cache;
	
	sub isnative { my $package=shift;
		if (! defined $isnative_cache{$package}) {
			# Make sure we look at the correct changelog.
			my $isnative_changelog=pkgfile($package,"changelog");
			if (! $isnative_changelog) {
				$isnative_changelog="debian/changelog";
			}

			# Get the package version.
			my $version=`dpkg-parsechangelog -l$isnative_changelog`;
			($dh{VERSION})=$version=~m/Version: (.*)/m;

			# Is this a native Debian package?
			if ($dh{VERSION}=~m/.*-/) {
				$isnative_cache{$package}=0;
			}
			else {
				$isnative_cache{$package}=1;
			}
		}
	
		return $isnative_cache{$package};
	}
}

# Automatically add a shell script snippet to a debian script.
# Only works if the script has #DEBHELPER# in it.
#
# Parameters:
# 1: package
# 2: script to add to
# 3: filename of snippet
# 4: sed to run on the snippet. Ie, s/#PACKAGE#/$PACKAGE/
sub autoscript { my $package=shift; my $script=shift; my $filename=shift; my $sed=shift;
	error "autoscript() not yet implemented (lazy, lazy!)";

	# This is the file we will append to.
	my $outfile="debian/".pkgext($package)."$script.debhelper";

	# Figure out what shell script snippet to use.
	my $infile;
	if ( -e "$main::ENV{DH_AUTOSCRIPTDIR}/$filename" ) {
		$infile="$main::ENV{DH_AUTOSCRIPTDIR}/$filename";
	}
	else {
		if ( -e "/usr/lib/debhelper/autoscripts/$filename" ) {
			$infile="/usr/lib/debhelper/autoscripts/$filename";
		}
		else {
			error("/usr/lib/debhelper/autoscripts/$filename does not exist");
		}
	}

	# TODO: do this in perl, perhaps?
	complex_doit("echo \"# Automatically added by ".basename($0).">> $outfile");
	complex_doit("sed \"$sed\" $infile >> $outfile");
	complex_doit("echo '# End automatically added section' >> $outfile");
}

# Reads in the specified file, one word at a time, and returns an array of
# the result.
sub filearray { my $file=shift;
	my @ret;
	open (DH_FARRAY_IN,"<$file") || error("cannot read $file: $1");
	while (<DH_FARRAY_IN>) {
		push @ret,split(/\s/,$_);
	}
	close DH_FARRAY_IN;
	
	return @ret;
}

# Returns a list of packages in the control file.
# Must pass "arch" or "indep" to specify arch-dependant or -independant
# packages. If nothing is specified, returns all packages.
sub GetPackages { my $type=shift;
	$type="" if ! defined $type;
	my $package="";
	my $arch="";
	my @list=();
	open (CONTROL,"<debian/control") || 
		error("cannot read debian/control: $!\n");
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
			     ($type eq 'arch' && $arch ne 'all') ||
			     ! $type)) {
				push @list, $package;
				$package="";
				$arch="";
			}
		}
	}
	close CONTROL;

	return @list;
}

1
