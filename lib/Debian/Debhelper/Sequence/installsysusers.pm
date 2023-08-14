#!/usr/bin/perl
# Enable dh_installsysusers

use strict;
use warnings;

insert_after('dh_install', 'dh_installsysusers');

1;
