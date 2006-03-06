# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gtk2-Ex-Geo.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN { use_ok('Gtk2::Ex::Geo') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use Gtk2::Ex::Geo::Glue;

my $history = "$ENV{HOME}/.rash_history";
my $resources = "$ENV{HOME}/.rashrc";

my @history = ();
if (open TMP, $history) {
    @history = <TMP>;
    for (@history) {
	chomp $_;
	s/\r//;
    }
    close TMP;
}

my %resources = ();
if (open TMP, $resources) {
    my $key = '';
    while (<TMP>) {
	chomp $_;
	s/\r//;
	if (/^  /) {
	    s/^  //;
	    $resources{$key}{$_} = 1;
	} else {
	    $key = $_;
	}
    }
    close TMP;
}

my $gis = new Gtk2::Ex::Geo::Glue history=>\@history, resources=>\%resources;

# make the GUI:

my $window = Gtk2::Window->new;

my $vbox = Gtk2::VBox->new (FALSE, 0);

$vbox->pack_start ($gis->{toolbar}, FALSE, FALSE, 0);

my $hbox = Gtk2::HBox->new (FALSE, 0);

$hbox->pack_start ($gis->{tree_view}, FALSE, FALSE, 0);
$hbox->pack_start ($gis->{overlay}, TRUE, TRUE, 0);

$vbox->add ($hbox);

$vbox->pack_start ($gis->{entry}, FALSE, FALSE, 0);

my $bar = Gtk2::Statusbar->new ();
$vbox->pack_start ($bar, FALSE, FALSE, 0);

$window->add ($vbox);


# connect callbacks:

$window->signal_connect ("destroy", 
			 sub {
			     if (open TMP,">$history") {
				 for (@history[max(0,$#history-1000)..$#history]) {
				     print TMP "$_\n";
				 }
				 close TMP;
			     } else {
				 croak "$!: $history";
			     }
			     if (open TMP,">$resources") {				 
				 for my $key (keys %resources) {
				     print TMP "$key\n";
				     for my $value (keys %{$resources{$key}}) {
					 print TMP "  $value\n";
				     }
				 }
				 close TMP;
			     } else {
				 croak "$!: $resources";
			     }
			     exit(0); 
			 });

$gis->set_event_handler(\&info);
$gis->set_draw_on(\&my_draw);

$window->set_default_size(600,600);
$window->show_all;

$gis->{overlay}->{rubberbanding} = 'zoom rect';

Glib->install_exception_handler(sub {

    if ($_[0] =~ /\@INC contains/) {
	$_[0] =~ s/\(\@INC contains.*?\)//;
    }
    my $dialog = Gtk2::MessageDialog->new(undef,'destroy-with-parent','info','close',$_[0]);

    $dialog->run;
    $dialog->destroy;

    return 1;
});

#comment out in test
Gtk2->main;


# these are the callbacks:

sub info {
    my (undef,$event,$x1,$y1,$x0,$y0) = @_;

    return unless defined $x1;

    my $layer = $gis->get_selected_layer();
    my $mode = '';
    ($mode) = $gis->{overlay}->{rubberbanding} =~ /^(\w+)/;

#    print ref($event),"\n";

    if (ref($event) eq 'Gtk2::Gdk::Event::Button') {
#	print $event->button," ",$event->device,"\n";
    }

    if (ref($event) eq 'Gtk2::Gdk::Event::Key') {
#	print $event->keyval,"\n";
    }

    my $location = sprintf("(x,y) = (%.4f, %.4f)",$x1,$y1);
    my $value = '';
    if ($layer and ref($layer) eq 'Geo::Raster') {
	my @ij = $layer->w2g($x1,$y1);
	$location .= sprintf(", (i,j) = (%i, %i)",@ij);
	$value = $layer->wget($x1,$y1);
	if (defined $value and $value ne 'nodata' and $layer->{INFO}) {
	    $value = $layer->{TABLE}->{DATA}->[$value]->[$layer->{INFO}-1];
	}
    } elsif (ref($layer) eq 'Geo::Shapelib') {
	if ($layer->{Rtree}) {
	    my @shapes;	
	    $layer->{Rtree}->query_point($x1,$y1,\@shapes);
	    if ($layer->{INFO}) {	
		my @v;
		for (@shapes) {
		    my $ref = $layer->{ShapeRecords}->[$_];
		    my $v = ref($ref) eq 'ARRAY' ? $ref->[$layer->{INFO}-1] : $ref->{$layer->{INFO}};
		    push @v,$v;
		}
		$value = join(', ',@v);
	    } else {
		$value = "shape(s) @shapes";
	    }
	}
    }

    $bar->pop(0);
    # if mode is move, tell the movement vector
    $value = '' unless defined $value;
    my $distance = '';
    $distance = sqrt(($x1-$x0)**2+($y1-$y0)**2) if defined $x0;
    $distance = "dist = $distance" if $distance;
    $bar->push(0, sprintf("$mode $location $value $distance"));
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
