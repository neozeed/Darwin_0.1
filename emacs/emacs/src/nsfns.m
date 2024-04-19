/* Functions for the OpenStep window system.

   Copyright (C) 1989, 1992, 1993, 1994 Free Software Foundation.

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


#import <AppKit/AppKit.h>

#include <signal.h>
#include "config.h"
#include "lisp.h"
#include "dispextern.h"
#include "nsterm.h"
#include "frame.h"
#include "window.h"
#include "buffer.h"
#include "dispextern.h"
#include "keyboard.h"
#include "blockinput.h"
#include "regex.h"
#include "termhooks.h"
#include "paths.h"
#include "charset.h"
#include "fontset.h"

#ifdef HAVE_NS

/*
 * 3.3 supports eight bit "pseudo-color" and is defined under the 3.3
 * operating system as an enum with the value "514". This hack allows the
 * code in nsfns.m to be compliant with 3.2 and 3.3 (3.2 doesn't define this
 * value in the NXWindowDepth enumerated type), as well as letting Emacs
 * versions compiled under 3.2 to work properly under 3.3. The only problem is
 * systems that have built more modern versions of the compiler from the source
 * (like me) that don't match up with the header files anymore. NeXT, of
 * course, doesn't place any versioning information in their headers, so in
 * this case, I don't know what the correct thing to do is. Maybe just
 * outright define it.  - darcy
 */

#if !defined(NX_CURRENT_COMPILER_RELEASE)||(NX_CURRENT_COMPILER_RELEASE < 330)
#define NSBestDepth(NSCalibratedRGBColorSpace, 8, 8, YES, NULL) 514
#endif

extern void x_free_frame_menubar();
void x_set_frame_parameters (struct frame *f, Lisp_Object alist);

extern struct re_pattern_buffer *compile_pattern ();

Lisp_Object Qns_frame_parameter;
Lisp_Object Qforeground_color;
Lisp_Object Qbackground_color;
Lisp_Object Qcursor_color;
Lisp_Object Qinternal_border_width;
Lisp_Object Qvisibility;
Lisp_Object Qicon_type;
Lisp_Object Qcursor_type;
Lisp_Object Qicon_left;
Lisp_Object Qicon_top;
Lisp_Object Qicon_type;
Lisp_Object Qleft;
Lisp_Object Qright;
Lisp_Object Qtop;
Lisp_Object Qicon_name;
Lisp_Object Qdisplay;
Lisp_Object Qnone;
Lisp_Object Qvertical_scroll_bars;
Lisp_Object Qauto_raise;
Lisp_Object Qauto_lower;
Lisp_Object Qbox;
Lisp_Object Qscroll_bar_width;
Lisp_Object Vx_bitmap_file_path;
Lisp_Object Qx_resource_name;

Lisp_Object Qfontsize;
Lisp_Object Qbuffered;


extern Lisp_Object Qunderline, Qundefined;
extern Lisp_Object Qheight, Qminibuffer, Qname, Qonly, Qwidth;
extern Lisp_Object Qunsplittable, Qmenu_bar_lines, Qbuffer_predicate, Qtitle;



/* Alist of elements (REGEXP . IMAGE) for images of icons associated
   to frames.*/
Lisp_Object Vns_icon_type_alist;

void check_ns (void)
   {
   if (ns_current_display == nil)
      error ("OpenStep is not in use or not initialized");
   }

/* Nonzero if we can use mouse menus. */
int have_menus_p ()
   {
   return ns_current_display != nil;
   }

/* Extract a frame as a FRAME_PTR, defaulting to the selected frame
   and checking validity for NS.  */

FRAME_PTR
check_ns_frame (frame)
     Lisp_Object frame;
{
  FRAME_PTR f;

  if (NILP (frame))
    f = selected_frame;
  else
    {
      CHECK_LIVE_FRAME (frame, 0);
      f = XFRAME (frame);
    }
  if (! FRAME_NS_P (f))
    error ("non-NS frame used");
  return f;
}

/* Let the user specify an NS display with a frame.
   nil stands for the selected frame--or, if that is not an NS frame,
   the first NS display on the list.  */

static struct ns_display_info *
check_ns_display_info (frame)
     Lisp_Object frame;
{
  if (NILP (frame))
    {
      if (FRAME_NS_P (selected_frame))
	return FRAME_NS_DISPLAY_INFO (selected_frame);
      else if (ns_display_list != 0)
	return ns_display_list;
      else
	error ("NS windows are not in use or not initialized");
    }
  else if (STRINGP (frame))
    return ns_display_info_for_name (frame);
  else
    {
      FRAME_PTR f;

      CHECK_LIVE_FRAME (frame, 0);
      f = XFRAME (frame);
      if (! FRAME_NS_P (f))
	error ("non-NS frame used");
      return FRAME_NS_DISPLAY_INFO (f);
    }
}

static Lisp_Object ns_get_arg (Lisp_Object alist, Lisp_Object param,
                               char *owner, char *name)
   {
   Lisp_Object tem;

   tem = Fassq (param, alist);
   if (!NILP(tem)) return Fcdr(tem);

   tem = Fassq (param, Vdefault_frame_alist);
   if (!NILP(tem)) return Fcdr(tem);

   if (!name) return Qunbound;

   tem = Fns_get_resource(owner ? build_string(owner) : Qnil, build_string (name));

   if (NILP(tem)) return Qunbound;

   if (XTYPE(tem)==Lisp_String)
      {
      if (!strcmp(XSTRING(tem)->data,"YES")||
          !strcmp(XSTRING(tem)->data,"ON")||
          !strcmp(XSTRING(tem)->data,"TRUE")) return Qt;
      if (!strcmp(XSTRING(tem)->data,"NO")||
          !strcmp(XSTRING(tem)->data,"OFF")||
          !strcmp(XSTRING(tem)->data,"FALSE")) return Qnil;
      }

   return tem;
   }

static Lisp_Object ns_default_parameter (struct frame *f, Lisp_Object alist,
                                         Lisp_Object prop, Lisp_Object deflt,
                                         char *owner, char *name)
   {
   Lisp_Object tem;

   tem = ns_get_arg (alist, prop, owner, name);
   if (EQ (tem, Qunbound)) tem=deflt;

   x_set_frame_parameters (f, Fcons (Fcons (prop, tem), Qnil));
   return tem;
   }

void ns_set_foreground_color (struct frame *f, Lisp_Object arg,
                              Lisp_Object oldval)
   {
   NSColor * col;

   if (ns_lisp_to_color(arg,&col))
      {
      store_frame_param(f,Qforeground_color,oldval);
      error("Unknown color");
      }

   [f->output_data.ns->foreground_color release];
   f->output_data.ns->foreground_color = [col retain];

   if (f->output_data.ns->view != nil)
      {
      ns_recompute_basic_faces (f);
      if (FRAME_VISIBLE_P (f))
         redraw_frame (f);
      }
   }

void ns_set_background_color (struct frame *f, Lisp_Object arg,
                              Lisp_Object oldval)
   {
   NSColor * col;
   id view=f->output_data.ns->view;

   if (ns_lisp_to_color(arg,&col))
      {
      store_frame_param(f,Qbackground_color,oldval);
      error("Unknown color");
      }

   [f->output_data.ns->background_color release];
   f->output_data.ns->background_color = [col retain];
   if (view != nil)
      {
      [[view window] setBackgroundColor:col];
      ns_recompute_basic_faces (f);
      if (FRAME_VISIBLE_P (f))
         redraw_frame (f);
      }
   }

void ns_set_cursor_color (struct frame *f, Lisp_Object arg, Lisp_Object oldval)
   {
     NSColor *col;
   id view=f->output_data.ns->view;
   if (ns_lisp_to_color(arg,&col))
      {
      store_frame_param(f,Qcursor_color,oldval);
      error("Unknown color");
      }

   [f->output_data.ns->desired_cursor_color release];
   f->output_data.ns->desired_cursor_color = [col retain];

   if (view != nil)
      {
      extern void ns_dumpcursor(struct frame *f,int nx,int ny);
      ns_dumpcursor(f,f->cursor_x,f->cursor_y);
      }
   }

void ns_set_internal_border_width (struct frame *f, Lisp_Object arg,
                                   Lisp_Object oldval)
   {
   if (XTYPE(arg)==Lisp_String)
      {
      arg=Fstring_to_number(arg, Qnil);
      store_frame_param(f,Qinternal_border_width,arg);
      }

   if (!NUMBERP(arg) || (XFLOATINT(arg)<0))
      {
      store_frame_param(f,Qinternal_border_width,oldval);
      error("Internal border width out of range");
      }

   f->output_data.ns->internal_border_width=XFLOATINT(arg);
   x_set_window_size (f, 0, f->width, f->height);
   }

void ns_set_visibility (struct frame *f, Lisp_Object arg, Lisp_Object oldval)
   {
   Lisp_Object frame;
   XSETFRAME (frame, f);

   if (XTYPE(arg)==Lisp_String)
      {
      arg=Fintern(arg, Qnil);
      store_frame_param(f,Qvisibility,arg);
      }

   if (NILP (arg))
      Fmake_frame_invisible (frame, Qt);
   else if (EQ (arg, Qicon))
      Ficonify_frame (frame);
   else
      Fmake_frame_visible (frame);
   }

void ns_set_icon_name (struct frame *f, Lisp_Object arg,
                       Lisp_Object oldval)
{
  id view=f->output_data.ns->view;

  // see if it's changed
  if (STRINGP (arg))
    {
      if (STRINGP (oldval) && EQ (Fstring_equal (oldval, arg), Qt))
	return;
    }
  else if (!STRINGP (oldval) && EQ (oldval, Qnil) == EQ (arg, Qnil))
    return;

  f->icon_name = arg;

  if (NILP (arg))
    {
      if (!NILP (f->title))
        arg = f->title;
      else
        // explicit name and no icon-name -> explicit_name
        if (f->explicit_name)
          arg = f->name;
        else
          {
            // no explicit name and no icon-name ->
            // name has to be rebuild from icon_title_format
            windows_or_buffers_changed++;
            return;
          }
    }

  /* Don't change the name if it's already NAME.  */
  if ([[view window] miniwindowTitle] &&
      ([[[view window] miniwindowTitle] isEqualToString:[NSString stringWithCString:XSTRING (arg)->data]]))
    return;

  [[view window] setMiniwindowTitle:[NSString stringWithCString:XSTRING (arg)->data]];
}

void x_set_name_iconic (struct frame *f, Lisp_Object name, int explicit)
{
  id view=f->output_data.ns->view;

  /* Make sure that requests from lisp code override requests from 
     Emacs redisplay code.  */
  if (explicit)
    {
      /* If we're switching from explicit to implicit, we had better
	 update the mode lines and thereby update the title.  */
      if (f->explicit_name && NILP (name))
	update_mode_lines = 1;

      f->explicit_name = ! NILP (name);
    }
  else if (f->explicit_name)
    name = f->name;

  // title overrides explicit name
  if (! NILP (f->title))
    name = f->title;
  
  // icon_name overrides title and explicit name
  if (! NILP (f->icon_name))
    name = f->icon_name;
    
  if (NILP (name))
    name = build_string ([[[NSProcessInfo processInfo] processName] cString]);
  else
    CHECK_STRING (name, 0);
  
  /* Don't change the name if it's already NAME.  */
  if ([[view window] miniwindowTitle] &&
      ([[[view window] miniwindowTitle] isEqualToString:[NSString stringWithCString:XSTRING (name)->data]]))
    return;

  [[view window] setMiniwindowTitle:[NSString stringWithCString:XSTRING (name)->data]];
}

void x_set_name (struct frame *f, Lisp_Object name, int explicit)
{
  id view=f->output_data.ns->view;

  /* Make sure that requests from lisp code override requests from 
     Emacs redisplay code.  */
  if (explicit)
    {
      /* If we're switching from explicit to implicit, we had better
	 update the mode lines and thereby update the title.  */
      if (f->explicit_name && NILP (name))
	update_mode_lines = 1;
      
      f->explicit_name = ! NILP (name);
    }
  else if (f->explicit_name)
    return;
  
  if (NILP (name))
    name = build_string ([[[NSProcessInfo processInfo] processName] cString]);
  
  f->name = name;

  // title overrides explicit name
  if (! NILP (f->title))
    name = f->title;

  CHECK_STRING (name, 0);

  /* Don't change the name if it's already NAME.  */
  if ([[[view window] title] isEqualToString:[NSString stringWithCString:XSTRING (name)->data]])
    return;

  [[view window] setTitle:[NSString stringWithCString:XSTRING (name)->data]];
}

/* This function should be called when the user's lisp code has
   specified a name for the frame; the name will override any set by the
   redisplay code.  */
void
x_explicitly_set_name (f, arg, oldval)
     FRAME_PTR f;
     Lisp_Object arg, oldval;
{
  x_set_name_iconic (f, arg, 1);
  x_set_name (f, arg, 1);
}

/* This function should be called by Emacs redisplay code to set the
   name; names set this way will never override names set by the user's
   lisp code.  */
void
x_implicitly_set_name (f, arg, oldval)
     FRAME_PTR f;
     Lisp_Object arg, oldval;
{
  if (FRAME_ICONIFIED_P (f))
    x_set_name_iconic (f, arg, 0);
  else
    x_set_name (f, arg, 0);
}

/* Change the title of frame F to NAME.
   If NAME is nil, use the frame name as the title.

   If EXPLICIT is non-zero, that indicates that lisp code is setting the
       name; if NAME is a string, set F's name to NAME and set
       F->explicit_name; if NAME is Qnil, then clear F->explicit_name.

   If EXPLICIT is zero, that indicates that Emacs redisplay code is
       suggesting a new name, which lisp code should override; if
       F->explicit_name is set, ignore the new name; otherwise, set it.  */

void
ns_set_title (f, name)
     struct frame *f;
     Lisp_Object name;
{
  /* Don't change the title if it's already NAME.  */
  if (EQ (name, f->title))
    return;

  update_mode_lines = 1;

  f->title = name;
}

void x_set_name_as_filename (struct frame *f)
{
  id view=f->output_data.ns->view;
  Lisp_Object name;
  Lisp_Object buf = XWINDOW (f->selected_window)->buffer;
  const char *title;

  if (f->explicit_name || ! NILP (f->title))
    return;

  name=XBUFFER(buf)->filename;
  if (NILP(name) || FRAME_ICONIFIED_P (f)) name=XBUFFER(buf)->name;

  if (FRAME_ICONIFIED_P (f) && !NILP (f->icon_name))
    name = f->icon_name;
    
  if (NILP (name))
    name = build_string ([[[NSProcessInfo processInfo] processName] cString]);
  else
    CHECK_STRING (name, 0);

  title = FRAME_ICONIFIED_P (f) ? [[[view window] miniwindowTitle] cString] :
    [[[view window] title] cString];
  
  if (title && (! strcmp (title, XSTRING (name)->data)))
    return;

  if (! FRAME_ICONIFIED_P (f))
    {
      [[view window] setTitleWithRepresentedFilename:[NSString stringWithCString:XSTRING (name)->data]];
      f->name = name;
    }
  else
    [[view window] setMiniwindowTitle:[NSString stringWithCString:XSTRING (name)->data]];
}

void ns_set_doc_edited (struct frame *f, Lisp_Object arg,
                        Lisp_Object oldval)
   {
   id view=f->output_data.ns->view;
   [[view window] setDocumentEdited:!NILP(arg)];
   }

void x_set_menu_bar_lines (struct frame *f, Lisp_Object arg,
                            Lisp_Object oldval)
   {
   FRAME_MENU_BAR_LINES (f) = 0;
   if (XTYPE(arg)==Lisp_String)
      {
      arg=Fstring_to_number(arg, Qnil);
      }

   if (FRAME_MINIBUF_ONLY_P(f))
      return;

   if (NILP(arg) || (XTYPE(arg)==Lisp_Int && XINT(arg)==0))
      {
      if (FRAME_EXTERNAL_MENU_BAR (f) == 1)
         x_free_frame_menubar (f);
      FRAME_EXTERNAL_MENU_BAR (f) = 0;
      }
   else
      {
      FRAME_EXTERNAL_MENU_BAR (f) = 1;
      }
   }

void ns_implicitly_set_icon_type (struct frame *f)
{
#ifndef NOT_IMPLEMENTED
  Lisp_Object tem, arg;
  id view=f->output_data.ns->view;
  id image=nil;
  unsigned char *name,*fname;
  Lisp_Object chain, elt;

  if (f->output_data.ns->miniimage
      && [[NSString stringWithCString:XSTRING(f->name)->data] isEqualToString:[f->output_data.ns->miniimage name]])
    return;

  tem = assq_no_quit (Qicon_type, f->param_alist);
  if (CONSP (tem) && ! NILP (XCONS (tem)->cdr))
    return;
  
  for (chain = Vns_icon_type_alist;
       (image==nil) && CONSP (chain);
       chain = XCONS (chain)->cdr)
    {
      elt = XCONS(chain)->car;
      if (SYMBOLP (elt) && elt == Qt)
        {

	  image = [[[NSWorkspace sharedWorkspace] 
		    iconForFile:[NSString stringWithCString:
				  XSTRING(f->name)->data]] retain];
        }
      else if (CONSP (elt) &&
               STRINGP (XCONS(elt)->car) &&
               STRINGP (XCONS(elt)->cdr) && 
               fast_string_match (XCONS(elt)->car, f->name) >= 0)
        {
          image = [EmacsImage allocInitFromFile:XCONS (elt)->cdr];
          if (image == nil)
            image=[[NSImage imageNamed:[NSString stringWithCString:XSTRING(XCONS (elt)->cdr)->data]] retain];
        }
    }
  
  if (image==nil) 
    image=[[[NSWorkspace sharedWorkspace] iconForFileType:@"text"] retain];

  [f->output_data.ns->miniimage release];
  f->output_data.ns->miniimage=image;
  [view setMiniwindowImage];
#endif
}

void ns_set_icon_type (struct frame *f, Lisp_Object arg,
                       Lisp_Object oldval)
{
  id view=f->output_data.ns->view;
  id image=nil;
   
  if (!NILP (arg) && SYMBOLP (arg))
    {
      arg=build_string(XSYMBOL(arg)->name->data);
      store_frame_param(f,Qicon_type,arg);
    }

  // do it the implicit way
  if (NILP (arg))
    {
      ns_implicitly_set_icon_type (f);
      return;
    }
  
  CHECK_STRING (arg,0);

  image = [EmacsImage allocInitFromFile:arg];
  if (image == nil)
    image=[NSImage imageNamed:[NSString stringWithCString:XSTRING(arg)->data]];
   
  if (image==nil) image=[NSImage imageNamed:@"text"];

  f->output_data.ns->miniimage=image;
  [view setMiniwindowImage];
}

int ns_lisp_to_cursor_type (Lisp_Object arg)
   {
   char *str;
   if (XTYPE(arg) == Lisp_String)
      str=XSTRING(arg)->data;
   else if (XTYPE(arg) == Lisp_Symbol)
      str=XSYMBOL(arg)->name->data;
   else return -1;
   if (!strcmp(str,"bar"))    return bar;
   if (!strcmp(str,"box"))    return filled_box;
   if (!strcmp(str,"hollow")) return hollow_box;
   if (!strcmp(str,"line"))   return line;
   if (!strcmp(str,"no"))     return no_highlight;
   return -1;
   }

void ns_set_cursor_type (struct frame *f, Lisp_Object arg,
                         Lisp_Object oldval)
   {
   int val;
   id view=f->output_data.ns->view;

   val=ns_lisp_to_cursor_type(arg);
   if (val>=0)
      {
      f->output_data.ns->desired_cursor=val;
      }
   else
      {
      store_frame_param(f,Qcursor_type,oldval);
      error ("the `cursor-type' frame parameter should be either `no', `bar', `box', `hollow' or `line'.");
      }

   update_mode_lines++;
   }

void ns_set_autoraise (struct frame *f, Lisp_Object arg, Lisp_Object oldval)
   {
   f->auto_raise = !NILP(arg);
   }

void ns_set_autolower (struct frame *f, Lisp_Object arg, Lisp_Object oldval)
   {
   f->auto_lower = !NILP(arg);
   }

void ns_set_unsplittable (struct frame *f, Lisp_Object arg,
                          Lisp_Object oldval)
{
  f->no_split = !NILP (arg);
}

void ns_set_vertical_scroll_bars (struct frame *f, Lisp_Object arg,
                                   Lisp_Object oldval)
   {
  if ((EQ (arg, Qleft) && FRAME_HAS_VERTICAL_SCROLL_BARS_ON_RIGHT (f))
      || (EQ (arg, Qright) && FRAME_HAS_VERTICAL_SCROLL_BARS_ON_LEFT (f))
      || (NILP (arg) && FRAME_HAS_VERTICAL_SCROLL_BARS (f))
      || (!NILP (arg) && ! FRAME_HAS_VERTICAL_SCROLL_BARS (f)))
    {
      FRAME_VERTICAL_SCROLL_BAR_TYPE (f)
	= (NILP (arg)
	   ? vertical_scroll_bar_none
	   : EQ (Qright, arg)
	   ? vertical_scroll_bar_right 
	   : vertical_scroll_bar_left);

      /* We set this parameter before creating the X window for the
	 frame, so we can get the geometry right from the start.
	 However, if the window hasn't been created yet, we shouldn't
	 call x_set_window_size.  */
      if (FRAME_NS_WINDOW (f))
	x_set_window_size (f, 0, FRAME_WIDTH (f), FRAME_HEIGHT (f));
    }
   }

void ns_set_scroll_bar_width (struct frame *f, Lisp_Object arg,
                              Lisp_Object oldval)
{
  if (NILP (arg))
    {
      FRAME_SCROLL_BAR_PIXEL_WIDTH (f) = 0;
      FRAME_SCROLL_BAR_COLS (f) = 2;
      if (FRAME_NS_WINDOW (f))
        x_set_window_size (f, 0, FRAME_WIDTH (f), FRAME_HEIGHT (f));
    }
  else if (INTEGERP (arg) && XINT (arg) > 0
	   && XFASTINT (arg) != FRAME_SCROLL_BAR_PIXEL_WIDTH (f))
    {
      int wid = FONT_WIDTH(f->output_data.ns->font);
      FRAME_SCROLL_BAR_PIXEL_WIDTH (f) = XFASTINT (arg);
      FRAME_SCROLL_BAR_COLS (f) = (XFASTINT (arg) + wid-1) / wid;
      if (FRAME_NS_WINDOW (f))
        x_set_window_size (f, 0, FRAME_WIDTH (f), FRAME_HEIGHT (f));
    }
}

void ns_set_font (struct frame *f, Lisp_Object arg, Lisp_Object oldval)
   {
   if (XTYPE(arg) == Lisp_Symbol)
      {
      arg=Fintern(arg, Qnil);
      store_frame_param (f, Qfont, arg);
      }
   else if (XTYPE(arg) != Lisp_String)
      {
      store_frame_param (f, Qfont, oldval);
      error ("Font not a string or symbol.");
      }

   if (f->output_data.ns->view)
      {
      if (ns_new_font(f, XSTRING(arg)->data) == Qnil)
         {
         store_frame_param (f, Qfont, oldval);
         error("Not an available fixed-width font.");
         }
      ns_recompute_basic_faces (f);
      }
   SET_FRAME_GARBAGED (f);
   }

void ns_set_fontsize (struct frame *f, Lisp_Object arg, Lisp_Object oldval)
   {
   if (XTYPE(arg)==Lisp_String)
      {
      arg=Fstring_to_number(arg, Qnil);
      store_frame_param (f, Qfontsize, arg);
      }

   if (!NUMBERP(arg) || (XFLOATINT(arg)<=0.0))
      {
      store_frame_param (f, Qfontsize, oldval);
      error ("Fontsize not a positive number.");
      }

   if (f->output_data.ns->view)
      {
      if (ns_new_font(f, "Ohlfs") == Qnil)
         {
         store_frame_param (f, Qfontsize, oldval);
         error("Not an available font size.");
         }
      ns_recompute_basic_faces (f);
      }
   SET_FRAME_GARBAGED (f);
   }

void ns_set_underline (struct frame *f, Lisp_Object arg, Lisp_Object oldval)
   {
   if (f->output_data.ns->view)
      {
      if (ns_new_font(f, "Ohlfs") == Qnil)
         {
         store_frame_param (f, Qunderline, oldval);
         error("Invalid underline.");
         }
      ns_recompute_basic_faces (f);
      }
   SET_FRAME_GARBAGED (f);
   }

struct ns_frame_parm_table
   {
   char *name;
   void (*setter)(struct frame *f, Lisp_Object arg, Lisp_Object oldval);
   };

static struct ns_frame_parm_table ns_frame_parms[] =
   {
//FIXME/cl
  "auto-raise", ns_set_autoraise,
  "auto-lower", ns_set_autolower,
  "background-color", ns_set_background_color,
//   "border-color", x_set_border_color,
//   "border-width", x_set_border_width,
  "cursor-color", ns_set_cursor_color,
  "cursor-type", ns_set_cursor_type,
  "doc-edited", ns_set_doc_edited,
  "font", ns_set_font,
  "fontsize", ns_set_fontsize,
  "foreground-color", ns_set_foreground_color,
  "icon-name", ns_set_icon_name,
  "icon-type", ns_set_icon_type,
  "internal-border-width", ns_set_internal_border_width,
  "menu-bar-lines", x_set_menu_bar_lines,
//   "mouse-color", x_set_mouse_color,
  "name", x_explicitly_set_name,
  "scroll-bar-width", ns_set_scroll_bar_width,
  //  "title", ns_set_title,
  "underline", ns_set_underline,
  "unsplittable", ns_set_unsplittable,
  "vertical-scroll-bars", ns_set_vertical_scroll_bars,
  "visibility", ns_set_visibility,
  };

void x_set_frame_parameters (struct frame *f, Lisp_Object alist)
   {
   Lisp_Object tail;

   /* If both of these parameters are present, it's more efficient to
      set them both at once.  So we wait until we've looked at the
      entire list before we set them.  */
   Lisp_Object width, height;

   /* Same here.  */
   Lisp_Object left, top;

  /* Same with these.  */
  Lisp_Object icon_left, icon_top;

   /* Record in these vectors all the parms specified.  */
   Lisp_Object *parms;
   Lisp_Object *values;
   int i;

   i = 0;
   for (tail = alist; CONSP (tail); tail = Fcdr (tail))
      i++;

   parms  = (Lisp_Object *) alloca (i * sizeof (Lisp_Object));
   values = (Lisp_Object *) alloca (i * sizeof (Lisp_Object));

   /* Extract parm names and values into those vectors.  */

   i = 0;
   for (tail = alist; CONSP (tail); tail = Fcdr (tail))
      {
      Lisp_Object elt, prop, val;

      elt = Fcar (tail);
      parms[i] = Fcar (elt);
      values[i] = Fcdr (elt);
      i++;
      }

   width = height = top = left = Qunbound;
  icon_left = icon_top = Qunbound;

   /* Now process them in reverse of specified order.  */
   for (i--; i >= 0; i--)
      {
      Lisp_Object prop, val;

      prop = parms[i];
      val = values[i];

      if (EQ (prop, Qwidth))
         width = (XTYPE(val)==Lisp_String) ? Fstring_to_number(val, Qnil) :val;
      else if (EQ (prop, Qheight))
         height = (XTYPE(val)==Lisp_String) ? Fstring_to_number(val, Qnil) : val;
      else if (EQ (prop, Qtop))
         top = (XTYPE(val)==Lisp_String) ? Fstring_to_number(val, Qnil) : val;
      else if (EQ (prop, Qleft))
         left = (XTYPE(val)==Lisp_String) ? Fstring_to_number(val, Qnil) : val;
      else if (EQ (prop, Qicon_top))
         icon_top = (XTYPE(val)==Lisp_String) ? Fstring_to_number(val, Qnil) : val;
      else if (EQ (prop, Qicon_left))
         icon_left = (XTYPE(val)==Lisp_String) ? Fstring_to_number(val, Qnil) : val;
      else
         {
         Lisp_Object param_index, old_value;

         param_index = Fget (prop, Qns_frame_parameter);
         old_value = get_frame_param (f, prop);

         store_frame_param (f, prop, val);
         if (XTYPE (param_index) == Lisp_Int
             && XINT (param_index) >= 0
             && (XINT (param_index)
                 < sizeof (ns_frame_parms)/sizeof (ns_frame_parms[0])))
	    (*ns_frame_parms[XINT (param_index)].setter)(f, val, old_value);
         }
      }

   /* Don't die if just one of these was set.  */
   if (EQ (left, Qunbound))
      XSETINT (left, (int)f->output_data.ns->left);
   if (EQ (top, Qunbound))
      XSETINT (top, (int)f->output_data.ns->top);

   /* Don't die if just one of these was set.  */
   if (EQ (icon_left, Qunbound))
     icon_left = f->output_data.ns->icon_left;
   if (EQ (icon_top, Qunbound))
     icon_top = f->output_data.ns->icon_top;

   /* Don't die if just one of these was set.  */
   if (EQ (width, Qunbound))
     {
       if (FRAME_NEW_WIDTH (f))
         XSETINT (width, FRAME_NEW_WIDTH (f));
       else
         XSETINT (width, FRAME_WIDTH (f));
     }
   if (EQ (height, Qunbound))
     {
       if (FRAME_NEW_HEIGHT (f))
         XSETINT (height, FRAME_NEW_HEIGHT (f));
       else
         XSETINT (height, FRAME_HEIGHT (f));
     }

   /* Don't set these parameters these unless they've been explicitly
      specified.  The window might be mapped or resized while we're in
      this function, and we don't want to override that unless the lisp
      code has asked for it.

      Don't set these parameters unless they actually differ from the
      window's current parameters; the window may not actually exist
      yet.  */
      {
      Lisp_Object frame;

      XSETFRAME (frame, f);

      if (!INTEGERP (width) || !INTEGERP (height)
          || (INTEGERP (width) && XINT (width) != FRAME_WIDTH (f))
          || (INTEGERP (height) && XINT (height) != FRAME_HEIGHT (f))
          || FRAME_NEW_HEIGHT (f) || FRAME_NEW_WIDTH (f))
         Fset_frame_size (frame, width, height);
      if (!INTEGERP (left) || !INTEGERP (top)
          || (INTEGERP (left) && XINT (left) != f->output_data.ns->left)
          || (INTEGERP (top) && XINT (top) != f->output_data.ns->top))
         Fset_frame_position (frame, left, top);
      if ((! EQ (icon_left, f->output_data.ns->icon_left))
          || (! EQ (icon_top, f->output_data.ns->icon_top)))
        {
          id window = [f->output_data.ns->view window];
          NSScreen *screen = [window screen];
          
          f->output_data.ns->icon_top = icon_top;
          f->output_data.ns->icon_left = icon_left;
          if (NUMBERP (icon_top) && NUMBERP (icon_left))
            if ([window isMiniaturized])
              [window setFrameTopLeftPoint:NSMakePoint(SCREENMAXBOUND(XFLOATINT (icon_left)), SCREENMAXBOUND([screen frame].size.height-
                                      XFLOATINT (icon_top)))];
#ifdef NOT_IMPLEMENTED
            else
#warning WindowConversion: style was converted to styleMask.  NXImageView also used to have a style method, which is now imageFrameStyle.  Check to make sure this conversion is correct.
              if ([[window counterpart] styleMask] == NX_MINIWINDOWSTYLE) 
                [[window counterpart] setFrameTopLeftPoint:NSMakePoint(SCREENMAXBOUND(XFLOATINT (icon_left)), SCREENMAXBOUND([screen frame].size.height-
                                    XFLOATINT (icon_top)))];
#endif
        }
      }
   }

void x_report_frame_params (struct frame *f, Lisp_Object *alistptr)
   {
   store_in_alist (alistptr, Qicon_left, f->output_data.ns->icon_left);
   store_in_alist (alistptr, Qicon_top, f->output_data.ns->icon_top);
   store_in_alist (alistptr, Qleft, make_number ((int) f->output_data.ns->left));
   store_in_alist (alistptr, Qtop, make_number ((int) f->output_data.ns->top));
   store_in_alist (alistptr, Qinternal_border_width,
                   make_number ((int) f->output_data.ns->internal_border_width));
   store_in_alist (alistptr, Qicon_name, f->icon_name);
   FRAME_SAMPLE_VISIBILITY (f);
   store_in_alist (alistptr, Qvisibility,
                   (FRAME_VISIBLE_P (f) ? Qt
                    : FRAME_ICONIFIED_P (f) ? Qicon : Qnil));
   store_in_alist (alistptr, Qdisplay,
                   XCONS (FRAME_NS_DISPLAY_INFO (f)->name_list_element)->car);
   store_in_alist (alistptr, Qmenu_bar_lines, FRAME_EXTERNAL_MENU_BAR(f));
   }

DEFUN ("ns-popup-font-panel", Fns_popup_font_panel, Sns_popup_font_panel, 0,1,"",
       "Pop up the font panel.")
     (frame)
     Lisp_Object frame;
   {
   id fm;
   struct frame *f;

   check_ns();
   fm=[NSFontManager new];
   if (NILP(frame))
      f=selected_frame;
   else
      {
      CHECK_FRAME(frame, 0);
      f=XFRAME (frame);
      }

#ifdef NOT_IMPLEMENTED2
   if (f->output_data.ns->face->font==0)
      ns_load_font(f->output_data.ns->face);
#endif
   [fm setSelectedFont:f->output_data.ns->font->nsfont isMultiple:NO];
   [fm orderFrontFontPanel:NSApp];
   return Qnil;
   }

DEFUN ("ns-popup-color-panel", Fns_popup_color_panel, Sns_popup_color_panel, 0,1,"",
       "Pop up the color panel.")
     (frame)
     Lisp_Object frame;
   {
   struct frame *f;

   check_ns();
   if (NILP(frame))
      f=selected_frame;
   else
      {
      CHECK_FRAME(frame, 0);
      f=XFRAME (frame);
      }

   [NSApp orderFrontColorPanel:NSApp];
   return Qnil;
   }

DEFUN ("ns-read-file-name", Fns_read_file_name, Sns_read_file_name, 1, 5, 0,
       "As read-file-name except that NS panels are used for querrying.")
  (prompt, dir, defalt, mustmatch, initial)
     Lisp_Object prompt, dir, defalt, mustmatch, initial;
   {
   int ret;
   id panel;

   check_ns();

   CHECK_STRING(prompt, 0);

   if (NILP(dir))
      dir=current_buffer->directory;
   else
      CHECK_STRING(dir,0);

   if (NILP(defalt))
      defalt=current_buffer->filename;
   else
      CHECK_STRING(defalt,0);
   
   if (NILP(initial))
      initial=build_string("");
   else
      CHECK_STRING(initial,0);

//   panel=[EmacsFilePanel openPanel];
   panel=[NSOpenPanel openPanel];
#if 0
   [panel setDelegate:panel];
   [panel setAllowCreate:NILP(mustmatch)];
   [panel setAllowOld:YES];
   [panel setAllowDir:YES];
#endif
   [panel setTitle:[NSString stringWithCString:XSTRING(prompt)->data]];
   [panel setRequiredFileType:@""];
   [panel setTreatsFilePackagesAsDirectories:YES];

   ret=[panel runModalForDirectory:@"" file:@""];
   [[selected_frame->output_data.ns->view window] makeKeyWindow];
   if (ret!=NSOKButton) Fsignal(Qquit,Qnil);
   return build_string([[panel filename] cString]);
   }

DEFUN ("ns-yes-or-no-p", Fns_yes_or_no_p, Sns_yes_or_no_p, 1, 1, 0,
       "As yes-or-no-p except that NS panels are used for querrying.")
   (prompt)
   {
   int ret;
   CHECK_STRING(prompt, 0);
   ret=NSRunAlertPanel([[NSProcessInfo processInfo] processName], [NSString stringWithCString:XSTRING(prompt)->data], @"Yes", @"No", @"Cancel");
   [[selected_frame->output_data.ns->view window] makeKeyWindow];
   if (ret==NSAlertDefaultReturn)   return Qt;
   if (ret==NSAlertAlternateReturn) return Qnil;
   if (ret==NSAlertOtherReturn)     Fsignal(Qquit,Qnil);
   error ("NXRunAlertPanel returns invalid.");
   return Qnil;
   }

DEFUN ("ns-get-resource", Fns_get_resource, Sns_get_resource, 2, 2, 0,
  "Return the value of the property NAME of OWNER from the defaults database.\n\
If OWNER is nil, Emacs is assumed.")
  (owner, name)
   Lisp_Object owner, name;
   {
   const char *value;
#ifdef AUTORELEASE
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif

   check_ns();
   if (NILP(owner))
      owner= build_string([[[NSProcessInfo processInfo] processName] cString]);
   CHECK_STRING(owner, 0);
   CHECK_STRING(name, 0);

   value=[[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:XSTRING(name)->data]] cString];

#ifdef AUTORELEASE
   [pool release];
#endif

   if (value)
      return build_string (value);
   else
      return Qnil;
   }

DEFUN ("x-get-resource", Fx_get_resource, Sx_get_resource, 2, 4, 0,
  "Return the value of ATTRIBUTE, of class CLASS, from the X defaults database.\n\
This uses `INSTANCE.ATTRIBUTE' as the key and `Emacs.CLASS' as the\n\
class, where INSTANCE is the name under which Emacs was invoked, or\n\
the name specified by the `-name' or `-rn' command-line arguments.\n\
\n\
The optional arguments COMPONENT and SUBCLASS add to the key and the\n\
class, respectively.  You must specify both of them or neither.\n\
If you specify them, the key is `INSTANCE.COMPONENT.ATTRIBUTE'\n\
and the class is `Emacs.CLASS.SUBCLASS'.")
  (attribute, class, component, subclass)
     Lisp_Object attribute, class, component, subclass;
{
  register const char *value;

  check_ns ();

  CHECK_STRING (attribute, 0);
  CHECK_STRING (class, 0);

  if (!NILP (component))
    CHECK_STRING (component, 1);
  if (!NILP (subclass))
    CHECK_STRING (subclass, 2);
  if (NILP (component) != NILP (subclass))
    error ("x-get-resource: must specify both COMPONENT and SUBCLASS or neither");

  value=[[[NSUserDefaults standardUserDefaults] 
	   objectForKey:[NSString stringWithCString:XSTRING (attribute)->data]] cString];
  

  if (value != (char *) 0)
    return build_string (value);
  else
    return Qnil;
}

DEFUN ("ns-set-resource", Fns_set_resource, Sns_set_resource, 3, 3, 0,
  "Set property NAME of OWNER to VALUE, from the defaults database.\n\
If OWNER is nil, Emacs is assumed.\n\
If VALUE is nil, the default is removed.")
  (owner, name, value)
   Lisp_Object owner, name, value;
   {
   check_ns();
   if (NILP(owner))
      owner= build_string([[[NSProcessInfo processInfo] processName] cString]);
   CHECK_STRING(owner, 0);
   CHECK_STRING(name, 0);
   if (NILP(value))
      {
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithCString:XSTRING(name)->data]];
      }
   else
      {
      CHECK_STRING(value, 0);
      [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:XSTRING(value)->data] forKey:[NSString stringWithCString:XSTRING(name)->data]];
      }

   return Qnil;
   }

static void
ns_icon (f, parms)
     struct frame *f;
     Lisp_Object parms;
{
  Lisp_Object icon_x, icon_y;

  f->output_data.ns->icon_top = Qnil;
  f->output_data.ns->icon_left = Qnil;

  /* Set the position of the icon.  */
  icon_x = ns_get_arg (parms, Qicon_left, 0, 0);
  icon_y = ns_get_arg (parms, Qicon_top, 0, 0);
  if (!EQ (icon_x, Qunbound) && !EQ (icon_y, Qunbound))
    {
      CHECK_NUMBER (icon_x, 0);
      CHECK_NUMBER (icon_y, 0);
      f->output_data.ns->icon_top = icon_y;
      f->output_data.ns->icon_left = icon_x;
    }
  else if (!EQ (icon_x, Qunbound) || !EQ (icon_y, Qunbound))
    error ("Both left and top icon corners of icon must be specified");

}

DEFUN ("x-create-frame", Fns_create_frame, Sns_create_frame,
       1, 1, 0,
  "Make a new NS window, which is called a \"frame\" in Emacs terms.\n\
Return an Emacs frame object representing the X window.\n\
ALIST is an alist of frame parameters.\n\
If the parameters specify that the frame should not have a minibuffer,\n\
and do not specify a specific minibuffer window to use,\n\
then `default-minibuffer-frame' must be a frame whose minibuffer can\n\
be shared by the new frame.")
  (parms)
Lisp_Object parms;
   {
   struct frame *f;
   Lisp_Object frame, tem;
   Lisp_Object name;
   int minibuffer_only = 0;
   long window_prompting = 0;
   int width, height;
   int count = specpdl_ptr - specpdl;
   Lisp_Object display;
   struct ns_display_info *dpyinfo;
   struct kboard *kb;
#ifdef AUTORELEASE
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif

   check_ns();

   display = ns_get_arg (parms, Qdisplay, 0, 0);
   if (EQ (display, Qunbound))
     display = Qnil;
   dpyinfo = check_ns_display_info (display);
#ifdef MULTI_KBOARD
   kb = dpyinfo->kboard;
#else
   kb = &the_only_kboard;
#endif

   name = ns_get_arg (parms, Qname, 0, 0);
   if (!STRINGP (name)
       && ! EQ (name, Qunbound)
      && ! NILP (name))
     error ("Invalid frame name--not a string or nil");

   tem = ns_get_arg(parms, Qminibuffer, 0, 0);
   if (XTYPE(tem)==Lisp_String) tem=Fintern(tem, Qnil);

   if (EQ (tem,Qnone) || NILP(tem))
      {
      f= make_frame_without_minibuffer(Qnil, current_kboard, display);
      }
   else if (EQ (tem, Qonly))
      {
      f= make_minibuffer_frame ();
      minibuffer_only =1;
      }
   else if (WINDOWP (tem))
      {
      f= make_frame_without_minibuffer(tem, current_kboard, display);
      }
   else
      {
      f= make_frame (1);
      }

   FRAME_CAN_HAVE_SCROLL_BARS (f) = 1;

   XSETFRAME (frame, f);
   f->output_method = output_ns;
   f->output_data.ns = (struct ns_output *) xmalloc (sizeof *(f->output_data.ns));
   bzero (f->output_data.ns, sizeof (*(f->output_data.ns)));

   f->icon_name = ns_get_arg (parms, Qicon_name, 0, 0);
   if (EQ (f->icon_name, Qunbound) || (XTYPE (f->icon_name) != Lisp_String))
     f->icon_name = Qnil;
   
  FRAME_NS_DISPLAY_INFO (f) = dpyinfo;
#ifdef MULTI_KBOARD
  FRAME_KBOARD (f) = kb;
#endif

  /* Note that the frame has no physical cursor right now.  */
   f->phys_cursor_x = -1;
   f->phys_cursor_y = -1;

  /* Set the name; the functions to which we pass f expect the name to
     be set.  */
   if (EQ (name, Qunbound) || NILP (name) || (XTYPE (name) != Lisp_String))
      {
      f->name = build_string([[[NSProcessInfo processInfo] processName] cString]);
      f->explicit_name=0;
      }
   else
      {
      f->name = name;
      f->explicit_name=1;
      /* use the frame's title when getting resources for this frame.  */
      specbind (Qx_resource_name, name);
      }

   ns_default_parameter(f, parms, Qinternal_border_width, make_number(2),
                        0, "InternalBorderWidth");
   ns_default_parameter(f, parms, Qvertical_scroll_bars, Qt,
                        0, "VerticalScrollBars");
   ns_default_parameter(f, parms, Qicon_type, Qnil, 0, "BitmapIcon");
   ns_default_parameter(f, parms, Qauto_raise, Qnil,0, "AutoRaise");
   ns_default_parameter(f, parms, Qauto_lower, Qnil,0, "AutoLower");
   ns_default_parameter(f, parms, Qbuffered, Qt, 0, "Buffered");
      {
      id font=[NSFont userFixedPitchFontOfSize:-1.0];
      ns_default_parameter(f, parms, Qfont, build_string([[font fontName] cString]),
                           0, "Font");
      ns_default_parameter(f, parms, Qforeground_color, build_string("Black"),
                           0, "Foreground");
      ns_default_parameter(f, parms, Qbackground_color, build_string("White"),
                           0, "Background");
      ns_default_parameter(f, parms, Qfontsize, make_number((int)[font pointSize]),
                           0, "FontSize");
      ns_default_parameter(f, parms, Qunderline, Qnil,
                           0, "Underline");
      ns_new_font(f, [[font fontName] cString]);
      }
   ns_default_parameter(f, parms, Qheight, make_number(48), 0, "Height");
   ns_default_parameter(f, parms, Qwidth, make_number(80), 0, "Width");
   ns_default_parameter(f, parms, Qcursor_color, build_string("Highlight"),
                        0, "CursorColor");
   ns_default_parameter(f, parms, Qcursor_type, Qbox, 0, "CursorType");
   ns_default_parameter(f, parms, Qtop, make_number(100), 0, "Top");
   ns_default_parameter(f, parms, Qleft, make_number(100), 0, "Left");
   ns_default_parameter(f, parms, Qmenu_bar_lines, make_number(1), 0, "Menus");
   ns_default_parameter(f, parms, Qscroll_bar_width, Qnil, 0,
                        "ScrollBarWidth");
   ns_default_parameter (f, parms, Qbuffer_predicate, Qnil, 0,
                         "BufferPredicate");
   ns_default_parameter (f, parms, Qtitle, Qnil, 0, "Title");

   tem= ns_get_arg (parms, Qunsplittable, 0, 0);
   f->no_split = minibuffer_only || (!EQ (tem, Qunbound) && !EQ (tem, Qnil));

   ns_icon (f, parms);
   ns_init_frame_faces(f);

   [[EmacsView alloc] initFrameFromEmacs:f];

   /* It is now ok to make the frame official
      even if we get an error below.
      And the frame needs to be on Vframe_list
      or making it visible won't work.  */
   Vframe_list = Fcons (frame, Vframe_list);

   tem=ns_get_arg(parms, Qvisibility,0,0);
   if (EQ (tem, Qunbound)) tem = Qt;
   ns_set_visibility(f,tem,Qnil);
   if (EQ (tem, Qt)) [[f->output_data.ns->view window] makeKeyWindow];

#ifdef AUTORELEASE
   [pool release];                         
#endif

   return unbind_to (count, frame);
   }

Lisp_Object x_get_focus_frame (frame)
     struct frame *frame;
   {
   Lisp_Object nsfocus;

   if (!ns_focus_frame)
      return Qnil;

   XSETFRAME (nsfocus, ns_focus_frame);
   return nsfocus;
   }

DEFUN ("ns-make-key-frame", Fns_make_key_frame, Sns_make_key_frame, 0, 1, 0,
  "Make FRAME the OpenStep key window.\n\
If FRAME is omitted, make the currently selected frame the OpenStep\n\
key window.")
  (frame)
    Lisp_Object frame;
{
#ifdef AUTORELEASE
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
  FRAME_PTR f = check_ns_frame (frame);
  id view = f->output_data.ns->view;
  [[view window] makeKeyWindow];
#ifdef AUTORELEASE
  [pool release];
#endif
  return Qnil;
}


DEFUN ("ns-list-fonts", Fns_list_fonts, Sns_list_fonts, 1, 3, 0,
  "Return a list of the names of available fonts matching PATTERN.\n\
If optional arguments FACE and FRAME are specified, return only fonts\n\
the same size as FACE on FRAME.\n\
\n\
PATTERN is a regular expression; FACE is a face name - a symbol.\n\
\n\
The return value is a list of strings, suitable as arguments to\n\
set-face-font.\n\
\n\
Fonts Emacs can't use (i.e. proportional fonts) may or may not be excluded\n\
even if they match PATTERN and FACE.")
  (pattern, face, frame)
    Lisp_Object pattern, face, frame;
   {
   int len;
   Lisp_Object list,str,rpattern,args[3];
   id fm=[NSFontManager new];
   struct re_pattern_buffer *bufp;
   NSEnumerator *fenum;
   NSString *font;
#ifdef AUTORELEASE
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif

   check_ns();
   CHECK_STRING(pattern,0);

   args[0]=build_string("^");
   args[1]=pattern;
   args[2]=build_string("$");
   rpattern = Fconcat(3, args);
   bufp = compile_pattern (rpattern, 0, 0, 0);

   if (!NILP(face))  CHECK_SYMBOL(face,0);
   if (!NILP(frame))
      {
      CHECK_FRAME(frame,0);
      if (! FRAME_NS_P (XFRAME(frame)))
         error ("non-NS frame used in `ns-list-fonts'");
      }

   fenum = [[fm availableFonts] objectEnumerator];
   while ( font = [fenum nextObject] ) {
     /* XXX: Don't ignore frame/face */
     len=[font length];
     if (re_search(bufp, [font cString], len, 0, len, 0)>=0)
       list=Fcons(build_string ([font cString]),list);
   }

#ifdef AUTORELEASE
   [pool release];
#endif
   return list;
   }

DEFUN ("ns-list-colors", Fns_list_colors, Sns_list_colors, 0, 1, 0,
  "Return a list of all available colors.\n\
The optional argument FRAME is currently ignored.")
  (frame)
    Lisp_Object frame;
{
  Lisp_Object list = Qnil;
  NSArray *colorlistlist = [NSColorList availableColorLists];
  int l, n = [colorlistlist count];
  int i;
#ifdef AUTORELEASE
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];  
#endif
  if (!NILP(frame))
    {
      CHECK_FRAME(frame,0);
      if (! FRAME_NS_P (XFRAME(frame)))
        error ("non-NS frame used in `ns-list-fonts'");
    }

  for (l = 0; l < n; l++)
    {
      id clist = [colorlistlist objectAtIndex:l];
      if ([[clist name] length] < 7 ||
          strncmp([[clist name] cString], "PANTONE", 7))
        {
          for (i = [[clist allKeys] count] - 1; i >= 0; i--)
            list = Fcons (build_string ([[[clist allKeys] objectAtIndex:i] cString]), list);
        }
    }
#ifdef AUTORELEASE
  [pool release];  
#endif
  return list;
}

DEFUN ("x-color-defined-p", Fns_color_defined_p, Sns_color_defined_p, 1, 2, 0,
  "Return t if the current NS display supports the color named COLOR.\n\
The optional argument FRAME is currently ignored.")
  (color, frame)
     Lisp_Object color, frame;
   {
   NSColor * col;
   check_ns();
   return ns_lisp_to_color(color, &col) ? Qnil : Qt;
   }

DEFUN ("x-color-values", Fns_color_values, Sns_color_values, 1, 2, 0,
  "Return a description of the color named COLOR.\n\
The value is a list of integer RGBA values--(RED GREEN BLUE ALPHA).\n\
These values appear to range from 0 to 65280; white is (65280 65280 65280 0).\n\
The optional argument FRAME is currently ignored.")
  (color, frame)
Lisp_Object color, frame;
   {
   NSColor * col;
   float red,green,blue,alpha;
   Lisp_Object rgba[4];
#ifdef AUTORELEASE
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];  
#endif

   check_ns ();
   CHECK_STRING (color, 0);
   
   if (ns_lisp_to_color(color, &col))
      return Qnil;

   [[col colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:&alpha];
   rgba[0] = make_number ((int) rint(red*65280));
   rgba[1] = make_number ((int) rint(green*65280));
   rgba[2] = make_number ((int) rint(blue*65280));
   rgba[3] = make_number ((int) rint(alpha*65280));

#ifdef AUTORELEASE
   [pool release];
#endif
   return Flist (4, rgba);
   }

static id ns_get_window(Lisp_Object frame)
   {// FIXME/cl for multi-display
   id view=nil,window=nil;
   NSScreen *screen =0;
   if (!FRAMEP(frame) || !FRAME_NS_P(XFRAME(frame)))
      frame = wrong_type_argument (Qframep, frame);
   view=XFRAME(frame)->output_data.ns->view;
   if (view) window=[view window];
   return window;
   }

static NSScreen *ns_get_screen(Lisp_Object display)
   {
   id window=nil;
   NSScreen *screen = 0;

   if (STRINGP(display)) // FIXME/cl for multi-display
     display = Qnil;
   if (FRAMEP(display) && FRAME_NS_P(XFRAME(display)))
      window = ns_get_window(display);
   if (window != nil) screen =[window screen];
   if (!screen) screen = [NSScreen mainScreen];
   return screen;
   }

DEFUN ("x-display-color-p", Fns_display_color_p, Sns_display_color_p, 0, 1, 0,
  "Return t if the NS display supports color.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
     NSWindowDepth depth;
   check_ns();
   depth = [ns_get_screen(display) depth];
   if ( depth == NSBestDepth(NSCalibratedWhiteColorSpace, 2, 2, YES, NULL)
	|| depth == NSBestDepth(NSCalibratedWhiteColorSpace, 8, 8, YES, NULL) )
     return Qnil;
   else if (depth == NSBestDepth(NSCalibratedRGBColorSpace, 8, 8, YES, NULL)
	    || depth == NSBestDepth(NSCalibratedRGBColorSpace, 4, 12, NO,NULL)
	    || depth == NSBestDepth(NSCalibratedRGBColorSpace, 8, 24, NO,NULL))
     return Qt;
   else
     error ("Screen has an unknown visual class");
   }

DEFUN ("x-display-grayscale-p", Fns_display_grayscale_p,
       Sns_display_grayscale_p, 0, 1, 0,
  "Return t if the NS display supports shades of gray.\n\
Note that color displays do support shades of gray.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
     NSWindowDepth depth;
   check_ns();
   depth = [ns_get_screen(display) depth];
   if ( depth == NSBestDepth(NSCalibratedWhiteColorSpace, 2, 2, YES, NULL)
	|| depth == NSBestDepth(NSCalibratedWhiteColorSpace, 8, 8, YES, NULL)
	|| depth == NSBestDepth(NSCalibratedRGBColorSpace, 8, 8, YES, NULL)
	|| depth == NSBestDepth(NSCalibratedRGBColorSpace, 4, 12, NO, NULL)
	|| depth == NSBestDepth(NSCalibratedRGBColorSpace, 8, 24, NO, NULL))
     return Qt;
   else
      error ("Screen has an unknown visual class");
   }

DEFUN ("x-display-pixel-width", Fns_display_pixel_width, Sns_display_pixel_width,
  0, 1, 0,
  "Returns the width in pixels of the NS display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   return make_number ((int) [ns_get_screen(display) frame].size.width);
   }

DEFUN ("ns-display-pixel-height", Fns_display_pixel_height,
  Sns_display_pixel_height, 0, 1, 0,
  "Returns the height in pixels of the NS display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   return make_number ((int) [ns_get_screen(display) frame].size.height);
   }

DEFUN ("ns-display-planes", Fns_display_planes, Sns_display_planes,
  0, 1, 0,
  "Returns the number of bitplanes of the NS display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   return make_number (NSBitsPerSampleFromDepth ([ns_get_screen(display) depth]));
   }

DEFUN ("ns-display-color-cells", Fns_display_color_cells, Sns_display_color_cells,
  0, 1, 0,
  "Returns the number of color cells of the NS display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   return make_number (1<<NSBitsPerSampleFromDepth ([ns_get_screen(display) depth]));
   }

DEFUN ("ns-server-max-request-size", Fns_server_max_request_size,
       Sns_server_max_request_size,
  0, 1, 0,
  "This function is only present for completeness.  It does not return\n\
a usable result for NS windows.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   /* This function has no real equivalent under NeXTstep.  Return nil to
      indicate this. */
   return Qnil;
   }

DEFUN ("ns-server-vendor", Fns_server_vendor, Sns_server_vendor, 0, 1, 0,
  "Returns the vendor ID string of the NS server of display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   return build_string ("Apple");
   }

DEFUN ("ns-server-version", Fns_server_version, Sns_server_version, 0, 1, 0,
  "Returns the version number of the NS release of display DISPLAY.\n\
See also the function `ns-server-vendor'.\n\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   kernel_version_t string;
   check_ns();
   if (host_kernel_version(host_self(), string) == KERN_SUCCESS)
      return build_string(string);
   else
      return Qnil;
   }

DEFUN ("ns-display-screens", Fns_display_screens, Sns_display_screens, 0, 1, 0,
  "Returns the number of screens on the NS server of display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   int num;

   check_ns();
   num = [[NSScreen screens] count];

   return (num!=0) ? make_number (num) : Qnil;
   }

DEFUN ("ns-display-mm-height", Fns_display_mm_height, Sns_display_mm_height, 0, 1, 0,
  "Returns the height in millimeters of the NS display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   return make_number ((int) ([ns_get_screen(display) frame].size.height/(92.0/25.4)));
   }

DEFUN ("ns-display-mm-width", Fns_display_mm_width, Sns_display_mm_width, 0, 1, 0,
  "Returns the width in millimeters of the NS display DISPLAY.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   return make_number ((int) ([ns_get_screen(display) frame].size.width/(92.0/25.4)));
   }

DEFUN ("ns-display-backing-store", Fns_display_backing_store,
  Sns_display_backing_store, 0, 1, 0,
  "Returns an indication of whether NS display DISPLAY does backing store.\n\
The value may be `buffered', `retained', or `non-retained'.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.\n\
Under NS, this may differ for each frame.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   switch ([ns_get_window(display) backingType])
      {
    case NSBackingStoreBuffered:
      return intern ("buffered");

    case NSBackingStoreRetained:
      return intern ("retained");

    case NSBackingStoreNonretained:
      return intern ("non-retained");

    default:
      error ("Strange value for backingType parameter of frame");
      }
   }

DEFUN ("ns-display-visual-class", Fns_display_visual_class,
  Sns_display_visual_class, 0, 1, 0,
  "Returns the visual class of the NS display DISPLAY.\n\
The value is one of the symbols `static-gray', `gray-scale',\n\
`static-color', `pseudo-color', `true-color', or `direct-color'.\n\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.")
	(display)
     Lisp_Object display;
   {
     NSWindowDepth depth;
   check_ns();
   depth = [ns_get_screen(display) depth];

   if ( depth == NSBestDepth(NSCalibratedWhiteColorSpace, 2, 2, YES, NULL))
     return (intern ("static-gray"));
   else if (depth == NSBestDepth(NSCalibratedWhiteColorSpace, 8, 8, YES, NULL))
     return (intern ("gray-scale"));
   else if ( depth == NSBestDepth(NSCalibratedRGBColorSpace, 8, 8, YES, NULL))
     return (intern ("pseudo-color"));
   else if ( depth == NSBestDepth(NSCalibratedRGBColorSpace, 4, 12, NO, NULL))
     return (intern ("true-color"));
   else if ( depth == NSBestDepth(NSCalibratedRGBColorSpace, 8, 24, NO, NULL))
     return (intern ("direct-color"));
   else
     error ("Screen has an unknown visual class");
   }

DEFUN ("ns-display-save-under", Fns_display_save_under,
  Sns_display_save_under, 0, 1, 0,
  "Returns t if the NS display DISPLAY supports the save-under feature.\n\
The optional argument DISPLAY specifies which display to ask about.\n\
DISPLAY should be either a frame or a display name (a string).\n\
If omitted or nil, that stands for the selected frame's display.\n\
Under NS, this may differ for each frame.")
  (display)
     Lisp_Object display;
   {
   check_ns();
   switch ([ns_get_window(display) backingType])
      {
    case NSBackingStoreBuffered:
      return Qt;

    case NSBackingStoreRetained:
    case NSBackingStoreNonretained:
      return Qnil;

    default:
      error ("Strange value for backingType parameter of frame");
      }
   }

int x_pixel_width (struct frame *f)
   {
   id view=f->output_data.ns->view;
   NSRect r;
   r = [view bounds];
   return r.size.width+2*f->output_data.ns->internal_border_width;
   }

int x_pixel_height (struct frame *f)
   {
   id view=f->output_data.ns->view;
   NSRect r;
   r = [view bounds];
   return r.size.height+2*f->output_data.ns->internal_border_width;
   }

int x_char_width (struct frame *f)
   {
   return FONT_WIDTH(f->output_data.ns->font);
   }

int x_char_height (struct frame *f)
   {
   return f->output_data.ns->line_height;
   }

int x_screen_planes (struct frame *f)
{
  Lisp_Object frame;
  XSETFRAME (frame, f);

  return NSBitsPerSampleFromDepth  ([ns_get_screen (frame) depth]);
}

/* Return the X display structure for the display named NAME.
   Open a new connection if necessary.  */

struct ns_display_info *
ns_display_info_for_name (name)
     Lisp_Object name;
{
  Lisp_Object names;
  struct ns_display_info *dpyinfo;

  CHECK_STRING (name, 0);

  for (dpyinfo = ns_display_list, names = ns_display_name_list;
       dpyinfo;
       dpyinfo = dpyinfo->next, names = XCONS (names)->cdr)
    {
      Lisp_Object tem;
      tem = Fstring_equal (XCONS (XCONS (names)->car)->car, name);
      if (!NILP (tem))
	return dpyinfo;
    }

  error ("Emacs for OpenStep does not yet support multi-display.");
  
  dpyinfo = ns_term_init (name);

  if (dpyinfo == 0)
    error ("OpenStep on %s not responding.\n", XSTRING (name)->data);

  return dpyinfo;
}

DEFUN ("ns-open-connection", Fns_open_connection, Sns_open_connection,
       1, 3, 0, "Open a connection to a NS server.\n\
DISPLAY is the name of the display to connect to.\n\
Optional arguments XRM-STRING and MUST-SUCCEED are currently ignored.")
  (display, resource_string, must_succeed)
Lisp_Object display, resource_string, must_succeed;
{
  struct ns_display_info *dpyinfo;
#ifdef AUTORELEASE
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];  
#endif

  CHECK_STRING (display, 0);
  if (ns_current_display != nil)
    {
      error ("NS connection already initialized");
#ifdef AUTORELEASE
      [pool release];
#endif
      return Qnil;
    }

  nxatoms_of_nsselect();
  dpyinfo = ns_term_init(display);
  if (dpyinfo == 0)
    {
      if (!NILP (must_succeed))
        fatal ("OpenStep on %s not responding.\n",
               XSTRING (display)->data);
      else
        error ("OpenStep on %s not responding.\n",
               XSTRING (display)->data);
    }

#ifdef AUTORELEASE
  [pool release];  
#endif

  return Qnil;
}

DEFUN ("ns-close-connection", Fns_close_connection, Sns_close_connection,
       1, 1, 0, "Close the connection to the current NS server.\n\
The second argument DISPLAY is currently ignored, but nil would stand for\n\
the selected frame's display.")
  (display)
  Lisp_Object display;
   {
   check_ns();
   PSFlush();
   [NSApp terminate:NSApp];
   ns_current_display=nil;
   return Qnil;
   }

DEFUN ("ns-display-list", Fns_display_list, Sns_display_list, 0, 0, 0,
  "Return the list of display names that Emacs has connections to.")
  ()
{
  Lisp_Object tail, result;

  result = Qnil;
  for (tail = ns_display_name_list; ! NILP (tail); tail = XCONS (tail)->cdr)
    result = Fcons (XCONS (XCONS (tail)->car)->car, result);

  return result;
}

DEFUN ("ns-synchronize", Fns_synchronize, Sns_synchronize,
       1, 2, 0,
"If ON is non-nil, report NS errors as soon as the erring request is made.\n\
If ON is nil, allow buffering of requests.\n\
Turning on synchronization prohibits the NS routines from buffering\n\
requests and seriously degrades performance, but makes debugging much\n\
easier.  The optional argument DISPLAY is currently ignored.")
  (on, display)
Lisp_Object on, display;
   {
   check_ns();
   DPSSetWrapSynchronization(DPSGetCurrentContext(), !EQ (on, Qnil));
   return Qnil;
   }

DEFUN ("hide-emacs", Fns_hide_emacs, Sns_hide_emacs,
       1, 1, 0, "If ON is non-nil, the entire emacs application is hidden.\n\
Otherwise if emacs is hidden, it is unhidden.\n\
If ON is equal to 'activate, emacs is unhidden and becomes the active application.")
  (on)
Lisp_Object on;
   {
   check_ns();
   if (EQ(on,intern("activate")))
      {
      [NSApp unhide:NSApp];
      [NSApp activateIgnoringOtherApps:YES];
      }
   else if (NILP(on))
      [NSApp unhide:NSApp];
   else
      [NSApp hide:NSApp];
   return Qnil;
   }


static Lisp_Object interpret_command_keys(id menu,
                                          Lisp_Object prefix,Lisp_Object old)
   {
   int i;
   id cell;
   unsigned short key;
   NSString *keys;
   NSArray *items = [menu itemArray];

   for (i=0; i < [items count]; i++)
      {
      cell=[items objectAtIndex:i];
      if ([cell hasSubmenu])
         {
         old=interpret_command_keys([cell target],
                                    Fcons([[cell representedObject] value],
					  prefix),old);
         }
      else if ((keys=[cell userKeyEquivalent]) && [keys length])
         {
	   key = [keys characterAtIndex:0];
         if (!NILP(ns_iso_latin) && key<256)
            key=ns2isomap[key];
         old=Fcons(Fcons(make_number(key|super_modifier),
                         Freverse(Fcons([[cell representedObject] value],
					prefix))),old);
         }
      }
   return old;
   }

DEFUN ("ns-list-command-keys", Fns_list_command_keys, Sns_list_command_keys,
       0, 0, 0, "List NS command equivalents for menus.")
   ()
   {
   Lisp_Object ret=Qnil;
   check_ns();
   ret=interpret_command_keys([NSApp mainMenu],Qnil,Qnil);
   return ret;
   }

static Lisp_Object interpret_services_menu(id menu,
                                           Lisp_Object prefix,Lisp_Object old)
   {
   int i;
   id cell;
   const char *name;
   unsigned short key;
   NSString *keys;
   Lisp_Object res;
   NSArray *items;

   items = [menu itemArray];

   for (i=0;i < [items count];i++)
      {
      cell=[items objectAtIndex:i];
      name=[[cell title] cString];
      if (!name) continue;
      if ([cell hasSubmenu])
         {
         old=interpret_services_menu([cell target],
                                     Fcons(build_string(name),prefix),old);
         [[cell target] release];
         }
      else
         {
         keys = [cell keyEquivalent];
         if (keys && [keys length] )
            {
	    key = [keys characterAtIndex:0];
            if (!NILP(ns_iso_latin) && key<256)
               key=ns2isomap[key];
            res=make_number(key|super_modifier);
            }
         else
            res=Qundefined;
         old=Fcons(Fcons(res,Freverse(Fcons(build_string(name),prefix))),old);
         }
      }
   return old;
   }

DEFUN ("ns-list-services", Fns_list_services, Sns_list_services, 0, 0, 0,
       "List NS services.\n\
WARNING:  This function crashes NS version older than NS 3.2.")
   ()
   {
   NSMenu *main, *smenu;
   id item;
   Lisp_Object ret=Qnil;
   check_ns();

#if 0
   main = [[NSMenu alloc] initWithTitle:@"Test"];
   [NSApp setMainMenu:main];
  
   item = [main addItemWithTitle:@"Services" action:0 keyEquivalent:@""];
   smenu = [[NSMenu alloc] init];
   [main setSubmenu:smenu forItem:item];
  
   [NSApp setServicesMenu:smenu];

   [NSApp registerServicesMenuSendTypes:ns_send_types returnTypes:ns_return_types];
   [smenu update];
#else
   [NSApp setServicesMenu:[[NSMenu alloc] init]];
   [NSApp registerServicesMenuSendTypes:ns_send_types returnTypes:ns_return_types];
   [[NSApp servicesMenu] update];
#endif

   ret=interpret_services_menu([NSApp servicesMenu],Qnil,ret);
   [NSApp setServicesMenu:nil];

   return ret;
   }

DEFUN ("ns-perform-service", Fns_perform_service, Sns_perform_service,
       2, 2, 0, "Perform NS SERVICE on SEND which is either a string or nil.\n\
Returns result of service as string or nil if no result.")
  (service, send)
Lisp_Object service, send;
   {
   id pb;

   check_ns();

   pb=[NSPasteboard pasteboardWithUniqueName];

   CHECK_STRING (service, 0);
   ns_string_to_pasteboard(pb,send);


   if (NSPerformService([NSString stringWithCString:XSTRING(service)->data], pb)==NO)
      Fsignal (Qerror, Fcons (build_string ("service not available"), Qnil));

   return ns_string_from_pasteboard(pb);

   }

DEFUN ("ns-show-ps", Fns_show_ps, Sns_show_ps,
       1, 1, 0, "Turn postscript logging on or off depending of the value of flag.")
  (flag)
Lisp_Object flag;
   {
   check_ns();
   [NSDPSContext setAllContextsOutputTraced:!NILP(flag)];
   return Qnil;
   }

DEFUN ("ns-show-events", Fns_show_events, Sns_show_events,
       1, 1, 0, "Turn event logging on or off depending of the value of flag.")
  (flag)
Lisp_Object flag;
   {
   check_ns();
   [NSDPSServerContext setEventsTraced:!NILP(flag)];
   return Qnil;
   }

void x_sync(Lisp_Object frame)
   {
   /* XXX Not implemented XXX */
   return;
   }


syms_of_nsfns ()
   {
   int i;

   ns_current_display=0;

   Qns_frame_parameter = intern ("ns-frame-parameter");
   staticpro (&Qns_frame_parameter);

   

   Qforeground_color = intern ("foreground-color");
   staticpro (&Qforeground_color);
   Qbackground_color = intern ("background-color");
   staticpro (&Qbackground_color);
   Qcursor_color = intern ("cursor-color");
   staticpro (&Qcursor_color);
   Qinternal_border_width = intern ("internal-border-width");
   staticpro (&Qinternal_border_width);
   Qvisibility = intern ("visibility");
   staticpro (&Qvisibility);
  Qicon_type = intern ("icon-type");
  staticpro (&Qicon_type);
  Qcursor_type = intern ("cursor-type");
  staticpro (&Qcursor_type);
  Qicon_left = intern ("icon-left");
  staticpro (&Qicon_left);
  Qicon_top = intern ("icon-top");
  staticpro (&Qicon_top);
  Qleft = intern ("left");
  staticpro (&Qleft);
  Qright = intern ("right");
  staticpro (&Qright);
  Qtop = intern ("top");
  staticpro (&Qtop);
  Qicon_name = intern ("icon-name");
  staticpro (&Qicon_name);
  Qdisplay = intern ("display");
  staticpro (&Qdisplay);
  Qnone = intern ("none");
  staticpro (&Qnone);
  Qx_resource_name = intern ("x-resource-name");
  staticpro (&Qx_resource_name);
  Qvertical_scroll_bars = intern ("vertical-scroll-bars");
  staticpro (&Qvertical_scroll_bars);
  Qauto_raise = intern ("auto-raise");
  staticpro (&Qauto_raise);
  Qauto_lower = intern ("auto-lower");
  staticpro (&Qauto_lower);
  Qbox = intern ("box");
  staticpro (&Qbox);
  Qscroll_bar_width = intern ("scroll-bar-width");
  staticpro (&Qscroll_bar_width);
  Qfontsize = intern ("fontsize");
  staticpro (&Qfontsize);
  Qbuffered = intern ("bufferd");
  staticpro (&Qbuffered);


   for (i = 0; i< sizeof (ns_frame_parms)/ sizeof (ns_frame_parms[0]); i++)
      Fput (intern (ns_frame_parms[i].name), Qns_frame_parameter,
            make_number (i));

   DEFVAR_LISP ("ns-icon-type-alist", &Vns_icon_type_alist,
"Alist of elements (REGEXP . IMAGE) for images of icons associated to\n\
frames.  If the title of a frame matches REGEXP, then IMAGE.tiff is\n\
selected as the image of the icon representing the frame when it's\n\
miniaturized.  If an element is t, then Emacs tries to select an icon\n\
based on the filetype of the visited file.\n\
\n\
The images have to be installed in a folder called English.lproj in the\n\
Emacs.app folder.  You have to restart Emacs after installing new icons.\n\
\n\
Example: Install an icon Gnus.tiff and execute the following code\n\
\n\
  (setq ns-icon-type-alist\n\
        (append ns-icon-type-alist\n\
                '((\"^\\\\*\\\\(Group\\\\*$\\\\|Summary \\\\|Article\\\\*$\\\\)\"\n\
                   . \"Gnus\"))))\n\
\n\
When you miniaturize a Group, Summary or Article frame, Gnus.tiff will\n\
be used as the image of the icon representing the frame.");
   Vns_icon_type_alist = Fcons (Qt, Qnil);

   DEFVAR_LISP ("x-bitmap-file-path", &Vx_bitmap_file_path,
		"List of directories to search for bitmap files for NS.");
   Vx_bitmap_file_path = decode_env_path ((char *) 0, PATH_BITMAPS);
  
   defsubr (&Sns_read_file_name);
   defsubr (&Sx_get_resource);
   defsubr (&Sns_get_resource);
   defsubr (&Sns_set_resource);
   defsubr (&Sns_display_color_p);
   defsubr (&Sns_display_grayscale_p);
   defsubr (&Sns_list_fonts);
   defsubr (&Sns_list_colors);
   defsubr (&Sns_color_defined_p);
   defsubr (&Sns_color_values);
   defsubr (&Sns_server_max_request_size);
   defsubr (&Sns_server_vendor);
   defsubr (&Sns_server_version);
   defsubr (&Sns_display_pixel_width);
   defsubr (&Sns_display_pixel_height);
   defsubr (&Sns_display_mm_width);
   defsubr (&Sns_display_mm_height);
   defsubr (&Sns_display_screens);
   defsubr (&Sns_display_planes);
   defsubr (&Sns_display_color_cells);
   defsubr (&Sns_display_visual_class);
   defsubr (&Sns_display_backing_store);
   defsubr (&Sns_display_save_under);
   defsubr (&Sns_create_frame);
   defsubr (&Sns_make_key_frame);
   defsubr (&Sns_open_connection);
   defsubr (&Sns_close_connection);
   defsubr (&Sns_display_list);
   defsubr (&Sns_synchronize);

   defsubr (&Sns_hide_emacs);
   defsubr (&Sns_list_command_keys);
   defsubr (&Sns_list_services);
   defsubr (&Sns_perform_service);
   defsubr (&Sns_show_ps);
   defsubr (&Sns_yes_or_no_p);
   defsubr (&Sns_show_events);
   defsubr (&Sns_popup_font_panel);
   defsubr (&Sns_popup_color_panel);

   get_font_info_func = ns_get_font_info;
   list_fonts_func = ns_list_fonts;
   load_font_func = ns_load_font;
//   query_font_func = x_query_font;
   set_frame_fontset_func = ns_set_font;
   check_window_system_func = check_ns;


   }

@implementation EmacsImage

static EmacsImage *ImageList = nil;

+ allocInitFromFile:(Lisp_Object)file
{
  EmacsImage *image = ImageList;
  Lisp_Object found;
  int fd;

  // look for an existing image of the same name
  while (image != nil && [[image name] compare:[NSString stringWithCString:XSTRING (file)->data]])
    image = [image imageListNext];
  
  if (image != nil)
    {
      [image reference];
      return image;
    }
  
  /* Search bitmap-file-path for the file, if appropriate.  */
  fd = openp (Vx_bitmap_file_path, file, "", &found, 0);
  if (fd < 0)
    return nil;

  close (fd);

  image = [[EmacsImage alloc] initByReferencingFile:[NSString stringWithCString:XSTRING (found)->data]];

  if ([image bestRepresentationForDevice:nil] == nil)
    {
      [image release];
      return nil;
    }

  [image setName:[NSString stringWithCString:XSTRING (file)->data]];
  [image reference];
  ImageList = [image imageListSetNext:ImageList];

  return image;
}

- reference
{
  refCount++;
  return self;
}

- imageListSetNext:(id)arg
{
  imageListNext = arg;
  return self;
}
  
- imageListNext
{
  return imageListNext;
}
  
- (void)dealloc
{
  id list = ImageList;
  
  if (refCount > 1)
    {
      refCount--;
      return;
    }

  if (list == self)
    ImageList = imageListNext;
  else
    {
      while (list != nil && [list imageListNext] != self)
        list = [list imageListNext];
      [list imageListSetNext:imageListNext];
    }
  if (stippleRep && stippleRep != self)
    [stippleRep release];
  { [super dealloc]; return; };
}

- initFromXBM:(unsigned char *)bits width:(int)w height:(int)h
{
  return [self initFromSkipXBM:bits width:w height:h length:0];
}

- initFromSkipXBM:(unsigned char *)bits width:(int)w height:(int)h
           length:(int)length;
{
  NSSize s = {w, h};
  id rep;
  unsigned char *planes[5];
  int bpr = (w + 7) / 8;
  
  [self initWithSize:s];

  rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:1 samplesPerPixel:2 hasAlpha:YES isPlanar:YES colorSpaceName:NSCalibratedBlackColorSpace bytesPerRow:bpr bitsPerPixel:0];

  [rep getBitmapDataPlanes:planes];
  {
    // turn the bytes around and invert for alpha on plane 2
    int i, j;
    unsigned char *s = bits;
    unsigned char *d = planes[0];
    unsigned char *d2 = planes[1];
    unsigned char swt[16] = {0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13,
                             3, 11, 7, 15};
    unsigned char c;
    
    for (j = 0; j < h; j++)
      for (i = 0; i < bpr; i++)
        {
          if (length)
            {
              unsigned char s1, s2;
              while (*s++ != 'x' && s < bits + length);
              if (s >= bits + length)
                {
                  [rep release];
                  return nil;
                }
#define hexchar(x) (isdigit (x) ? x - '0' : x - 'a' + 10)
              s1 = *s++;
              s2 = *s++;
              c = hexchar (s1) * 0x10 + hexchar (s2);
            }
          else
            c = *s++;
          
          *d = 0;
          *d = swt[c >> 4] | (swt[c & 0xf] << 4);
          *d2 = *d ^ 255;
          d++;
          d2++;
        }
  }
  
  [self addRepresentation:rep];

  return self;
}

// since 48 is a popular pixmap size, 96 is a good choice
#define STIPPLE_MIN_WIDTH 96
#define STIPPLE_MIN_HEIGHT 96
- prepareForStippling
{
  NSSize r;

  if (stippleRep && stippleRep != self)
    [stippleRep release];
  
  r = [self size];
  if ((r.width < STIPPLE_MIN_WIDTH || r.height < STIPPLE_MIN_HEIGHT)
      && r.width != 0 && r.height != 0)
    {
      int i;
      NSScreen *screen = [NSScreen mainScreen];// FIXME/cl for multi-display
      NSSize new;

      for (i = r.width; i < STIPPLE_MIN_WIDTH; i *= 2, new.width = i);
      for (i = r.height; i < STIPPLE_MIN_HEIGHT; i *= 2, new.height = i);

      stippleRep = [[NSImage alloc] initWithSize:new];
      [stippleRep addRepresentation:[[[NSCachedImageRep alloc] initWithSize:[stippleRep size] depth:[screen depth] separate:[stippleRep isCachedSeparately] alpha:YES] autorelease]];
      [stippleRep lockFocus];
        {
          NSPoint p = {0, 0};
          [self compositeToPoint:p operation:NSCompositeCopy];
          if (new.width != r.width)
            {
              NSRect s = {0, 0, 0, r.height};
              NSPoint d = {0, 0};
              for (i = r.width; i != new.width; i *= 2)
                {
                  s.size.width = i;
                  d.x = i;
                  [stippleRep compositeToPoint:d fromRect:s operation:NSCompositeCopy];
                }
            }
          if (new.height != r.height)
            {
              NSRect s = {0, 0, new.width, 0};
              NSPoint d = {0, 0};
              for (i = r.height; i != new.height; i *= 2)
                {
                  s.size.height = i;
                  d.y = i;
                  [stippleRep compositeToPoint:d fromRect:s operation:NSCompositeCopy];
                }
            }
          [stippleRep unlockFocus];
        }
    }
  else
    stippleRep = self;
}

- (NSImage *)stippleRep
{
  if (! stippleRep)
    [self prepareForStippling];
  return stippleRep;
}

@end

@implementation EmacsFilePanel

- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename
{
  return YES;
}

#ifdef NOT_IMPLEMENTED
- (BOOL)_validateNames:(char *)name checkBrowser:(BOOL)check
   {
   Lisp_Object path;
   NSString *newName;

   newName = [NSString stringWithFormat:@"%s/%s", [self directory], name);
   path=build_string(buf);

   if (NILP(Ffile_exists_p(path)))
      {
      if (!allowCreate) return NO;
      }
   else
      {
      if (!allowOld) return NO;
      }

   if (!allowDir && !NILP(Ffile_directory_p(path))) return NO;
   [self filename] = NXCopyStringBuffer(buf);
   return YES;
   }
#endif

- setAllowCreate:(BOOL)ifAllowCreate
   {
   allowCreate = ifAllowCreate;
   return self;
   }

- setAllowOld:(BOOL)ifAllowOld
   {
   allowOld = ifAllowOld;
   return self;
   }

- setAllowDir:(BOOL)ifAllowDir
   {
   allowDir = ifAllowDir;
   return self;
   }
@end
#endif
