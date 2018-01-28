#!/usr/bin/perl

use Test::More tests => 82;

use strict;
use warnings;
use IPC::Open2;
use Cwd ();
use File::Temp qw(tempfile);
use File::Basename ();

# Let the tests to be run from anywhere but currect directory
# is expected to be the one where this test lives in.
chdir File::Basename::dirname($0) or die "Unable to chdir to ".File::Basename::dirname($0);

use_ok( 'Debian::Debhelper::Dh_Lib' );
use_ok( 'Debian::Debhelper::Buildsystem' );
use_ok( 'Debian::Debhelper::Dh_Buildsystems' );

my $TOPDIR = $ENV{AUTOPKGTEST_TMP} ? '/usr/bin' : '../..';
my @STEPS = qw(configure build test install clean);
my $BS_CLASS = 'Debian::Debhelper::Buildsystem';

my ($bs);
my ($tmp, @tmp, %tmp);
my ($default_builddir);

### Common subs ####
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
test_buildsystem_paths_api($bs, "out of source preferred, sourcedir=builddir", \%tmp);

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

#### Test parallel building and related options / routines
@tmp = ( $ENV{MAKEFLAGS}, $ENV{DEB_BUILD_OPTIONS} );


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
export DEB_RULES_REQUIRES_ROOT:=no
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
	system("$TOPDIR/dh_clean");
}
