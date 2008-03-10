use Test::More tests => 1;
use Geo::Raster;
use Geo::Vector;
use Gtk2;

eval {
    require IPC::Gnuplot;
};
my $have_gnuplot = !$@;
BEGIN { 
    use_ok('Gtk2::Ex::Geo');
};

exit unless $ENV{GUI};

Gtk2->init;
Glib->install_exception_handler(\&Gtk2::Ex::Geo::exception_handler);

{
    package Gtk2::Ex::Geo::Test;
    our @ISA = qw(Gtk2::Ex::Geo::Layer);
    sub new {
	my $self = Gtk2::Ex::Geo::Layer::new(@_);
	return $self;
    }
    sub world {
	return (0, 0, 100, 100);
    }
    sub render {
	my($self, $pb, $cr, $overlay, $viewport) = @_;
    }
}

my($window, $gis) = Gtk2::Ex::Geo::simple
	(classes => [qw/Gtk2::Ex::Geo::Layer Geo::Vector::Layer Geo::Raster::Layer/]);

if ($have_gnuplot) {
    my $gnuplot = IPC::Gnuplot->new();
    $gis->register_function( name => 'plot', object => $gnuplot );
    $gis->register_function( name => 'p', object => $gnuplot );
}

my $layer = Gtk2::Ex::Geo::Test->new(name => 'test 1');
$gis->add_layer($layer);

$layer = Gtk2::Ex::Geo::Test->new(name => 'test 2');
$gis->add_layer($layer);

$gis->{overlay}->signal_connect(update_layers => 
	sub {
	#print STDERR "in callback: @_\n";
	});

$gis->register_commands
    ( 
      {
	  'test' => {
	      nr => 1,
	      text => 'test',
	      pos => -1,
	      sub => sub {
		  my(undef, $gui) = @_;
	      }
	  }
      } );

Gtk2->main;
