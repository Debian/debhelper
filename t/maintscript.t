#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use File::Path qw(remove_tree);
use File::Basename qw(dirname);
use lib dirname(__FILE__);
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);

plan(tests => 2);

each_compat_up_to_and_incl_subtest(10, sub {
	my @scripts = qw{postinst preinst prerm postrm};
	my $file = 'debian/maintscript';

	remove_tree('debian/debhelper', 'debian/tmp');
	rm_files(@scripts, $file);

	open(my $fd, ">", $file) || die("open($file): $!");
	print {$fd} <<EOF;
rm_conffile /etc/1
mv_conffile /etc/2 /etc/3 1.0-1
EOF
	close($fd) or die("close($file): $!\n");

	run_dh_tool('dh_installdeb');

	for my $script (@scripts) {
		my @output=`cat debian/debhelper.$script.debhelper`;
		ok(grep { m{^dpkg-maintscript-helper rm_conffile /etc/1 -- "\$\@"$} } @output);
		ok(grep { m{^dpkg-maintscript-helper mv_conffile /etc/2 /etc/3 1\.0-1 -- "\$\@"$} } @output);
	}
});

sub test_maintscript_syntax {
	my ($contents) = @_;
	my @scripts = map { ("debian/debhelper.${_}.debhelper", "debian/$_") } qw{postinst preinst prerm postrm};
	my $file = 'debian/maintscript';


	open(my $fd, ">", $file) or die("open($file): $!");
	print {$fd} <<EOF;
${contents}
EOF
	close($fd) or die("close($file): $!\n");

	my $res = run_dh_tool( { 'quiet' => 1 }, 'dh_installdeb');

	remove_tree('debian/debhelper', 'debian/tmp', 'debian/.debhelper');
	rm_files(@scripts);

	return $res;
}

# Negative tests
each_compat_from_and_above_subtest(12, sub {
	ok(!test_maintscript_syntax('rm_conffile foo 1.0~'), "rm_conffile absolute path check");
	ok(!test_maintscript_syntax('rm_conffile /foo 1.0\~'), "rm_conffile version check");
	ok(!test_maintscript_syntax('rm_conffile /foo 1.0~ some_pkg'), "rm_conffile package name check");
	ok(!test_maintscript_syntax('rm_conffile /foo 1.0~ some-pkg --'), "rm_conffile separator check");

	ok(!test_maintscript_syntax('mv_conffile foo /bar 1.0~'), "mv_conffile absolute (current) path check");
	ok(!test_maintscript_syntax('mv_conffile /foo bar 1.0~'), "mv_conffile absolute (current) path check");
	ok(!test_maintscript_syntax('mv_conffile /foo /bar 1.0\~'), "mv_conffile version check");
	ok(!test_maintscript_syntax('mv_conffile /foo /bar 1.0~ some_pkg'), "mv_conffile package name check");
	ok(!test_maintscript_syntax('mv_conffile /foo /bar 1.0~ some-pkg -- '), "mv_conffile separator check ");
});

