use strict;
use warnings;

use Debian::Debhelper::SequencerUtil;

my $include_if_compat_X_or_newer = sub {
	my ($compat, @commands) = @_;
	if (not compat($compat, 1)) {
		return @commands;
	}
	return;
};

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
	$include_if_compat_X_or_newer->(10, 'dh_installsystemd'),
	$include_if_compat_X_or_newer->(11, 'dh_installsystemduser'),
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

1;
