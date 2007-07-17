use Test::More tests => 1;
eval {
    require IPC::Gnuplot;
};
my $have_gnuplot = !$@;
BEGIN { 
    use_ok('Gtk2::Ex::Geo');
};

exit unless $ENV{GUI};

use Gtk2;

Gtk2->init;
Glib->install_exception_handler(\&Gtk2::Ex::Geo::exception_handler);

{
    package Gtk2::Ex::Geo::Test;
    our @ISA = qw(Gtk2::Ex::Geo::Layer);
    sub new {
	my($package) = @_;
	my $self = Gtk2::Ex::Geo::Layer::new($package);
	return $self;
    }
    sub name {
	'test';
    }
    sub world {
	return (0, 0, 100, 100);
    }
    sub render {
	my($self, $pb, $cr, $overlay, $viewport) = @_;
    }
}

my @r = (Gtk2::Ex::Geo::Layer::registration());
my($window, $gis) = Gtk2::Ex::Geo::simple(registrations => \@r);

if ($have_gnuplot) {
    my $gnuplot = IPC::Gnuplot->new();
    $gis->register_function( name => 'plot', object => $gnuplot );
    $gis->register_function( name => 'p', object => $gnuplot );
}

my $layer = Gtk2::Ex::Geo::Test->new();
$gis->add_layer($layer);

$gis->register_commands
    ( 
      {
	  'test' => {
	      nr => 1,
	      text => 'test',
	      pos => -1,
	      sub => sub {
		  my(undef, $gui) = @_;
		  print STDERR "test command\n";
	      }
	  }
      } );

Gtk2->main;
