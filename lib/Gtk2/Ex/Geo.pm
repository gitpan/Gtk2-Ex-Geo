package Gtk2::Ex::Geo;

use 5.005000;
use strict;
use warnings;
use Gtk2::Ex::Geo::Renderer;
use Gtk2::Ex::Geo::Overlay;
use Gtk2::Ex::Geo::Glue;

require Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Gtk2::Ex::Geo ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.31';


# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Gtk2::Ex::Geo - A Perl Gtk2 widget for spatial data and a glue class for using it

=head1 SEE ALSO

Gtk2::Ex::Geo::Overlay
Gtk2::Ex::Geo::Glue

http://libral.sf.net
http://users.tkk.fi/u/jolma/index.html

=head1 AUTHOR

Ari Jolma, E<lt>ari.jolma _at_ tkk.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
