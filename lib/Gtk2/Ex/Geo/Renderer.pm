package Gtk2::Ex::Geo::Renderer;

use strict;
use warnings;
use Carp;
use Gtk2;

BEGIN {
    use Exporter "import";
    our @EXPORT = qw();
    our @EXPORT_OK = qw();
    our %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}

our $VERSION = '0.31';

require DynaLoader;

our @ISA = qw(Exporter DynaLoader Gtk2::Gdk::Pixbuf);

sub dl_load_flags {0x01}

bootstrap Gtk2::Ex::Geo::Renderer;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

=pod

=head1 NAME

Gtk2::Ex::Geo::Renderer - A Gtk2::Gdk::Pixbuf made from spatial data

=head1 SYNOPSIS

my $pixbuf = Gtk2::Ex::Geo::Renderer->new($layers,$minX,$maxY,$pixel_width,@viewport_size,$w_offset,$h_offset,@bg_color);

$pixmap = $pixbuf->render_pixmap_and_mask(0);

$image->set_from_pixmap($pixmap,undef);

=head2 Parameters

$layers

a ref to a list of spatial data layers, currently supported are Geo::Shapelib and Geo::Raster

$minX,$maxY

upper left coordinates of the world

$pixel_width

self explanatory

@viewport_size

width and height (in pixels) of the requested pixbuf

$w_offset,$h_offset

offset of the viewport in world coordinates

@bg_color

red, green, blue for the background (each in the range 0..255)

=head1 LAYER ATTRIBUTES

A Renderer object renders libral grids (via Geo::Raster) and
shapefiles (via Geo::Shapelib). The following attributes are used.

=head2 all layers

HIDE = int

ALPHA = number, hash, or grid # float (0..1)

=head2 Geo::Raster

COLOR_TABLE = color_table *

GRID = grid *

FDG = if defined then calls render_fdg

=head2 Geo::Shapelib

Shapes

MinBounds = (minx,miny) 

MaxBounds = (maxx,maxy) 

ShowPoints = int # if true, renders unselected vertices as red
crosses, and selected vertices as inverted crosses

=head2 Shapes from Geo::Shapelib

SHPType

Hide = int # if true, shape is not rendered

MinBounds = (minx,miny) 

MaxBounds = (maxx,maxy) 

Selected = int

SelectedVertices = (int,...)

Color = (r,g,b,a) # float in the range 0..1

Vertices

NParts

Parts

=cut

# just passing thru...
# nothing very interesting here

sub new {
    my($class,$grids,$minX,$maxY,$pixel_width,$width,$height,$w_offset,$h_offset,$bg_r,$bg_g,$bg_b) = @_;

    my $self = gdk_pixbuf_new_from_data($grids,$minX+$pixel_width*$w_offset,$maxY-$pixel_width*$h_offset,$pixel_width,
					$width,$height,
#					$w_offset,$h_offset,
					$bg_r,$bg_g,$bg_b);

    bless($self, $class); 
}

1;
__END__
