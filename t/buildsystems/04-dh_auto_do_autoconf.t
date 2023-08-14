#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 31;

use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);
use Debian::Debhelper::Dh_Buildsystems;

# Let the tests to be run from anywhere but currect directory
# is expected to be the one where this test lives in.
chdir File::Basename::dirname($0) or die "Unable to chdir to ".File::Basename::dirname($0);

$Test::DH::TEST_DH_COMPAT = 10;

# Build the autoconf test package
sub dh_auto_do_autoconf {
	my ($sourcedir, $builddir, %args) = @_;

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
		my ($step) = @_;
		my @extra_args;
		my $extra_str = "";
		if (exists $args{"${step}_args"}) {
			push @extra_args, @{$args{"${step}_args"}};
			$extra_str .= " $_" foreach (@extra_args);
		}
		ok(run_dh_tool({ 'quiet' => 1 }, "dh_auto_${step}", @dh_auto_args, '--', @extra_args),
			 "dh_auto_$step $dh_auto_str$extra_str");
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

