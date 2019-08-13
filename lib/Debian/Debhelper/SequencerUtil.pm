#!/usr/bin/perl
#
# Internal library functions for the dh(1) command

package Debian::Debhelper::SequencerUtil;
use strict;
use warnings;
use constant {
	'DUMMY_TARGET' => 'debhelper-fail-me',
	'SEQUENCE_NO_SUBSEQUENCES' => 'none',
	'SEQUENCE_ARCH_INDEP_SUBSEQUENCES' => 'both',
	'SEQUENCE_TYPE_ARCH_ONLY' => 'arch',
	'SEQUENCE_TYPE_INDEP_ONLY' => 'indep',
	'SEQUENCE_TYPE_BOTH' => 'both',
};

use Exporter qw(import);

our @EXPORT = qw(
	extract_rules_target_name
	to_rules_target
	sequence_type
	unpack_sequence
	rules_explicit_target
	extract_skipinfo
	DUMMY_TARGET
	SEQUENCE_NO_SUBSEQUENCES
	SEQUENCE_ARCH_INDEP_SUBSEQUENCES
	SEQUENCE_TYPE_ARCH_ONLY
	SEQUENCE_TYPE_INDEP_ONLY
	SEQUENCE_TYPE_BOTH
);

our (%EXPLICIT_TARGETS, $RULES_PARSED);

sub extract_rules_target_name {
	my ($command) = @_;
	if ($command =~ m{^debian/rules\s++(.++)}) {
		return $1
	}
	return;
}

sub to_rules_target  {
	return 'debian/rules '.join(' ', @_);
}

sub sequence_type {
	my ($sequence_name) = @_;
	if ($sequence_name =~ m/-indep$/) {
		return 'indep';
	} elsif ($sequence_name =~ m/-arch/) {
		return 'arch';
	}
	return 'both';
}

sub _agg_subseq {
	my ($current_subseq, $outer_subseq) = @_;
	if ($current_subseq eq $outer_subseq) {
		return $current_subseq;
	}
	if ($current_subseq eq 'both') {
		return $outer_subseq;
	}
	return $current_subseq;
}

sub unpack_sequence {
	my ($sequences, $sequence_name, $always_inline, $completed_sequences) = @_;
	my (@sequence, @targets, %seen, %non_inlineable_targets, @stack);
	my $sequence_type = sequence_type($sequence_name);
	# Walk through the sequence effectively doing a DFS of the rules targets
	# (when we are allowed to inline them).
	my $seq = $sequences->{$sequence_name};
	push(@stack, [$seq->flatten_sequence($sequence_type)]);
	while (@stack) {
		my $current_sequence = pop(@stack);
	  COMMAND:
		while (@{$current_sequence}) {
			my $command = shift(@{$current_sequence});
			if (ref($command) eq 'ARRAY') {
				$command = $command->[0];
			}
			my $rules_target=extract_rules_target_name($command);
			next if (defined($rules_target) and exists($completed_sequences->{$rules_target}));
			if (defined($rules_target) and $always_inline) {
				my $subsequence = $sequences->{$rules_target};
				my $subseq_type = _agg_subseq(sequence_type($rules_target), $sequence_type);
				push(@stack, $current_sequence);
				$current_sequence = [$subsequence->flatten_sequence($subseq_type)];
			} elsif (defined($rules_target)) {
				my $subsequence = $sequences->{$rules_target};
				my $subseq_type = _agg_subseq(sequence_type($rules_target), $sequence_type);
				my @subseq_types = ($subseq_type);
				my %subtarget_status;
				my ($transparent_subseq, $opaque_subseq, $subtarget_decided_both);
				if ($subseq_type eq SEQUENCE_TYPE_BOTH) {
					push(@subseq_types, SEQUENCE_TYPE_ARCH_ONLY, SEQUENCE_TYPE_INDEP_ONLY);
				}
				for my $ss_type (@subseq_types) {
					my $full_rule_target = ($ss_type eq SEQUENCE_TYPE_BOTH) ? $rules_target : "${rules_target}-${ss_type}";
					if (exists($completed_sequences->{$full_rule_target})) {
						$subtarget_status{$ss_type} = 'complete';
						last if $ss_type eq $subseq_type;
					}
					elsif (defined(rules_explicit_target($full_rule_target))) {
						$subtarget_status{$ss_type} = 'opaque';
						last if $ss_type eq $subseq_type;
					}
					else {
						$subtarget_status{$ss_type} = 'transparent';
					}
				}
				# At this point, %subtarget_status has 1 or 3 kv-pairs.
				# - If it has 1, then just check that and be done
				# - If it has 3, then "both" must be "transparent".

				if (scalar(keys(%subtarget_status)) == 3) {
					if ($subtarget_status{${\SEQUENCE_TYPE_ARCH_ONLY}} eq $subtarget_status{${\SEQUENCE_TYPE_INDEP_ONLY}}) {
						# The "both" target is transparent and the subtargets agree.  This is the common case
						# of "everything is transparent" (or both subtargets are opaque) and we reduce that by
						# reducing it to only have one key.
						%subtarget_status = ( $subseq_type => $subtarget_status{${\SEQUENCE_TYPE_ARCH_ONLY}} );
						# There is one special-case for this flow if both targets are opaque.
						$subtarget_decided_both = 1;
					} else {
						# The subtargets have different status but we know that the "both" key must be irrelevant
						# then.  Remove it to simplify matters below.
						delete($subtarget_status{${\SEQUENCE_TYPE_BOTH}});
					}
				}

				if (scalar(keys(%subtarget_status)) == 1) {
					# "Simple" case where we only have to check exactly one result
					if ($subtarget_status{$subseq_type} eq 'opaque') {
						$opaque_subseq = $subseq_type;
					}
					elsif ($subtarget_status{$subseq_type} eq 'transparent') {
						$transparent_subseq = $subseq_type;
					}
				} else {
					# Either can be transparent, opaque or complete at this point.
					if ($subtarget_status{${\SEQUENCE_TYPE_ARCH_ONLY}} eq 'transparent') {
						$transparent_subseq = SEQUENCE_TYPE_ARCH_ONLY
					} elsif ($subtarget_status{${\SEQUENCE_TYPE_INDEP_ONLY}}  eq 'transparent') {
						$transparent_subseq = SEQUENCE_TYPE_INDEP_ONLY
					}
					if ($subtarget_status{${\SEQUENCE_TYPE_ARCH_ONLY}} eq 'opaque') {
						$opaque_subseq = SEQUENCE_TYPE_ARCH_ONLY
					} elsif ($subtarget_status{${\SEQUENCE_TYPE_INDEP_ONLY}}  eq 'opaque') {
						$opaque_subseq = SEQUENCE_TYPE_INDEP_ONLY
					}
				}
				if ($opaque_subseq) {
					if ($subtarget_decided_both) {
						# Final special-case - we are here because the rules file define X-arch AND X-indep but
						# not X.  In this case, we want two d/rules X-{arch,indep} calls rather than a single
						# d/rules X call.
						for my $ss_type ((SEQUENCE_TYPE_ARCH_ONLY, SEQUENCE_TYPE_INDEP_ONLY)) {
							my $rules_target_cmd = $subsequence->as_rules_target_command($ss_type);
							push(@targets, $rules_target_cmd) if not $seen{$rules_target_cmd}++;
						}
					} else {
						my $rules_target_cmd = $subsequence->as_rules_target_command($opaque_subseq);
						push(@targets, $rules_target_cmd) if not $seen{$rules_target_cmd}++;
					}
				}
				if ($transparent_subseq) {
					push(@stack, $current_sequence);
					$current_sequence = [$subsequence->flatten_sequence($transparent_subseq)];
				}
				next COMMAND;
			} else {
				if (defined($rules_target) and not $always_inline) {
					next COMMAND if exists($non_inlineable_targets{$rules_target});
					push(@targets, $command) if not $seen{$command}++;
				} elsif (! $seen{$command}) {
					$seen{$command} = 1;
					push(@sequence, $command);
				}
			}
		}
	}
	return (\@targets, \@sequence);
}


sub rules_explicit_target {
	# Checks if a specified target exists as an explicit target
	# in debian/rules.
	# undef is returned if target does not exist, 0 if target is noop
	# and 1 if target has dependencies or executes commands.
	my ($target) = @_;

	if (! $RULES_PARSED) {
		my $processing_targets = 0;
		my $not_a_target = 0;
		my $current_target;
		open(MAKE, "LC_ALL=C make -Rrnpsf debian/rules ${\DUMMY_TARGET} 2>/dev/null |");
		while (<MAKE>) {
			if ($processing_targets) {
				if (/^# Not a target:/) {
					$not_a_target = 1;
				} else {
					if (!$not_a_target && m/^([^#:]+)::?\s*(.*)$/) {
						# Target is defined. NOTE: if it is a dependency of
						# .PHONY it will be defined too but that's ok.
						# $2 contains target dependencies if any.
						$current_target = $1;
						$EXPLICIT_TARGETS{$current_target} = ($2) ? 1 : 0;
					} else {
						if (defined($current_target)) {
							if (m/^#/) {
								# Check if target has commands to execute
								if (m/^#\s*(commands|recipe) to execute/) {
									$EXPLICIT_TARGETS{$current_target} = 1;
								}
							} else {
								# Target parsed.
								$current_target = undef;
							}
						}
					}
					# "Not a target:" is always followed by
					# a target name, so resetting this one
					# here is safe.
					$not_a_target = 0;
				}
			} elsif (m/^# Files$/) {
				$processing_targets = 1;
			}
		}
		close MAKE;
		$RULES_PARSED = 1;
	}

	return $EXPLICIT_TARGETS{$target};
}

sub extract_skipinfo {
	my ($command) = @_;

	foreach my $dir (split(':', $ENV{PATH})) {
		if (open (my $h, "<", "$dir/$command")) {
			while (<$h>) {
				if (m/PROMISE: DH NOOP( WITHOUT\s+(.*))?\s*$/) {
					close $h;
					return split(' ', $2) if defined($2);
					return ('always-skip');
				}
			}
			close $h;
			return;
		}
	}
	return;
}


1;
