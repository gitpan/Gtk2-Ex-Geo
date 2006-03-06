package Gtk2::Ex::Geo::Overlay;

use strict;
use POSIX;
use Carp;
use Glib qw/TRUE FALSE/;
use Gtk2::Gdk::Keysyms;
use Gtk2;
use Geo::Raster;
use Gtk2::Ex::Geo::Renderer;

=pod

=head1 NAME

Gtk2::Ex::Geo::Overlay - A Gtk2 widget for a visual overlay of geospatial data

=head1 SYNOPSIS

my $overlay = Gtk2::Ex::Geo::Overlay->new;

$overlay->my_inits;

=head1 DESCRIPTION

Gtk2::Ex::Geo::Overlay is a subclass of Gtk2::ScrolledWindow

=head1 ATTRIBUTES

public:

bg_color = ($red, $green, $blue) # a color for the background for the overlay

rubberbanding = FALSE, /line/, /rect/, /circle/ 

private:

image
event_box
zoom_factor
step

=head1 METHODS

=cut

my %visual_keys = ($Gtk2::Gdk::Keysyms{plus}=>1,
		   $Gtk2::Gdk::Keysyms{minus}=>1,
		   $Gtk2::Gdk::Keysyms{Right}=>1,
		   $Gtk2::Gdk::Keysyms{Left}=>1,
		   $Gtk2::Gdk::Keysyms{Up}=>1,
		   $Gtk2::Gdk::Keysyms{Down}=>1);


use Glib::Object::Subclass
    Gtk2::ScrolledWindow::,
    signals => {
	# hmm.. empty ... probably I'm not using the signal system correctly...
    },
    properties => [
		   Glib::ParamSpec->double (
					    'zoom_factor', 'Zoom factor', 
					    'Zoom multiplier when user presses + or -',
					    0.1, 1000, 1.2, [qw/readable writable/]
					    ),
		   Glib::ParamSpec->double (
					    'step', 'Step', 
					    'One step when scrolling is window width/height divided by step',
					    1, 100, 8, [qw/readable writable/]
					    ),

		   ]
    ;

sub INIT_INSTANCE {

    my $self = shift;

    $self->{image} = Gtk2::Image->new;

    $self->{image}->set_size_request(0,0);

    $self->{event_box} = Gtk2::EventBox->new;

    $self->{event_box}->add($self->{image});

    $self->{event_box}->signal_connect(button_press_event => \&button_press_event, $self);
    $self->{event_box}->signal_connect(button_release_event => \&button_release_event, $self);

    $self->{event_box}->add_events('pointer-motion-mask');
    $self->{event_box}->signal_connect(motion_notify_event => \&motion_notify, $self);

    $self->signal_connect(key_press_event => \&key_press_event, $self);

    # why do not these work? 
    # event box does not have focus? does not accept focus? does not accept key presses?
#    $self->{event_box}->add_events('key-press-mask');
#    $self->{event_box}->signal_connect(key_press_event => \&key_press_event, $self);
        
    # why do I need to set these?
    $self->{zoom_factor} = 1.2;
    $self->{step} = 8;

    $self->{w_offset} = 0;
    $self->{h_offset} = 0;
    @{$self->{bg_color}} = (0,0,0);

}

=pod

=head2 my_inits

some initializations which cannot be done automagically (for some reason unknown to me...)

=cut

sub my_inits {
    my($self) = @_;
    
    $self->{ha} = $self->get_hadjustment();
    $self->{va} = $self->get_vadjustment();

    $self->{ha}->signal_connect("value-changed" => \&value_changed, $self);
    $self->{va}->signal_connect("value-changed" => \&value_changed, $self);
    
    $self->{ha}->signal_connect("changed" => \&changed, $self);
    $self->{va}->signal_connect("changed" => \&changed, $self);

    $self->add_with_viewport($self->{event_box});
}

=pod

=head2 add_layer($layer,$do_not_zoom_to);

adds a spatial data layer to the top of the overlay, the default
behavior is to zoom to the new layer

=cut

sub add_layer {
    my($self,$layer,$do_not_zoom_to) = @_;
    my $ref = ref($layer);
    return unless $ref =~ /Geo::/;
    push @{$self->{layers}},$layer;

    # MUST zoom to if this is the first layer
    $do_not_zoom_to = 0 if @{$self->{layers}} == 1; 

    $self->my_inits unless $self->{ha};
    unless ($do_not_zoom_to) {
	$self->zoom_to($layer);
	$self->set_adjustments();
	$self->render();
    }
    return $#{$self->{layers}};

}

=pod

=head2 layer_count

=head2 get_layer_by_index($index)

=head2 get_layer_by_name($name)

returns a layer by its index (top = 0) or name

=cut

sub layer_count {
    my($self) = @_;
    my $count = @{$self->{layers}};
    return $count;
}

sub get_layer_by_index {
    my($self,$index) = @_;
    return unless $index >= 0 and $index <= $#{$self->{layers}};
    return $self->{layers}->[$#{$self->{layers}} - $index];
}

sub get_layer_by_name {
    my($self,$name) = @_;
    for my $layer (@{$self->{layers}}) {
	return $layer if $layer->{name} eq $name;
    }
}

=pod

=head2 zoom_to($layer) or zoom_to($minx,$miny,$maxx,$maxy)

sets the given bounding box as the world

=cut

sub zoom_to {
    # usage: ->zoom_to(layer) or ->zoom_to(minX,minY,maxX,maxY)

    my $self = shift;

    # up left (minX,maxY) is fixed, adjust maxX or minY

    my @bounds; # minX,minY,maxX,maxY

    if (@_ == 1) {
	my $layer = shift;
	return unless $self->{layers} and @{$self->{layers}};
	if (ref($layer) eq 'Geo::Raster' or ref($layer) eq 'Geo::Vector') {
	    @bounds = $layer->world(1);
	} elsif (ref($layer) eq 'Geo::Shapelib') {
	    @bounds[0..1] = @{$layer->{MinBounds}}[0..1];
	    @bounds[2..3] = @{$layer->{MaxBounds}}[0..1];
	} else {
	    return;
	}
    } else {
	@bounds = @_;
    }

    my $ws = $self->{ha}->page_size();
    my $hs = $self->{va}->page_size();
    $self->{canvas_size} = [$ws,$hs];
    $self->{pixel_size} = max(($bounds[2]-$bounds[0])/$ws,($bounds[3]-$bounds[1])/$hs);
    
    $self->{minX} = $bounds[0];
    $self->{maxY} = $bounds[3];
    $self->{maxX} = $bounds[0]+$self->{pixel_size}*$ws;
    $self->{minY} = $bounds[3]-$self->{pixel_size}*$hs;

    $self->{ha}->lower(0);
    $self->{ha}->upper($ws);
    $self->{ha}->value(0);
    
    $self->{va}->lower(0);
    $self->{va}->upper($hs);
    $self->{va}->value(0);

    $self->set_adjustments();
    $self->render();
}

=pod

=head2 zoom_to_all

sets the bounding box which bounds all layers as the world

=cut

sub zoom_to_all {
    my($self) = @_;
    return unless $self->{layers} and @{$self->{layers}};
    my @size;
    for my $layer (@{$self->{layers}}) {
	my @s;
	if (ref($layer) eq 'Geo::Raster' or ref($layer) eq 'Geo::Vector') {
	    @s = $layer->world(1);
	} elsif (ref($layer) eq 'Geo::Shapelib') {
	    $s[0] = $layer->{MinBounds}->[0];
	    $s[1] = $layer->{MinBounds}->[1];
	    $s[2] = $layer->{MaxBounds}->[0];
	    $s[3] = $layer->{MaxBounds}->[1];
	}
	if (@size) {
	    $size[0] = min($size[0],$s[0]);
	    $size[1] = min($size[1],$s[1]);
	    $size[2] = max($size[2],$s[2]);
	    $size[3] = max($size[3],$s[3]);
	} else {
	    @size = @s;
	}
    }
    $self->zoom_to(@size) if @size;
}

=pod

=head2 set_event_handler($event_handler,$user_param)

sets a subroutine which gets called when something happens in the
widget, the sub is called like this:
$event_handler->($user_param,$event,@xy);

=cut

sub set_event_handler {
    my($self,$event_handler,$user_param) = @_;
    $self->{event_handler} = $event_handler;
    $self->{event_handler_user_param} = $user_param;
}

=pod

=head2 set_draw_on($draw_on,$user_param)

sets a subroutine which gets called whenever a new pixmap is drawn for
the widget, the sub is called like this:
$draw_on->($user_param,$pixmap);

=cut

sub set_draw_on {
    my($self,$draw_on,$user_param) = @_;
    $self->{draw_on} = $draw_on;
    $self->{draw_on_user_param} = $user_param;
}

sub set_adjustments {
    my($self) = @_;

    $self->{w_max} = $self->{ha}->upper() - $self->{ha}->page_size();
    $self->{h_max} = $self->{va}->upper() - $self->{va}->page_size();

    @{$self->{viewport_size}} = (int($self->{ha}->page_size),int($self->{va}->page_size));

    $self->{w_offset} = $self->{ha}->value();
    $self->{h_offset} = $self->{va}->value();
}

sub value_changed {
    my($adjustment,$self) = @_;

    my $w_offset = $self->{w_offset};
    my $h_offset = $self->{h_offset};

    $self->set_adjustments();

    return if $w_offset == $self->{w_offset} and $h_offset == $self->{h_offset};

    $self->render();

}

sub changed {
    my($adjustment,$self) = @_;
    
    return unless $self->{viewport_size}; # not yet operational

    my @tmp = @{$self->{viewport_size}};

    $self->set_adjustments();

    return if $tmp[0] == $self->{viewport_size}->[0] and $tmp[1] == $self->{viewport_size}->[1];

    $self->render();
}

# provided for the user: (in world coordinates)

=pod

=head2 visible_area

returns ($minx,$maxy,$maxx,$miny), the visible area of the world

=cut

sub visible_area {
    my($self) = @_;
    my @ul = ($self->{minX}+$self->{w_offset}*$self->{pixel_size},
	      $self->{maxY}-$self->{h_offset}*$self->{pixel_size});
    my @dr = ($ul[0]+$self->{viewport_size}->[0]*$self->{pixel_size},
	      $ul[1]-$self->{viewport_size}->[1]*$self->{pixel_size});
    return (@ul,@dr);
}

=pod

=head2 render(key=>value,..)

Does the actual rendering by calling (creating) a new
Gtk2::Ex::Geo::Renderer object. Currently used parameters:

reuse_pixbuf=>boolean

    whether to render the layers

filename=>filename, type=>type

    if filename is set, calls pixbuf->save with given options

do_not_draw_selection=>boolean

    prevents drawing of the selection (only for internal use)

=cut

sub render {
    my $self = shift;
    my %opt = @_;

    return unless $self->{layers} and @{$self->{layers}};

    my $xalign = $self->{w_max} == 0 ? 0 : $self->{ha}->value()/$self->{w_max};
    my $yalign = $self->{h_max} == 0 ? 0 : $self->{va}->value()/$self->{h_max};

    $xalign = max(min($xalign,1),0);
    $yalign = max(min($yalign,1),0);

    $self->{pixbuf} = Gtk2::Ex::Geo::Renderer->new($self->{layers},
						   $self->{minX},$self->{maxY},$self->{pixel_size},
						   @{$self->{viewport_size}},
						   $self->{w_offset},$self->{h_offset},
						   @{$self->{bg_color}}) unless $opt{reuse_pixbuf};
    
    $self->{pixbuf}->save(@_) if $opt{filename};
    
    $self->{pixmap} = $self->{pixbuf}->render_pixmap_and_mask(0);
    $self->{image}->set_from_pixmap($self->{pixmap},undef);
    $self->{image}->set_size_request(@{$self->{canvas_size}});
    $self->{image}->set_alignment($xalign,$yalign);
    
    $self->{draw_on}->($self->{draw_on_user_param},$self->{pixmap}) if $self->{draw_on};

    $self->draw_selection if $self->{selection} and not $opt{do_not_draw_selection};

# call set from pixmap here?
    
}

sub draw_selection {
    my($self) = @_;
    my @p = $self->point2pixmap_pixel(@{$self->{selection}}[0..1]);
    my @q = $self->point2pixmap_pixel(@{$self->{selection}}[2..3]);
    my $gc = new Gtk2::Gdk::GC $self->{pixmap};
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,65535,0));
    $gc->set_line_attributes(2,'GDK_LINE_ON_OFF_DASH','GDK_CAP_NOT_LAST','GDK_JOIN_MITER');
    $self->{pixmap}->draw_rectangle($gc,0,$p[0],$q[1],$q[0]-$p[0],$p[1]-$q[1]);
}

=pod

=head2 zoom($w_offset,$h_offset,$pixel_size)

select a part of the world into the visible area

=cut

sub zoom {
    my($self,$w_offset,$h_offset,$pixel_size) = @_;

    $self->{w_offset} = $w_offset;
    $self->{h_offset} = $h_offset;
    $self->{pixel_size} = $pixel_size;

    my $w = ($self->{maxX}-$self->{minX})/$self->{pixel_size};
    my $h = ($self->{maxY}-$self->{minY})/$self->{pixel_size};

    $self->{ha}->upper(max($w,$self->{ha}->page_size()));
    $self->{va}->upper(max($h,$self->{va}->page_size()));

    $w = $self->{ha}->upper();
    $h = $self->{va}->upper();
    $self->{canvas_size} = [$w,$h];
    
    $self->{w_max} = max($w - $self->{ha}->page_size(),0);
    $self->{h_max} = max($h - $self->{va}->page_size(),0);
    
    $self->{w_offset} = max(min($self->{w_offset},$self->{w_max}),0);
    $self->{h_offset} = max(min($self->{h_offset},$self->{h_max}),0);
    
    $self->{ha}->value($self->{w_offset});
    $self->{va}->value($self->{h_offset});
    
    $self->set_adjustments();
    $self->render();
}

sub _zoom { 
    my($self,$in,$event,$center_x,$center_y) = @_;

    return unless $self->{layers} and @{$self->{layers}};

    my $old_w_offset = $self->{w_offset};
    my $old_h_offset = $self->{h_offset};

    # the center point should stay where it is unless center is not defined
    $center_x = $self->{minX} + ($self->{w_offset}+$self->{viewport_size}->[0]/2)*$self->{pixel_size} unless defined $center_x;
    $center_y = $self->{maxY} - ($self->{h_offset}+$self->{viewport_size}->[1]/2)*$self->{pixel_size} unless defined $center_y;

    $self->{pixel_size} = $in ? $self->{pixel_size} / $self->{zoom_factor} : $self->{pixel_size} * $self->{zoom_factor};

    $self->{w_offset} = int(($center_x - $self->{minX})/$self->{pixel_size} - $self->{viewport_size}->[0]/2);
    $self->{h_offset} = int(($self->{maxY} - $center_y)/$self->{pixel_size} - $self->{viewport_size}->[1]/2);

    $self->zoom($self->{w_offset},$self->{h_offset},$self->{pixel_size});

    $self->{event_coordinates}->[0] += $self->{w_offset} - $old_w_offset;
    $self->{event_coordinates}->[1] += $self->{h_offset} - $old_h_offset;
    $self->event_handler($event) if $event;
}

=pod

=head2 zoom_in($event,$center_x,$center_y)

zooms in a zoom_factor amount

=cut

sub zoom_in { 
    my($self,$event,$center_x,$center_y) = @_;
    $self->_zoom(1,$event,$center_x,$center_y);
}

=pod

=head2 zoom_out($event,$center_x,$center_y)

zooms out a zoom_factor amount

note: may enlarge the world

=cut

sub zoom_out { 
    my($self,$event,$center_x,$center_y) = @_;
    if ($self->{w_offset} == 0 and $self->{h_offset} == 0) {
	my $dx = ($self->{maxX}-$self->{minX})*$self->{zoom_factor}/6.0;
	my $dy = ($self->{maxY}-$self->{minY})*$self->{zoom_factor}/6.0;
	$self->zoom_to($self->{minX}-$dx,$self->{minY}-$dy,$self->{maxX}+$dx,$self->{maxY}+$dy);
    } else {
	$self->_zoom(0,$event,$center_x,$center_y);
    }
}

=pod

=head2 pan($w_move,$h_move,$event)

pans the viewport

=cut

sub pan {
    my($self,$w_move,$h_move,$event) = @_;

    $self->{event_coordinates}->[0] += floor($w_move);
    $self->{event_coordinates}->[1] += floor($h_move);

    my $new_w_offset = $self->{w_offset} + floor($w_move);
    my $new_h_offset = $self->{h_offset} + floor($h_move);

    $new_w_offset = max(min($new_w_offset,$self->{w_max}),0);
    $new_h_offset = max(min($new_h_offset,$self->{h_max}),0);

#    return if ($new_w_offset == $self->{w_offset} and $new_h_offset == $self->{h_offset});

    $self->{w_offset} = $new_w_offset;
    $self->{ha}->value($self->{w_offset});
    $self->{h_offset} = $new_h_offset;
    $self->{va}->value($self->{h_offset});

    $self->set_adjustments();

    $self->render();

    $self->event_handler($event) if $event;
}

=pod

=head2 internal handling of key and button events

+ => zoom_in
- => zoom_out
arrow keys => pan 

the attribute rubberbanding defines what is done with button press,
move and release

=cut

sub key_press_event {
    my($self,$event) = @_;

    return unless $self->{layers} and @{$self->{layers}};
    
    # if this were an event box handler like button press
#    my(undef,$event,$self) = @_;

    my $key = $event->keyval;
    if ($key == $Gtk2::Gdk::Keysyms{plus}) {
	$self->zoom_in($event); # ,$self->event_pixel2point());
    } elsif ($key == $Gtk2::Gdk::Keysyms{minus}) {
	$self->zoom_out($event); # ,$self->event_pixel2point());
    } elsif ($key == $Gtk2::Gdk::Keysyms{Right}) {
	$self->pan($self->{viewport_size}->[0]/$self->{step},0,$event);
    } elsif ($key == $Gtk2::Gdk::Keysyms{Left}) {
	$self->pan(-$self->{viewport_size}->[0]/$self->{step},0,$event);
    } elsif ($key == $Gtk2::Gdk::Keysyms{Up}) {
	$self->pan(0,-$self->{viewport_size}->[1]/$self->{step},$event);
    } elsif ($key == $Gtk2::Gdk::Keysyms{Down}) {
	$self->pan(0,$self->{viewport_size}->[1]/$self->{step},$event);
    } else {
	$self->event_handler($event);
    }
       
}

# rubberbanding yes/no?
# if rubberbanding, what to draw when motion? line/rect/circle
# if rubberbanding, what to do when button release? (how to cancel?) pan/zoom/select

sub button_press_event {
    my(undef,$event,$self) = @_;

    return unless $self->{layers} and @{$self->{layers}};
    $self->grab_focus;

    if ($event->button == 3) {

	my $menu = Gtk2::Menu->new;

	my $zoom_mode = $self->{rubberbanding} =~ /zoom/;
	$zoom_mode = $zoom_mode ? ' v' : '';
	my $pan_mode = $self->{rubberbanding} =~ /pan/;
	$pan_mode = $pan_mode ? ' v' : '';
	my $select_mode = $self->{rubberbanding} =~ /select/;
	$select_mode = $select_mode ? ' v' : '';
	
	my @data = ('Zoom _in','Zoom _out','',
		    '_Zoom'.$zoom_mode,'_Pan'.$pan_mode,'_Select'.$select_mode,'_Clear selection','',
		    'Set _background color...',
		    '_Export as PNG');
	
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
	    $item->signal_connect(activate => \&context_menu_item, [$self, $data[$i]]);
	}
	$menu->popup(undef, undef, undef, undef, $event->button, $event->time);

    } elsif ($event->button == 1) {

	@{$self->{event_coordinates}} = ($event->x,$event->y);

	if ($self->{rubberbanding}) {
	    @{$self->{rubberband_begin}} = @{$self->{rubberband_coordinates}} = @{$self->{event_coordinates}};
	    $self->{rubberband_begin}->[0] -= $self->{w_offset};
	    $self->{rubberband_begin}->[1] -= $self->{h_offset};
	    $self->{rubberband} = [];
	    $self->{rubberband_gc} = Gtk2::Gdk::GC->new ($self->{pixmap});
	    $self->{rubberband_gc}->copy($self->style->fg_gc($self->state));
	    $self->{rubberband_gc}->set_function('invert');
	    
	    $self->render(reuse_pixbuf=>1, do_not_draw_selection=>1) if $self->{selection} and $self->{rubberbanding} =~ /select/;

	}

    }

    $self->event_handler($event);
}

sub context_menu_item {
    my ($item, $info) = @_;
    my $self = shift @$info;
    $_ = shift @$info;
    $_ =~ s/_//g;
  SWITCH: {
      if (/Zoom in/) {
	  $self->zoom_in();
	  last SWITCH; 
      }
      if (/Zoom out/) {
	  $self->zoom_out();
	  last SWITCH; 
      }
      if (/Zoom/) {
	  $self->{rubberbanding} = 'zoom rect';
	  $self->event_handler();
	  last SWITCH; 
      }
      if (/Pan/) {
	  $self->{rubberbanding} = 'pan line';
	  $self->event_handler();
	  last SWITCH; 
      }
      if (/Select/) {
	  $self->{rubberbanding} = 'select rect';
	  $self->event_handler();
	  last SWITCH; 
      }
      if (/Clear selection/) {
	  if ($self->{selection}) {
	      delete $self->{selection};
	      $self->render(reuse_pixbuf=>1);
	  }
      }
      if (/Set background color/) {

	  my $color = $self->{bg_color};
	  my $d = Gtk2::ColorSelectionDialog->new('Color for the background');
	  my $c = new Gtk2::Gdk::Color ($color ? $color->[0]*257 : 0,
					$color ? $color->[1]*257 : 0,
					$color ? $color->[2]*257 : 0);
	  $d->colorsel->set_current_color($c);
	  
	  if ($d->run eq 'ok') {
	      $c = $d->colorsel->get_current_color;
	      $self->{bg_color} = 
		  [int($c->red/257),int($c->green/257),int($c->blue/257)];
	      $self->render;
	  }
	  $d->destroy;

	  last SWITCH; 
      }
      if (/Export as PNG/) {

	  my $filename;
	  my $type = 'png';

	  my $file_chooser =
	      Gtk2::FileChooserDialog->new ('Export as a PNG image',
					    undef, 'save',
					    'gtk-cancel' => 'cancel',
					    'gtk-ok' => 'ok');

	  my $folder = $file_chooser->get_current_folder;

	  $file_chooser->set_current_folder($self->{folder}) if $self->{folder};
	  
	  if ('ok' eq $file_chooser->run) {
	      # you can get the user's selection as a filename or a uri.
	      $self->{folder} = $file_chooser->get_current_folder;
	      $filename = $file_chooser->get_filename;
	  }

	  $file_chooser->set_current_folder($folder);
    
	  $file_chooser->destroy;

	  $self->render(filename=>$filename, type=>$type) if $filename;

	  last SWITCH; 
      }   
  }
}

sub button_release_event {
    my(undef,$event,$self) = @_;
    
    return unless $self->{layers} and @{$self->{layers}};
    
    @{$self->{event_coordinates}} = ($event->x,$event->y);

    if ($self->{rubberbanding} and $self->{rubberband_begin}) {

	my @end = @{$self->{event_coordinates}};

	$end[0] -= $self->{w_offset};
	$end[1] -= $self->{h_offset};

	# erase & do pan or zoom 

	for ($self->{rubberbanding}) {
	    /line/ && do { 
		$self->{pixmap}->draw_line($self->{rubberband_gc},@{$self->{rubberband}}) if @{$self->{rubberband}};
	    };
	    /rect/ && do {
		$self->{pixmap}->draw_rectangle($self->{rubberband_gc},FALSE,@{$self->{rubberband}}) if @{$self->{rubberband}};
	    };
	    /circle/ && do {
		$self->{pixmap}->draw_arc($self->{rubberband_gc},FALSE,@{$self->{rubberband}},0,360) if @{$self->{rubberband}};
	    };

	    $self->{image}->set_from_pixmap($self->{pixmap},undef);

	    my @wbegin = ($self->{minX} + $self->{pixel_size} * ($self->{rubberband_coordinates}->[0]+0.5),
			  $self->{maxY} - $self->{pixel_size} * ($self->{rubberband_coordinates}->[1]+0.5));
	    
	    my @wend = ($self->{minX} + $self->{pixel_size} * ($self->{event_coordinates}->[0]+0.5),
			$self->{maxY} - $self->{pixel_size} * ($self->{event_coordinates}->[1]+0.5));

	    /pan/ && do {
		$self->pan($self->{rubberband_begin}->[0] - $end[0], $self->{rubberband_begin}->[1] - $end[1]);
	    };
	    /move/ && do {
		my @vector = ($wend[0]-$wbegin[0],$wend[1]-$wbegin[1]);

#		@{$self->{selection}} = ($wbegin[0],$wbegin[1],@vector);

#               gis should have an event_handler and that should take care of
#               moving of vertices of shapes when this function proceeds there

#               this class does not have a notion of a selected layer...
#		my ($selected,$selected_name) = $self->selected_layer();
#		if (ref($selected) eq 'Geo::Shapelib') {
#		    # the actual moving is in raster_window button_release_event $selected->move_selected(@vector);
#		    $self->{raster_window}->render();
#		}

	    };
	    /zoom/ && do {		
		my $w_offset = min($self->{rubberband_coordinates}->[0],$self->{event_coordinates}->[0]);
		my $h_offset = min($self->{rubberband_coordinates}->[1],$self->{event_coordinates}->[1]);
		
		if ($end[0] > $self->{rubberband_begin}->[0] and $end[1] > $self->{rubberband_begin}->[1]) {
		    
		    my $pixel_size = max(abs($wbegin[0]-$wend[0])/$self->{viewport_size}->[0],
					  abs($wbegin[1]-$wend[1])/$self->{viewport_size}->[1]);
		    
		    $w_offset = int(($wbegin[0]-$self->{minX})/$pixel_size);
		    $h_offset = int(($self->{maxY}-$wbegin[1])/$pixel_size);
		    
		    $self->zoom($w_offset,$h_offset,$pixel_size);
		    
		}
	    };
	    /select/ && do {

		# compute $self->{selection} in world coordinates
		@{$self->{selection}} = (min($wbegin[0],$wend[0]),min($wbegin[1],$wend[1]),
					 max($wbegin[0],$wend[0]),max($wbegin[1],$wend[1]));

		$self->draw_selection;
		
	    }
	}
	delete $self->{rubberband_begin};

	$self->event_handler($event);

    } else {

	$self->event_handler($event);
    }

}

sub motion_notify {
    my(undef,$event,$self) = @_;

    return unless $self->{layers} and @{$self->{layers}};

    @{$self->{event_coordinates}} = ($event->x,$event->y);

    if ($self->{rubberbanding} and $self->{rubberband_begin}) {

	my @end = @{$self->{event_coordinates}};

	$end[0] -= $self->{w_offset};
	$end[1] -= $self->{h_offset};

	# erase & draw

	for ($self->{rubberbanding}) {
	    /line/ && do { 
#		$self->{pixmap}->draw_line($self->{rubberband_gc},@{$self->{rubberband}}) if @{$self->{rubberband}};
		@{$self->{rubberband}} = (@{$self->{rubberband_begin}},@end);
#		$self->{pixmap}->draw_line($self->{rubberband_gc},@{$self->{rubberband}}); 

		my $x = $end[0] - $self->{rubberband_begin}->[0];
		my $y = $end[1] - $self->{rubberband_begin}->[1];
		my $gc = new Gtk2::Gdk::GC $self->{pixmap};
		$self->{pixmap}->draw_rectangle($gc,1,0,0,@{$self->{viewport_size}});
		$self->{pixmap}->draw_pixbuf($gc,$self->{pixbuf},0,0,$x,$y,-1,-1,'GDK_RGB_DITHER_NONE',0,0);
		
	    };
	    /rect/ && do {
		$self->{pixmap}->draw_rectangle($self->{rubberband_gc},FALSE,@{$self->{rubberband}}) if @{$self->{rubberband}};
		my $w = $end[0] - $self->{rubberband_begin}->[0];
		my $h = $end[1] - $self->{rubberband_begin}->[1];
		if ($w > 0 and $h > 0) {
		    @{$self->{rubberband}} = (@{$self->{rubberband_begin}},$w,$h);
		    $self->{pixmap}->draw_rectangle($self->{rubberband_gc},FALSE,@{$self->{rubberband}});
		} else {
		    $self->{rubberband} = [];
		}
	    };
	    /circle/ && do {
		$self->{pixmap}->draw_arc($self->{rubberband_gc},FALSE,@{$self->{rubberband}},0,360) if @{$self->{rubberband}};
		my $w = $end[0] - $self->{rubberband_begin}->[0];
		my $h = $end[1] - $self->{rubberband_begin}->[1];
		if ($w > 0 and $h > 0) {
		    @{$self->{rubberband}} = (@{$self->{rubberband_begin}},$w,$h);
		    $self->{pixmap}->draw_arc($self->{rubberband_gc},FALSE,@{$self->{rubberband}},0,360);
		} else {
		    $self->{rubberband} = [];
		}
	    };
	}
	
	$self->{image}->set_from_pixmap($self->{pixmap},undef);
    }
    
    $self->event_handler($event);
}

=pod

=head2 coordinate transforms

event_pixel2point => returns event coordinates as world coordinates

point2pixmap_pixel => returns world coordinates as pixmap pixel
coordinates

=cut

# from event coordinates to world coordinates
sub event_pixel2point {
    my($self,@pixel) = @_;
    return unless $self->{layers} and @{$self->{layers}};
    @pixel = @{$self->{event_coordinates}} unless @pixel;
    return ($self->{minX} + $self->{pixel_size} * ($pixel[0]+0.5),
	    $self->{maxY} - $self->{pixel_size} * ($pixel[1]+0.5));
}

# from world coordinates to the coordinates of the drawable
sub point2pixmap_pixel {
    my($self,@p) = @_;
    return (round(($p[0] - $self->{minX})/$self->{pixel_size} - 0.5 - $self->{w_offset}),
	    round(($self->{maxY} - $p[1])/$self->{pixel_size} - 0.5 - $self->{h_offset}));
}

sub event_handler {
    my($self,$event) = @_;
    return unless $self->{event_handler};
    my @xy = $self->event_pixel2point if $self->{event_coordinates};
    my @xy_begin;
    if ($self->{rubberband_begin}) {
	@xy_begin = @{$self->{rubberband_begin}};
	$xy_begin[0] += $self->{w_offset};
	$xy_begin[1] += $self->{h_offset};	
	@xy_begin = $self->event_pixel2point(@xy_begin);
    }
    $self->{event_handler}->($self->{event_handler_user_param},$event,@xy,@xy_begin);
}

sub min {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

sub max {
    $_[0] > $_[1] ? $_[0] : $_[1];
}

sub round {
    return int($_[0] + .5 * ($_[0] <=> 0));
}

1;
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
