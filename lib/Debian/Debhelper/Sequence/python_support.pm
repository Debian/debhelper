#!/usr/bin/perl
# Obsolete debhelper sequence file for python-support

use warnings;
use strict;
use Debian::Debhelper::Dh_Lib qw(deprecated_functionality);

deprecated_functionality('python_support sequence does nothing as dh_pysupport is no longer available', 11);

1
