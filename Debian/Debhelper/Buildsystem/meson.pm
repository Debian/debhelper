# A debhelper build system class for handling Meson based projects.
#
# Copyright: © 2017 Michael Biebl
# License: GPL-2+

package Debian::Debhelper::Buildsystem::meson;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(dpkg_architecture_value);
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

	# TODO: Support cross compilation
	# https://github.com/mesonbuild/meson/wiki/Cross-compilation

	# Standard set of options for meson.
	my @opts;
	push @opts, "--buildtype=plain";
	push @opts, "--prefix=/usr";
	push @opts, "--sysconfdir=/etc";
	push @opts, "--localstatedir=/var";
	my $multiarch=dpkg_architecture_value("DEB_HOST_MULTIARCH");
	push @opts, "--libdir=lib/$multiarch";
	push @opts, "--libexecdir=lib/$multiarch";

	$this->mkdir_builddir();
	eval {
		$this->doit_in_builddir("meson", $this->get_source_rel2builddir(), @opts, @_);
	};
	if ($@) {
		if (-e $this->get_buildpath("meson-logs/meson-log.txt")) {
			$this->doit_in_builddir("tail -v -n +0 meson-logs/meson-log.txt");
		}
		die $@;
	}
}

sub test {
	my $this=shift;
	return $this->SUPER::test(@_);
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
