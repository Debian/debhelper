#!/usr/bin/perl
use Test;
plan(tests => 13);

# It used to not make absolute links in this situation, and it should.
# #37774
system("./dh_link","etc/foo","usr/lib/bar");
ok(readlink("debian/debhelper/usr/lib/bar"), "/etc/foo");

# let's make sure it makes simple relative links ok.
system("./dh_link","usr/bin/foo","usr/bin/bar");
ok(readlink("debian/debhelper/usr/bin/bar"), "foo");
system("./dh_link","sbin/foo","sbin/bar");
ok(readlink("debian/debhelper/sbin/bar"), "foo");

# ok, more complex relative links.
system("./dh_link","usr/lib/1","usr/bin/2");
ok(readlink("debian/debhelper/usr/bin/2"),"../lib/1");

# Check conversion of relative symlink to different top-level directory
# into absolute symlink. (#244157)
system("mkdir -p debian/debhelper/usr/lib; mkdir -p debian/debhelper/lib; touch debian/debhelper/lib/libm.so; cd debian/debhelper/usr/lib; ln -sf ../../lib/libm.so");
system("./dh_link");
ok(readlink("debian/debhelper/usr/lib/libm.so"), "/lib/libm.so");

# Check links to the current directory and below, they used to be
# unnecessarily long (#346405).
system("./dh_link","usr/lib/geant4","usr/lib/geant4/a");
ok(readlink("debian/debhelper/usr/lib/geant4/a"), ".");
system("./dh_link","usr/lib","usr/lib/geant4/b");
ok(readlink("debian/debhelper/usr/lib/geant4/b"), "..");
system("./dh_link","usr","usr/lib/geant4/c");
ok(readlink("debian/debhelper/usr/lib/geant4/c"), "../..");
system("./dh_link","/","usr/lib/geant4/d");
ok(readlink("debian/debhelper/usr/lib/geant4/d"), "/");

# Link to self.
system("./dh_link usr/lib/foo usr/lib/foo 2>/dev/null");
ok(! -l "debian/debhelper/usr/lib/foo");

# Make sure the link conversion didn't change any of the previously made
# links.
ok(readlink("debian/debhelper/usr/lib/bar"), "/etc/foo");
ok(readlink("debian/debhelper/usr/bin/bar"), "foo");
ok(readlink("debian/debhelper/usr/bin/2"),"../lib/1");

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
