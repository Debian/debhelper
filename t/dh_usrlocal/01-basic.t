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


sub perform_test {
	my ($install_dirs, $expected_dirs_postinst, $expected_dirs_prerm) = @_;
	my (@postinst, @prerm);
	my @scripts = qw(
        debian/debhelper.postinst.debhelper
        debian/debhelper.prerm.debhelper
    );

	rm_files(@scripts);
	remove_tree('debian/debhelper');
	install_dir(map { "debian/debhelper/$_" } @{$install_dirs});

	ok(run_dh_tool('dh_usrlocal'));

	@postinst = extract_generated_lines("debian/debhelper.postinst.debhelper");
	@prerm = extract_generated_lines("debian/debhelper.prerm.debhelper");

	is_deeply(\@postinst,
			  [map { "$_ default" } @{$expected_dirs_postinst}],
			  "Correct postinst"
		) or do { diag("postinst: $_") for @postinst; };
	is_deeply(\@prerm,
			  $expected_dirs_prerm,
			  "Correct prerm"
		) or do { diag("prerm: $_") for @prerm; };
}

each_compat_subtest {

	perform_test(
		['/usr/local/bar', '/usr/local/foo'],
		['/usr/local/bar', '/usr/local/foo'],
		[]
	);

	perform_test(
		[
		 '/usr/local/foo/bar',
		 '/usr/local/foo/baz',
		],
		[
		 '/usr/local/foo',
		 '/usr/local/foo/bar',
		 '/usr/local/foo/baz',
		],
		[
		 '/usr/local/foo/bar',
		 '/usr/local/foo/baz',
		]
	);

	perform_test(
		[qw(
		 /usr/local/a/a/a
		 /usr/local/a/a/b
		 /usr/local/a/b/a
		 /usr/local/a/b/b
		 /usr/local/b/a/a
		 /usr/local/b/a/b
		 /usr/local/b/b/a
		 /usr/local/b/b/b
		)],
		[qw(
		 /usr/local/a
		 /usr/local/a/a
		 /usr/local/a/a/a
		 /usr/local/a/a/b
		 /usr/local/a/b
		 /usr/local/a/b/a
		 /usr/local/a/b/b
		 /usr/local/b
		 /usr/local/b/a
		 /usr/local/b/a/a
		 /usr/local/b/a/b
		 /usr/local/b/b
		 /usr/local/b/b/a
		 /usr/local/b/b/b
		 )],
		[qw(
		 /usr/local/a/a/a
		 /usr/local/a/a/b
		 /usr/local/a/a
		 /usr/local/a/b/a
		 /usr/local/a/b/b
		 /usr/local/a/b
		 /usr/local/b/a/a
		 /usr/local/b/a/b
		 /usr/local/b/a
		 /usr/local/b/b/a
		 /usr/local/b/b/b
		 /usr/local/b/b
		 )]
	);

	perform_test(
		[
		 '/usr/local/foo/dir/somewhere',
		 '/usr/local/bar/another-dir/elsewhere',
		 '/usr/local/baz/foo+bar/thing',
		],
		[
		 '/usr/local/bar',
		 '/usr/local/bar/another-dir',
		 '/usr/local/bar/another-dir/elsewhere',
		 '/usr/local/baz',
		 '/usr/local/baz/foo+bar',
		 '/usr/local/baz/foo+bar/thing',
		 '/usr/local/foo',
		 '/usr/local/foo/dir',
		 '/usr/local/foo/dir/somewhere',
		],
		[
		 '/usr/local/bar/another-dir/elsewhere',
		 '/usr/local/bar/another-dir',
		 '/usr/local/baz/foo+bar/thing',
		 '/usr/local/baz/foo+bar',
		 '/usr/local/foo/dir/somewhere',
		 '/usr/local/foo/dir',
		]
	);
};

