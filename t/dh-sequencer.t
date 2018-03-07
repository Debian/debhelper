#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Debian::Debhelper::SequencerUtil;

# Shorten variants of the sequences.
my @bd = (qw{
	dh_testdir
	dh_auto_configure
	dh_auto_build
	dh_auto_test
});
my @i = (qw{
	dh_testroot
	dh_prep
	dh_auto_install

	dh_install
	dh_missing
});
my @ba=qw{
	dh_strip
	dh_makeshlibs
	dh_shlibdeps
};
my @b=qw{
	dh_installdeb
	dh_gencontrol
	dh_builddeb
};

my %sequences = (
    'build-indep' => [@bd],
    'build-arch'  => [@bd],
    'build'       => [to_rules_target("build-arch"), to_rules_target("build-indep")],

    'install-indep' => [to_rules_target("build-indep"), @i],
    'install-arch'  => [to_rules_target("build-arch"), @i],
    'install'       => [to_rules_target("build"), to_rules_target("install-arch"), to_rules_target("install-indep")],

    'binary-indep' => [to_rules_target("install-indep"), @b],
    'binary-arch'  => [to_rules_target("install-arch"), @ba, @b],
    'binary'       => [to_rules_target("install"), to_rules_target("binary-arch"), to_rules_target("binary-indep")],
);

my %sequences_unpacked = (
	'build-indep' => [@bd],
	'build-arch'  => [@bd],
	'build'       => [@bd],

	'install-indep' => [@bd, @i],
	'install-arch'  => [@bd, @i],
	'install'       => [@bd, @i],

	'binary-indep' => [@bd, @i, @b],
	'binary-arch'  => [@bd, @i, @ba, @b],
	'binary'       => [@bd, @i, @ba, @b],
);

plan tests => 11 + 3 * scalar(keys(%sequences));

# We will horse around with %EXPLICIT_TARGETS in this test; it should
# definitely not attempt to read d/rules or the test will be break.
$Debian::Debhelper::SequencerUtil::RULES_PARSED = 1;


is_deeply(
    [unpack_sequence(\%sequences, 'build')],
    [[], $sequences_unpacked{'build'}],
    'Inlined build sequence matches build-indep/build-arch');

is_deeply(
    [unpack_sequence(\%sequences, 'install')],
    [[], $sequences_unpacked{'install'}],
    'Inlined install sequence matches build-indep/build-arch + install commands');

is_deeply(
    [unpack_sequence(\%sequences, 'binary-arch')],
    [[], $sequences_unpacked{'binary-arch'}],
    'Inlined binary-arch sequence has all the commands');

is_deeply(
    [unpack_sequence(\%sequences, 'binary-indep')],
    [[], $sequences_unpacked{'binary-indep'}],
    'Inlined binary-indep sequence has all the commands except @bd');

is_deeply(
    [unpack_sequence(\%sequences, 'binary')],
    [[], $sequences_unpacked{'binary'}],
    'Inlined binary sequence has all the commands');


is_deeply(
	[unpack_sequence(\%sequences, 'binary', 0, { 'build' => 1, 'build-arch' => 1, 'build-indep' => 1})],
	[[], [@i, @ba, @b]],
	'Inlined binary sequence with build-* done has @i, @ba and @b');

{
    local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build'} = 1;

    is_deeply(
        [unpack_sequence(\%sequences, 'binary')],
        [[to_rules_target('build')], [@i, @ba, @b]],
        'Inlined binary sequence has all the commands but build target is opaque');

	is_deeply(
		[unpack_sequence(\%sequences, 'binary', 0, { 'build' => 1, 'build-arch' => 1, 'build-indep' => 1})],
		[[], [@i, @ba, @b]],
		'Inlined binary sequence has all the commands with build-* done and not build-target');

    is_deeply(
        [unpack_sequence(\%sequences, 'build')],
        [[], $sequences_unpacked{'build'}],
        'build sequence is inlineable');


	# Compat <= 8 ignores explicit targets!
	for my $seq_name (sort(keys(%sequences))) {
		is_deeply(
			[unpack_sequence(\%sequences, $seq_name, 1)],
			[[], $sequences_unpacked{$seq_name}],
			"Compat <= 8 ignores explicit build target in sequence ${seq_name}");
	}
}

{
    local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'install-arch'} = 1;

    is_deeply(
        [unpack_sequence(\%sequences, 'binary')],
		# @bd_minimal, @bd and @i should be "-i"-only, @ba + @b should be both.
		# Unfortunately, unpack_sequence cannot show that.
        [[to_rules_target('install-arch')], [@bd, @i, @ba, @b]],
        'Inlined binary sequence has all the commands');

	# Compat <= 8 ignores explicit targets!
	for my $seq_name (sort(keys(%sequences))) {
		is_deeply(
			[unpack_sequence(\%sequences, $seq_name, 1)],
			[[], $sequences_unpacked{$seq_name}],
			"Compat <= 8 ignores explicit install-arch target in sequence ${seq_name}");
	}
}

{
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'install-arch'} = 1;
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build'} = 1;

	my $actual = [unpack_sequence(\%sequences, 'binary')];
	# @i should be "-i"-only, @ba + @b should be both.
	# Unfortunately, unpack_sequence cannot show that.
	my $expected = [[to_rules_target('build'), to_rules_target('install-arch')], [@i, @ba, @b]];
	# Permit some fuzz on the order between build and install-arch
	if ($actual->[0][0] eq to_rules_target('install-arch')) {
		$expected->[0][0] = to_rules_target('install-arch');
		$expected->[0][1] = to_rules_target('build');
	}
	is_deeply(
		$actual,
		$expected,
		'Inlined binary sequence has all the commands');

	# Compat <= 8 ignores explicit targets!
	for my $seq_name (sort(keys(%sequences))) {
		is_deeply(
			[unpack_sequence(\%sequences, $seq_name, 1)],
			[[], $sequences_unpacked{$seq_name}],
			"Compat <= 8 ignores explicit build + install-arch targets in sequence ${seq_name}");
	}
}
