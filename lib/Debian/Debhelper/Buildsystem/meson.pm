# A debhelper build system class for handling Meson based projects.
#
# Copyright: © 2017 Michael Biebl
# License: GPL-2+

package Debian::Debhelper::Buildsystem::meson;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(compat dpkg_architecture_value is_cross_compiling doit warning error generated_file qx_cmd);
use parent qw(Debian::Debhelper::Buildsystem);

sub DESCRIPTION {
	"Meson (meson.build)"
}

sub IS_GENERATOR_BUILD_SYSTEM {
	return 1;
}

sub SUPPORTED_TARGET_BUILD_SYSTEMS {
	return qw(ninja);
}


sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;

	return 0 unless -e $this->get_sourcepath("meson.build");

	# Handle configure explicitly; inherit the rest
	return 1 if $step eq "configure";
	my $ret = $this->get_targetbuildsystem->check_auto_buildable(@_);
	if ($ret == 0 and $this->check_auto_buildable_clean_oos_buildir(@_)) {
		# Assume that the package can be cleaned (i.e. the build directory can
		# be removed) as long as it is built out-of-source tree and can be
		# configured.
		$ret++;
	}
	return $ret;
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->prefer_out_of_source_building(@_);
	return $this;
}

sub _get_meson_env {
	my $update_env = {
		LC_ALL => 'C.UTF-8',
	};
	$update_env->{DEB_PYTHON_INSTALL_LAYOUT} = 'deb' unless $ENV{DEB_PYTHON_INSTALL_LAYOUT};
	return $update_env;
}

sub configure {
	my $this=shift;

	eval { require Dpkg::Version; };
	error($@) if $@;

	my $output = qx_cmd('meson', '--version');
	chomp $output;
	my $version = Dpkg::Version->new($output);

	# Standard set of options for meson.
	my @opts = (
		'--wrap-mode=nodownload',
	);
	push @opts, "--buildtype=plain";
	push @opts, "--prefix=/usr";
	push @opts, "--sysconfdir=/etc";
	push @opts, "--localstatedir=/var";
	my $multiarch=dpkg_architecture_value("DEB_HOST_MULTIARCH");
	push @opts, "--libdir=lib/$multiarch";
	push(@opts, "--libexecdir=lib/$multiarch") if compat(11);
	# There was a behaviour change in Meson 1.2.0: previously
	# byte-compilation wasn't supported, but since 1.2.0 it is on by
	# default. We can only use this option to turn it off in versions
	# where the option exists.
	push(@opts, "-Dpython.bytecompile=-1") if $version >= '1.2.0';

	if (is_cross_compiling()) {
		# http://mesonbuild.com/Cross-compilation.html
		my $cross_file = $ENV{'DH_MESON_CROSS_FILE'};
		if (not $cross_file) {
			my $debcrossgen = '/usr/share/meson/debcrossgen';
			if (not -x $debcrossgen) {
				warning("Missing debcrossgen (${debcrossgen}) cannot generate a meson cross file and non was provided");
				error("Cannot cross-compile: Please use meson (>= 0.42.1) or provide a cross file via DH_MESON_CROSS_FILE");
			}
			my $filename = generated_file('_source', 'meson-cross-file.conf');
			my %options = (
				stdout => '/dev/null',
				update_env => { LC_ALL => 'C.UTF-8'},
			);
			doit(\%options, $debcrossgen, "-o${filename}");
			$cross_file = $filename;
		}
		if ($cross_file !~ m{^/}) {
			# Make the file name absolute as meson will be called from the build dir.
			require Cwd;
			$cross_file =~ s{^\./}{};
			$cross_file = Cwd::getcwd() . "/${cross_file}";
		}
		push(@opts, '--cross-file', $cross_file);
	}

	$this->mkdir_builddir();
	eval {
		my %options = (
			update_env => _get_meson_env(),
		);
		$this->doit_in_builddir(\%options, "meson", "setup", $this->get_source_rel2builddir(), @opts, @_);
	};
	if ($@) {
		if (-e $this->get_buildpath("meson-logs/meson-log.txt")) {
			$this->doit_in_builddir('tail', '-v', '-n', '+0', 'meson-logs/meson-log.txt');
		}
		die $@;
	}
}

sub test {
	my $this = shift;
	my $target = $this->get_targetbuildsystem;

	eval {
		if (compat(12) or $target->NAME ne 'ninja') {
			$target->test(@_);
		} else {
			# In compat 13 with meson+ninja, we prefer using "meson test"
			# over "ninja test"
			my %options = (
				update_env => _get_meson_env(),
			);
			if ($this->get_parallel() > 0) {
				$options{update_env}{MESON_TESTTHREADS} = $this->get_parallel();
			}
			$this->doit_in_builddir(\%options, 'meson', 'test', @_);
		}
	};
	if (my $err = $@) {
		if (-e $this->get_buildpath("meson-logs/testlog.txt")) {
			$this->doit_in_builddir('tail', '-v', '-n', '+0', 'meson-logs/testlog.txt');
		}
		die $err;
	}
	return 1;
}

sub install {
	my ($this, $destdir, @args) = @_;
	my $target = $this->get_targetbuildsystem;

	if (compat(13) or $target->NAME ne 'ninja') {
		$target->install($destdir, @args);
	} else {
		# In compat 14 with meson+ninja, we prefer using "meson install"
		# over "ninja install"
		my %options = (
			update_env => _get_meson_env(),
		);
		$this->doit_in_builddir(\%options, 'meson', 'install', '--destdir', $destdir, @args);
	}
	return 1;
}



1
