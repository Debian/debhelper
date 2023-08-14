# Defines dh sequence state variables
#
# License: GPL-2+

package Debian::Debhelper::DH::SequenceState;
use strict;
use warnings;

our (
	# Definitions of sequences.
	%sequences,
	# Additional command options
	%command_opts,
	# Track commands added by (which) addons
	%commands_added_by_addon,
	# Removed commands
	%obsolete_command,
	# Commands that can be skipped due to DEB_BUILD_OPTIONS=X flags
	%commands_skippable_via_deb_build_options,
	# Options passed that should be passed on to underlying helpers (in order)
	@options,
	# Options passed by name (to assist can_skip with which options are used)
	%seen_options,
	# Whether there were sequences of options that inhibit certain optimizations
	# * $unoptimizable_option_bundle => can skip iff cli-options hint is present and empty
	# * $unoptimizable_user_option => We can never skip anything (non-option seen)
	$unoptimizable_option_bundle,
	$unoptimizable_user_option,
);

1;
