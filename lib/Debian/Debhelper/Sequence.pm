#!/usr/bin/perl
#
# Internal library functions for the dh(1) command

package Debian::Debhelper::Sequence;
use strict;
use warnings;

use Exporter qw(import);

use Debian::Debhelper::Dh_Lib qw(error);
use Debian::Debhelper::SequencerUtil qw(extract_rules_target_name sequence_type	SEQUENCE_NO_SUBSEQUENCES
	SEQUENCE_ARCH_INDEP_SUBSEQUENCES SEQUENCE_TYPE_ARCH_ONLY SEQUENCE_TYPE_INDEP_ONLY SEQUENCE_TYPE_BOTH
	FLAG_OPT_SOURCE_BUILDS_NO_ARCH_PACKAGES	FLAG_OPT_SOURCE_BUILDS_NO_INDEP_PACKAGES);


sub _as_command {
	my ($input) = @_;
	if (ref($input) eq 'HASH') {
		return $input;
	}
	my $rules_target = extract_rules_target_name($input);
	if (defined($rules_target)) {
		my $sequence_type = sequence_type($rules_target);
		return {
			'command'             => $input,
			'command-options'     => [],
			'sequence-limitation' => $sequence_type,
		}
	}
	return {
		'command'             => $input,
		'command-options'     => [],
		'sequence-limitation' => SEQUENCE_TYPE_BOTH,
	}
}

sub new {
	my ($class, $name, $sequence_type, @cmds) = @_;
	return bless({
		'_name' => $name,
		'_subsequences' => $sequence_type,
		'_cmds' => [map {_as_command($_)} @cmds],
	}, $class);
}

sub name {
	my ($this) = @_;
	return $this->{'_name'};
}

sub allowed_subsequences {
	my ($this) = @_;
	return $this->{'_subsequences'};
}

sub _insert {
	my ($this, $offset, $existing, $new) = @_;
	my @list = @{$this->{'_cmds'}};
	my @new;
	my $new_cmd = _as_command($new);
	foreach my $command (@list) {
		if ($command->{'command'} eq $existing) {
			push(@new, $new_cmd) if $offset < 0;
			push(@new, $command);
			push(@new, $new_cmd) if $offset > 0;
		} else {
			push(@new, $command);
		}
	}
	$this->{'_cmds'} = \@new;
	return;
}

sub remove_command {
	my ($this, $command) = @_;
	$this->{'_cmds'} = [grep { $_->{'command'} ne $command } @{$this->{'_cmds'}}];
	return;
}

sub add_command_at_start {
	my ($this, $command) = @_;
	unshift(@{$this->{'_cmds'}}, _as_command($command));
	return;
}

sub add_command_at_end {
	my ($this, $command) = @_;
	push(@{$this->{'_cmds'}}, _as_command($command));
	return;
}

sub rules_target_name {
	my ($this, $sequence_type) = @_;
	error("Internal error: Invalid sequence type $sequence_type") if $sequence_type eq SEQUENCE_NO_SUBSEQUENCES;
	my $name = $this->{'_name'};
	my $allowed_sequence_type = $this->{'_subsequences'};
	if ($sequence_type ne SEQUENCE_TYPE_BOTH and $allowed_sequence_type eq SEQUENCE_NO_SUBSEQUENCES) {
		error("Internal error: Requested subsequence ${sequence_type} of sequence ${name}, but it has no subsequences");
	}
	if ($sequence_type ne SEQUENCE_TYPE_BOTH) {
		return "${name}-${sequence_type}";
	}
	return $name;
}

sub as_rules_target_command {
	my ($this) = shift;
	my $rules_name = $this->rules_target_name(@_);
	return "debian/rules ${rules_name}";
}

sub flatten_sequence {
	my ($this, $sequence_type, $flags) = @_;
	error("Invalid sequence type $sequence_type") if $sequence_type eq SEQUENCE_NO_SUBSEQUENCES;
	my @cmds;
	for my $cmd_desc (@{$this->{'_cmds'}}) {
		my $seq_limitation = $cmd_desc->{'sequence-limitation'};
		next if ($seq_limitation eq SEQUENCE_TYPE_ARCH_ONLY and ($flags & FLAG_OPT_SOURCE_BUILDS_NO_ARCH_PACKAGES));
		next if ($seq_limitation eq SEQUENCE_TYPE_INDEP_ONLY and ($flags & FLAG_OPT_SOURCE_BUILDS_NO_INDEP_PACKAGES));
		if ($seq_limitation eq $sequence_type or $sequence_type eq SEQUENCE_TYPE_BOTH or $seq_limitation eq SEQUENCE_TYPE_BOTH) {
			my $cmd = $cmd_desc->{'command'};
			my @cmd_options = $cmd_desc->{'command-options'};
			push(@cmds, [$cmd, @cmd_options]);
			next;
		}
	}
	return @cmds;
}

1;
