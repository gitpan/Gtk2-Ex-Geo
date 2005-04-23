#include "gtk2perl.h"
#include "ral_grid.h"
#include "ral_ct.h"
#include "ral_catchment.h"

/* the main part of the code in here should perhaps go into libral */

/* these are duplicates, the real ones are in Grid.so but I can't make DynaLoader to find them from there?? */
int debug = 0;
int hashmarks = 1;
int sigint = 0;
grid *mask = NULL;

/* simplifying macros, assume pb in in the current scope */

#define PBINDEX(i,j) (i)*pb.rowstride+(j)*3

/* screen to raster */
#define SCRi2Ri(i,gd) (floor((((gd)->world.max.y - (pb.bbox.max.y - (double)(i)*pb.pixel_width)))/(gd)->unit_length))
#define SCRj2Rj(j,gd) (floor(((pb.bbox.min.x + (double)(j)*pb.pixel_width) - (gd)->world.min.x)/(gd)->unit_length))

/* raster to screen */
#define Ri2SCRi(i, gd) (floor((pb.bbox.max.y - (gd)->world.max.y + (gd)->unit_length * ((double)(i)+0.5))/pb.pixel_width))
#define Rj2SCRj(j, gd) (floor(((gd)->world.min.x - pb.bbox.min.x + (gd)->unit_length * ((double)(j)+0.5))/pb.pixel_width))

#define SET_PIXEL(i,j,R,G,B) \
	{	(pb.data)[PBINDEX(i,j)] = (R); \
		(pb.data)[PBINDEX(i,j)+1] = (G); \
		(pb.data)[PBINDEX(i,j)+2] = (B);	}

#define GET_PIXEL(i,j,R,G,B) \
	{	(R) = (pb.data)[PBINDEX(i,j)]; \
		(G) = (pb.data)[PBINDEX(i,j)+1]; \
		(B) = (pb.data)[PBINDEX(i,j)+2];	}

/* pb.data is RGB image with 256 shades */

#define SET_PIXEL_COLOR(i,j,c) \
	{(pb.data)[PBINDEX(i,j)] = min(max(floor((1-(c.alpha))*(pb.data)[PBINDEX(i,j)]+(c.alpha)*(c.r)*255),0),255); \
	 (pb.data)[PBINDEX(i,j)+1] = min(max(floor((1-(c.alpha))*(pb.data)[PBINDEX(i,j)+1]+(c.alpha)*(c.g)*255),0),255); \
	 (pb.data)[PBINDEX(i,j)+2] = min(max(floor((1-(c.alpha))*(pb.data)[PBINDEX(i,j)+2]+(c.alpha)*(c.b)*255),0),255);}
  

static void
grid2gtk_pixbuf_destroy_notify (guchar * pixels,
                                gpointer data)
{
	/*printf("free %#x\n",pixels);*/
	free(pixels);
}

typedef struct {
	guchar *data;

	int width;
	int height;

	int rowstride;
	int bits_per_sample;
	
	/* world coordinates */
	rectangle bbox;
	double pixel_width;

	/* color info, alpha is a number or a grid, color table is defined in libral */
	double alpha_nv;
	grid *alpha_gd;
	color_table *ct;
	int ct_offset;

	int bg_r;
	int bg_g;
	int bg_b;
	
} pixbuf;

void 
render_shapefile(HV *shapefile, AV *shapes, pixbuf pb)
{
	SV **sv = hv_fetch(shapefile, "MinBounds", 9, 0);
	AV *av  = (AV *)SvRV(*sv);
	sv = av_fetch(av, 0, 0);
	/* minX */
	if (SvNV(*sv) > pb.bbox.max.x) return;

	sv = av_fetch(av, 1, 0);
	/* minY */
	if (SvNV(*sv) > pb.bbox.max.y) return;
	
	sv = hv_fetch(shapefile, "MaxBounds", 9, 0);
	av  = (AV *)SvRV(*sv);
	sv = av_fetch(av, 0, 0);
	/* maxX */
	if (SvNV(*sv) < pb.bbox.min.x) return;

	sv = av_fetch(av, 1, 0);
	/* maxY */
	if (SvNV(*sv) < pb.bbox.min.y) return;

	/* we do not use explicit NShapes (it should probably be removed also from Geo::Shapelib) */

	int NShapes = av_len(shapes) + 1;
	int ShowPoints = 0,sindex;

	sv = hv_fetch(shapefile, "ShowPoints", 10, 0);
	if (sv) ShowPoints = SvIV(*sv);

	/*
	printf("shapefile with %i shapes\n",NShapes);
	*/

	for (sindex = 0; sindex < NShapes; sindex++) {
		if (!shapes) {
			fprintf(stderr,"no shapes any more!\n");
		}
		HV *shape = (HV *)SvRV(*(av_fetch(shapes, sindex, 0)));
		SV **sv = hv_fetch(shape, "SHPType", 7, 0);
		int i, k;
		int SHPType = SvIV(*sv);
		int NParts = 1;
		int NVertices = 0;
		AV *parts = NULL, *vertices = NULL, *av;
		point *points_of_shape = NULL;
		polygon *parts_of_shape = NULL;
		color clr;

		int Selected = 0;
		int NSelectedVertices;
		int *SelectedVertices = NULL;

		sv = hv_fetch(shape, "Hide", 4, 0);
		if (sv) if (SvIV(*sv)) continue;

		sv = hv_fetch(shape, "MinBounds", 9, 0);
		av  = (AV *)SvRV(*sv);
		sv = av_fetch(av, 0, 0);
		/* minX */
		if (SvNV(*sv) > pb.bbox.max.x) continue;

		sv = av_fetch(av, 1, 0);
		/* minY */
		if (SvNV(*sv) > pb.bbox.max.y) continue;

		sv = hv_fetch(shape, "MaxBounds", 9, 0);
		av  = (AV *)SvRV(*sv);
		sv = av_fetch(av, 0, 0);
		/* maxX */
		if (SvNV(*sv) < pb.bbox.min.x) continue;

		sv = av_fetch(av, 1, 0);
		/* max.y */
		if (SvNV(*sv) < pb.bbox.min.y) continue;
	
		/* in shape: Selected, SelectedVertices */
		sv = hv_fetch(shape, "Selected", 8, 0);
		if (sv) Selected = SvIV(*sv);
		sv = hv_fetch(shape, "SelectedVertices", 16, 0);
		if (sv) {
			vertices = (AV *)SvRV(*sv);
			if (vertices) {
				NSelectedVertices = av_len(vertices) + 1;
				SelectedVertices = calloc(NSelectedVertices, sizeof(int));
				for (i = 0; i < NSelectedVertices; i++) {
					SV **sv = av_fetch(vertices, i, 0);
					if (sv) SelectedVertices[i] = SvIV(*sv);
				}
			}
		}

		clr.r = 1;
		clr.g = 1;
		clr.b = 1;
		clr.alpha = pb.alpha_nv;

		/* color and alpha for the shape from its colortable? */
		sv = hv_fetch(shape, "Color", 5, 0);
		if (sv) {
			AV *avcolor = (AV *)SvRV(*sv);
			if (avcolor) {
				sv = av_fetch(avcolor, 0, 0);
				if (sv) clr.r = SvNV(*sv);
				sv = av_fetch(avcolor, 1, 0);
				if (sv) clr.g = SvNV(*sv);
				sv = av_fetch(avcolor, 2, 0);
				if (sv) clr.b = SvNV(*sv);
				sv = av_fetch(avcolor, 3, 0);
				if (sv) clr.alpha = SvNV(*sv);
			}
		}
	
		sv = hv_fetch(shape, "Vertices", 8, 0);
		if (sv) vertices = (AV *)SvRV(*sv);
		if (vertices) NVertices = av_len(vertices) + 1;
		if (NVertices == 0) continue;

		sv = hv_fetch(shape, "NParts", 6, 0);
		if (sv) NParts = SvIV(*sv);

		if (NParts == 0) {
			parts = NULL;
			NParts = 1;
		} else {
			sv = hv_fetch(shape, "Parts", 5, 0);
			if (sv) parts = (AV *)SvRV(*sv);
			if (parts) NParts = av_len(parts) + 1;
		}
		
		/*
		sv = hv_fetch(shape, "NVertices", 9, 0);
		if (sv) NVertices = SvIV(*sv);
		*/

		/*
		printf("type %i shape %i with %i parts, %i vertices\n",SHPType,sindex,NParts,NVertices);
		*/

		points_of_shape = calloc(NVertices, sizeof(point));
		for (i = 0; i < NVertices; i++) {
			SV **sv = av_fetch(vertices, i, 0);
			AV *p2 = (AV *)SvRV(*sv);
			sv = av_fetch(p2, 0, 0);
			points_of_shape[i].x = SvNV(*sv);
			sv = av_fetch(p2, 1, 0);
			points_of_shape[i].y = SvNV(*sv);
		}

		parts_of_shape = calloc(NParts, sizeof(polygon)); 
		k = 0;
		parts_of_shape[0].nodes = &(points_of_shape[0]);
		if (parts) {
			for (i = 0; i < NParts; i++) {
				SV **sv = av_fetch(parts, i, 0);
				AV *p2 = (AV *)SvRV(*sv);
				int j;
				sv = av_fetch(p2, 0, 0);
				j = SvIV(*sv);
				if (i > 0) parts_of_shape[i-1].n = j - k;
				parts_of_shape[i].nodes = &(points_of_shape[j]);
				k = j;
			}
		}
		parts_of_shape[NParts-1].n = NVertices - k;

		switch (SHPType) {
		case 3: /* Polyline */
		{
			int i;
			for (i = 0; i < NParts; i++) {
				int j;
				for (j = 0; j < parts_of_shape[i].n - 1; j++) {
					/* draw line from parts_of_shape[i].nodes[j] to parts_of_shape[i].nodes[j+1] */
					/* clip */
					line l;
					l.begin = parts_of_shape[i].nodes[j];
					l.end = parts_of_shape[i].nodes[j+1];
					if (ral_clip_line_to_rect(&l,pb.bbox)) {
						/* bresenham */
						int i,j,i1,j1,i2,j2;
						int di, dj, incr1, incr2, d, iend, jend, idirflag, jdirflag;
						i1 = max(min(floor((pb.bbox.max.y - l.begin.y)/pb.pixel_width),pb.height-1),0);
						j1 = max(min(floor((l.begin.x - pb.bbox.min.x)/pb.pixel_width),pb.width-1),0);
						i2 = max(min(floor((pb.bbox.max.y - l.end.y)/pb.pixel_width),pb.height-1),0);
						j2 = max(min(floor((l.end.x - pb.bbox.min.x)/pb.pixel_width),pb.width-1),0);
						di = abs(i2-i1);
						dj = abs(j2-j1);
						if (dj <= di) {
							d = 2*dj - di;
							incr1 = 2*dj;
							incr2 = 2 * (dj - di);
							if (i1 > i2) {
						    		i = i2;
								j = j2;
								jdirflag = (-1);
								iend = i1;
							} else {
						    		i = i1;
		    						j = j1;
		    						jdirflag = 1;
		    						iend = i2;
							}
							SET_PIXEL_COLOR(i,j,clr)
							if (((j2 - j1) * jdirflag) > 0) {
	    							while (i < iend) {
									i++;
									if (d <0) {
		    								d+=incr1;
									} else {
		    								j++;
		    								d+=incr2;
									}
									SET_PIXEL_COLOR(i,j,clr)
	    							}
							} else {
	    							while (i < iend) {
									i++;
									if (d <0) {
		    								d+=incr1;
									} else {
		    								j--;
		    								d+=incr2;
									}
									SET_PIXEL_COLOR(i,j,clr)
	    							}
							}		
						} else {
							d = 2*di - dj;
							incr1 = 2*di;
							incr2 = 2 * (di - dj);
							if (j1 > j2) {
	    							j = j2;
	    							i = i2;
	    							jend = j1;
	    							idirflag = (-1);
							} else {
	    							j = j1;
	    							i = i1;
	    							jend = j2;
	    							idirflag = 1;
							}
							SET_PIXEL_COLOR(i,j,clr)
							if (((i2 - i1) * idirflag) > 0) {
	    							while (j < jend) {
									j++;
									if (d <0) {
		    								d+=incr1;
									} else {
		   				 				i++;
		    								d+=incr2;
									}
									SET_PIXEL_COLOR(i,j,clr)
	    							}
							} else {
	    							while (j < jend) {
									j++;
									if (d <0) {
		    								d+=incr1;
									} else {
		    								i--;
		    								d+=incr2;
									}
									SET_PIXEL_COLOR(i,j,clr)
	    							}
							}
						}
					}
				}
			}
			break;
		}
		case 5: /* Polygon */
		{			
			active_edge_table *aet_list = ral_get_active_edge_tables(parts_of_shape, NParts);

			int i;
			for (i = pb.height - 1; i >= 0; i--) {
				point p;
				double *x;
				int n;
				p.y = pb.bbox.max.y - ((double)(i) + 0.5)*pb.pixel_width;
				ral_scanline_at(aet_list, NParts, p.y, &x, &n);
				if (x) {
					int draw = 0;
					int begin = 0;
					int j, k;
					/*while ((begin < pb.width) AND (x[begin] < pb.bbox.min.x)) { */
					while ((begin < n) AND (x[begin] < pb.bbox.min.x)) {
						begin++;
	   					draw = !draw;
					}
					j = 0;
					for (k = begin; k < n; k++) {
						int jmax = ceil((x[k] - pb.bbox.min.x)/pb.pixel_width);	
						while ((j < pb.width) AND (j < jmax)) {
							if (draw) SET_PIXEL_COLOR(i,j,clr)
							j++;
						}
						if (j == pb.width) break;
						draw = !draw;
					}
					ral_delete_scanline(&x);
				}
			}

			ral_delete_active_edge_tables(aet_list, NParts);
			break;
		}
		}

		/* draw vertices in all cases if some flag is on */
		if ((SHPType == 1) OR (ShowPoints))
		/* case 1: Point */
		{
			int point_size = 4;
			int i, vindex, svindex;
			if (SHPType != 1) {
				clr.r = 1;
				clr.g = 0;
				clr.b = 0;
			}
			vindex = 0;
			svindex = 0;
			for (i = 0; i < NParts; i++) {
				int j;
				for (j = 0; j < parts_of_shape[i].n; j++) {
					point p = parts_of_shape[i].nodes[j];
					int selected = 0;

					if (SelectedVertices AND (svindex < NSelectedVertices) AND (vindex == SelectedVertices[svindex])) {
						selected = 1;
						svindex++;
					}

					vindex++;

					if (POINT_IN_RECTANGLE(p,pb.bbox)) {
						int i1,j1;
						i1 = floor((pb.bbox.max.y - p.y)/pb.pixel_width);
						j1 = floor((p.x - pb.bbox.min.x)/pb.pixel_width);
						if (selected) {
							int i,j;
							for (i = max(0,i1-point_size); i < min(pb.height,i1+point_size+1); i++) {
							for (j = max(0,j1-point_size); j < min(pb.width,j1+point_size+1); j++) {
								if ((i != i1) AND (j != j1))
									SET_PIXEL_COLOR(i,j,clr)
							}}
						} else {
							int i,j;
							for (i = max(0,i1-point_size); i < min(pb.height,i1+point_size+1); i++) {
								SET_PIXEL_COLOR(i,j1,clr)
							}
							for (j = max(0,j1-point_size); j < min(pb.width,j1+point_size+1); j++) {
								SET_PIXEL_COLOR(i1,j,clr)
							}
						}
					}
				}
			}
		}

		if (SelectedVertices) free(SelectedVertices);		
		if (parts_of_shape) free(parts_of_shape);
		if (points_of_shape) free(points_of_shape);
	}
}

void
render_fdg(grid *fdg, pixbuf pb)
{
	cell c;
	int l = ceil(fdg->unit_length/pb.pixel_width/2.0); /* length of the arrow in pixels */
	int h = floor(fdg->unit_length/pb.pixel_width/3.0);
	color clr;
	clr.r = 0.3;
	clr.g = 0.3;
	clr.b = 1;
	clr.alpha = 1;

	for(c.i = 0; c.i < fdg->M; c.i++) {
		int i = Ri2SCRi(c.i, fdg);
		if ((i-l < 0) OR (i+l >= pb.height)) continue;
	  	for(c.j = 0; c.j < fdg->N; c.j++) {
			int j = Rj2SCRj(c.j, fdg);
			int a;
			int i1,j1;
			int di,dj,di1,dj1,di2,dj2;
			if ((j-l < 0) OR (j+l >= pb.width)) continue;

			switch (IGD_CELL(fdg, c)) {
			case UP:
				di = -1; dj = 0;  i1 = i - l; j1 = j;     di1 = 1;  dj1 = 1;  di2 = 1;  dj2 = -1;
				break;
			case UPRIGHT:
				di = -1; dj = 1;  i1 = i - l; j1 = j + l; di1 = 1;  dj1 = 0;  di2 = 0;  dj2 = -1;
				break;
			case RIGHT:
				di = 0;  dj = 1;  i1 = i;     j1 = j + l; di1 = 1;  dj1 = -1; di2 = -1; dj2 = -1;
				break;
			case DOWNRIGHT:
				di = 1;  dj = 1;  i1 = i + l; j1 = j + l; di1 = -1; dj1 = 0;  di2 = 0;  dj2 = -1;
				break;
			case DOWN:
				di = 1;  dj = 0;  i1 = i + l; j1 = j;     di1 = -1; dj1 = 1;  di2 = -1; dj2 = -1;
				break;
			case DOWNLEFT:
				di = 1;  dj = -1; i1 = i + l; j1 = j - l; di1 = -1; dj1 = 0;  di2 = 0;  dj2 = 1;
				break;
			case LEFT:
				di = 0;  dj = -1; i1 = i;     j1 = j - l; di1 = 1;  dj1 = 1;  di2 = -1; dj2 = 1;
				break;
			case UPLEFT:
				di = -1; dj = -1; i1 = i - l; j1 = j - l; di1 = 0;  dj1 = 1;  di2 = 1;  dj2 = 0;
				break;
			case FLAT_AREA:
				di = 0;  dj = 0;  i1 = i;     j1 = j;     di1 = 0;  dj1 = 0;  di2 = 0;  dj2 = 0;
				for (a = -h; a <= h; a++) {
					SET_PIXEL_COLOR(i1+a,j1,clr)
					SET_PIXEL_COLOR(i1,j1+a,clr)
				}
				break;
			case PIT_CELL:
				di = 0;  dj = 0;  i1 = i;     j1 = j;     di1 = 0;  dj1 = 0;  di2 = 0;  dj2 = 0;
				for (a = -h; a <= h; a++) {
					SET_PIXEL_COLOR(i1+a,j1+h,clr)
					SET_PIXEL_COLOR(i1+a,j1-h,clr)
					SET_PIXEL_COLOR(i1+h,j1+a,clr)
					SET_PIXEL_COLOR(i1-h,j1+a,clr)
				}
				break;
			}
			for (a = 1; a <= l; a++) {
				SET_PIXEL_COLOR(i+di*a,j+dj*a,clr)
			}
			for (a = 1; a <= h; a++) {
				SET_PIXEL_COLOR(i1+di1*a,j1+dj1*a,clr)
				SET_PIXEL_COLOR(i1+di2*a,j1+dj2*a,clr)
			}
		}
	}
}

void
render_igrid(grid *fdg, pixbuf pb)
{
	int i,j;
	double min, max, delta;
	min = IGD_VALUE_RANGE(fdg)->min;
	max = IGD_VALUE_RANGE(fdg)->max;
	delta = max - min;
	for (i = 0; i < pb.height; i++) {
		cell c;
		c.i = SCRi2Ri(i, fdg);
		for (j = 0; j < pb.width; j++) {
			c.j = SCRj2Rj(j, fdg);
			if (GD_CELL_IN(fdg, c) AND IGD_DATACELL(fdg, c)) {
				color clr;
				int v = IGD_CELL(fdg, c);

				if (pb.ct AND pb.ct->nc) {
					/* use the colortable from grid */
					v -= pb.ct_offset;
					if ((v >= 0) AND (v <= pb.ct->nc)) 
						ral_get_color(pb.ct, v, &clr);
					else {
						clr.r = clr.g = clr.b = 0;
						clr.alpha = 1;
					}
				} else {
					/* use some scale, .. only grayscale implemented now */
					clr.r = clr.g = clr.b = ((double)v - min)/delta;
					clr.alpha = 1;
				}

				if (pb.alpha_gd) {
					cell alpha_c;
					alpha_c.i = SCRi2Ri(i, pb.alpha_gd);
					alpha_c.j = SCRj2Rj(j, pb.alpha_gd);
					if (GD_CELL_IN(pb.alpha_gd, alpha_c) AND RGD_DATACELL(pb.alpha_gd, alpha_c))
						clr.alpha *= RGD_CELL(pb.alpha_gd, alpha_c);
				}

				clr.alpha *= pb.alpha_nv;

				SET_PIXEL_COLOR(i,j,clr)
			}
		}
	}
}

void
render_rgrid(grid *gd, pixbuf pb)
{
	double min, max, delta;
	min = RGD_VALUE_RANGE(gd)->min;
	max = RGD_VALUE_RANGE(gd)->max;
	delta = max - min;
	int i,j;
	for (i = 0; i < pb.height; i++) { 
		cell c;
		c.i = SCRi2Ri(i, gd);
		for (j = 0; j < pb.width; j++) {
			c.j = SCRj2Rj(j, gd);
			if (GD_CELL_IN(gd, c) AND RGD_DATACELL(gd, c)) {
				color clr;
				double v = RGD_CELL(gd, c);

				/* use some scale, .. only grayscale implemented now */
				clr.r = clr.g = clr.b = (v - min)/delta;
				clr.alpha = 1;

				if (pb.alpha_gd) {
					cell alpha_c;
					alpha_c.i = SCRi2Ri(i, pb.alpha_gd);
					alpha_c.j = SCRj2Rj(j, pb.alpha_gd);
					if (GD_CELL_IN(pb.alpha_gd, alpha_c) AND RGD_DATACELL(pb.alpha_gd, alpha_c))
						clr.alpha *= RGD_CELL(pb.alpha_gd, alpha_c);
				}

				clr.alpha *= pb.alpha_nv;

				SET_PIXEL_COLOR(i,j,clr)
			}
		}
	}
}

MODULE = Gtk2::Ex::Geo::Renderer		PACKAGE = Gtk2::Ex::Geo::Renderer

GdkPixbuf_noinc *
gdk_pixbuf_new_from_data (ga, minX, maxY, pixel_width, width, height, bg_r, bg_g, bg_b)
	AV *ga
	double minX
	double maxY
	double pixel_width
	int width
	int height
	int bg_r
	int bg_g
	int bg_b
    CODE:
	pixbuf pb;

	GdkColorspace colorspace = GDK_COLORSPACE_RGB;
	gboolean has_alpha = FALSE;
	int i_ga;

	pb.width = width;
	pb.height = height;
	pb.rowstride = width*3;
	pb.bits_per_sample = 8;
	pb.bbox.min.x = minX;
	pb.bbox.max.y = maxY;
	pb.pixel_width = pixel_width;
	pb.bbox.max.x = pb.bbox.min.x + (width)*pixel_width;
	pb.bbox.min.y = pb.bbox.max.y - (height)*pixel_width;
	pb.bg_r = bg_r;
	pb.bg_g = bg_g;
	pb.bg_b = bg_b;
	pb.data = malloc(3*width*height); /* is freed in grid2gtk_pixbuf_destroy_notify */

	/*printf("malloc %#x\n",data);*/
	
	/* 
		go through the provided list of rasters/shapefiles and render them
		
	   	rendering is based on world coordinates

		rendering uses a simple greyscale (or maybe later some other palette) 

		unless the data has a color table

		the greyscale is calculate using min & max values from the raster (C struct)
		which are _not_ calculated here
		
		color tables are only considered for integer rasters and shapefiles

		a raster may have an alpha value, which is a (global) number or a raster
		also color may have an alpha value

	*/

	{
		int i,j;
		for (i = 0; i < pb.height; i++) for (j = 0; j < pb.width; j++)
			SET_PIXEL(i,j,bg_r,bg_g,bg_b)
	}

	for (i_ga = 0; i_ga <= av_len(ga); i_ga++) {

		grid *gd;

		pb.ct = NULL;
		pb.ct_offset = 0;

		pb.alpha_gd = NULL;
		pb.alpha_nv = 1.0;

		SV **sv = av_fetch(ga, i_ga, 0);
		HV *layer = (HV *)SvRV(*sv);

		sv = hv_fetch(layer, "HIDE", 4, 0);
		if (sv) if (SvIV(*sv)) continue;

		sv = hv_fetch(layer, "ALPHA", 5, 0);
		if (sv) { /* has an alpha */
			if (SvROK(*sv)) { /* alpha is hash or grid */
				HV *hv_gd = (HV *)SvRV(*sv);
				sv = hv_fetch(hv_gd, "GRID", 4, 0);
				if (sv) {
					pb.alpha_gd = (grid *)SvIV((SV *)SvRV(*sv));
					if (pb.alpha_gd->datatype != REAL_GRID) {
						fprintf(stderr,"alpha raster has to be a real number raster\n");
						pb.alpha_gd = NULL;
					}
				}
			} else /* alpha is a number */
				pb.alpha_nv = SvNV(*sv);
				if (pb.alpha_nv <= 0) continue;
				pb.alpha_nv = min(pb.alpha_nv,1);
		}

		sv = hv_fetch(layer, "Shapes", 6, 0);
		if (sv) {
			AV *shapes = (AV *)SvRV(*sv);
			render_shapefile(layer, shapes, pb);
			continue;
		}

		sv = hv_fetch(layer, "COLOR_TABLE", 11, 0);
		if (sv AND SvROK(*sv)) {
			pb.ct = (color_table *)SvIV((SV *)SvRV(*sv));
			sv = hv_fetch(layer, "COLOR_TABLE_OFFSET", 18, 0);
			if (sv) pb.ct_offset = SvIV(*sv);
		}

		sv = hv_fetch(layer, "GRID", 4, 0);
		if (!(sv AND *sv AND SvROK(*sv))) continue; /* probably not a grid */
		gd = (grid *)SvIV((SV *)SvRV(*sv));

		if (gd->world.max.x < pb.bbox.min.x) continue;
		if (gd->world.min.y > pb.bbox.max.y) continue;
		if (gd->world.min.x > pb.bbox.max.x) continue;
		if (gd->world.max.y < pb.bbox.min.y) continue;

		/* draw arrows for flow direction grids (if it makes sense) */
		sv = hv_fetch(layer, "FDG", 3, 0);
		if (sv AND gd->unit_length/pb.pixel_width >= 5) {
			render_fdg(gd, pb);
			continue;
		}

		if (gd->datatype == INTEGER_GRID) {			
			render_igrid(gd, pb);
		} else {
			render_rgrid(gd, pb);
		}
		
	}
	RETVAL = gdk_pixbuf_new_from_data (pb.data, 
					   colorspace, 
					   has_alpha,
			  		   pb.bits_per_sample,
					   pb.width,
					   pb.height,
					   pb.rowstride,
					   grid2gtk_pixbuf_destroy_notify,
					   pb.data);
    OUTPUT:
	RETVAL


