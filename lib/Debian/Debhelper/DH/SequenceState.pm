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
);

1;
