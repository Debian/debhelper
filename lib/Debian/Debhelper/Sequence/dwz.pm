#!/usr/bin/perl
# Enable dh_dwz

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(compat error);

if (not compat(11)) {
	error("In compat 12, dh_dwz is run by default and the dwz-sequence is no longer required.");
}

insert_before('dh_strip', 'dh_dwz');

1;
