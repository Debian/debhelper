use strict;
use warnings;

use Debian::Debhelper::Dh_Lib qw(getpackages error warning tmpdir);
use Debian::Debhelper::SequencerUtil;

my @packages = getpackages();
my $pkg = $packages[0];
my $tmp = tmpdir($pkg);
if (@packages != 1) {
    warning('Detected multiple binary packages (Package paragraphs) in debian/control, which is incompatible');
    warning('with the single-binary dh add-on.');
    warning();
    warning('Please:');
    warning(' 1) Remove the single-binary add-on ("dh-sequence-single-binary" in Build-Depends)');
    warning(' 2) Update the packaging to cope with dh_auto_install using \"debian/tmp\" as default dest dir');
    warning("    (Previously, it would probably have used \"${tmp}\")");
    warning(' 3) Add Breaks/Replaces if you are moving existing files into a new package.');
    warning(' 4) Double check that the resulting binaries have content.');
    warning();
    warning("IF YOU ARE ADDING A TRANSITIONAL PACKAGE: Then you probably want to pass --destdir=${tmp} to");
    warning('  dh_auto_install.  Most likely you will need Breaks + Replaces as renaming a package counts as');
    warning('  moving files between two packages.');
    warning();
    warning('IF YOU ARE "SPLITTING" THE CONTENT INTO MULTIPLE PACKAGES: Then remember to install the content');
    warning("  into them (by creating debian/${pkg}.install, etc.).  Also remember to add Breaks + Replaces if");
    warning('  you are moving files from one package into another.');
    warning();
    error("The single-binary add-on cannot be used for source packages that build multiple binary packages.");
}

add_command_options('dh_auto_install', "--destdir=${tmp}/");

1;
