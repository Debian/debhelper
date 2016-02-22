#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

eval 'use Test::Pod';
plan skip_all => 'Test::Pod required' if $@;

all_pod_files_ok(grep { -x $_ } glob 'dh_*');

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
