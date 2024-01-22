package Debian::Debhelper::Buildsystem::qmake6;

use strict;
use warnings;
use parent qw(Debian::Debhelper::Buildsystem::qmake);
use Debian::Debhelper::Dh_Lib qw(is_cross_compiling dpkg_architecture_value);

sub DESCRIPTION {
	"qmake for QT 6 (*.pro)";
}

sub _qmake {
	if (is_cross_compiling()) {
		return dpkg_architecture_value("DEB_HOST_GNU_TYPE") . '-qmake6';
	}
	return 'qmake6';
}

1
