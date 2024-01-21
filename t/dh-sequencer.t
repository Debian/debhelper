#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Debian::Debhelper::Sequence;
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
my @ba = (
	{
		'command'             => 'dh_strip',
		'command-options'     => [],
		'sequence-limitation' => SEQUENCE_TYPE_ARCH_ONLY,
	},
	{
		'command'             => 'dh_makeshlibs',
		'command-options'     => [],
		'sequence-limitation' => SEQUENCE_TYPE_ARCH_ONLY,
	},
	{
		'command'             => 'dh_shlibdeps',
		'command-options'     => [],
		'sequence-limitation' => SEQUENCE_TYPE_ARCH_ONLY,
	}
);
my @b=qw{
	dh_installdeb
	dh_gencontrol
	dh_builddeb
};
my @c=qw{
	dh_testdir
	dh_auto_clean
	dh_clean
};

my %sequences;

sub _add_sequence {
	my @args = @_;
	my $seq = Debian::Debhelper::Sequence->new(@args);
	my $name = $seq->name;
	$sequences{$name} = $seq;
	if ($seq->allowed_subsequences eq SEQUENCE_ARCH_INDEP_SUBSEQUENCES) {
		for my $subseq ((SEQUENCE_TYPE_ARCH_ONLY, SEQUENCE_TYPE_INDEP_ONLY)) {
			my $subname = "${name}-${subseq}";
			$sequences{$subname} = $seq;
		}
	}
	return;
}

_add_sequence('build', SEQUENCE_ARCH_INDEP_SUBSEQUENCES, @bd);
_add_sequence('install', SEQUENCE_ARCH_INDEP_SUBSEQUENCES, to_rules_target("build"), @i);
_add_sequence('binary', SEQUENCE_ARCH_INDEP_SUBSEQUENCES, to_rules_target("install"), @ba, @b);
_add_sequence('clean', SEQUENCE_NO_SUBSEQUENCES, @c);

sub _cmd_names {
	my (@input) = @_;
	my @cmds;
	for my $cmd (@input) {
		if (ref($cmd) eq 'HASH') {
			push(@cmds, $cmd->{'command'});
		} else {
			push(@cmds, $cmd);
		}
	}
	return \@cmds;
}

my %sequences_unpacked = (
	'build-indep'   => _cmd_names(@bd),
	'build-arch'    => _cmd_names(@bd),
	'build'         => _cmd_names(@bd),

	'install-indep' => _cmd_names(@bd, @i),
	'install-arch'  => _cmd_names(@bd, @i),
	'install'       => _cmd_names(@bd, @i),

	'binary-indep'  => _cmd_names(@bd, @i, @b),
	'binary-arch'   => _cmd_names(@bd, @i, @ba, @b),
	'binary'        => _cmd_names(@bd, @i, @ba, @b),

	'clean'         => _cmd_names(@c),
);

plan tests => 21 + 3 * scalar(keys(%sequences));

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
	[[], _cmd_names(@i, @ba, @b)],
	'Inlined binary sequence with build-* done has @i, @ba and @b');


is_deeply(
	[unpack_sequence(\%sequences, 'binary', 0, { 'build-arch' => 1, 'build-indep' => 1})],
	[[], _cmd_names(@i, @ba, @b)],
	'Inlined binary sequence with build-* done has @i, @ba and @b');

is_deeply(
	[unpack_sequence(\%sequences, 'binary', 0, {}, 0)],
	[[], _cmd_names(@bd, @i, @ba, @b)],
	'Inlined binary sequence and arch:all + arch:any is reduced to @bd, @i, @ba and @b');

is_deeply(
	[unpack_sequence(\%sequences, 'binary', 0, {}, FLAG_OPT_SOURCE_BUILDS_NO_ARCH_PACKAGES)],
	[[], _cmd_names(@bd, @i, @b)],
	'Inlined binary sequence and not arch:any is reduced to @bd, @i and @b');

is_deeply(
	[unpack_sequence(\%sequences, 'binary', 0, {}, FLAG_OPT_SOURCE_BUILDS_NO_INDEP_PACKAGES)],
	[[], _cmd_names(@bd, @i, @ba, @b)],
	'Inlined binary sequence and not arch:all is reduced to @bd, @i, @ba and @b');


{
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build-arch'} = [1, 'debian/rules'];
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build-indep'} = [1, 'debian/rules'];

	is_deeply(
		[unpack_sequence(\%sequences, 'binary', 0, { 'build-arch' => 1, 'build-indep' => 1})],
		[[], _cmd_names(@i, @ba, @b)],
		'Inlined binary sequence with build-* done has @i, @ba and @b');
	my $actual = [unpack_sequence(\%sequences, 'binary')];
	# @i should be "-i"-only, @ba + @b should be both.
	# Unfortunately, unpack_sequence cannot show that.
	my $expected = [[to_rules_target('build-arch'), to_rules_target('build-indep')], _cmd_names(@i, @ba, @b)];
	# Permit some fuzz on the order between build-arch and build-arch
	if ($actual->[0][0] eq to_rules_target('build-indep')) {
		$expected->[0][0] = to_rules_target('build-indep');
		$expected->[0][1] = to_rules_target('build-arch');
	}
	is_deeply(
		$actual,
		$expected,
		'Inlined binary sequence with explicit build-* has explicit d/rules build-{arch,indep} + @i, @ba, @b');

	is_deeply(
		[unpack_sequence(\%sequences, 'binary', 0, { 'build' => 1})],
		[[], _cmd_names(@i, @ba, @b)],
		'Inlined binary sequence with explicit build-* but done build has only @i, @ba and @b');
}

{
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build-indep'} = [1, 'debian/rules'];
	is_deeply(
		[ unpack_sequence(\%sequences, 'binary', 0, { 'build-arch' => 1 }) ],
		[ [to_rules_target('build-indep')], _cmd_names(@i, @ba, @b) ],
		'Inlined binary sequence with build-arch done and build-indep explicit has d/rules build-indep + @i, @ba and @b');

	is_deeply(
		[ unpack_sequence(\%sequences, 'binary-arch', 0, { 'build-arch' => 1 }) ],
		[ [], _cmd_names(@i, @ba, @b) ],
		'Inlined binary-arch sequence with build-arch done and build-indep explicit has @i, @ba and @b');


	is_deeply(
		[ unpack_sequence(\%sequences, 'binary-indep', 0, { 'build-arch' => 1 }) ],
		[ [to_rules_target('build-indep')], _cmd_names(@i, @b) ],
		'Inlined binary-indep sequence with build-arch done and build-indep explicit has d/rules build-indep + @i and @b');
}

{
    local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build'} = [1, 'debian/rules'];

    is_deeply(
        [unpack_sequence(\%sequences, 'binary')],
        [[to_rules_target('build')], _cmd_names(@i, @ba, @b)],
        'Inlined binary sequence has all the commands but build target is opaque');

	is_deeply(
		[unpack_sequence(\%sequences, 'binary', 0, { 'build' => 1, 'build-arch' => 1, 'build-indep' => 1})],
		[[], _cmd_names(@i, @ba, @b)],
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
    local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'install-arch'} = [1, 'debian/rules'];

    is_deeply(
        [unpack_sequence(\%sequences, 'binary')],
		# @bd_minimal, @bd and @i should be "-i"-only, @ba + @b should be both.
		# Unfortunately, unpack_sequence cannot show that.
        [[to_rules_target('install-arch')], _cmd_names(@bd, @i, @ba, @b)],
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
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'install-arch'} = [1, 'debian/rules'];
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build'} = [1, 'debian/rules'];

	my $actual = [unpack_sequence(\%sequences, 'binary')];
	# @i should be "-i"-only, @ba + @b should be both.
	# Unfortunately, unpack_sequence cannot show that.
	my $expected = [[to_rules_target('build'), to_rules_target('install-arch')], _cmd_names(@i, @ba, @b)];
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
