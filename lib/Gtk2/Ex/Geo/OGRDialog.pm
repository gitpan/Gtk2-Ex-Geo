package Gtk2::Ex::Geo::OGRDialog;

use strict;
use warnings;

use Gtk2::Ex::Geo::GDALDialog qw/:all/;
use Gtk2::GladeXML;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);


=pod

=head1 NAME

Gtk2::Ex::Geo::OGRDialog - Dialogs for vector (ogr) layers

=head1 SYNOPSIS

  use Gtk2::Ex::Geo::OGRDialog;

=head1 DESCRIPTION

=head2 EXPORT

None by default.

=head1 METHODS

=head2 new

=cut

sub new {
    my $class = shift;
    my %opt = @_;

    my $self = {};

    $self->{path} = $opt{add_from_folder};
    $self->{resources} = $opt{resources};

    my @buffer = <DATA>;
    $self->{glade} = Gtk2::GladeXML->new_from_buffer("@buffer");

#    prepare_simple_combo($self, 'datasource_comboboxentry');
    my $combo = $self->{glade}->get_widget('datasource_comboboxentry');
    my $model = Gtk2::ListStore->new('Glib::String');
    $combo->set_model($model);
    $combo->set_text_column(0);
    $model = $combo->get_model;
    $model->clear;

    $model->set ($model->append, 0, '');
    for my $datasource (sort keys %{$self->{resources}->{datasources}}) {
	$model->set ($model->append, 0, $datasource);
    }
    $combo->set_active(0);

    $self->{dir_model} = Gtk2::TreeStore->new(qw/Glib::String/);
    my $tv = $self->{glade}->get_widget('dir_tv');
    $tv->set_model($self->{dir_model});
    my @columns = qw /dir/;
    my $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    $self->{layer_model} = Gtk2::TreeStore->new(qw/Glib::String Glib::String/);
    $tv = $self->{glade}->get_widget('layer_tv');
    $tv->set_model($self->{layer_model});
    @columns = qw /layer geom/;
    $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    $self->{property_model} = Gtk2::TreeStore->new(qw/Glib::String Glib::String/);
    $tv = $self->{glade}->get_widget('property_tv');
    $tv->set_model($self->{property_model});
    @columns = qw /property value/;
    $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    $self->{schema_model} = Gtk2::TreeStore->new(qw/Glib::String Glib::String/);
    $tv = $self->{glade}->get_widget('schema_tv');
    $tv->set_model($self->{schema_model});
    @columns = qw /field type/;
    $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    $self->{in_dir_tb} = [];

    for my $name ('SQL') {

	my $entry = $self->{glade}->get_widget($name.'_entry');
	
	$entry->signal_connect(key_press_event => \&edit_entry, [$self, $entry, $name]);
	$entry->signal_connect(key_press_event => \&edit_entry, [$self, $entry, $name]);
    }

    my $fdialog = $self->{glade}->get_widget('features_dialog');
    my $close = $self->{glade}->get_widget('close-button');
    $close->signal_connect(clicked => 
			   sub {
			       @{$self->{features_position}} = $fdialog->get_position;
			       $fdialog->hide;
			    });

    $tv = $self->{glade}->get_widget('treeview1');    

    my $select = $tv->get_selection;
    $select->set_mode('multiple');
    $select->signal_connect(changed => \&feature_activated, $self);

    $self->{glade}->get_widget('spinbutton1')->signal_connect
	(value_changed => \&fill_ftv, $self);
    $self->{glade}->get_widget('spinbutton2')->signal_connect
	(value_changed => \&fill_ftv, $self);


    my $gdialog = $self->{glade}->get_widget('geom_dialog');
    $close = $self->{glade}->get_widget('closebutton1');
    $close->signal_connect(clicked => 
			   sub {
			       @{$self->{geom_position}} = $gdialog->get_position;
			       $gdialog->hide;
			   });

    $tv = $self->{glade}->get_widget('treeview3');

    $select = $tv->get_selection;
    $select->set_mode('multiple');
    $select->signal_connect(changed => \&vertex_activated, $self);

    $self->{glade}->get_widget('from_vertex_sp')->signal_connect
	(value_changed => \&fill_gtv, $self);
    $self->{glade}->get_widget('max_vertices_sp')->signal_connect
	(value_changed => \&fill_gtv, $self);


    prepare_simple_combo($self, 'like_combobox');
    prepare_simple_combo($self, 'rasterize_render_as_combobox');
    prepare_simple_combo($self, 'rasterize_value_comboboxentry');
#    $self->{glade}->get_widget('rasterize_value_comboboxentry')->set_text_column(0);

    prepare_simple_combo($self, 'color_scheme_combobox');
    prepare_simple_combo($self, 'color_from_combobox');

    $combo = $self->{glade}->get_widget('color_scheme_combobox');
    $combo->signal_connect(changed=>\&new_color_scheme, $self);
    
    bless $self => (ref($class) or $class);
    
    return $self;
}

=pod

=head2 prepare_simple_combo

=cut

sub prepare_simple_combo {
    my ($self,$combo) = @_;
    $combo = $self->{glade}->get_widget($combo);
    my $model = Gtk2::ListStore->new('Glib::String');
    $combo->set_model($model);
    my $cell = new Gtk2::CellRendererText;
    $combo->pack_start($cell, 1);
    $combo->add_attribute($cell, text=>0);
}

=pod

=head2 geom_dialog

=head3 browse_vertices

=cut

##################
#
#   geom_dialog
#
##################

sub browse_vertices {
    my ($self,$layer,$overlay) = @_;

    $self->{layer} = $layer;
    $self->{overlay} = $overlay;

    my $tv = $self->{glade}->get_widget('treeview3');
    my @c = $tv->get_columns;
    for (@c) {
	$tv->remove_column($_);
    }

    $self->{gtv_model} = Gtk2::TreeStore->new(qw/Glib::String/);
    my $cell = Gtk2::CellRendererText->new;
    my $col = Gtk2::TreeViewColumn->new_with_attributes('Vertices', $cell, text => 0);
    $tv->append_column($col);
    $tv->set_model($self->{gtv_model});

    fill_gtv(undef,$self);
    
    my $dialog = $self->{glade}->get_widget('geom_dialog');
    $dialog->set_title("Vertices of '".$layer->GetName."'");

    $dialog->move(@{$self->{geom_position}}) if $self->{geom_position}; # for WinAxe
    $dialog->show_all;
    
}

=pod

=head3 vertex_activated

=cut

sub vertex_activated {
    my($ts,$self) = @_;

    my $overlay = $self->{overlay};

    $overlay->render(reuse_pixbuf=>1);

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));

    my @sel = $ts->get_selected_rows;
    for (@sel) {

	my $selected = $_->to_string;

	next unless exists $self->{GIDS}->{$selected};

	my @path = split /:/,$self->{GIDS}->{$selected};

	my $f = $self->{layer}->GetFeature($path[0]);
	my $geom = $f->GetGeometryRef();
	for my $i (1..$#path-1) {
	    $geom = $geom->GetGeometryRef($path[$i]);
	}
	my @p = ($geom->GetX($path[$#path]),$geom->GetY($path[$#path]));

	@p = $overlay->point2pixmap_pixel(@p);

	
	
	$overlay->{pixmap}->draw_line($gc,$p[0]-4,$p[1],$p[0]+4,$p[1]);
	$overlay->{pixmap}->draw_line($gc,$p[0],$p[1]-4,$p[0],$p[1]+4);
	
	$overlay->hide;
	$overlay->show;
	
    }
}

=pod

=head3 fill_gtv

=cut

sub fill_gtv {
    my ($sp,$self) = @_;

    my $layer = $self->{layer};

    my $from = $self->{glade}->get_widget('from_vertex_sp')->get_value_as_int;
    my $count = $self->{glade}->get_widget('max_vertices_sp')->get_value_as_int;

    $self->{gtv_model}->clear;

    $layer->SetSpatialFilterRect(@{$self->{overlay}->{selection}}) if $self->{overlay}->{selection};
    $layer->ResetReading();

    delete $self->{GIDS};
    my $vertex = 0;
    my $vertices = 0;
    my @data;
    while (1) {
	my $f = $layer->GetNextFeature();
	last unless $f;
	my $geom = $f->GetGeometryRef();
	my $fid = $f->GetFID;
	my $name = $geom->GetGeometryName;

	my $vertices2 = $vertices;
	my $d = $self->get_geom_data($geom,\$vertex,\$vertices2,$from,$count);
	push @data,["Feature (fid=$fid) ($name)",$d,$fid] if $vertices2 > $vertices;
	$vertices = $vertices2;
	last if $vertices >= $count;

    }

    my $i = 0;
    for my $d (@data) {
	$self->set_geom_data($d,$i,$d->[2],$self->{gtv_model});
	$i++;
    }
}

=pod

=head3 set_geom_data

=cut

sub set_geom_data {
    my($self,$data,$path,$gid,$tree_store,$iter) = @_;
    
    my $iter2 = $tree_store->append($iter);
    $tree_store->set ($iter2,0 => $data->[0]);
    
    if ($data->[1]) {

	my $i = 0;
	for my $d (@{$data->[1]}) {
	    $self->set_geom_data($d,"$path:$i","$gid:$d->[2]",$tree_store,$iter2);
	    $i++;
	}

    } else {

	$self->{GIDS}->{$path} = $gid;

    }
}

=pod

=head3 get_geom_data

=cut

sub get_geom_data {
    my($self,$geom,$vertex,$vertices,$from,$count) = @_;

    return if $$vertices >= $count;
    
    if ($geom->GetGeometryCount) {
	
	my @d;
	for my $i2 (0..$geom->GetGeometryCount-1) {
	    
	    my $geom2 = $geom->GetGeometryRef($i2);
	    my $name = $geom2->GetGeometryName;
	    
	    my $vertices2 = $$vertices;
	    my $data = $self->get_geom_data($geom2,$vertex,\$vertices2,$from,$count);
	    push @d,[($i2+1).'. '.$name,$data,$i2] if $vertices2 > $$vertices;
	    $$vertices = $vertices2;
	    last if $$vertices >= $count;
	    
	}
	return \@d if @d;
	
    } else {

	my @va;
	if ($self->{overlay}->{selection}) {
	    my $r = $self->{overlay}->{selection};
	    @va = ($r->[0],$r->[3],$r->[2],$r->[1]);
	} else {
	    @va = $self->{overlay}->visible_area(); ## ul, dr
	}
	
	my @d;
	for my $i (0..$geom->GetPointCount-1) {	    
	    my $x = $geom->GetX($i);
	    next if $x < $va[0] or $x > $va[2];
	    my $y = $geom->GetY($i);
	    next if $y > $va[1] or $y < $va[3];
	    my $z = $geom->GetZ($i);
	    $$vertex++;
	    if ($$vertex >= $from) {
		push @d,[($i+1).": $x $y $z",undef,$i];
		$$vertices++;
	    }
	    last if $$vertices >= $count;
	}
	
	return \@d;
	
    }

    return undef;

}

=pod

=head2 features_dialog

=head3 browse_features

=cut

##################
#
#   features_dialog
#
##################

sub browse_features {
    my ($self,$layer,$overlay) = @_;

    $self->{layer} = $layer;
    $self->{schema} = $layer->GetLayerDefn();
    $self->{overlay} = $overlay;

    my @columns;
    my @headers;

    push @columns, 'fid';
    push @headers, 'Glib::String';

    $self->{f_schema}->{fid}->{i} = 0;
    $self->{f_schema}->{fid}->{type} = $ogr::OFTInteger;

    for my $i (0..$self->{schema}->GetFieldCount()-1) {
	my $c = $self->{schema}->GetFieldDefn($i);
	my $name = $c->GetName;
	$name =~ s/_/__/g;
	$self->{f_schema}->{$name}->{i} = $i+1;
	$self->{f_schema}->{$name}->{type} = $c->GetType;
	push @columns, $name;
	push @headers, 'Glib::String';
    }

    my $tv = $self->{glade}->get_widget('treeview1');

    $self->{ftv_model} = Gtk2::TreeStore->new(@headers);
    $tv->set_model($self->{ftv_model});

    my @c = $tv->get_columns;
    for (@c) {
	$tv->remove_column($_);
    }

    my $i = 0;
    foreach my $column (@columns) {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    @c = $tv->get_columns;
    for (@c) {
	$_->set_clickable(1);
	$_->signal_connect(clicked => sub {
	    my ($column,$self) = @_;
	    fill_ftv(undef, $self, $column->get_title);
	}, $self);
    }

    fill_ftv(undef,$self);
    
    my $dialog = $self->{glade}->get_widget('features_dialog');
    $dialog->set_title("Features of '".$layer->GetName."'");

    $dialog->move(@{$self->{features_position}}) if $self->{features_position}; # for WinAxe
    $dialog->show_all;
}

=pod

=head3 feature_activated

=cut

sub feature_activated {
    my($ts,$self) = @_;

    my $overlay = $self->{overlay};

    $overlay->render(reuse_pixbuf=>1);

    my $gc = Gtk2::Gdk::GC->new($overlay->{pixmap});
    $gc->set_rgb_fg_color(Gtk2::Gdk::Color->new(65535,0,0));

    my @sel = $ts->get_selected_rows;
    for (@sel) {

	my $selected = $_->to_string;

	my $f = $self->{layer}->GetFeature($self->{FIDS}->[$selected]);
	next unless $f;

	my $geom = $f->GetGeometryRef();
	next unless $geom;

	render_selected($overlay,$gc,$geom);      
		
	$overlay->hide;
	$overlay->show;
	
    }
}

=pod

=head3 render_selected

=cut

sub render_selected {
    my($overlay,$gc,$geom) = @_;
    my $n = $geom->GetGeometryCount;
    if ($n) {
	for my $i (0..$n-1) {
	    my $g = $geom->GetGeometryRef($i);
	    render_selected($overlay,$gc,$g);
	}
    } else {
	my $type = $geom->GetGeometryType;
      SWITCH: {
	  if ($type == $ogr::wkbPoint or
	      $type == $ogr::wkbMultiPoint or
	      $type == $ogr::wkbPoint25D or
	      $type == $ogr::wkbMultiPoint25D) {

	      for my $i (0..$geom->GetPointCount-1) {
		  my @p = ($geom->GetX($i),$geom->GetY($i));
		  @p = $overlay->point2pixmap_pixel(@p);
	
		  $overlay->{pixmap}->draw_line($gc,$p[0]-4,$p[1],$p[0]+4,$p[1]);
		  $overlay->{pixmap}->draw_line($gc,$p[0],$p[1]-4,$p[0],$p[1]+4);
	      }

	      last SWITCH; }
	  if ($type == $ogr::wkbLineString or
	      $type == $ogr::wkbPolygon or
	      $type == $ogr::wkbMultiLineString or
	      $type == $ogr::wkbMultiPolygon or
	      $type == $ogr::wkbLineString25D or
	      $type == $ogr::wkbPolygon25D or
	      $type == $ogr::wkbMultiLineString25D or
	      $type == $ogr::wkbMultiPolygon25D) { 
	      
	      my @points;
	      for my $i (0..$geom->GetPointCount-1) {
		  my @p = ($geom->GetX($i), $geom->GetY($i));
		  my @q = $overlay->point2pixmap_pixel(@p);
		  push @points,@q;
	      }
	      $overlay->{pixmap}->draw_lines($gc, @points);

	      last SWITCH; }
      }
    }
}

=pod

=head3 fill_ftv

=cut

sub fill_ftv {
    my ($sp,$self,$sort_by) = @_; ### SORTing is built-in in fact!!

    my $from = $self->{glade}->get_widget('spinbutton1')->get_value_as_int;
    my $count = $self->{glade}->get_widget('spinbutton2')->get_value_as_int;

    my $layer = $self->{layer};
    my $n = $self->{schema}->GetFieldCount();
    my $model = $self->{ftv_model};

    $model->clear;

    $layer->SetSpatialFilterRect(@{$self->{overlay}->{selection}}) if $self->{overlay}->{selection};
    $layer->ResetReading();

    my @recs;
    $self->{FIDS} = [];
    my $i = 1;
    while ($i < $from+$count) {
	my $f = $layer->GetNextFeature();
	$i++;
	next if $i <= $from;
	last unless $f;
	my @rec;
	my $rec = 0;

	push @rec,$rec++;
	push @rec,$f->GetFID;

	for my $j (0..$n-1) {
	    push @rec,$rec++;
	    push @rec,$f->GetFieldAsString($j);
	}

	push @recs,\@rec;
    }

    my $k = defined $sort_by ? 2*$self->{f_schema}->{$sort_by}->{i}+1 : 1;

    my $type = defined $sort_by ? $self->{f_schema}->{$sort_by}->{type} : $ogr::OFTInteger;
    
    if ($type == $ogr::OFTInteger or $type == $ogr::OFTReal) {
	@recs = sort {$a->[$k] <=> $b->[$k]} @recs;
    } else {
	@recs = sort {$a->[$k] cmp $b->[$k]} @recs;
    }

    for my $rec (@recs) {
	
	my $iter = $model->insert (undef, 999999);
	$model->set ($iter, @$rec);
	push @{$self->{FIDS}},$rec->[1];
	
    }
    
}

=pod

=head2 open_dialog

=head3 ogr_open

=cut

##################
#
#   open_dialog
#
##################

sub ogr_open {
    my ($self,$historian) = @_;

    my @ret;

    $self->{historian} = $historian;

    for ('SQL') {
	$historian->{'history_index_'.$_} = $#{$historian->{history}} unless defined $historian->{'history_index_'.$_};
	my $text = $historian->{history}->[$historian->{'history_index_'.$_}];
	$self->{glade}->get_widget($_.'_entry')->set_text($text) if $text;
    }

    $self->fill_dir_tv();
    $self->fill_layer_tv();

    $self->{property_model}->clear;
    $self->{schema_model}->clear;

    my $dialog = $self->{glade}->get_widget('open_dialog');

    $dialog->move(@{$self->{ogr_open_position}}) if $self->{ogr_open_position}; # for WinAxe
    $dialog->show_all;

    while (1) {

	my $response = $dialog->run;

	my $sql = $self->{glade}->get_widget('SQL_entry')->get_text;
	my $datasource = $self->{glade}->get_widget('datasource_comboboxentry')->child->get_text;
	
	if ($response eq 'ok') {

	    if ($sql) {
		my $h = $self->{historian};
		push @{$h->{history}}, '' unless $h->{history}->[$#{$h->{history}}] eq '';
		$self->{glade}->get_widget('SQL_entry')->set_text('');
	    }
	    
	    unless ($datasource) {
		$datasource = $self->get_current_folder();
	    }
	    
	    my($path, $focus_column) = $self->{glade}->get_widget('layer_tv')->get_cursor;
	    my $index = $path->to_string if $path;
	    
	    my $layer;
	    
	    if ($sql) {
		$layer = 'sql';
	    } elsif (defined $index) {
		$layer = $self->{layers}->[$index];
	    }
	    
	    @ret = ($datasource,$layer,$sql);

	    last;

	} elsif ($response eq '1') { # chdir

	    unless ($datasource) {
		my($path, $focus_column) = $self->{glade}->get_widget('dir_tv')->get_cursor;
		if ($path) {
		    my $index = $path->to_string;
		    $self->{path} .= $self->{dirs}->[$index].'/' if defined $index;
		}
		$self->fill_dir_tv();
	    }
	    
	    $self->fill_layer_tv();

	} elsif ($response eq '2') { # schema

	    $self->fill_property_and_schema_tvs();

	} else { # cancel

	    last;

	}	

    }

    @{$self->{ogr_open_position}} = $dialog->get_position;
    $dialog->hide;
    return @ret;
}

=pod

=head3 get_current_folder

=cut

sub get_current_folder {
    my $self = shift;
    my $ret = '';
    for (reverse @{$self->{in_dir_tb}}) {
	$ret .= $_->get_label;
	$ret .= '/' unless $ret =~ /\/$/;
#	last if $_ == $_[0];
    }
    return $ret;
}

=pod

=head3 fill_dir_tv

=cut

sub fill_dir_tv {
    my $self = shift;

    $self->{dir_model}->clear;

    my $tb = $self->{glade}->get_widget('dir_tb');

    for (@{$self->{in_dir_tb}}) {$tb->remove($_);}
    $self->{in_dir_tb} = [];

    my $sub = sub {
	my $n = $_[0]->get_label;
	$self->{path} = '';
	for (reverse @{$self->{in_dir_tb}}) {
	    $self->{path} .= $_->get_label;
	    $self->{path} .= '/' unless $self->{path} =~ /\/$/;
	    last if $_ == $_[0];
	}
	$self->fill_dir_tv();
	$self->fill_layer_tv();
    };
    
    my($volume,$directories,$file) = File::Spec->splitpath( $self->{path} );
    my @dirs = File::Spec->splitdir( $directories );
    pop @dirs;
    unshift @dirs,'/';
    for (reverse @dirs) {
	next if /^\s*$/;
	my $b = Gtk2::ToolButton->new(undef,$_);
	$b->signal_connect ("clicked", $sub);
	$b->show;
	$tb->insert($b,0);
	push @{$self->{in_dir_tb}}, $b;
    }
    
    if (opendir(DIR,$self->{path})) {
	
	@{$self->{dirs}} = sort {$b cmp $a} 
	grep { !/^\./ && -d "$self->{path}/$_" } readdir(DIR);
	closedir DIR;
	
	for my $i (0..$#{$self->{dirs}}) {
	    my $iter = $self->{dir_model}->insert (undef, 0);
	    $self->{dir_model}->set ($iter,
				     0, $self->{dirs}->[$i],
				     );
	}

	$self->{glade}->get_widget('dir_tv')->set_cursor(Gtk2::TreePath->new(0));
    }
    @{$self->{dirs}} = reverse @{$self->{dirs}} if $self->{dirs};
}

=pod

=head3 fill_layer_tv

=cut

sub fill_layer_tv {
    my $self = shift;

    $self->{layer_model}->clear;

    @{$self->{layers}} = ();
    my %geom_types;
        
    $self->{datasource} = 0;

    my $datasource = $self->{glade}->get_widget('datasource_comboboxentry')->child->get_text;
    $datasource = $self->{path} unless $datasource;

    my $open;

    eval {
	$open = $self->{datasource} = ogr::Open($datasource, 0);
    };
    if ($@) {
	$open = 0;
	message($@);
    }

    if ($open and $self->{datasource}->GetLayerCount) {

	if ($datasource ne $self->{path} and not $self->{resources}->{datasources}->{$datasource}) {
	    my $combo = $self->{glade}->get_widget('datasource_comboboxentry');
	    my $model = $combo->get_model;
	    $model->set ($model->append, 0, $datasource);
	    $self->{resources}->{datasources}->{$datasource} = 1;
	}

	for (0..$self->{datasource}->GetLayerCount-1) {
	    my $l = $self->{datasource}->GetLayerByIndex($_);
	    my $fd = $l->GetLayerDefn();
	    push @{$self->{layers}}, $l->GetName;
	    $geom_types{$l->GetName} = $fd->GetGeomType;
	}
	@{$self->{layers}} = sort {$b cmp $a} @{$self->{layers}};
	
	for my $i (0..$#{$self->{layers}}) {
	    my $iter = $self->{layer_model}->insert (undef, 0);
	    my $geom = $Geo::Vector::ogr_geom_types{$geom_types{$self->{layers}->[$i]}};
	    $geom = $geom_types{$self->{layers}->[$i]} unless $geom;
	    $self->{layer_model}->set ($iter,
				       0, $self->{layers}->[$i],
				       1, $geom
				       );
	}
	$self->{glade}->get_widget('layer_tv')->set_cursor(Gtk2::TreePath->new(0));
	
    }
    @{$self->{layers}} = reverse @{$self->{layers}};
}

=pod

=head3 fill_property_and_schema_tvs

=cut

sub fill_property_and_schema_tvs {
    my $self = shift;

    $self->{property_model}->clear;
    $self->{schema_model}->clear;

    my $label = $self->{glade}->get_widget('schema_lb');

    my $layer;

    my $sql = $self->{glade}->get_widget('SQL_entry')->get_text;

    if ($sql) {

	$label->set_label('Schema from SQL:');

	eval {
	    $layer = $self->{datasource}->ExecuteSQL($sql);
	};
	message($@) if $@;

    } else {

	my ($path, $focus_column) = $self->{glade}->get_widget('layer_tv')->get_cursor;
	my $index = $path->to_string if $path;
    
	if ($self->{layers}->[$index]) {
	
	    $label->set_label('Schema of "'.$self->{layers}->[$index].'":');
	
	    $layer = $self->{datasource}->GetLayerByName($self->{layers}->[$index]);
	}

    }

    return unless $layer;
 
    my $iter = $self->{property_model}->insert (undef, 0);
    $self->{property_model}->set ($iter,
				  0, 'FeatureCount',
				  1, $layer->GetFeatureCount()
				  );
	
    my $schema = $layer->GetLayerDefn();
	
    my $n = $schema->GetFieldCount();
    my %data;
    for my $i (0..$n-1) {
	my $c = $schema->GetFieldDefn($i);
	$data{$c->GetName} = $c->GetFieldTypeName($c->GetType);
    }
    for my $name (sort {$b cmp $a} keys %data) {
	my $iter = $self->{schema_model}->insert (undef, 0);
	$self->{schema_model}->set ($iter,
				    0, $name,
				    1, $data{$name}
				    );
    }

    if ($sql) {
	$self->{datasource}->ReleaseResultSet($layer);
    }
    
}

=pod

=head3 edit_entry

=cut

sub edit_entry {
    my($e,$event,$data) = @_;
    my($self, $entry, $name) = @$data;
    my $index = 'history_index_'.$name;

    my $key = $event->keyval;
    my $h = $self->{historian};

    my $text = $entry->get_text;

    $h->{history}->[$h->{$index}] = $text;

    if ($key == 65362) { # arrow up
	$h->{$index} = max(0, $h->{$index}-1);
	$entry->set_text($h->{history}->[$h->{$index}]);
	return 1;
    } elsif ($key == 65364) { # arrow down
	$h->{$index} = min($#{$h->{history}}, $h->{$index}+1);
	$entry->set_text($h->{history}->[$h->{$index}]);
	return 1;
    }

}

=pod

=head2 property_dialog

=head3 layer_properties

=cut

##################
#
#   property_dialog
#
##################

sub layer_properties {
    my($self,$overlay,$layer) = @_;

    my $schema = $layer->{ogr_layer}->GetLayerDefn();

    my $dialog = $self->{glade}->get_widget('property_dialog');
    $dialog->set_title("Properties of layer '".$layer->{name}."'");

    $self->{glade}->get_widget('geom_type_lbl')->set_text($Geo::Vector::ogr_geom_types{$schema->GetGeomType});

    $self->{glade}->get_widget('feature_count_lbl')->set_text($layer->{ogr_layer}->GetFeatureCount());

    $self->{glade}->get_widget('datasource_lbl')->set_text($layer->{datasource});
    $self->{glade}->get_widget('sql_lbl')->set_text($layer->{sql});

    $self->{glade}->get_widget('name_entry')->set_text($layer->{name});
    my $a = $layer->{alpha};
    $a = 255 unless defined $a;
    $self->{glade}->get_widget('alpha_spinbutton')->set_value($layer->{alpha});

    my $cb = $self->{glade}->get_widget('combobox1');

    if ($layer->{RenderAs}) {
	$cb->set_active($layer->{RenderAs});
    } else {
	my $fd = $layer->{ogr_layer}->GetLayerDefn();
	if ($fd->GetGeomType == $ogr::wkbPoint or
	    $fd->GetGeomType == $ogr::wkbMultiPoint or
	    $fd->GetGeomType == $ogr::wkbPoint25D or
	    $fd->GetGeomType == $ogr::wkbMultiPoint25D) {
	    $cb->set_active(1);
	} elsif ($fd->GetGeomType == $ogr::wkbLineString or
		 $fd->GetGeomType == $ogr::wkbMultiLineString or
		 $fd->GetGeomType == $ogr::wkbLineString25D or
		 $fd->GetGeomType == $ogr::wkbMultiLineString25D) {
	    $cb->set_active(2);
	} elsif ($fd->GetGeomType == $ogr::wkbPolygon or
		 $fd->GetGeomType == $ogr::wkbMultiPolygon or
		 $fd->GetGeomType == $ogr::wkbPolygon25D or
		 $fd->GetGeomType == $ogr::wkbMultiPolygon25D) {
	    $cb->set_active(3);
	} else {
	    $cb->set_active(0);
	}
    }

    my $ret;

    $dialog->move(@{$self->{layer_properties_position}}) if $self->{layer_properties_position}; # for WinAxe
    $dialog->show_all;

    while (1) {

	my $response = $dialog->run;
	
	if ($response eq 'ok') {

	    for my $k ('name') {
		$ret->{$k} = $self->{glade}->get_widget($k.'_entry')->get_text;
	    }
	    $ret->{alpha} = $self->{glade}->get_widget('alpha_spinbutton')->get_value_as_int;

	    my $r = $cb->get_active();
	    if ($r != $layer->{RenderAs}) {
		$layer->{RenderAs} = $r;
		$overlay->render;
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

=head2 color_dialog

=cut

##################
#
#   color_dialog
#
##################

sub color_dialog {
    my($self,$layer,$overlay) = @_;

    my $color = $layer->{COLOR};
    my $a = ref $color ? $color->[3] : 255;
    $a = $layer->{alpha} if defined $layer->{alpha};

    my $c = new Gtk2::Gdk::Color ($color ? $color->[0]*257 : 65535,
				  $color ? $color->[1]*257 : 65535,
				  $color ? $color->[2]*257 : 65535);

    my $d = Gtk2::ColorSelectionDialog->new('Color for '.$layer->{name});
    
    $d->colorsel->set_current_color($c);
    $d->colorsel->set_has_opacity_control(1);
    $d->colorsel->set_current_alpha($a*257);

    if ($d->run eq 'ok') {
	$c = $d->colorsel->get_current_color;
	$a = $d->colorsel->get_current_alpha;
	$a = int($a/257);

	$layer->{COLOR} = [int($c->red/257),int($c->green/257),int($c->blue/257),$a];
	$layer->{alpha} = $a;
	$overlay->render;
    }
    $d->destroy;
}

=pod

=head2 colors_dialog

=head3 new_color_scheme

=cut

##################
#
#   colors_dialog
#
##################

sub new_color_scheme {
    my($combo,$self) = @_;
#    my $s = \%Geo::Vector::COLOR_SCHEMES;
    for ('color_from_combobox','label37','label38','palette_min_entry','label39','palette_max_entry','colortable_treeview','copy_colortable_button','color_button','button7') {
	$self->{glade}->get_widget($_)->set_sensitive(1);
    }
    if ($combo->get_active() == 3) {
	for ('color_from_combobox','label37','label38','palette_min_entry','label39','palette_max_entry','colortable_treeview','copy_colortable_button','color_button','button7') {
	    $self->{glade}->get_widget($_)->set_sensitive(0);
	}
    } elsif ($combo->get_active() == 0 or $combo->get_active() == 1) {
	for ('colortable_treeview','copy_colortable_button','color_button','button7') {
	    $self->{glade}->get_widget($_)->set_sensitive(0);
	}
    } else {
	
    }
}

=pod

=head2 colors_dialog

=cut

sub colors_dialog {
    my($self,$layer,$overlay,$layers) = @_;

    my $dialog = $self->{glade}->get_widget('colors_dialog');
    $dialog->set_title("Coloring of $layer->{name}");

    $self->{color_table} = $layer->get_color_table(1);

    my $combo = $self->{glade}->get_widget('color_scheme_combobox');
    my $model = $combo->get_model;
    $model->clear;
    my $s = \%Geo::Vector::COLOR_SCHEMES;
    for (sort {$s->{$a} <=> $s->{$b}} keys %$s) {
	$model->set ($model->append, 0, $_);
    }
    $combo->set_active($layer->color_scheme());
    new_color_scheme($combo,$self);

    $combo = $self->{glade}->get_widget('color_from_combobox');
    $model = $combo->get_model;
    $model->clear;
    my $active = 0;
    $layer->{value_field} = '' unless $layer->{value_field};
    my @fields = ('');
    $model->set ($model->append, 0, 'FID');
    my $schema = $layer->{ogr_layer}->GetLayerDefn();
    for my $i (0..$schema->GetFieldCount-1) {
	my $column = $schema->GetFieldDefn($i);
	my $type = $column->GetFieldTypeName($column->GetType);
	if ($type eq 'Integer') {
	    push @fields, $column->GetName;
	    $model->set ($model->append, 0, $column->GetName);
	    $active = $#fields if $column->GetName eq $layer->{value_field};
	}
    }
    $combo->set_active($active);

    my $pal_min = $self->{glade}->get_widget('palette_min_entry');
    my $pal_max = $self->{glade}->get_widget('palette_max_entry');
    $pal_min->set_text(($layer->{PALETTE_MIN} or 0));
    $pal_max->set_text(($layer->{PALETTE_MAX} or 0));
    
    my $tv = $self->{glade}->get_widget('colortable_treeview');
    my $select = $tv->get_selection;
    $select->set_mode('multiple');

    $model = Gtk2::TreeStore->new(qw/Glib::Int Glib::Int Glib::Int Glib::Int Glib::Int/);
    $tv->set_model($model);

    for ($tv->get_columns) {
	$tv->remove_column($_);
    }

    my $i = 0;
    foreach my $column ('value','red','green','blue','alpha') {
	my $cell = Gtk2::CellRendererText->new;
	my $col = Gtk2::TreeViewColumn->new_with_attributes($column, $cell, text => $i++);
	$tv->append_column($col);
    }

    fill_colors_treeview(undef,$self);

    my @backup;
    for my $i (0..$self->{color_table}->GetCount-1) {
	my @c = $self->{color_table}->GetColorEntry($i);
	$backup[$i] = \@c;
    }
    my $value_field_backup = $layer->{value_field};
    my $pal_min_backup = $layer->{PALETTE_MIN};
    my $pal_max_backup = $layer->{PALETTE_MAX};
    my $scheme_backup = $layer->{COLOR_SCHEME};
    
    $dialog->move(@{$self->{colors_position}}) if $self->{colors_position}; # for WinAxe
    $dialog->show_all;

    while (1) {

	my $response = $dialog->run;

	$layer->{value_field} = $fields[$self->{glade}->get_widget('color_from_combobox')->get_active()];
	$layer->{COLOR_SCHEME} = $self->{glade}->get_widget('color_scheme_combobox')->get_active();
	$layer->{PALETTE_MIN} = $pal_min->get_text();
	$layer->{PALETTE_MAX} = $pal_max->get_text();

	if ($response eq 'apply') {

	    $overlay->render;
	
	} elsif ($response eq '1') { # color editor

	    my $sel = $tv->get_selection;
	    my @sel = $sel->get_selected_rows;
	    next unless @sel;
		
	    my $i = $sel[0]->to_string;

	    my $d = Gtk2::ColorSelectionDialog->new('Choose color for selected entries');
	    my $s = $d->colorsel;

	    my @color = $self->{color_table}->GetColorEntry($i);

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
		    $self->{color_table}->SetColorEntry($i,\@color);
		}
		
		fill_colors_treeview(undef,$self);
#		$overlay->render;
	    }
	    $d->destroy;

	    for (@sel) {
		$sel->select_path($_);
	    }

	} elsif ($response eq '2') { # copy colortable from 

	    if (get_colortable_from_dialog($self,$layer,$layers)) {
		
		fill_colors_treeview(undef,$self);
#		$overlay->render;

	    }

	} elsif ($response eq '3') { # add a color

	    $self->{contents}->{$self->{color_table}->GetCount} = 1;
	    fill_colors_treeview(undef,$self);

	} elsif ($response eq 'cancel') {

	    $layer->{value_field} = $value_field_backup;
	    for my $i (0..$self->{color_table}->GetCount-1) {
		$self->{color_table}->SetColorEntry($i, $backup[$i]) if ref $backup[$i];
	    }
	    $layer->{PALETTE_MIN} = $pal_min_backup;
	    $layer->{PALETTE_MAX} = $pal_max_backup;
	    $layer->{COLOR_SCHEME} = $scheme_backup;

	    last;
	    
	} else {
	    
	    last;

	}	

    }

    @{$self->{colors_position}} = $dialog->get_position;
    $dialog->hide;

    $overlay->render;
}

=pod

=head2 rasterize_dialog

=cut

##################
#
#   rasterize_dialog
#
##################

sub rasterize_dialog {
    my ($self,$layer,$overlay) = @_;

    my $dialog = $self->{glade}->get_widget('rasterize_dialog');
    $dialog->set_title("Rasterize $layer->{name}");

    # fill like_combobox: all available rasters

    my $combo = $self->{glade}->get_widget('like_combobox');
    my $model = $combo->get_model;
    $model->clear;

    my @rasters;
    for my $layer (@{$overlay->{layers}}) {
	next unless ref($layer) eq 'Geo::Raster';
	push @rasters, $layer;
	$model->set ($model->append, 0, $layer->{name});
    }
    $combo->set_active(0);

#    $combobox->set_model($model);

    # fill rasterize_render_as_combobox: native, points, (lines, (areas))
    $combo = $self->{glade}->get_widget('rasterize_render_as_combobox');
    $model = $combo->get_model;
    $model->clear;
    for my $a ('Native','Points','Lines','Areas') {
	$model->set ($model->append, 0, $a);
    }
    $combo->set_active(0);

    # fill rasterize_value_comboboxentry: int and float fields
    $combo = $self->{glade}->get_widget('rasterize_value_comboboxentry');
    $model = $combo->get_model;
    $model->clear;

    my @fields = ('');
    $model->set ($model->append, 0, 'Draw with value 1');
    my $schema = $layer->{ogr_layer}->GetLayerDefn();
    for my $i (0..$schema->GetFieldCount-1) {
	my $column = $schema->GetFieldDefn($i);
	my $type = $column->GetFieldTypeName($column->GetType);
	if ($type eq 'Integer' or $type eq 'Real') {
	    push @fields, $column->GetName;
	    $model->set ($model->append, 0, $column->GetName);
	}
    }
    $combo->set_active(0);

    $self->{glade}->get_widget('rasterize_nodata_value_entry')->set_text(-9999);

    $dialog->move(@{$self->{rasterize_dialog_position}}) if $self->{rasterize_dialog_position}; # for WinAxe
    $dialog->show;

    my %ret = ();

    while (1) {

	my $response = $dialog->run;
	
	if ($response eq 'ok') {

	    $ret{like} = $rasters[$self->{glade}->get_widget('like_combobox')->get_active];
	    $ret{RenderAs} = $self->{glade}->get_widget('rasterize_render_as_combobox')->get_active;
	    $ret{feature} = $self->{glade}->get_widget('rasterize_fid_entry')->get_text;
	    $ret{feature} = -1 unless $ret{feature} =~ /^\d+$/;
	    $ret{value_field} = $self->{glade}->get_widget('rasterize_value_comboboxentry')->get_active;
	    $ret{value_field} = $fields[$ret{value_field}];
	    $ret{nodata_value} = $self->{glade}->get_widget('rasterize_nodata_value_entry')->get_text();
	    
	    if (0) {
#		message("bad input");
	    } else {
		
		last;
	    }

	} elsif ($response eq 'cancel') {

	    last;

	}	

    }

    @{$self->{rasterize_dialog_position}} = $dialog->get_position;
    $dialog->hide;
    return \%ret;
}

=pod

=head2 message

=cut

sub message {
    my($message) = @_;
    my $dialog = Gtk2::MessageDialog->new(undef,'destroy-with-parent','info','close',$message);
    $dialog->run;
    $dialog->destroy;
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

<widget class="GtkDialog" id="open_dialog">
  <property name="width_request">700</property>
  <property name="height_request">400</property>
  <property name="title" translatable="yes">Select a vector data layer</property>
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
	    <widget class="GtkButton" id="button1">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">1</property>

	      <child>
		<widget class="GtkAlignment" id="alignment1">
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xscale">0</property>
		  <property name="yscale">0</property>
		  <property name="top_padding">0</property>
		  <property name="bottom_padding">0</property>
		  <property name="left_padding">0</property>
		  <property name="right_padding">0</property>

		  <child>
		    <widget class="GtkHBox" id="hbox1">
		      <property name="homogeneous">False</property>
		      <property name="spacing">2</property>

		      <child>
			<widget class="GtkImage" id="image1">
			  <property name="stock">gtk-jump-to</property>
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
			<widget class="GtkLabel" id="label1">
			  <property name="label" translatable="yes">C_hDir</property>
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
	    <widget class="GtkButton" id="button2">
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">2</property>

	      <child>
		<widget class="GtkAlignment" id="alignment2">
		  <property name="xalign">0.5</property>
		  <property name="yalign">0.5</property>
		  <property name="xscale">0</property>
		  <property name="yscale">0</property>
		  <property name="top_padding">0</property>
		  <property name="bottom_padding">0</property>
		  <property name="left_padding">0</property>
		  <property name="right_padding">0</property>

		  <child>
		    <widget class="GtkHBox" id="hbox2">
		      <property name="homogeneous">False</property>
		      <property name="spacing">2</property>

		      <child>
			<widget class="GtkImage" id="image2">
			  <property name="stock">gtk-dnd</property>
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
			<widget class="GtkLabel" id="label2">
			  <property name="label" translatable="yes">_Schema</property>
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
	<widget class="GtkHBox" id="hbox3">
	  <property name="width_request">750</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkVBox" id="vbox1">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkHBox" id="hbox4">
		  <property name="homogeneous">False</property>
		  <property name="spacing">0</property>

		  <child>
		    <widget class="GtkLabel" id="label6">
		      <property name="label" translatable="yes">DS:</property>
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
		    <widget class="GtkComboBoxEntry" id="datasource_comboboxentry">
		      <property name="visible">True</property>
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
		<widget class="GtkToolbar" id="dir_tb">
		  <property name="orientation">GTK_ORIENTATION_HORIZONTAL</property>
		  <property name="toolbar_style">GTK_TOOLBAR_BOTH</property>
		  <property name="tooltips">True</property>
		  <property name="show_arrow">True</property>

		  <child>
		    <placeholder/>
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
		    <widget class="GtkTreeView" id="dir_tv">
		      <property name="can_focus">True</property>
		      <property name="headers_visible">False</property>
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

	  <child>
	    <widget class="GtkVSeparator" id="vseparator1">
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">False</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkVBox" id="vbox2">
	      <property name="width_request">280</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkHBox" id="hbox5">
		  <property name="homogeneous">False</property>
		  <property name="spacing">0</property>

		  <child>
		    <widget class="GtkLabel" id="SQL-label">
		      <property name="label" translatable="yes">SQL:</property>
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
		    <widget class="GtkEntry" id="SQL_entry">
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
		<widget class="GtkScrolledWindow" id="scrolledwindow2">
		  <property name="can_focus">True</property>
		  <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
		  <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
		  <property name="shadow_type">GTK_SHADOW_IN</property>
		  <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

		  <child>
		    <widget class="GtkTreeView" id="layer_tv">
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

	  <child>
	    <widget class="GtkVSeparator" id="vseparator2">
	    </widget>
	    <packing>
	      <property name="padding">0</property>
	      <property name="expand">False</property>
	      <property name="fill">True</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkVBox" id="vbox3">
	      <property name="width_request">200</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="schema_lb">
		  <property name="label" translatable="yes"></property>
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
		<widget class="GtkScrolledWindow" id="scrolledwindow3">
		  <property name="can_focus">True</property>
		  <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
		  <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
		  <property name="shadow_type">GTK_SHADOW_IN</property>
		  <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

		  <child>
		    <widget class="GtkTreeView" id="property_tv">
		      <property name="can_focus">True</property>
		      <property name="headers_visible">False</property>
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

	      <child>
		<widget class="GtkScrolledWindow" id="scrolledwindow4">
		  <property name="can_focus">True</property>
		  <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
		  <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
		  <property name="shadow_type">GTK_SHADOW_IN</property>
		  <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

		  <child>
		    <widget class="GtkTreeView" id="schema_tv">
		      <property name="can_focus">True</property>
		      <property name="headers_visible">False</property>
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
	<packing>
	  <property name="padding">0</property>
	  <property name="expand">True</property>
	  <property name="fill">True</property>
	</packing>
      </child>
    </widget>
  </child>
</widget>

<widget class="GtkDialog" id="features_dialog">
  <property name="width_request">700</property>
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
    <widget class="GtkVBox" id="dialog-vbox2">
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area2">
	  <property name="layout_style">GTK_BUTTONBOX_END</property>

	  <child>
	    <widget class="GtkButton" id="close-button">
	      <property name="can_focus">True</property>
	      <property name="label">gtk-close</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">0</property>
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
	<widget class="GtkVBox" id="vbox4">
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkHBox" id="hbox6">
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label8">
		  <property name="label" translatable="yes"> from record: </property>
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
		<widget class="GtkSpinButton" id="spinbutton1">
		  <property name="can_focus">True</property>
		  <property name="climb_rate">1</property>
		  <property name="digits">0</property>
		  <property name="numeric">False</property>
		  <property name="update_policy">GTK_UPDATE_ALWAYS</property>
		  <property name="snap_to_ticks">False</property>
		  <property name="wrap">False</property>
		  <property name="adjustment">1 1 1e+06 1 10 10</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="label9">
		  <property name="label" translatable="yes">  show max </property>
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
		<widget class="GtkSpinButton" id="spinbutton2">
		  <property name="can_focus">True</property>
		  <property name="climb_rate">1</property>
		  <property name="digits">0</property>
		  <property name="numeric">False</property>
		  <property name="update_policy">GTK_UPDATE_ALWAYS</property>
		  <property name="snap_to_ticks">False</property>
		  <property name="wrap">False</property>
		  <property name="adjustment">10 1 1000 1 10 10</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="label10">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes"> records</property>
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
	      <property name="expand">False</property>
	      <property name="fill">False</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkScrolledWindow" id="scrolledwindow5">
	      <property name="can_focus">True</property>
	      <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="shadow_type">GTK_SHADOW_IN</property>
	      <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

	      <child>
		<widget class="GtkTreeView" id="treeview1">
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

<widget class="GtkDialog" id="property_dialog">
  <property name="border_width">3</property>
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
      <property name="spacing">5</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area1">
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
	    <widget class="GtkButton" id="okbutton1">
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
	<widget class="GtkHBox" id="hbox1">
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkLabel" id="label1">
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
	  <property name="expand">True</property>
	  <property name="fill">True</property>
	</packing>
      </child>

      <child>
	<widget class="GtkHBox" id="hbox14">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkLabel" id="label28">
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
	      <property name="adjustment">1 1 255 1 10 10</property>
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
	<widget class="GtkHBox" id="hbox7">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkLabel" id="label11">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">Render as: </property>
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
	    <widget class="GtkComboBox" id="combobox1">
	      <property name="visible">True</property>
	      <property name="items" translatable="yes">Native
Points
Lines
Areas</property>
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
	<widget class="GtkHBox" id="hbox9">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkLabel" id="label15">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">Geom. type: </property>
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
	    <widget class="GtkLabel" id="geom_type_lbl">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">label16</property>
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
	<widget class="GtkHBox" id="hbox11">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkLabel" id="label17">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">Number of features: </property>
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
	    <widget class="GtkLabel" id="feature_count_lbl">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">label18</property>
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
	<widget class="GtkHBox" id="hbox12">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkLabel" id="label25">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">Datasource: </property>
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
	    <widget class="GtkLabel" id="datasource_lbl">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">label26</property>
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
	<widget class="GtkHBox" id="hbox13">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkLabel" id="label27">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">SQL: </property>
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
	    <widget class="GtkLabel" id="sql_lbl">
	      <property name="visible">True</property>
	      <property name="label" translatable="yes">label28</property>
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

<widget class="GtkDialog" id="geom_dialog">
  <property name="width_request">500</property>
  <property name="height_request">500</property>
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
    <widget class="GtkVBox" id="dialog-vbox3">
      <property name="visible">True</property>
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area3">
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
	<widget class="GtkVBox" id="vbox5">
	  <property name="visible">True</property>
	  <property name="homogeneous">False</property>
	  <property name="spacing">0</property>

	  <child>
	    <widget class="GtkHBox" id="hbox8">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label12">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">from vertex: </property>
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
		<widget class="GtkSpinButton" id="from_vertex_sp">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="climb_rate">1</property>
		  <property name="digits">0</property>
		  <property name="numeric">False</property>
		  <property name="update_policy">GTK_UPDATE_ALWAYS</property>
		  <property name="snap_to_ticks">False</property>
		  <property name="wrap">False</property>
		  <property name="adjustment">1 1 100000 1 10 10</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="label13">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes"> show max </property>
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
		<widget class="GtkSpinButton" id="max_vertices_sp">
		  <property name="visible">True</property>
		  <property name="can_focus">True</property>
		  <property name="climb_rate">1</property>
		  <property name="digits">0</property>
		  <property name="numeric">False</property>
		  <property name="update_policy">GTK_UPDATE_ALWAYS</property>
		  <property name="snap_to_ticks">False</property>
		  <property name="wrap">False</property>
		  <property name="adjustment">100 1 10000 1 10 10</property>
		</widget>
		<packing>
		  <property name="padding">0</property>
		  <property name="expand">False</property>
		  <property name="fill">False</property>
		</packing>
	      </child>

	      <child>
		<widget class="GtkLabel" id="label14">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes"> vertices</property>
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
	      <property name="expand">False</property>
	      <property name="fill">False</property>
	    </packing>
	  </child>

	  <child>
	    <widget class="GtkScrolledWindow" id="scrolledwindow6">
	      <property name="visible">True</property>
	      <property name="can_focus">True</property>
	      <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="shadow_type">GTK_SHADOW_IN</property>
	      <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

	      <child>
		<widget class="GtkTreeView" id="treeview3">
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
	<packing>
	  <property name="padding">0</property>
	  <property name="expand">True</property>
	  <property name="fill">True</property>
	</packing>
      </child>
    </widget>
  </child>
</widget>

<widget class="GtkDialog" id="rasterize_dialog">
  <property name="width_request">500</property>
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
	    <widget class="GtkButton" id="cancelbutton2">
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
	    <widget class="GtkButton" id="okbutton2">
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
	    <widget class="GtkHBox" id="hbox15">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label29">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Select raster to be as a model for the canvas: </property>
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
		<widget class="GtkComboBox" id="like_combobox">
		  <property name="visible">True</property>
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
	    <widget class="GtkHBox" id="hbox16">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label30">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Render the data as: </property>
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
		<widget class="GtkComboBox" id="rasterize_render_as_combobox">
		  <property name="visible">True</property>
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
	    <widget class="GtkHBox" id="hbox17">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label31">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Enter the fid of the feature to be rendered (optional): </property>
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
		<widget class="GtkEntry" id="rasterize_fid_entry">
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
	    <widget class="GtkHBox" id="hbox18">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label32">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Select a field for the value (optional): </property>
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
		<widget class="GtkComboBox" id="rasterize_value_comboboxentry">
		  <property name="visible">True</property>
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
	    <widget class="GtkHBox" id="hbox19">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label33">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">'Nodata value' to be used: </property>
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
		<widget class="GtkEntry" id="rasterize_nodata_value_entry">
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

<widget class="GtkDialog" id="colors_dialog">
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
    <widget class="GtkVBox" id="dialog-vbox5">
      <property name="width_request">664</property>
      <property name="height_request">594</property>
      <property name="visible">True</property>
      <property name="homogeneous">False</property>
      <property name="spacing">0</property>

      <child internal-child="action_area">
	<widget class="GtkHButtonBox" id="dialog-action_area5">
	  <property name="visible">True</property>
	  <property name="layout_style">GTK_BUTTONBOX_END</property>

	  <child>
	    <widget class="GtkButton" id="copy_colortable_button">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="label">gtk-add</property>
	      <property name="use_stock">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">3</property>
	    </widget>
	  </child>

	  <child>
	    <widget class="GtkButton" id="color_button">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">2</property>

	      <child>
		<widget class="GtkAlignment" id="alignment6">
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
		    <widget class="GtkHBox" id="hbox26">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">2</property>

		      <child>
			<widget class="GtkImage" id="image6">
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
			<widget class="GtkLabel" id="label41">
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
	    <widget class="GtkButton" id="button7">
	      <property name="visible">True</property>
	      <property name="can_default">True</property>
	      <property name="can_focus">True</property>
	      <property name="relief">GTK_RELIEF_NORMAL</property>
	      <property name="focus_on_click">True</property>
	      <property name="response_id">1</property>

	      <child>
		<widget class="GtkAlignment" id="alignment5">
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
		    <widget class="GtkHBox" id="hbox25">
		      <property name="visible">True</property>
		      <property name="homogeneous">False</property>
		      <property name="spacing">2</property>

		      <child>
			<widget class="GtkImage" id="image5">
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
			<widget class="GtkLabel" id="label40">
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
	    <widget class="GtkButton" id="button8">
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
	    <widget class="GtkButton" id="button9">
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
	    <widget class="GtkButton" id="button10">
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
	  <property name="spacing">2</property>

	  <child>
	    <widget class="GtkHBox" id="hbox22">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label36">
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
	    <widget class="GtkHBox" id="hbox23">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label37">
		  <property name="visible">True</property>
		  <property name="label" translatable="yes">Color is based on: </property>
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
		<widget class="GtkComboBox" id="color_from_combobox">
		  <property name="visible">True</property>
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
	    <widget class="GtkHBox" id="hbox24">
	      <property name="visible">True</property>
	      <property name="homogeneous">False</property>
	      <property name="spacing">0</property>

	      <child>
		<widget class="GtkLabel" id="label38">
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
		<widget class="GtkLabel" id="label39">
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
	    <widget class="GtkScrolledWindow" id="scrolledwindow7">
	      <property name="visible">True</property>
	      <property name="can_focus">True</property>
	      <property name="hscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="vscrollbar_policy">GTK_POLICY_ALWAYS</property>
	      <property name="shadow_type">GTK_SHADOW_IN</property>
	      <property name="window_placement">GTK_CORNER_TOP_LEFT</property>

	      <child>
		<widget class="GtkTreeView" id="colortable_treeview">
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
