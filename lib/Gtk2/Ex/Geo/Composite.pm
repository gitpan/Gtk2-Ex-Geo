package Gtk2::Ex::Geo::Composite;

use strict;
use warnings;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2;
use Geo::Raster;

BEGIN {
    use Exporter "import";
    our @EXPORT = qw();
    our @EXPORT_OK = qw();
    our %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}

=pod

=head1 NAME

Gtk2::Ex::Geo::Composite - A layer comprised of a set of spatial layers visualized together

=head1 METHODS

=head2 new

    $c = new Gtk2::Ex::Geo::Composite type=>$type, layers=>[$l1, $l2,
    ...];

Types 'RGB' and 'HSV' are implemented.

=cut

sub new {
    my $class = shift;
    my $type = shift;

    my $self = {type => $type, layers => [@_]};

    if ($type eq 'rgb' or $type eq 'RGB') {
	$self->{color_coding} = 1;
    } elsif ($type eq 'hsv' or $type eq 'HSV') {
	$self->{color_coding} = 2;
    }

    bless($self, $class); 
}

=pod

=head2 render

Called by Gtk2::Ex::Geo::Renderer.

=cut

sub render {
    my($self, $pb, $alpha) = @_;

    $alpha = $alpha->{GRID} if $alpha and ref($alpha) eq 'Geo::Raster';
    my ($b1,$b2,$b3) = @{$self->{layers}};

    &Geo::Raster::ral_render_grids($pb, $b1->{GRID}, $b2->{GRID}, $b3->{GRID},
				   $alpha, $self->{color_coding})

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
