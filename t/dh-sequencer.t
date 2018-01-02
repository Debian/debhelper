#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Debian::Debhelper::SequencerUtil;

# Shorten variants of the sequences.
my @bd_minimal = qw{
	dh_testdir
};
my @bd = (qw{
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
    'build-indep' => [@bd_minimal, @bd],
    'build-arch'  => [@bd_minimal, @bd],
    'build'       => [@bd_minimal, to_rules_target("build-arch"), to_rules_target("build-indep")],

    'install-indep' => [to_rules_target("build-indep"), @i],
    'install-arch'  => [to_rules_target("build-arch"), @i],
    'install'       => [to_rules_target("build"), to_rules_target("install-arch"), to_rules_target("install-indep")],

    'binary-indep' => [to_rules_target("install-indep"), @b],
    'binary-arch'  => [to_rules_target("install-arch"), @ba, @b],
    'binary'       => [to_rules_target("install"), to_rules_target("binary-arch"), to_rules_target("binary-indep")],
);


plan tests => 9;

# We will horse around with %EXPLICIT_TARGETS in this test; it should
# definitely not attempt to read d/rules or the test will be break.
$Debian::Debhelper::SequencerUtil::RULES_PARSED = 1;


is_deeply(
    [optimize_sequence(\%sequences, 'build')],
    [@bd_minimal, @bd],
    'Inlined build sequence matches build-indep/build-arch');

is_deeply(
    [optimize_sequence(\%sequences, 'install')],
    [@bd_minimal, @bd, @i],
    'Inlined install sequence matches build-indep/build-arch + install commands');

is_deeply(
    [optimize_sequence(\%sequences, 'binary-arch')],
    [@bd_minimal, @bd, @i, @ba, @b],
    'Inlined binary-arch sequence has all the commands');

is_deeply(
    [optimize_sequence(\%sequences, 'binary-indep')],
    [@bd_minimal, @bd, @i, @b],
    'Inlined binary-indep sequence has all the commands except @bd');

is_deeply(
    [optimize_sequence(\%sequences, 'binary')],
    [@bd_minimal, @bd, @i, @ba, @b],
    'Inlined binary sequence has all the commands');

{
    local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build'} = 1;

    is_deeply(
        [optimize_sequence(\%sequences, 'binary')],
        [to_rules_target('build'), @i, @ba, @b],
        'Inlined binary sequence has all the commands but build target is opaque');

    is_deeply(
        [optimize_sequence(\%sequences, 'build')],
        [@bd_minimal, @bd],
        'build sequence is inlineable');

}

{
    local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'install-arch'} = 1;

    is_deeply(
        [optimize_sequence(\%sequences, 'binary')],
		# @bd_minimal, @bd and @i should be "-i"-only, @ba + @b should be both.
		# Unfortunately, optimize_sequence cannot show that.
        [to_rules_target('install-arch'), @bd_minimal, @bd, @i, @ba, @b],
        'Inlined binary sequence has all the commands');
}

{
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'install-arch'} = 1;
	local $Debian::Debhelper::SequencerUtil::EXPLICIT_TARGETS{'build'} = 1;

	my $actual = [optimize_sequence(\%sequences, 'binary')];
	# @i should be "-i"-only, @ba + @b should be both.
	# Unfortunately, optimize_sequence cannot show that.
	my $expected = [to_rules_target('build'), to_rules_target('install-arch'), @i, @ba, @b];
	# Permit some fuzz on the order between build and install-arch
	if ($actual->[0] eq to_rules_target('install-arch')) {
		$expected->[0] = to_rules_target('install-arch');
		$expected->[1] = to_rules_target('build');
	}
	is_deeply(
		$actual,
		$expected,
		'Inlined binary sequence has all the commands');
}
