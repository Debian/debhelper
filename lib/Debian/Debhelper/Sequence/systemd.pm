#!/usr/bin/perl
use warnings;
use strict;
use Debian::Debhelper::Dh_Lib;

# dh_systemd_enable runs unconditionally, and before dh_installinit, so that
# the latter can use invoke-rc.d and all symlinks are already in place.
insert_before("dh_installinit", "dh_systemd_enable");

# dh_systemd_start handles the case where there is no corresponding init
# script, so it runs after dh_installinit.
insert_after("dh_installinit", "dh_systemd_start");

1
