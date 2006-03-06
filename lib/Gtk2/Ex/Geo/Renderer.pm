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
    our $VERSION = '0.43';
}

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

    my $pixbuf = Gtk2::Ex::Geo::Renderer->new($layers, $minX, $maxY,
    $pixel_size, @viewport_size, $w_offset, $h_offset, @bg_color);

    $pixmap = $pixbuf->render_pixmap_and_mask(0);

    $image->set_from_pixmap($pixmap,undef);

=head2 Parameters

=over

=item $layers

a ref to a list of spatial data layers, currently supported are
Geo::Raster, Geo::Vector, and Gtk2::Ex::Geo::Composite

=item $minX, $maxY

upper left coordinates of the world

=item $pixel_size

self explanatory

=item @viewport_size

width and height (in pixels) of the requested pixbuf

=item $w_offset, $h_offset

offset of the viewport in world coordinates

=item @bg_color

red, green, blue for the background (each in the range 0..255)

=back

=head1 LAYER ATTRIBUTES

A Renderer object renders geospatial layer objects by calling the
method render($pb) on them (duck typing). $pb is a ral_pixbuf *
created with Geo::Raster::ral_pixbuf_new.

=cut

sub new {
    my($class,$layers,$minX,$maxY,
       $pixel_size,$width,$height,
       $w_offset,$h_offset,$bg_r,$bg_g,$bg_b) = @_;
    
    my $pb = &Geo::Raster::ral_pixbuf_new($width, $height,
					  $minX+$pixel_size*$w_offset, 
					  $maxY-$pixel_size*$h_offset, 
					  $pixel_size, 
					  $bg_r, $bg_g, $bg_b, 255);
    
    for my $lyr (@$layers) {

	next if $lyr->{hidden};
	my $alpha = $lyr->{alpha};
	$alpha = -1 unless defined($alpha);
	next if !ref($alpha) and $alpha == 0;
	$lyr->render($pb, $alpha);

    }

    my $wd = &Geo::Raster::ral_pixbuf_get_world($pb);
#    print STDERR "@$wd\n";

    my $self = gdk_pixbuf_new_from_data($pb);

    &Geo::Raster::ral_pixbuf_delete($pb); # does not delete the real pixbuf

    bless($self, $class); 
}

1;
__END__
=pod

=head1 SEE ALSO

Gtk2::Ex::Geo

=head1 AUTHOR

Ari Jolma, E<lt>ajolma at tkk.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut