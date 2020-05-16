#!/usr/bin/perl
#
# Internal library functions for the dh(1) command

package Debian::Debhelper::SequencerUtil;
use strict;
use warnings;
use constant {
	'DUMMY_TARGET'                             => 'debhelper-fail-me',
	'SEQUENCE_NO_SUBSEQUENCES'                 => 'none',
	'SEQUENCE_ARCH_INDEP_SUBSEQUENCES'         => 'both',
	'SEQUENCE_TYPE_ARCH_ONLY'                  => 'arch',
	'SEQUENCE_TYPE_INDEP_ONLY'                 => 'indep',
	'SEQUENCE_TYPE_BOTH'                       => 'both',
	'FLAG_OPT_SOURCE_BUILDS_NO_ARCH_PACKAGES'  => 0x1,
	'FLAG_OPT_SOURCE_BUILDS_NO_INDEP_PACKAGES' => 0x2,
	'UNSKIPPABLE_CLI_OPTIONS_BUILD_SYSTEM' => q(-S|--buildsystem|-D|--sourcedir|--sourcedirectory|-B|--builddir|--builddirectory),
};

use Exporter qw(import);

use Debian::Debhelper::Dh_Lib qw(
	%dh
	basename
	commit_override_log
	compat error
	escape_shell
	get_buildoption
	getpackages
	load_log
	package_is_arch_all
    pkgfile
	rm_files
	tmpdir
	warning
	write_log
);


our @EXPORT = qw(
	extract_rules_target_name
	to_rules_target
	sequence_type
	unpack_sequence
	rules_explicit_target
	extract_skipinfo
	compute_selected_addons
	load_sequence_addon
	run_sequence_command_and_exit_on_failure
	should_skip_due_to_dpo
	check_for_obsolete_commands
	compute_starting_point_in_sequences
	parse_dh_cmd_options
	run_hook_target
	run_through_command_sequence
	DUMMY_TARGET
	SEQUENCE_NO_SUBSEQUENCES
	SEQUENCE_ARCH_INDEP_SUBSEQUENCES
	SEQUENCE_TYPE_ARCH_ONLY
	SEQUENCE_TYPE_INDEP_ONLY
	SEQUENCE_TYPE_BOTH
	FLAG_OPT_SOURCE_BUILDS_NO_ARCH_PACKAGES
	FLAG_OPT_SOURCE_BUILDS_NO_INDEP_PACKAGES
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
	} elsif ($sequence_name =~ m/-arch$/) {
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
	my ($sequences, $sequence_name, $always_inline, $completed_sequences, $flags) = @_;
	my (@sequence, @targets, %seen, %non_inlineable_targets, @stack);
	my $sequence_type = sequence_type($sequence_name);
	# Walk through the sequence effectively doing a DFS of the rules targets
	# (when we are allowed to inline them).
	my $seq = $sequences->{$sequence_name};
	$flags //= 0;

	push(@stack, [$seq->flatten_sequence($sequence_type, $flags)]);
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
				$current_sequence = [$subsequence->flatten_sequence($subseq_type, $flags)];
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
					$current_sequence = [$subsequence->flatten_sequence($transparent_subseq, $flags)];
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

sub _skipped_call_due_dpo {
	my ($command, $dbo_flag) = @_;
	my $me = Debian::Debhelper::Dh_Lib::_color(basename($0), 'bold');
	my $skipped = Debian::Debhelper::Dh_Lib::_color('command-omitted', 'yellow');
	print "${me}: ${skipped}: The call to \"${command}\" was omitted due to \"DEB_BUILD_OPTIONS=${dbo_flag}\"\n";
	return;
}

sub should_skip_due_to_dpo {
	my ($command, $to_be_invoked) = @_;

	# Indirection/reference for readability
	my $commands_ref = \%Debian::Debhelper::DH::SequenceState::commands_skippable_via_deb_build_options;

	if (not $dh{'NO_ACT'} and exists($commands_ref->{$command})) {
		my $flags_ref = $commands_ref->{$command};
		for my $flag (@{$flags_ref}) {
			if (get_buildoption($flag)) {
				_skipped_call_due_dpo($to_be_invoked, $flag) if defined($to_be_invoked);
				return 1;
			}
		}
	}
	return 0;
}

sub compute_starting_point_in_sequences {
	my ($packages_ref, $full_sequence, $logged) = @_;
	my %startpoint;
	if (compat(9)) {
		foreach my $package (@{$packages_ref}) {
			my @log = load_log($package, $logged);
			# Find the last logged command that is in the sequence, and
			# continue with the next command after it. If no logged
			# command is in the sequence, we're starting at the beginning..
			$startpoint{$package} = 0;
			COMMAND:
			foreach my $command (reverse(@log)) {
				foreach my $i (0 .. $#{$full_sequence}) {
					if ($command eq $full_sequence->[$i]) {
						$startpoint{$package} = $i + 1;
						last COMMAND;
					}
				}
			}
		}
	} else {
		foreach my $package (@{$packages_ref}) {
			$startpoint{$package} = 0;
		}
	}
	return %startpoint;
}


sub compute_selected_addons {
	my ($sequence_name, @addon_requests_from_args) = @_;
	my (@enabled_addons, %disabled_addons, %enabled);
	my @addon_requests;
	my $sequence_type = sequence_type($sequence_name);

	my %addon_constraints = %{ Debian::Debhelper::Dh_Lib::bd_dh_sequences() };

	# Inject elf-tools early as other addons rely on their presence and it historically
	# has been considered a part of the "core" sequence.
	if (exists($addon_constraints{'elf-tools'})) {
		# Explicitly requested; respect that
		push(@addon_requests, '+elf-tools');
	} elsif (compat(12, 1)) {
		# In compat 12 and earlier, we only inject the sequence if there are arch
		# packages present and the sequence requires it.
		if (getpackages('arch') and $sequence_type ne SEQUENCE_TYPE_INDEP_ONLY) {
			push(@addon_requests, '+elf-tools');
		}
	} else {
		# In compat 13, we always inject the addon if not explicitly requested and
		# then flag it as arch_only
		push(@addon_requests, '+elf-tools');
		$addon_constraints{'elf-tools'} = SEQUENCE_TYPE_ARCH_ONLY if not exists($addon_constraints{'elf-tools'});
	}

	# Order is important; DH_EXTRA_ADDONS must come before everything
	# else; then comes built-in and finally argument provided add-ons
	# requests.
	push(@addon_requests,  map { "+${_}" } split(",", $ENV{DH_EXTRA_ADDONS}))
		if $ENV{DH_EXTRA_ADDONS};
	if (not compat(9, 1)) {
		# Enable autoreconf'ing by default in compat 10 or later.
		push(@addon_requests, '+autoreconf');

		# Enable systemd support by default in compat 10 or later.
		# - compat 11 injects the dh_installsystemd tool directly in the
		#   sequence instead of using a --with sequence.
		push(@addon_requests, '+systemd') if compat(10, 1);
		push(@addon_requests, '+build-stamp');
	}
	for my $addon_name (sort(keys(%addon_constraints))) {
		my $addon_type = $addon_constraints{$addon_name};

		# Special-case for the "clean" target to avoid B-D-I dependencies in that for conditional add-ons
		next if $sequence_name eq 'clean' and $addon_type ne SEQUENCE_TYPE_BOTH;
		if ($addon_type eq 'both' or $sequence_type eq 'both' or $addon_type eq $sequence_type) {
			push(@addon_requests, "+${addon_name}");
		}
	}

	push(@addon_requests, @addon_requests_from_args);

	# Removing disabled add-ons are expensive (O(N) per time), so we
	# attempt to make removals in bulk.  Note that we have to be order
	# preserving (due to #885580), so there is a limit to how "smart"
	# we can be.
	my $flush_disable_cache = sub {
		@enabled_addons = grep { not exists($disabled_addons{$_}) } @enabled_addons;
		for my $addon (keys(%disabled_addons)) {
			delete($enabled{$addon});
		}
		%disabled_addons = ();
	};

	for my $request (@addon_requests) {
		if ($request =~ m/^[+-]root[-_]sequence$/) {
			error("Invalid request to skip the sequence \"root-sequence\": It cannot be disabled")
				if $request =~ m/^-/;
			error("Invalid request to load the sequence \"root-sequence\": Do not reference it directly");
		}
		if ($request =~ s/^[+]//) {
			$flush_disable_cache->() if %disabled_addons;
			push(@enabled_addons, $request) if not $enabled{$request}++;
		} elsif ($request =~ s/^-//) {
			$disabled_addons{$request} = 1;
		} else {
			error("Internal error: Invalid add-on request: $request (Missing +/- prefix)");
		}
	}

	$flush_disable_cache->() if %disabled_addons;
	return map {
		{
			'name' => $_,
			'addon-type' => $addon_constraints{$_} // SEQUENCE_TYPE_BOTH,
		}
	} @enabled_addons;
}


sub load_sequence_addon {
	my ($addon_name, $addon_type) = @_;
	require Debian::Debhelper::DH::AddonAPI;
	my $mod="Debian::Debhelper::Sequence::${addon_name}";
	$mod=~s/-/_/g;
	local $Debian::Debhelper::DH::AddonAPI::DH_INTERNAL_ADDON_NAME = $addon_name;
	local $Debian::Debhelper::DH::AddonAPI::DH_INTERNAL_ADDON_TYPE = $addon_type;
	eval "package Debian::Debhelper::DH::AddonAPI; use $mod";
	if ($@) {
		error("unable to load addon ${addon_name}: $@");
	}
}

sub check_for_obsolete_commands {
	my ($full_sequence) = @_;
	my ($found_obsolete_targets);
	for my $command (@{$full_sequence}) {
		if (exists($Debian::Debhelper::DH::SequenceState::obsolete_command{$command})) {
			my $addon_name = $Debian::Debhelper::DH::SequenceState::obsolete_command{$command};
			error("The addon ${addon_name} claimed that $command was obsolete, but it is not!?");
		}
	}
	for my $command (sort(keys(%Debian::Debhelper::DH::SequenceState::obsolete_command))) {
		for my $prefix (qw(execute_before_ execute_after_ override_)) {
			for my $suffix ('', '-arch', '-indep') {
				my $target = "${prefix}${command}${suffix}";
				if (defined(rules_explicit_target($target))) {
					$found_obsolete_targets = 1;
					warning("The target ${target} references a now obsolete command and will not be run!");
				}
			}
		}
	}
	if ($found_obsolete_targets and not compat(12)) {
		error("Aborting due to left over override/hook targets for now removed commands.");
	}
	return;
}

sub run_sequence_command_and_exit_on_failure {
	my ($command, @options) = @_;

	# 3 space indent lines the command being run up under the
	# sequence name after "dh ".
	if (!$dh{QUIET}) {
		print "   ".escape_shell($command, @options)."\n";
	}

	return if $dh{NO_ACT};

	my $ret=system { $command } $command, @options;
	if ($ret >> 8 != 0) {
		exit $ret >> 8;
	}
	if ($ret) {
		exit 1;
	}
	return;
}


sub run_hook_target {
	my ($target_stem, $min_compat_level, $command, $packages, @opts) = @_;
	my @todo = @{$packages};
	foreach my $override_type (undef, "arch", "indep") {
		@todo = _run_injected_rules_target($target_stem, $override_type, $min_compat_level, $command, \@todo, @opts);
	}
	return @todo;
}

# Tries to run an override / hook target for a command. Returns the list of
# packages that it was unable to run the target for.
sub _run_injected_rules_target {
	my ($target_stem, $override_type, $min_compat_level, $command, $packages, @options) = @_;

	my $rules_target = $target_stem .
		(defined $override_type ? "-".$override_type : "");

	$command //= $rules_target;  # Ensure it is defined

	# Check which packages are of the right architecture for the
	# override_type.
	my (@todo, @rest);
	my $has_explicit_target = rules_explicit_target($rules_target);

	if ($has_explicit_target and defined($min_compat_level) and compat($min_compat_level - 1)) {
		error("Hook target ${rules_target} is only supported in compat ${min_compat_level} or later");
	}

	if (defined $override_type) {
		foreach my $package (@{$packages}) {
			my $isall=package_is_arch_all($package);
			if (($override_type eq 'indep' && $isall) ||
				($override_type eq 'arch' && !$isall)) {
				push @todo, $package;
			} else {
				push @rest, $package;
				push @options, "-N$package";
			}
		}
	} else {
		@todo=@{$packages};
	}

	return @{$packages} unless defined $has_explicit_target; # no such override
	return @rest if ! $has_explicit_target; # has empty override
	return @rest unless @todo; # has override, but no packages to act on
	return @rest if should_skip_due_to_dpo($command, "debian/rules $rules_target");

	if (defined $override_type) {
		# Ensure appropriate -a or -i option is passed when running
		# an arch-specific override target.
		my $opt=$override_type eq "arch" ? "-a" : "-i";
		push @options, $opt unless grep { $_ eq $opt } @options;
	}

	# Discard any override log files before calling the override
	# target
	if (not compat(9)) {
		my @files = glob('debian/*.debhelper.log');
		rm_files(@files) if @files;
	}
	# This passes the options through to commands called
	# inside the target.
	$ENV{DH_INTERNAL_OPTIONS}=join("\x1e", @options);
	$ENV{DH_INTERNAL_OVERRIDE}=$command;
	run_sequence_command_and_exit_on_failure("debian/rules", $rules_target);
	delete $ENV{DH_INTERNAL_OPTIONS};
	delete $ENV{DH_INTERNAL_OVERRIDE};

	# Update log for overridden command now that it has
	# finished successfully.
	# (But avoid logging for dh_clean since it removes
	# the log earlier.)
	if (! $dh{NO_ACT} && $command ne 'dh_clean' && compat(9)) {
		write_log($command, @todo);
		commit_override_log(@todo);
	}

	# Override targets may introduce new helper files.  Strictly
	# speaking this *shouldn't* be necessary, but lets make no
	# assumptions.
	Debian::Debhelper::Dh_Lib::dh_clear_unsafe_cache();

	return @rest;
}


# Options parsed to dh that may need to be passed on to helpers
sub parse_dh_cmd_options {
	my (@argv) = @_;

	# Ref for readability
	my $options_ref = \@Debian::Debhelper::DH::SequenceState::options;

	while (@argv) {
		my $opt = shift(@argv);
		if ($opt =~ /^--?(after|until|before|with|without)$/) {
			shift(@argv);
			next;
		} elsif ($opt =~ /^--?(no-act|remaining|(after|until|before|with|without)=)/) {
			next;
		} elsif ($opt =~ /^-/) {
			if (not @{$options_ref} and $opt eq '--parallel' or $opt eq '--no-parallel') {
				my $max_parallel;
				# Ignore the option if it is the default for the given
				# compat level.
				next if compat(9) and $opt eq '--no-parallel';
				next if not compat(9) and $opt eq '--parallel';
				# Having an non-empty "@options" hurts performance quite a
				# bit.  At the same time, we want to promote the use of
				# --(no-)parallel, so "tweak" the options a bit if there
				# is no reason to include this option.
				$max_parallel = get_buildoption('parallel') // 1;
				next if $max_parallel == 1;
			}
			if ($opt =~ m/^(--[^=]++)(?:=.*)?$/ or $opt =~ m/^(-[^-])(?:=.*)?$/) {
				my $optname = $1;
				if (length($optname) > 2 and (compat(12, 1) or $optname =~ m/^-[^-][^=]/)) {
					# We cannot optimize bundled options but we can optimize a single
					# short option with an explicit parameter (-B=F is ok, -BF is not)
					# In compat 12 or earlier, we also punt on long options due to
					# auto-abbreviation.
					$Debian::Debhelper::DH::SequenceState::unoptimizable_option_bundle = 1
				}
				$Debian::Debhelper::DH::SequenceState::seen_options{$optname} = 1;
			} elsif ($opt =~ m/^-[^-][^-]/) {
				# We cannot optimize bundled options but we can optimize a single
				# short option with an explicit parameter (-B=F is ok, -BF is not)
				$Debian::Debhelper::DH::SequenceState::unoptimizable_option_bundle = 1
			} else {
				# Special case that disables NOOP cli-options() as well
				$Debian::Debhelper::DH::SequenceState::unoptimizable_user_option = 1;
			}
			push(@{$options_ref}, "-O" . $opt);
		} elsif (@{$options_ref}) {
			if ($options_ref->[$#{$options_ref}] =~ /^-O--/) {
				$options_ref->[$#{$options_ref}] .= '=' . $opt;
			} else {
				# Special case that disables NOOP cli-options() as well
				$Debian::Debhelper::DH::SequenceState::unoptimizable_user_option = 1;
				$options_ref->[$#{$options_ref}] .= $opt;
			}
		} else {
			error("Unknown parameter: $opt");
		}
	}
	return;
}


sub run_through_command_sequence {
	my ($full_sequence, $startpoint, $logged, $options, $all_packages, $arch_packages, $indep_packages) = @_;

	my $command_opts = \%Debian::Debhelper::DH::SequenceState::command_opts;
	my $stoppoint = $#{$full_sequence};

	# Now run the commands in the sequence.
	foreach my $i (0 .. $stoppoint) {
		my $command = $full_sequence->[$i];

		# Figure out which packages need to run this command.
		my (@todo, @opts);
		my @filtered_packages = _active_packages_for_command($command, $all_packages, $arch_packages, $indep_packages);

		foreach my $package (@filtered_packages) {
			if (($startpoint->{$package}//0) > $i ||
				$logged->{$package}{$full_sequence->[$i]}) {
				push(@opts, "-N$package");
			}
			else {
				push(@todo, $package);
			}
		}
		next unless @todo;
		push(@opts, @{$options});

		my $rules_target = extract_rules_target_name($command);
		error("Internal error: $command is a rules target, but it is not supported to be!?") if defined($rules_target);

		if (my $stamp_file = _stamp_target($command)) {
			my %seen;
			print "   create-stamp " . escape_shell($stamp_file) . "\n";

			next if $dh{NO_ACT};
			open(my $fd, '+>>', $stamp_file) or error("open($stamp_file, rw) failed: $!");
			# Seek to the beginning
			seek($fd, 0, 0) or error("seek($stamp_file) failed: $!");
			while (my $line = <$fd>) {
				chomp($line);
				$seen{$line} = 1;
			}
			for my $pkg (grep {not exists($seen{$_})} @todo) {
				print {$fd} "$pkg\n";
			}
			close($fd) or error("close($stamp_file) failed: $!");
			next;
		}

		my @full_todo = @todo;
		run_hook_target("execute_before_${command}", 10, $command, \@full_todo, @opts);

		# Check for override targets in debian/rules, and run instead of
		# the usual command. (The non-arch-specific override is tried first,
		# for simplest semantics; mixing it with arch-specific overrides
		# makes little sense.)
		@todo = run_hook_target("override_${command}", undef, $command, \@full_todo, @opts);

		if (@todo and not _can_skip_command($command, @todo)) {
			# No need to run the command for any packages handled by the
			# override targets.
			my %todo = map {$_ => 1} @todo;
			foreach my $package (@full_todo) {
				if (!$todo{$package}) {
					push @opts, "-N$package";
				}
			}
			if (not should_skip_due_to_dpo($command, Debian::Debhelper::Dh_Lib::_format_cmdline($command, @opts))) {
				my @cmd_options;
				# Include additional command options if any
				push(@cmd_options, @{$command_opts->{$command}})
					if exists($command_opts->{$command});
				push(@cmd_options, @opts);
				run_sequence_command_and_exit_on_failure($command, @cmd_options);
			}
		}

		run_hook_target("execute_after_${command}", 10, $command, \@full_todo, @opts);
	}
}


sub _stamp_target {
	my ($command) = @_;
	if ($command =~ s/^create-stamp\s+//) {
		return $command;
	}
	return;
}

{
	my %skipinfo;
	sub _can_skip_command {
		my ($command, @packages) = @_;

		return 0 if $dh{NO_ACT} and not $ENV{DH_INTERNAL_TEST_CAN_SKIP};

		return 0 if $Debian::Debhelper::DH::SequenceState::unoptimizable_user_option ||
			(exists $ENV{DH_OPTIONS} && length $ENV{DH_OPTIONS});

		return 0 if exists($Debian::Debhelper::DH::SequenceState::command_opts{$command})
			and @{$Debian::Debhelper::DH::SequenceState::command_opts{$command}};

		if (! defined $skipinfo{$command}) {
			$skipinfo{$command}=[extract_skipinfo($command)];
		}
		my @skipinfo=@{$skipinfo{$command}};
		return 0 unless @skipinfo;
		return 1 if scalar(@skipinfo) == 1 and $skipinfo[0] eq 'always-skip';
		my ($all_pkgs, $had_cli_options);

		foreach my $skipinfo (@skipinfo) {
			my $type = 'pkgfile';
			my $need = $skipinfo;
			if ($skipinfo=~/^([a-zA-Z0-9-_]+)\((.*)\)$/) {
				($type, $need) = ($1, $2);
			}
			if ($type eq 'tmp') {
				foreach my $package (@packages) {
					my $tmp = tmpdir($package);
					return 0 if -e "$tmp/$need";
				}
			} elsif ($type eq 'pkgfile' or $type eq 'pkgfile-logged') {
				my $pkgs;
				if ($type eq 'pkgfile') {
					$pkgs = \@packages;
				} else {
					$all_pkgs //= [ getpackages() ];
					$pkgs = $all_pkgs;
				}
				# Use the secret bulk check call
				return 0 if pkgfile($pkgs, $need) ne '';
			} elsif ($type eq 'cli-options') {
				$had_cli_options = 1;
				# If cli-options is empty, we know the helper does not
				# react to any thing and can always be skipped.
				next if $need =~ m/^\s*$/;
				# Long options are subject to abbreviations so it is
				# very difficult to implement this optimization with
				# long options.
				return 0 if $Debian::Debhelper::DH::SequenceState::unoptimizable_option_bundle;
				$need =~ s/(?:^|\s)BUILDSYSTEM(?:\s|$)/${\UNSKIPPABLE_CLI_OPTIONS_BUILD_SYSTEM}/;
				my @behavior_options = split(qr/\Q|\E/, $need);
				for my $opt (@behavior_options) {
					return 0 if exists($Debian::Debhelper::DH::SequenceState::seen_options{$opt});
				}
			} elsif ($type eq 'buildsystem') {
				require Debian::Debhelper::Dh_Buildsystems;
				my $system = Debian::Debhelper::Dh_Buildsystems::load_buildsystem(undef, $need);
				return 0 if defined($system);
			} elsif ($type eq 'internal') {
				if ($need ne 'bug#950723') {
					warning('Broken internal NOOP hint; should not happen unless someone is using implementation details');
					error("Unknown internal NOOP type hint in ${command}: ${need}");
				}

				$all_pkgs //= [ getpackages() ];
				push(@{$all_pkgs}, map { "${_}@"} getpackages());
				push(@packages, map { "${_}@"} @packages);
			} else {
				# Unknown hint - make no assumptions
				return 0;
			}
		}
		return 0 if not $had_cli_options and %Debian::Debhelper::DH::SequenceState::seen_options;
		return 1;
	}
}

sub _active_packages_for_command {
	my ($command, $all_packages, $arch_packages, $indep_packages) = @_;
	my $command_opts_ref = $Debian::Debhelper::DH::SequenceState::command_opts{$command};
	my $selection = $all_packages;
	if (grep { $_ eq '-i'} @{$command_opts_ref}) {
		if (grep { $_ ne '-a'} @{$command_opts_ref}) {
			$selection = $indep_packages;
		}
	} elsif (grep { $_ eq '-a'} @{$command_opts_ref}) {
		$selection = $arch_packages;
	}
	return @{$selection};
}

1;
