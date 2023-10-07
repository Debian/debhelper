#!/usr/bin/perl
# Enable dh_movetousr

use strict;
use warnings;

insert_before('dh_installdeb', 'dh_movetousr');

1;
