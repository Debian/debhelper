#!/usr/bin/perl
use strict;
use Test::More;
use File::Basename ();

# Let the tests be run from anywhere, but current directory
# is expected to be the one where this test lives in.
chdir File::Basename::dirname($0) or die "Unable to chdir to ".File::Basename::dirname($0);

my $TOPDIR = "../..";

plan(tests => 5);


# Verify dh_missing does not fail when all files are installed.
system("$TOPDIR/dh_clean");
system("make install");
system("PATH=$TOPDIR:\$PATH $TOPDIR/dh_install");
is(system("$TOPDIR/dh_missing --fail-missing"), 0, 'dh_missing failed');

# Verify dh_missing does fail when not all files are installed.
system("$TOPDIR/dh_clean");
system("make installmore");
system("PATH=$TOPDIR:\$PATH $TOPDIR/dh_install");
system("$TOPDIR/dh_missing --fail-missing >/dev/null 2>&1");
isnt($?, -1, 'dh_missing was executed');
ok(! ($? & 127), 'dh_missing did not die due to a signal');
my $exitcode = ($? >> 8);
is($exitcode, 2, 'dh_missing exited with exit code 2');

# Verify that dh_install -X --fail-missing is passed through to dh_missing (#863447)
# dh_install -Xfile makes file-for-foo not be installed. Then we shouldn't
# complain about it not being missing.
system("$TOPDIR/dh_clean");
system("make install");
is(system("PATH=$TOPDIR:\$PATH $TOPDIR/dh_install -X more --exclude lots --fail-missing"),0, 'dh_install -X... --fail-missing failed');

system("$TOPDIR/dh_clean");

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
