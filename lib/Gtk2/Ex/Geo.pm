## @namespace Gtk2::Ex::Geo
# @brief a framework for building geospatial GUI toolkit
#
# Contains classes Gtk2::Ex::Geo::DialogMaster,
# Gtk2::Ex::Geo::Dialogs, Gtk2::Ex::Geo::Raster
# Gtk2::Ex::Geo::Raster::Dialogs #Gtk2::Ex::Geo::Vector
# Gtk2::Ex::Geo::Vector::Dialogs #Gtk2::Ex::Geo::Glue
# Gtk2::Ex::Geo::History #Gtk2::Ex::Geo::Layer
# Gtk2::Ex::Geo::TreeDumper

package Gtk2::Ex::Geo;

# @brief A widget and other classes for geospatial applications
# @author Copyright (c) Ari Jolma
# @author This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.5 or,
# at your option, any later version of Perl 5 you may have available.

=pod

=head1 NAME

Gtk2::Ex::Geo - A widget and other classes for geospatial applications

The <a href="http://map.hut.fi/doc/Geoinformatica/html/">
documentation of Gtk2::Ex::Geo</a> is written in doxygen format.

=cut

use strict;
use warnings;
use XSLoader;

use Glib qw/TRUE FALSE/;
use Gtk2;
use Gtk2::Gdk::Keysyms; # in Overlay

use Gtk2::GladeXML;
use Gtk2::Ex::Geo::DialogMaster;

use Gtk2::Ex::Geo::Glue;

BEGIN {
    use Exporter "import";
    our @ISA = qw(Exporter);
    our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );
    our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
    our @EXPORT = qw( );
    our $VERSION = '0.55';
    XSLoader::load( 'Gtk2::Ex::Geo', $VERSION );
}

## @cmethod list simple(%params)
# @brief Construct a simple GIS
#
# @param params named parameters:
# - <i>registrations</i> an anonymous list of class registrations for a Glue object
# @return a list of window and a Glue object

sub simple{
    my %params = @_;
    my $home = Gtk2::Ex::Geo::homedir();

    my $window = Gtk2::Window->new;
    
    $params{title} = 'Geoinformatica' unless $params{title};
    $window->set_title($params{title});

    $window->set_default_icon_from_file($params{icon}) if $params{icon} and -f $params{icon};
    
    my $gis = Gtk2::Ex::Geo::Glue->new
	( 
	  history => "$home.rash_history", 
	  resources => "$home.rashrc", 
	  main_window => $window
	  );

    if ($params{registrations}) {
	for (@{$params{registrations}}) {
	    $gis->register_class(%{$_});
	}
    }
    
    my $vbox = Gtk2::VBox->new (FALSE, 0);
    
    $vbox->pack_start ($gis->{toolbar}, FALSE, FALSE, 0);
    
    my $hbox = Gtk2::HBox->new (FALSE, 0);
    
    $hbox->pack_start ($gis->{tree_view}, FALSE, FALSE, 0);
    $hbox->pack_start ($gis->{overlay}, TRUE, TRUE, 0);
    
    $vbox->add ($hbox);
    
    $vbox->pack_start ($gis->{entry}, FALSE, FALSE, 0);
    $vbox->pack_start ($gis->{statusbar}, FALSE, FALSE, 0);

    $window->add ($vbox);
    
    $window->signal_connect("destroy", \&close_the_app, [$window, $gis]);

    $window->set_default_size(600,600);
    $window->show_all;
    
    return ($window, $gis);
}

## @ignore
sub exception_handler {
    
    if ($_[0] =~ /\@INC contains/) {
	$_[0] =~ s/\(\@INC contains.*?\)//;
    }
    my $dialog = Gtk2::MessageDialog->new(undef,'destroy-with-parent','info','close',$_[0]);
    $dialog->signal_connect(response => \&destroy_dialog);
    $dialog->show_all;
    
    return 1;
}

## @ignore
sub destroy_dialog {
    my($dialog) = @_;
    $dialog->destroy;
}

## @ignore
sub close_the_app {
    my($window, $gis) = @{$_[1]};
    $gis->close();
    Gtk2->main_quit;
    exit(0);
}

## @ignore
sub homedir {

    require Config;
    my $OS = $Config::Config{'osname'};

    if ($OS eq 'MSWin32') {

	require Win32::Registry;
    
	my $Register = "Volatile Environment";
	my $hkey = $::HKEY_CURRENT_USER; # assignment is just to get rid of a "used only once" warning
    
	$::HKEY_CURRENT_USER->Open($Register,$hkey);
    
	my %values;

	$hkey->GetValues(\%values);
    
	$hkey->Close;

	return "$values{HOMEDRIVE}->[2]$values{HOMEPATH}->[2]\\";

    } else {

	return "$ENV{HOME}/";

    }

}

1;
