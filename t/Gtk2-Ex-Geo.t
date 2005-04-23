# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gtk2-Ex-Geo.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN { use_ok('Gtk2::Ex::Geo') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use Gtk2::Ex::Geo::Glue;

my $gis = new Gtk2::Ex::Geo::Glue;

# make the GUI:

my $window = Gtk2::Window->new;

my $vbox = Gtk2::VBox->new (FALSE, 0);

$vbox->pack_start ($gis->{toolbar}, FALSE, FALSE, 0);

my $hbox = Gtk2::HBox->new (FALSE, 0);

$hbox->pack_start ($gis->{tree_view}, FALSE, FALSE, 0);
$hbox->pack_start ($gis->{overlay}, TRUE, TRUE, 0);

$vbox->add ($hbox);

{
    my @history = `cat $ENV{HOME}/.rash_history`;
    for (@history) {
	chomp $_;
    }
    $gis->add_history(\@history);
}

$vbox->pack_start ($gis->{entry}, FALSE, FALSE, 0);

my $bar = Gtk2::Statusbar->new ();
$vbox->pack_start ($bar, FALSE, FALSE, 0);

$window->add ($vbox);


# connect callbacks:

$window->signal_connect ("destroy", 
			 sub {
			     my @history = $gis->get_history;
			     if (open HISTORY,">$ENV{HOME}/.rash_history") {
				 for (@history[max(0,$#history-1000)..$#history]) {
				     print HISTORY "$_\n";
				 }
				 close HISTORY;
			     }
			     exit(0); 
			 });

$gis->set_event_handler(\&info);
$gis->set_draw_on(\&my_draw);

my $s = new Geo::Shapelib '/home/ajolma/habitat/CAGeologySeries/Area1/gma1sub', {Rtree=>1};

for my $shape (@{$s->{Shapes}}) {
    $shape->{Color} = [rand,rand,rand,rand];
}

#$s->{Rtree}->dump;
#exit;

#my $s = new Geo::Shapelib '/home/ajolma/habitat/CAGeologySeries/Area1/GMA1GEO';
#my $s = new Geo::Shapelib '/home/ajolma/habitat/bodega100mxyz';
#my $s = new Geo::Shapelib '/home/ajolma/DIGIROAD_LIIKENNE_ELEMENTTI';

$gis->add_layer($s,'test');

#my $s = new Geo::Raster '/home/ajolma/proj/MilSim/slam3_19o';
#$gis->add_layer($s,'test');

# start up:

$window->set_default_size(600,600);
$window->show_all;

$gis->{overlay}->{rubberbanding} = 'zoom rect';

#comment out in test
#Gtk2->main;


# these are the callbacks:

sub info {
    my (undef,$event,@xy) = @_;

    my ($selected,$selected_name) = $gis->selected_layer();
    my $mode = '';
    ($mode) = $gis->{overlay}->{rubberbanding} =~ /^(\w+)/;

#    print ref($event),"\n";

    if (ref($event) eq 'Gtk2::Gdk::Event::Button') {
#	print $event->button," ",$event->device,"\n";
    }

    if (ref($event) eq 'Gtk2::Gdk::Event::Key') {
	print $event->keyval,"\n";
    }

    my $location = sprintf("(x,y) = (%.4f, %.4f)",@xy);
    my $value = '';
    if ($selected and ref($selected) eq 'Geo::Raster') {
	my @ij = $selected->w2g(@xy);
	$location .= sprintf(", (i,j) = (%i, %i)",@ij);
	$value = $selected->get(@ij);
	if (defined $value and $value ne 'nodata' and $selected->{INFO}) {
	    $value = $selected->{TABLE}->{DATA}->[$value]->[$selected->{INFO}-1];
	}
    } elsif (ref($selected) eq 'Geo::Shapelib') {
	if ($selected->{Rtree}) {
	    my @shapes;	
	    $selected->{Rtree}->query_point(@xy,\@shapes);
	    if ($selected->{INFO}) {	
		my @v;
		for (@shapes) {
		    push @v,$selected->{ShapeRecords}->[$_]->[$selected->{INFO}-1];
		}
		$value = join(@v,', ');
	    } else {
		$value = "shape(s) @shapes";
	    }
	}
    }

    $bar->pop(0);
    # if mode is move, tell the movement vector
    $value = '' unless defined $value;
    $bar->push(0, sprintf("$mode $location $value"));
}

sub my_draw {
    my(undef,$pixmap) = @_;
    
}

sub min {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

sub max {
    $_[0] > $_[1] ? $_[0] : $_[1];
}
