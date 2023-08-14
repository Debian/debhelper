#!/usr/bin/perl
use warnings;
use strict;
use Debian::Debhelper::Dh_Lib qw(compat error);

if (not compat(10)) {
       error("The systemd-sequence is no longer provided in compat >= 11, please rely on dh_installsystemd instead");
}


# dh_systemd_enable runs unconditionally, and before dh_installinit, so that
# the latter can use invoke-rc.d and all symlinks are already in place.
insert_before("dh_installinit", "dh_systemd_enable");

# dh_systemd_start handles the case where there is no corresponding init
# script, so it runs after dh_installinit.
insert_after("dh_installinit", "dh_systemd_start");

1
