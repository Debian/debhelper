#!/usr/bin/perl
use strict;
use Test::More;
use File::Basename ();

# Let the tests be run from anywhere, but current directory
# is expected to be the one where this test lives in.
chdir File::Basename::dirname($0) or die "Unable to chdir to ".File::Basename::dirname($0);

my $TOPDIR = "../..";
my $rootcmd;

if ($< == 0) {
	$rootcmd = '';
}
else {
	system("fakeroot true 2>/dev/null");
	$rootcmd = $? ? undef : 'fakeroot';
}

if (not defined($rootcmd)) {
	plan skip_all => 'fakeroot required';
}
else {
	plan(tests => 5);
}

system("$TOPDIR/dh_clean");

my $service = "debian/foo.service";

system("mkdir -p debian/foo debian/bar debian/baz");
system("$rootcmd $TOPDIR/dh_installinit");
ok(-e "debian/foo/lib/systemd/system/foo.service");
ok(-e "debian/foo.postinst.debhelper");
system("$TOPDIR/dh_clean");

system("mkdir -p debian/foo debian/bar debian/baz");
system("DH_COMPAT=11 $rootcmd $TOPDIR/dh_installinit");
ok(! -e "debian/foo/lib/systemd/system/foo.service");
ok(! -e "debian/foo.postinst.debhelper");
system("$TOPDIR/dh_clean");

system("mkdir -p debian/foo debian/bar debian/baz");
system("mkdir -p debian/foo/lib/systemd/system/");
system("cp debian/foo.service debian/foo/lib/systemd/system/");
system("DH_COMPAT=11 $rootcmd $TOPDIR/dh_installinit");
ok(! -e "debian/foo.postinst.debhelper");
system("$TOPDIR/dh_clean");

system("$TOPDIR/dh_clean");

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
