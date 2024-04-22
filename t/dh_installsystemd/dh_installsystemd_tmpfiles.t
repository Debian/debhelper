#!/usr/bin/perl
use strict;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

our $TEST_DH_FIXTURE_DIR = 'named-legacy';
our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
    debian/foo.service
    debian/foo.init
));

plan(tests => 3);


# Units are installed and enabled
each_compat_from_x_to_and_incl_y_subtest(11, 12, sub {
	make_path('debian/foo/usr/lib/tmpfiles.d');
	create_empty_file('debian/foo/usr/lib/tmpfiles.d/foo.conf');
	ok(run_dh_tool('dh_installinit'));
	ok(run_dh_tool('dh_installsystemd'));
	ok(-e "debian/foo/etc/init.d/foo");
	ok(-e "debian/foo/usr/lib/systemd/system/foo.service");
	my @postinst = find_script('foo', 'postinst');
	# We should have two snippets (one for the tmpfiles and one for the services).
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

each_compat_from_and_above_subtest(13, sub {
	make_path('debian/foo/usr/lib/tmpfiles.d');
	create_empty_file('debian/foo/usr/lib/tmpfiles.d/foo.conf');
	ok(run_dh_tool('dh_installinit'));
	ok(run_dh_tool('dh_installsystemd'));
	ok(-e "debian/foo/etc/init.d/foo");
	ok(-e "debian/foo/usr/lib/systemd/system/foo.service");
	my @postinst = find_script('foo', 'postinst');
	# We should have one snippet (one for the services).
	is(scalar(@postinst), 1);
	if (scalar(@postinst) == 1) {
		open(my $fd, '<', $postinst[0]) or error("open($postinst[0]) failed: $!");
		my $snippet = readlines($fd);
		close($fd);
		ok(grep { m/(?:invoke|update)-rc.d|deb-systemd-invoke/ } @{$snippet});
		ok(! grep { m/systemd-tmpfiles/ } @{$snippet});
	}
	ok(run_dh_tool('dh_clean'));
});


each_compat_from_and_above_subtest(13, sub {
	my ($compat) = @_;

	make_path('debian/foo/usr/lib/tmpfiles.d');
	create_empty_file('debian/foo/usr/lib/tmpfiles.d/foo.conf');

	my $purge_file = <<END;
# Some comment

d /tmp/somedir
f /tmp/somedir/somefile - - - - baz
d /tmp/otherdir
R /tmp/yetotherdir
END

	open(my $fd, '>', 'debian/foo/usr/lib/tmpfiles.d/bar.conf') or error("open(bar.conf) failed: $!");
	print $fd $purge_file;
	close($fd) or error("close(bar.conf) failed: $!");

	ok(run_dh_tool('dh_installtmpfiles'));
	# dh_installtmpfiles do not install services
	ok(!-e "debian/foo/etc/init.d/foo");
	ok(!-e "debian/foo/usr/lib/systemd/system/foo.service");
	my @postinst = find_script('foo', 'postinst');
	# We should have too snippets (one for the tmpfiles and one for the services).
	is(scalar(@postinst), 1);
	if (scalar(@postinst) == 1) {
		open(my $fd, '<', $postinst[0]) or error("open($postinst[0]) failed: $!");
		my $snippet = readlines($fd);
		close($fd);
		ok(! grep { m/(?:invoke|update)-rc.d|deb-systemd-invoke/ } @{$snippet});
		ok(grep { m/systemd-tmpfiles/ } @{$snippet});
	}

	my @postrm = find_script('foo', 'postrm');
	if ($compat <= 13) {
		# No factory reset on compat 13
		is(scalar(@postrm), 0);
	} else {
		# We should have an inlined snippets for removal/purge
		is(scalar(@postrm), 1);
		if (scalar(@postrm) == 1) {
			open(my $fd, '<', $postrm[0]) or error("open($postrm[0]) failed: $!");
			my $snippet = readlines($fd);
			close($fd);
			ok(grep { m/# Some comment/ } @{$snippet});
			ok(grep { m/d \/tmp\/somedir/ } @{$snippet});
			ok(grep { m/f \/tmp\/somedir\/somefile - - - - baz/ } @{$snippet});
			ok(grep { m/d \/tmp\/otherdir/ } @{$snippet});
			ok(grep { m/R \/tmp\/yetotherdir/ } @{$snippet});
		}
	}

	ok(run_dh_tool('dh_clean'));
});
