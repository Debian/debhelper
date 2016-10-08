#!/usr/bin/perl

use Test::More tests => 300;

use strict;
use warnings;
use IPC::Open2;
use Cwd ();
use File::Temp qw(tempfile tempdir);
use File::Basename ();

# Let the tests to be run from anywhere but currect directory
# is expected to be the one where this test lives in.
chdir File::Basename::dirname($0) or die "Unable to chdir to ".File::Basename::dirname($0);

use_ok( 'Debian::Debhelper::Dh_Lib' );
use_ok( 'Debian::Debhelper::Buildsystem' );
use_ok( 'Debian::Debhelper::Dh_Buildsystems' );

my $TOPDIR = "../..";
my @STEPS = qw(configure build test install clean);
my $BS_CLASS = 'Debian::Debhelper::Buildsystem';

my ($bs, @bs, %bs);
my ($tmp, @tmp, %tmp);
my ($tmpdir, $builddir, $default_builddir);

### Common subs ####
sub touch {
	my $file=shift;
	my $chmod=shift;
	open FILE, ">", $file and close FILE or die "Unable to touch $file";
	chmod $chmod, $file if defined $chmod;
}

sub cleandir {
	my $dir=shift;
	system ("find", $dir, "-type", "f", "-delete");
}
sub readlines {
	my $h=shift;
	my @lines = <$h>;
	close $h;
	chop @lines;
	return \@lines;
}

sub process_stdout {
	my ($cmdline, $stdin) = @_;
	my ($reader, $writer);

	my $pid = open2($reader, $writer, $cmdline) or die "Unable to exec $cmdline";
	print $writer $stdin if $stdin;
	close $writer;
	waitpid($pid, 0);
	$? = $? >> 8; # exit status
	return readlines($reader);
}

sub write_debian_rules {
	my $contents=shift;
	my $backup;

	if (-f "debian/rules") {
		(undef, $backup) = tempfile(DIR => ".", OPEN => 0);
		rename "debian/rules", $backup;
	}
	# Write debian/rules if requested
	if ($contents) {
		open(my $f, ">", "debian/rules");
		print $f $contents;;
		close($f);
		chmod 0755, "debian/rules";
	}
	return $backup;
}

### Test Buildsystem class API methods
is( $BS_CLASS->canonpath("path/to/the/./nowhere/../../somewhere"),
    "path/to/somewhere", "canonpath no1" );
is( $BS_CLASS->canonpath("path/to/../forward/../../somewhere"),
    "somewhere","canonpath no2" );
is( $BS_CLASS->canonpath("path/to/../../../somewhere"),
    "../somewhere","canonpath no3" );
is( $BS_CLASS->canonpath("./"), ".", "canonpath no4" );
is( $BS_CLASS->canonpath("/absolute/path/./somewhere/../to/nowhere"),
    "/absolute/path/to/nowhere", "canonpath no5" );
is( $BS_CLASS->_rel2rel("path/my/file", "path/my", "/tmp"),
    "file", "_rel2rel no1" );
is( $BS_CLASS->_rel2rel("path/dir/file", "path/my", "/tmp"),
    "../dir/file", "_rel2rel no2" );
is( $BS_CLASS->_rel2rel("file", "/root/path/my", "/root"),
    "/root/file", "_rel2rel abs no3" );
is( $BS_CLASS->_rel2rel(".", ".", "/tmp"), ".", "_rel2rel no4" );
is( $BS_CLASS->_rel2rel("path", "path/", "/tmp"), ".", "_rel2rel no5" );
is( $BS_CLASS->_rel2rel("/absolute/path", "anybase", "/tmp"),
    "/absolute/path", "_rel2rel abs no6");
is( $BS_CLASS->_rel2rel("relative/path", "/absolute/base", "/tmp"),
    "/tmp/relative/path", "_rel2rel abs no7");

### Test Buildsystem class path API methods under different configurations
sub test_buildsystem_paths_api {
	my ($bs, $config, $expected)=@_;

	my $api_is = sub {
		my ($got, $name)=@_;
		is( $got, $expected->{$name}, "paths API ($config): $name")
	};

	&$api_is( $bs->get_sourcedir(), 'get_sourcedir()' );
	&$api_is( $bs->get_sourcepath("a/b"), 'get_sourcepath(a/b)' );
	&$api_is( $bs->get_builddir(), 'get_builddir()' );
	&$api_is( $bs->get_buildpath(), 'get_buildpath()' );
	&$api_is( $bs->get_buildpath("a/b"), 'get_buildpath(a/b)' );
	&$api_is( $bs->get_source_rel2builddir(), 'get_source_rel2builddir()' );
	&$api_is( $bs->get_source_rel2builddir("a/b"), 'get_source_rel2builddir(a/b)' );
	&$api_is( $bs->get_build_rel2sourcedir(), 'get_build_rel2sourcedir()' );
	&$api_is( $bs->get_build_rel2sourcedir("a/b"), 'get_build_rel2sourcedir(a/b)' );
}

# Defaults
$bs = $BS_CLASS->new();
$default_builddir = $bs->DEFAULT_BUILD_DIRECTORY();
%tmp = (
	"get_sourcedir()" => ".",
	"get_sourcepath(a/b)" => "./a/b",
	"get_builddir()" => undef,
	"get_buildpath()" => ".",
	"get_buildpath(a/b)" =>  "./a/b",
	"get_source_rel2builddir()" => ".",
	"get_source_rel2builddir(a/b)" => "./a/b",
	"get_build_rel2sourcedir()" => ".",
	"get_build_rel2sourcedir(a/b)" => "./a/b",
);
test_buildsystem_paths_api($bs, "no builddir, no sourcedir", \%tmp);

# builddir=bld/dir
$bs = $BS_CLASS->new(builddir => "bld/dir");
%tmp = (
	"get_sourcedir()" => ".",
	"get_sourcepath(a/b)" => "./a/b",
	"get_builddir()" => "bld/dir",
	"get_buildpath()" => "bld/dir",
	"get_buildpath(a/b)" =>  "bld/dir/a/b",
	"get_source_rel2builddir()" => "../..",
	"get_source_rel2builddir(a/b)" => "../../a/b",
	"get_build_rel2sourcedir()" => "bld/dir",
	"get_build_rel2sourcedir(a/b)" => "bld/dir/a/b",
);
test_buildsystem_paths_api($bs, "builddir=bld/dir, no sourcedir", \%tmp);

# Default builddir, sourcedir=autoconf
$bs = $BS_CLASS->new(builddir => undef, sourcedir => "autoconf");
%tmp = (
	"get_sourcedir()" => "autoconf",
	"get_sourcepath(a/b)" => "autoconf/a/b",
	"get_builddir()" => "$default_builddir",
	"get_buildpath()" => "$default_builddir",
	"get_buildpath(a/b)" =>  "$default_builddir/a/b",
	"get_source_rel2builddir()" => "../autoconf",
	"get_source_rel2builddir(a/b)" => "../autoconf/a/b",
	"get_build_rel2sourcedir()" => "../$default_builddir",
	"get_build_rel2sourcedir(a/b)" => "../$default_builddir/a/b",
);
test_buildsystem_paths_api($bs, "default builddir, sourcedir=autoconf", \%tmp);

# sourcedir=autoconf (builddir should be dropped)
$bs = $BS_CLASS->new(builddir => "autoconf", sourcedir => "autoconf");
%tmp = (
	"get_sourcedir()" => "autoconf",
	"get_sourcepath(a/b)" => "autoconf/a/b",
	"get_builddir()" => undef,
	"get_buildpath()" => "autoconf",
	"get_buildpath(a/b)" =>  "autoconf/a/b",
	"get_source_rel2builddir()" => ".",
	"get_source_rel2builddir(a/b)" => "./a/b",
	"get_build_rel2sourcedir()" => ".",
	"get_build_rel2sourcedir(a/b)" => "./a/b",
);
test_buildsystem_paths_api($bs, "no builddir, sourcedir=autoconf", \%tmp);

# Prefer out of source tree building when
# sourcedir=builddir=autoconf hence builddir should be dropped.
$bs->prefer_out_of_source_building(builddir => "autoconf");
test_buildsystem_paths_api($bs, "out of source prefered, sourcedir=builddir", \%tmp);

# builddir=bld/dir, sourcedir=autoconf. Should be the same as sourcedir=autoconf.
$bs = $BS_CLASS->new(builddir => "bld/dir", sourcedir => "autoconf");
$bs->enforce_in_source_building();
test_buildsystem_paths_api($bs, "in source enforced, sourcedir=autoconf", \%tmp);

# builddir=../bld/dir (relative to the curdir)
$bs = $BS_CLASS->new(builddir => "bld/dir/", sourcedir => "autoconf");
%tmp = (
	"get_sourcedir()" => "autoconf",
	"get_sourcepath(a/b)" => "autoconf/a/b",
	"get_builddir()" => "bld/dir",
	"get_buildpath()" => "bld/dir",
	"get_buildpath(a/b)" =>  "bld/dir/a/b",
	"get_source_rel2builddir()" => "../../autoconf",
	"get_source_rel2builddir(a/b)" => "../../autoconf/a/b",
	"get_build_rel2sourcedir()" => "../bld/dir",
	"get_build_rel2sourcedir(a/b)" => "../bld/dir/a/b",
);
test_buildsystem_paths_api($bs, "builddir=../bld/dir, sourcedir=autoconf", \%tmp);

### Test check_auto_buildable() of each buildsystem
sub test_check_auto_buildable {
	my $bs=shift;
	my $config=shift;
	my $expected=shift;
	my @steps=@_ || @STEPS;

	if (! ref $expected) {
		my %all_steps;
		$all_steps{$_} = $expected foreach (@steps);
		$expected = \%all_steps;
	}
	for my $step (@steps) {
		my $e = 0;
		if (exists $expected->{$step}) {
			$e = $expected->{$step};
		} elsif (exists $expected->{default}) {
			$e = $expected->{default};
		}
		is( $bs->check_auto_buildable($step), $e,
			$bs->NAME() . "($config): check_auto_buildable($step) == $e" );
	}
}

$tmpdir = tempdir("tmp.XXXXXX");
$builddir = "$tmpdir/builddir";
mkdir $builddir;
%tmp = (
	builddir => "$tmpdir/builddir",
	sourcedir => $tmpdir
);

# Test if all buildsystems can be loaded
@bs = load_all_buildsystems([ $INC[0] ], %tmp);
@tmp = map { $_->NAME() } @bs;
ok(@Debian::Debhelper::Dh_Buildsystems::BUILDSYSTEMS >= 1, "some build systems are built in" );
is_deeply( \@tmp, \@Debian::Debhelper::Dh_Buildsystems::BUILDSYSTEMS, "load_all_buildsystems() loads all built-in buildsystems" );

# check_auto_buildable() fails with numeric 0
for $bs (@bs) {
    test_check_auto_buildable($bs, "fails with numeric 0", 0);
}

%bs = ();
for $bs (@bs) {
    $bs{$bs->NAME()} = $bs;
}

touch "$tmpdir/configure", 0755;
test_check_auto_buildable($bs{autoconf}, "configure", { configure => 1, clean => 1 });

touch "$tmpdir/CMakeLists.txt";
test_check_auto_buildable($bs{cmake}, "CMakeLists.txt", { configure => 1, clean => 1 });

touch "$tmpdir/Makefile.PL";
test_check_auto_buildable($bs{perl_makemaker}, "Makefile.PL", { configure => 1 });

# With Makefile
touch "$builddir/Makefile";
test_check_auto_buildable($bs{makefile}, "Makefile", 1);
test_check_auto_buildable($bs{autoconf}, "configure+Makefile", { configure => 1, test => 1, build => 1, install => 1, clean => 1 });
test_check_auto_buildable($bs{cmake}, "CMakeLists.txt+Makefile", 1);
touch "$builddir/CMakeCache.txt"; # strong evidence that cmake was run
test_check_auto_buildable($bs{cmake}, "CMakeCache.txt+Makefile", 2);

# Makefile.PL forces in-source
#(see note in check_auto_buildable() why always 1 here)
unlink "$builddir/Makefile";
touch "$tmpdir/Makefile";
test_check_auto_buildable($bs{perl_makemaker}, "Makefile.PL+Makefile", 1);

# Perl Build.PL - handles always
test_check_auto_buildable($bs{perl_build}, "no Build.PL", 0);
touch "$tmpdir/Build.PL";
test_check_auto_buildable($bs{perl_build}, "Build.PL", { configure => 1 });
touch "$tmpdir/Build"; # forced in source
test_check_auto_buildable($bs{perl_build}, "Build.PL+Build", 1);

# Python Distutils
test_check_auto_buildable($bs{python_distutils}, "no setup.py", 0);
touch "$tmpdir/setup.py";
test_check_auto_buildable($bs{python_distutils}, "setup.py", 1);

cleandir($tmpdir);

### Now test if it can autoselect a proper buildsystem for a typical package
sub test_autoselection {
	my $testname=shift;
	my $expected=shift;
	my %args=@_;
	for my $step (@STEPS) {
		my $bs = load_buildsystem({'enable-thirdparty' => 0}, $step, @_);
		my $e = $expected;
		$e = $expected->{$step} if ref $expected;
		if (defined $bs) {
			is( $bs->NAME(), $e, "autoselection($testname): $step=".((defined $e)?$e:'undef') );
		}
		else {
			is ( undef, $e, "autoselection($testname): $step=".((defined $e)?$e:'undef') );
		}
		&{$args{"code_$step"}}() if exists $args{"code_$step"};
	}
}

# Auto-select nothing when no supported build system can be found
# (see #557006).
test_autoselection("auto-selects nothing", undef, %tmp);

# Autoconf
touch "$tmpdir/configure", 0755;
touch "$builddir/Makefile";
test_autoselection("autoconf",
    { configure => "autoconf", build => "autoconf",
      test => "autoconf", install => "autoconf", clean => "autoconf" }, %tmp);
cleandir $tmpdir;

# Perl Makemaker (build, test, clean fail with builddir set [not supported])
touch "$tmpdir/Makefile.PL";
touch "$tmpdir/Makefile";
test_autoselection("perl_makemaker", "perl_makemaker", %tmp);
cleandir $tmpdir;

# Makefile
touch "$builddir/Makefile";
test_autoselection("makefile", "makefile", %tmp);
cleandir $tmpdir;

# Python Distutils
touch "$tmpdir/setup.py";
test_autoselection("python_distutils", "python_distutils", %tmp);
cleandir $tmpdir;

# Perl Build
touch "$tmpdir/Build.PL";
touch "$tmpdir/Build";
test_autoselection("perl_build", "perl_build", %tmp);
cleandir $tmpdir;

# CMake
touch "$tmpdir/CMakeLists.txt";
$tmp = sub {
	touch "$builddir/Makefile";
};
test_autoselection("cmake without CMakeCache.txt",
	{ configure => "cmake", build => "makefile",
	  test => "makefile", install => "makefile", clean => "makefile" }, %tmp,
	code_configure => $tmp);
cleandir $tmpdir;

touch "$tmpdir/CMakeLists.txt";
$tmp = sub {
	touch "$builddir/Makefile";
	touch "$builddir/CMakeCache.txt";
};
test_autoselection("cmake with CMakeCache.txt",
	"cmake", %tmp, code_configure => $tmp);
cleandir $tmpdir;

touch "$tmpdir/CMakeLists.txt";
touch "$builddir/Makefile";
test_autoselection("cmake and existing Makefile", "makefile", %tmp);
cleandir $tmpdir;

### Test Buildsystem::rmdir_builddir()
sub do_rmdir_builddir {
	my $builddir=shift;
	my $system;
	$system = $BS_CLASS->new(builddir => $builddir, sourcedir => $tmpdir);
	$system->mkdir_builddir();
	$system->rmdir_builddir();
}

$builddir = "$tmpdir/builddir";
do_rmdir_builddir($builddir);
ok ( ! -e $builddir, "testing rmdir_builddir() 1: builddir parent '$builddir' deleted" );
ok ( -d $tmpdir, "testing rmdir_builddir() 1: sourcedir '$tmpdir' remains" );

$builddir = "$tmpdir/bld";
do_rmdir_builddir("$builddir/dir");
ok ( ! -e $builddir, "testing rmdir_builddir() 2: builddir parent '$builddir' deleted" );
ok ( -d $tmpdir, "testing rmdir_builddir() 2: sourcedir '$tmpdir' remains" );

$builddir = "$tmpdir/bld";
mkdir "$builddir";
touch "$builddir/afile";
mkdir "$builddir/dir";
touch "$builddir/dir/afile2";
do_rmdir_builddir("$builddir/dir");
ok ( ! -e "$builddir/dir", "testing rmdir_builddir() 3: builddir '$builddir/dir' not empty, but deleted" );
ok ( -d $builddir, "testing rmdir_builddir() 3: builddir parent '$builddir' not empty, remains" );

cleandir $tmpdir;

### Test buildsystems_init() and commandline/env argument handling
sub get_load_bs_source {
	my ($system, $step)=@_;
	$step = (defined $step) ? "'$step'" : 'undef';
	$system = (defined $system) ? "'$system'" : 'undef';

return <<EOF;
use strict;
use warnings;
use Debian::Debhelper::Dh_Buildsystems;

buildsystems_init();
my \$bs = load_buildsystem($system, $step);
if (defined \$bs) {
	print 'NAME=', \$bs->NAME(), "\\n";
	print \$_, "=", (defined \$bs->{\$_}) ? \$bs->{\$_} : 'undef', "\\n"
	    foreach (sort keys \%\$bs);
}
EOF
}

$tmp = Cwd::getcwd();
# NOTE: disabling parallel building explicitly (it might get automatically
# enabled if run under dpkg-buildpackage -jX) to make output deterministic.
is_deeply( process_stdout("$^X -- - --builddirectory='autoconf/bld dir' --sourcedirectory autoconf --max-parallel=1",
                          get_load_bs_source(undef, "configure")),
    [ 'NAME=autoconf', 'builddir=autoconf/bld dir', "cwd=$tmp",  'makecmd=make', 'parallel=1', 'sourcedir=autoconf' ],
    "autoconf autoselection and sourcedir/builddir" );

is_deeply( process_stdout("$^X -- - -Sautoconf -D autoconf --max-parallel=1", get_load_bs_source("autoconf", "build")),
    [ 'NAME=autoconf', 'builddir=undef', "cwd=$tmp", 'makecmd=make', 'parallel=1', 'sourcedir=autoconf' ],
    "forced autoconf and sourcedir" );

is_deeply( process_stdout("$^X -- - -B -Sautoconf --max-parallel=1", get_load_bs_source("autoconf", "build")),
    [ 'NAME=autoconf', "builddir=$default_builddir", "cwd=$tmp", 'makecmd=make', 'parallel=1', 'sourcedir=.' ],
    "forced autoconf and default build directory" );

# Build the autoconf test package
sub dh_auto_do_autoconf {
	my $sourcedir=shift;
	my $builddir=shift;
	my %args=@_;

	my (@lines, @extra_args);
	my $buildpath = $sourcedir;
	my @dh_auto_args = ("-D", $sourcedir);
	my $dh_auto_str = "-D $sourcedir";
	if ($builddir) {
		push @dh_auto_args, "-B", $builddir;
		$dh_auto_str .= " -B $builddir";
		$buildpath = $builddir;
	}

	my $do_dh_auto = sub {
		my $step=shift;
		my @extra_args;
		my $extra_str = "";
		if (exists $args{"${step}_args"}) {
			push @extra_args, @{$args{"${step}_args"}};
			$extra_str .= " $_" foreach (@extra_args);
		}
		is ( system("$TOPDIR/dh_auto_$step", @dh_auto_args, "--", @extra_args), 0,
			 "dh_auto_$step $dh_auto_str$extra_str" );
		return @extra_args;
	};
	
	@extra_args = &$do_dh_auto('configure');
	ok ( -f "$buildpath/Makefile", "$buildpath/Makefile exists" );
	@lines=();
	if ( ok(open(FILE, '<', "$buildpath/stamp_configure"), "$buildpath/stamp_configure exists") ) {
		@lines = @{readlines(\*FILE)};
		close(FILE);
	}
	is_deeply( \@lines, \@extra_args, "$buildpath/stamp_configure contains extra args" );

	&$do_dh_auto('build');
	ok ( -f "$buildpath/stamp_build", "$buildpath/stamp_build exists" );
	&$do_dh_auto('test');
	@lines=();
	if ( ok(open(FILE, '<', "$buildpath/stamp_test"), "$buildpath/stamp_test exists") ) {
		@lines = @{readlines(\*FILE)};
		close(FILE);
	}
	is_deeply( \@lines, [ "VERBOSE=1" ],
	    "$buildpath/stamp_test contains VERBOSE=1" );
	&$do_dh_auto('install');
	@lines=();
	if ( ok(open(FILE, '<', "$buildpath/stamp_install"), "$buildpath/stamp_install exists") ) {
		@lines = @{readlines(\*FILE)};
		close(FILE);
	} 
	is_deeply( \@lines, [ "DESTDIR=".Cwd::getcwd()."/debian/testpackage" ],
	    "$buildpath/stamp_install contains DESTDIR" );
	&$do_dh_auto('clean');
	if ($builddir) {
		ok ( ! -e "$buildpath", "builddir $buildpath was removed" );
	}
	else {
		ok ( ! -e "$buildpath/Makefile" && ! -e "$buildpath/stamp_configure", "Makefile and stamps gone" );
	}
	ok ( -x "$sourcedir/configure", "configure script renamins after clean" );
}

dh_auto_do_autoconf('autoconf');
dh_auto_do_autoconf('autoconf', 'bld/dir', configure_args => [ "--extra-autoconf-configure-arg" ]);
ok ( ! -e 'bld', "bld got deleted too" );

#### Test parallel building and related options / routines
@tmp = ( $ENV{MAKEFLAGS}, $ENV{DEB_BUILD_OPTIONS} );

# Test clean_jobserver_makeflags.

test_clean_jobserver_makeflags('--jobserver-fds=103,104 -j',
                               undef,
                               'unset makeflags');

test_clean_jobserver_makeflags('-a --jobserver-fds=103,104 -j -b',
                               '-a -b',
                               'clean makeflags');

test_clean_jobserver_makeflags(' --jobserver-fds=1,2 -j  ',
                               undef,
                               'unset makeflags');

test_clean_jobserver_makeflags('-a -j -b',
                               '-a -j -b',
                               'clean makeflags does not remove -j');

test_clean_jobserver_makeflags('-a --jobs -b',
                               '-a --jobs -b',
                               'clean makeflags does not remove --jobs');

test_clean_jobserver_makeflags('-j6',
                               '-j6',
                               'clean makeflags does not remove -j6');

test_clean_jobserver_makeflags('-a -j6 --jobs=7',
                               '-a -j6 --jobs=7',
                               'clean makeflags does not remove -j or --jobs');

test_clean_jobserver_makeflags('-j6 --jobserver-fds=103,104 --jobs=8',
                               '-j6 --jobs=8',
                               'jobserver options removed');

test_clean_jobserver_makeflags('-j6 --jobserver-auth=103,104 --jobs=8',
                               '-j6 --jobs=8',
                               'jobserver options removed');

# Test parallel building with makefile build system.
$ENV{MAKEFLAGS} = "";
$ENV{DEB_BUILD_OPTIONS} = "";

sub do_parallel_mk {
	my $dh_opts=shift || "";
	my $make_opts=shift || "";
	return process_stdout(
		"LANG=C LC_ALL=C LC_MESSAGES=C $TOPDIR/dh_auto_build -Smakefile $dh_opts " .
		"-- -s -f parallel.mk $make_opts 2>&1 >/dev/null", "");
}

sub test_isnt_parallel {
	my ($got, $desc) = @_;
	my @makemsgs = grep /^make[\d\[\]]*:/, @$got;
	if (@makemsgs) {
		like( $makemsgs[0], qr/Error 10/, $desc );
	}
	else {
		ok( scalar(@makemsgs) > 0, $desc );
	}
}

sub test_is_parallel {
	my ($got, $desc) = @_;
	is_deeply( $got, [] , $desc );
	is( $?, 0, "(exit status=0) $desc");
}

sub test_clean_jobserver_makeflags {
    my ($orig, $expected, $test) = @_;

    local $ENV{MAKEFLAGS} = $orig;
    clean_jobserver_makeflags();
    is($ENV{MAKEFLAGS}, $expected, $test);
}

test_isnt_parallel( do_parallel_mk(),
	"No parallel by default" );
test_isnt_parallel( do_parallel_mk("parallel"),
	"No parallel by default with --parallel" );
test_isnt_parallel( do_parallel_mk("--max-parallel=5"),
	"No parallel by default with --max-parallel=5" );

$ENV{DEB_BUILD_OPTIONS}="parallel=5";
test_isnt_parallel( do_parallel_mk(),
	"DEB_BUILD_OPTIONS=parallel=5 without parallel options" );
test_is_parallel( do_parallel_mk("--parallel"),
	"DEB_BUILD_OPTIONS=parallel=5 with --parallel" );
test_is_parallel( do_parallel_mk("--max-parallel=2"),
	"DEB_BUILD_OPTIONS=parallel=5 with --max-parallel=2" );
test_isnt_parallel( do_parallel_mk("--max-parallel=1"),
	"DEB_BUILD_OPTIONS=parallel=5 with --max-parallel=1" );

$ENV{MAKEFLAGS} = "--jobserver-fds=105,106 -j";
$ENV{DEB_BUILD_OPTIONS}="";
test_isnt_parallel( do_parallel_mk(),
	"makefile.pm (no parallel): no make warnings about unavailable jobserver" );
$ENV{DEB_BUILD_OPTIONS}="parallel=5";
test_is_parallel( do_parallel_mk("--parallel"),
	"DEB_BUILD_OPTIONS=parallel=5: no make warnings about unavail parent jobserver" );

$ENV{MAKEFLAGS} = "-j2";
$ENV{DEB_BUILD_OPTIONS}="";
test_isnt_parallel( do_parallel_mk(),
	"MAKEFLAGS=-j2: dh_auto_build ignores MAKEFLAGS" );
test_isnt_parallel( do_parallel_mk("--max-parallel=1"),
	"MAKEFLAGS=-j2 with --max-parallel=1: dh_auto_build enforces -j1" );

# Test dh dpkg-buildpackage -jX detection
sub do_rules_for_parallel {
	my $cmdline=shift || "";
	my $stdin=shift || "";
	return process_stdout("LANG=C LC_ALL=C LC_MESSAGES=C PATH=$TOPDIR:\$PATH " .
		"make -f - $cmdline 2>&1 >/dev/null", $stdin);
}

doit("ln", "-sf", "parallel.mk", "Makefile");

# Test if dh+override+$(MAKE) legacy punctuation hack work as before
$ENV{MAKEFLAGS} = "-j5";
$ENV{DEB_BUILD_OPTIONS} = "parallel=5";

$tmp = write_debian_rules(<<'EOF');
#!/usr/bin/make -f
override_dh_auto_build:
	$(MAKE)
%:
	@dh_clean > /dev/null 2>&1
	@+dh $@ --buildsystem=makefile 2>/dev/null
	@dh_clean > /dev/null 2>&1
EOF
test_is_parallel( do_rules_for_parallel("build", "include debian/rules"),
	"legacy punctuation hacks: +dh, override with \$(MAKE)" );
unlink "debian/rules";

if (defined $tmp) {
	rename($tmp, "debian/rules");
}
else {
	unlink("debian/rules");
}

# Clean up after parallel testing
END {
	system("rm", "-f", "Makefile");
}
$ENV{MAKEFLAGS} = $tmp[0] if defined $tmp[0];
$ENV{DEB_BUILD_OPTIONS} = $tmp[1] if defined $tmp[1];

END {
	system("rm", "-rf", $tmpdir);
	system("$TOPDIR/dh_clean");
}
