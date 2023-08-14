#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(locale_h);
use Test::More;
use Time::Piece;
use Time::Seconds qw(ONE_MONTH ONE_YEAR);

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;

use constant TEST_DIR => dirname($0);
our @TEST_DH_EXTRA_TEMPLATE_FILES = (qw(
    debian/changelog
    debian/control
));

# Force Time::Piece to generate dch-compliant timestamps (i.e. in English).
setlocale(LC_ALL, "C.UTF-8");

use constant CUTOFF_DATE_STR => "2019-07-06"; # oldstable = Debian 10 Buster
use constant CUTOFF_DATE => Time::Piece->strptime(CUTOFF_DATE_STR, "%Y-%m-%d");
use constant MIN_NUM_ENTRIES => 4;

sub install_changelog {
	my ($latest_offset_years, $num_years, $is_binnmu) = @_;
	$is_binnmu //= 0;

	my $entry_date_first = CUTOFF_DATE->add_years($latest_offset_years);
	my $entry_date_stop = $entry_date_first->add_years(-$num_years);

	my $changelog = "${\TEST_DIR}/debian/changelog";

	open(my $fd, ">", $changelog) or error("open($changelog): $!");

	if ($is_binnmu) {
		my $nmu_date = $entry_date_first->add_months(-1);
		my $nmu_entry = entry_text($nmu_date, 1);
		print($fd $nmu_entry);
	}

	# Add one entry every three months ~= four per year.
	my $entry_date = $entry_date_first;
	while ($entry_date > $entry_date_stop) {
		my $entry = entry_text($entry_date, 0);
		print($fd $entry);

		$entry_date = $entry_date->add_months(-3);
	}
	close($fd);
}

sub entry_text {
	my ($entry_date, $is_binnmu) = @_;
	my $entry_date_str = $entry_date->strftime("%a, %d %b %Y %T %z");
	my $ver = $entry_date->year . "." . $entry_date->mon . "-1";
	my $binnmu_text = "";

	if ($is_binnmu) {
		$binnmu_text = " binary-only=yes";
		$ver .= "+b1";
	}

	my $entry = "";
	$entry .= "foo ($ver) unstable; urgency=low$binnmu_text\n\n";
	$entry .= "  * New release.\n\n";
	$entry .= " -- Test <testing\@nowhere>  $entry_date_str\n\n";

	return $entry;
}

sub changelog_lines_pkg {
	return changelog_lines("debian/changelog");
}
sub changelog_lines_installed {
	return changelog_lines("debian/foo/usr/share/doc/foo/changelog.Debian");
}
sub changelog_lines_binnmu {
	return changelog_lines("debian/foo/usr/share/doc/foo/changelog.Debian.all");
}
sub changelog_lines {
	my ($changelog) = @_;
	open(my $fd, $changelog) or error("open($changelog): $!");
	my @lines = @{readlines($fd)};
	@lines = grep(!/^$/, @lines);
	return @lines;
}

sub dates_in_lines {
	my @lines = @_;
	my @lines_dates = grep(/^ -- /, @lines);
	@lines_dates = map { (my $l = $_) =~ s/^\s*--\s+.*?\s+<[^>]*>\s+[A-Za-z]+, +//; $l }  @lines_dates;
	@lines_dates = map { Time::Piece->strptime($_, "%d %b %Y %T %z") }  @lines_dates;
	return @lines_dates;
}

plan(tests => 8);

# Test changelog with only recent entries (< oldstable)
my $years_after_cutoff = 2;
my $years_of_changelog = 2;
install_changelog($years_after_cutoff, $years_of_changelog);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	ok(run_dh_tool("dh_installchangelogs"));
	my @lines = changelog_lines_installed();
	my @comments = grep(/^#/, @lines);

	is(@lines, @lines_orig);
	is(@comments, 0);
};

# Test changelog with both recent and old entries
$years_after_cutoff = 1;
$years_of_changelog = 4;
install_changelog($years_after_cutoff, $years_of_changelog);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	ok(run_dh_tool("dh_installchangelogs"));
	my @lines = changelog_lines_installed();
	my @entries = dates_in_lines(@lines);
	my @entries_old = grep { $_ < CUTOFF_DATE } @entries;
	my @comments = grep(/^#/, @lines);

	cmp_ok(@lines, "<", @lines_orig);
	cmp_ok(@entries, ">", 1);
	is(@entries_old, 0);
	cmp_ok(@comments, ">=", 1);
};

# Test changelog with only old entries
$years_after_cutoff = -1;
$years_of_changelog = 2;
install_changelog($years_after_cutoff, $years_of_changelog);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	ok(run_dh_tool("dh_installchangelogs"));
	my @lines = changelog_lines_installed();
	my @entries = dates_in_lines(@lines);
	my @entries_old = grep { $_ < CUTOFF_DATE } @entries;
	my @comments = grep(/^#/, @lines);

	cmp_ok(@lines, "<", @lines_orig);
	is(@entries, MIN_NUM_ENTRIES);
	is(@entries_old, MIN_NUM_ENTRIES);
	cmp_ok(@comments, ">=", 1);
};

# Test changelog with only recent entries (< oldstable) + binNUM
$years_after_cutoff = 2;
$years_of_changelog = 2;
install_changelog($years_after_cutoff, $years_of_changelog, 1);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	my @entries_orig = dates_in_lines(@lines_orig);
	ok(run_dh_tool("dh_installchangelogs"));
	my @lines = changelog_lines_installed();
	my @entries = dates_in_lines(@lines);
	my @entries_nmu = dates_in_lines(changelog_lines_binnmu());
	my @comments = grep(/^#/, @lines);

	is(@entries, @entries_orig-1);
	is($entries[0], $entries_orig[1]);
	is(@comments, 0);

	is(@entries_nmu, 1);
};

# Test changelog with both recent and old entries + binNMU
$years_after_cutoff = 1;
$years_of_changelog = 4;
install_changelog($years_after_cutoff, $years_of_changelog, 1);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	my @entries_orig = dates_in_lines(@lines_orig);
	ok(run_dh_tool("dh_installchangelogs"));
	my @lines = changelog_lines_installed();
	my @entries = dates_in_lines(@lines);
	my @entries_old = grep { $_ < CUTOFF_DATE } @entries;
	my @entries_nmu = dates_in_lines(changelog_lines_binnmu());
	my @comments = grep(/^#/, @lines);

	cmp_ok(@entries, "<", @entries_orig-1);
	is($entries[0], $entries_orig[1]);
	is(@entries_old, 0);
	cmp_ok(@comments, ">=", 1);

	is(@entries_nmu, 1);
};

# Test changelog with only old entries + binNMU
$years_after_cutoff = -1;
$years_of_changelog = 2;
install_changelog($years_after_cutoff, $years_of_changelog, 1);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	my @entries_orig = dates_in_lines(@lines_orig);
	ok(run_dh_tool("dh_installchangelogs"));
	my @lines = changelog_lines_installed();
	my @entries = dates_in_lines(@lines);
	my @entries_old = grep { $_ < CUTOFF_DATE } @entries;
	my @entries_nmu = dates_in_lines(changelog_lines_binnmu());
	my @comments = grep(/^#/, @lines);

	is(@entries, MIN_NUM_ENTRIES);
	is($entries[0], $entries_orig[1]);
	is(@entries_old, MIN_NUM_ENTRIES);
	cmp_ok(@comments, ">=", 1);

	is(@entries_nmu, 1);
};

# Test changelog with both recent and old entries + --no-trim
$years_after_cutoff = 1;
$years_of_changelog = 4;
install_changelog($years_after_cutoff, $years_of_changelog);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	ok(run_dh_tool("dh_installchangelogs", "--no-trim"));
	my @lines = changelog_lines_installed();
	my @entries = dates_in_lines(@lines);
	my @entries_old = grep { $_ < CUTOFF_DATE } @entries;
	my @comments = grep(/^#/, @lines);

	is(@lines, @lines_orig);
	cmp_ok(@entries, ">", 1);
	cmp_ok(@entries_old, ">", 1);
	is(@comments, 0);
};

# Test changelog with both recent and old entries + notrimdch
$years_after_cutoff = 1;
$years_of_changelog = 4;
install_changelog($years_after_cutoff, $years_of_changelog);
each_compat_subtest {
	my @lines_orig = changelog_lines_pkg();
	$ENV{DEB_BUILD_OPTIONS} = "notrimdch";
	ok(run_dh_tool("dh_installchangelogs"));
	my @lines = changelog_lines_installed();
	my @entries = dates_in_lines(@lines);
	my @entries_old = grep { $_ < CUTOFF_DATE } @entries;
	my @comments = grep(/^#/, @lines);

	is(@lines, @lines_orig);
	cmp_ok(@entries, ">", 1);
	cmp_ok(@entries_old, ">", 1);
	is(@comments, 0);
};

unlink("${\TEST_DIR}/debian/changelog");
