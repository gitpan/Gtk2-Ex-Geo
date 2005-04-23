package Gtk2::Ex::Geo::Glue;

#use strict; # BAAAD thing but we need eval below...
use warnings;
use Carp;
use Term::ReadLine;
use Glib qw/TRUE FALSE/;
use Gtk2;
use Geo::Raster;
use Geo::Shapelib;
use Gtk2::Ex::Geo::Overlay;

BEGIN {
    use Exporter "import";
    our @EXPORT = qw();
    our @EXPORT_OK = qw();
    our %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}

our $VERSION = '0.31';

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

=pod

=head1 NAME

Gtk2::Ex::Geo::Glue - Some of the pieces of a GIS

=head1 SYNOPSIS

Look at the test code for an example.

=head1 GUI

The GUI is rather simple but hopefully usable and extendable.

=head1 METHODS

=head2 new

no parameters (todo: treestore columns should be parameters)

creates toolbar, entry, model, tree_view and overlay widgets

=cut

sub new {
    my($class) = @_;

    my @columns = qw /name type ? a/;
    
    my $model = Gtk2::TreeStore->new(qw/Glib::String Glib::String Glib::String Glib::String/);

    my $tree_view = Gtk2::TreeView->new($model);

    my $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tree_view->append_column($col);
    }

    my $overlay = Gtk2::Ex::Geo::Overlay->new();
    $overlay->my_inits();

    my $self = { model => $model,
		 tree_view => $tree_view, 
		 overlay => $overlay };

    $overlay->set_event_handler(\&event_handler,$self);
    $overlay->set_draw_on(\&draw_on,$self);

    $self->{toolbar} = toolbar($self);

    $self->{entry} = Gtk2::Entry->new();

    $self->{entry}->signal_connect(key_press_event => \&eval_entry, $self);

    bless($self, $class); 
}

=pod

=head2 add_history(\@history)

@history is a history for the entry

=cut

sub add_history {
    my($self,$history) = @_;
    $self->{history} = $history;
    $self->{history_index} = @$history;
}

=pod

=head2 @history = get_history()

@history is the history from the entry

=cut

sub get_history {
    my($self) = @_;
    return @{$self->{history}};
}

=pod

=head2 set_event_handler($event_handler,$user_param);

$event_handler is a user subroutine for handling events happening in
the overlay widget, it is called with parameters ($user_param, $event,
@xy);

=cut

sub set_event_handler {
    my($self,$event_handler,$user_param) = @_;
    $self->{event_handler} = $event_handler;
    $self->{event_handler_user_param} = $user_param;
}

=pod

=head2 set_draw_on($draw_on,$user_param);

$draw_on is a user subroutine for drawing on the overlay widget once
the overlay widget has created it, it is called with parameters
($user_param, $pixmap);

=cut

sub set_draw_on {
    my($self,$draw_on,$user_param) = @_;
    $self->{draw_on} = $draw_on;
    $self->{draw_on_user_param} = $user_param;
}

=pod

=head2 toolbar

returns a Gtk2::Toolbar, which is tied to attribute {toolbar} when a
new Gtk2::Ex::Geo::Glue object is created, a subroutine is connected
to each toolbar button

=cut

sub toolbar {
    my($self) = @_;

    my $toolbar = Gtk2::Toolbar->new ();

    for (reverse('Add','Remove','Up','Down','Toggle',
		 '+','-','Pan','Zoom','Zoom to','Zoom to all',
		 'Select','Edit','Move','Shell')) {

	my $b = Gtk2::ToolButton->new(undef,$_);
	$toolbar->insert($b,0);
	my $sub;
      SWITCH: {
	  if (/^Add/) { $sub = 
			    sub { 
				$self->add();
				$self->{tree_view}->set_cursor(Gtk2::TreePath->new(0));
				my ($selected,$selected_name) = $self->selected_layer();
				$self->{overlay}->zoom_to($selected);
			    }; last SWITCH; }
	  if (/^Remove/) { $sub = 
			       sub {
				   $self->delete_selected(); 
			       }; last SWITCH; }
	  if (/^Up/) { $sub = 
			   sub { 
			       $self->move_up(); 
			   }; last SWITCH; }
	  if (/^Down/) { $sub = 
			     sub { 
				 $self->move_down(); 
			     }; last SWITCH; }
	  if (/^Toggle/) { $sub = 
			     sub { 
				 $self->toggle(); 
			     }; last SWITCH; }
	  if (/^\+/) { $sub = 
			   sub { 
			       $self->{overlay}->zoom_in(); 
			   }; last SWITCH; }
	  if (/^\-/) { $sub = 
			   sub { 
			       $self->{overlay}->zoom_out(); 
			   }; last SWITCH; }
	  if (/^Zoom to all/) { $sub = 
				    sub { 
					$self->{overlay}->zoom_to_all(); 
				    }; last SWITCH; }
	  if (/^Zoom to/) { $sub = 
				sub { 
				    my ($selected,$selected_name) = $self->selected_layer();
				    $self->{overlay}->zoom_to($selected);
				}; last SWITCH; }
	  if (/^Zoom/) { $sub = 
			     sub { 
				 $self->{overlay}->{rubberbanding} = 'zoom rect';
				 $self->{overlay}->event_handler();
			       }; last SWITCH; }
	  if (/^Pan/) { $sub = 
			    sub { 
				$self->{overlay}->{rubberbanding} = 'pan line';
				$self->{overlay}->event_handler();
			    }; last SWITCH; }
	  if (/^Select/) { $sub = 
			       sub { 
				   $self->{overlay}->{rubberbanding} = 'select rect';
				   $self->{overlay}->event_handler();
			       }; last SWITCH; }
	  if (/^Edit/) { $sub = 
			     sub { 
				 my ($selected,$selected_name) = $self->selected_layer();
				 if (ref($selected) eq 'Geo::Shapelib') {
				     $selected->{ShowPoints} = $selected->{ShowPoints} ? 0 : 1;
				     $self->{overlay}->render();
				     $self->{overlay}->event_handler();
				 }
			     }; last SWITCH; }
	  if (/^Move/) { $sub = 
			     sub {
				 $self->{overlay}->{rubberbanding} = 'move line';
				 $self->{overlay}->event_handler();
			     }; last SWITCH; }
	  if (/^Shell/) { $sub = 
			      sub { 
				  $self->shell();
			      }; last SWITCH; }
      }
	$b->signal_connect ("clicked", $sub);
    }
    return $toolbar;
}

=pod

=head2 add

calls Gtk2::FileChooserDialog and if a file of known type is selected,
opens it and adds it by calling add_layer

=cut

sub add {
    my($self) = @_;
    my $filename;

    my $file_chooser =
	Gtk2::FileChooserDialog->new ('Select a spatial data file',
				      undef, 'open',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');

    my $folder = $file_chooser->get_current_folder;

    $file_chooser->set_current_folder($self->{add_from_folder}) if $self->{add_from_folder};
    
    if ('ok' eq $file_chooser->run) {
	# you can get the user's selection as a filename or a uri.
	$self->{add_from_folder} = $file_chooser->get_current_folder;
	$filename = $file_chooser->get_filename;
    }

    $file_chooser->set_current_folder($folder);
    
    $file_chooser->destroy;

    return unless $filename;

    my ($ext) = $filename =~ /\.(\w+)$/;
    my @f = split /\//,$filename;
    my $name = pop @f;
    $name =~ s/\.\w+$//;

    my %grid = (asc=>1,bil=>1,dem=>1,hdr=>1);
    my %shape = (shp=>1,SHP=>1);

    if ($grid{lc($ext)}) {
	my $grid = new Geo::Raster $filename;
	return unless $grid;
	$self->add_layer($grid, $name);
    } elsif ($shape{$ext}) {
#	my $shapefile = new Geo::Shapelib $filename, {Rtree=>1};
	my $shapefile = new Geo::Shapelib $filename;
	return unless $shapefile;
	$shapefile->{ALPHA} = 1;
	$self->add_layer($shapefile, $name);
    } else {
	croak("unrecognized format: $ext");
    }
}

=pod

=head2 p($something,%options)

an extended print, tries to print the contents of a hash or array
nicely

=cut

sub p {
    my($self,$this,%o) = @_;
    $self->output($o{file}) if $o{file};
    if (ref($this) eq 'HASH') {
	my @keys = keys %{$this};
	return unless @keys;
	if ($keys[0] =~ /^[-+\d.]+$/) {
	    foreach (sort {$a<=>$b} @keys) {
		my $v = $$this{$_};
		if (ref($v) eq 'ARRAY') {
		    print "$_ @{$v}\n";
		} else {
		    print "$_ $v\n";
		}
	    }
	} else {
	    foreach (sort @keys) {
		my $v = $$this{$_};
		if (ref($v) eq 'ARRAY') {
		    print "$_ @{$v}\n";
		} else {
		    print "$_ $v\n";
		}
	    }
	}
    } elsif (ref($this) eq 'ARRAY') {
	foreach (@{$this}) {
	    if (ref($_) eq 'ARRAY') {
		print "@{$_}\n";
	    } else {
		print "$_\n";
	    }
	}
    } else {
	print "$this\n";
    }
    $self->output() if $o{file};
}

=pod

=head2 plot($something,%options)

an interface to gnuplot, tries to plot the contents of a hash or array
nicely

=cut

sub plot {
    open GNUPLOT, "| gnuplot" or croak "can't open gnuplot: $!\n";
    my $fh = select(GNUPLOT); $| = 1;
    my($self,$this,%o) = @_;
    my $_plot_file = '.gis_plot';
    if ($o{file}) {
	gnuplot("set terminal png");
	gnuplot("set output \"$o{file}.png\"");
    }
    $o{with} = 'lines' unless $o{with};
    my $xrange = $o{xrange} ? $o{xrange} : '';
    my $yrange = $o{yrange} ? $o{yrange} : '';
    $o{title} = '' unless $o{title};
    my $using = $o{using} ? 'using ' . $o{using} : 'using 1:2';
    my $other = $o{other} ? ', ' . $o{other} : '';

    gnuplot("set xdata");
    gnuplot("set format x");

    # the plottable may be a HASH ref, ARRAY ref, Timeseries, or an array of those
    # support only array of Timeseries for now

    my $plottable = 'datafile';
    my @datasets = ($this);
    my @title;
    my @with;
    if (ref($this)) {
	if (ref($this) eq 'ARRAY') {
	    @datasets = @{$this};
	    if (ref($this->[0]) eq 'Timeseries') { # list of timeseries
		$plottable = 'timeseries';
	    } else { # list of arrays
		$plottable = 'array';
	    }
	    for my $set (0..$#datasets) {
		$title[$set] = ref($o{title}) ? $o{title}->{$set} : $o{title};
		$with[$set] = ref($o{with}) ? $o{with}->{$set} : $o{with};
	    }
	} elsif (ref($this) eq 'HASH') {
	    $plottable = 'hash';
	    my $set = 0;
	    $with[$set] = ref($o{with}) ? $o{with}->{$set} : $o{with};
	    $title[$set] = ref($o{title}) ? $o{title}->{$set} : $o{title};
	    foreach my $name (sort keys %{$this}) {
		if (ref($this->{$name}) eq 'Timeseries') { # hash of timeseries
		    $plottable = 'timeseries';
		    $datasets[$set] = $this->{$name};
		    if ($o{title}) {
			$title[$set] = ref($o{title}) ? $o{title}->{$set} : $o{title};
		    } else {
			$title[$set] = $name;
		    }
		    $with[$set] = ref($o{with}) ? $o{with}->{$set} : $o{with};
		    $set++;
		}
	    }
	} elsif (ref($this) eq 'Timeseries') {
	    $plottable = 'timeseries';
	} else {
	    croak "don't know how to plot a " . ref($this) . "\n";
	}
    }

    my @what; # = for each dataset: <function> | {"<datafile>" {datafile-modifiers}} 
    my @index;
    my @using;
    if ($plottable eq 'array' or $plottable eq 'hash') {
	my($minx,$maxx);
	my $r = 0;
	for my $set (0..$#datasets) {
	    unless (ref($datasets[$set])) {
		$what[$set] = $datasets[$set];
		$index[$set] = '';
		$using[$set] = '';
		next;
	    }
	    $self->output($_plot_file, $set ? (gnuplot_add=>1) : (0=>0));
	    $self->p($datasets[$set]);
	    $self->output;
	    $what[$set] = "\"$_plot_file\"";
	    $index[$set] = "index $set";
	    $using[$set] = $using;
	    if ($with[$set] eq 'impulses') {
		$r = 1;
		if (ref($datasets[$set]) eq 'HASH') {
		    foreach (keys %{$this}) {
			$minx = $_ if !defined($minx) or $_ < $minx;
			$maxx = $_ if !defined($maxx) or $_ > $maxx;
		    }
		} else {
		    foreach (@{$datasets[$set]}) {
			$minx = $$_[0] if !defined($minx) or $$_[0] < $minx;
			$maxx = $$_[0] if !defined($maxx) or $$_[0] > $maxx;
		    }
		}
		$minx--;
		$maxx++;
	    }
	}
	$xrange = "[$minx:$maxx]" if $r;
    } elsif ($plottable eq 'timeseries') {
	for my $set (0..$#datasets) {
	    $with[$set] = ref($o{with}) ? $o{with}->{$set} : $o{with};
	    if ($o{scaled}) {
		$datasets[$set]->scale->save($_plot_file, $set ? (gnuplot_add=>1) : (0=>0));
	    } else {
		$datasets[$set]->save($_plot_file, $set ? (gnuplot_add=>1) : (0=>0));
	    }
	    $what[$set] = "\"$_plot_file\"";
	    $index[$set] = "index $set";
	    $using[$set] = $using;
	}
	gnuplot("set xdata time");
	gnuplot("set timefmt \"%Y%m%d\"");
	gnuplot("set format x \"%d.%m\\n%y\"");
    } else {
	$title[0] = $o{title} ? $o{title} : '';
	$with[0] = $o{with} ? $o{with} : 'points';
	$index[0] = 'index 0';
	$using[0] = $using;
	if (-r $this) {
	    $what[0] = "\"$this\"";
	} else {
	    $what[0] = $this;
	    $using[0] = '';
	}
    }

    if ($#datasets == 0) {
	gnuplot("plot $xrange$yrange $what[0] $using[0] title \"$title[0]\" with $with[0]" . $other);
    } else {
#	unless (@names) {
#	    @names = $_input =~ /\$[a-zA-Z]\w*/g;
#	    unless (@names) {
#		@names = (0..$#datasets);
#	    }
#	}
	$title[0] = '' unless $title[0];
	my $plot = "plot $xrange$yrange $what[0] $index[0] $using[0] title \"$title[0]\" with $with[0]";
	for my $set (1..$#datasets) {
	    $title[$set] = '' unless $title[$set];
	    $plot .= ", $what[$set] $index[$set] $using[$set] title \"$title[$set]\" with $with[$set]";
	}
	gnuplot($plot . $other);
    }

    gnuplot("set xdata") if $plottable eq 'timeseries';
    if ($o{file}) {
	gnuplot("set terminal x11");
	gnuplot("set output");
    }
    select($fh);
}

sub gnuplot {
    my $line = shift;
    $line = '' unless $line;
#    print "$line\n" if $_options{debug};
    print GNUPLOT "$line\n";
}

=pod

=head2 clip_selected

returns the visible piece of a selected raster

todo: same for vector layers

=cut

sub clip_selected {
    my($self) = @_;
    my($gd) = $self->selected_layer();
    return unless $gd;
    return unless ref($gd) eq 'Geo::Raster';
    my @va = $self->{overlay}->visible_area;
    @va = $gd->wa2ga(@va);
    return $gd->clip(@va);
}

=pod

=head2 set_iter($iter,$layer,$name)

calls {model}->set for the given $iter use $name and data from $layer

probably private

=cut

sub set_iter {
    my($self,$iter,$layer,$name) = @_;
    my($type,$colors,$visible,$alpha);
    if (ref($layer) eq 'Geo::Raster') {
	$type = $layer->{DATATYPE} == $Geo::Raster::INTEGER_GRID ? 'int' : 'real';
#	$colors = $layer->{COLOR_TABLE_SIZE};
	$alpha = defined $layer->{ALPHA} ? (ref($layer->{ALPHA}) ? 'Layer' : $layer->{ALPHA}) : '1';
    } elsif (ref($layer) eq 'Geo::Shapelib') {
	$type = 'shape';
#	$colors = 'tbd';
	$alpha = defined $layer->{ALPHA} ? $layer->{ALPHA} : '1';
    }
    $visible = $layer->{HIDE} ? ' ' : 'X';
    $self->{model}->set ($iter,
			 0, "$name",
			 1, "$type",
			 2, $visible,
			 3, $alpha,
			 );
}

=pod

=head2 add_layermy($layer,$name,$do_not_zoom_to);

adds $layer with $name to overlay and model

the default behavior is to zoom to the new layer

=cut

sub add_layer {
    my($self,$layer,$name,$do_not_zoom_to) = @_;
    return unless $layer;
    return unless ref($layer) =~ /^Geo::/;
    $self->{overlay}->add_layer($layer,$do_not_zoom_to);
    my $iter = $self->{model}->insert (undef, 0);
    $self->set_iter($iter,$layer,$name);
    push @{$self->{list}},$iter;
    push @{$self->{names}},$name;
    $self->{layers}->{$name} = $layer;
}

=pod

=head2 get($name)

returns a layer by its name

=cut

sub get {
    my($self,$name) = @_;
    for my $index (0..$#{$self->{list}}) {
	if ($name eq $self->{names}->[$index]) {
	    return $self->{overlay}->{layers}->[$index];
	}
    }
}

=pod

=head2 get_focal($name)

returns a clipped part of a raster layer by its name

todo: same for vector layers

=cut

sub get_focal {
    my($self,$name) = @_;
    my $gd = $self->get($name);
    if ($gd and ref($gd) eq 'Geo::Raster') {
	my @va = $self->{overlay}->visible_area; # ul, dr
	@va = $gd->wa2ga(@va);
	# do not expand the view
	$va[2]--; 
	$va[3]--;
	return $gd->clip(@va);
    }
}

=pod

=head2 update($index_or_name)

$index_or_name is optional

updates the tree_view (by calling set_iter) for the given layer

=cut

sub update {
    my($self,$index_or_name) = @_;
    if (!defined $index_or_name) {
	for my $index (0..$#{$self->{list}}) {
	    $self->update($index);
	}
    } elsif ($index_or_name =~ /^\d+$/) {
	$self->set_iter($self->{list}->[$index_or_name],
			$self->{overlay}->{layers}->[$index_or_name],
			$self->{names}->[$index_or_name]);
    } else {
	for my $index (0..$#{$self->{list}}) {
	    if ($index_or_name eq $self->{names}->[$index]) {
		$self->update($index);
	    }
	}
    }
}

sub swap {
    my($array,$i1,$i2) = @_;
    my $e1 = $array->[$i1];
    my $e2 = $array->[$i2];
    $array->[$i1] = $e2;
    $array->[$i2] = $e1;
    return ($e1,$e2);
}

=pod

=head2 move_down

moves the selected layer down in the overlay

=cut

sub move_down {
    my($self) = @_;

    my ($path, $focus_column) = $self->{tree_view}->get_cursor;
    return unless $path;
    my $index = $path->to_string;
    my $n = $#{$self->{list}};
    if ($index < $n) {
	swap($self->{overlay}->{layers},$n-$index,$n-$index-1);
	my($iter1,$iter2) = swap($self->{list},$n-$index,$n-$index-1);
	swap($self->{names},$n-$index,$n-$index-1);
	$self->{model}->move_after($iter1,$iter2);
	$self->{overlay}->render;
    }

}

=pod

=head2 move_up

moves the selected layer up in the overlay

=cut

sub move_up {
    my($self) = @_;

    my ($path, $focus_column) = $self->{tree_view}->get_cursor;
    return unless $path;
    my $index = $path->to_string;
    my $n = $#{$self->{list}};
    if ($index > 0) {	
	swap($self->{overlay}->{layers},$n-$index,$n-$index+1);
	my($iter1,$iter2) = swap($self->{list},$n-$index,$n-$index+1);
	my ($n1, $n2) = swap($self->{names},$n-$index,$n-$index+1);
	$self->{model}->move_before($iter1,$iter2);
	$self->{overlay}->render;
    }

}

=pod

=head2 delete_selected

removes the selected layer from the overlay

=cut

sub delete_selected {
    my($self) = @_;
    my ($path, $focus_column) = $self->{tree_view}->get_cursor;
    return unless $path;
    my $index = $path->to_string;
    my $n = $#{$self->{list}};
    if ($index >= 0 and $index <= $n) {
	splice(@{$self->{overlay}->{layers}},$n-$index,1);
	my $iter = $self->{list}->[$n-$index];
	splice(@{$self->{list}},$n-$index,1);
	splice(@{$self->{names}},$n-$index,1);
	$self->{model}->remove($iter);
	if ($n > 0) {
	    $index-- if $index == $n;
	    $self->{tree_view}->set_cursor(Gtk2::TreePath->new($index));
	}
	$self->{overlay}->render;
    }
}

=pod

=head2 selected_layer

returns the selected layer

=cut

sub selected_layer {
    my($self) = @_;
    my ($path, $focus_column) = $self->{tree_view}->get_cursor;
    return unless $path;
    my $index = $path->to_string;
    my $n = $#{$self->{list}};
    if ($index >= 0 and $index <= $n) {
	return ($self->{overlay}->{layers}->[$n-$index],$self->{names}->[$n-$index]);
    } 
    return undef;
}

=pod

=head2 top_layer

returns the top layer

=cut

sub top_layer {
    my($self) = @_;
    return ($self->{overlay}->{layers}->[$#{$self->{list}}],$self->{names}->[$#{$self->{list}}]);
}

=pod

=head2 toggle

hides/shows the selected layer

=cut

sub toggle {
    my($self) = @_;
    my ($path, $focus_column) = $self->{tree_view}->get_cursor;
    return unless $path;
    my $index = $path->to_string;
    my $n = $#{$self->{list}};
    if ($index >= 0 and $index <= $n) {
	$self->{overlay}->{layers}->[$n-$index]->{HIDE} = !$self->{overlay}->{layers}->[$n-$index]->{HIDE};
	$self->update($n-$index);
	$self->{overlay}->render;
    }
}

sub event_handler {
    my ($self,$event,@xy) = @_;

    # select & move vertices is handled here

    if ($self->{overlay}->{selection}) {

	my ($selected,$selected_name) = $self->selected_layer();

	if (ref($selected) eq 'Geo::Shapelib') {

	    if ($self->{overlay}->{rubberbanding} =~ /select/ and $selected->{Rtree}) {

		my @selection = @{$self->{overlay}->{selection}};

		my @shapes;

		$selected->{Rtree}->query_completely_within_rect(@selection,\@shapes);
		print "you selected shapes: @shapes\n";

		@shapes = ();
		$selected->{Rtree}->query_partly_within_rect(@selection,\@shapes);
		print "shapes: @shapes overlap with the selection\n";
		
		# undo all

		$selected->clear_selections();
		
		# here find the vertices in the selection

		for my $shape (@shapes) {
		    my $vertices = $selected->select_vertices($shape,@selection);
		    my $n = @$vertices;
		    print "you selected $n vertices from shape $shape\n";
		}
		
	    } elsif ($self->{overlay}->{rubberbanding} =~ /move/) {

		my($fromx,$fromy,$dx,$dy) = @{$self->{overlay}->{selection}};

		$selected->move_selected_vertices($dx,$dy);

	    }

	    $self->{overlay}->render();

	}
	
    }

    return unless $self->{event_handler};
    $self->{event_handler}->($self->{event_handler_user_param},$event,@xy);
}

sub draw_on {
    my($self,$pixmap) = @_;
    $self->{draw_on}->($self->{draw_on_user_param},$pixmap) if $self->{draw_on};
}


=pod

=head2 eval_entry and shell

eval_entry is called when something happens in the entry, arrow up and
down retrieve entries from the history

the entry is given to Perl eval function after 

1) the variable names are inspected and found layer names are replaced
with pointers to real layers

2) keyword "focal:" in the beginning of an entry is removed and all
references to layers are replaced with clipped versions

shell suspends the main Gtk2 window and gives the focus to the
text-based terminal with a plain Perl eval loop

=cut

sub eval_entry {
    my($entry,$event,$self) = @_;
    my $key = $event->keyval;
    if ($key == 65293) {
	my $text = $entry->get_text;
	push @{$self->{history}}, $text if $text ne '';
	$self->{history_index} = @{$self->{history}};
	$entry->set_text('');
	my $focal = 0; # default is global
	if ($text =~ /^focal:\s*/) {
	    $text =~ s/^focal:\s*//;
	    $focal = 1;
	}
	my @g = $text =~ /\$(\w+)/g;
	my @gd;
	for my $i (0..$#g) {
	    $gd[$i] = $focal ? $self->get_focal($g[$i]) : $self->get($g[$i]);
	    next unless $gd[$i];
	    $text =~ s/\$$g[$i]\b/\$gd[$i]/;
	}
	{
	    no strict; # this does not do the trick and no strict 'refs' is not enough!!
#	    no warnings;
	    eval $text;
	    print STDERR "$text\n$@" if $@;
	}
	for my $i (0..$#g) {
	    if ($self->get($g[$i])) {
		$gd[$i]->getminmax() if ref($gd[$i]) =~ /^Geo::Raster/;
	    } else {
		eval "\$self->add_layer(\$$g[$i],'$g[$i]',1) if ref(\$$g[$i]) =~ /^Geo::/;";
	    }
	}
	$self->update();
	$self->{overlay}->render;
	return 1;
    } elsif ($key == 65362) { # arrow up, history?
	$self->{history_index} = max(0, $self->{history_index}-1);
	$entry->set_text($self->{history}->[$self->{history_index}]) if 
	    $self->{history_index} >=0 and $self->{history}->[$self->{history_index}];
	return 1;
    } elsif ($key == 65364) {
	$self->{history_index} = min($#{$self->{history}}+1, $self->{history_index}+1);
	if ($self->{history_index} <= $#{$self->{history}}) {
	    $entry->set_text($self->{history}->[$self->{history_index}]);
	} else {
	    $entry->set_text('');
	}
	return 1;
    }
}

sub min {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

sub max {
    $_[0] > $_[1] ? $_[0] : $_[1];
}

sub shell {
    my($self,$iter,$layer,$name) = @_;
    my $term = new Term::ReadLine '';
    my $hfile = "$ENV{HOME}/.rash_history";
    $term->ReadHistory($hfile);
    while ( defined ($_ = $term->readline('>')) ) {
	chomp;
	my $input = $_;
	if (/^\?$/ or /^help$/i) {
	    system "perldoc $0";
	} elsif (/^\? Raster$/ or /^help Raster$/i) {
	    system "man Geo::Raster";
	} elsif (/^\!(.*)/) {
	    system $1;
	} else {
	    eval;
	    print $@;
	}
	Gtk2->main_iteration_do(FALSE); # does not do the trick of window updating
    }
    print "\n";
    $term->WriteHistory($hfile);
    $self->update();
    $self->{overlay}->render;
}

sub output {
    my($self,$fn,%o) = @_;
    if ($fn and exists $o{gnuplot_add}) {
	open OUTPUT,">>$fn" or croak("can't open $fn: $!\n");
	print OUTPUT "\n\n";
	select OUTPUT;
    } elsif ($fn) {
	open OUTPUT, ">$fn" or croak "can't open $fn: $!\n";
	select OUTPUT;
    } else {
	close(OUTPUT);
	select STDOUT;
    }
}

1;
__END__
