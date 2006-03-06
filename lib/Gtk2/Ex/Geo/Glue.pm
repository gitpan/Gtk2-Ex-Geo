package Gtk2::Ex::Geo::Glue;

#use strict; # BAAAD thing but we need eval below...
use warnings;
use Carp;
use File::Basename;
use Term::ReadLine;
use Glib qw/TRUE FALSE/;
use Gtk2;
use Geo::Raster;
use Geo::Vector;
use gdal;
use ogr;
use Gtk2::GladeXML;
use Gtk2::Ex::Geo::Composite;
use Gtk2::Ex::Geo::Overlay;
use Gtk2::Ex::Geo::OGRDialog;
use Gtk2::Ex::Geo::GDALDialog;

use Data::TreeDumper::Renderer::GTK;

BEGIN {
    use Exporter "import";
    our @EXPORT = qw();
    our @EXPORT_OK = qw();
    our %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
    gdal::AllRegister;
    ogr::RegisterAll();
    gdal::UseExceptions();
}

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

=pod

=head1 NAME

Gtk2::Ex::Geo::Glue - Module for glueing widgets into a GIS.

=head1 METHODS

=head2 new

    $gis = new Gtk2::Ex::Geo::Glue (history=>\@history,
    resources=>$resources);

Creates toolbar, entry, model, tree_view and overlay widgets and
stores them into the object.

=cut

sub new {
    my $class = shift;
    my %opt = @_;

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

    $self->{history} = $opt{history};
    $self->{history_index} = $#{$self->{history}};
    unless ($self->{history}->[$self->{history_index}] eq '') {
	push @{$self->{history}}, '';
	$self->{history_index}++;
    }

    $self->{resources} = $opt{resources};

    my @buffer = <DATA>;
    $self->{glade} = Gtk2::GladeXML->new_from_buffer("@buffer");
    my $dialog = $self->{glade}->get_widget('dialog1');
    my $close = $self->{glade}->get_widget('closebutton1');
    $close->signal_connect(clicked => 
			   sub {
			       @{$self->{dialog1_position}} = $dialog->get_position;
			       $dialog->hide;
			    });

    $tree_view->signal_connect(button_press_event => \&layer_menu, $self);

    $overlay->set_event_handler(\&event_handler,$self);
    $overlay->set_draw_on(\&draw_on,$self);

    $self->{toolbar} = toolbar($self);


    my $folder;
    chomp ($folder = `pwd`);
    $folder .= '/';
    $self->{add_from_folder} = $folder;

    $self->{ogr_dialog} = new Gtk2::Ex::Geo::OGRDialog(%$self);

    $self->{gdal_dialog} = new Gtk2::Ex::Geo::GDALDialog();

    $self->{entry} = Gtk2::Entry->new();

    $self->{entry}->signal_connect(key_press_event => \&eval_entry, $self);

    bless($self, $class); 
}

sub layer_menu {
    my($tv,$event,$self) = @_;

    my @res = $self->{tree_view}->get_path_at_pos($event->x,$event->y);
    return unless defined $res[0];

    my $layer = $self->{overlay}->get_layer_by_index($res[0]->to_string); 
    return unless $layer;

    my $column = $res[1]->get_title;
    
    if ($event->button == 3) {

	my $menu = Gtk2::Menu->new;

	my $hide = $layer->{hidden} ? '_Show' : '_Hide';
	
	my @data = ('_Zoom to','_Up','_Down',$hide,'_Remove');
	
	if (ref($layer) eq 'Geo::Vector') {
	    push @data, ('','_Features...','_Vertices...','R_asterize...');
	    push @data, ('','C_olor...','_Colors...');
	} elsif (ref($layer) eq 'Geo::Raster') {
	    push @data, ('','C_lip...') if $layer->{GDAL};
	    push @data, ('','_Colors...');
	}
	push @data, ('_Inspect...','_Properties...');
	
	for (my $i = 0 ; $i < @data ; $i++) {
	    if ($data[$i] eq '') {
		my $item = Gtk2::SeparatorMenuItem->new();
		$item->show;
		$menu->append ($item);
		next;
	    }
	    my $item = Gtk2::MenuItem->new ($data[$i]);
	    $item->show;
	    $menu->append ($item);
	    $item->{index} = $i;
	    $item->{text} = $data[$i];
	    $item->signal_connect(activate => \&layer_menu_item, [$self, $data[$i]]);
	}
	$menu->popup(undef, undef, undef, undef, $event->button, $event->time);

    } elsif ($column eq '?') {

	$layer->{hidden} = !$layer->{hidden};
	$self->update;
	$self->{overlay}->render;

    }

    return 0;
}

sub layer_menu_item {
    my ($item, $info) = @_;
    my $self = shift @$info;
    $_ = shift @$info;
    $_ =~ s/_//g;
    my $layer = $self->get_selected_layer();
  SWITCH: {
      if (/Zoom to/) {
	  $self->{overlay}->zoom_to($layer);
	  last SWITCH; 
      }
      if (/Up/) {
	  $self->move_up();
	  last SWITCH; 
      }
      if (/Down/) {
	  $self->move_down();
	  last SWITCH; 
      }
      if (/(Show)|(Hide)/) {
	  $layer->{hidden} = !$layer->{hidden};
	  $self->update;
	  $self->{overlay}->render;
	  last SWITCH;
      }
      if (/Properties/) {
	  my $ret;
	  if (ref($layer) eq 'Geo::Vector') {
	      $ret = $self->{ogr_dialog}->layer_properties($self->{overlay},$layer);
	  } elsif (ref($layer) eq 'Geo::Raster' and not $layer->{GDAL}) {
	      $ret = $self->{gdal_dialog}->layer_properties($self->{overlay},$layer);
	      if ($ret->{nodata} and $ret->{nodata} =~ /^(\d|\.)/) {
		  $layer->nodata_value($ret->{nodata});
	      }
	  } elsif (ref($layer) eq 'Geo::Raster' and $layer->{GDAL}) {
	      $ret = $self->{gdal_dialog}->layer_properties2($self->{overlay},$layer);
	  }
	  $layer->{alpha} = $ret->{alpha} if defined $ret->{alpha};
	  $layer->{name} = $ret->{name} if defined $ret->{name};
	  $self->update();
	  $self->{overlay}->render if defined $ret->{alpha};
	  last SWITCH; 
      }
      if (/Features/) {
	  last SWITCH unless $layer;
	  last SWITCH unless ref($layer) eq 'Geo::Vector';
	  $self->{ogr_dialog}->browse_features($layer->{ogr_layer},$self->{overlay});
	  last SWITCH;
      }
      if (/Vertices/) {
	  last SWITCH unless $layer;
	  last SWITCH unless ref($layer) eq 'Geo::Vector';
	  $self->{ogr_dialog}->browse_vertices($layer->{ogr_layer},$self->{overlay});
	  last SWITCH; 
      }
      if (/Rasterize/) {
	  my $ret = $self->{ogr_dialog}->rasterize_dialog($layer,$self->{overlay});
	  if ($ret->{like}) {
	      my $g = $layer->rasterize(%$ret);
	      if ($g) {
		  $self->add_layer($g, 'r', 1);
		  $self->{overlay}->render;
	      }
	  }
	  last SWITCH;
      }
      if (/Colors/) {
	  if (ref($layer) eq 'Geo::Vector') {
	      $self->{ogr_dialog}->colors_dialog($layer,$self->{overlay});
	  } elsif (ref($layer) eq 'Geo::Raster') {
	      $self->{gdal_dialog}->colors_dialog($layer,$self->{overlay});
	  }
	  last SWITCH; 
      }
      if (/Color/) {
	  if (ref($layer) eq 'Geo::Vector') {
	      $self->{ogr_dialog}->color_dialog($layer,$self->{overlay});
	  }
	  last SWITCH; 
      }
      if (/Clip/) {
	  last SWITCH unless $layer and ref($layer) eq 'Geo::Raster' and $layer->{GDAL};
	  my @dim = $self->{gdal_dialog}->clip_dialog($layer,$self->{overlay});
	  if (@dim) {
	      my $name = shift @dim;
	      my $g = $layer->cache(@dim);
	      $self->add_layer($g, $name, 1);
	      $self->{overlay}->render;
	  }
      }
      if (/Inspect/) {
	  $self->inspect($layer);
	  last SWITCH; 
      }
      if (/Remove/) {
	  $self->delete_selected(); 
	  last SWITCH; 
      }
  }
    
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
    
    my %tips = ('Open raster layer' => 'Add a new raster layer.',
		'Open vector layer' => 'Add a new vector layer.',
		'Zoom to all' => 'Zoom to all layers.',
		'Select' => 'Set select mode.',
		'Edit' => 'Show the vertices or the objects.',
		'Move' => 'Set the move mode (move selected vertices).',
		'Shell' => 'Go back to Perl shell in the terminal.'
		);

    for (reverse('Open raster layer',
		 'Open vector layer',
		 'Zoom to all',
#		 'Select',
#		 'Edit',
#		 'Move',
#		 'Shell'
		 )) {

	my $b = Gtk2::ToolButton->new(undef,$_);

	my $tooltips = Gtk2::Tooltips->new;
	$b->set_tooltip($tooltips,$tips{$_},'');
	$tooltips->set_tip($b,$tips{$_});
	$tooltips->enable;

	$toolbar->insert($b,0);
	my $sub;
      SWITCH: {
	  if (/raster/) { $sub = 
			      sub { 
				  return unless $self->add_raster();
				  $self->{tree_view}->set_cursor(Gtk2::TreePath->new(0));
			      }; last SWITCH; }
	  if (/vector/) { $sub = 
			      sub { 
				  return unless $self->add_vector();
				  $self->{tree_view}->set_cursor(Gtk2::TreePath->new(0));
			      }; last SWITCH; }
	  if (/^Zoom to all/) { $sub = 
				    sub { 
					$self->{overlay}->zoom_to_all(); 
				    }; last SWITCH; }
	  if (/^Select/) { $sub = 
			       sub { 
				   $self->{overlay}->{rubberbanding} = 'select rect';
				   $self->{overlay}->event_handler();
			       }; last SWITCH; }
	  if (/^Edit/) { $sub = 
			     sub { 
				 my $layer = $self->get_selected_layer();
				 if (ref($layer) eq 'Geo::Shapelib' or 
				     ref($layer) eq 'Geo::Vector') {
				     $layer->{ShowPoints} = $layer->{ShowPoints} ? 0 : 1;
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

sub inspect {
    my ($self,$data,$name) = @_;

    my $dialog = $self->{glade}->get_widget('dialog1');
    $name = $data->{name} if ref($data) and ref($data) =~ /^Geo/;
    $name = '' unless $name;
    $dialog->set_title($name);

    $data = \$data unless ref $data;

    my $treedumper = Data::TreeDumper::Renderer::GTK->new
	(data => $data,
	 title => $name,
	 dumper_setup => {});

    $treedumper->modify_font(Gtk2::Pango::FontDescription->from_string ('monospace'));
    $treedumper->collapse_all;

    my $scroller = $self->{glade}->get_widget('scrolledwindow2');
    $scroller->remove($self->{treedumper}) if $self->{treedumper};

    $self->{treedumper} = $treedumper;
    $scroller->add($treedumper);

    $dialog->move(@{$self->{dialog1_position}}) if $self->{dialog1_position}; # for WinAxe
    $dialog->show_all;
}

=pod

=head2 add_raster

calls Gtk2::FileChooserDialog and if a file of known type is selected,
opens it and adds it by calling add_layer

=cut

sub add_raster {
    my($self) = @_;

    my $file_chooser =
	Gtk2::FileChooserDialog->new ('Select a spatial data file',
				      undef, 'open',
				      'gtk-cancel' => 'cancel',
				      'gtk-ok' => 'ok');

    $file_chooser->set_select_multiple(1);

    my $folder = $file_chooser->get_current_folder;

    $file_chooser->set_current_folder($self->{add_from_folder}) if $self->{add_from_folder};

    my $filename;
    my @filenames;
    
    if ('ok' eq $file_chooser->run) {
	# you can get the user's selection as a filename or a uri.
	$self->{add_from_folder} = $file_chooser->get_current_folder;
#	$filename = $file_chooser->get_filename;
	@filenames = $file_chooser->get_filenames;
    }

    $file_chooser->set_current_folder($folder);
    
    $file_chooser->destroy;

#    return unless $filename;
    return unless @filenames;

    for $filename (@filenames) {
	my $layer;

	eval {
	    $layer = new Geo::Raster $filename;
	};
	if ($@) {
	    my $err = "Not a raster: ".$@;
	    if ($@) {
		$err =~ s/\n/ /g;
		$err =~ s/\s+$//;
		$err =~ s/\s+/ /g;
		$err =~ s/^\s+$//;		
		croak("$filename is not recognized by GDAL: $err");
		next;
	    }
	}
	
	my $name = fileparse($filename);
	$name =~ s/\.\w+$//;
	$self->add_layer($layer, $name, 1);
	$self->{overlay}->render;
    }
    
    return 1;
}

sub add_vector {
    my($self) = @_;

    my $folder = $self->{add_from_folder};

    my ($datasource,$layer_name,$sql) = $self->{ogr_dialog}->ogr_open($self);

    return unless $layer_name;
    
    $self->{add_from_folder} = $self->{ogr_dialog}->get_current_folder();

    my $layer;

    eval {
	$layer = new Geo::Vector datasource=>$datasource,layer=>$layer_name,sql=>$sql;
    };
    if ($@) {
	if ($err) {
	    $err =~ s/\n/ /g;
	    $err =~ s/\s+$//;
	    $err =~ s/\s+/ /g;
	    $err =~ s/^\s+$//;
	} else {
	    $err = 'unspecified error';
	}
	croak("Could not open a layer: $err");
	return;
    }

    $self->add_layer($layer, $layer_name, 1);
    $self->{overlay}->render;

    return 1;
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
    my $gd = $self->selected_layer();
    return unless $gd;
    return unless ref($gd) eq 'Geo::Raster';
    my @va = $self->{overlay}->visible_area;
    @va = $gd->wa2ga(@va);
    return $gd->clip(@va);
}

sub set_layer {
    my($self,$layer) = @_;
    my($type,$colors,$visible,$alpha);

    $type = '';
    $alpha = defined $layer->{alpha} ? $layer->{alpha} : 255;

    if (ref($layer) eq 'Geo::Raster') {

	$type = $layer->{DATATYPE} == $Geo::Raster::INTEGER_GRID ? 'int' : 'real'
	    if defined $layer->{DATATYPE};

	$alpha = 'Layer' if ref($alpha);

    } elsif (ref($layer) eq 'Gtk2::Ex::Geo::Composite') {

	$type = $layer->{type};
	
    } elsif (ref($layer) eq 'Geo::Vector') {

	$type = 'ogr';

    } else {
	croak "unknown layer type ref($layer)";
    }

    $visible = $layer->{hidden} ? ' ' : 'X';

    $self->{model}->set ($layer->{iterator},
			 0, $layer->{name},
			 1, $type,
			 2, $visible,
			 3, $alpha,
			 );
}

=pod

=head2 add_layer($layer,$name,$do_not_zoom_to);

adds $layer with $name to overlay and model

the default behavior is to zoom to the new layer

=cut

sub add_layer {
    my($self,$layer,$name,$do_not_zoom_to) = @_;
    return unless $layer;
    return unless ref($layer) =~ /Geo::/;

    $layer->{alpha} = 255;
    $layer->{iterator} = $self->{model}->insert (undef, 0);
    $layer->{name} = $name;

    $self->set_layer($layer);
    $self->{overlay}->add_layer($layer,$do_not_zoom_to);
}

=pod

=head2 get_focal($name)

returns a clipped part of a raster layer by its name

todo: same for vector layers

=cut

sub get_focal {
    my($self,$name) = @_;
    my $gd = $self->{overlay}->get_layer_by_name($name);
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

=head2 update

updates the tree_view

=cut

sub update {
    my($self) = @_;
    for my $layer (@{$self->{overlay}->{layers}}) {
	$self->set_layer($layer);
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
    my $n = $#{$self->{overlay}->{layers}};
    if ($index < $n) {
	my($layer1,$layer2) = swap($self->{overlay}->{layers},$n-$index,$n-$index-1);
	$self->{model}->move_after($layer1->{iterator},$layer2->{iterator});
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
    my $n = $#{$self->{overlay}->{layers}};
    if ($index > 0) {
	my($layer1,$layer2) = swap($self->{overlay}->{layers},$n-$index,$n-$index+1);
	$self->{model}->move_before($layer1->{iterator},$layer2->{iterator});
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
    my $n = $#{$self->{overlay}->{layers}};
    if ($index >= 0 and $index <= $n) {
	my($layer) = splice(@{$self->{overlay}->{layers}},$n-$index,1);
	$self->{model}->remove($layer->{iterator});
	if ($n > 0) {
	    $index-- if $index == $n;
	    $self->{tree_view}->set_cursor(Gtk2::TreePath->new($index));
	}
	$self->{overlay}->render;
    }
}

=pod

=head2 get_selected_layer

returns the selected layer

=cut

sub get_selected_layer {
    my($self) = @_;
    my ($path, $focus_column) = $self->{tree_view}->get_cursor;
    return unless $path;
    my $index = $path->to_string;
    return $self->{overlay}->get_layer_by_index($index);
}

=pod

=head2 event_handler

=cut

sub event_handler {
    my ($self,$event,@points) = @_;

    # select & move vertices is handled here

    if ($self->{overlay}->{selection}) {

	my $layer = $self->get_selected_layer();

	if (ref($layer) eq 'Geo::Shapelib') {

	    if ($self->{overlay}->{rubberbanding} =~ /select/ and $layer->{Rtree}) {

		my @selection = @{$self->{overlay}->{selection}};

		my @shapes;

		$layer->{Rtree}->query_completely_within_rect(@selection,\@shapes);
		print "you selected shapes: @shapes\n";

		@shapes = ();
		$layer->{Rtree}->query_partly_within_rect(@selection,\@shapes);
		print "shapes: @shapes overlap with the selection\n";
		
		# undo all

		$layer->clear_selections();
		
		# here find the vertices in the selection

		for my $shape (@shapes) {
		    my $vertices = $layer->select_vertices($shape,@selection);
		    my $n = @$vertices;
		    print "you selected $n vertices from shape $shape\n";
		}
		
	    } elsif ($self->{overlay}->{rubberbanding} =~ /move/) {

		my($fromx,$fromy,$dx,$dy) = @{$self->{overlay}->{selection}};

		$layer->move_selected_vertices($dx,$dy);

	    }

	    $self->{overlay}->render();

	}
	
    }

    return unless $self->{event_handler};
    $self->{event_handler}->($self->{event_handler_user_param},$event,@points);
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
    
    my $text = $entry->get_text;
    $self->{history}->[$self->{history_index}] = $text;

    if ($text ne '' and $key == 65293) {

	push @{$self->{history}}, '' unless $self->{history}->[$#{$self->{history}}] eq '';
	$self->{history_index} = $#{$self->{history}};
	$entry->set_text('');

	my $focal = 0; # default is global
	if ($text =~ /^focal:\s*/) {
	    $text =~ s/^focal:\s*//;
	    $focal = 1;
	}
	my @g = $text =~ /\$(\w+)/g;
	my @_gd;
	for my $i (0..$#g) {
	    $_gd[$i] = $focal ? $self->get_focal($g[$i]) : $self->{overlay}->get_layer_by_name($g[$i]);
	    next unless $_gd[$i];
	    $text =~ s/\$$g[$i]\b/\$_gd[$i]/;
	}
	{
	    no strict; # this does not do the trick and no strict 'refs' is not enough!!
#	    no warnings;
	    eval $text;
	    croak "$text\n$@" if $@;
	}
	for my $i (0..$#g) {
	    if ($self->{overlay}->get_layer_by_name($g[$i])) {
		$_gd[$i]->getminmax() if ref($_gd[$i]) =~ /^Geo::Raster/;
	    } else {
		eval "\$self->add_layer(\$$g[$i],'$g[$i]',1) if ref(\$$g[$i]) =~ /Geo::/;"
		    if $g[$i] and $g[$i] ne 'self';
	    }
	}
	undef @_gd;
	$self->update();
	$self->{overlay}->render;
	return 1;
    } elsif ($key == 65362) { # arrow up, history?
	$self->{history_index} = max(0, $self->{history_index}-1);
	$entry->set_text($self->{history}->[$self->{history_index}]);
	return 1;
    } elsif ($key == 65364) {
	$self->{history_index} = min($#{$self->{history}}, $self->{history_index}+1);
	$entry->set_text($self->{history}->[$self->{history_index}]);
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
    my($self) = @_;
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

1;
__DATA__
<?xml version="1.0" standalone="no"?> <!--*- mode: xml -*-->
<!DOCTYPE glade-interface SYSTEM "http://glade.gnome.org/glade-2.0.dtd">

<glade-interface>

<widget class="GtkDialog" id="dialog1">
  <property name="width_request">250</property>
  <property name="height_request">400</property>
  <property name="title" translatable="yes">dialog1</property>
  <property name="type">GTK_WINDOW_TOPLEVEL</property>
  <property name="window_position">GTK_WIN_POS_NONE</property>
  <property name="modal">False</property>
  <property name="resizable">True</property>
  <property name="destroy_with_parent">False</property>
  <property name="decorated">True</property>
  <property name="skip_taskbar_hint">False</property>
  <property name="skip_pager_hint">False</property>
  <property name="type_hint">GDK_WINDOW_TYPE_HINT_DIALOG</property>
  <property name="gravity">GDK_GRAVITY_NORTH_WEST</property>
  <property name="has_separator">True</property>

  <child internal-child="vbox">
    <widget class="GtkVBox" id="dialog-vbox4">
      <property name="visible">True</property>
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area4">
	  <property name="visible">True</property>
	  <property name="layout_style">GTK_BUTTONBOX_END</property>

	  <child>
	    <widget class="GtkButton" id="closebutton1">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-close</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-7</property>
	    </widget>
	  </child>
	</widget>
	<packing>
	  <property name="padding">0</property>
	  <property name="expand">False</property>
	  <property name="fill">True</property>
	  <property name="pack_type">GTK_PACK_END</property>
	</packing>
      </child>

      <child>
	<widget class="GtkScrolledWindow" id="scrolledwindow2">
	  <property name="visible">True</property>
	  <property name="can_focus">True</property>
	  <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
	  <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
	  <property name="shadow_type">GTK_SHADOW_NONE</property>
	  <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

	  <child>
	    <placeholder/>
	  </child>
	</widget>
	<packing>
	  <property name="padding">0</property>
	  <property name="expand">True</property>
	  <property name="fill">True</property>
	</packing>
      </child>
    </widget>
  </child>
</widget>

</glade-interface>
