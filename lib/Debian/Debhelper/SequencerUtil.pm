#!/usr/bin/perl
#
# Internal library functions for the dh(1) command

package Debian::Debhelper::SequencerUtil;
use strict;
use warnings;
use constant DUMMY_TARGET => 'debhelper-fail-me';

use Exporter qw(import);

our @EXPORT = qw(
	extract_rules_target_name
	to_rules_target
	unpack_sequence
	rules_explicit_target
	extract_skipinfo
	DUMMY_TARGET
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

sub unpack_sequence {
	my ($sequences, $sequence_name, $always_inline, $completed_sequences) = @_;
	my (@sequence, @targets, %seen, %non_inlineable_targets, @stack);
	# Walk through the sequence effectively doing a DFS of the rules targets
	# (when we are allowed to inline them).
	push(@stack, [@{$sequences->{$sequence_name}}]);
	while (@stack) {
		my $current_sequence = pop(@stack);
	  COMMAND:
		while (@{$current_sequence}) {
			my $command = shift(@{$current_sequence});
			my $rules_target=extract_rules_target_name($command);
			next if (defined($rules_target) and exists($completed_sequences->{$rules_target}));
			if (defined($rules_target) && ($always_inline ||
				! exists($non_inlineable_targets{$rules_target}) &&
				! defined(rules_explicit_target($rules_target)))) {

				# inline the sequence for this implicit target.
				push(@stack, $current_sequence);
				$current_sequence = [@{$sequences->{$rules_target}}];
				next COMMAND;
			} else {
				if (defined($rules_target) and not $always_inline) {
					next COMMAND if exists($non_inlineable_targets{$rules_target});
					my @opaque_targets = ($rules_target);
					while (my $opaque_target = pop(@opaque_targets)) {
						for my $c (@{$sequences->{$opaque_target}}) {
							my $subtarget = extract_rules_target_name($c);
							next if not defined($subtarget);
							next if exists($non_inlineable_targets{$subtarget});
							$non_inlineable_targets{$subtarget} = $rules_target;
						}
					}
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
