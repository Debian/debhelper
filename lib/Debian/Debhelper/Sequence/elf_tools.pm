#!/usr/bin/perl

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(compat);

insert_after('dh_missing', 'dh_strip');
if (not compat(11)) {
	insert_before('dh_strip', 'dh_dwz');
}
insert_after('dh_strip', 'dh_makeshlibs');
insert_after('dh_makeshlibs', 'dh_shlibdeps');

1;