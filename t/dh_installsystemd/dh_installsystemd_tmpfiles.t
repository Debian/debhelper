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
    debian/foo.init
));

plan(tests => 1);

# Units are installed and enabled
each_compat_from_and_above_subtest(11, sub {
	make_path('debian/foo/usr/lib/tmpfiles.d');
	create_empty_file('debian/foo/usr/lib/tmpfiles.d/foo.conf');
	ok(run_dh_tool('dh_installinit'));
	ok(run_dh_tool('dh_installsystemd'));
	ok(-e "debian/foo/etc/init.d/foo");
	ok(-e "debian/foo/lib/systemd/system/foo.service");
	my @postinst = find_script('foo', 'postinst');
	# We should have too snippets (one for the tmpfiles and one for the services).
	is(scalar(@postinst), 2);
	if (scalar(@postinst) == 2) {
		open(my $fd, '<', $postinst[0]) or error("open($postinst[0]) failed: $!");
		my $early_snippet = readlines($fd);
		close($fd);
		open($fd, '<', $postinst[1]) or error("open($postinst[1]) failed: $!");
		my $late_snippet = readlines($fd);
		close($fd);
		ok(! grep { m/(?:invoke|update)-rc.d|deb-systemd-invoke/ } @{$early_snippet});
		ok(grep { m/(?:invoke|update)-rc.d|deb-systemd-invoke/ } @{$late_snippet});
		ok(grep { m/systemd-tmpfiles/ } @{$early_snippet});
		ok(! grep { m/systemd-tmpfiles/ } @{$late_snippet});
	}
	ok(run_dh_tool('dh_clean'));

});
