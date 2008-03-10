## @namespace Gtk2::Ex::Geo
# @brief A framework of widgets for geospatial applications

package Gtk2::Ex::Geo;

# @brief A framework of widgets for geospatial applications
# @author Copyright (c) Ari Jolma
# @author This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.5 or,
# at your option, any later version of Perl 5 you may have available.

=pod

=head1 NAME

Gtk2::Ex::Geo - The main module to use for geospatial applications

Gtk2::Ex::Geo is a namespace for modules, classes, and widgets for
geospatial applications. This package contains the modules:

=head2 Gtk2::Ex::Geo

The main module to 'use'. Contains also function 'simple', which
constructs a simple geospatial desktop application.

=head2 Gtk2::Ex::Geo::Canvas

A subclass of Gtk2::Gdk::Pixbuf. Constructs a pixbuf from a stack of
geospatial layer objects by calling the 'render' method for each
$layer. Embedded in Gtk2::Ex::Geo::Overlay.

=head2 Gtk2::Ex::Geo::Overlay

A subclass of Gtk2::ScrolledWindow. A canvas in a scrolled
window. Contains a list of layer objects. Functionality includes
redraw, support for selections (point, line, path, rectangle, polygon,
or many of them), zoom, pan, and conversion between event and world
(layer) coordinates.

=head2 Gtk2::Ex::Geo::Layer

The root class for geospatial layers. A geospatial layer is a
typically a subclass of a geospatial data (raster, vector features, or
something else) and of this class. The idea is that this class
contains visualization information (transparency, palette, colors,
symbology, label placement, etc) for the data. Contains many callbacks
that are fired as a result of user using context menu, making a
selection, etc. Uses layer dialogs.

=head2 Gtk2::Ex::Geo::DialogMaster

A class which maintains a set of Glade dialogs taken from XML in DATA
section.

=head2 Gtk2::Ex::Geo::Dialogs

A subclass of Gtk2::Ex::Geo::DialogMaster. Contains dialogs for
Gtk2::Ex::Geo::Layer.

=head2 Gtk2::Ex::Geo::Glue

Typically a singleton class for an object, which manages a
Gtk2::Ex::Geo::Overlay widget, a Gtk2::TreeView widgets, and other
widgets of a geospatial application. The object also takes care of
popping up context menus and other things.

=head2 Gtk2::Ex::Geo::History

Embedded in Gtk2::Ex::Geo::Glue. Input history a'la (at least
attempting) GNU history that is used by Glue object with Gtk2::Entry.

=head2 Gtk2::Ex::Geo::TreeDumper

From http://www.asofyet.org/muppet/software/gtk2-perl/treedumper.pl-txt
For inspecting layer and other objects.

=head1 USAGE

# these two geospatial layer classes are not included:
use Geo::Raster;
use Geo::Vector;

use Gtk2::Ex::Geo;
use Gtk2 '-init';

Glib->install_exception_handler(\&Gtk2::Ex::Geo::exception_handler);

my($window, $gis) = Gtk2::Ex::Geo::simple
	(classes => [qw/Gtk2::Ex::Geo::Layer Geo::Vector::Layer Geo::Raster::Layer/]);

Gtk2->main;

=head1 DOCUMENTATION

The documentation of Gtk2::Ex::Geo is included into the source code in
<a href="http://www.stack.nl/~dimitri/doxygen/">doxygen</a>
format. The documentation can be generated in HTML, LaTeX, and other
formats using the doxygen executable and the <a
href="http://www.bigsister.ch/doxygenfilter/">perl doxygen filter</a>.

The documentation is of this framework is available as a part of the
documentation for <a
href="http://map.hut.fi/doc/Geoinformatica/html/">Geoinformatica</a>.

=cut

use strict;
use warnings;
use XSLoader;

use Carp;
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
    our $VERSION = '0.57';
    XSLoader::load( 'Gtk2::Ex::Geo', $VERSION );
}

## @cmethod list simple(%params)
# @brief Construct a simple GIS
#
# @param params named parameters:
# - <i>classes</i> an anonymous list of layer classes
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
    
    if ($params{classes}) {
	for (@{$params{classes}}) {
	    $gis->register_class($_);
	}
    } else {
	croak "usage: simple(classes => [qw/Gtk2::Ex::Geo::Layer ...other layer classes.../])";
    }
    
    my $vbox = Gtk2::VBox->new (FALSE, 0);
    
    $vbox->pack_start ($gis->{toolbar}, FALSE, FALSE, 0);
    
    my $hbox = Gtk2::HBox->new (FALSE, 0);
    
    my $w = Gtk2::ScrolledWindow->new();
    $w->set_policy("never", "automatic");
    $hbox->pack_start ($w, FALSE, FALSE, 0);
    $w->add ($gis->{tree_view});
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
