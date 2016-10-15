#!/usr/bin/perl
use strict;
use warnings;
use Test;
plan(tests => 8);

system("mkdir -p t/tmp/debian");
system("cp debian/control t/tmp/debian");
open(OUT, ">", "t/tmp/debian/maintscript") || die "$!";
print OUT <<EOF;
rm_conffile /etc/1
mv_conffile /etc/2 /etc/3 1.0-1
EOF
close OUT;
system("echo 10 >> t/tmp/debian/compat");
system("cd t/tmp && fakeroot ../../dh_installdeb");
for my $script (qw{postinst preinst prerm postrm}) {
	my @output=`cat t/tmp/debian/debhelper.$script.debhelper`;
	ok(grep { m{^dpkg-maintscript-helper rm_conffile /etc/1 -- "\$\@"$} } @output);
	ok(grep { m{^dpkg-maintscript-helper mv_conffile /etc/2 /etc/3 1\.0-1 -- "\$\@"$} } @output);
}
system("rm -rf t/tmp");

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
