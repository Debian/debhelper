use strict;
use warnings;

use Debian::Debhelper::Dh_Lib qw(compat);
use Debian::Debhelper::SequencerUtil;

my $include_if_compat_X_or_newer = sub {
	my ($compat, @commands) = @_;
	return if compat($compat - 1, 1);
	return @commands;
};

my @obsolete_command = (
	$include_if_compat_X_or_newer->(11, 'dh_systemd_enable', 'dh_systemd_start'),
);

my @commands_controlled_by_deb_build_options = (
	$include_if_compat_X_or_newer->(13, ['dh_auto_test', 'nocheck'], ['dh_dwz', 'nostrip'], ['dh_strip', 'nostrip']),
);

my @bd_minimal = qw{
	dh_testdir
};
my @bd = (@bd_minimal, qw{
	dh_update_autotools_config
	dh_auto_configure
	dh_auto_build
	dh_auto_test
});
my @i = (qw{
	dh_testroot
	dh_prep
	dh_installdirs
	dh_auto_install

	dh_install
	dh_installdocs
	dh_installchangelogs
	dh_installexamples
	dh_installman

	dh_installcatalogs
	dh_installcron
	dh_installdebconf
	dh_installemacsen
	dh_installifupdown
	dh_installinfo
	dh_installinit
},
	$include_if_compat_X_or_newer->(13, 'dh_installtmpfiles'),
	$include_if_compat_X_or_newer->(11, 'dh_installsystemd'),
	$include_if_compat_X_or_newer->(12, 'dh_installsystemduser'),
qw{
	dh_installmenu
	dh_installmime
	dh_installmodules
	dh_installlogcheck
	dh_installlogrotate
	dh_installpam
	dh_installppp
	dh_installudev
	dh_installgsettings
},
	(!compat(11) ? qw(dh_installinitramfs) : qw()),
qw{
	dh_installalternatives
	dh_bugfiles
	dh_ucf
	dh_lintian
	dh_gconf
	dh_icons
	dh_perl
	dh_usrlocal

	dh_link
	dh_installwm
	dh_installxfonts
	dh_strip_nondeterminism
	dh_compress
	dh_fixperms
	dh_missing
});

# Looking for dh_dwz, dh_strip, dh_makeshlibs, dh_shlibdeps (et al)?  They are
# in the elf-tools addon.
my @b=qw{
	dh_installdeb
	dh_gencontrol
	dh_md5sums
	dh_builddeb
};

_add_sequence('build', SEQUENCE_ARCH_INDEP_SUBSEQUENCES, @bd);
_add_sequence('install', SEQUENCE_ARCH_INDEP_SUBSEQUENCES, to_rules_target("build"), @i);
_add_sequence('binary', SEQUENCE_ARCH_INDEP_SUBSEQUENCES, to_rules_target("install"), @b);
_add_sequence('clean', SEQUENCE_NO_SUBSEQUENCES, @bd_minimal, qw{
	dh_auto_clean
	dh_clean
});

for my $command (@obsolete_command) {
	declare_command_obsolete($command);
}

for my $entry (@commands_controlled_by_deb_build_options) {
	my ($command, $dbo_flag) = @{$entry};
	# Dear reader; Should you be in doubt, then this is internal API that is
	# subject to change without notice.  If you need this feature, please
	# make an explicit feature request, so we can implement a better solution.
	_skip_cmd_if_deb_build_options_contains($command, $dbo_flag);
}

1;
