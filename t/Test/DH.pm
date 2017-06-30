package Test::DH;

use strict;
use warnings;

use Test::More;

use Exporter qw(import);

use File::Basename qw(dirname);

my $ROOT_DIR;

BEGIN {
    $ROOT_DIR = dirname(dirname(dirname(__FILE__)));
};

use lib "$ROOT_DIR/lib";

$ENV{PATH} = "$ROOT_DIR:$ENV{PATH}" if $ENV{PATH} !~ m{\Q$ROOT_DIR\E/?:};

use Debian::Debhelper::Dh_Lib;

our @EXPORT = qw(
    each_compat_up_to_and_incl_subtest each_compat_subtest
    each_compat_from_and_above_subtest
);

sub each_compat_up_to_and_incl_subtest($&) {
    my ($compat, $code) = @_;
    my $low = Debian::Debhelper::Dh_Lib::MIN_COMPAT_LEVEL;
    error("compat $compat is no longer support! Min compat $low")
        if $compat < $low;
    subtest '' => sub {
        while ($low <= $compat) {
            $code->($low);
            ++$low;
        }
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
        while ($compat <= $end) {
            $code->($compat);
            ++$compat;
        }
    };
    return;
}

sub each_compat_subtest(&) {
    unshift(@_, Debian::Debhelper::Dh_Lib::MIN_COMPAT_LEVEL);
    goto \&each_compat_from_and_above_subtest;
}

1;
