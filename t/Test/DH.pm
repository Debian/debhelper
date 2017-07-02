package Test::DH;

use strict;
use warnings;

use Test::More;

use Cwd qw(cwd realpath);
use Errno qw(EEXIST);
use Exporter qw(import);

use File::Temp qw(tempdir);
use File::Path qw(remove_tree make_path);
use File::Basename qw(dirname);

my $ROOT_DIR;

BEGIN {
    my $res = realpath(__FILE__) or error('Cannot resolve ' . __FILE__ . ": $!");
    $ROOT_DIR = dirname(dirname(dirname($res)));
};

use lib "$ROOT_DIR/lib";

$ENV{PATH} = "$ROOT_DIR:$ENV{PATH}" if $ENV{PATH} !~ m{\Q$ROOT_DIR\E/?:};
$ENV{PERL5LIB} = join(':', "${ROOT_DIR}/lib", (grep { defined } $ENV{PERL5LIB}))
    if not $ENV{PERL5LIB} or $ENV{PERL5LIB} !~ m{\Q$ROOT_DIR\E(?:/lib)?/?:};
$ENV{DH_AUTOSCRIPTDIR} = "$ROOT_DIR/autoscripts";

# Drop DEB_BUILD_PROFILES and DEB_BUILD_OPTIONS so they don't interfere
delete($ENV{DEB_BUILD_PROFILES});
delete($ENV{DEB_BUILD_OPTIONS});

use Debian::Debhelper::Dh_Lib;

our @EXPORT = qw(
    each_compat_up_to_and_incl_subtest each_compat_subtest
    each_compat_from_and_above_subtest run_dh_tool
    uid_0_test_is_ok
);

our ($TEST_DH_COMPAT, $ROOT_OK, $ROOT_CMD);

my $START_DIR = cwd();
my $TEST_DIR;

sub run_dh_tool {
    my (@cmd) = @_;
    my $compat = $TEST_DH_COMPAT;
    my $options = ref($cmd[0]) ? shift(@cmd) : {};
    my $pid;

    if ($options->{'needs_root'}) {
        BAIL_OUT('BROKEN TEST - Attempt to run "needs_root" test when not possible')
            if not uid_0_test_is_ok();
        unshift(@cmd, $ROOT_CMD) if defined($ROOT_CMD);
    }

    $pid = fork() // BAIL_OUT("fork failed: $!");
    if (not $pid) {
        $ENV{DH_COMPAT} = $compat;
        $ENV{DH_INTERNAL_TESTSUITE_SILENT_WARNINGS} = 1;
        if ($options->{quiet}) {
            open(STDOUT, '>', '/dev/null') or error("Reopen stdout: $!");
            open(STDERR, '>', '/dev/null') or error("Reopen stderr: $!");
        } else {
            # If run under prove/TAP, we don't want to confuse the test runner.
            open(STDOUT, '>&', *STDERR) or error("Redirect stdout to stderr: $!");
        }
        exec(@cmd);
    }
    waitpid($pid, 0) == $pid or BAIL_OUT("waitpid($pid) failed: $!");
    return 1 if not $?;
    return 0;
}

sub uid_0_test_is_ok {
    return $ROOT_OK if defined($ROOT_OK);
    my $ok = 0;
    if ($< == 0) {
        $ok = 1;
    } else {
        system('fakeroot true 2>/dev/null');
        if ($? == 0) {
            $ROOT_CMD = 'fakeroot';
            $ok = 1;
        }
    }
    $ROOT_OK = $ok;
    return $ok;
}

sub _prepare_test_root {
    my $dir = tempdir(CLEANUP => 1);
    if (not mkdir("$dir/debian", 0777)) {
        error("mkdir $dir/debian failed: $!")
            if $! != EEXIST;
    } else {
        # auto seed it
        my @files = qw(
            debian/control
            debian/compat
            debian/changelog
        );
        for my $file (@files) {
            install_file($file, "${dir}/${file}");
        }
        if (@::TEST_DH_EXTRA_TEMPLATE_FILES) {
            my $test_dir = ($TEST_DIR //= dirname($0));
            for my $file (@::TEST_DH_EXTRA_TEMPLATE_FILES) {
                my $install_dir = dirname($file);
                install_dir($install_dir);
                install_file("${test_dir}/${file}", "${dir}/${file}");
            }
        }
    }
    return $dir;
}

sub each_compat_up_to_and_incl_subtest($&) {
    my ($compat, $code) = @_;
    my $low = Debian::Debhelper::Dh_Lib::MIN_COMPAT_LEVEL;
    error("compat $compat is no longer support! Min compat $low")
        if $compat < $low;
    subtest '' => sub {
        # Keep $dir alive until the test is over
        my $dir = _prepare_test_root;
        chdir($dir) or error("chdir($dir): $!");
        while ($low <= $compat) {
            local $TEST_DH_COMPAT = $compat;
            $code->($low);
            ++$low;
        }
        chdir($START_DIR) or error("chdir($START_DIR): $!");
    };
    return;
}

sub each_compat_from_and_above_subtest($&) {
    my ($compat, $code) = @_;
    my $lowest = Debian::Debhelper::Dh_Lib::MIN_COMPAT_LEVEL;
    my $end = Debian::Debhelper::Dh_Lib::MAX_COMPAT_LEVEL;
    if ($lowest > $compat) {
        diag("Bumping $compat to $lowest ($compat is no longer supported)");
        $compat = $lowest;
    }
    error("$compat is from the future! Max known is $end")
        if $compat > $end;
    subtest '' => sub {
        # Keep $dir alive until the test is over
        my $dir = _prepare_test_root;
        chdir($dir) or error("chdir($dir): $!");
        while ($compat <= $end) {
            local $TEST_DH_COMPAT = $compat;
            $code->($compat);
            ++$compat;
        }
        chdir($START_DIR) or error("chdir($START_DIR): $!");
    };
    return;
}

sub each_compat_subtest(&) {
    unshift(@_, Debian::Debhelper::Dh_Lib::MIN_COMPAT_LEVEL);
    goto \&each_compat_from_and_above_subtest;
}

1;
