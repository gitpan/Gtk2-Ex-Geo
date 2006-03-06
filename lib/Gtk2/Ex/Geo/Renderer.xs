#include "gtk2perl.h"
#include "gdal.h"
#include "ogr_api.h"

#include "ral_grid.h"
#include "ral_pixbuf.h"
#include "ral_catchment.h"

MODULE = Gtk2::Ex::Geo::Renderer		PACKAGE = Gtk2::Ex::Geo::Renderer

GdkPixbuf_noinc *
gdk_pixbuf_new_from_data (pb)
	ral_pixbuf *pb
    CODE:
	RETVAL = gdk_pixbuf_new_from_data (pb->data, 
					   pb->colorspace, 
					   pb->has_alpha,
			  		   pb->bits_per_sample,
					   pb->width,
					   pb->height,
					   pb->rowstride,
					   pb->destroy_fn,
					   pb->data);
    OUTPUT:
	RETVAL
