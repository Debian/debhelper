package Debian::Debhelper::Buildsystem::qmake_qt4;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(error);
use parent qw(Debian::Debhelper::Buildsystem::qmake);

sub DESCRIPTION {
	"qmake for QT 4 (*.pro)";
}

sub configure {
	my $this=shift;
	$Debian::Debhelper::Buildsystem::qmake::qmake="qmake-qt4";
	$this->SUPER::configure(@_);
}

1

# Local Variables:
# indent-tabs-mode: t
# tab-width: 4
# cperl-indent-level: 4
# End:
