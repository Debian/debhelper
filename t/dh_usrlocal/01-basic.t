#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
plan(tests => 1);

use File::Path qw(remove_tree);
use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);

sub extract_generated_lines {
	my ($file) = @_;
	my (@lines, $marker);
	return if not -f $file;
	open(my $fd, '<', $file) or error("open($file) failed: $!");
	while (my $line = <$fd>) {
		chomp($line);
		if (defined($marker)) {
			last if $line eq $marker;
			push(@lines, $line);
			next;
		}
		if ($line =~ m{\s*<<\s*(\S+)\s*$}) {
			$marker = $1;
		}
	}
	close($fd);
	return @lines;
}

each_compat_subtest {

	my (@postinst, @prerm);
	my @scripts = qw(
        debian/debhelper.postinst.debhelper
        debian/debhelper.prerm.debhelper
    );

	rm_files(@scripts);
	remove_tree('debian/debhelper');
	install_dir('debian/debhelper/usr/local/foo');
	install_dir('debian/debhelper/usr/local/bar');

	ok(run_dh_tool('dh_usrlocal'));
	@postinst = extract_generated_lines("debian/debhelper.postinst.debhelper");
	@prerm = extract_generated_lines("debian/debhelper.prerm.debhelper");

	is_deeply(\@postinst, [
				  '/usr/local/bar 02775 root staff',
				  '/usr/local/foo 02775 root staff',
			  ], "Correct dir creation")
		or do { diag("postinst: $_") for @postinst; };
	is_deeply(\@prerm, [], "No removal of top level dirs #894549")
		or do { diag("prerm: $_") for @prerm; };
	
	remove_tree('debian/debhelper');
	rm_files(@scripts);
	install_dir('debian/debhelper/usr/local/foo/dir/somewhere');
	install_dir('debian/debhelper/usr/local/bar/another-dir/elsewhere');
	install_dir('debian/debhelper/usr/local/baz/foo+bar/thing');

	ok(run_dh_tool('dh_usrlocal'));

	@postinst = extract_generated_lines("debian/debhelper.postinst.debhelper");
	@prerm = extract_generated_lines("debian/debhelper.prerm.debhelper");

	is_deeply(\@postinst, [
				  '/usr/local/bar 02775 root staff',
				  '/usr/local/bar/another-dir 02775 root staff',
				  '/usr/local/bar/another-dir/elsewhere 02775 root staff',
				  '/usr/local/baz 02775 root staff',
				  '/usr/local/baz/foo+bar 02775 root staff',
				  '/usr/local/baz/foo+bar/thing 02775 root staff',
				  '/usr/local/foo 02775 root staff',
				  '/usr/local/foo/dir 02775 root staff',
				  '/usr/local/foo/dir/somewhere 02775 root staff',
			  ], "Correct dir creation")
		or do { diag("postinst: $_") for @postinst; };
	is_deeply(\@prerm, [
				  '/usr/local/bar/another-dir/elsewhere',
				  '/usr/local/bar/another-dir',
				  '/usr/local/baz/foo+bar/thing',
				  '/usr/local/baz/foo+bar',
				  '/usr/local/foo/dir/somewhere',
				  '/usr/local/foo/dir',
			  ], "Correct dir removal")
		or do { diag("prerm: $_") for @prerm; };
};

