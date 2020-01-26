# Defines dh sequence state variables
#
# License: GPL-2+

package Debian::Debhelper::DH::AddonAPI;
use strict;
use warnings;

use Debian::Debhelper::Dh_Lib qw(warning error);
use Debian::Debhelper::Sequence;
use Debian::Debhelper::SequencerUtil;
use Debian::Debhelper::DH::SequenceState;


our ($DH_INTERNAL_ADDON_TYPE, $DH_INTERNAL_ADDON_NAME);

sub _add_sequence {
	my @args = @_;
	my $seq = Debian::Debhelper::Sequence->new(@args);
	my $name = $seq->name;
	$Debian::Debhelper::DH::SequenceState::sequences{$name} = $seq;
	if ($seq->allowed_subsequences eq SEQUENCE_ARCH_INDEP_SUBSEQUENCES) {
		for my $subseq ((SEQUENCE_TYPE_ARCH_ONLY, SEQUENCE_TYPE_INDEP_ONLY)) {
			my $subname = "${name}-${subseq}";
			$Debian::Debhelper::DH::SequenceState::sequences{$subname} = $seq;
		}
	}
	return;
}

sub _skip_cmd_if_deb_build_options_contains {
	my ($command, $flag) = @_;
	push(@{$Debian::Debhelper::DH::SequenceState::commands_skippable_via_deb_build_options{$command}}, $flag);
	return;
}

sub _assert_not_conditional_sequence_addon {
	my ($feature) = @_;
	return if $DH_INTERNAL_ADDON_TYPE eq 'both';
	warning("The add-on ${DH_INTERNAL_ADDON_NAME} relies on a feature (${feature}) (possibly indirectly), which is "
		. 'not supported for conditional debhelper sequence add-ons.');
	warning("Hint: You may have to move the build-dependency for dh-sequence-${DH_INTERNAL_ADDON_NAME} to "
		. 'Build-Depends to avoid this error assuming it is possible to use the sequence unconditionally.');
	error("${feature} is not supported for conditional dh sequence add-ons.\n");
}

sub _filter_sequences_for_conditional_add_ons {
	my @sequences = @_;
	# If it is unconditional, then there is no issues.
	return @sequences if $DH_INTERNAL_ADDON_TYPE eq 'both' or not @sequences;
	for my $seq (@sequences) {
		# Typically, if you add a command to a sequence, then you will in fact add it to two. E.g.
		# Adding dh_foo after dh_installdocs will affect both install-arch AND install-indep.  We want
		# this to "just work(tm)" with a conditional add-on to avoid too much hassle (i.e. only affect
		# the relevant sequence).  At the same time, we must abort if a sequence like "clean" is
		# affected.
		#
		# We solve the above by checking if the sequence has an -arch + an -indep variant and then
		# insert the command only for that sequence variant.

		if ($seq->allowed_subsequences ne SEQUENCE_ARCH_INDEP_SUBSEQUENCES) {
			my $sequence_name = $seq->name;
			warning("The add-on ${DH_INTERNAL_ADDON_NAME} attempted to modify the sequence ${sequence_name} (possibly "
				. "indirectly) but the add-on is conditional for \"*-${DH_INTERNAL_ADDON_TYPE}\" targets");
			warning("Hint: You may have to move the build-dependency for dh-sequence-${DH_INTERNAL_ADDON_NAME} to "
				. 'Build-Depends to avoid this error assuming it is possible to use the sequence unconditionally.');
			error("The add-on ${DH_INTERNAL_ADDON_NAME} cannot be use conditionally for \"*-${DH_INTERNAL_ADDON_TYPE}\""
				. " targets\n");
		}
	}
	return @sequences;
}

sub _register_cmd_added_by_addon {
	my ($cmd) = @_;
	my $existing = $Debian::Debhelper::DH::SequenceState::commands_added_by_addon{$cmd};
	if ($existing) {
		if ($existing->{'addon-type'} ne $DH_INTERNAL_ADDON_TYPE) {
			my $old_addon_name = $existing->{'addon-name'};
			my $old_addon_type = $existing->{'addon-type'};
			# Technically, "both" could be made compatible with "indep" OR "arch" (but not both at the same time).
			# Implement if it turns out to be relevant.
			warning("Both dh sequence add-ons ${DH_INTERNAL_ADDON_NAME} and ${old_addon_name} have attempted to add "
				. "the command $cmd (possibly indirectly).");
			warning("However, the two add-ons do not have compatible constraints (${DH_INTERNAL_ADDON_TYPE} vs. "
				. "${old_addon_type}).");
			warning("Hint: You may have to move the build-dependency for dh-sequence-<X> to "
				. ' the same build-dependency field to avoid this error assuming it is possible.');
			error("Multiple sequences have conflicting requests for $cmd.\n");
		}
		return;
	}

	$Debian::Debhelper::DH::SequenceState::commands_added_by_addon{$cmd} = {
		'addon-name' => $DH_INTERNAL_ADDON_NAME,
		'addon-type' => $DH_INTERNAL_ADDON_TYPE,
	};
	return;
}

sub _sequences_containing_cmd {
	my ($cmd) = @_;
	my @sequences;
	foreach my $sequence_name (keys(%Debian::Debhelper::DH::SequenceState::sequences)) {
		my $seq = $Debian::Debhelper::DH::SequenceState::sequences{$sequence_name};
		for my $scmd (@{$seq->{'_cmds'}}) {
			if ($scmd->{'command'} eq $cmd) {
				push(@sequences, $seq);
				last;
			}
		}
	}
	return @sequences;
}

sub _seq_cmd {
	my ($cmd_name) = @_;
	return {
		'command'             => $cmd_name,
		'command-options'     => [],
		'sequence-limitation' => $DH_INTERNAL_ADDON_TYPE,
	};
}

# sequence addon interface
sub _insert {
	my ($offset, $existing, $new) = @_;
	my @affected_sequences = _sequences_containing_cmd($existing);
	@affected_sequences = _filter_sequences_for_conditional_add_ons(@affected_sequences);
	return if not @affected_sequences;
	_register_cmd_added_by_addon($new);
	for my $seq (@affected_sequences) {
		$seq->_insert($offset, $existing, _seq_cmd($new));
	}
	return 1;
}
sub insert_before {
	return _insert(-1, @_);
}
sub insert_after {
	return _insert(1, @_);
}
sub remove_command {
	my ($command) = @_;
	# Implement if actually needed (I *think* it basically means to transform dh_foo to dh_foo -a/-i)
	_assert_not_conditional_sequence_addon('remove_command');
	my @affected_sequences = _sequences_containing_cmd($command);
	@affected_sequences = _filter_sequences_for_conditional_add_ons(@affected_sequences);
	return 1 if not @affected_sequences;
	for my $seq (@affected_sequences) {
		$seq->remove_command($command);
	}
	return 1;
}
sub add_command {
	my ($command, $sequence) = @_;
	_assert_not_conditional_sequence_addon('add_command');
	_register_cmd_added_by_addon($command);
	if (not exists($Debian::Debhelper::DH::SequenceState::sequences{$sequence})) {
		_add_sequence($sequence, SEQUENCE_NO_SUBSEQUENCES, _seq_cmd($command));
	} else {
		my $seq = $Debian::Debhelper::DH::SequenceState::sequences{$sequence};
		_filter_sequences_for_conditional_add_ons($seq);
		$seq->add_command_at_start(_seq_cmd($command))
	}
	return 1;
}
sub add_command_at_end {
	my ($command, $sequence) = @_;
	_assert_not_conditional_sequence_addon('add_command');
	_register_cmd_added_by_addon($command);
	if (not exists($Debian::Debhelper::DH::SequenceState::sequences{$sequence})) {
		_add_sequence($sequence, SEQUENCE_NO_SUBSEQUENCES, _seq_cmd($command));
	} else {
		my $seq = $Debian::Debhelper::DH::SequenceState::sequences{$sequence};
		_filter_sequences_for_conditional_add_ons($seq);
		$seq->add_command_at_end(_seq_cmd($command))
	}
	return 1;
}

sub add_command_options {
	my $command=shift;
	# Implement if actually needed (Complicated as dh_foo becomes dh_foo -a && dh_foo -i <extra_options>
	# and that implies smarter deduplication logic)
	_assert_not_conditional_sequence_addon('add_command_options');
	push(@{$Debian::Debhelper::DH::SequenceState::command_opts{$command}}, @_);
	return 1;
}

sub remove_command_options {
	my ($command, @cmd_options) = @_;
	# Implement if actually needed (Complicated as dh_foo <extra_options> becomes
	#   dh_foo -a  <extra_options> && dh_foo -i and that implies smarter deduplication logic)
	_assert_not_conditional_sequence_addon('remove_command_options');
	if (@cmd_options) {
		# Remove only specified options
		if (my $opts = $Debian::Debhelper::DH::SequenceState::command_opts{$command}) {
			foreach my $opt (@cmd_options) {
				$opts = [ grep { $_ ne $opt } @$opts ];
			}
			$Debian::Debhelper::DH::SequenceState::command_opts{$command} = $opts;
		}
	}
	else {
		# Clear all additional options
		delete($Debian::Debhelper::DH::SequenceState::command_opts{$command});
	}
	return 1;
}

sub declare_command_obsolete {
	my ($command) = @_;
	_assert_not_conditional_sequence_addon('declare_command_obsolete');
	$Debian::Debhelper::DH::SequenceState::obsolete_command{$command} = $DH_INTERNAL_ADDON_NAME;
	return 1;
}


1;
