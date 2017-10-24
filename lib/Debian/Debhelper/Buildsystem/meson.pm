# A debhelper build system class for handling Meson based projects.
#
# Copyright: © 2017 Michael Biebl
# License: GPL-2+

package Debian::Debhelper::Buildsystem::meson;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(dpkg_architecture_value is_cross_compiling doit warning error);
use parent qw(Debian::Debhelper::Buildsystem::ninja);

sub DESCRIPTION {
	"Meson (meson.build)"
}

sub check_auto_buildable {
	my $this=shift;
	my ($step)=@_;

	return 0 unless -e $this->get_sourcepath("meson.build");

	# Handle configure explicitly; inherit the rest
	return 1 if $step eq "configure";
	return $this->SUPER::check_auto_buildable(@_);
}

sub new {
	my $class=shift;
	my $this=$class->SUPER::new(@_);
	$this->prefer_out_of_source_building(@_);
	return $this;
}

sub configure {
	my $this=shift;

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
	push @opts, "--libexecdir=lib/$multiarch";

	if (is_cross_compiling()) {
		# http://mesonbuild.com/Cross-compilation.html
		my $cross_file = $ENV{'DH_MESON_CROSS_FILE'};
		if (not $cross_file) {
			my $debcrossgen = '/usr/share/meson/debcrossgen';
			if (not -x $debcrossgen) {
				warning("Missing debcrossgen (${debcrossgen}) cannot generate a meson cross file and non was provided");
				error("Cannot cross-compile: Please use meson (>= 0.42.1) or provide a cross file via DH_MESON_CROSS_FILE");
			}
			my $filename = generated_file('_source', 'meason-cross-file.conf');
			doit({ stdout => '/dev/null' }, $debcrossgen, "-o${filename}");
			$cross_file = $filename;
		}
		if ($cross_file !~ m{^/}) {
			# Make the file name absolute as meson will be called from the build dir.
			require Cwd;
			$cross_file =~ s{^\./}{};
			$cross_file = Cwd::cwd() . "/${cross_file}";
		}
		push(@opts, '--cross-file', $cross_file);
	}

	$this->mkdir_builddir();
	eval {
		$this->doit_in_builddir("meson", $this->get_source_rel2builddir(), @opts, @_);
	};
	if ($@) {
		if (-e $this->get_buildpath("meson-logs/meson-log.txt")) {
			$this->doit_in_builddir('tail', '-v', '-n', '+0', 'meson-logs/meson-log.txt');
		}
		die $@;
	}
}

sub test {
	my $this=shift;
	return $this->SUPER::test(@_);
}

1
