#!/usr/bin/perl
use strict;
use Test::More tests => 1;

use autodie;
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use File::Path qw(remove_tree make_path);
use Debian::Debhelper::Dh_Lib qw(!dirname);

our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
));

my $SCHEMAS = 'usr/share/glib-2.0/schemas';

sub touch {
	my $path = shift;
	open(my $fh, '>>', $path);
	close $fh;
}

sub slurp {
	my $path = shift;
	local $/ = undef;
	open(my $fh, '<', $path);
	my $contents = <$fh>;
	close $fh;
	return $contents;
}

each_compat_subtest {
	make_path("debian/has-settings/$SCHEMAS");
	touch("debian/has-settings/$SCHEMAS/com.example.HasSettings.xml");
	make_path("debian/has-unimportant-settings/$SCHEMAS");
	touch("debian/no-settings.substvars");
	ok(run_dh_tool('dh_installgsettings', '-phas-settings'), 'run for has-settings');
	ok(run_dh_tool('dh_installgsettings', '-pno-settings'), 'run for no-settings');
	remove_tree(qw(debian/has-settings debian/has-unimportant-settings));
	like(slurp('debian/has-settings.substvars'),
		qr{^misc:Depends=dconf-gsettings-backend \| gsettings-backend$}m,
		'has-settings should depend on a backend');
	unlike(slurp('debian/no-settings.substvars'),
		qr{^misc:Depends=dconf-gsettings-backend \| gsettings-backend$}m,
		'no-settings should not depend on a backend');
};

