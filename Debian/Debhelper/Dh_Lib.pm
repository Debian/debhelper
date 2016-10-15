#!/usr/bin/perl
#
# Library functions for debhelper programs, perl version.
#
# Joey Hess, GPL copyright 1997-2008.

package Debian::Debhelper::Dh_Lib;
use strict;
use warnings;

use constant {
	# Lowest compat level supported
	'MIN_COMPAT_LEVEL' => 5,
	# Lowest compat level that does *not* cause deprecation
	# warnings
	'LOWEST_NON_DEPRECATED_COMPAT_LEVEL' => 9,
	# Highest "open-beta" compat level.  Remember to notify
	# debian-devel@l.d.o before bumping this.
	'BETA_TESTER_COMPAT' => 10,
	# Highest compat level permitted
	'MAX_COMPAT_LEVEL' => 11,
};

my %NAMED_COMPAT_LEVELS = (
	# The bleeding-edge compat level is deliberately not documented.
	# You are welcome to use it, but please subscribe to the git
	# commit mails if you do.  There is no heads up on changes for
	# bleeding-edge testers as it is mainly intended for debhelper
	# developers.
	'bleeding-edge-tester' => MAX_COMPAT_LEVEL,
	'beta-tester'          => BETA_TESTER_COMPAT,
);

use Exporter qw(import);
use vars qw(@EXPORT %dh);
@EXPORT=qw(&init &doit &doit_noerror &complex_doit &verbose_print &error
            &nonquiet_print &print_and_doit &print_and_doit_noerror
            &warning &tmpdir &pkgfile &pkgext &pkgfilename &isnative
	    &autoscript &filearray &filedoublearray
	    &getpackages &basename &dirname &xargs %dh
	    &compat &addsubstvar &delsubstvar &excludefile &package_arch
	    &is_udeb &debhelper_script_subst &escape_shell
	    &inhibit_log &load_log &write_log &commit_override_log
	    &dpkg_architecture_value &sourcepackage &make_symlink
	    &is_make_jobserver_unavailable &clean_jobserver_makeflags
	    &cross_command &set_buildflags &get_buildoption
	    &install_dh_config_file &error_exitcode &package_multiarch
	    &install_file &install_prog &install_lib &install_dir
	    &get_source_date_epoch &is_cross_compiling
	    &generated_file &autotrigger &package_section
	    &restore_file_on_clean &restore_all_files
	    &open_gz &reset_perm_and_owner
);

# The Makefile changes this if debhelper is installed in a PREFIX.
my $prefix="/usr";

sub init {
	my %params=@_;

	# Check to see if an option line starts with a dash,
	# or DH_OPTIONS is set.
	# If so, we need to pass this off to the resource intensive 
	# Getopt::Long, which I'd prefer to avoid loading at all if possible.
	if ((defined $ENV{DH_OPTIONS} && length $ENV{DH_OPTIONS}) ||
 	    (defined $ENV{DH_INTERNAL_OPTIONS} && length $ENV{DH_INTERNAL_OPTIONS}) ||
	    grep /^-/, @ARGV) {
		eval "use Debian::Debhelper::Dh_Getopt";
		error($@) if $@;
		Debian::Debhelper::Dh_Getopt::parseopts(%params);
	}

	# Another way to set excludes.
	if (exists $ENV{DH_ALWAYS_EXCLUDE} && length $ENV{DH_ALWAYS_EXCLUDE}) {
		push @{$dh{EXCLUDE}}, split(":", $ENV{DH_ALWAYS_EXCLUDE});
	}
	
	# Generate EXCLUDE_FIND.
	if ($dh{EXCLUDE}) {
		$dh{EXCLUDE_FIND}='';
		foreach (@{$dh{EXCLUDE}}) {
			my $x=$_;
			$x=escape_shell($x);
			$x=~s/\./\\\\./g;
			$dh{EXCLUDE_FIND}.="-regex .\\*$x.\\* -or ";
		}
		$dh{EXCLUDE_FIND}=~s/ -or $//;
	}
	
	# Check to see if DH_VERBOSE environment variable was set, if so,
	# make sure verbose is on. Otherwise, check DH_QUIET.
	if (defined $ENV{DH_VERBOSE} && $ENV{DH_VERBOSE} ne "") {
		$dh{VERBOSE}=1;
	} elsif (defined $ENV{DH_QUIET} && $ENV{DH_QUIET} ne "") {
		$dh{QUIET}=1;
	}

	# Check to see if DH_NO_ACT environment variable was set, if so, 
	# make sure no act mode is on.
	if (defined $ENV{DH_NO_ACT} && $ENV{DH_NO_ACT} ne "") {
		$dh{NO_ACT}=1;
	}

	# Get the name of the main binary package (first one listed in
	# debian/control). Only if the main package was not set on the
	# command line.
	if (! exists $dh{MAINPACKAGE} || ! defined $dh{MAINPACKAGE}) {
		my @allpackages=getpackages();
		$dh{MAINPACKAGE}=$allpackages[0];
	}

	# Check if packages to build have been specified, if not, fall back to
	# the default, building all relevant packages.
	if (! defined $dh{DOPACKAGES} || ! @{$dh{DOPACKAGES}}) {
		push @{$dh{DOPACKAGES}}, getpackages('both');
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

	# If no error handling function was specified, just propagate
	# errors out.
	if (! exists $dh{ERROR_HANDLER} || ! defined $dh{ERROR_HANDLER}) {
		$dh{ERROR_HANDLER}='exit \$?';
	}
}

# Run at exit. Add the command to the log files for the packages it acted
# on, if it's exiting successfully.
my $write_log=1;
sub END {
	if ($? == 0 && $write_log && (compat(9, 1) || $ENV{DH_INTERNAL_OVERRIDE})) {
		write_log(basename($0), @{$dh{DOPACKAGES}});
	}
}

sub logfile {
	my $package=shift;
	my $ext=pkgext($package);
	return "debian/${ext}debhelper.log"
}

sub add_override {
	my $line=shift;
	$line="override_$ENV{DH_INTERNAL_OVERRIDE} $line"
		if defined $ENV{DH_INTERNAL_OVERRIDE};
	return $line;
}

sub remove_override {
	my $line=shift;
	$line=~s/^\Qoverride_$ENV{DH_INTERNAL_OVERRIDE}\E\s+//
		if defined $ENV{DH_INTERNAL_OVERRIDE};
	return $line;
}

sub load_log {
	my ($package, $db)=@_;

	my @log;
	open(LOG, "<", logfile($package)) || return;
	while (<LOG>) {
		chomp;
		my $command=remove_override($_);
		push @log, $command;
		$db->{$package}{$command}=1 if defined $db;
	}
	close LOG;
	return @log;
}

sub write_log {
	my $cmd=shift;
	my @packages=@_;

	return if $dh{NO_ACT};

	foreach my $package (@packages) {
		my $log=logfile($package);
		open(LOG, ">>", $log) || error("failed to write to ${log}: $!");
		print LOG add_override($cmd)."\n";
		close LOG;
	}
}

sub commit_override_log {
	my @packages=@_;

	return if $dh{NO_ACT};

	foreach my $package (@packages) {
		my @log=map { remove_override($_) } load_log($package);
		my $log=logfile($package);
		open(LOG, ">", $log) || error("failed to write to ${log}: $!");
		print LOG $_."\n" foreach @log;
		close LOG;
	}
}

sub inhibit_log {
	$write_log=0;
}

# Pass it an array containing the arguments of a shell command like would
# be run by exec(). It turns that into a line like you might enter at the
# shell, escaping metacharacters and quoting arguments that contain spaces.
sub escape_shell {
	my @args=@_;
	my @ret;
	foreach my $word (@args) {
		if ($word=~/\s/) {
			# Escape only a few things since it will be quoted.
			# Note we use double quotes because you cannot
			# escape ' in single quotes, while " can be escaped
			# in double.
			# This does make -V"foo bar" turn into "-Vfoo bar",
			# but that will be parsed identically by the shell
			# anyway..
			$word=~s/([\n`\$"\\])/\\$1/g;
			push @ret, "\"$word\"";
		}
		else {
			# This list is from _Unix in a Nutshell_. (except '#')
			$word=~s/([\s!"\$()*+#;<>?@\[\]\\`|~])/\\$1/g;
			push @ret,$word;
		}
	}
	return join(' ', @ret);
}

# Run a command, and display the command to stdout if verbose mode is on.
# Throws error if command exits nonzero.
#
# All commands that modify files in $TMP should be run via this
# function.
#
# Note that this cannot handle complex commands, especially anything
# involving redirection. Use complex_doit instead.
sub doit {
	doit_noerror(@_) || error_exitcode(join(" ", @_));
}

sub doit_noerror {
	verbose_print(escape_shell(@_));

	if (! $dh{NO_ACT}) {
		return (system(@_) == 0)
	}
	else {
		return 1;
	}
}

sub print_and_doit {
	print_and_doit_noerror(@_) || error_exitcode(join(" ", @_));
}

sub print_and_doit_noerror {
	nonquiet_print(escape_shell(@_));

	if (! $dh{NO_ACT}) {
		return (system(@_) == 0)
	}
	else {
		return 1;
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
		system(join(" ", @_)) == 0 || error_exitcode(join(" ", @_))
	}			
}

sub error_exitcode {
	my $command=shift;
	if ($? == -1) {
		error("$command failed to to execute: $!");
	}
	elsif ($? & 127) {
		error("$command died with signal ".($? & 127));
	}
	elsif ($?) {
		error("$command returned exit code ".($? >> 8));
	}
	else {
		warning("This tool claimed that $command have failed, but it");
		warning("appears to have returned 0.");
		error("Probably a bug in this tool is hiding the actual problem.");
	}
}

# Some shortcut functions for installing files and dirs to always
# have the same owner and mode
# install_file - installs a non-executable
# install_prog - installs an executable
# install_lib  - installs a shared library (some systems may need x-bit, others don't)
# install_dir  - installs a directory
sub install_file {
	doit('install', '-p', '-m0644', @_);
}
sub install_prog {
	doit('install', '-p', '-m0755', @_);
}
sub install_lib {
	doit('install', '-p', '-m0644', @_);
}
sub install_dir {
	my @to_create = grep { not -d $_ } @_;
	doit('install', '-d', @to_create) if @to_create;
}
sub reset_perm_and_owner {
	my ($mode, @paths) = @_;
	doit('chmod', $mode, '--', @paths);
	doit('chown', '0:0', '--', @paths);
}

# Run a command that may have a huge number of arguments, like xargs does.
# Pass in a reference to an array containing the arguments, and then other
# parameters that are the command and any parameters that should be passed to
# it each time.
sub xargs {
	my $args=shift;

        # The kernel can accept command lines up to 20k worth of characters.
	my $command_max=20000; # LINUX SPECIFIC!!
			# (And obsolete; it's bigger now.)
			# I could use POSIX::ARG_MAX, but that would be slow.

	# Figure out length of static portion of command.
	my $static_length=0;
	foreach (@_) {
		$static_length+=length($_)+1;
	}
	
	my @collect=();
	my $length=$static_length;
	foreach (@$args) {
		if (length($_) + 1 + $static_length > $command_max) {
			error("This command is greater than the maximum command size allowed by the kernel, and cannot be split up further. What on earth are you doing? \"@_ $_\"");
		}
		$length+=length($_) + 1;
		if ($length < $command_max) {
			push @collect, $_;
		}
		else {
			doit(@_,@collect) if $#collect > -1;
			@collect=($_);
			$length=$static_length + length($_) + 1;
		}
	}
	doit(@_,@collect) if $#collect > -1;
}

# Print something if the verbose flag is on.
sub verbose_print {
	my $message=shift;
	
	if ($dh{VERBOSE}) {
		print "\t$message\n";
	}
}

# Print something unless the quiet flag is on
sub nonquiet_print {
	my $message=shift;

	if (!$dh{QUIET}) {
		print "\t$message\n";
	}
}

# Output an error message and die (can be caught).
sub error {
	my $message=shift;

	die basename($0).": $message\n";
}

# Output a warning.
sub warning {
	my $message=shift;
	
	print STDERR basename($0).": $message\n";
}

# Returns the basename of the argument passed to it.
sub basename {
	my $fn=shift;

	$fn=~s/\/$//g; # ignore trailing slashes
	$fn=~s:^.*/(.*?)$:$1:;
	return $fn;
}

# Returns the directory name of the argument passed to it.
sub dirname {
	my $fn=shift;
	
	$fn=~s/\/$//g; # ignore trailing slashes
	$fn=~s:^(.*)/.*?$:$1:;
	return $fn;
}

# Pass in a number, will return true iff the current compatibility level
# is less than or equal to that number.
{
	my $warned_compat=0;
	my $c;

	sub compat {
		my $num=shift;
		my $nowarn=shift;
	
		if (! defined $c) {
			$c=1;
			if (-e 'debian/compat') {
				open(my $compat_in, '<', "debian/compat") || error "debian/compat: $!";
				my $l=<$compat_in>;
				close($compat_in);
				if (! defined $l || ! length $l) {
					error("debian/compat must contain a positive number (found an empty first line)");

				}
				else {
					chomp $l;
					$c=$l;
					$c =~ s/^\s*+//;
					$c =~ s/\s*+$//;
					if (exists($NAMED_COMPAT_LEVELS{$c})) {
						$c = $NAMED_COMPAT_LEVELS{$c};
					} elsif ($c !~ m/^\d+$/) {
						error("debian/compat must contain a positive number (found: \"$c\")");
					}
				}
			}
			elsif (not $nowarn) {
				error("Please specify the compatibility level in debian/compat");
			}

			if (defined $ENV{DH_COMPAT}) {
				$c=$ENV{DH_COMPAT};
			}
		}
		if (not $nowarn) {
			if ($c < MIN_COMPAT_LEVEL) {
				error("Compatibility levels before ${\MIN_COMPAT_LEVEL} are no longer supported (level $c requested)");
			}

			if ($c < LOWEST_NON_DEPRECATED_COMPAT_LEVEL && ! $warned_compat) {
				warning("Compatibility levels before ${\LOWEST_NON_DEPRECATED_COMPAT_LEVEL} are deprecated (level $c in use)");
				$warned_compat=1;
			}
	
			if ($c > MAX_COMPAT_LEVEL) {
				error("Sorry, but ${\MAX_COMPAT_LEVEL} is the highest compatibility level supported by this debhelper.");
			}
		}

		return ($c <= $num);
	}
}

# Pass it a name of a binary package, it returns the name of the tmp dir to
# use, for that package.
sub tmpdir {
	my $package=shift;

	if ($dh{TMPDIR}) {
		return $dh{TMPDIR};
	}
	else {
		return "debian/$package";
	}
}

# Pass this the name of a binary package, and the name of the file wanted
# for the package, and it will return the actual existing filename to use.
#
# It tries several filenames:
#   * debian/package.filename.buildarch
#   * debian/package.filename.buildos
#   * debian/package.filename
#   * debian/filename (if the package is the main package)
# If --name was specified then the files
# must have the name after the package name:
#   * debian/package.name.filename.buildarch
#   * debian/package.name.filename.buildos
#   * debian/package.name.filename
#   * debian/name.filename (if the package is the main package)
sub pkgfile {
	my $package=shift;
	my $filename=shift;

	if (defined $dh{NAME}) {
		$filename="$dh{NAME}.$filename";
	}
	
	# First, check for files ending in buildarch and buildos.
	my $match;
	foreach my $file (glob("debian/$package.$filename.*")) {
		next if ! -f $file;
		next if $dh{IGNORE} && exists $dh{IGNORE}->{$file};
		if ($file eq "debian/$package.$filename.".buildarch()) {
			$match=$file;
			# buildarch files are used in preference to buildos files.
			last;
		}
		elsif ($file eq "debian/$package.$filename.".buildos()) {
			$match=$file;
		}
	}
	return $match if defined $match;

	my @try=("debian/$package.$filename");
	if ($package eq $dh{MAINPACKAGE}) {
		push @try, "debian/$filename";
	}
	
	foreach my $file (@try) {
		if (-f $file &&
		    (! $dh{IGNORE} || ! exists $dh{IGNORE}->{$file})) {
			return $file;
		}

	}

	return "";

}

# Pass it a name of a binary package, it returns the name to prefix to files
# in debian/ for this package.
sub pkgext {
	my ($package) = @_;
	return "$package.";
}

# Pass it the name of a binary package, it returns the name to install
# files by in eg, etc. Normally this is the same, but --name can override
# it.
sub pkgfilename {
	my $package=shift;

	if (defined $dh{NAME}) {
		return $dh{NAME};
	}
	return $package;
}

# Returns 1 if the package is a native debian package, null otherwise.
# As a side effect, sets $dh{VERSION} to the version of this package.
{
	# Caches return code so it only needs to run dpkg-parsechangelog once.
	my %isnative_cache;
	
	sub isnative {
		my $package=shift;

		return $isnative_cache{$package} if defined $isnative_cache{$package};
		
		# Make sure we look at the correct changelog.
		my $isnative_changelog=pkgfile($package,"changelog");
		if (! $isnative_changelog) {
			$isnative_changelog="debian/changelog";
		}
		# Get the package version.
		my $version=`dpkg-parsechangelog -l$isnative_changelog -SVersion`;
		chomp($dh{VERSION} = $version);
		# Did the changelog parse fail?
		if ($dh{VERSION} eq q{}) {
			error("changelog parse failure");
		}

		# Is this a native Debian package?
		if (index($dh{VERSION}, '-') > -1) {
			return $isnative_cache{$package}=0;
		}
		else {
			return $isnative_cache{$package}=1;
		}
	}
}

# Automatically add a shell script snippet to a debian script.
# Only works if the script has #DEBHELPER# in it.
#
# Parameters:
# 1: package
# 2: script to add to
# 3: filename of snippet
# 4: either text: shell-quoted sed to run on the snippet. Ie, 's/#PACKAGE#/$PACKAGE/'
#    or a sub to run on each line of the snippet. Ie sub { s/#PACKAGE#/$PACKAGE/ }
sub autoscript {
	my $package=shift;
	my $script=shift;
	my $filename=shift;
	my $sed=shift || "";

	# This is the file we will modify.
	my $outfile="debian/".pkgext($package)."$script.debhelper";

	# Figure out what shell script snippet to use.
	my $infile;
	if (defined($ENV{DH_AUTOSCRIPTDIR}) && 
	    -e "$ENV{DH_AUTOSCRIPTDIR}/$filename") {
		$infile="$ENV{DH_AUTOSCRIPTDIR}/$filename";
	}
	else {
		if (-e "$prefix/share/debhelper/autoscripts/$filename") {
			$infile="$prefix/share/debhelper/autoscripts/$filename";
		}
		else {
			error("$prefix/share/debhelper/autoscripts/$filename does not exist");
		}
	}

	if (-e $outfile && ($script eq 'postrm' || $script eq 'prerm')
	   && !compat(5)) {
		# Add fragments to top so they run in reverse order when removing.
		complex_doit("echo \"# Automatically added by ".basename($0)."\"> $outfile.new");
		autoscript_sed($sed, $infile, "$outfile.new");
		complex_doit("echo '# End automatically added section' >> $outfile.new");
		complex_doit("cat $outfile >> $outfile.new");
		complex_doit("mv $outfile.new $outfile");
	}
	else {
		complex_doit("echo \"# Automatically added by ".basename($0)."\">> $outfile");
		autoscript_sed($sed, $infile, $outfile);
		complex_doit("echo '# End automatically added section' >> $outfile");
	}
}

sub autoscript_sed {
	my $sed = shift;
	my $infile = shift;
	my $outfile = shift;
	if (ref($sed) eq 'CODE') {
		open(my $in, '<', $infile) or die "$infile: $!";
		open(my $out, '>>', $outfile) or die "$outfile: $!";
		while (<$in>) { $sed->(); print {$out} $_; }
		close($out) or die "$outfile: $!";
		close($in) or die "$infile: $!";
	}
	else {
		complex_doit("sed \"$sed\" $infile >> $outfile");
	}
}

# Adds a trigger to the package
{
	my %VALID_TRIGGER_TYPES = map { $_ => 1 } qw(
		interest interest-await interest-noawait
		activate activate-await activate-noawait
	);

	sub autotrigger {
		my ($package, $trigger_type, $trigger_target) = @_;
		my ($triggers_file, $ifd);

		if (not exists($VALID_TRIGGER_TYPES{$trigger_type})) {
			require Carp;
			Carp::confess("Invalid/unknown trigger ${trigger_type}");
		}
		return if $dh{NO_ACT};

		$triggers_file = generated_file($package, 'triggers');
		if ( -f $triggers_file ) {
			open($ifd, '<', $triggers_file)
				or error("open $triggers_file failed $!");
		} else {
			open($ifd, '<', '/dev/null')
				or error("open /dev/null failed $!");
		}
		open(my $ofd, '>', "${triggers_file}.new")
			or error("open ${triggers_file}.new failed: $!");
		while (my $line = <$ifd>) {
			next if $line =~ m{\A  \Q${trigger_type}\E  \s+
                                   \Q${trigger_target}\E (?:\s|\Z)
                              }x;
			print {$ofd} $line;
		}
		print {$ofd} '# Triggers added by ' . basename($0) . "\n";
		print {$ofd} "${trigger_type} ${trigger_target}\n";
		close($ofd) or error("closing ${triggers_file}.new failed: $!");
		close($ifd);
		doit('mv', '-f', "${triggers_file}.new", $triggers_file);
	}
}

sub generated_file {
	my ($package, $filename, $mkdirs) = @_;
	my $dir = "debian/.debhelper/generated/${package}";
	my $path = "${dir}/${filename}";
	$mkdirs //= 1;
	install_dir($dir) if $mkdirs;
	return $path;
}

# Removes a whole substvar line.
sub delsubstvar {
	my $package=shift;
	my $substvar=shift;

	my $ext=pkgext($package);
	my $substvarfile="debian/${ext}substvars";

	if (-e $substvarfile) {
		complex_doit("grep -a -s -v '^${substvar}=' $substvarfile > $substvarfile.new || true");
		doit("mv", "$substvarfile.new","$substvarfile");
	}
}
				
# Adds a dependency on some package to the specified
# substvar in a package's substvar's file.
sub addsubstvar {
	my $package=shift;
	my $substvar=shift;
	my $deppackage=shift;
	my $verinfo=shift;
	my $remove=shift;

	my $ext=pkgext($package);
	my $substvarfile="debian/${ext}substvars";
	my $str=$deppackage;
	$str.=" ($verinfo)" if defined $verinfo && length $verinfo;

	# Figure out what the line will look like, based on what's there
	# now, and what we're to add or remove.
	my $line="";
	if (-e $substvarfile) {
		my %items;
		open(my $in, '<', $substvarfile) || error "read $substvarfile: $!";
		while (<$in>) {
			chomp;
			if (/^\Q$substvar\E=(.*)/) {
				%items = map { $_ => 1} split(", ", $1);
				
				last;
			}
		}
		close($in);
		if (! $remove) {
			$items{$str}=1;
		}
		else {
			delete $items{$str};
		}
		$line=join(", ", sort keys %items);
	}
	elsif (! $remove) {
		$line=$str;
	}

	if (length $line) {
		 complex_doit("(grep -a -s -v ${substvar} $substvarfile; echo ".escape_shell("${substvar}=$line").") > $substvarfile.new");
		 doit("mv", "$substvarfile.new", $substvarfile);
	}
	else {
		delsubstvar($package,$substvar);
	}
}

# Reads in the specified file, one line at a time. splits on words, 
# and returns an array of arrays of the contents.
# If a value is passed in as the second parameter, then glob
# expansion is done in the directory specified by the parameter ("." is
# frequently a good choice).
sub filedoublearray {
	my $file=shift;
	my $globdir=shift;

	# executable config files are a v9 thing.
	my $x=! compat(8) && -x $file;
	if ($x) {
		require Cwd;
		my $cmd=Cwd::abs_path($file);
		$ENV{"DH_CONFIG_ACT_ON_PACKAGES"} = join(",", @{$dh{"DOPACKAGES"}});
		open (DH_FARRAY_IN, "$cmd |") || error("cannot run $file: $!");
		delete $ENV{"DH_CONFIG_ACT_ON_PACKAGES"};
	}
	else {
		open (DH_FARRAY_IN, '<', $file) || error("cannot read $file: $!");
	}

	my @ret;
	while (<DH_FARRAY_IN>) {
		chomp;
		if (not $x)  {
			next if /^#/ || /^$/;
		}
		my @line;
		# The tricky bit is that the glob expansion is done
		# as if we were in the specified directory, so the
		# filenames that come out are relative to it.
		if (defined($globdir) && ! $x) {
			foreach (map { glob "$globdir/$_" } split) {
				s#^$globdir/##;
				push @line, $_;
			}
		}
		else {
			@line = split;
		}
		push @ret, [@line];
	}

	if (!close(DH_FARRAY_IN)) {
		if ($x) {
			error("Error closing fd/process for $file: $!") if $!;
			error_exitcode("$file (executable config)");
		} else {
			error("problem reading $file: $!");
		}
	}
	
	return @ret;
}

# Reads in the specified file, one word at a time, and returns an array of
# the result. Can do globbing as does filedoublearray.
sub filearray {
	return map { @$_ } filedoublearray(@_);
}

# Passed a filename, returns true if -X says that file should be excluded.
sub excludefile {
        my $filename = shift;
        foreach my $f (@{$dh{EXCLUDE}}) {
                return 1 if $filename =~ /\Q$f\E/;
        }
        return 0;
}

{
	my %dpkg_arch_output;
	sub dpkg_architecture_value {
		my $var = shift;
		if (exists($ENV{$var})) {
			return $ENV{$var};
		}
		elsif (! exists($dpkg_arch_output{$var})) {
			local $_;
			open(PIPE, '-|', 'dpkg-architecture')
				or error("dpkg-architecture failed");
			while (<PIPE>) {
				chomp;
				my ($k, $v) = split(/=/, $_, 2);
				$dpkg_arch_output{$k} = $v;
			}
			close(PIPE);
		}
		return $dpkg_arch_output{$var};
	}
}

# Returns the build architecture.
sub buildarch {
	dpkg_architecture_value('DEB_HOST_ARCH');
}

# Returns the build OS.
sub buildos {
	dpkg_architecture_value("DEB_HOST_ARCH_OS");
}

# Returns a truth value if this seems to be a cross-compile
sub is_cross_compiling {
	return dpkg_architecture_value("DEB_BUILD_GNU_TYPE")
	    ne dpkg_architecture_value("DEB_HOST_GNU_TYPE");
}

# Passed an arch and a list of arches to match against, returns true if matched
{
	my %knownsame;

	sub samearch {
		my $arch=shift;
		my @archlist=split(/\s+/,shift);
	
		foreach my $a (@archlist) {
			if (exists $knownsame{$arch}{$a}) {
				return 1 if $knownsame{$arch}{$a};
				next;
			}

			require Dpkg::Arch;
			if (Dpkg::Arch::debarch_is($arch, $a)) {
				return $knownsame{$arch}{$a}=1;
			}
			else {
				$knownsame{$arch}{$a}=0;
			}
		}
	
		return 0;
	}
}

# Returns source package name
sub sourcepackage {
	open (my $fd, '<', 'debian/control') ||
	    error("cannot read debian/control: $!\n");
	while (<$fd>) {
		chomp;
		s/\s+$//;
		if (/^Source:\s*(.*)/i) {
			close($fd);
			return $1;
		}
	}

	close($fd);
	error("could not find Source: line in control file.");
}

# Returns a list of packages in the control file.
# Pass "arch" or "indep" to specify arch-dependant (that will be built
# for the system's arch) or independant. If nothing is specified,
# returns all packages. Also, "both" returns the union of "arch" and "indep"
# packages.
#
# As a side effect, populates %package_arches and %package_types
# with the types of all packages (not only those returned).
my (%package_types, %package_arches, %package_multiarches, %packages_by_type,
    %package_sections);
sub getpackages {
	my ($type) = @_;
	error("getpackages: First argument must be one of \"arch\", \"indep\", or \"both\"")
		if defined($type) and $type ne 'both' and $type ne 'indep' and $type ne 'arch';

	$type //= 'all-listed-in-control-file';

	if (%packages_by_type) {
		return @{$packages_by_type{$type}};
	}

	$packages_by_type{$_} = [] for qw(both indep arch all-listed-in-control-file);
	

	my $package="";
	my $arch="";
	my $section="";
	my ($package_type, $multiarch, %seen, @profiles, $source_section,
		$included_in_build_profile);
	if (exists $ENV{'DEB_BUILD_PROFILES'}) {
		@profiles=split /\s+/, $ENV{'DEB_BUILD_PROFILES'};
	}
	open (my $fd, '<', 'debian/control') ||
		error("cannot read debian/control: $!\n");
	while (<$fd>) {
		chomp;
		s/\s+$//;
		if (/^Package:\s*(.*)/i) {
			$package=$1;
			# Detect duplicate package names in the same control file.
			if (! $seen{$package}) {
				$seen{$package}=1;
			}
			else {
				error("debian/control has a duplicate entry for $package");
			}
			$package_type="deb";
			$included_in_build_profile=1;
		}
		if (/^Section:\s(.*)\s*$/i) {
			$section = $1;
		}
		if (/^Architecture:\s*(.*)/i) {
			$arch=$1;
		}
		if (/^(?:X[BC]*-)?Package-Type:\s*(.*)/i) {
			$package_type=$1;
		}
		if (/^Multi-Arch: \s*(.*)\s*/i) {
			$multiarch = $1;
		}
		# rely on libdpkg-perl providing the parsing functions because
		# if we work on a package with a Build-Profiles field, then a
		# high enough version of dpkg-dev is needed anyways
		if (/^Build-Profiles:\s*(.*)/i) {
		        my $build_profiles=$1;
			eval {
				require Dpkg::BuildProfiles;
				my @restrictions=Dpkg::BuildProfiles::parse_build_profiles($build_profiles);
				if (@restrictions) {
					$included_in_build_profile=Dpkg::BuildProfiles::evaluate_restriction_formula(\@restrictions, \@profiles);
				}
			};
			if ($@) {
				error("The control file has a Build-Profiles field. Requires libdpkg-perl >= 1.17.14");
			}
		}

		if (!$_ or eof) { # end of stanza.
			if ($package) {
				$package_types{$package}=$package_type;
				$package_arches{$package}=$arch;
				$package_multiarches{$package} = $multiarch;
				$package_sections{$package} = $section || $source_section;
				if ($included_in_build_profile) {
					push(@{$packages_by_type{'all-listed-in-control-file'}}, $package);
					if ($arch eq 'all') {
						push(@{$packages_by_type{'indep'}}, $package);
						push(@{$packages_by_type{'both'}}, $package);
					} elsif ($arch eq 'any' ||
							 ($arch ne 'all' && samearch(buildarch(), $arch))) {
						push(@{$packages_by_type{'arch'}}, $package);
						push(@{$packages_by_type{'both'}}, $package);
					}
				}
			} elsif ($section and not defined($source_section)) {
				$source_section = $section;
			}
			$package='';
			$arch='';
			$section='';
		}
	}
	close($fd);

	return @{$packages_by_type{$type}};
}

# Returns the arch a package will build for.
sub package_arch {
	my $package=shift;
	
	if (! exists $package_arches{$package}) {
		warning "package $package is not in control info";
		return buildarch();
	}
	return $package_arches{$package} eq 'all' ? "all" : buildarch();
}

# Returns the multiarch value of a package.
sub package_multiarch {
	my $package=shift;

	# Test the architecture field instead, as it is common for a
	# package to not have a multi-arch value.
	if (! exists $package_arches{$package}) {
		warning "package $package is not in control info";
		# The only sane default
		return 'no';
	}
	return $package_multiarches{$package} // 'no';
}

# Returns the (raw) section value of a package (possibly including component).
sub package_section {
	my ($package) = @_;

	# Test the architecture field instead, as it is common for a
	# package to not have a multi-arch value.
	if (! exists $package_sections{$package}) {
		warning "package $package is not in control info";
		return 'unknown';
	}
	return $package_sections{$package} // 'unknown';
}

# Return true if a given package is really a udeb.
sub is_udeb {
	my $package=shift;
	
	if (! exists $package_types{$package}) {
		warning "package $package is not in control info";
		return 0;
	}
	return $package_types{$package} eq 'udeb';
}

# Handles #DEBHELPER# substitution in a script; also can generate a new
# script from scratch if none exists but there is a .debhelper file for it.
sub debhelper_script_subst {
	my $package=shift;
	my $script=shift;
	
	my $tmp=tmpdir($package);
	my $ext=pkgext($package);
	my $file=pkgfile($package,$script);

	if ($file ne '') {
		if (-f "debian/$ext$script.debhelper") {
			# Add this into the script, where it has #DEBHELPER#
			complex_doit("perl -pe 's~#DEBHELPER#~qx{cat debian/$ext$script.debhelper}~eg' < $file > $tmp/DEBIAN/$script");
		}
		else {
			# Just get rid of any #DEBHELPER# in the script.
			complex_doit("sed s/#DEBHELPER#// < $file > $tmp/DEBIAN/$script");
		}
		reset_perm_and_owner('0755', "$tmp/DEBIAN/$script");
	}
	elsif ( -f "debian/$ext$script.debhelper" ) {
		complex_doit("printf '#!/bin/sh\nset -e\n' > $tmp/DEBIAN/$script");
		complex_doit("cat debian/$ext$script.debhelper >> $tmp/DEBIAN/$script");
		reset_perm_and_owner('0755', "$tmp/DEBIAN/$script");
	}
}


# make_symlink($dest, $src[, $tmp]) creates a symlink from  $dest -> $src.
# if $tmp is given, $dest will be created within it.
# Usually $tmp should be the value of tmpdir($package);
sub make_symlink{
	my $dest = shift;
	my $src = _expand_path(shift);
	my $tmp = shift;
        $tmp = '' if not defined($tmp);
	$src=~s:^/::;
	$dest=~s:^/::;

	if ($src eq $dest) {
		warning("skipping link from $src to self");
		return;
	}

	# Make sure the directory the link will be in exists.
	my $basedir=dirname("$tmp/$dest");
	install_dir($basedir);

	# Policy says that if the link is all within one toplevel
	# directory, it should be relative. If it's between
	# top level directories, leave it absolute.
	my @src_dirs=split(m:/+:,$src);
	my @dest_dirs=split(m:/+:,$dest);
	if (@src_dirs > 0 && $src_dirs[0] eq $dest_dirs[0]) {
		# Figure out how much of a path $src and $dest
		# share in common.
		my $x;
		for ($x=0; $x < @src_dirs && $src_dirs[$x] eq $dest_dirs[$x]; $x++) {}
		# Build up the new src.
		$src="";
		for (1..$#dest_dirs - $x) {
			$src.="../";
		}
		for ($x .. $#src_dirs) {
			$src.=$src_dirs[$_]."/";
		}
		if ($x > $#src_dirs && ! length $src) {
			$src="."; # special case
		}
		$src=~s:/$::;
	}
	else {
		# Make sure it's properly absolute.
		$src="/$src";
	}

	if (-d "$tmp/$dest" && ! -l "$tmp/$dest") {
		error("link destination $tmp/$dest is a directory");
	}
	doit("rm", "-f", "$tmp/$dest");
	doit("ln","-sf", $src, "$tmp/$dest");
}

# _expand_path expands all path "." and ".." components, but doesn't
# resolve symbolic links.
sub _expand_path {
	my $start = @_ ? shift : '.';
	my @pathname = split(m:/+:,$start);
	my @respath;
	for my $entry (@pathname) {
		if ($entry eq '.' || $entry eq '') {
			# Do nothing
		}
		elsif ($entry eq '..') {
			if ($#respath == -1) {
				# Do nothing
			}
			else {
				pop @respath;
			}
		}
		else {
			push @respath, $entry;
		}
	}

	my $result;
	for my $entry (@respath) {
		$result .= '/' . $entry;
	}
	if (! defined $result) {
		$result="/"; # special case
	}
	return $result;
}

# Checks if make's jobserver is enabled via MAKEFLAGS, but
# the FD used to communicate with it is actually not available.
sub is_make_jobserver_unavailable {
	if (exists $ENV{MAKEFLAGS} && 
	    $ENV{MAKEFLAGS} =~ /(?:^|\s)--jobserver-(?:fds|auth)=(\d+)/) {
		if (!open(my $in, "<&$1")) {
			return 1; # unavailable
		}
		else {
			close $in;
			return 0; # available
		}
	}

	return; # no jobserver specified
}

# Cleans out jobserver options from MAKEFLAGS.
sub clean_jobserver_makeflags {
	if (exists $ENV{MAKEFLAGS}) {
		if ($ENV{MAKEFLAGS} =~ /(?:^|\s)--jobserver-(?:fds|auth)=\d+/) {
			$ENV{MAKEFLAGS} =~ s/(?:^|\s)--jobserver-(?:fds|auth)=\S+//g;
			$ENV{MAKEFLAGS} =~ s/(?:^|\s)-j\b//g;
		}
		delete $ENV{MAKEFLAGS} if $ENV{MAKEFLAGS} =~ /^\s*$/;
	}
}

# If cross-compiling, returns appropriate cross version of command.
sub cross_command {
	my $command=shift;
	if (is_cross_compiling()) {
		return dpkg_architecture_value("DEB_HOST_GNU_TYPE")."-$command";
	}
	else {
		return $command;
	}
}

# Returns the SOURCE_DATE_EPOCH ENV variable if set OR computes it
# from the latest changelog entry, sets the SOURCE_DATE_EPOCH ENV
# variable and returns the computed value.
sub get_source_date_epoch {
	return $ENV{SOURCE_DATE_EPOCH} if exists($ENV{SOURCE_DATE_EPOCH});
	eval "use Dpkg::Changelog::Debian";
	if ($@) {
		warning "unable to set SOURCE_DATE_EPOCH: $@";
		return;
	}
	eval "use Time::Piece";
	if ($@) {
		warning "unable to set SOURCE_DATE_EPOCH: $@";
		return;
	}

	my $changelog = Dpkg::Changelog::Debian->new(range => {"count" => 1});
	$changelog->load("debian/changelog");

	my $tt = @{$changelog}[0]->get_timestamp();
	$tt =~ s/\s*\([^\)]+\)\s*$//; # Remove the optional timezone codename
	my $timestamp = Time::Piece->strptime($tt, "%a, %d %b %Y %T %z");

	return $ENV{SOURCE_DATE_EPOCH} = $timestamp->epoch();
}

# Sets environment variables from dpkg-buildflags. Avoids changing
# any existing environment variables.
sub set_buildflags {
	return if $ENV{DH_INTERNAL_BUILDFLAGS};
	$ENV{DH_INTERNAL_BUILDFLAGS}=1;

	# For the side effect of computing the SOURCE_DATE_EPOCH variable.
	get_source_date_epoch();

	return if compat(8);

	# Export PERL_USE_UNSAFE_INC as a transitional step to allow us
	# to remove . from @INC by default without breaking packages which
	# rely on this [CVE-2016-1238]
	$ENV{PERL_USE_UNSAFE_INC}=1;

	eval "use Dpkg::BuildFlags";
	if ($@) {
		warning "unable to load build flags: $@";
		return;
	}

	my $buildflags = Dpkg::BuildFlags->new();
	$buildflags->load_config();
	foreach my $flag ($buildflags->list()) {
		next unless $flag =~ /^[A-Z]/; # Skip flags starting with lowercase
		if (! exists $ENV{$flag}) {
			$ENV{$flag} = $buildflags->get($flag);
		}
	}
}

# Gets a DEB_BUILD_OPTIONS option, if set.
sub get_buildoption {
	my $wanted=shift;

	return undef unless exists $ENV{DEB_BUILD_OPTIONS};

	foreach my $opt (split(/\s+/, $ENV{DEB_BUILD_OPTIONS})) {
		# currently parallel= is the only one with a parameter
		if ($opt =~ /^parallel=(-?\d+)$/ && $wanted eq 'parallel') {
			return $1;
		}
		elsif ($opt eq $wanted) {
			return 1;
		}
	}
}

# install a dh config file (e.g. debian/<pkg>.lintian-overrides) into
# the package.  Under compat 9+ it may execute the file and use its
# output instead.
#
# install_dh_config_file(SOURCE, TARGET[, MODE])
sub install_dh_config_file {
	my ($source, $target, $mode) = @_;
	$mode = 0644 if not defined($mode);

	if (!compat(8) and -x $source) {
		my @sstat = stat(_) || error("cannot stat $source: $!");
		open(my $tfd, '>', $target) || error("cannot open $target: $!");
		chmod($mode, $tfd) || error("cannot chmod $target: $!");
		open(my $sfd, '-|', $source) || error("cannot run $source: $!");
		while (my $line = <$sfd>) {
			print ${tfd} $line;
		}
		if (!close($sfd)) {
			error("cannot close handle from $source: $!") if $!;
			error_exitcode($source);
		}
		close($tfd) || error("cannot close $target: $!");
		# Set the mtime (and atime) to ensure reproducibility.
		utime($sstat[9], $sstat[9], $target);
	} else {
		my $str_mode = sprintf('%#4o', $mode);
		doit('install', '-p', "-m${str_mode}", $source, $target);
	}
	return 1;
}

sub restore_file_on_clean {
	my ($file) = @_;
	my $bucket_index = 'debian/.debhelper/bucket/index';
	my $bucket_dir = 'debian/.debhelper/bucket/files';
	my $checksum;
	install_dir($bucket_dir);
	if ($file =~ m{^/}) {
		error("restore_file_on_clean requires a path relative to the package dir");
	}
	$file =~ s{^\./}{}g;
	$file =~ s{//++}{}g;
	if ($file =~ m{^\.} or $file =~ m{/CVS/} or $file =~ m{/\.svn/}) {
		# We do not want to smash a Vcs repository by accident.
		warning("Attempt to store $file, which looks like a VCS file or");
		warning("a hidden package file (like quilt's \".pc\" directory");
		error("This tool probably contains a bug.");
	}
	if (-l $file or not -f _) {
		error("Cannot store $file, which is a non-file (incl. a symlink)");
	}
	require Digest::SHA;

	$checksum = Digest::SHA->new('256')->addfile($file, 'b')->hexdigest;

	if (not $dh{NO_ACT}) {
		my ($in_index);
		open(my $fd, '+>>', $bucket_index)
			or error("open($bucket_index, a+) failed: $!");
		seek($fd, 0, 0);
		while (my $line = <$fd>) {
			my ($cs, $stored_file);
			chomp($line);
			($cs, $stored_file) = split(m/ /, $line, 2);
			next if ($stored_file ne $file);
			$in_index = 1;
		}
		if (not $in_index) {
			# Copy and then rename so we always have the full copy of
			# the file in the correct place (if any at all).
			doit('cp', '-an', '--reflink=auto', $file, "${bucket_dir}/${checksum}.tmp");
			doit('mv', '-f', "${bucket_dir}/${checksum}.tmp", "${bucket_dir}/${checksum}");
			print {$fd} "${checksum} ${file}\n";
		}
		close($fd) or error("close($bucket_index) failed: $!");
	}

	return 1;
}

sub restore_all_files {
	my $bucket_index = 'debian/.debhelper/bucket/index';
	my $bucket_dir = 'debian/.debhelper/bucket/files';

	return if not -f $bucket_index;
	open(my $fd, '<', $bucket_index)
		or error("open($bucket_index) failed: $!");

	while (my $line = <$fd>) {
		my ($cs, $stored_file, $bucket_file);
		chomp($line);
		($cs, $stored_file) = split(m/ /, $line, 2);
		$bucket_file = "${bucket_dir}/${cs}";
		# Restore by copy and then rename.  This ensures that:
		# 1) If dh_clean is interrupted, we can always do a full restore again
		#    (otherwise, we would be missing some of the files and have to handle
		#     that with scary warnings)
		# 2) The file is always fully restored or in its "pre-restore" state.
		doit('cp', '-an', '--reflink=auto', $bucket_file, "${bucket_file}.tmp");
		doit('mv', '-Tf', "${bucket_file}.tmp", $stored_file);
	}
	close($fd);
	return;
}

sub open_gz {
	my ($file) = @_;
	my $fd;
	eval {
		require PerlIO::gzip;
	};
	if ($@) {
		open($fd, '-|', 'gzip', '-dc', $file)
		  or die("gzip -dc $file failed: $!");
	} else {
		open($fd, '<:gzip', $file)
		  or die("open $file [<:gzip] failed: $!");
	}
	return $fd;
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
