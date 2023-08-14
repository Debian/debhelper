#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

use File::Basename qw(dirname);
use lib dirname(dirname(__FILE__));
use Test::DH;
use Debian::Debhelper::Dh_Lib qw(!dirname);
use Debian::Debhelper::Buildsystem;

my $BS_CLASS = 'Debian::Debhelper::Buildsystem';


build_system_path_apis();

# Bulk tests
sub build_system_path_apis {
    ### Test Buildsystem class API methods
    is( $BS_CLASS->canonpath("path/to/the/./nowhere/../../somewhere"),
        "path/to/somewhere", "canonpath no1" );
    is( $BS_CLASS->canonpath("path/to/../forward/../../somewhere"),
        "somewhere","canonpath no2" );
    is( $BS_CLASS->canonpath("path/to/../../../somewhere"),
        "../somewhere","canonpath no3" );
    is( $BS_CLASS->canonpath("./"), ".", "canonpath no4" );
    is( $BS_CLASS->canonpath("/absolute/path/./somewhere/../to/nowhere"),
        "/absolute/path/to/nowhere", "canonpath no5" );
    is( $BS_CLASS->_rel2rel("path/my/file", "path/my", "/tmp"),
        "file", "_rel2rel no1" );
    is( $BS_CLASS->_rel2rel("path/dir/file", "path/my", "/tmp"),
        "../dir/file", "_rel2rel no2" );
    is( $BS_CLASS->_rel2rel("file", "/root/path/my", "/root"),
        "/root/file", "_rel2rel abs no3" );
    is( $BS_CLASS->_rel2rel(".", ".", "/tmp"), ".", "_rel2rel no4" );
    is( $BS_CLASS->_rel2rel("path", "path/", "/tmp"), ".", "_rel2rel no5" );
    is( $BS_CLASS->_rel2rel("/absolute/path", "anybase", "/tmp"),
        "/absolute/path", "_rel2rel abs no6");
    is( $BS_CLASS->_rel2rel("relative/path", "/absolute/base", "/tmp"),
        "/tmp/relative/path", "_rel2rel abs no7");
}

