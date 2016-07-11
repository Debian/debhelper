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
	plan(tests => 17);
}

system("rm -rf debian/foo debian/bar debian/baz");

my $doc = "debian/docfile";

system("$rootcmd $TOPDIR/dh_installdocs -pbar $doc");
ok(-e "debian/bar/usr/share/doc/bar/docfile");
system("rm -rf debian/foo debian/bar debian/baz");

#regression in debhelper 9.20160709 (#830309)
system("DH_COMPAT=11 $rootcmd $TOPDIR/dh_installdocs -pbar $doc");
ok(-e "debian/bar/usr/share/doc/foo/docfile");
system("rm -rf debian/foo debian/bar debian/baz");

#regression in debhelper 9.20160702 (#830309)
system("$rootcmd $TOPDIR/dh_installdocs -pbaz --link-doc=foo $doc");
ok(-l "debian/baz/usr/share/doc/baz");
ok(readlink("debian/baz/usr/share/doc/baz") eq 'foo');
ok(-e "debian/baz/usr/share/doc/foo/docfile");
system("rm -rf debian/foo debian/bar debian/baz");

system("DH_COMPAT=11 $rootcmd $TOPDIR/dh_installdocs -pbaz --link-doc=foo $doc");
ok(-l "debian/baz/usr/share/doc/baz");
ok(readlink("debian/baz/usr/share/doc/baz") eq 'foo');
ok(-e "debian/baz/usr/share/doc/foo/docfile");
system("rm -rf debian/foo debian/bar debian/baz");

system("DH_COMPAT=11 $rootcmd $TOPDIR/dh_installdocs -pbaz --link-doc=bar $doc");
ok(-l "debian/baz/usr/share/doc/baz");
ok(readlink("debian/baz/usr/share/doc/baz") eq 'bar');
ok(-e "debian/baz/usr/share/doc/foo/docfile");
system("rm -rf debian/foo debian/bar debian/baz");

system("$rootcmd $TOPDIR/dh_installdocs -pfoo --link-doc=bar $doc");
ok(-l "debian/foo/usr/share/doc/foo");
ok(readlink("debian/foo/usr/share/doc/foo") eq 'bar');
ok(-e "debian/foo/usr/share/doc/bar/docfile");
system("rm -rf debian/foo debian/bar debian/baz");

system("DH_COMPAT=11 $rootcmd $TOPDIR/dh_installdocs -pfoo --link-doc=bar $doc");
ok(-l "debian/foo/usr/share/doc/foo");
ok(readlink("debian/foo/usr/share/doc/foo") eq 'bar');
ok(-e "debian/foo/usr/share/doc/bar/docfile");
system("rm -rf debian/foo debian/bar debian/baz");

system("$TOPDIR/dh_clean");

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
