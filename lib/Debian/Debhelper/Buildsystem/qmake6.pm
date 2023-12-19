package Debian::Debhelper::Buildsystem::qmake6;

use strict;
use warnings;
use parent qw(Debian::Debhelper::Buildsystem::qmake);

sub DESCRIPTION {
	"qmake for QT 6 (*.pro)";
}

sub _qmake {
	return 'qmake6';
}

1
