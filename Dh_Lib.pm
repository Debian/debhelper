#!/usr/bin/perl -w
#
# Library functions for debhelper programs, perl version.
#
# Joey Hess, GPL copyright 1997, 1998.

package Dh_Lib;

use Exporter;
use vars qw(%dh);
@ISA=qw(Exporter);
@EXPORT=qw(&init &doit &complex_doit &verbose_print &error &warning &tmpdir
	    &pkgfile &pkgext &isnative &autoscript &filearray &GetPackages
	    %dh);

sub init {
	# Check to see if an argument on the command line starts with a dash.
	# if so, we need to pass this off to the resource intensive Getopt::Long,
	# which I'd prefer to avoid loading at all if possible.
	my $parseopt=undef;
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

	# Get the name of the main binary package (first one listed in
	# debian/control).
	my @allpackages=GetPackages();
	$dh{MAINPACKAGE}=$allpackages[0];

	# Check if packages to build have been specified, if not, fall back to 
	# the default, doing them all.
	if (! @{$dh{DOPACKAGES}}) {
		if ($dh{DH_DOINDEP} || $dh{DH_DOARCH}) {
			error("I have no package to build.");
		}
		push @{$dh{DOPACKAGES}},@allpackages;
	}

	# Check to see if -P was specified. If so, we can only act on a single
	# package.
	if ($dh{TMPDIR} || $#{$dh{DOPACKAGES}} > 0) {
		error("-P was specified, but multiple packages would be acted on.");
	}

	# Figure out which package is the first one we were instructed to build.
	# This package gets special treatement: files and directories specified on
	# the command line may affect it.
	$dh{FIRSTPACKAGE}=${$dh{DOPACKAGES}}[0];
}

# Run a command, and display the command to stdout if verbose mode is on.
# All commands that modifiy files in $TMP should be ran via this 
# function.
#
# Note that this cannot handle complex commands, especially anything
# involving redirection. Use complex_doit instead.
sub doit {
	verbose_print(join(" ",,@_));
	
	if (! $dh{NO_ACT}) {
		system(@_) == 0
			|| error("command returned error code");
		
	}
}

# This is an identical command to doit, except the parameters passed to it
# can include complex shell stull like redirection and compound commands.
sub complex_doit {
	error("complex_doit() not yet supported");
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
	my $fn=$0;
	$fn=~s:.*/(.*?):$1:;
	print STDERR "$fn: $message\n";
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
	if ($package ne $MAINPACKAGE) {
		return "$package.";
	}
	return "";
}

# Returns 1 if the package is a native debian package, null otherwise.
# As a side effect, sets $dh{VERSION} to the version of this package.
{
	# Caches return code so it only needs to run dpkg-parsechangelog once.
	my $isnative_cache;
	
	sub isnative { my $package=shift;
		if ($isnative_cache eq undef) {
			# Make sure we look at the correct changelog.
			my $isnative_changelog=pkgfile($package,"changelog");
			if (! $isnative_changelog) {
				$isnative_changelog="debian/changelog";
			}
			
			# Get the package version.
			my $version=`dpkg-parsechangelog -l$isnative_changelog`;
			($dh{VERSION})=$version=~s/[^|\n]Version: \(.*\)\n//m;
	
			# Is this a native Debian package?
			if ($dh{VERSION}=~m/.*-/) {
				$isnative_cache=1;
			}
			else {
				$isnative_cache=0;
			}
		}
	
		return $isnative_cache;
	}
}

# Automatically add a shell script snippet to a debian script.
# Only works if the script has #DEBHELPER# in it.
#
# Parameters:
# 1: script to add to
# 2: filename of snippet
# 3: sed commands to run on the snippet. Ie, s/#PACKAGE#/$PACKAGE/
sub autoscript {
	error "autoscript() not yet implemented (lazy, lazy!)";
#	autoscript_script=$1
#	autoscript_filename=$2
#	autoscript_sed=$3
#	autoscript_debscript=debian/`pkgext $PACKAGE`$autoscript_script.debhelper
#
#	if [ -e "$DH_AUTOSCRIPTDIR/$autoscript_filename" ]; then
#		autoscript_filename="$DH_AUTOSCRIPTDIR/$autoscript_filename"
#	else
#		if [ -e "/usr/lib/debhelper/autoscripts/$autoscript_filename" ]; then
#			autoscript_filename="/usr/lib/debhelper/autoscripts/$autoscript_filename"
#		else
#			error "/usr/lib/debhelper/autoscripts/$autoscript_filename does not exist"
#		fi
#	fi
#
#	complex_doit "echo \"# Automatically added by `basename $0`\" >> $autoscript_debscript"
#	complex_doit "sed \"$autoscript_sed\" $autoscript_filename >> $autoscript_debscript"
#	complex_doit "echo '# End automatically added section' >> $autoscript_debscript"
}

# Reads in the specified file, one word at a time, and returns an array of
# the result.
sub filearray { $file=shift;
	my @ret;
	open (DH_FARRAY_IN,"<$file") || error("cannot read $file: $1");
	while (<DH_FARRAY_IN>) {
		push @ret,split(/\s/,$_);
	}
	close DH_ARRAY;
	
	return @ret;
}

# Returns a list of packages in the control file.
# Must pass "arch" or "indep" to specify arch-dependant or -independant
# packages. If nothing is specified, returns all packages.
sub GetPackages { $type=shift;
	my $package;
	my $arch;
	my @list;
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
				undef $package;
				undef $arch;
			}
		}
	}
	close CONTROL;

	return @list;
}

1
