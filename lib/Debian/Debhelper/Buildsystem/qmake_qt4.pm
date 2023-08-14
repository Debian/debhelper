package Debian::Debhelper::Buildsystem::qmake_qt4;

use strict;
use warnings;
use parent qw(Debian::Debhelper::Buildsystem::qmake);

sub DESCRIPTION {
	"qmake for QT 4 (*.pro)";
}

sub _qmake {
	return 'qmake-qt4';
}

1
