#!/usr/bin/perl
package Debian::Debhelper::Dh_Lib::Test;
use strict;
use warnings;
use Test::More;

use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Test::DH;

use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 2);


sub ok_autoscript_result {
	ok(-f 'debian/testpackage.postinst.debhelper');
	open(my $fd, '<', 'debian/testpackage.postinst.debhelper') or die("open test-poinst: $!");
	my (@c) = <$fd>;
	close($fd);
	like(join('',@c), qr{update-rc\.d test-script test parms with"quote >/dev/null});
}


each_compat_subtest {

	ok(autoscript('testpackage', 'postinst', 'postinst-init',
				  's/#SCRIPT#/test-script/g; s/#INITPARMS#/test parms with\\"quote/g'));
	ok_autoscript_result;

	ok(rm_files('debian/testpackage.postinst.debhelper'));

	ok(autoscript('testpackage', 'postinst', 'postinst-init',
				  sub { s/\#SCRIPT\#/test-script/g; s/\#INITPARMS\#/test parms with"quote/g } ));
	ok_autoscript_result;

	ok(rm_files('debian/testpackage.postinst.debhelper'));

	ok(autoscript('testpackage', 'postinst', 'postinst-init',
				  { 'SCRIPT' => 'test-script', 'INITPARMS' => 'test parms with"quote' } ));
	ok_autoscript_result;

	ok(rm_files('debian/testpackage.postinst.debhelper'));
};

$ENV{'FOO'} = "test";
my @SUBST_TEST_OK = (
	['unchanged', 'unchanged'],
	["unchanged\${\n}", "unchanged\${\n}"],  # Newline is not an allowed part of ${}
	['raw dollar-sign ${}', 'raw dollar-sign $'],
	['${Dollar}${Space}${Dollar}', '$ $'],
	['Hello ${env:FOO}', 'Hello test'],
	['${Dollar}{Space}${}{Space}', '${Space}${Space}'],  # We promise that ${Dollar}/${} never cause recursion
	['/usr/lib/${DEB_HOST_MULTIARCH}', '/usr/lib/' . dpkg_architecture_value('DEB_HOST_MULTIARCH')],
);

each_compat_subtest {
	for my $test (@SUBST_TEST_OK) {
		my ($input, $expected_output) = @{$test};
		my $actual_output = Debian::Debhelper::Dh_Lib::_variable_substitution($input, 'test');
		is($actual_output, $expected_output, qq{${input}" => "${actual_output}" (should be: "${expected_output})"});
	}
};
