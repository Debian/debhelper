#!/usr/bin/perl
# debhelper sequence file for python-support

use warnings;
use strict;
use Debian::Debhelper::Dh_Lib;

# Test if dh_pysupport is available before inserting it.
# (This would not be needed if this file was contained in the python-support
# package.)
if (-x "/usr/bin/dh_pysupport") {
	insert_before("dh_installinit", "dh_pysupport");
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
