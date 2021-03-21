#!/usr/bin/perl
use strict;
use Test::More;
use File::Path qw(make_path);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 1);

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
	debian/changelog
	debian/control
	debian/foo.user.service
	debian/baz.user.service
));


sub read_script {
	my ($package, $name) = @_;
	my @lines;

	foreach my $script (find_script($package, $name)) {
		open(my $fh, '<', $script) or die("open($script): $!");
		push @lines, $_ for <$fh>;
		close($fh);
	}

	return @lines;
}

sub _unit_check_user_enabled {
	my ($package, $unit, $enabled) = @_;
	my $verb = $enabled ? "is" : "isnt";
	my $matches;

	my @postinst = read_script($package, 'postinst');
	# Match exactly two tab character. The "dont-enable" script has
	# an "enable" line for re-enabling the service if the admin had it
	# enabled, but we do not want to include that in our count.
	$matches = grep { m{^\t\tif deb-systemd-helper( --\w+)* --user was-enabled.*'\Q$unit'} } @postinst;
	is($matches, $enabled, "$unit $verb enabled");

	my @postrm = read_script($package, 'postrm');
	$matches = grep { m{deb-systemd-helper( --\w+)* --user mask.*'\Q$unit'} } @postrm;
	is($matches, $enabled, "$unit $verb masked");
}

sub is_enabled { _unit_check_user_enabled(@_, 1); }
sub isnt_enabled { _unit_check_user_enabled(@_, 0); }

each_compat_subtest {
	make_path('debian/foo/usr/lib/systemd/user/');
	install_file('debian/foo.user.service', 'debian/foo/usr/lib/systemd/user/bar.service');
	ok(run_dh_tool('dh_installsystemduser'));
	ok(-e 'debian/foo/usr/lib/systemd/user/foo.service');
	is_enabled('foo', 'foo.service');
	is_enabled('foo', 'bar.service');
	ok(run_dh_tool('dh_clean'));

	ok(run_dh_tool('dh_installsystemduser'));
	ok(-e 'debian/foo/usr/lib/systemd/user/foo.service');
	ok(! -e 'debian/foo/usr/lib/systemd/user/baz.service');
	is_enabled('foo', 'foo.service');
	isnt_enabled('foo', 'baz.service');
	ok(run_dh_tool('dh_clean'));

	ok(run_dh_tool('dh_installsystemduser', '--name', 'baz'));
	ok(! -e 'debian/foo/usr/lib/systemd/user/foo.service');
	ok(-e 'debian/foo/usr/lib/systemd/user/baz.service');
	isnt_enabled('foo', 'foo.service');
	is_enabled('foo', 'baz.service');
	ok(run_dh_tool('dh_clean'));
};
