/* "Face" primitives.
   Copyright (C) 1993, 1994 Free Software Foundation.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA. 

Originally by Carl Edman
Updated by Christian Limpach (chris@nice.ch)
OpenStep/Rhapsody  port by Scott Bender (sbender@harmony-ds.com)

*/


/* This is derived from work by Lucid (some parts very loosely so).  */

/* NOTE: face->font==0 does not mean unused face in this file ! */

#import <AppKit/AppKit.h>

#include <sys/types.h>
#include <sys/stat.h>

#include "config.h"
#include "lisp.h"

#ifdef HAVE_NS

#include "nsgui.h"
#include "nsterm.h"
#include "buffer.h"
#include "dispextern.h"
#include "frame.h"
#include "blockinput.h"
#include "window.h"
#include "charset.h"
#include "fontset.h"

#define FACE_DEFAULT (~0)

/* The number of face-id's in use (same for all frames).  */
int ns_next_face_id;
static NSColor * default_color;

/* The number of the face to use to indicate the region.  */
static int region_face;

Lisp_Object Qpixmap_spec_p;
Lisp_Object Qface, Qmouse_face;
extern Lisp_Object Qfontsize, Qunderline;

int ns_face_name_id_number ( /* FRAME_PTR, Lisp_Object name */ );
void ns_recompute_basic_faces ( /* FRAME_PTR f */ );
static int new_computed_face (struct frame *f, struct face *new_face);
static void ensure_face_ready (struct frame *f, int fid);
static int face_eql(const struct face *f1,const struct face *f2);

#ifdef OLD
int ns_load_font(struct face *f)
   {
   double shrink;
   float bbox1,bbox3,under;
   id font,screenfont;
   NSRect rect;

   if (!NUMBERP(ns_shrink_space)) return 4;
   shrink=XFLOATINT(ns_shrink_space);

   if (f->name==0 || f->size==-1) return 1;
   font=[NSFont fontWithName:[NSString stringWithCString:f->name] size:f->size];
   if (font==nil) return 2;

   if (screenfont=[font screenFont]) font=screenfont;

   if (![font isFixedPitch]) return 3;

   f->font=font;
   f->width=[font widthOfString:@"M"];

   rect = [font boundingRectForFont];
   bbox1= rect.origin.y;
   bbox3= rect.origin.y + rect.size.height;
   under= [font underlinePosition];
   if (font != [font screenFont])
      {
      bbox1=floor(f->size*bbox1);
      bbox3=ceil (f->size*bbox3);
      under=floor(f->size*under);
      }
   f->height=rint(shrink*bbox3) - bbox1;
   f->descender=-bbox1;
   f->underpos=under-bbox1;
   f->underwidth=rint([font underlineThickness]);
   return 0;
   }

#else

/* Load font named FONTNAME of the size SIZE for frame F, and return a
   pointer to the structure font_info while allocating it dynamically.
   If SIZE is 0, load any size of font.
   If loading is failed, return NULL.  */

struct font_info *
ns_load_font (f, fontname, size)
     struct frame *f;
     register char *fontname;
     int size;
{
  struct ns_display_info *dpyinfo = FRAME_NS_DISPLAY_INFO (f);
  int i;

  if ( size == 0 )
    size = XINT(get_frame_param (f, Qfontsize));

  for (i = 0; i < dpyinfo->n_fonts; i++)
    if (!strcmp (dpyinfo->font_table[i].name, fontname)
      && (dpyinfo->font_table[i].size == size))
      return (dpyinfo->font_table + i);

  /* Load the font and add it to the table.  */
  {
    char *full_name;
    XFontStruct *font;
    struct font_info *fontp;
    unsigned long value;
    NSFont *nsfont;
    double shrink;
    float bbox1,bbox3,under;
    NSRect rect;

    /* If we have found fonts by x_list_font, load one of them.  If
       not, we still try to load a font by the name given as FONTNAME
       because XListFonts (called in x_list_font) of some X server has
       a bug of not finding a font even if the font surely exists and
       is loadable by XLoadQueryFont.  */

    nsfont = [NSFont fontWithName:[NSString stringWithCString:fontname] 
							       size:size];

    if (!nsfont)
      return NULL;

    if ( [nsfont screenFont] )
      nsfont = [nsfont screenFont];

    font = (struct ns_font *)xmalloc(sizeof(struct ns_font));
    bzero (font, sizeof(struct ns_font));
    font->nsfont = nsfont;
    font->name = fontname;

    /* Do we need to create the table?  */
    if (dpyinfo->font_table_size == 0)
      {
	dpyinfo->font_table_size = 16;
	dpyinfo->font_table
	  = (struct font_info *) xmalloc (dpyinfo->font_table_size
					  * sizeof (struct font_info));
      }
    /* Do we need to grow the table?  */
    else if (dpyinfo->n_fonts
	     >= dpyinfo->font_table_size)
      {
	dpyinfo->font_table_size *= 2;
	dpyinfo->font_table
	  = (struct font_info *) xrealloc (dpyinfo->font_table,
					   (dpyinfo->font_table_size
					    * sizeof (struct font_info)));
      }

    fontp = dpyinfo->font_table + dpyinfo->n_fonts;

    /* Now fill in the slots of *FONTP.  */
    fontp->font = font;
    fontp->font_idx = dpyinfo->n_fonts;
    fontp->name = (char *) xmalloc (strlen (fontname) + 1);
    bcopy (fontname, fontp->name, strlen (fontname) + 1);
    fontp->full_name = fontp->name;


    font->width = [nsfont widthOfString:@"M"];

    rect = [nsfont boundingRectForFont];
    bbox1= rect.origin.y;
    bbox3= rect.origin.y + rect.size.height;
    under= [nsfont underlinePosition];

#if 0
    if (nsfont != [nsfont screenFont])
      {
	bbox1=floor(f->size*bbox1);
	bbox3=ceil (f->size*bbox3);
	under=floor(f->size*under);
      }
#endif

    if (!NUMBERP(ns_shrink_space)) 
      error("No shrink space defined");

    shrink=XFLOATINT(ns_shrink_space);

    font->height=rint(shrink*bbox3) - bbox1;
    font->descender=-bbox1;
    font->underpos=under-bbox1;
    font->underwidth=rint([nsfont underlineThickness]);
    font->size = size;
    
    fontp->height = font->height;
//    fontp->size = font->width;
    fontp->size = size;



#ifdef I_DONT_KNOW
    /* The slot `encoding' specifies how to map a character
       code-points (0x20..0x7F or 0x2020..0x7F7F) of each charset to
       the font code-points (0:0x20..0x7F, 1:0xA0..0xFF, 0:0x2020..0x7F7F,
       the font code-points (0:0x20..0x7F, 1:0xA0..0xFF,
       0:0x2020..0x7F7F, 1:0xA0A0..0xFFFF, 3:0x20A0..0x7FFF, or
       2:0xA020..0xFF7F).  For the moment, we don't know which charset
       uses this font.  So, we set informatoin in fontp->encoding[1]
       which is never used by any charset.  If mapping can't be
       decided, set FONT_ENCODING_NOT_DECIDED.  */
    fontp->encoding[1]
      = (font->max_byte1 == 0
	 /* 1-byte font */
	 ? (font->min_char_or_byte2 < 0x80
	    ? (font->max_char_or_byte2 < 0x80
	       ? 0		/* 0x20..0x7F */
	       : FONT_ENCODING_NOT_DECIDED) /* 0x20..0xFF */
	    : 1)		/* 0xA0..0xFF */
	 /* 2-byte font */
	 : (font->min_byte1 < 0x80
	    ? (font->max_byte1 < 0x80
	       ? (font->min_char_or_byte2 < 0x80
		  ? (font->max_char_or_byte2 < 0x80
		     ? 0		/* 0x2020..0x7F7F */
		     : FONT_ENCODING_NOT_DECIDED) /* 0x2020..0x7FFF */
		  : 3)		/* 0x20A0..0x7FFF */
	       : FONT_ENCODING_NOT_DECIDED) /* 0x20??..0xA0?? */
	    : (font->min_char_or_byte2 < 0x80
	       ? (font->max_char_or_byte2 < 0x80
		  ? 2		/* 0xA020..0xFF7F */
		  : FONT_ENCODING_NOT_DECIDED) /* 0xA020..0xFFFF */
	       : 1)));		/* 0xA0A0..0xFFFF */
#else
    fontp->encoding[1] = 1;
#endif
    

#ifdef I_DONT_KNOW
    fontp->baseline_offset
      = (XGetFontProperty (font, dpyinfo->Xatom_MULE_BASELINE_OFFSET, &value)
	 ? (long) value : 0);
    fontp->relative_compose
      = (XGetFontProperty (font, dpyinfo->Xatom_MULE_RELATIVE_COMPOSE, &value)
	 ? (long) value : 0);
    fontp->default_ascent
      = (XGetFontProperty (font, dpyinfo->Xatom_MULE_DEFAULT_ASCENT, &value)
	 ? (long) value : 0);
#endif

//    UNBLOCK_INPUT;
    dpyinfo->n_fonts++;

    return fontp;
  }
}
#endif /** OLD **/

/* Clear out face_vector and start anew.
   This should be done from time to time just to avoid
   keeping too many graphics contexts in face_vector
   that are no longer needed.  */

void clear_face_cache (void)
   {
   /* Empty for NS */
   return;
   }

static int face_eql(const struct face *f1,const struct face *f2)
   {
   return(f1->font->size==f2->font->size &&
          f1->underline==f2->underline &&
          f1->stipple == f2->stipple &&
          [NS_FACE_FOREGROUND(f1) isEqual:NS_FACE_FOREGROUND(f2)] &&
          [NS_FACE_BACKGROUND(f1) isEqual:NS_FACE_BACKGROUND(f2)] &&
          (f1->font->name==f2->font->name));
   }

/* Managing parameter face arrays for frames. */

void ns_init_frame_faces (struct frame *f)
{
   ensure_face_ready (f, 0);
   ensure_face_ready (f, 1);

   f->output_data.ns->n_computed_faces=0;
   f->output_data.ns->computed_faces=0;

   new_computed_face (f, f->output_data.ns->param_faces[0]);
   new_computed_face (f, f->output_data.ns->param_faces[1]);
   ns_recompute_basic_faces(f);

   {
     Lisp_Object tail, frame, result;

     result = Qnil;
     FOR_EACH_FRAME (tail, frame)
       if (FRAME_NS_P (XFRAME (frame))
           && XFRAME (frame) != f)
         {
           result = frame;
           break;
         }

     /* If we didn't find any NS frames other than f, then we don't need
        any faces other than 0 and 1, so we're okay.  Otherwise, make
        sure that all faces valid on the selected frame are also valid
        on this new frame.  */
     if (FRAMEP (result))
       {
         int i;
         int n_faces = FRAME_N_PARAM_FACES (XFRAME (result));
         struct face **faces = FRAME_PARAM_FACES (XFRAME (result));

         for (i = 2; i < n_faces; i++)
           if (faces[i])
             ensure_face_ready (f, i);
       }
   }
}


void ns_free_frame_faces (struct frame *f)
   {
   int i;

   for(i=0; i< f->output_data.ns->n_param_faces; i++)
      if (f->output_data.ns->param_faces[i])
         xfree (f->output_data.ns->param_faces[i]);

   for(i=0; i< f->output_data.ns->n_computed_faces; i++)
      if (f->output_data.ns->computed_faces[i])
         xfree (f->output_data.ns->computed_faces[i]);

   xfree (f->output_data.ns->param_faces);
   f->output_data.ns->param_faces =0;
   f->output_data.ns->n_param_faces =0;

   xfree (f->output_data.ns->computed_faces);
   f->output_data.ns->computed_faces =0;
   f->output_data.ns->n_computed_faces =0;
   }

/* Interning faces in a frame's face array.  */
static int new_computed_face (struct frame *f, struct face *new_face)
   {
   int i;

   if (f->output_data.ns->n_computed_faces >= f->output_data.ns->size_computed_faces)
      {
      int new_size = f->output_data.ns->n_computed_faces + 32;

      f->output_data.ns->computed_faces = (struct face **)
         xrealloc (f->output_data.ns->computed_faces,
                   new_size * sizeof (struct face *));
      f->output_data.ns->size_computed_faces = new_size;
      }

   i = f->output_data.ns->n_computed_faces++;
   f->output_data.ns->computed_faces[i] =
      (struct face *) xmalloc (sizeof(struct face));

   *(f->output_data.ns->computed_faces[i]) = *new_face;
   return i;
   }


/* Find a match for NEW_FACE in a FRAME's computed face array, and add
   it if we don't find one.  */
static int intern_computed_face (struct frame *f, struct face *new_face)
   {
   int i;

   /* Search for a computed face already on F equivalent to FACE.  */
   for (i = 0; i < f->output_data.ns->n_computed_faces; i++)
      {
      if (! f->output_data.ns->computed_faces[i])
         abort ();
      if (face_eql(new_face,f->output_data.ns->computed_faces[i]))
         return i;
      }

   /* We didn't find one; add a new one.  */
   return new_computed_face (f, new_face);
   }

/* Make parameter face id ID valid on frame F.  */
static void ensure_face_ready (struct frame *f, int fid)
   {
   if (f->output_data.ns->n_param_faces <= fid)
      {
      int n = fid + 10;
      f->output_data.ns->param_faces = (struct face **)
         xrealloc (f->output_data.ns->param_faces,sizeof (struct face *) * n);
      bzero (f->output_data.ns->param_faces + f->output_data.ns->n_param_faces,
             (n - f->output_data.ns->n_param_faces) * sizeof (struct face *));

      f->output_data.ns->n_param_faces = n;
      }

   if (f->output_data.ns->param_faces [fid] == 0)
      {
      struct face *nface=(struct face *) xmalloc(sizeof (*nface));
      struct ns_font *font = (struct ns_font *) xmalloc(sizeof (*font));
      bzero(nface, sizeof (*nface));
      bzero(font, sizeof (*font));
      font->nsfont=0;
      font->name=0;
      font->size=-1;

      nface->font = font;
      nface->underline=FACE_DEFAULT;
      nface->foreground=(EMACS_UINT)[default_color retain];
//      nface->foreground = FACE_DEFAULT;
      nface->background=(EMACS_UINT)[default_color retain];
//      nface->background=FACE_DEFAULT;
      nface->stipple = nil;
//      nface->stipple = FACE_DEFAULT;
      f->output_data.ns->param_faces [fid] = nface;
      }
   }


DEFUN ("ns-pixmap-spec-p", Fns_pixmap_spec_p, Sns_pixmap_spec_p, 1, 1, 0,
  "Return t if OBJECT is a valid pixmap specification.")
  (object)
     Lisp_Object object;
{
  Lisp_Object height, width;

  return ((STRINGP (object)
	   || (CONSP (object)
	       && CONSP (XCONS (object)->cdr)
	       && CONSP (XCONS (XCONS (object)->cdr)->cdr)
	       && NILP (XCONS (XCONS (XCONS (object)->cdr)->cdr)->cdr)
	       && (width = XCONS (object)->car, INTEGERP (width))
	       && (height = XCONS (XCONS (object)->cdr)->car, INTEGERP (height))
	       && STRINGP (XCONS (XCONS (XCONS (object)->cdr)->cdr)->car)
	       && XINT (width) > 0
	       && XINT (height) > 0
	       /* The string must have enough bits for width * height.  */
	       && ((XSTRING (XCONS (XCONS (XCONS (object)->cdr)->cdr)->car)->size
		    * (BITS_PER_INT / sizeof (int)))
		   >= XFASTINT (width) * XFASTINT (height)))
           || (CONSP (object)
               && CONSP (XCONS (object)->cdr)
	       && CONSP (XCONS (XCONS (object)->cdr)->cdr)
	       && NILP (XCONS (XCONS (XCONS (object)->cdr)->cdr)->cdr)
	       && (width = XCONS (object)->car, INTEGERP (width))
	       && (height = XCONS (XCONS (object)->cdr)->car, INTEGERP (height))
	       && CONSP (XCONS (XCONS (XCONS (object)->cdr)->cdr)->car)
               && XINT (width) > 0
	       && XINT (height) > 0))
	  ? Qt : Qnil);
}

/* Load a bitmap according to NAME (which is either a file name
   or a pixmap spec).  Return the EmacsImage object
   or get an error if NAME is invalid.

   Store the bitmap width in *W_PTR and height in *H_PTR.  */

static id
load_pixmap (f, name, w_ptr, h_ptr)
     FRAME_PTR f;
     Lisp_Object name;
     unsigned int *w_ptr, *h_ptr;
{
  id bitmap_id = nil;
  Lisp_Object tem;
  NSSize s;

  if (NILP (name))
    return nil;

  tem = Fns_pixmap_spec_p (name);
  if (NILP (tem))
    wrong_type_argument (Qpixmap_spec_p, name);

  if (CONSP (name))
    {
      /* Decode a bitmap spec into a bitmap.  */
      int h, w;
      Lisp_Object bits;

      w = XINT (Fcar (name));
      h = XINT (Fcar (Fcdr (name)));
      bits = Fcar (Fcdr (Fcdr (name)));
      if (STRINGP (bits))
        bitmap_id = [[EmacsImage alloc] initFromXBM:XSTRING (bits)->data
                                        width:w height:h];
      else if (CONSP (bits) &&
               !strcmp ((char *) XSYMBOL (XCONS (bits)->car)->name->data,
                        "xbm"))
        {
          bits = Fcdr (bits);
          bitmap_id = [[EmacsImage alloc]
                          initFromSkipXBM:XSTRING (bits)->data
                          width:w height:h length:XSTRING (bits)->size];
        }
    }
  else
    /* It must be a string -- a file name.  */
    bitmap_id = [EmacsImage allocInitFromFile:name];

  if (! bitmap_id)
    Fsignal (Qerror, Fcons (build_string ("invalid or undefined bitmap"),
			    Fcons (name, Qnil)));

  s = [[bitmap_id stippleRep] size];
  *w_ptr = s.width;
  *h_ptr = s.height;

  return bitmap_id;
}


/* Return non-zero if FONT1 and FONT2 have the same width.
   We do not check the height, because we can now deal with
   different heights.
   We assume that they're both character-cell fonts.  */

int ns_same_size_fonts (struct face *font1, struct face *font2)
   {
   return (font1->font->width == font2->font->width);
   }

/* Update the line_height of frame F according to the biggest font in
   any face.  Return nonzero if if line_height changes.  */

int ns_frame_update_line_height (struct frame *f)
   {
   int i,shift;
   int biggest = (int)rint(f->output_data.ns->font->height);

#if 0
   for (i = 0; i < f->output_data.ns->n_computed_faces; i++)
      if (f->output_data.ns->computed_faces[i]!=0)
         {
         if (f->output_data.ns->computed_faces[i]->font==0)
            ns_load_font(f->output_data.ns->computed_faces[i]);
         if ((f->output_data.ns->computed_faces[i]->font->height) > biggest)
            biggest = (int)rint(f->output_data.ns->computed_faces[i]->font->height);
         }
#else
   for (i = 0; i < f->output_data.ns->n_param_faces; i++)
      if (f->output_data.ns->param_faces[i]!=0)
         {
         if (f->output_data.ns->param_faces[i]->font==0)
            ns_load_font(f->output_data.ns->param_faces[i]);
         if ((f->output_data.ns->param_faces[i]->font->height) > biggest)
            biggest = (int)rint(f->output_data.ns->param_faces[i]->font->height);
         }
#endif

   if (biggest == f->output_data.ns->line_height)
      return 0;

   f->output_data.ns->line_height = biggest;
   return 1;
   }

/* Modify face TO by copying from FROM all properties which have
   nondefault settings.  */

static void merge_faces (struct face *from, struct face *to)
   {
   if (from->font->name && to->font->name!=from->font->name)
      {
      to->font->name=from->font->name;
      to->font->nsfont=0;
      }
   if (from->font->size!=-1 && to->font->size!=from->font->size)
      {
      to->font->size=from->font->size;
      to->font->nsfont=0;
      }
   if (from->underline != -1)
      to->underline = from->underline;
   if (![NS_FACE_FOREGROUND(from) isEqual:default_color])
//   if ( NS_FACE_FOREGROUND(from) != FACE_DEFAULT)
      to->foreground = (EMACS_UINT)[NS_FACE_FOREGROUND(from) retain];
   if (![NS_FACE_BACKGROUND(from) isEqual:default_color])
//   if (NS_FACE_BACKGROUND(from) != FACE_DEFAULT)
      to->background = (EMACS_UINT)[NS_FACE_BACKGROUND(from) retain];
   if (from->stipple && to->stipple != from->stipple)
//   if (from->stipple != FACE_DEFAULT)
     {
       to->stipple = from->stipple;
       to->pixmap_w = from->pixmap_w;
       to->pixmap_h = from->pixmap_h;
     }
   }

/* Set up the basic set of facial parameters, based on the frame's
   data; all faces are deltas applied to this.  */

static void compute_base_face (struct frame *f, struct face *face)
   {
  face->gc = 0;
  face->foreground = (EMACS_UINT)[FRAME_FOREGROUND_COLOR (f) retain];
  face->background = (EMACS_UINT)[FRAME_BACKGROUND_COLOR (f) retain];
  face->font = FRAME_FONT (f);
  face->fontset = -1;
  face->stipple = 0;
  face->underline = 0;
   }

/* Return the face ID to use to display a special glyph which selects
   FACE_CODE as the face ID, assuming that ordinarily the face would
   be CURRENT_FACE.  F is the frame.  */

int compute_glyph_face (struct frame *f, int face_code, int current_face)
   {
   struct face face;

   face = *f->output_data.ns->param_faces[current_face];

   if (face_code >= 0 && face_code < f->output_data.ns->n_param_faces
       && f->output_data.ns->param_faces[face_code] != 0)
      merge_faces (f->output_data.ns->param_faces[face_code], &face);

   return intern_computed_face (f, &face);
   }

/* Return the face ID to use to display a special glyph which selects
   FACE_CODE as the face ID, assuming that ordinarily the face would
   be CURRENT_FACE.  F is the frame.  */

int compute_glyph_face_1 (struct frame *f, Lisp_Object face_name,
                             int current_face)
   {
   struct face face;
   
   face = *f->output_data.ns->param_faces[current_face];
   
   if (!NILP (face_name))
      {
      int face_code = ns_face_name_id_number (f, face_name);
      
      if (face_code >= 0 && face_code < f->output_data.ns->n_param_faces
          && f->output_data.ns->param_faces[face_code] != 0)
         merge_faces (f->output_data.ns->param_faces[face_code], &face);
      }
   
   return intern_computed_face (f, &face);
   }

/* Return the face ID associated with a buffer position POS.
   Store into *ENDPTR the position at which a different face is needed.
   This does not take account of glyphs that specify their own face codes.
   F is the frame in use for display, and W is a window displaying
   the current buffer.

   REGION_BEG, REGION_END delimit the region, so it can be highlighted.

   LIMIT is a position not to scan beyond.  That is to limit
   the time this function can take.

   If MOUSE is nonzero, use the character's mouse-face, not its face.  */

int compute_char_face (struct frame *f, struct window *w, int pos,
                          int region_beg, int region_end, int *endptr, int limit,
                          int mouse)
   {
   struct face face;
   Lisp_Object prop, position;
   int i, j, noverlays;
   int facecode;
   Lisp_Object *overlay_vec;
   Lisp_Object frame;
   int endpos;
   Lisp_Object propname;

   /* W must display the current buffer.  We could write this function
      to use the frame and buffer of W, but right now it doesn't.  */
   if (XBUFFER (w->buffer) != current_buffer)
      abort ();

   XSETFRAME (frame, f);

   endpos = ZV;
   if (pos < region_beg && region_beg < endpos)
      endpos = region_beg;

   XSETFASTINT (position, pos);

   if (mouse)
      propname = Qmouse_face;
   else
      propname = Qface;

   prop = Fget_text_property (position, propname, w->buffer);
      {
      Lisp_Object limit1, end;

      XSETFASTINT (limit1, (limit < endpos ? limit : endpos));
    end = Fnext_single_property_change (position, propname, w->buffer, limit1);
      if (INTEGERP (end))
         endpos = XINT (end);
      }

      {
      int next_overlay;
      int len;

      /* First try with room for 40 overlays.  */
      len = 40;
      overlay_vec = (Lisp_Object *) alloca (len * sizeof (Lisp_Object));

      noverlays = overlays_at (pos, 0, &overlay_vec, &len,
                               &next_overlay, (int *) 0);

      /* If there are more than 40,
         make enough space for all, and try again.  */
      if (noverlays > len)
         {
         len = noverlays;
         overlay_vec = (Lisp_Object *) alloca (len * sizeof (Lisp_Object));
         noverlays = overlays_at (pos, 0, &overlay_vec, &len,
                                  &next_overlay, (int *) 0);
         }

      if (next_overlay < endpos)
         endpos = next_overlay;
      }

   *endptr = endpos;

   /* Optimize the default case.  */
   if (noverlays == 0 && NILP (prop)
       && !(pos >= region_beg && pos < region_end))
      return 0;

   compute_base_face (f, &face);

  if (CONSP (prop))
    {
      /* We have a list of faces, merge them in reverse order */
      Lisp_Object length;
      int len;
      Lisp_Object *faces;

      length = Fsafe_length (prop);
      len = XFASTINT (length);

      /* Put them into an array */
      faces = (Lisp_Object *) alloca (len * sizeof (Lisp_Object));
      for (j = 0; j < len; j++)
	{
	  faces[j] = Fcar (prop);
	  prop = Fcdr (prop);
	}
      /* So that we can merge them in the reverse order */
      for (j = len - 1; j >= 0; j--)
	{
	  facecode = ns_face_name_id_number (f, faces[j]);
	  if (facecode >= 0 && facecode < f->output_data.ns->n_param_faces
	      && f->output_data.ns->param_faces [facecode] != 0)
	    merge_faces (f->output_data.ns->param_faces [facecode], &face);
	}
    }
  else if (!NILP (prop))
      {
      facecode = ns_face_name_id_number (f, prop);
      if (facecode >= 0 && facecode < f->output_data.ns->n_param_faces
	  && f->output_data.ns->param_faces [facecode] != 0)
         merge_faces (f->output_data.ns->param_faces [facecode], &face);
      }

   noverlays = sort_overlays (overlay_vec, noverlays, w);

   /* Now merge the overlay data in that order.  */
   for (i = 0; i < noverlays; i++)
      {
      prop = Foverlay_get (overlay_vec[i], propname);
      if (CONSP (prop))
	{
	  /* We have a list of faces, merge them in reverse order */
	  Lisp_Object length;
	  int len;
	  Lisp_Object *faces;
	  int i;

	  length = Fsafe_length (prop);
	  len = XFASTINT (length);

	  /* Put them into an array */
	  faces = (Lisp_Object *) alloca (len * sizeof (Lisp_Object));
	  for (j = 0; j < len; j++)
	    {
	      faces[j] = Fcar (prop);
	      prop = Fcdr (prop);
	    }
	  /* So that we can merge them in the reverse order */
	  for (j = len - 1; j >= 0; j--)
	    {
	      facecode = ns_face_name_id_number (f, faces[j]);
	      if (facecode >= 0 && facecode < f->output_data.ns->n_param_faces
		  && f->output_data.ns->param_faces [facecode] != 0)
		merge_faces (f->output_data.ns->param_faces [facecode], &face);
	    }
          /* FIXME/cl maybe should calc endpos here as well !? */
	}
      else if (!NILP (prop))
         {
         Lisp_Object oend;
         int oendpos;

         facecode = ns_face_name_id_number (f, prop);
         if (facecode >= 0 && facecode < f->output_data.ns->n_param_faces
             && f->output_data.ns->param_faces[facecode] != 0)
            merge_faces (f->output_data.ns->param_faces[facecode], &face);

         oend = OVERLAY_END (overlay_vec[i]);
         oendpos = OVERLAY_POSITION (oend);
         if (oendpos < endpos)
            endpos = oendpos;
         }
      }

   if (pos >= region_beg && pos < region_end)
      {
      if (region_end < endpos)
         endpos = region_end;
      if (region_face >= 0 && region_face < ns_next_face_id)
         merge_faces (f->output_data.ns->param_faces[region_face], &face);
      }

   *endptr = endpos;

   return intern_computed_face (f, &face);
   }

/* Recompute the GC's for the default and modeline faces.
   We call this after changing frame parameters on which those GC's
   depend.  */

void ns_recompute_basic_faces (struct frame *f)
   {
   /* If the frame's faces haven't been initialized yet, don't worry about
      this stuff.  */
   if (f->output_data.ns->n_param_faces < 2)
      return;

   compute_base_face (f, f->output_data.ns->computed_faces[0]);
   compute_base_face (f, f->output_data.ns->computed_faces[1]);

   merge_faces (f->output_data.ns->param_faces[0],
                f->output_data.ns->computed_faces[0]);
   merge_faces (f->output_data.ns->param_faces[1],
                f->output_data.ns->computed_faces[1]);
   }

DEFUN ("make-face-internal", Fns_make_face_internal, Sns_make_face_internal, 1, 1, 0,
  "Create face number FACE-ID on all frames.")
  (face_id)
     Lisp_Object face_id;
   {
   Lisp_Object rest, frame;
   int id = XINT (face_id);

   CHECK_NUMBER (face_id, 0);
   if (id < 0 || id >= ns_next_face_id)
      error ("Face id out of range");

   FOR_EACH_FRAME (rest, frame)
     {
       if (FRAME_NS_P (XFRAME (frame)))
         ensure_face_ready (XFRAME (frame), id);
     }
   return Qnil;
   }

DEFUN ("set-face-attribute-internal", Fns_set_face_attribute_internal,
       Sns_set_face_attribute_internal, 4, 4, 0, "")
     (face_id, attr_name, attr_value, frame)
     Lisp_Object face_id, attr_name, attr_value, frame;
   {
   struct face *face;
   struct frame *f;
   int fid;
   int garbaged=0;
#ifdef AUTORELEASE
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif

   CHECK_FRAME (frame, 0);
   CHECK_NUMBER (face_id, 0);
   CHECK_SYMBOL (attr_name, 0);

   f = XFRAME (frame);
   fid = XINT (face_id);
   if (fid < 0 || fid >= ns_next_face_id)
      error ("Face id out of range");

   if (! FRAME_NS_P (f)) {
#ifdef AUTORELEASE
     [pool release];
#endif
     return;
   }

   ensure_face_ready (f, fid);
   face = f->output_data.ns->param_faces[XINT (face_id)];

   if (EQ (attr_name, Qfont))
      {
      if (NILP(attr_value))
         {
         face->font->name=0;
         }
      else
         {
         CHECK_STRING(attr_value,0);
         face->font->name=(char *)NXUniqueString(XSTRING (attr_value)->data);
         }
      face->font->nsfont=0;
      if (ns_frame_update_line_height (f))
         x_set_window_size (f, 0, f->width, f->height);
      garbaged=1;
      }
   else if (EQ (attr_name, Qfontsize))
      {
      if (NILP(attr_value))
         face->font->size=-1;
      else
         {
         CHECK_NUMBER_OR_FLOAT (attr_value, 0);
         face->font->size=XFLOATINT(attr_value);
         if (face->font->size<=0)
            error("Facesize non-positive.");
         }
      face->font->nsfont=0;
      if (ns_frame_update_line_height (f))
         x_set_window_size (f, 0, f->width, f->height);
      garbaged=1;
      }
   else if (EQ (attr_name, intern ("foreground")))
      {
	[NS_FACE_FOREGROUND(face) release];
	face->foreground = 0;
      if (NILP(attr_value))
         face->foreground = (EMACS_UINT)default_color;
      else {
	NSColor *col;
	if (ns_lisp_to_color(attr_value,&col))
	  error("Unknown color.");
	face->foreground = (EMACS_UINT)col;
      }
      [NS_FACE_FOREGROUND(face) retain];
      garbaged=1;
      }
   else if (EQ (attr_name, intern ("background")))
      {
	[NS_FACE_BACKGROUND(face) release];
	face->background = 0;
      if (NILP(attr_value))
         face->background = (EMACS_UINT)default_color;
      else {
	NSColor *col;
	if (ns_lisp_to_color(attr_value,&col))
	  error("Unknown color.");
	face->background = (EMACS_UINT)col;
      }
      [NS_FACE_BACKGROUND(face) retain];
      garbaged=1;
      }
   else if (EQ (attr_name, intern ("background-pixmap")))
     {
       unsigned int w, h;
       id new_pixmap = load_pixmap (f, attr_value, &w, &h);

       [face->stipple release];
       face->stipple = new_pixmap;
       face->pixmap_w = w;
       face->pixmap_h = h;
       garbaged = 1;
     }
   else if (EQ (attr_name, Qunderline))
      {
      if (NILP(attr_value))
         face->underline=-1;
      else if (EQ(attr_value,Qt))
         face->underline=1;
      else
         face->underline=0;
      garbaged=1;
      }
   else
      error ("unknown face attribute");

   if (fid == 0 || fid == 1)
      ns_recompute_basic_faces (f);

   if (garbaged)
      SET_FRAME_GARBAGED (f);

#ifdef AUTORELEASE
  [pool release];
#endif   
   return Qnil;
   }

DEFUN ("internal-next-face-id", Fns_internal_next_face_id,
  Sns_internal_next_face_id, 0, 0, 0, "")
  ()
   {
   return make_number (ns_next_face_id++);
   }

DEFUN ("ns-convert-font-trait-internal",
  Fns_convert_font_trait_internal, Sns_convert_font_trait_internal,
  2, 2, 0, "")
  (Lisp_Object name, Lisp_Object attribute)
   {
   id fm;
   id font;
   check_ns();
   CHECK_STRING(name,0);
   CHECK_SYMBOL(attribute,0);
   fm=[NSFontManager new];
   font=[NSFont fontWithName:[NSString stringWithCString:XSTRING(name)->data] size:10.0];
   if (!fm || !font)
      error ("Unknown font.");

   if (EQ(attribute, intern ("italic")))
      font=[fm convertFont:font toHaveTrait:NSItalicFontMask];
   else if (EQ(attribute, intern ("unitalic")))
      font=[fm convertFont:font toNotHaveTrait:NSItalicFontMask];
   else if (EQ(attribute, intern ("bold")))
      font=[fm convertFont:font toHaveTrait:NSBoldFontMask];
   else if (EQ(attribute, intern ("unbold")))
      font=[fm convertFont:font toNotHaveTrait:NSBoldFontMask];
   else if (EQ(attribute, intern ("nonstandardcharset")))
      font=[fm convertFont:font toHaveTrait:NSNonStandardCharacterSetFontMask];
   else if (EQ(attribute, intern ("unnonstandardcharset")))
      font=[fm convertFont:font toNotHaveTrait:NSNonStandardCharacterSetFontMask];
   else if (EQ(attribute, intern ("narrow")))
      font=[fm convertFont:font toHaveTrait:NSNarrowFontMask];
   else if (EQ(attribute, intern ("unnarrow")))
      font=[fm convertFont:font toNotHaveTrait:NSNarrowFontMask];
   else if (EQ(attribute, intern ("expanded")))
      font=[fm convertFont:font toHaveTrait:NSExpandedFontMask];
   else if (EQ(attribute, intern ("unexpanded")))
      font=[fm convertFont:font toNotHaveTrait:NSExpandedFontMask];
   else if (EQ(attribute, intern ("condensed")))
      font=[fm convertFont:font toHaveTrait:NSCondensedFontMask];
   else if (EQ(attribute, intern ("uncondensed")))
      font=[fm convertFont:font toNotHaveTrait:NSCondensedFontMask];
   else if (EQ(attribute, intern ("smallcaps")))
      font=[fm convertFont:font toHaveTrait:NSSmallCapsFontMask];
   else if (EQ(attribute, intern ("unsmallcaps")))
      font=[fm convertFont:font toNotHaveTrait:NSSmallCapsFontMask];
   else if (EQ(attribute, intern ("poster")))
      font=[fm convertFont:font toHaveTrait:NSPosterFontMask];
   else if (EQ(attribute, intern ("unposter")))
      font=[fm convertFont:font toNotHaveTrait:NSPosterFontMask];
   else if (EQ(attribute, intern ("compressed")))
      font=[fm convertFont:font toHaveTrait:NSCompressedFontMask];
   else if (EQ(attribute, intern ("uncompressed")))
      font=[fm convertFont:font toNotHaveTrait:NSCompressedFontMask];
   return build_string([[font fontName] cString]);
   }

int ns_face_name_id_number (struct frame *f, Lisp_Object name)
   {
   Lisp_Object tem;

   tem= Fcdr (assq_no_quit (name, f->face_alist));
   if (NILP (tem)) return 0;

   CHECK_VECTOR (tem, 0);
   tem = XVECTOR (tem)->contents[2];
   CHECK_NUMBER (tem, 0);
   return XINT (tem);
   }

DEFUN ("frame-face-alist", Fframe_face_alist, Sframe_face_alist, 1, 1, 0,
       "")
     (frame)
     Lisp_Object frame;
{
  CHECK_FRAME (frame, 0);
  return XFRAME (frame)->face_alist;
}

DEFUN ("set-frame-face-alist", Fset_frame_face_alist, Sset_frame_face_alist,
       2, 2, 0, "")
     (frame, value)
     Lisp_Object frame, value;
{
  CHECK_FRAME (frame, 0);
  XFRAME (frame)->face_alist = value;
  return value;
}

void syms_of_nsfaces ()
   {
   default_color=[[NSColor clearColor] retain];

   Qpixmap_spec_p = intern ("pixmap-spec-p");
   staticpro (&Qpixmap_spec_p);
   Qmouse_face = intern ("mouse-face");
   staticpro (&Qmouse_face);
   Qface = intern ("face");
   staticpro (&Qface);

   DEFVAR_INT ("region-face", &region_face,
    "Face number to use to highlight the region\n\
The region is highlighted with this face\n\
when Transient Mark mode is enabled and the mark is active.");

   defsubr (&Sframe_face_alist);
   defsubr (&Sset_frame_face_alist);
   defsubr (&Sns_pixmap_spec_p);
   defsubr (&Sns_make_face_internal);
   defsubr (&Sns_set_face_attribute_internal);
   defsubr (&Sns_internal_next_face_id);
   defsubr (&Sns_convert_font_trait_internal);
   }

#endif

