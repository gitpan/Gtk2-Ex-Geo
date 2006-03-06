package Gtk2::Ex::Geo::GDALDialog;

use strict;
use warnings;

use Gtk2::GladeXML;
use Gtk2::Ex::Geo::OGRDialog;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
				   fill_colors_treeview	
				   get_colortable_from_dialog
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.43';

=pod

=head1 NAME

Gtk2::Ex::Geo::GDALDialog - Dialogs for raster (gdal) layers

=head1 SYNOPSIS

  use Gtk2::Ex::Geo::GDALDialog;

=head1 DESCRIPTION

=head2 EXPORT

:all exports &fill_colors_treeview and &get_colortable_from_dialog

=head1 METHODS

=head2 new

=cut

sub new {
    my $package = shift;
    my $self = {};

    $self->{path} = shift;

    @{$self->{buffer}} = <DATA>;
    $self->{glade} = Gtk2::GladeXML->new_from_buffer("@{$self->{buffer}}");

    bless $self => (ref($package) or $package);
    
    return $self;
}

=pod

=head2 bootstrap

=cut

sub bootstrap {
    my($self,$widget) = @_;
    $self->{glade} = Gtk2::GladeXML->new_from_buffer("@{$self->{buffer}}");
    return $self->{glade}->get_widget($widget);
}

=pod

=head2 layer_properties

=cut

sub layer_properties {
    my($self,$overlay,$layer) = @_;

    my $dialog = $self->{glade}->get_widget('properties_dialog');
    $dialog->set_title("Properties of $layer->{name}");
    my $a = $layer->{alpha};
    $a = 255 unless defined $a;
    $self->{glade}->get_widget('alpha_spinbutton')->set_value($a);

    $self->{glade}->get_widget('name_entry')->set_text("$layer->{name}");

    my @a = $layer->attributes();

    $self->{glade}->get_widget('size_lbl')->set_text("$a[1] $a[2]");

    $self->{glade}->get_widget('min_x_entry')->set_text($a[4]);
    $self->{glade}->get_widget('min_y_entry')->set_text($a[5]);
    $self->{glade}->get_widget('max_x_entry')->set_text($a[6]);
    $self->{glade}->get_widget('max_y_entry')->set_text($a[7]);

    $self->{glade}->get_widget('cellsize_entry')->set_text("$a[3]");
    $a = $a[8];
    $a = '' unless defined $a;
    $self->{glade}->get_widget('nodata_entry')->set_text($a);

    my ($minval,$maxval) = $layer->getminmax();
    $self->{glade}->get_widget('minmax_lbl')->set_text("$minval, $maxval");

    my $ret;

    $dialog->move(@{$self->{layer_properties_position}}) if $self->{layer_properties_position}; # for WinAxe
    $dialog->show_all;

    while (1) {

	my $response = $dialog->run;
	
	if ($response eq 'ok') {
	    
	    for my $k ('name','min_x','min_y','max_x','max_y','cellsize','nodata') {
		$ret->{$k} = $self->{glade}->get_widget($k.'_entry')->get_text;
	    }
	    $ret->{alpha} = $self->{glade}->get_widget('alpha_spinbutton')->get_value_as_int;

	    if ($ret->{nodata} ne $a) {
		$layer->nodata_value($ret->{nodata});
	    }

	    if ($ret->{min_x} ne $a[4] or 
		$ret->{min_y} ne $a[5] or 
		$ret->{max_x} ne $a[6] or 
		$ret->{max_y} ne $a[7] or 
		$ret->{cellsize} ne "$a[3]") {

		my ($minX,$minY) = ($ret->{min_x},$ret->{min_y});
		my ($maxX,$maxY) = ($ret->{max_x},$ret->{max_y});
		my $cell_size = $ret->{cellsize};

		for ($minX,$minY,$maxX,$maxY,$cell_size) {
		    $_ = undef if /^\s*$/;
		}

#		print STDERR "minX=>$minX,minY=>$minY,maxX=>$maxX,maxY=>$maxY,cell_size=>$cell_size\n";

		$layer->setbounds(minX=>$minX,minY=>$minY,maxX=>$maxX,maxY=>$maxY,cell_size=>$cell_size);

	    }
	    
	    last;

	} else { # cancel

	    last;

	}	

    }

    @{$self->{layer_properties_position}} = $dialog->get_position;
    $dialog->hide;

    return $ret;
    
}

=pod

=head2 layer_properties2

=cut

sub layer_properties2 {
    my($self,$overlay,$layer) = @_;

    my $glade = $self->{glade};

    my $dialog = $glade->get_widget('properties_dialog2');
    $dialog->set_title("Properties of $layer->{name}");

    $glade->get_widget('name_entry2')->set_text($layer->{name});
    my $a = $layer->{alpha};
    $a = 255 unless defined $a;
    $self->{glade}->get_widget('alpha_spinbutton2')->set_value($a);

    my $gdal = $layer->{GDAL};

    $glade->get_widget('gdal_size_label')->set_text("$gdal->{dataset}->{RasterYSize} $gdal->{dataset}->{RasterXSize}");

    $glade->get_widget('gdal_min_x_label')->set_text($gdal->{world}->[0]);
    $glade->get_widget('gdal_min_y_label')->set_text($gdal->{world}->[1]);
    $glade->get_widget('gdal_max_x_label')->set_text($gdal->{world}->[2]);
    $glade->get_widget('gdal_max_y_label')->set_text($gdal->{world}->[3]);

    $glade->get_widget('gdal_cellsize_label')->set_text($gdal->{cell_size});
    my $band = $gdal->{dataset}->GetRasterBand($gdal->{band});
    my $nodata = $band->GetNoDataValue;
    my ($minval,$maxval) = ($band->GetMinimum,$band->GetMaximum);

    my @a = $layer->attributes();
    $a[9] = 1;
    for (@a) {
	$_ = '' unless defined $_;
    }
    for ($nodata,$minval,$maxval,@a) {
	$_ = '' unless defined $_;
    }
    $glade->get_widget('gdal_nodata_entry2')->set_text($nodata);
    $glade->get_widget('gdal_minmax_label')->set_text("$minval, $maxval");
    
    $glade->get_widget('size_label')->set_text("$a[1] $a[2]");

    $glade->get_widget('min_x_label')->set_text($a[4]);
    $glade->get_widget('min_y_label')->set_text($a[5]);
    $glade->get_widget('max_x_label')->set_text($a[6]);
    $glade->get_widget('max_y_label')->set_text($a[7]);

    $glade->get_widget('cellsize_label')->set_text("$a[3]");
    $glade->get_widget('nodata_label')->set_text("$a[8]");

    ($minval,$maxval) = $layer->getminmax();
    for ($minval,$maxval) {
	$_ = '' unless defined $_;
    }
    $glade->get_widget('minmax_label')->set_text("$minval, $maxval");

    my $ret;

    $dialog->move(@{$self->{layer_properties2_position}}) if $self->{layer_properties2_position}; # for WinAxe
    $dialog->show_all;

    while (1) {

	my $response = $dialog->run;
	
	if ($response eq 'ok') {

	    for my $k ('name','gdal_nodata') {
		$ret->{$k} = $glade->get_widget($k.'_entry2')->get_text;
	    }
	    $ret->{alpha} = $self->{glade}->get_widget('alpha_spinbutton2')->get_value_as_int;
	    last;

	} else { # cancel

	    last;

	}	

    }

    @{$self->{layer_properties2_position}} = $dialog->get_position;
    $dialog->hide;

    return $ret;
    
}

=pod

=head2 colors_dialog

=cut

sub colors_dialog {
    my($self,$layer,$overlay) = @_;

    my $dialog = $self->{glade}->get_widget('colors_dialog');
    $dialog = $self->bootstrap('colors_dialog') unless $dialog;
    $dialog->set_title("Color table of $layer->{name}");

    $self->{overlay} = $overlay;

    $self->{color_table} = $layer->get_color_table(1);

    $self->{contents} = $layer->datatype eq 'integer' ? $layer->contents : {};

    my $scheme = $self->{glade}->get_widget('color_scheme_combobox');

    $scheme->set_active($layer->color_scheme());

    my $pal_min = $self->{glade}->get_widget('palette_min_entry');
    my $pal_max = $self->{glade}->get_widget('palette_max_entry');
    $pal_min->set_text(($layer->{PALETTE_MIN} or 0));
    $pal_max->set_text(($layer->{PALETTE_MAX} or 0));
    
    my $tv = $self->{glade}->get_widget('colortable_treeview');
    my $select = $tv->get_selection;
    $select->set_mode('multiple');

    my $model = Gtk2::TreeStore->new(qw/Glib::Int Glib::Int Glib::Int Glib::Int Glib::Int Glib::Int/);
    $tv->set_model($model);

    for ($tv->get_columns) {
	$tv->remove_column($_);
    }

    my $i = 0;
    foreach my $column ('value','pixels','red','green','blue','alpha') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    fill_colors_treeview(undef,$self);

    my @keys = sort {$a<=>$b} keys %{$self->{contents}};

    my @backup;
    for my $i (0..$self->{color_table}->GetCount-1) {
	my @c = $self->{color_table}->GetColorEntry($i);
	$backup[$i] = \@c;
    }
    my $pal_min_backup = $layer->{PALETTE_MIN};
    my $pal_max_backup = $layer->{PALETTE_MAX};
    my $scheme_backup = $layer->{COLOR_SCHEME};
    
    $dialog->move(@{$self->{colors_position}}) if $self->{colors_position}; # for WinAxe
    $dialog->show_all;

    while (1) {

	my $response = $dialog->run;

	$layer->{COLOR_SCHEME} = $scheme->get_active();
	$layer->{PALETTE_MIN} = $pal_min->get_text();
	$layer->{PALETTE_MAX} = $pal_max->get_text();

	if ($response eq 'apply') {

	    $overlay->render;
	
	} elsif ($response eq '1') { # color editor

	    my $sel = $tv->get_selection;
	    my @sel = $sel->get_selected_rows;
	    next unless @sel;

	    my $has_negative = 0;
	    for (@sel) {
		if ($keys[$_->to_string] < 0) {
		    $has_negative = 1;
		    last;
		}
	    }

	    if ($has_negative) {

		&Gtk2::Ex::Geo::OGRDialog::message("Can't have negative indexes in color table.");
		next

	    }
		
	    my $i = $sel[0]->to_string;
	    
	    my $d = Gtk2::ColorSelectionDialog->new('Choose color for selected entries');
	    my $s = $d->colorsel;
	    
	    my @color = $self->{color_table}->GetColorEntry($keys[$i]);
	    
	    $s->set_has_opacity_control(1);
	    my $c = new Gtk2::Gdk::Color ($color[0]*257,$color[1]*257,$color[2]*257);
	    $s->set_current_color($c);
	    $s->set_current_alpha($color[3]*257);
	    
	    if ($d->run eq 'ok') {
		$c = $s->get_current_color;
		@color = (int($c->red/257),int($c->green/257),int($c->blue/257));
		$color[3] = int($s->get_current_alpha()/257);
		
		for (@sel) {
		    my $i = $_->to_string;
		    $self->{color_table}->SetColorEntry($keys[$i],\@color);
		}
		
		fill_colors_treeview(undef,$self);
		$overlay->render;
	    }
	    $d->destroy;
	    
	    for (@sel) {
		$sel->select_path($_);
	    }

	} elsif ($response eq '2') { # copy colortable from 

	    if ($self->get_colortable_from_dialog($layer)) {
		
		fill_colors_treeview(undef,$self);
		$overlay->render;

	    }

	} elsif ($response eq 'cancel') {

	    my $ct = $layer->get_color_table(1);
	    for my $i (0..$ct->GetCount-1) {
		$ct->SetColorEntry($i, $backup[$i]);
	    }
	    $layer->{PALETTE_MIN} = $pal_min_backup;
	    $layer->{PALETTE_MAX} = $pal_max_backup;
	    $layer->{COLOR_SCHEME} = $scheme_backup;
	    
	    $overlay->render;
	    last;
	    
	} else {

	    $overlay->render;
	    last;

	}	

    }

    @{$self->{colors_position}} = $dialog->get_position;
    $dialog->hide;
}

=pod

=head2 fill_colors_treeview

=cut

sub fill_colors_treeview {
    my ($sp,$self) = @_;
    my $treeview = $self->{glade}->get_widget('colortable_treeview');
    my @columns = $treeview->get_columns;
    my $model = $treeview->get_model;
    $model->clear;
#    for my $i (0..$self->{color_table}->GetCount-1) {
    for my $i (sort {$a<=>$b} keys %{$self->{contents}}) {
	my @c;
	eval {
	    @c = $self->{color_table}->GetColorEntry($i);
	};
	if ($@) {
	    @c = (0,0,0,255);
	    $self->{color_table}->SetColorEntry($i,\@c);
	}
	my $iter = $model->insert(undef, 999999);
	my $j = 0;
	my @set = ($iter, $j++, $i);
	push @set, ($j++, $self->{contents}->{$i}) if @columns == 6;
	for my $k (0..3) {
	    push @set, ($j++, $c[$k]);
	}
	$model->set(@set);
    }
}

=pod

=head2 get_colortable_from_dialog

=cut

sub get_colortable_from_dialog {
    my($self,$to_layer) = @_;

    my $dialog = $self->{glade}->get_widget('colortable_from_dialog');
    my $tv = $self->{glade}->get_widget('colortable_from_treeview');

    my $model = Gtk2::TreeStore->new(qw/Glib::String/);
    $tv->set_model($model);

    for ($tv->get_columns) {
	$tv->remove_column($_);
    }

    my $i = 0;
    foreach my $column ('Raster') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    $model->clear;
    my @names;
    for my $layer (@{$self->{overlay}->{layers}}) {
	next if $layer->{name} eq $to_layer->{name};
	push @names, $layer->{name};
	$model->set ($model->insert (undef, 999999), 0, $layer->{name});
    }

    $dialog->move(@{$self->{get_colortable_from_position}}) if $self->{get_colortable_from_position};
    $dialog->show_all;

    my $response = $dialog->run;

    my $ret;

    if ($response eq 'ok') {

	my @sel = $tv->get_selection->get_selected_rows;
	if (@sel) {
	    my $i = $sel[0]->to_string if @sel;
	    my $from_layer = $self->{overlay}->get_layer_by_name($names[$i]);

	    my $from_ct = $from_layer->get_color_table(1);
	    my $to_ct = $to_layer->get_color_table(1);
	    
	    for $i (0..$from_ct->GetCount-1) {
		my @c = $from_ct->GetColorEntry($i);
		$to_ct->SetColorEntry($i, \@c);
	    }
	    $ret = 1;
	}
	
    }
    
    @{$self->{get_colortable_from_position}} = $dialog->get_position;
    $dialog->hide;

    return $ret;
}

=pod

=head2 clip_dialog

=cut

sub clip_dialog {
    my($self,$layer,$overlay) = @_;

    my $dialog = $self->{glade}->get_widget('clip_dialog');
    $dialog->set_title("Create a libral raster from $layer->{name}");

    $self->{glade}->get_widget('clip_name_entry')->set_text('gd');
    $self->cache_dim($layer,$overlay->visible_area(),$layer->{GDAL}->{cell_size});

    $dialog->move(@{$self->{clip_position}}) if $self->{clip_position};
    $dialog->show_all;

    my @ret;

    while (1) {

	my $response = $dialog->run;
	
	if ($response eq 'cancel') {
	    
	    last;

	} elsif ($response eq 'ok') {

	    my @dim = $self->cache_dim($layer);
	    @ret = ($self->{glade}->get_widget('clip_name_entry')->get_text, @dim);
	    last;
	    
	} elsif ($response eq '1') { # compute
	    
	    $self->cache_dim($layer);
	    
	} else { # cancel
	    
	    last;
	    
	}	

    }
    
    @{$self->{clip_position}} = $dialog->get_position;
    $dialog->hide;

    return @ret;
}

=pod

=head2 cache_dim

=cut

sub cache_dim {
    my($self,$layer,@dim) = @_;

    my $cellsize;

    if (@dim) {

	$self->{glade}->get_widget('clip_minx_entry')->set_text($dim[0]);
	$self->{glade}->get_widget('clip_miny_entry')->set_text($dim[3]);
	$self->{glade}->get_widget('clip_maxx_entry')->set_text($dim[2]);
	$self->{glade}->get_widget('clip_maxy_entry')->set_text($dim[1]);
	
	$self->{glade}->get_widget('clip_cellsize_label')->set_text($dim[4]);

	$cellsize = pop @dim;

    } else {

	@dim = ($self->{glade}->get_widget('clip_minx_entry')->get_text(),
		$self->{glade}->get_widget('clip_maxy_entry')->get_text(),
		$self->{glade}->get_widget('clip_maxx_entry')->get_text(),
		$self->{glade}->get_widget('clip_miny_entry')->get_text());
	$cellsize = $self->{glade}->get_widget('clip_cellsize_label')->get_text();
    }

    my $M = int(($dim[1] - $dim[3])/$cellsize)+1;
    my $N = int(($dim[2] - $dim[0])/$cellsize)+1;
    my $bytes = $layer->datatype eq 'integer' ? 2 : 4; # should look this upfrom libral
    my $size = $M*$N*$bytes;
    if ($size > 1024) {
	$size = int($size/1024);
	if ($size > 1024) {
	    $size = int($size/1024);
	    $size = "$size MiB";
	} else {
	    $size = "$size KiB";
	}
    } else {
	$size = "$size B";
    }

    $self->{glade}->get_widget('clip_info_label')->set_text("size of the (${M}x${N}) libral raster will be $size");

    return @dim;

}

sub min {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

sub max {
    $_[0] > $_[1] ? $_[0] : $_[1];
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

__DATA__
<?xml version="1.0" standalone="no"?> <!--*- mode: xml -*-->
<!DOCTYPE glade-interface SYSTEM "http://glade.gnome.org/glade-2.0.dtd">

<glade-interface>

<widget class="GtkDialog" id="colors_dialog">
  <property name="width_request">550</property>
  <property name="height_request">600</property>
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
    <widget class="GtkVBox" id="dialog-vbox1">
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area1">
	  <property name="layout_style">GTK_BUTTONBOX_END</property>

	  <child>
	    <widget class="GtkButton" id="copy_colortable_button">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">2</property>

	      <child>
		<widget class="GtkAlignment" id="alignment1">
		  <property name="visible">True</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xscale">0</property>
		  <property name="yscale">0</property>
		  <property name="top_padding">0</property>
		  <property name="bottom_padding">0</property>
		  <property name="left_padding">0</property>
		  <property name="right_padding">0</property>

		  <child>
		    <widget class="GtkHBox" id="hbox29">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">2</property>

		      <child>
			<widget class="GtkImage" id="image1">
			  <property name="visible">True</property>
			  <property name="stock">gtk-copy</property>
			  <property name="icon_size">4</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="label43">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">_Get colors</property>
			  <property name="use_underline">True</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		  </child>
		</widget>
	      </child>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="close_button">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">1</property>

	      <child>
		<widget class="GtkAlignment" id="alignment2">
		  <property name="visible">True</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xscale">0</property>
		  <property name="yscale">0</property>
		  <property name="top_padding">0</property>
		  <property name="bottom_padding">0</property>
		  <property name="left_padding">0</property>
		  <property name="right_padding">0</property>

		  <child>
		    <widget class="GtkHBox" id="hbox30">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">2</property>

		      <child>
			<widget class="GtkImage" id="image2">
			  <property name="visible">True</property>
			  <property name="stock">gtk-select-color</property>
			  <property name="icon_size">4</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="label44">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">C_olor</property>
			  <property name="use_underline">True</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		  </child>
		</widget>
	      </child>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="button3">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-apply</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-10</property>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="button5">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-cancel</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-6</property>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="button6">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-ok</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-5</property>
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
	<widget class="GtkVBox" id="vbox7">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkHBox" id="hbox41">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label66">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Coloring scheme: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkComboBox" id="color_scheme_combobox">
		  <property name="visible">True</property>
		  <property name="items" translatable="yes">Grayscale
Rainbow
Colortable</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">False</property>
	      <property name="fill">False</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox42">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label67">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Scalemin: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="palette_min_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="label68">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes"> Scalemax: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="palette_max_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">False</property>
	      <property name="fill">False</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkScrolledWindow" id="scrolledwindow1">
	      <property name="can_focus">True</property>
	      <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="shadow_type">GTK_SHADOW_IN</property>
	      <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

	      <child>
		<widget class="GtkTreeView" id="colortable_treeview">
		  <property name="can_focus">True</property>
		  <property name="headers_visible">True</property>
		  <property name="rules_hint">False</property>
		  <property name="reorderable">False</property>
		  <property name="enable_search">True</property>
		</widget>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
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

<widget class="GtkDialog" id="properties_dialog">
  <property name="title" translatable="yes">dialog2</property>
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
    <widget class="GtkVBox" id="dialog-vbox2">
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area2">
	  <property name="layout_style">GTK_BUTTONBOX_END</property>

	  <child>
	    <widget class="GtkButton" id="cancelbutton1">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-cancel</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-6</property>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="okbutton2">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-ok</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-5</property>
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
	<widget class="GtkVBox" id="vbox1">
	  <property name="border_width">5</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">10</property>

	  <child>
	    <widget class="GtkHBox" id="hbox6">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label17">
		  <property name="label" translatable="yes">Name: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="name_entry">
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">False</property>
	      <property name="fill">False</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox24">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label38">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Alpha: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkSpinButton" id="alpha_spinbutton">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="climb_rate">1</property>
		  <property name="digits">0</property>
		  <property name="numeric">False</property>
		  <property name="update_policy">GTK_UPDATE_ALWAYS</property>
		  <property name="snap_to_ticks">False</property>
		  <property name="wrap">False</property>
		  <property name="adjustment">1 0 255 1 10 10</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox1">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label2">
		  <property name="label" translatable="yes">Size: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="size_lbl">
		  <property name="label" translatable="yes">label3</property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox2">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label53">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Max y: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="max_y_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox28">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label54">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Min y: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="min_y_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox38">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label56">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Min x: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="min_x_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="label57">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes"> Max x: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="max_x_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox3">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label10">
		  <property name="label" translatable="yes">Cellsize: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="cellsize_entry">
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox4">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label12">
		  <property name="label" translatable="yes">Nodata: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="nodata_entry">
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox5">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label14">
		  <property name="label" translatable="yes">Min, Max: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="minmax_lbl">
		  <property name="label" translatable="yes">label15</property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
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

<widget class="GtkDialog" id="properties_dialog2">
  <property name="width_request">500</property>
  <property name="title" translatable="yes">dialog2</property>
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
    <widget class="GtkVBox" id="vbox2">
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="hbuttonbox1">
	  <property name="layout_style">GTK_BUTTONBOX_END</property>

	  <child>
	    <widget class="GtkButton" id="button1">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-cancel</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-6</property>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="button2">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-ok</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-5</property>
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
	<widget class="GtkVBox" id="vbox3">
	  <property name="border_width">5</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">5</property>

	  <child>
	    <widget class="GtkHBox" id="hbox12">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label25">
		  <property name="label" translatable="yes">Name:</property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="name_entry2">
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="label39">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">  Alpha: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkSpinButton" id="alpha_spinbutton2">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="climb_rate">1</property>
		  <property name="digits">0</property>
		  <property name="numeric">False</property>
		  <property name="update_policy">GTK_UPDATE_ALWAYS</property>
		  <property name="snap_to_ticks">False</property>
		  <property name="wrap">False</property>
		  <property name="adjustment">1 1 255 1 10 10</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">False</property>
	      <property name="fill">False</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox13">
	      <property name="homogeneous">False</property>
	      <property name="spacing">10</property>

	      <child>
		<widget class="GtkVBox" id="vbox4">
		  <property name="homogeneous">False</property>
		  <property name="spacing">5</property>

		  <child>
		    <widget class="GtkLabel" id="label26">
		      <property name="label" translatable="yes">&lt;b&gt;GDAL&lt;/b&gt;</property>
		      <property name="use_underline">False</property>
		      <property name="use_markup">True</property>
		      <property name="justify">GTK_JUSTIFY_LEFT</property>
		      <property name="wrap">False</property>
		      <property name="selectable">False</property>
		      <property name="xalign">0.5</property>
		      <property name="yalign">0.5</property>
		      <property name="xpad">0</property>
		      <property name="ypad">0</property>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">False</property>
		      <property name="fill">False</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox14">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label28">
			  <property name="label" translatable="yes">Size: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="gdal_size_label">
			  <property name="label" translatable="yes">label38</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox15">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label29">
			  <property name="label" translatable="yes">Max y: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="gdal_max_y_label">
			  <property name="label" translatable="yes">label39</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox26">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label40">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">Min y: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="gdal_min_y_label">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">label42</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox39">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label58">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">Min x: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="gdal_min_x_label">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">label59</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="label60">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes"> Max x: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="gdal_max_x_label">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">label61</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox16">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label30">
			  <property name="label" translatable="yes">Cellsize: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="gdal_cellsize_label">
			  <property name="label" translatable="yes">label40</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox17">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label31">
			  <property name="label" translatable="yes">Nodata: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkEntry" id="gdal_nodata_entry2">
			  <property name="width_request">50</property>
			  <property name="can_focus">True</property>
			  <property name="editable">True</property>
			  <property name="visibility">True</property>
			  <property name="max_length">0</property>
			  <property name="text" translatable="yes"></property>
			  <property name="has_frame">True</property>
			  <property name="invisible_char" translatable="yes">*</property>
			  <property name="activates_default">False</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">True</property>
			  <property name="fill">True</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox18">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label32">
			  <property name="label" translatable="yes">Min, Max: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="gdal_minmax_label">
			  <property name="label" translatable="yes">label41</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkVBox" id="vbox5">
		  <property name="homogeneous">False</property>
		  <property name="spacing">5</property>

		  <child>
		    <widget class="GtkLabel" id="label27">
		      <property name="label" translatable="yes">&lt;b&gt;libral&lt;/b&gt;</property>
		      <property name="use_underline">False</property>
		      <property name="use_markup">True</property>
		      <property name="justify">GTK_JUSTIFY_LEFT</property>
		      <property name="wrap">False</property>
		      <property name="selectable">False</property>
		      <property name="xalign">0.5</property>
		      <property name="yalign">0.5</property>
		      <property name="xpad">0</property>
		      <property name="ypad">0</property>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">False</property>
		      <property name="fill">False</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox19">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label33">
			  <property name="label" translatable="yes">Size: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="size_label">
			  <property name="label" translatable="yes">label42</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox20">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label34">
			  <property name="label" translatable="yes">Max y: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="max_y_label">
			  <property name="label" translatable="yes">label43</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox27">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label41">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">Min y: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="min_y_label">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">label43</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox40">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label62">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">Min x: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="min_x_label">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">label63</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="label64">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes"> Max x: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="max_x_label">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">label65</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox21">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label35">
			  <property name="label" translatable="yes">Cellsize: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="cellsize_label">
			  <property name="label" translatable="yes">label44</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox22">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label36">
			  <property name="label" translatable="yes">Nodata: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="nodata_label">
			  <property name="height_request">25</property>
			  <property name="label" translatable="yes">label45</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>

		  <child>
		    <widget class="GtkHBox" id="hbox23">
		      <property name="homogeneous">False</property>
		      <property name="spacing">0</property>

		      <child>
			<widget class="GtkLabel" id="label37">
			  <property name="label" translatable="yes">Min, Max: </property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="minmax_label">
			  <property name="label" translatable="yes">label46</property>
			  <property name="use_underline">False</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		    <packing>
		      <property name="padding">0</property>
		      <property name="expand">True</property>
		      <property name="fill">True</property>
		    </packing>
		  </child>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
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

<widget class="GtkDialog" id="clip_dialog">
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
    <widget class="GtkVBox" id="dialog-vbox3">
      <property name="visible">True</property>
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area3">
	  <property name="visible">True</property>
	  <property name="layout_style">GTK_BUTTONBOX_END</property>

	  <child>
	    <widget class="GtkButton" id="cancelbutton2">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">1</property>

	      <child>
		<widget class="GtkAlignment" id="alignment3">
		  <property name="visible">True</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xscale">0</property>
		  <property name="yscale">0</property>
		  <property name="top_padding">0</property>
		  <property name="bottom_padding">0</property>
		  <property name="left_padding">0</property>
		  <property name="right_padding">0</property>

		  <child>
		    <widget class="GtkHBox" id="hbox37">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">2</property>

		      <child>
			<widget class="GtkImage" id="image3">
			  <property name="visible">True</property>
			  <property name="stock">gtk-apply</property>
			  <property name="icon_size">4</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>

		      <child>
			<widget class="GtkLabel" id="label46">
			  <property name="visible">True</property>
			  <property name="label" translatable="yes">Co_mpute</property>
			  <property name="use_underline">True</property>
			  <property name="use_markup">False</property>
			  <property name="justify">GTK_JUSTIFY_LEFT</property>
			  <property name="wrap">False</property>
			  <property name="selectable">False</property>
			  <property name="xalign">0.5</property>
			  <property name="yalign">0.5</property>
			  <property name="xpad">0</property>
			  <property name="ypad">0</property>
			</widget>
			<packing>
			  <property name="padding">0</property>
			  <property name="expand">False</property>
			  <property name="fill">False</property>
			</packing>
		      </child>
		    </widget>
		  </child>
		</widget>
	      </child>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="okbutton3">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-cancel</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-6</property>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="button4">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-ok</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-5</property>
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
	<widget class="GtkVBox" id="vbox6">
	  <property name="border_width">5</property>
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">5</property>

	  <child>
	    <widget class="GtkHBox" id="hbox31">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label45">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Name: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="clip_name_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox32">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label48">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Min x: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="clip_minx_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox33">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label49">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Min y: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="clip_miny_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox34">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label50">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Max x: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="clip_maxx_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox35">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label51">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Max y: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkEntry" id="clip_maxy_entry">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="editable">True</property>
		  <property name="visibility">True</property>
		  <property name="max_length">0</property>
		  <property name="text" translatable="yes"></property>
		  <property name="has_frame">True</property>
		  <property name="invisible_char" translatable="yes">*</property>
		  <property name="activates_default">False</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">True</property>
		  <property name="fill">True</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkHBox" id="hbox36">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label52">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Cellsize: </property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="clip_cellsize_label">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">label53</property>
		  <property name="use_underline">False</property>
		  <property name="use_markup">False</property>
		  <property name="justify">GTK_JUSTIFY_LEFT</property>
		  <property name="wrap">False</property>
		  <property name="selectable">False</property>
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xpad">0</property>
		  <property name="ypad">0</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">True</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkLabel" id="clip_info_label">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">label47</property>
	      <property name="use_underline">False</property>
	      <property name="use_markup">False</property>
	      <property name="justify">GTK_JUSTIFY_LEFT</property>
	      <property name="wrap">False</property>
	      <property name="selectable">False</property>
	      <property name="xalign">0.5</property>
	      <property name="yalign">0.5</property>
	      <property name="xpad">0</property>
	      <property name="ypad">0</property>
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">False</property>
	      <property name="fill">False</property>
	    </packing>
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

<widget class="GtkDialog" id="colortable_from_dialog">
  <property name="height_request">300</property>
  <property name="title" translatable="yes">Get colortable from</property>
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
	    <widget class="GtkButton" id="cancelbutton3">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-cancel</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-6</property>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="okbutton4">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-ok</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">-5</property>
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
	  <property name="shadow_type">GTK_SHADOW_IN</property>
	  <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

	  <child>
	    <widget class="GtkTreeView" id="colortable_from_treeview">
	      <property name="visible">True</property>
	      <property name="can_focus">True</property>
	      <property name="headers_visible">True</property>
	      <property name="rules_hint">False</property>
	      <property name="reorderable">False</property>
	      <property name="enable_search">True</property>
	    </widget>
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
