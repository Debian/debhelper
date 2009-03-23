# A module for loading and managing debhelper buildsystem plugins.
#
# Copyright: © 2009 Modestas Vainius
# License: GPL-2+

package Debian::Debhelper::Dh_Buildsystems;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib;

use Exporter qw( import );
our @EXPORT_OK = qw( DEFAULT_BUILD_DIRECTORY );

# IMPORTANT: more specific buildsystems should go first
my @BUILDSYSTEMS = (
    "autotools",
    "cmake",
    "perl_build",
    "perl_makefile",
    "python_distutils",
    "makefile",
);

sub DEFAULT_BUILD_DIRECTORY {
	return "obj-" . dpkg_architecture_value("DEB_BUILD_GNU_TYPE");
}

sub new {
	my $cls=shift;
	my %opts=@_;
	my $self = bless({
	    'o_dir' => undef,
	    'o_system' => undef,
	    'loaded_buildsystems' => [] }, $cls);

	if (!exists $opts{noenv}) {
		if (exists $ENV{DH_AUTO_BUILDDIRECTORY}) {
			$self->_set_build_directory_option("env", $ENV{DH_AUTO_BUILDDIRECTORY});
		}
		if (exists $ENV{DH_AUTO_BUILDSYSTEM}) {
			$self->{o_system} = $ENV{DH_AUTO_BUILDSYSTEM};
		}
	}
	return $self;
}

sub get_options {
	my $self=shift;
	my @options=@_;

	my $set_dir = sub { $self->_set_build_directory_option(@_) };
	my $list_bs = sub { $self->list_buildsystems(@_); exit 0 };

	push @options, (
	    "b:s" => $set_dir,
	    "build-directory:s" => $set_dir,
	    "builddirectory:s" => $set_dir,

	    "m=s" => \$self->{o_system},
	    "build-system=s" => \$self->{o_system},
	    "buildsystem=s" => \$self->{o_system},

	    "l" => $list_bs,
	    "--list" => $list_bs,
	);
	my %options = @options;
	return \%options;
}

sub _set_build_directory_option {
	my ($self, $option, $value) = @_;
	if (!$value || $value eq "auto") {
		# Autogenerate build directory name
		$self->{o_dir} = DEFAULT_BUILD_DIRECTORY;
	}
	else {
		$self->{o_dir} = $value;
	}
}

sub _dump_options {
	my $self=shift;
	for my $opt (qw(o_dir o_system)) {
		if (defined $self->{$opt}) {
			print $opt, ": ", $self->{$opt}, "\n";
		}
	}
}

sub _get_buildsystem_module {
	my ($self, $system) = @_;
	my $module = "Debian::Debhelper::Buildsystem::$system";

	if (grep $module, @{$self->{loaded_buildsystems}} == 0) {
		eval "use $module";
		if ($@) {
			error("Unable to load buildsystem '$system': $@");
		}
		push @{$self->{loaded_buildsystems}}, $module;
	}
	return $module;
}

sub load_buildsystem {
	my ($self, $action, $system) = @_;

	if (!defined $system) {
		$system = $self->{o_system};
	}
	if (defined $system) {
		my $module =  $self->_get_buildsystem_module($system);
		verbose_print("Selected buildsystem (specified): ".$module->NAME());
		return $module->new($self->{o_dir});
	}
	else {
		# Try to determine build system automatically
		for $system (@BUILDSYSTEMS) {
			my $module = $self->_get_buildsystem_module($system);
			my $inst = $module->new($self->{o_dir});
			if ($inst->is_buildable($action)) {
				verbose_print("Selected buildsystem (auto): ".$module->NAME());
				return $inst;
			}
		}
	}
	return;
}

sub load_all_buildsystems {
	my $self=shift;
	for my $system (@BUILDSYSTEMS) {
		$self->_get_buildsystem_module($system);
	}
	return @{$self->{loaded_buildsystems}};
}

sub list_buildsystems {
	my $self=shift;
	for my $system ($self->load_all_buildsystems()) {
		printf("%s - %s.\n", $system->NAME(), $system->DESCRIPTION());
	}
}

sub init_dh_auto_tool {
	my $self=shift;

	Debian::Debhelper::Dh_Lib::init(
	    options => $self->get_options(@_));
	$self->{initialized}=1;
}

sub run_dh_auto_tool {
	my $self=shift;
	my $toolname = basename($0);
	my $buildsystem;

	if (!exists $self->{initialized}) {
		$self->init_dh_auto_tool();
	}

	# Guess action from the dh_auto_* name
	$toolname =~ s/^dh_auto_//;
	if (grep(/^\Q$toolname\E$/, qw{configure build test install clean}) == 0) {
		error("Unrecognized dh auto tool: ".basename($0));
	}

	$buildsystem = $self->load_buildsystem($toolname);
	if (defined $buildsystem) {
		return $buildsystem->$toolname(@_, @{$dh{U_PARAMS}});
	}
	return 0;
}

1;
