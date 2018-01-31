#!/usr/bin/perl
use strict;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.service
    debian/foo2.service
));

plan(tests => 1);

sub unit_is_enabled {
	my ($package, $unit, $num_enables, $num_masks) = @_;
	my @output;
	my $matches;
	$num_masks = $num_masks // $num_enables;
	@output=`cat debian/$package.postinst.debhelper`;
	# Match exactly one tab; the "dont-enable" script has an "enable"
	# line for re-enabling the service if the admin had it enabled.
	# But we do not want to include that in our count.
	$matches = grep { m{^\tif deb-systemd-helper .* was-enabled .*'\Q$unit\E\.service'} } @output;
	ok($matches == $num_enables) or diag("$unit appears to have been enabled $matches times (expected $num_enables)");
	@output=`cat debian/$package.postrm.debhelper`;
	$matches = grep { m{deb-systemd-helper mask.*'\Q$unit\E\.service'} } @output;
	ok($matches == $num_masks) or diag("$unit appears to have been masked $matches times (expected $num_masks)");
}
sub unit_is_started {
	my ($package, $unit, $num_starts, $num_stops) = @_;
	my @output;
	my $matches;
	$num_stops = $num_stops // $num_starts;
	@output=`cat debian/$package.postinst.debhelper`;
	$matches = grep { m{deb-systemd-invoke \$_dh_action .*'\Q$unit\E.service'} } @output;
	ok($matches == $num_starts) or diag("$unit appears to have been started $matches times (expected $num_starts)");
	@output=`cat debian/$package.prerm.debhelper`;
	$matches = grep { m{deb-systemd-invoke stop .*'\Q$unit\E.service'} } @output;
	ok($matches == $num_stops) or diag("$unit appears to have been stopped $matches times (expected $num_stops)");
}

# Units are installed and enabled
each_compat_up_to_and_incl_subtest(10, sub {
	ok(run_dh_tool('dh_systemd_enable'));
	ok(run_dh_tool('dh_systemd_start'));
	ok(-e "debian/foo/lib/systemd/system/foo.service");
	ok(-e "debian/foo.postinst.debhelper");
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 0);
	unit_is_started('foo', 'foo2', 0);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	install_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_systemd_enable'));
	ok(run_dh_tool('dh_systemd_start'));
	ok(-e "debian/foo/lib/systemd/system/foo.service");
	ok(-e "debian/foo.postinst.debhelper");
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	install_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_systemd_enable'));
	ok(run_dh_tool('dh_systemd_start', '--no-start'));
	ok(-e "debian/foo/lib/systemd/system/foo.service");
	ok(-e "debian/foo.postinst.debhelper");
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 0, 1); # present units are stopped on remove even if no start
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 0, 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	install_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_systemd_enable'));
	ok(run_dh_tool('dh_systemd_start', '--no-start', 'debian/foo.service'));
	ok(run_dh_tool('dh_systemd_start', '-p', 'foo', 'foo2.service'));
	ok(-e "debian/foo/lib/systemd/system/foo.service");
	ok(-e "debian/foo.postinst.debhelper");
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 0, 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	install_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_systemd_enable', '--no-enable', 'debian/foo.service'));
	ok(run_dh_tool('dh_systemd_enable', '-p', 'foo', 'foo2.service'));
	ok(run_dh_tool('dh_systemd_start'));
	ok(-e "debian/foo/lib/systemd/system/foo.service");
	ok(-e "debian/foo.postinst.debhelper");
	unit_is_enabled('foo', 'foo', 0, 1); # Disabled units are still masked on removal
	unit_is_started('foo', 'foo', 1, 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	install_file('debian/foo.service', 'debian/foo/lib/systemd/system/foo.service');
	ok(run_dh_tool('dh_systemd_start', '--no-restart-after-upgrade'));
        my $matches = grep { m{deb-systemd-invoke start .*foo.service} } `cat debian/foo.postinst.debhelper`;
	ok($matches == 1);
	ok(run_dh_tool('dh_clean'));

	# Quoting #764730
	make_path('debian/foo/lib/systemd/system/');
	install_file('debian/foo.service', 'debian/foo/lib/systemd/system/foo\x2dfuse.service');
	ok(run_dh_tool('dh_systemd_enable'));
	ok(run_dh_tool('dh_systemd_start'));
	unit_is_enabled('foo', 'foo\x2dfuse', 1);
	unit_is_started('foo', 'foo\x2dfuse', 1);
	ok(run_dh_tool('dh_clean'));
});


