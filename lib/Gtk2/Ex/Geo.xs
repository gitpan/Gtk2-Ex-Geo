#include <gtk2perl.h>
#include <cairo-perl.h>

/* This xs file provides and the definition of the struct
gtk2_ex_geo_pixbuf and the following methods:

- gtk2_ex_geo_pixbuf_create (create the struct and the cairo surface)
- gtk2_ex_geo_pixbuf_get_cairo_surface (get a handle to the cairo surface)
- gtk2_ex_geo_pixbuf_get_pixbuf (convert the cairo surface to a gdk pixbuf)
- gtk2_ex_geo_pixbuf_destroy (destroy the cairo surface and the struct)

and

- gtk2_ex_geo_pixbuf_destroy_notify (destroy the pixbuf))

If libral is available (HAVE_RAL is defined), these methods link to
those in libral, otherwise they are implemented here. This xs file
contains a lot of unncessary methods if HAVE_RAL since there is a
problem in moving them into appropriate xs files in
Gtk2::Ex::Geo::Raster and Vector in MinGW environment. */

#ifdef HAVE_RAL

#include <ral.h>

#else

static void
gtk2_ex_geo_pixbuf_destroy_notify (guchar * pixels,
			   gpointer data)
{
	/*fprintf(stderr,"free %#x\n",pixels);*/
	free(pixels);
}
typedef struct {

    /** cairo image, each pixel is 4 bytes XRGB (BGRX if little endian) */
    unsigned char *image;

    /** rowstride of the cairo image */
    int image_rowstride;

    /** pixbuf data, each pixel is 3 bytes RGB, freed in gtk2_ex_geo_pixbuf_destroy_notify */
    guchar *pixbuf;

    /** needed for gdk pixbuf */
    GdkPixbufDestroyNotify destroy_fn;

    /** needed for gdk pixbuf */
    GdkColorspace colorspace;

    /** needed for gdk pixbuf */
    gboolean has_alpha;

    /** needed for gdk pixbuf */
    int rowstride;
    
    /** needed for gdk pixbuf */
    int bits_per_sample;

    int width;
    int height;

    /** geographic world */
    double world_min_x;
    double world_max_y;

    /** size of pixel in geographic space */
    double pixel_size;

} gtk2_ex_geo_pixbuf;

#endif

#ifdef HAVE_RAL

#define RAL_GRIDPTR "ral_gridPtr"
#define RAL_ERRSTR_OOM "Out of memory"

IV SV2Handle(SV *sv)
{
	if (SvGMAGICAL(sv))
		mg_get(sv);
	if (!sv_isobject(sv))
		croak("parameter is not an object");
	SV *tsv = (SV*)SvRV(sv);
	if ((SvTYPE(tsv) != SVt_PVHV))
		croak("parameter is not a hashref");
	if (!SvMAGICAL(tsv))
		croak("parameter does not have magic");
	MAGIC *mg = mg_find(tsv,'P');
	if (!mg)
		croak("parameter does not have right kind of magic");
	sv = mg->mg_obj;
	if (!sv_isobject(sv))
		croak("parameter does not have really right kind of magic");
	return SvIV((SV*)SvRV(sv));
}

IV SV2Object(SV *sv, char *stash)
{
	if (!sv_isobject(sv)) {
		croak("parameter is not an object");
		return 0;
	}
	sv = (SV*)SvRV(sv);
	if (strcmp(stash,HvNAME((HV*)SvSTASH(sv)))!=0) {
		croak("parameter is not a %s",stash);
		return 0;
	}
	return SvIV(sv);
}

GDALColorEntry fetch_color(AV *a, int i)
{
	GDALColorEntry color;
	SV **s = av_fetch(a, i++, 0);
	color.c1 = s ? SvUV(*s) : 0;
	s = av_fetch(a, i++, 0);
	color.c2 = s ? SvUV(*s) : 0;
	s = av_fetch(a, i++, 0);
	color.c3 = s ? SvUV(*s) : 0;
	s = av_fetch(a, i++, 0);
	color.c4 = s ? SvUV(*s) : 0;
	return color;
}

#define RAL_FETCH(from, key, to, as) \
{SV **s = hv_fetch(from, key, strlen(key), 0);\
 if (s) {\
	(to) = as(*s);\
}}

#define RAL_STORE(to, key, from, with) \
hv_store(to, key, strlen(key), with(from), 0);

int fetch2visual(HV *perl_layer, ral_visual *visual, OGRFeatureDefnH defn)
{
	/* these are mostly from the Geo::Layer object */
	RAL_FETCH(perl_layer, "ALPHA", visual->alpha, SvIV);
	RAL_FETCH(perl_layer, "PALETTE_VALUE", visual->palette_type, SvIV);
	RAL_FETCH(perl_layer, "SYMBOL_VALUE", visual->symbol, SvIV);
	RAL_FETCH(perl_layer, "SYMBOL_SIZE", visual->symbol_pixel_size, SvIV);
	RAL_FETCH(perl_layer, "HUE_AT_MIN", visual->hue_at.min, SvIV);
	RAL_FETCH(perl_layer, "HUE_AT_MAX", visual->hue_at.max, SvIV);
	RAL_FETCH(perl_layer, "HUE_DIR", visual->hue_dir, SvIV);
	RAL_FETCH(perl_layer, "HUE", visual->hue, SvIV);
	SV **s = hv_fetch(perl_layer, "SINGLE_COLOR", strlen("SINGLE_COLOR"), 0);
	if (s AND SvROK(*s)) {
		AV *a = (AV*)SvRV(*s);
		if (a)
			visual->single_color = fetch_color(a, 0);
	}
	RAL_FETCH(perl_layer, "SYMBOL_FIELD_VALUE", visual->symbol_field, SvIV);
	OGRFieldType symbol_field_type;
	if (visual->symbol_field >= 0) {
		RAL_CHECK(ral_get_field_type(defn, visual->symbol_field, &symbol_field_type));
	} else /* FID or fixed size */
		symbol_field_type = OFTInteger;

	switch (symbol_field_type) {
	case OFTInteger:
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MIN", visual->symbol_size_int.min, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MAX", visual->symbol_size_int.max, SvIV);
		break;
	case OFTReal:
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MIN", visual->symbol_size_double.min, SvNV);
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MAX", visual->symbol_size_double.max, SvNV);
		break;
	default:
		RAL_CHECKM(0, ral_msg("Invalid field type for symbol scale: %s", OGR_GetFieldTypeName(symbol_field_type)));
		break;
	}

	RAL_FETCH(perl_layer, "COLOR_FIELD_VALUE", visual->color_field, SvIV);
	OGRFieldType color_field_type;
	if (visual->color_field >= 0) {
		RAL_CHECK(ral_get_field_type(defn, visual->color_field, &color_field_type));
	} else /* FID */
		color_field_type = OFTInteger;

	switch (color_field_type) {
	case OFTInteger:
		RAL_FETCH(perl_layer, "COLOR_SCALE_MIN", visual->color_int.min, SvIV);
		RAL_FETCH(perl_layer, "COLOR_SCALE_MAX", visual->color_int.max, SvIV);
		break;
	case OFTReal:
		RAL_FETCH(perl_layer, "COLOR_SCALE_MIN", visual->color_double.min, SvNV);
		RAL_FETCH(perl_layer, "COLOR_SCALE_MAX", visual->color_double.max, SvNV);
		break;
	case OFTString:
		break;
	default:
		RAL_CHECKM(0, ral_msg("Invalid field type for color scale: %s", OGR_GetFieldTypeName(color_field_type)));
		break;
	}
	
	RAL_FETCH(perl_layer, "RENDER_AS_VALUE", visual->render_as, SvIV);
	s = hv_fetch(perl_layer, "COLOR_TABLE", strlen("COLOR_TABLE"), 0);
	if (visual->palette_type == RAL_PALETTE_COLOR_TABLE AND s AND SvROK(*s)) {
		AV *a = (AV*)SvRV(*s);
		int i, n = a ? av_len(a)+1 : 0;
		if (n > 0) {
			switch (color_field_type) {
			case OFTInteger:
				RAL_CHECK(visual->color_table = ral_color_table_create(n));
				for (i = 0; i < n; i++) {
					SV **s = av_fetch(a, i, 0);
					AV *c;
					RAL_CHECKM(s AND SvROK(*s) AND (c = (AV*)SvRV(*s)), "Bad color table data");
					s = av_fetch(c, 0, 0);
					visual->color_table->keys[i] = s ? SvIV(*s) : 0;
					visual->color_table->colors[i] = fetch_color(c, 1);
				}
				break;
			case OFTString:
				RAL_CHECK(visual->string_color_table = ral_string_color_table_create(n));
				for (i = 0; i < n; i++) {
					STRLEN len;
					SV **s = av_fetch(a, i, 0);
					AV *c;
					RAL_CHECKM(s AND SvROK(*s) AND (c = (AV*)SvRV(*s)), "Bad color table data");
					s = av_fetch(c, 0, 0);
					if (s)
						ral_string_color_table_set(visual->string_color_table, SvPV(*s, len), i, fetch_color(c, 1));
				}
				break;
			default:
    				RAL_CHECKM(0, ral_msg("Invalid field type for color table: %s", OGR_GetFieldTypeName(color_field_type)));
			}
		}
	}
	s = hv_fetch(perl_layer, "COLOR_BINS", strlen("COLOR_BINS"), 0);
	if (visual->palette_type == RAL_PALETTE_COLOR_BINS AND s AND SvROK(*s)) {
		AV *a = (AV*)SvRV(*s);
		int i, n = a ? av_len(a)+1 : 0;
		if (n > 0) {
			switch (color_field_type) {
			case OFTInteger:
    				RAL_CHECK(visual->int_bins = ral_int_color_bins_create(n));
				for (i = 0; i < n; i++) {
					SV **s = av_fetch(a, i, 0);
					AV *c;
					RAL_CHECKM(s AND SvROK(*s) AND (c = (AV*)SvRV(*s)), "Bad color bins data");
					s = av_fetch(c, 0, 0);
					if (i < n-1)
						visual->int_bins->bins[i] = s ? SvIV(*s) : 0;
					visual->int_bins->colors[i] = fetch_color(c, 1);
				}
			    	break;
			case OFTReal:
				RAL_CHECK(visual->double_bins = ral_double_color_bins_create(n));
				for (i = 0; i < n; i++) {
					SV **s = av_fetch(a, i, 0);
					AV *c;
					RAL_CHECKM(s AND SvROK(*s) AND (c = (AV*)SvRV(*s)), "Bad color bins data");
					s = av_fetch(c, 0, 0);
					if (i < n-1)
						visual->double_bins->bins[i] = s ? SvNV(*s) : 0;
					visual->double_bins->colors[i] = fetch_color(c, 1);
				}
				break;
			default:
				RAL_CHECKM(0, ral_msg("Invalid field type for color bins: %s", OGR_GetFieldTypeName(color_field_type)));
			}
		}
	}
	return 1;
	fail:
	return 0;
}

#endif

MODULE = Gtk2::Ex::Geo		PACKAGE = Gtk2::Ex::Geo

#ifndef HAVE_RAL

gtk2_ex_geo_pixbuf *
gtk2_ex_geo_pixbuf_create(int width, int height, double minX, double maxY, double pixel_size, int bgc1, int bgc2, int bgc3)
	CODE:
		gtk2_ex_geo_pixbuf *pb = malloc(sizeof(gtk2_ex_geo_pixbuf));
		if (pb) {
			pb->pixbuf = NULL;
			pb->destroy_fn = NULL;
			pb->image = malloc(4*width*height);
			pb->colorspace = GDK_COLORSPACE_RGB;
			pb->has_alpha = FALSE;
			pb->image_rowstride = 4 * width;
			pb->rowstride = 3 * width;
			pb->bits_per_sample = 8;
			pb->height = height;
			pb->width = width;
			pb->world_min_x = minX;
			pb->world_max_y = maxY;
			pb->pixel_size = pixel_size;
			if (pb->image) {
				int i,j;
				for (i = 0; i < height; i++) for (j = 0; j < width; j++) {
					int k = 4*i*width+4*j;
					(pb->image)[k+3] = 255;
 					(pb->image)[k+2] = bgc1;
					(pb->image)[k+1] = bgc2;
					(pb->image)[k+0] = bgc3;
				}
			} else {
				free(pb);
				croak("Out of memory");
			}
		} else
			croak("Out of memory");
		RETVAL = pb;
	OUTPUT:
		RETVAL

cairo_surface_t_noinc *
gtk2_ex_geo_pixbuf_get_cairo_surface(gtk2_ex_geo_pixbuf *pb)
	CODE:
		RETVAL = cairo_image_surface_create_for_data
			(pb->image, CAIRO_FORMAT_ARGB32, pb->width, pb->height, pb->image_rowstride);
	OUTPUT:
		RETVAL

GdkPixbuf_noinc *
gtk2_ex_geo_pixbuf_get_pixbuf(gtk2_ex_geo_pixbuf *pb)
	CODE:
		guint i, j;
		unsigned char *src, *dst;

		free(pb->pixbuf);
		pb->pixbuf = malloc(4*pb->width*pb->height);
		if (!pb->pixbuf)
			croak("Out of memory");
		pb->destroy_fn = gtk2_ex_geo_pixbuf_destroy_notify;

		dst = pb->pixbuf;
		src = pb->image;

		for (i = 0; i < pb->height; i++) {
			for (j = 0; j < pb->width; j++) {
#if G_BYTE_ORDER == G_LITTLE_ENDIAN
				dst[0] = src[2];
				dst[1] = src[1];
				dst[2] = src[0];
#else
				dst[0] = src[1];
				dst[1] = src[2];
				dst[2] = src[3];
#endif
				src += 4;
				dst += 3;
			}
		}
	OUTPUT:
		RETVAL

void
gtk2_ex_geo_pixbuf_destroy(gtk2_ex_geo_pixbuf *pb)
	CODE:
		free(pb->image);
		free(pb);

#else

ral_pixbuf *
gtk2_ex_geo_pixbuf_create(int width, int height, double minX, double maxY, double pixel_size, int bgc1, int bgc2, int bgc3)
	CODE:
		GDALColorEntry background = {bgc1, bgc2, bgc3, 255};
		ral_pixbuf *pb = ral_pixbuf_create(width, height, minX, maxY, pixel_size, background);
		RETVAL = pb;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

ral_pixbuf *
ral_pixbuf_create_from_grid(gd)
	ral_grid *gd
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void 
gtk2_ex_geo_pixbuf_destroy(pb)
	ral_pixbuf *pb
	CODE:
	ral_pixbuf_destroy(&pb);

void
ral_pixbuf_save(pb, filename, type, option_keys, option_values)
	ral_pixbuf *pb
	const char *filename
	const char *type
	AV* option_keys
	AV* option_values
	CODE:
		GdkPixbuf *gpb;
		GError *error = NULL;
		int i;
		char **ok = NULL;
		char **ov = NULL;
		int size = av_len(option_keys)+1;
		gpb = ral_gdk_pixbuf(pb);
		RAL_CHECKM(ok = (char **)calloc(size, sizeof(char *)), RAL_ERRSTR_OOM);
		RAL_CHECKM(ov = (char **)calloc(size, sizeof(char *)), RAL_ERRSTR_OOM);
		for (i = 0; i < size; i++) {
			STRLEN len;
			SV **s = av_fetch(option_keys, i, 0);
			ok[i] = SvPV(*s, len);
			s = av_fetch(option_values, i, 0);
			ov[i] = SvPV(*s, len);
		}
		gdk_pixbuf_savev(gpb, filename, type, ok, ov, &error);
		fail:
		if (ok) {
			for (i = 0; i < size; i++) {
				if (ok[i]) free (ok[i]);
			}
			free(ok);
		}
		if (ov) {
			for (i = 0; i < size; i++) {
				if (ov[i]) free (ov[i]);
			}
			free(ov);
		}
		if (error) {
			croak(error->message);
			g_error_free(error);
		}
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

AV *
ral_pixbuf_get_world(pb)
	ral_pixbuf *pb
	CODE:
		AV *av = (AV *)sv_2mortal((SV*)newAV());
		av_push(av, newSVnv(pb->world.min.x));
		av_push(av, newSVnv(pb->world.min.y));
		av_push(av, newSVnv(pb->world.max.x));
		av_push(av, newSVnv(pb->world.max.y));
		av_push(av, newSVnv(pb->pixel_size));
		av_push(av, newSViv(pb->N));
		av_push(av, newSViv(pb->M));
		RETVAL = av;
  OUTPUT:
    RETVAL

ral_integer_grid_layer *
ral_make_integer_grid_layer(perl_layer)
	HV *perl_layer
	CODE:
		ral_integer_grid_layer *layer = ral_integer_grid_layer_create();
		SV **s = hv_fetch(perl_layer, "ALPHA", strlen("ALPHA"), 0);
		if (s) {
			if (SvIOK(*s))
				layer->alpha = SvIV(*s);
			else if (sv_isobject(*s)) {
				RAL_CHECK(layer->alpha_grid = (ral_grid*)SV2Object(*s, RAL_GRIDPTR));
			}
		}
		RAL_FETCH(perl_layer, "PALETTE_VALUE", layer->palette_type, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_VALUE", layer->symbol, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_SIZE", layer->symbol_pixel_size, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MIN", layer->symbol_size_min, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MAX", layer->symbol_size_max, SvIV);
		s = hv_fetch(perl_layer, "SINGLE_COLOR", strlen("SINGLE_COLOR"), 0);
		if (s AND SvROK(*s)) {
			AV *a = (AV*)SvRV(*s);
			layer->single_color = fetch_color((AV *)SvRV(*s), 0);
		}
		RAL_FETCH(perl_layer, "HUE_AT_MIN", layer->hue_at.min, SvIV);
		RAL_FETCH(perl_layer, "HUE_AT_MAX", layer->hue_at.max, SvIV);
		RAL_FETCH(perl_layer, "HUE_DIR", layer->hue_dir, SvIV);
		RAL_FETCH(perl_layer, "HUE", layer->hue, SvIV);
		RAL_FETCH(perl_layer, "COLOR_SCALE_MIN", layer->range.min, SvIV);
		RAL_FETCH(perl_layer, "COLOR_SCALE_MAX", layer->range.max, SvIV);
		s = hv_fetch(perl_layer, "COLOR_TABLE", strlen("COLOR_TABLE"), 0);
		if (s AND SvROK(*s)) {
			AV *a = (AV*)SvRV(*s);
			int i, n = a ? av_len(a)+1 : 0;
			if (n > 0) {
				RAL_CHECK(layer->color_table = ral_color_table_create(n));
				for (i = 0; i < n; i++) {
					SV **s = av_fetch(a, i, 0);
					AV *c;
					RAL_CHECKM(s AND SvROK(*s) AND (c = (AV*)SvRV(*s)), "Bad color table data");
					s = av_fetch(c, 0, 0);
					layer->color_table->keys[i] = s ? SvIV(*s) : 0;
					layer->color_table->colors[i] = fetch_color(c, 1);
				}
			}
		}
		s = hv_fetch(perl_layer, "COLOR_BINS", strlen("COLOR_BINS"), 0);
		if (s AND SvROK(*s)) {
			AV *a = (AV*)SvRV(*s);
			int i, n = a ? av_len(a)+1 : 0;
			if (n > 0) {
				RAL_CHECK(layer->color_bins = ral_integer_color_bins_create(n));
				for (i = 0; i < n; i++) {
					SV **s = av_fetch(a, i, 0);
					AV *c;
					RAL_CHECKM(s AND SvROK(*s) AND (c = (AV*)SvRV(*s)), "Bad color bins data");
					s = av_fetch(c, 0, 0);
					if (i < n-1)
						layer->color_bins->bins[i] = s ? SvIV(*s) : 0;
					layer->color_bins->colors[i] = fetch_color(c, 1);
				}
			}
		}
		goto ok;
		fail:
		ral_integer_grid_layer_destroy(&layer);
		layer = NULL;
		ok:
		RETVAL = layer;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());


void
ral_destroy_integer_grid_layer(layer)
	ral_integer_grid_layer *layer
	CODE:
		ral_integer_grid_layer_destroy(&layer);


ral_real_grid_layer *
ral_make_real_grid_layer(perl_layer)
	HV *perl_layer
	CODE:
		ral_real_grid_layer *layer = ral_real_grid_layer_create();
		SV **s = hv_fetch(perl_layer, "ALPHA", strlen("ALPHA"), 0);
		if (s) {
			if (SvIOK(*s))
				layer->alpha = SvIV(*s);
			else if (sv_isobject(*s)) {
				RAL_CHECK(layer->alpha_grid = (ral_grid*)SV2Object(*s, RAL_GRIDPTR));
			}
		}
		RAL_FETCH(perl_layer, "PALETTE_VALUE", layer->palette_type, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_VALUE", layer->symbol, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_SIZE", layer->symbol_pixel_size, SvIV);
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MIN", layer->symbol_size_min, SvNV);
		RAL_FETCH(perl_layer, "SYMBOL_SCALE_MAX", layer->symbol_size_max, SvNV);
		s = hv_fetch(perl_layer, "SINGLE_COLOR", strlen("SINGLE_COLOR"), 0);
		if (s AND SvROK(*s)) {
			AV *a = (AV*)SvRV(*s);
			layer->single_color = fetch_color((AV *)SvRV(*s), 0);
		}
		RAL_FETCH(perl_layer, "HUE_AT_MIN", layer->hue_at.min, SvIV);
		RAL_FETCH(perl_layer, "HUE_AT_MAX", layer->hue_at.max, SvIV);
		RAL_FETCH(perl_layer, "HUE_DIR", layer->hue_dir, SvIV);
		RAL_FETCH(perl_layer, "HUE", layer->hue, SvIV);
		RAL_FETCH(perl_layer, "COLOR_SCALE_MIN", layer->range.min, SvNV);
		RAL_FETCH(perl_layer, "COLOR_SCALE_MAX", layer->range.max, SvNV);
		s = hv_fetch(perl_layer, "COLOR_BINS", strlen("COLOR_BINS"), 0);
		if (s AND SvROK(*s)) {
			AV *a = (AV*)SvRV(*s);
			int i, n = a ? av_len(a)+1 : 0;
			if (n > 0) {
				RAL_CHECK(layer->color_bins = ral_real_color_bins_create(n));
				for (i = 0; i < n; i++) {
					SV **s = av_fetch(a, i, 0);
					AV *c;
					RAL_CHECKM(s AND SvROK(*s) AND (c = (AV*)SvRV(*s)), "Bad color bins data");
					s = av_fetch(c, 0, 0);
					if (i < n-1)
						layer->color_bins->bins[i] = s ? SvNV(*s) : 0;
					layer->color_bins->colors[i] = fetch_color(c, 1);
				}
			}
		}
		goto ok;
		fail:
		ral_real_grid_layer_destroy(&layer);
		layer = NULL;
		ok:
		RETVAL = layer;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());


void
ral_destroy_real_grid_layer(layer);
	ral_real_grid_layer *layer
	CODE:
		ral_real_grid_layer_destroy(&layer);


void 
ral_render_igrid(pb, gd, layer)
	ral_pixbuf *pb
	ral_grid *gd
	ral_integer_grid_layer *layer
	CODE:
		layer->gd = gd;
		ral_render_integer_grid(pb, layer);
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());


void 
ral_render_rgrid(pb, gd, layer)
	ral_pixbuf *pb
	ral_grid *gd
	ral_real_grid_layer *layer
	CODE:
		layer->gd = gd;
		ral_render_real_grid(pb, layer);
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void 
ral_render_grids(pb, b1, b2, b3, alpha, color_interpretation)
	ral_pixbuf *pb
	ral_grid *b1
	ral_grid *b2
	ral_grid *b3
	SV *alpha
	int color_interpretation
	CODE:
		short a = 255;
		ral_grid *a_gd = NULL;
		if (SvIOK(alpha))
			a = SvIV(alpha);
		else if (sv_isobject(alpha)) {
			RAL_CHECK(a_gd = (ral_grid*)SV2Object(alpha, RAL_GRIDPTR));
		} else {
			croak("alpha is not integer nor a grid");
			goto fail;
		}
		/*ral_render_grids(pb, b1, b2, b3, a, a_gd, color_interpretation);*/
		fail:
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());


ral_visual_layer *
ral_visual_layer_create(perl_layer, ogr_layer)
	HV *perl_layer
	OGRLayerH ogr_layer
	CODE:
		ral_visual_layer *layer = ral_visual_layer_create();
		layer->layer = ogr_layer;
		RAL_CHECK(fetch2visual(perl_layer, &layer->visualization, OGR_L_GetLayerDefn(layer->layer)));
		RAL_FETCH(perl_layer, "EPSG_FROM", layer->EPSG_from, SvIV);
		RAL_FETCH(perl_layer, "EPSG_TO", layer->EPSG_to, SvIV);
		goto ok;
		fail:
		ral_visual_layer_destroy(&layer);
		layer = NULL;
		ok:
		RETVAL = layer;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void
ral_visual_layer_destroy(layer)
	ral_visual_layer *layer
	CODE:
		ral_visual_layer_destroy(&layer);

void
ral_visual_layer_render(layer, pb)
	ral_visual_layer *layer
	ral_pixbuf *pb
	CODE:
		ral_render_visual_layer(pb, layer);
	POSTCALL:
	if (ral_has_msg())
		croak(ral_get_msg());

ral_visual_feature_table *
ral_visual_feature_table_create(perl_layer, features)
	HV *perl_layer
	AV *features
	CODE:
		ral_visual_feature_table *layer = ral_visual_feature_table_create(av_len(features)+1);
		RAL_CHECK(layer);
		char *color_field_name = NULL, *symbol_size_field_name = NULL;;

		RAL_FETCH(perl_layer, "COLOR_FIELD", color_field_name, SvPV_nolen);
		RAL_FETCH(perl_layer, "SYMBOL_FIELD", symbol_size_field_name, SvPV_nolen);

		int i;
		for (i = 0; i <= av_len(features); i++) {
			SV** sv = av_fetch(features,i,0);
			OGRFeatureH f = SV2Handle(*sv);
			layer->features[i].feature = f;
			OGRFeatureDefnH fed = OGR_F_GetDefnRef(f);

			int field = -1;
			if (color_field_name) {
				field = OGR_FD_GetFieldIndex(fed, color_field_name);
				if (field >= 0) {
					OGRFieldDefnH fid = OGR_FD_GetFieldDefn(fed, field);
					OGRFieldType fit = OGR_Fld_GetType(fid);
					if (!(fit == OFTInteger OR fit == OFTReal))
						field = -1;
				}
			}
			RAL_STORE(perl_layer, "COLOR_FIELD_VALUE", field, newSViv);

			field = -2;
			if (symbol_size_field_name) {
				field = OGR_FD_GetFieldIndex(fed, symbol_size_field_name);
				if (field >= 0) {
					OGRFieldDefnH fid = OGR_FD_GetFieldDefn(fed, field);
					OGRFieldType fit = OGR_Fld_GetType(fid);
					if (!(fit == OFTInteger OR fit == OFTReal))
						field = -2;
				} else
					field = -2;
			}
			RAL_STORE(perl_layer, "SYMBOL_FIELD_VALUE", field, newSViv);

			RAL_CHECK(fetch2visual(perl_layer, &layer->features[i].visualization, OGR_F_GetDefnRef(f)));
			
		}

		RAL_FETCH(perl_layer, "EPSG_FROM", layer->EPSG_from, SvIV);
		RAL_FETCH(perl_layer, "EPSG_TO", layer->EPSG_to, SvIV);
		goto ok;
		fail:
		ral_visual_feature_table_destroy(&layer);
		layer = NULL;
		ok:
		RETVAL = layer;
  OUTPUT:
    RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void
ral_visual_feature_table_destroy(layer)
	ral_visual_feature_table *layer
	CODE:
		ral_visual_feature_table_destroy(&layer);

void
ral_visual_feature_table_render(layer, pb)
	ral_visual_feature_table *layer
	ral_pixbuf *pb
	CODE:
		ral_render_visual_feature_table(pb, layer);
	POSTCALL:
	if (ral_has_msg())
		croak(ral_get_msg());

GdkPixbuf_noinc *
gtk2_ex_geo_pixbuf_get_pixbuf(ral_pixbuf *pb)
	CODE:
		if (ral_cairo_to_pixbuf(pb))
			RETVAL = ral_gdk_pixbuf(pb);
	OUTPUT:
		RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

cairo_surface_t_noinc *
gtk2_ex_geo_pixbuf_get_cairo_surface(pb)
	ral_pixbuf *pb
    CODE:
	RETVAL = cairo_image_surface_create_for_data
		(pb->image, CAIRO_FORMAT_ARGB32, pb->N, pb->M, pb->image_rowstride);
    OUTPUT:
	RETVAL

#endif
