#!/usr/bin/perl
use Test;
plan(tests => 23);

system("rm -rf debian/debhelper debian/tmp");

# #537140: debian/tmp is explcitly specified despite being searched by
# default in v7+
system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("./dh_install", "debian/tmp/usr/bin/foo");
ok(-e "debian/debhelper/usr/bin/foo");
ok(! -e "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# debian/tmp explicitly specified in filenames in older compat level
system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("DH_COMPAT=6 ./dh_install debian/tmp/usr/bin/foo 2>/dev/null");
ok(-e "debian/debhelper/usr/bin/foo");
ok(! -e "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# --sourcedir=debian/tmp in older compat level
system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("DH_COMPAT=6 ./dh_install --sourcedir=debian/tmp usr/bin/foo 2>/dev/null");
ok(-e "debian/debhelper/usr/bin/foo");
ok(! -e "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# redundant --sourcedir=debian/tmp in v7+
system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("./dh_install --sourcedir=debian/tmp usr/bin/foo");
ok(-e "debian/debhelper/usr/bin/foo");
ok(! -e "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# #537017: --sourcedir=debian/tmp/foo is used
system("mkdir -p debian/tmp/foo/usr/bin; touch debian/tmp/foo/usr/bin/foo; touch debian/tmp/foo/usr/bin/bar");
system("./dh_install", "--sourcedir=debian/tmp/foo", "usr/bin/bar");
ok(-e "debian/debhelper/usr/bin/bar");
ok(! -e "debian/debhelper/usr/bin/foo");
system("rm -rf debian/debhelper debian/tmp");

# #535367: installation of entire top-level directory from debian/tmp
system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("./dh_install", "usr");
ok(-e "debian/debhelper/usr/bin/foo");
ok(-e "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# #534565: fallback use of debian/tmp in v7+
system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("./dh_install", "usr/bin");
ok(-e "debian/debhelper/usr/bin/foo");
ok(-e "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# no fallback to debian/tmp before v7
system("mkdir -p debian/tmp/usr/bin; touch debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("DH_COMPAT=6 ./dh_install usr/bin 2>/dev/null");
ok(! -e "debian/debhelper/usr/bin/foo");
ok(! -e "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# #534565: glob expands to dangling symlink -> should install the dangling link
system("mkdir -p debian/tmp/usr/bin; ln -s broken debian/tmp/usr/bin/foo; touch debian/tmp/usr/bin/bar");
system("./dh_install", "usr/bin/*");
ok(-l "debian/debhelper/usr/bin/foo");
ok(! -e "debian/debhelper/usr/bin/foo");
ok(-e "debian/debhelper/usr/bin/bar");
ok(! -l "debian/debhelper/usr/bin/bar");
system("rm -rf debian/debhelper debian/tmp");

# regular specification of file not in debian/tmp
system("./dh_install", "dh_install", "usr/bin");
ok(-e "debian/debhelper/usr/bin/dh_install");
system("rm -rf debian/debhelper debian/tmp");

# specification of file in source directory not in debian/tmp
system("mkdir -p bar/usr/bin; touch bar/usr/bin/foo");
system("./dh_install", "--sourcedir=bar", "usr/bin/foo");
ok(-e "debian/debhelper/usr/bin/foo");
system("rm -rf debian/debhelper bar");

# specification of file in subdir, not in debian/tmp
system("mkdir -p bar/usr/bin; touch bar/usr/bin/foo");
system("./dh_install", "bar/usr/bin/foo");
ok(-e "debian/debhelper/bar/usr/bin/foo");
system("rm -rf debian/debhelper bar");

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
