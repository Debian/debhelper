#!/usr/bin/perl
package Debian::Debhelper::Dh_Lib::Test;
use strict;
use warnings;
use Test::More;

plan(tests => 10);

use_ok('Debian::Debhelper::Dh_Lib');

sub ok_autoscript_result {
	ok(-f 'debian/testpackage.postinst.debhelper');
	open(my $fd, '<', 'debian/testpackage.postinst.debhelper') or die("open test-poinst: $!");
	my (@c) = <$fd>;
	close($fd);
	like(join('',@c), qr{update-rc\.d test-script test parms with"quote >/dev/null});
}

ok(unlink('debian/testpackage.postinst.debhelper') >= 0);

ok(autoscript('testpackage', 'postinst', 'postinst-init',
              's/#SCRIPT#/test-script/g; s/#INITPARMS#/test parms with\\"quote/g'));
ok_autoscript_result;

ok(unlink('debian/testpackage.postinst.debhelper') >= 0);

ok(autoscript('testpackage', 'postinst', 'postinst-init',
              sub { s/#SCRIPT#/test-script/g; s/#INITPARMS#/test parms with"quote/g } ));
ok_autoscript_result;

ok(unlink('debian/testpackage.postinst.debhelper') >= 0);

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
