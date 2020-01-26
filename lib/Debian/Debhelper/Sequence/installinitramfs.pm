#!/usr/bin/perl
# Enable dh_installinitramfs

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(compat error);

if (not compat(11)) {
	error("In compat 12, dh_installinitramfs is run by default and the installinitramfs-sequence is no longer required.");
}

insert_after('dh_installgsettings', 'dh_installinitramfs');

1;
