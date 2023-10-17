#!/usr/bin/perl
# Enable dh_movetousr

use strict;
use warnings;

$ENV{DH_INTERNAL_MOVETOUSR_IS_ADDON} = '1';
insert_before('dh_installdeb', 'dh_movetousr');

1;
