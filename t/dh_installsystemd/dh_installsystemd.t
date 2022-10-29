#!/usr/bin/perl
use strict;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 5);

sub write_file {
	my ($path, $content) = @_;

	my $dir = dirname($path);
	mkdirs($dir);

	open(my $fd, '>>', $path) or error("open($path) failed: $!");
	print {$fd} $content . '\n';
	close($fd) or error("close($path) failed: $!");
}

sub unit_is_enabled {
	my ($package, $unit, $num_enables) = @_;
	my @output;
	my $matches;
	my @postinst_snippets = find_script($package, 'postinst');
	@output=`cat @postinst_snippets` if @postinst_snippets;
	# Match exactly one tab; the "dont-enable" script has an "enable"
	# line for re-enabling the service if the admin had it enabled.
	# But we do not want to include that in our count.
	$matches = grep { m{^\tif deb-systemd-helper .* was-enabled .*'\Q$unit\E\.service'} } @output;
	ok($matches == $num_enables) or diag("$unit appears to have been enabled $matches times (expected $num_enables)");
}

sub unit_is_started {
	my ($package, $unit, $num_starts, $num_stops) = @_;
	my @output;
	my $matches;
	$num_stops = $num_stops // $num_starts;
	my @postinst_snippets = find_script($package, 'postinst');
	@output=`cat @postinst_snippets` if @postinst_snippets;
	$matches = grep { m{deb-systemd-invoke \$_dh_action .*'\Q$unit\E.service'} } @output;
	ok($matches == $num_starts) or diag("$unit appears to have been started $matches times (expected $num_starts)");
	my @prerm_snippets = find_script($package, 'prerm');
	@output=`cat @prerm_snippets` if @prerm_snippets;
	$matches = grep { m{deb-systemd-invoke stop .*'\Q$unit\E.service'} } @output;
	ok($matches == $num_stops) or diag("$unit appears to have been stopped $matches times (expected $num_stops)");
}


#
# Test a simple source package defining a single binary package
#
our $TEST_DH_FIXTURE_DIR = 'simple';
our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.service
));

each_compat_subtest {
	ok(run_dh_tool('dh_installsystemd'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	ok(run_dh_tool('dh_clean'));

	ok(run_dh_tool('dh_installsystemd', '--no-start'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 0, 0);
	ok(run_dh_tool('dh_clean'));

	ok(run_dh_tool('dh_installsystemd', '--no-start', 'foo.service'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 0, 0);
	ok(run_dh_tool('dh_clean'));

	# Quoting #764730
	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo.service', 'debian/foo/lib/systemd/system/foo\x2dfuse.service');
	ok(run_dh_tool('dh_installsystemd'));
	unit_is_enabled('foo', 'foo\x2dfuse', 1);
	unit_is_started('foo', 'foo\x2dfuse', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo.service', 'debian/foo/lib/systemd/system/target.service');
	make_symlink_raw_target('target.service', 'debian/foo/lib/systemd/system/source.service');
	ok(run_dh_tool('dh_installsystemd'));
	unit_is_enabled('foo', 'foo', 1);
	# Alias= realized by symlinks are not enabled in maintainer scripts
	unit_is_enabled('foo', 'source', 0);
	unit_is_enabled('foo', 'target', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	ok(run_dh_tool('dh_installsystemd', '--no-restart-after-upgrade'));
	my @foo_postinst = find_script('foo', 'postinst');
	ok(@foo_postinst);
	my $matches = @foo_postinst ? grep { m{deb-systemd-invoke start .*foo.service} } `cat @foo_postinst` : -1;
	ok($matches == 1);
	ok(run_dh_tool('dh_clean'));
};


#
# Test a more complex source package defining three binary packages
#
$TEST_DH_FIXTURE_DIR = 'named-legacy';
@TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.service
    debian/foo2.service
));

each_compat_up_to_and_incl_subtest(13, sub {
	ok(run_dh_tool( 'dh_installsystemd'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 0);
	unit_is_started('foo', 'foo2', 0);
	ok(run_dh_tool('dh_clean'));

	# Install unit directly below /lib
	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	# Install unit directly below /usr/lib
	make_path('debian/foo/usr/lib/systemd/system/');
	copy_file('debian/foo2.service', 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '--no-start'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 0, 0);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 0, 0);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', '--no-start', 'foo.service'));
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', 'foo2.service'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 0, 0);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', '--no-enable', 'foo.service'));
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', 'foo2.service'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 0);
	unit_is_started('foo', 'foo', 1, 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	ok(run_dh_tool('dh_installsystemd', '--no-restart-after-upgrade'));
	my @foo_postinst = find_script('foo', 'postinst');
	ok(@foo_postinst);
	my $matches = @foo_postinst ? grep { m{deb-systemd-invoke start .*foo.service} } `cat @foo_postinst` : -1;
	ok($matches == 1);
	ok(run_dh_tool('dh_clean'));

	# Quoting #764730
	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo.service', 'debian/foo/lib/systemd/system/foo\x2dfuse.service');
	ok(run_dh_tool('dh_installsystemd'));
	unit_is_enabled('foo', 'foo\x2dfuse', 1);
	unit_is_started('foo', 'foo\x2dfuse', 1);
	ok(run_dh_tool('dh_clean'));

	# --name flag #870768
	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo2.service', 'debian/foo/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '--name=foo'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 0);
	unit_is_started('foo', 'foo2', 0);
	ok(run_dh_tool('dh_installsystemd', '--name=foo2'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/lib/systemd/system/');
	copy_file('debian/foo.service', 'debian/foo/lib/systemd/system/target.service');
	make_symlink_raw_target('target.service', 'debian/foo/lib/systemd/system/source.service');
	ok(run_dh_tool('dh_installsystemd'));
	unit_is_enabled('foo', 'foo', 1);
	# Alias= realized by symlinks are not enabled in maintainer scripts
	unit_is_enabled('foo', 'source', 0);
	unit_is_enabled('foo', 'target', 1);
	ok(run_dh_tool('dh_clean'));
});

each_compat_up_to_and_incl_subtest(11, sub {
	make_path('debian/foo/lib/systemd/system/');
	make_path('debian/foo/etc/init.d/');
	copy_file('debian/foo.service', 'debian/foo/lib/systemd/system/target.service');
	make_symlink_raw_target('target.service', 'debian/foo/lib/systemd/system/source.service');
	write_file('debian/foo/etc/init.d/source', '# something');
	ok(run_dh_tool('dh_installsystemd'));
	unit_is_enabled('foo', 'foo', 1);
	# Alias= realized by symlinks are not enabled in maintainer scripts
	unit_is_enabled('foo', 'source', 0);
	unit_is_enabled('foo', 'target', 1);
	# The presence of a sysvinit script for the alias unit inhibits start of both
	unit_is_started('foo', 'source', 0);
	unit_is_started('foo', 'target', 0);
	ok(run_dh_tool('dh_clean'));
});

each_compat_from_and_above_subtest(12, sub {
	make_path('debian/foo/lib/systemd/system/');
	make_path('debian/foo/etc/init.d/');
	copy_file('debian/foo.service', 'debian/foo/lib/systemd/system/target.service');
	make_symlink_raw_target('target.service', 'debian/foo/lib/systemd/system/source.service');
	write_file('debian/foo/etc/init.d/source', '# something');
	ok(run_dh_tool('dh_installsystemd'));
	unit_is_enabled('foo', 'foo', 1);
	# Alias= realized by symlinks are not enabled in maintainer scripts
	unit_is_enabled('foo', 'source', 0);
	unit_is_enabled('foo', 'target', 1);
	unit_is_started('foo', 'source', 0);
	unit_is_started('foo', 'target', 1);
	ok(run_dh_tool('dh_clean'));
});


#
# Test a more complex source package defining three binary packages
#
$TEST_DH_FIXTURE_DIR = 'named';
@TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.foo.service
    debian/foo.foo2.service
));

each_compat_from_and_above_subtest(14, sub {
	ok(run_dh_tool( 'dh_installsystemd', '--name', 'foo'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 0);
	unit_is_started('foo', 'foo2', 0);
	ok(run_dh_tool('dh_clean'));

	# Install unit directly below /lib
	make_path('debian/foo/usr/lib/systemd/system/');
	copy_file('debian/foo.foo2.service', 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd'));
	ok(! -e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 0);
	unit_is_started('foo', 'foo', 0);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	# Install unit directly below /usr/lib
	make_path('debian/foo/usr/lib/systemd/system/');
	copy_file('debian/foo.foo2.service', 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 0);
	unit_is_started('foo', 'foo', 0);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/usr/lib/systemd/system/');
	copy_file('debian/foo.foo2.service', 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '--no-start'));
	ok(!-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 0);
	unit_is_started('foo', 'foo', 0, 0);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 0, 0);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/usr/lib/systemd/system/');
	copy_file('debian/foo.foo2.service', 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', '--no-start', '--name', 'foo'));
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', 'foo2.service'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 0, 0);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	make_path('debian/foo/usr/lib/systemd/system/');
	copy_file('debian/foo.foo.service', 'debian/foo/usr/lib/systemd/system/foo.service');
	copy_file('debian/foo.foo2.service', 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', '--no-enable', 'foo.service'));
	ok(run_dh_tool('dh_installsystemd', '-p', 'foo', 'foo2.service'));
	ok(-e 'debian/foo/usr/lib/systemd/system/foo.service');
	ok(find_script('foo', 'postinst'));
	unit_is_enabled('foo', 'foo', 0);
	unit_is_started('foo', 'foo', 1, 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));

	# --name flag #870768
	make_path('debian/foo/usr/lib/systemd/system/');
	copy_file('debian/foo.foo2.service', 'debian/foo/usr/lib/systemd/system/foo2.service');
	ok(run_dh_tool('dh_installsystemd', '--name=foo'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 0);
	unit_is_started('foo', 'foo2', 0);
	ok(run_dh_tool('dh_installsystemd', '--name=foo2'));
	unit_is_enabled('foo', 'foo', 1);
	unit_is_started('foo', 'foo', 1);
	unit_is_enabled('foo', 'foo2', 1);
	unit_is_started('foo', 'foo2', 1);
	ok(run_dh_tool('dh_clean'));
});
