package Debian::Debhelper::Buildsystem::qmake_qt4;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(error);
use base 'Debian::Debhelper::Buildsystem::qmake';

$Debian::Debhelper::Buildsystem::qmake::qmake="qmake-qt4";

sub DESCRIPTION {
	"qmake for QT 4 (*.pro)";
}

1
