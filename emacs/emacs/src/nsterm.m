/* NeXTstep communication module
   Copyright (C) 1989, 1993, 1994 Free Software Foundation, Inc.

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
#import <Foundation/NSObject.h>
#import <Foundation/NSDistantObject.h>
#import <Foundation/NSPort.h>
#import <drivers/event_status_driver.h>
#import <mach/mach.h>
#import <mach/message.h>
#import <servers/netname.h>
#import <math.h>
#import <sys/types.h>

#include "config.h"
#include "lisp.h"
#include "blockinput.h"
#include "dispextern.h"
#include "nsterm.h"
#include "systime.h"
#include "charset.h"
#include "fontset.h"

#include "termhooks.h"
#include "termopts.h"
#include "termchar.h"
#include "gnu.h"
#include "frame.h"
#include "disptab.h"
#include "buffer.h"
#include "window.h"
#include "keyboard.h"
#include "paths.h"
#include "charset.h"

#include "nswraps.h"

#define WAIT_FOR_DATA

#define min(a,b) ((a)<(b) ? (a) : (b))
#define max(a,b) ((a)>(b) ? (a) : (b))

#define KEY_NS_POWER_OFF      ((1<<28)|(0<<16)|1)
#define KEY_NS_OPEN_FILE      ((1<<28)|(0<<16)|2)
#define KEY_NS_OPEN_TEMP_FILE ((1<<28)|(0<<16)|3)
#define KEY_NS_DRAG_FILE      ((1<<28)|(0<<16)|4)
#define KEY_NS_DRAG_COLOR     ((1<<28)|(0<<16)|5)
#define KEY_NS_DRAG_ASCII     ((1<<28)|(0<<16)|6)
#define KEY_NS_CHANGE_FONT    ((1<<28)|(0<<16)|7)
#define KEY_NS_OPEN_FILE_LINE ((1<<28)|(0<<16)|8)
#define KEY_NS_CHANGE_GDB     ((1<<28)|(0<<16)|9)

NSMutableArray *selectingFileHandles = nil;

NSTrackingRectTag FRAME_TRACKNUM;
NSTrackingRectTag WINDOW_TRACKNUM;
NSTrackingRectTag MOUSE_FACE_TRACKNUM;

Lisp_Object ns_input_file,ns_input_font,ns_input_fontsize,ns_input_line;
Lisp_Object ns_input_color,ns_input_ascii;
extern Lisp_Object Qmouse_face;
extern Lisp_Object Qleft, Qright, Qcursor_color, Qcursor_type;
extern Lisp_Object Qbuffered;

id ns_current_display=nil;

/* Under NS, nonzero means that ns_read_file_name is executed whenever
   read_file_name is called */
int ns_use_open_panel;

/* Under NS, nonzero means that ns_yes_or_no_p is executed whenever
   yes_or_no_p or y_or_n_p are called */
int ns_use_yes_no_panel;

Lisp_Object ns_alternate_is_meta,ns_iso_latin,ns_cursor_blink_rate,ns_shrink_space;
NSArray *ns_send_types=0,*ns_return_types=0,*ns_drag_types=0;

/* This is a chain of structures for all the NS displays currently in use.  */
struct ns_display_info *ns_display_list;

Lisp_Object ns_display_name_list;

struct frame *ns_highlight_frame = 0;
struct frame *ns_focus_frame = 0;
struct frame *ns_focus_event_frame = 0;

static BOOL send_appdefined = NO;
static NSEvent *last_appdefined_event;
static NSTimer *timed_entry = 0;
static NSTimer *cursor_blink_entry = 0;
static fd_set *select_readfds = 0;
static fd_set *select_writefds = 0;
static fd_set *select_exceptfds = 0;
static int select_nfds;
static int lockfocused=0;
static int ns_window_num=0;

extern void x_free_frame_menubar ();

static void ns_frame_rehighlight(struct frame *f);
static void ns_adjust_size(struct frame *f);
static void redraw_previous_char ();
static void redraw_following_char ();
static void note_mouse_movement (struct frame *frame, int x, int y);
static void note_mouse_highlight (struct frame *frame, int x, int y);
static int fast_find_position ();
static void clear_mouse_face ();
static void show_mouse_face ();

static NSRect last_mouse_glyph;
static unsigned long last_mouse_movement_time;
static struct frame *last_mouse_frame = 0;
static int mouse_face_beg_row, mouse_face_beg_col;
static int mouse_face_end_row, mouse_face_end_col;
static int mouse_face_past_end;
static Lisp_Object mouse_face_window;
static int mouse_face_face_id;
static FRAME_PTR mouse_face_mouse_frame;
static int mouse_face_mouse_x, mouse_face_mouse_y;
static int mouse_face_defer;
static int mouse_face_deferred_gc;
static int disable_mouse_highlight;
static NSRect mouse_face_mouse_rect;
static int mouse_face_mouse_row;
static id mouse_face_tracked_view;

/* Number of event we should fake in `getNextEvent:waitFor:threshold:'. */
BOOL fake_event_p;
NSEvent *fake_event;

/* Convert modifiers in a NeXTSTEP event to emacs style modifiers.  */
#define EV_MODIFIERS(e) \
((([e modifierFlags] & NSHelpKeyMask) ? hyper_modifier : 0) \
 |((EQ(ns_alternate_is_meta,Qt) && ([e modifierFlags] & NSAlternateKeyMask)) ? meta_modifier:0) \
 |((EQ(ns_alternate_is_meta,Qleft) && ([e modifierFlags] & NSAlternateKeyMask) && ([e modifierFlags] & NSAlternateKeyMask)) ? meta_modifier:0) \
 |((EQ(ns_alternate_is_meta,Qright) && ([e modifierFlags] & NSAlternateKeyMask) && ([e modifierFlags] & NSAlternateKeyMask)) ? meta_modifier:0) \
 |(([e modifierFlags] & NSShiftKeyMask) ? shift_modifier:0) \
 |(([e modifierFlags] & NSControlKeyMask) ? ctrl_modifier:0) \
 |(([e modifierFlags] & NSCommandKeyMask) ? super_modifier:0))

#define EV_UDMODIFIERS(e) \
((([e type] == NSLeftMouseDown) ? down_modifier : 0) \
 |(([e type] == NSRightMouseDown) ? down_modifier : 0) \
 |(([e type] == NSLeftMouseDragged) ? down_modifier : 0) \
 |(([e type] == NSRightMouseDragged) ? down_modifier : 0) \
 |(([e type] == NSLeftMouseUp)   ? up_modifier   : 0) \
 |(([e type] == NSRightMouseUp)   ? up_modifier   : 0))

#define EV_BUTTON(e) \
((([e type] == NSLeftMouseDown) || ([e type] == NSLeftMouseUp)) ? 0 : \
 (([e type] == NSRightMouseDown) || ([e type] == NSRightMouseUp)) ? 1 : 2)

/* Convert the time field in a NeXTSTEP event to a timestap in milliseconds.
   XXX this is not portable to non NeXT NeXTSTEP systems yet.
   1000/68=250/17.  Avoid over/underflow */
#define EV_TIMESTAMP(e) (([e timestamp]/17)*250)

/* This is a piece of code which is common to all the event handeling
   methods.  Maybe it should even be a function.  */
#define EV_TRAILER(e)    \
  { \
  XSETFRAME (events->frame_or_window, emacsframe); \
  events->timestamp = EV_TIMESTAMP (e); \
  events++; \
  eventsleft--; \
  if (send_appdefined) ns_send_appdefined (-1); \
  }

static int curs_x,curs_y,flexlines,highlight;

static struct input_event *events=0;
static int eventsleft=0;

extern struct frame *updating_frame;

static int keytypeno=0;
static unsigned char *keytypes=0;
static unsigned char **keycode=0;
unsigned char *ns2isomap=0;
unsigned char *iso2nsmap=0;

// enable this to make the tracking rects used for mouse-face
// highlighting visible
#if 0
NSRect trackrec;
#define TRACKREC(r, v) {NSRect s=r; [v lockFocus]; NSHighlightRect(s); \
  s.size.width-=2; s.size.height-=2; s.origin.x+=1; s.origin.y+=1; \
  NSHighlightRect(s); trackrec=r; [v unlockFocus]; \
  [[v window] flushWindow];}
#else
#define TRACKREC(r, v)
#endif

void *ns_alloc_autorelease_pool()
{
  return [[NSAutoreleasePool alloc] init];
}

void ns_release_autorelease_pool(void *pool)
{
  [(NSAutoreleasePool *)pool release];
}


static void keymap_init(void)
   {
   unsigned char *mapping;

   [NSDPSServerContext setDeadKeyProcessingEnabled:NILP(ns_alternate_is_meta)];

      {
      NXEventHandle handle=NXOpenEventStatus();
      NXKeyMapping map;

      if (!handle)
         error ("NXOpenEventStatus: %s", strerror (errno));

      map.size = NXKeyMappingLength(handle);
      map.mapping = (char *) xmalloc(map.size);
      if (!NXGetKeyMapping(handle,&map))
         error ("NXGetKeyMapping: %s", strerror (errno));

      NXCloseEventStatus(handle);
      if ((map.mapping[0]!=0) || (map.mapping[1]!=0))
         error ("Unknown keyboard map format.");

      mapping=(unsigned char *)(map.mapping+2);
      }

      {
      int i;
      keytypeno=*mapping++;
      keytypes=mapping;
      for(i=0;i<keytypeno;i++)
         mapping+=2+mapping[1];
      }

      {
      int kc;
      int kcs = *mapping++;

      keycode=(unsigned char **) xmalloc(sizeof(*keycode)*kcs);

      for(kc=0;kc<kcs;kc++)
         {
         char mask;
         keycode[kc]=mapping;

         if ((mask=*mapping++)!=-1)
            {
            int i=2;
            while(mask)
               {
               if (mask&0x1) i<<=1;
               mask>>=1;
               }
            mapping+=i;
            }
         }
      }

      {
      float tmp[256];
      int n;

      ns2isomap=(void *) xmalloc(sizeof(*ns2isomap)*256);
      nswrap_transtable("NextStepEncoding","ISOLatin1Encoding",tmp);
      for (n=0;n<256;n++) ns2isomap[n]=tmp[n] ? tmp[n] : n;
      /* Unfortunately this hack is necessary due to a bug
         in either NextStepEncoding or ISOLatin1Encoding */
      ns2isomap[(unsigned char) '-']=(unsigned char)'-';

      iso2nsmap=(void *) xmalloc(sizeof(*iso2nsmap)*256);
      nswrap_transtable("ISOLatin1Encoding","NextStepEncoding",tmp);
      for (n=0;n<256;n++) iso2nsmap[n]=tmp[n] ? tmp[n] : n;
      /* Unfortunately this hack is necessary due to a bug
         in either NextStepEncoding or ISOLatin1Encoding */
      iso2nsmap[(unsigned char) '-']=(unsigned char)'-';
      }
   }

static unsigned short char_from_key(unsigned short kc,int mod)
   {
   unsigned char *map=keycode[kc];
   int pos=0;

   if (map[0]&0x40) pos=(pos<<1) + ((mod&NSHelpKeyMask)!=0);
   if (map[0]&0x20) pos=(pos<<1) + ((mod&NSNumericPadKeyMask)!=0);
   if (map[0]&0x10) pos=(pos<<1) + ((mod&NSCommandKeyMask)!=0);
   if (map[0]&0x08) pos=(pos<<1) + ((mod&NSAlternateKeyMask)!=0);
   if (map[0]&0x04) pos=(pos<<1) + ((mod&NSControlKeyMask)!=0);
   if (map[0]&0x02) pos=(pos<<1) + ((mod&NSShiftKeyMask)!=0);
   if (map[0]&0x01) pos=(pos<<1) + ((mod&NSAlphaShiftKeyMask)!=0);

   return /* (map[1+pos*2]<<8) + */ map[2+pos*2];
   }

static BOOL char_is_type(unsigned short kc,int mod)
   {
   unsigned char *m,*n;
   int t,i;
   for(mod >>= 16,t=-1;mod;t++,mod>>=1);
   if (t==-1) return NO;
   for(i=0,m=keytypes;i<keytypeno;i++,m+=2+m[1])
      if (m[0]==t) break;
   if (i>=keytypeno) return NO;
   for(i=0,n=m+2;n<m+2+m[1];n++) if (*n==kc) return YES;
   return NO;
   }

void ns_chars_to_rect(struct frame *f,int x1,int y1,int x2,int y2, NSRect *r)
   {
   r->origin.x=x1*FONT_WIDTH(f->output_data.ns->font);
   r->origin.y=y1*f->output_data.ns->line_height;
   r->size.width=(x2-x1+1)*FONT_WIDTH(f->output_data.ns->font);
   r->size.height=(y2-y1+1)*f->output_data.ns->line_height;
   }

/* Given a pixel position P on the frame F, return glyph co-ordinates in
   (*X, *Y). */
void pixel_to_glyph_coords (struct frame *f, int px, int py,
                               int *x, int *y, void *bounds, int noclip)
   {
   *x=(FONT_WIDTH(f->output_data.ns->font) <=0)
     ? 0 : floor(((float)px) / FONT_WIDTH(f->output_data.ns->font));
   *y=(f->output_data.ns->line_height<=0)
            ? 0 : floor(((float)py) / f->output_data.ns->line_height);

   if (bounds)
      abort();

   if (!noclip)
      {
      *x = BOUND(0,*x,f->width);
      *y = BOUND(0,*y,f->height);
      }
   }

void glyph_to_pixel_coords(struct frame *f,int x,int y,int *pix_x,int *pix_y)
   {
   *pix_x=(int)rint(x*FONT_WIDTH(f->output_data.ns->font));
   *pix_y=(int)rint(y*f->output_data.ns->line_height);
   }

static void ns_rect_to_glyph_coords(struct frame *f, NSRect *r,int maximize,
                                     int *x, int *y, int *cols, int *rows)
   {
   if (FONT_WIDTH(f->output_data.ns->font)<=0)
      {
      *x=0;
      *cols=f->width;
      }
   else if (maximize)
      {
      *x=floor(r->origin.x/FONT_WIDTH(f->output_data.ns->font)+0.001);
      *cols=ceil((r->origin.x+r->size.width)/FONT_WIDTH(f->output_data.ns->font)-0.001);
      }
   else
      {
	int vbextra = f->output_data.ns->vertical_scroll_bar_extra
	  = (!FRAME_HAS_VERTICAL_SCROLL_BARS (f)
	     ? 0
	     : FRAME_SCROLL_BAR_PIXEL_WIDTH (f) > 0
	     ? FRAME_SCROLL_BAR_PIXEL_WIDTH (f)
	     : (FRAME_SCROLL_BAR_COLS(f) * 
		FONT_WIDTH(f->output_data.ns->font)));

      *x=ceil(r->origin.x/FONT_WIDTH(f->output_data.ns->font)-0.001);
      *cols=floor(((r->origin.x+r->size.width)-vbextra)/FONT_WIDTH(f->output_data.ns->font)+0.001);
      }

   if (f->output_data.ns->line_height<=0)
      {
      *y=0;
      *rows=f->height;
      }
   else if (maximize)
      {
      *y=floor(r->origin.y/f->output_data.ns->line_height+0.001);
      *rows=ceil((r->origin.y+r->size.height)/f->output_data.ns->line_height-0.001);
      }
   else
      {
      *y=ceil(r->origin.y/f->output_data.ns->line_height-0.001);
      *rows=floor((r->origin.y+r->size.height)/f->output_data.ns->line_height+0.001);
      }

   *cols=*cols-*x;
   *rows=*rows-*y;
   }

void ns_focus_on_frame (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
/*   [[view window] makeKeyAndOrderFront:NXApp]; */
   }

void ns_unfocus_frame (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
/*   [[view window] orderBack:NXApp]; */ /* XXX unfocus ! */
   }

void ns_raise_frame (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
   [[view window] orderFront:NSApp];
   }

void ns_lower_frame (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
   [[view window] orderBack:NSApp];
   }

void x_make_frame_visible (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
//   [[view window] orderFront:NSApp];
   [[view window] makeKeyAndOrderFront:NSApp];
   }

void x_make_frame_invisible (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
   [[view window] orderOut:NSApp];
   }

void x_iconify_frame (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
   if ([[view window] windowNumber] <= 0)
     {
       // the window is still deferred.  Make it very small, bring it
       // on screen and order it out.
       NSRect s = {100, 100, 0, 0};
       NSRect t;
       t = [[view window] frame];
       [[view window] setFrame:s display:NO];
       [[view window] orderBack:NSApp];
       [[view window] orderOut:NSApp];
       [[view window] setFrame:t display:NO];
     }
   [[view window] miniaturize:NSApp];
   }

void x_destroy_window (struct frame *f)
   {
   id view=f->output_data.ns->view;
   check_ns();
   if (f==ns_focus_frame)
      ns_focus_frame=0;
   if (f==ns_highlight_frame)
      ns_highlight_frame=0;
   if (f == mouse_face_mouse_frame)
      {
      mouse_face_beg_row = mouse_face_beg_col = -1;
      mouse_face_end_row = mouse_face_end_col = -1;
      mouse_face_window = Qnil;
      }
   if (view == mouse_face_tracked_view)
     mouse_face_tracked_view = nil;
//   xfree (f->output_data.ns->face);
   xfree (f->output_data.ns);
   [[view window] close];
   ns_window_num--;

#if 0
      {
      Lisp_Object rest;
      struct frame *f;
      
      for (rest=Vframe_list; CONSP(rest); rest=XCONS(rest)->cdr)
         if (FRAME_NS_P(f=XFRAME(XCONS(rest)->car)))
            [[f->output_data.ns->view window] setCloseButton:NSApp to:(ns_window_num>1)];
      }
#endif
   }

int ns_get_color (const char *name, NSColor **col)
   {
   NSColor * new = nil;
   unsigned int t1,t2;
   const char *c;
   NSString *nsname = [NSString stringWithCString:name];
   
   if (name[0]=='R' && name[1]=='G' && name[2]=='B')
      {
      for(t1=t2=0,c=name+3;1;c++)
         {
         if (*c>='0' && *c<='9')      t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-'0';
         else if (*c>='a' && *c<='f') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('a'-10);
         else if (*c>='A' && *c<='F') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('A'-10);
         else break;
         }
      if ((*c=='\0') && (t2==0))
         {
         *col=[NSColor colorWithCalibratedRed:((t1>>24)&0xff)/255.0 green:((t1>>16)&0xff)/255.0 blue:((t1>> 8)&0xff)/255.0 alpha:(t1&0xff)/255.0];
         return 0;
         }
      }

   if (name[0]=='H' && name[1]=='S' && name[2]=='B')
      {
      for(t1=t2=0,c=name+3;1;c++)
         {
         if (*c>='0' && *c<='9')      t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-'0';
         else if (*c>='a' && *c<='f') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('a'-10);
         else if (*c>='A' && *c<='F') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('A'-10);
         else break;
         }
      if ((*c=='\0') && (t2==0))
         {
         *col=[NSColor colorWithCalibratedHue:((t1>>24)&0xff)/255.0 saturation:((t1>>16)&0xff)/255.0 brightness:((t1>> 8)&0xff)/255.0 alpha:(t1&0xff)/255.0];
         return 0;
         }
      }

   if (name[0]=='G' && name[1]=='R' && name[2]=='A' && name[3]=='Y')
      {
      for(t1=t2=0,c=name+4;1;c++)
         {
         if (*c>='0' && *c<='9')      t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-'0';
         else if (*c>='a' && *c<='f') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('a'-10);
         else if (*c>='A' && *c<='F') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('A'-10);
         else break;
         }
      if ((*c=='\0') && (t1>>16==0) && (t2==0))
         {
         *col=[NSColor colorWithCalibratedWhite:((t1>>8)&0xff)/255.0 alpha:(t1&0xff)/255.0];
         return 0;
         }
      }

   if (name[0]=='C' && name[1]=='M' && name[2]=='Y' && name[3]=='K')
      {
      for(t1=t2=0,c=name+4;1;c++)
         {
         if (*c>='0' && *c<='9')      t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-'0';
         else if (*c>='a' && *c<='f') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('a'-10);
         else if (*c>='A' && *c<='F') t2=16*t2+((t1>>28)&0xff),t1=16*t1+*c-('A'-10);
         else break;
         }
      if ((*c=='\0') && (t2>>8==0))
         {
         *col=[NSColor colorWithDeviceCyan:(t2&0xff)/255.0 magenta:((t1>>24)&0xff)/255.0 yellow:((t1>>16)&0xff)/255.0 black:((t1>> 8)&0xff)/255.0 alpha:(t1&0xff)/255.0];
         return 0;
         }
      }

   
   {
     NSEnumerator *lenum, *cenum;
     NSString *name;
     NSColorList *clist;

     lenum = [[NSColorList availableColorLists] objectEnumerator];
     while ( (clist = [lenum nextObject]) && new == nil ) {
       cenum = [[clist allKeys] objectEnumerator];
       while ( (name = [cenum nextObject]) && new == nil ) {
	 if ( [name compare:nsname options:NSCaseInsensitiveSearch]
	      == NSOrderedSame ) {
	   new = [clist colorWithKey:name];
	 }
       }
     }
   }

   if ( new )
     *col=new;
   return new ? 0 : 1;
   }

NSColor * ns_get_color_default (const char *name, NSColor *dflt)
   {
   NSColor * col;

   if (ns_get_color(name, &col))
      return dflt;
   else
      return col;
   }

int ns_lisp_to_color (Lisp_Object color, NSColor **col)
   {
   if (XTYPE(color) == Lisp_String)
      return ns_get_color (XSTRING(color)->data, col);
   else if (XTYPE(color) == Lisp_Symbol)
      return ns_get_color (XSYMBOL(color)->name->data, col);
   return 1;
   }

Lisp_Object ns_color_to_lisp (NSColor * col)
   {
   float red,green,blue,alpha,gray;
   char buf[1024];
   const char *str;

   if (str=[[col colorNameComponent] cString])
      return build_string((char *)str);
   
   [[col colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:&alpha];
   if (red==green && red==blue)
      {
      [[col colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] getWhite:&gray alpha:&alpha];
      sprintf(buf,"GRAY%02.2x%02.2x",(int)rint(gray*0xff),(int)rint(alpha*0xff));
      return build_string(buf);
      }

   sprintf(buf,"RGB%02.2x%02.2x%02.2x%02.2x",(int)rint(red*0xff),
           (int)rint(green*0xff),(int)rint(blue*0xff),(int)rint(alpha*0xff));
   return build_string(buf);
   }

/* If hl==-1, write out buffer unconditionally
      hl== 0, add glyphs described by glyphs, len
      hl== 1, add glyphs described by glyphs, len in face=1
      hl== 2, clear region described by len, x, y
      hl== 3, add glyphs described by glyphs, len in face=mouse_face_face_id */

void ns_dumpglyphs(struct frame *nf,int x,int y, GLYPH *glyphs,int len,int hl)
   {
   static int faceid=-1,no=0;
   static struct frame *f=0;
   static NSRect r[256];
   static unsigned int l[256];
   static unsigned char *t[256];
   static unsigned char buf[4096];
   static unsigned char *p=buf;
   int tlen = GLYPH_TABLE_LENGTH;
   Lisp_Object *tbase = GLYPH_TABLE_BASE;
   int nfaceid,g;

 start:
   switch(hl)
      {
    case -1:
      if (no==0) return;
      nfaceid=-1;
      break;
    case 0:
      g=*glyphs;
      GLYPH_FOLLOW_ALIASES (GLYPH_TABLE_BASE, GLYPH_TABLE_LENGTH, g);
      nfaceid=FAST_GLYPH_FACE(g);
      break;
    case 1:
      nfaceid=1;
      break;
    case 2:
      nfaceid=0;
      break;
    case 3:
      nfaceid=mouse_face_face_id;
      break;
      }

   if ((no>0)&&
       ((nf!=f) || (nfaceid!=faceid) || (no>=sizeof(t)/sizeof(t[0])) ||
        (p+len-buf>=sizeof(buf)/sizeof(buf[0]))))
      {
      id view=f->output_data.ns->view;
      int i;
      struct face *face;

      face=f->output_data.ns->computed_faces[((faceid<-1)||
                                          (faceid>=f->output_data.ns->n_computed_faces)||
                                          (f->output_data.ns->computed_faces[faceid]==0))
                                         ? 0 : faceid];

      if (f!=updating_frame || !lockfocused)
         {
         [view lockFocus];
         if (f==updating_frame) lockfocused=1;
         }

      [NS_FACE_BACKGROUND(face) set];
      if (! face->stipple)
        {
          NSRectFillList(r,no);
        }
      else
        {
          NSPoint p;
          NSRect s;
          int minx = NSMinX(r[0]);
          int miny = NSMinY(r[0]);
          int maxx = NSMaxX(r[0]);
          int maxy = NSMaxY(r[0]);
          id stipple = [face->stipple stippleRep];

          for (i = 1; i < no; i++)
            if (l[i] > 0)
              {
                int t;
                if ((t = NSMinX(r[i])) < minx) minx = t;
                if ((t = NSMinY(r[i])) < miny) miny = t;
                if ((t = NSMaxX(r[i])) > maxx) maxx = t;
                if ((t = NSMaxY(r[i])) > maxy) maxy = t;
              }

          s = NSMakeRect(minx, miny, maxx - minx, maxy - miny);
          
          miny += face->pixmap_h;  // view is flipped
          maxy += face->pixmap_h;
          minx -= minx % face->pixmap_w;  // align with previous stipples
          miny -= miny % face->pixmap_h;

          NSRectClipList(r , no);
          if ([[stipple bestRepresentationForDevice:nil] hasAlpha])
            {
              NSRectFill(s);
              for (p.y = miny; p.y <= maxy; p.y += face->pixmap_h)
                for (p.x = minx; p.x <= maxx; p.x += face->pixmap_w)
                  [stipple compositeToPoint:p operation:NSCompositeSourceOver];
            }
          else
            {
             for (p.y = miny; p.y <= maxy; p.y += face->pixmap_h)
                for (p.x = minx; p.x <= maxx; p.x += face->pixmap_w)
                  [stipple compositeToPoint:p operation:NSCompositeCopy];
            } 
          PSinitclip ();
        }
      [NS_FACE_FOREGROUND(face) set];
      if (face->font->nsfont==0) ns_load_font(face);
      [face->font->nsfont set];
      for(i=0;i<no;i++) if (l[i]>0)
         nswrap_moveshow(r[i].origin.x,r[i].origin.y+f->output_data.ns->line_height
                         -face->font->descender,t[i],l[i]);
      if (face->underline)
         {
         PSsetlinewidth(face->font->underwidth);
         for(i=0;i<no;i++) if (l[i]>0)
            nswrap_moveline(r[i].origin.x,
                            r[i].origin.y+f->output_data.ns->line_height
                            -face->font->underpos,floor(r[i].size.width-1));
         PSstroke();
         }
      if (f!=updating_frame)
         {
         [view unlockFocus];
         [[view window] flushWindow];
         PSFlush();
         }
      no=0;
      }

   if (no==0)
      {
      p=buf;
      faceid=nfaceid;
      f=nf;
      }

   switch(hl)
      {
    case -1:
      break;
    case  0:
      for(t[no]=p;(len>0);len--)
         {
         g=*glyphs;
         GLYPH_FOLLOW_ALIASES (GLYPH_TABLE_BASE, GLYPH_TABLE_LENGTH, g);
         if (FAST_GLYPH_FACE(g)!=nfaceid) break;
         *p=FAST_GLYPH_CHAR(g); glyphs++;   // FIXME/cl was *glyphs++ ???
         if (!NILP(ns_iso_latin)) *p=iso2nsmap[*p];
         p++;
         }
      ns_chars_to_rect(f,x,y,x+(p-t[no])-1,y,&r[no]);
      l[no]=p-t[no];
      x+=l[no];
      no++;
      break;
    case 1:
      for(t[no]=p;len>0;len--)
         {
         g=*glyphs;
         GLYPH_FOLLOW_ALIASES (GLYPH_TABLE_BASE, GLYPH_TABLE_LENGTH, g);
         *p=FAST_GLYPH_CHAR(g); glyphs++;
         if (!NILP(ns_iso_latin)) *p=iso2nsmap[*p];
         p++;
         }
      ns_chars_to_rect(f,x,y,x+(p-t[no])-1,y,&r[no]);
      l[no]=p-t[no];
      x+=l[no];
      no++;
      break;
    case 2:
      ns_chars_to_rect(f,x,y,x+len-1,y,&r[no]);
      t[no]=p;
      l[no]=0;
      len=0;
      no++;
      break;
    case 3:
      for(t[no]=p;len>0;len--)
         {
         g=*glyphs;
         GLYPH_FOLLOW_ALIASES (GLYPH_TABLE_BASE, GLYPH_TABLE_LENGTH, g);
         *p=FAST_GLYPH_CHAR(g); glyphs++;
         if (!NILP(ns_iso_latin)) *p=iso2nsmap[*p];
         p++;
         }
      ns_chars_to_rect(f,x,y,x+(p-t[no])-1,y,&r[no]);
      l[no]=p-t[no];
      x+=l[no];
      no++;
      break;
      }

   if (len>0) goto start;
   }

void ns_dumpcursor(struct frame *f,int nx,int ny)
   {
   NSRect r,s;
   id view=f->output_data.ns->view;

   if (f->phys_cursor_x==nx && f->phys_cursor_y == ny &&
       f->output_data.ns->current_cursor==f->output_data.ns->desired_cursor &&
       [f->output_data.ns->current_cursor_color isEqual:f->output_data.ns->desired_cursor_color])
      return;

   if (f!=updating_frame || !lockfocused)
      {
      [view lockFocus];
      if (f==updating_frame) lockfocused=1;
      }

   if (f->phys_cursor_x >= 0 && f->phys_cursor_x < f->width &&
       f->phys_cursor_y >= 0 && f->phys_cursor_y < f->height)
      {
      ns_chars_to_rect(f,f->phys_cursor_x,f->phys_cursor_y,
                       f->phys_cursor_x,f->phys_cursor_y,&r);
      if ([f->output_data.ns->current_cursor_color isEqual:[NSColor clearColor]])
         {
         switch(f->output_data.ns->current_cursor)
            {
          case no_highlight:
            break;
          case filled_box:
            NSHighlightRect(r);
            break;
          case hollow_box:
            s=r;
            NSHighlightRect(s);
            s.size.width-=2;
            s.size.height-=2;
            s.origin.x+=1;
            s.origin.y+=1;
            NSHighlightRect(s);
            break;
          case bar:
            s=r;
            s.origin.y += 0.75 * s.size.height;
            s.size.height *= 0.25;
            NSHighlightRect(s);
            break;
          case line:
            s=r;
            s.size.width = 2;
            NSHighlightRect(s);
            break;
            }
         }
      else
         {
         struct face *face=f->output_data.ns->computed_faces[FAST_GLYPH_FACE(f->phys_cursor_glyph)];
         unsigned char c=FAST_GLYPH_CHAR(f->phys_cursor_glyph);

	 if (face->font->nsfont==0) /** no font yet **/
	   return;


         [NS_FACE_BACKGROUND(face) set];
         if (! face->stipple)
           {
             NSRectFill(r);
           }
         else
           {
             NSPoint p;
             int minx = NSMinX(r);
             int miny = NSMinY(r) + face->pixmap_h;
             int maxx = NSMaxX(r);
             int maxy = NSMaxY(r) + face->pixmap_h;
             id stipple = [face->stipple stippleRep];

             minx -= minx % face->pixmap_w;  // align with previous stipples
             miny -= miny % face->pixmap_h;

             NSRectClip(r);
             // unfortunately we have to stipple here because it's not
             // guaranteed, that the cursor is not on an edge
             if ([[stipple bestRepresentationForDevice:nil] hasAlpha])
               {
                 NSRectFill(r);
                 for (p.y = miny; p.y <= maxy; p.y += face->pixmap_h)
                   for (p.x = minx; p.x <= maxx; p.x += face->pixmap_w)
                     [stipple compositeToPoint:p operation:NSCompositeSourceOver];
               }
             else
               {
                 for (p.y = miny; p.y <= maxy; p.y += face->pixmap_h)
                   for (p.x = minx; p.x <= maxx; p.x += face->pixmap_w)
                     [stipple compositeToPoint:p operation:NSCompositeCopy];
               }
             PSinitclip ();
           }
         [NS_FACE_FOREGROUND(face) set];
         if (face->font->nsfont==0) ns_load_font(face);
         [face->font->nsfont set];
         if (!NILP(ns_iso_latin)) c=iso2nsmap[c];
         nswrap_moveshow(r.origin.x,r.origin.y+f->output_data.ns->line_height
                         -face->font->descender,&c,1);
         if (face->underline)
            {
            PSsetlinewidth(face->font->underwidth);
            nswrap_moveline(r.origin.x,r.origin.y+f->output_data.ns->line_height
                            -face->font->underpos,r.size.width-1);
            PSstroke();
            }
         }
      }

   f->phys_cursor_x = nx;
   f->phys_cursor_y = ny;
   f->output_data.ns->current_cursor = f->output_data.ns->desired_cursor;
   f->output_data.ns->current_cursor_color = f->output_data.ns->desired_cursor_color;

   if (f->phys_cursor_x >= 0 && f->phys_cursor_x < f->width &&
       f->phys_cursor_y >= 0 && f->phys_cursor_y < f->height)
      {
      ns_chars_to_rect(f,f->phys_cursor_x,f->phys_cursor_y,
                       f->phys_cursor_x,f->phys_cursor_y,&r);
      if ([f->output_data.ns->current_cursor_color isEqual:[NSColor clearColor]])
         {
         switch(f->output_data.ns->current_cursor)
            {
          case no_highlight:
            break;
          case filled_box:
            NSHighlightRect(r);
            break;
          case hollow_box:
            s=r;
            NSHighlightRect(s);
            s.size.width-=2;
            s.size.height-=2;
            s.origin.x+=1;
            s.origin.y+=1;
            NSHighlightRect(s);
            break;
          case bar:
            s=r;
            s.origin.y += 0.75 * s.size.height;
            s.size.height *= 0.25;
            NSHighlightRect(s);
            break;
          case line:
            s=r;
            s.size.width = 2;
            NSHighlightRect(s);
            break;
            }
         }
      else
         {
         struct frame_glyphs *current_glyphs = FRAME_CURRENT_GLYPHS (f);
         struct face *face;
         unsigned char c;

         f->phys_cursor_glyph
            = ((current_glyphs->enable[f->phys_cursor_y]
                && f->phys_cursor_x < current_glyphs->used[f->phys_cursor_y])
               ? current_glyphs->glyphs[f->phys_cursor_y][f->phys_cursor_x]
               : SPACEGLYPH);
         face=f->output_data.ns->computed_faces[FAST_GLYPH_FACE(f->phys_cursor_glyph)];
         c=FAST_GLYPH_CHAR(f->phys_cursor_glyph);

         [NS_FACE_BACKGROUND(face) set];
         NSRectFill(r);
         [f->output_data.ns->current_cursor_color set];
         switch(f->output_data.ns->current_cursor)
            {
          case no_highlight:
            break;
          case filled_box:
            NSRectFill(r);
            break;
          case hollow_box:
            NSFrameRect(r);
            break;
          case bar:
            s=r;
            s.origin.y += 0.75 * s.size.height;
            s.size.height *= 0.25;
            NSRectFill(s);
            break;
          case line:
            s=r;
            s.size.width = 2;
            NSRectFill(s);
            break;
            }
	 if ([f->output_data.ns->current_cursor_color isEqual:NS_FACE_FOREGROUND(face)])
            [NS_FACE_BACKGROUND(face) set];
	 else
            [NS_FACE_FOREGROUND(face) set];

         if (face->font->nsfont==0) ns_load_font(f, face);
         [face->font->nsfont set];

         if (!NILP(ns_iso_latin)) c=iso2nsmap[c];
         nswrap_moveshow(r.origin.x,r.origin.y+f->output_data.ns->line_height
                         -face->font->descender,&c,1);
         if (face->underline)
            {
            PSsetlinewidth(face->font->underwidth);
            nswrap_moveline(r.origin.x,r.origin.y+f->output_data.ns->line_height
                            -face->font->underpos,r.size.width-1);
            PSstroke();
            }
         }
      }

   if (f!=updating_frame)
      {
      [view unlockFocus];
      [[view window] flushWindow];
      PSFlush();
      }
   }

static int ns_cursor_to(int row, int col)
   {
   struct frame *f=(updating_frame ? updating_frame : selected_frame);
   id view=f->output_data.ns->view;

   curs_x = col;
   curs_y = row;

   if (f!=updating_frame)
      {
      ns_dumpglyphs(f,0,0,0,0,-1);
      ns_dumpcursor(f,curs_x,curs_y);
      }

   return 0;
   }

void x_set_offset (struct frame *f, int xoff, int yoff, int change_grav)
   {
   NSScreen *screen;
   id view=f->output_data.ns->view;
   f->output_data.ns->left=xoff;
   f->output_data.ns->top=yoff;
   if (view != nil && (screen=[[view window] screen])!=0)
      [[view window] setFrameTopLeftPoint:NSMakePoint(SCREENMAXBOUND(f->output_data.ns->left), SCREENMAXBOUND([screen frame].size.height-
                          f->output_data.ns->top))];
   }


static void ns_reset_clip(id view)
   {
   int i;
   NSArray *sv;
   NSView *v;
   NSRect r,s;

   if ( [[view  window] windowNumber] > 0 )
	 [view lockFocus];
   PSinitclip();
   PSnewpath();
   r = [view bounds];
   nswrap_rect(r.origin.x,r.origin.y,r.size.width,r.size.height);

   if (sv = [[view superview] subviews]) for(i=[sv count]-1;i>=0;i--)
      {
      v=[sv objectAtIndex:i];
      if (v==view) continue;
      s = [v frame];
      [view convertRect:s fromView:[view superview]];
      if (NSIsEmptyRect(s = NSIntersectionRect(r , s))) continue;
      if (s.origin.y==0)
         {
         s.origin.y-=1;
         s.size.height+=1;
         }
      nswrap_rect_rev(s.origin.x,s.origin.y,s.size.width,s.size.height);
      }

   PSclip();
   PSnewpath();
   PSgstate();
   DPSDefineUserObject([view gState]);
   if ( [[view  window] windowNumber] > 0 )
	 [view unlockFocus];
   }

void ns_set_mouse_tracking (id view)
{
  NSRect r;
  if (mouse_face_tracked_view && mouse_face_tracked_view != view)
    {
      TRACKREC (trackrec, mouse_face_tracked_view);
      [mouse_face_tracked_view removeTrackingRect:MOUSE_FACE_TRACKNUM];
    }
  r = mouse_face_mouse_rect;
  TRACKREC (r, view);
  [view convertRect:r toView:nil];
  MOUSE_FACE_TRACKNUM = [view addTrackingRect:r owner:view userData:nil assumeInside:YES];
  mouse_face_tracked_view = view;
}

void ns_remove_mouse_tracking ()
{
  if (mouse_face_tracked_view)
    {
      TRACKREC (trackrec, mouse_face_tracked_view);
      [mouse_face_tracked_view removeTrackingRect:MOUSE_FACE_TRACKNUM];
      mouse_face_tracked_view = nil;
    }
}

ns_adjust_tracking_rects (struct frame *f)
{
  NSRect r;
  NSView *view=f->output_data.ns->view;
  NSWindow *win=[view window];

  if (view == mouse_face_tracked_view)
    ns_remove_mouse_tracking ();

  r = [view bounds];
  [view convertRect:r toView:nil];
  // set inside to NO: if we are inside, we'll immediately get an
  // event and everything will be ok
  WINDOW_TRACKNUM = [view addTrackingRect:r owner:view userData:nil assumeInside:NO];

  r = [win frame];
  r.origin.x=r.origin.y=0;
  FRAME_TRACKNUM = [view addTrackingRect:r owner:view userData:nil assumeInside:NO];
}

static void ns_adjust_size(struct frame *f)
   {
   int x, y, rows, cols;
   id view=f->output_data.ns->view;
   id win=[view window];
   NSRect r;

   [win invalidateCursorRectsForView:view];

   // don't setup tracking rects as long as the window is deferred
   if ([win windowNumber] > 0)
     ns_adjust_tracking_rects (f);
   
   r = [view bounds];
   ns_reset_clip(view);
   ns_rect_to_glyph_coords(f,&r,0,&x,&y,&cols,&rows);
   change_frame_size (f, rows, cols, 0, 1);
   SET_FRAME_GARBAGED (f);
   }

void x_set_window_size (struct frame *f, int change_grav, int cols, int rows)
   {
   NSView *view=f->output_data.ns->view;
   NSWindow *window;
   NSScreen *screen;
   NSRect r,wr;
   int vbextra;

   if (view!=nil && [[view window] windowNumber] > 0)
      {
      window=[view window];
      screen=[window screen];
      r = [view frame];
      wr = [window frame];

      ns_dumpcursor(f,-1,-1);

      vbextra = f->output_data.ns->vertical_scroll_bar_extra
	= (!FRAME_HAS_VERTICAL_SCROLL_BARS (f)
	   ? 0
	   : FRAME_SCROLL_BAR_PIXEL_WIDTH (f) > 0
	   ? FRAME_SCROLL_BAR_PIXEL_WIDTH (f)
	   : (FRAME_SCROLL_BAR_COLS(f) * FONT_WIDTH(f->output_data.ns->font)));

      r.origin.x=f->output_data.ns->internal_border_width;
      r.origin.y=f->output_data.ns->internal_border_width;
      r.size.width = (FONT_WIDTH(f->output_data.ns->font) * cols) + vbextra; 
      r.size.height=f->output_data.ns->line_height * rows;

      wr.size.width = r.size.width  
	+ f->output_data.ns->internal_border_width*2
+ f->output_data.ns->border_width;// +vbextra;
      wr.size.height = r.size.height
	+ f->output_data.ns->internal_border_width*2
	+ f->output_data.ns->border_height;

      [view setFrame:r];

      if (screen)
         {
         wr.origin.x=f->output_data.ns->left;
         wr.origin.y=[screen frame].size.height-(f->output_data.ns->top
                                                       +wr.size.height);
         }

      wr.origin.x=BOUND(-SCREENMAX,wr.origin.x,SCREENMAX);
      wr.origin.y=BOUND(-SCREENMAX,wr.origin.y,SCREENMAX);
      [window setFrame:wr display:NO];

      ns_adjust_size(f);
#if 0
      r.origin.x=f->output_data.ns->internal_border_width;
      r.origin.y=f->output_data.ns->internal_border_width;
      r.size.width =wr.size.width -(f->output_data.ns->internal_border_width*2+
                                    f->output_data.ns->border_width) - vbextra;
      r.size.height=wr.size.height-(f->output_data.ns->internal_border_width*2+
                                    f->output_data.ns->border_height);
      [view setFrame:r];

      wr.size.width +=cols*FONT_WIDTH(f->output_data.ns->font)-r.size.width;
      wr.size.height+=rows*f->output_data.ns->line_height-r.size.height;

      if (screen)
         {
         wr.origin.x=f->output_data.ns->left;
         wr.origin.y=[screen frame].size.height-(f->output_data.ns->top
                                                       +wr.size.height);
         }

      wr.origin.x=BOUND(-SCREENMAX,wr.origin.x,SCREENMAX);
      wr.origin.y=BOUND(-SCREENMAX,wr.origin.y,SCREENMAX);
      [window setFrame:wr display:NO];

      ns_adjust_size(f);
#endif
      }
   else
      {
      change_frame_size(f, rows, cols, 0, 0);
      SET_FRAME_GARBAGED(f);
      }
   }

void x_set_mouse_pixel_position (struct frame *f, int pix_x, int pix_y)
   {
   id view=f->output_data.ns->view;

   ns_raise_frame(f);
   [view lockFocus];
   PSsetmouse((float)pix_x,(float)pix_y);
   [view unlockFocus];
   PSFlush();
   }

int x_set_mouse_position (struct frame *f, int x, int y)
   {
   NSRect r;

   ns_chars_to_rect(f,x,y,x,y,&r);
   x_set_mouse_pixel_position(f,r.origin.x+r.size.width/2,
                               r.origin.y+r.size.height/2);
   return 0;
   }

static void
note_mouse_movement (struct frame *frame, int x, int y)
{
  /* Has the mouse moved off the glyph it was on at the last sighting?  */
  if ((frame!=last_mouse_frame)||
      (x<last_mouse_glyph.origin.x)||
      (x>=(last_mouse_glyph.origin.x+last_mouse_glyph.size.width))||
      (y<last_mouse_glyph.origin.y)||
      (y>=(last_mouse_glyph.origin.y+last_mouse_glyph.size.height)))
    {
      frame->mouse_moved = 1;
      last_mouse_frame = frame;
      // mouse-faces are updated elsewhere
      // note_mouse_highlight (frame, x, y);
    }
}

/* Take proper action when the mouse has moved to position X, Y on frame F
   as regards highlighting characters that have mouse-face properties.
   Also dehighlighting chars where the mouse was before.  */

static void note_mouse_highlight (struct frame *f, int x, int y)
{
  int row, column, portion;
  Lisp_Object window;
  struct window *w;

  if (disable_mouse_highlight)
    return;

  mouse_face_mouse_x = x;
  mouse_face_mouse_y = y;
  mouse_face_mouse_frame = f;

  /* Find out which glyph the mouse is on.  */
  pixel_to_glyph_coords (f, x, y, &column, &row, 0, 1);

  mouse_face_mouse_row = row;
  // set mouse_face_mouse_rect to cover current glyph for when we're
  // not in a mouse-face
  ns_chars_to_rect (f, column, row, column, row, &mouse_face_mouse_rect);
  
  if (mouse_face_defer)
    return;

  if (gc_in_progress)
    {
      mouse_face_deferred_gc = 1;
      return;
    }

  /* Which window is that in?  */
  window = window_from_coordinates (f, column, row, &portion);
  w = XWINDOW (window);

  /* If we were displaying active text in another window, clear that.  */
  if (! EQ (window, mouse_face_window))
    clear_mouse_face ();

  /* Are we in a window whose display is up to date?
     And verify the buffer's text has not changed.  */
  if (WINDOWP (window) && portion == 0 && row >= 0 && column >= 0
      && row < FRAME_HEIGHT (f) && column < FRAME_WIDTH (f)
      && EQ (w->window_end_valid, w->buffer)
      && w->last_modified == BUF_MODIFF (XBUFFER (w->buffer)))
    {
      int *ptr = FRAME_CURRENT_GLYPHS (f)->charstarts[row];
      int i, pos;

      /* Find which buffer position the mouse corresponds to.  */
      for (i = column; i >= 0; i--)
	if (ptr[i] > 0)
	  break;
      pos = ptr[i];
      /* Is it outside the displayed active region (if any)?  */
      if (pos <= 0)
	clear_mouse_face ();
      else if (! (EQ (window, mouse_face_window)
		  && row >= mouse_face_beg_row
		  && row <= mouse_face_end_row
		  && (row > mouse_face_beg_row
		      || column >= mouse_face_beg_col)
		  && (row < mouse_face_end_row
		      || column < mouse_face_end_col
		      || mouse_face_past_end)))
	{
	  Lisp_Object mouse_face, overlay, position;
	  Lisp_Object *overlay_vec;
	  int len, noverlays, ignor1;
	  struct buffer *obuf;
	  int obegv, ozv;

	  /* If we get an out-of-range value, return now; avoid an error.  */
	  if (pos > BUF_Z (XBUFFER (w->buffer)))
	    return;

	  /* Make the window's buffer temporarily current for
	     overlays_at and compute_char_face.  */
	  obuf = current_buffer;
	  current_buffer = XBUFFER (w->buffer);
	  obegv = BEGV;
	  ozv = ZV;
	  BEGV = BEG;
	  ZV = Z;

	  /* Yes.  Clear the display of the old active region, if any.  */
	  clear_mouse_face ();

	  /* Is this char mouse-active?  */
	  XSETINT (position, pos);

          len = 10;
          overlay_vec = (Lisp_Object *) xmalloc (len * sizeof (Lisp_Object));
          
          /* Put all the overlays we want in a vector in overlay_vec.
             Store the length in len.  */
          noverlays = overlays_at (XINT (pos), 1, &overlay_vec, &len,
                                   NULL, NULL);
          noverlays = sort_overlays (overlay_vec, noverlays, w);

          /* Find the highest priority overlay that has a mouse-face prop.  */
          overlay = Qnil;
          for (i = 0; i < noverlays; i++)
            {
              mouse_face = Foverlay_get (overlay_vec[i], Qmouse_face);
              if (!NILP (mouse_face))
                {
                  overlay = overlay_vec[i];
                  break;
                }
            }
          free (overlay_vec);
          /* If no overlay applies, get a text property.  */
          if (NILP (overlay))
            mouse_face =
              Fget_text_property (position, Qmouse_face, w->buffer);
          
	  /* Handle the overlay case.  */
	  if (! NILP (overlay))
	    {
	      /* Find the range of text around this char that
		 should be active.  */
	      Lisp_Object before, after;
	      int ignore;

	      before = Foverlay_start (overlay);
	      after = Foverlay_end (overlay);
	      /* Record this as the current active region.  */
	      fast_find_position (window, before, ozv,
				  &mouse_face_beg_col,
				  &mouse_face_beg_row);
	      mouse_face_past_end
		= !fast_find_position (window, after, ozv,
				       &mouse_face_end_col,
				       &mouse_face_end_row);
	      mouse_face_window = window;
	      mouse_face_face_id
		= compute_char_face (f, w, pos, 0, 0,
                                        &ignore, pos + 1, 1);

	      /* Display it as active.  */
	      show_mouse_face (1);
	    }
	  /* Handle the text property case.  */
	  else if (! NILP (mouse_face))
	    {
	      /* Find the range of text around this char that
		 should be active.  */
	      Lisp_Object before, after, beginning, end;
	      int ignore;

	      beginning = Fmarker_position (w->start);
              end = XSETINT (end, (BUF_Z (XBUFFER (w->buffer))
                                   - XFASTINT (w->window_end_pos)));

	      before
		= Fprevious_single_property_change (make_number (pos + 1),
						    Qmouse_face,
						    w->buffer, beginning);
	      after
		= Fnext_single_property_change (position, Qmouse_face,
						w->buffer, end);
	      /* Record this as the current active region.  */
	      fast_find_position (window, before, ozv,
				  &mouse_face_beg_col,
				  &mouse_face_beg_row);
	      mouse_face_past_end
		= !fast_find_position (window, after, ozv,
				       &mouse_face_end_col,
				       &mouse_face_end_row);
	      mouse_face_window = window;
	      mouse_face_face_id
		= compute_char_face (f, w, pos, 0, 0,
                                        &ignore, pos + 1, 1);

	      /* Display it as active.  */
	      show_mouse_face (1);
	    }
          /* Handle the no-mouse-face case */
          else
            {
              Lisp_Object tbefore, tafter, obefore, oafter;
              Lisp_Object beginning, end;
              int bcol, brow, ecol, erow, pcol, prow;
              int width = window_internal_width (w) + w->left;
              int height = window_internal_height (w) + w->top;
              
              beginning = Fmarker_position (w->start);
	      XSETINT (end, (BUF_Z (XBUFFER (w->buffer))
                             - XFASTINT (w->window_end_pos)));

              //was if ((pos + 1) >= XFASTINT (end))
              if (pos >= XFASTINT (end))
		{
                  fast_find_position (window, position, ozv,
                                      &bcol, &brow);
                  ecol = width;
                  erow = height;
		  
                  if (bcol > column)
                    {
                      bcol = w->left;
                      brow++;
                    }
                }
              else
		{
                  int after, before;
                  
                  tbefore =
                    Fprevious_single_property_change (make_number (pos + 1),
                                                      Qmouse_face,
                                                      w->buffer, beginning);
                  tafter =
                    Fnext_single_property_change (position, Qmouse_face,
                                                  w->buffer, end);

                  obefore = Fprevious_overlay_change (make_number (pos + 1));
                  oafter = Fnext_overlay_change (position);

                  if ((before = max (XFASTINT (tbefore),
                                     XFASTINT (obefore)))
                      == XFASTINT (beginning))
                    {
                      bcol = w->left;
                      brow = w->top;
                    }
                  else
                    {
                      fast_find_position (window, before, ozv,
                                          &bcol, &brow);

                      if (brow != row && bcol != w->left)
                        {
                          brow++;
                          bcol = w->left;
                        }
                    }
                  
                  if ((after = min (XFASTINT (tafter),
                                    XFASTINT (oafter))) == XFASTINT (end))
                    {
                      ecol = width;
                      erow = height;
                    }
                  else
                    {
                      fast_find_position (window, after, ozv,
                                          &ecol, &erow);

                      if (erow != row)
                        {
                          erow--;
                          ecol = width;
                        }
                      // we are in the row, but the region apparently
                      // ends before column.  This happens with
                      // invisible text, so we extend the region to the
                      // end of the line.
                      else if (ecol < column)
                        ecol = width;
                    }
                }
              ns_chars_to_rect (f, bcol, brow, ecol-1, erow,
                                &mouse_face_mouse_rect);
            }
	  BEGV = obegv;
	  ZV = ozv;
	  current_buffer = obuf;
	}
    }
}

/* Find the row and column of position POS in window WINDOW.
   Store them in *COLUMNP and *ROWP.
   This assumes display in WINDOW is up to date.
   If POS is above start of WINDOW, return coords
   of start of first screen line.
   If POS is after end of WINDOW, return coords of end of last screen line.

   Value is 1 if POS is in range, 0 if it was off screen.  */

static int
fast_find_position (window, pos, end, columnp, rowp)
     Lisp_Object window;
     int pos, end;
     int *columnp, *rowp;
{
  struct window *w = XWINDOW (window);
  FRAME_PTR f = XFRAME (WINDOW_FRAME (w));
  int i;
  int row = 0;
  int left = w->left;
  int top = w->top;
  int height = XFASTINT (w->height) - ! MINI_WINDOW_P (w);
  int width = window_internal_width (w);
  int *charstarts;
  int lastcol;
  int maybe_next_line = 0;

  /* Find the right row.  */
  for (i = 0;
       i < height;
       i++)
    {
      int linestart = FRAME_CURRENT_GLYPHS (f)->charstarts[top + i][left];
      if (linestart > pos)
	break;
      /* If the position sought is the end of the buffer,
	 don't include the blank lines at the bottom of the window.  */
      if (linestart == pos && pos == end) // was BUF_ZV (XBUFFER (w->buffer)))
	{
	  maybe_next_line = 1;
	  break;
	}
      if (linestart > 0)
	row = i;
    }

  /* Find the right column with in it.  */
  charstarts = FRAME_CURRENT_GLYPHS (f)->charstarts[top + row];
  lastcol = left;
  for (i = 0; i < width; i++)
    {
      if (charstarts[left + i] == pos)
	{
	  *rowp = row + top;
	  *columnp = i + left;
	  return 1;
	}
      else if (charstarts[left + i] > pos)
	break;
      else if (charstarts[left + i] > 0)
	lastcol = left + i;
    }

  /* If we're looking for the end of the buffer,
     and we didn't find it in the line we scanned,
     use the start of the following line.  */
  if (maybe_next_line)
    {
      row++;
      lastcol = left;
    }

  *rowp = row + top;
  *columnp = lastcol;
  return 0;
}

// FIXME/cl needs display_info arg
static void show_mouse_face (int hl)
{
  struct window *w = XWINDOW (mouse_face_window);
  int width = window_internal_width (w);
  FRAME_PTR f = XFRAME (WINDOW_FRAME (w));
  int i;
  int cursor_off = 0;
  int old_curs_x = curs_x;
  int old_curs_y = curs_y;
  NSRect r;

  /* Set these variables temporarily
     so that if we have to turn the cursor off and on again
     we will put it back at the same place.  */
  curs_x = f->phys_cursor_x;
  curs_y = f->phys_cursor_y;

  for (i = mouse_face_beg_row;
       i <= mouse_face_end_row; i++)
    {
      int column = (i == mouse_face_beg_row
		    ? mouse_face_beg_col
		    : w->left);
      int endcolumn = (i == mouse_face_end_row
		       ? mouse_face_end_col
		       : w->left + width);
      endcolumn = min (endcolumn, FRAME_CURRENT_GLYPHS (f)->used[i]);

      /* If the cursor's in the text we are about to rewrite,
	 turn the cursor off.  */
      if (i == curs_y
	  && curs_x >= column - 1
	  && curs_x <= endcolumn)
	{
          ns_dumpcursor (f, -1, -1);
	  cursor_off = 1;
	}

      ns_dumpglyphs (f, column, i,   // r.origin.x, r.origin.y,
                     FRAME_CURRENT_GLYPHS (f)->glyphs[i] + column,
                     endcolumn - column,
                     /* Highlight with mouse face if hl > 0.  */
                     hl > 0 ? 3 : 0 /*, 0*/);
      
      if (i == mouse_face_mouse_row)
        {
          ns_chars_to_rect (f, column, i, endcolumn-1, i,
                            &mouse_face_mouse_rect);
        }
      
    }
  
  ns_dumpglyphs(f,0,0,0,0,-1);
  /* If we turned the cursor off, turn it back on.  */
  if (cursor_off)
    ns_dumpcursor(f,f->cursor_x,f->cursor_y);

  curs_x = old_curs_x;
  curs_y = old_curs_y;

#if 0
  /* Change the mouse cursor according to the value of HL.  */
  if (hl > 0)
    XDefineCursor (FRAME_X_DISPLAY (f), FRAME_X_WINDOW (f),
		   f->output_data.x->cross_cursor);
  else
    XDefineCursor (FRAME_X_DISPLAY (f), FRAME_X_WINDOW (f),
		   f->output_data.x->text_cursor);
#endif
}

// FIXME/cl needs display_info arg
static void clear_mouse_face (void)
{
  if (! NILP (mouse_face_window))
    show_mouse_face (0);

  mouse_face_beg_row = mouse_face_beg_col = -1;
  mouse_face_end_row = mouse_face_end_col = -1;
  mouse_face_window = Qnil;
}

/* Return a list of names of available fonts matching PATTERN on frame
   F.  If SIZE is not 0, it is the size (maximum bound width) of fonts
   to be listed.  Frame F NULL means we have not yet created any
   frame on X, and consult the first display in x_display_list.
   MAXNAMES sets a limit on how many fonts to match.  */

Lisp_Object
ns_list_fonts (f, pattern, size, maxnames)
     FRAME_PTR f;
     Lisp_Object pattern;
     int size;
     int maxnames;
{
  Lisp_Object list = Qnil, patterns, newlist = Qnil, key, tem, second_best;
  id fm=[NSFontManager new];

  patterns = Fcons (pattern, Qnil);

  for (; CONSP (patterns); patterns = XCONS (patterns)->cdr)
    {
      int num_fonts;
      char **names;
      NSEnumerator *fenum;
      NSFont *font;

      pattern = XCONS (patterns)->car;
      /* See if we cached the result for this particular query.
         The cache is an alist of the form:
	   (((PATTERN . MAXNAMES) (FONTNAME . WIDTH) ...) ...)
      */
      if (f && (tem = XCONS (FRAME_NS_DISPLAY_INFO (f)->name_list_element)->cdr,
		key = Fcons (pattern, make_number (maxnames)),
		!NILP (list = Fassoc (key, tem))))
	{
	  list = Fcdr_safe (list);
	  /* We have a cashed list.  Don't have to get the list again.  */
	  goto label_cached;
	}

      /* At first, put PATTERN in the cache.  */
//      BLOCK_INPUT;
//      names = XListFonts (dpy, XSTRING (pattern)->data, maxnames, &num_fonts);
//      UNBLOCK_INPUT;
      fenum = [[fm availableFonts] objectEnumerator];

      /* Make a list of all the fonts we got back.
	 Store that in the font cache for the display.  */
      while ( font = [fenum nextObject] )
	{
	  int width = 0;

	  width = [font pointSize]; //[font widthOfString:@"M"];
	  list = Fcons (Fcons (tem, make_number (width)), list);
	}

      /* Now store the result in the cache.  */
      if (f != NULL)
	XCONS (FRAME_NS_DISPLAY_INFO (f)->name_list_element)->cdr
	  = Fcons (Fcons (key, list),
		   XCONS (FRAME_NS_DISPLAY_INFO (f)->name_list_element)->cdr);

    label_cached:
      if (NILP (list)) continue; /* Try the remaining alternatives.  */

      newlist = second_best = Qnil;
      /* Make a list of the fonts that have the right width.  */
      for (; CONSP (list); list = XCONS (list)->cdr)
	{
	  int found_size;

	  tem = XCONS (list)->car;

	  if (!CONSP (tem) || NILP (XCONS (tem)->car))
	    continue;
	  if (!size)
	    {
	      newlist = Fcons (XCONS (tem)->car, newlist);
	      continue;
	    }

	  found_size = XINT (XCONS (tem)->cdr);
	  if (found_size == size)
	    newlist = Fcons (XCONS (tem)->car, newlist);
	  else if (found_size > 0)
	    {
	      if (NILP (second_best))
		second_best = tem;
	      else if (found_size < size)
		{
		  if (XINT (XCONS (second_best)->cdr) > size
		      || XINT (XCONS (second_best)->cdr) < found_size)
		    second_best = tem;
		}
	      else
		{
		  if (XINT (XCONS (second_best)->cdr) > size
		      && XINT (XCONS (second_best)->cdr) > found_size)
		    second_best = tem;
		}
	    }
	}
      if (!NILP (newlist))
	break;
      else if (!NILP (second_best))
	{
	  newlist = Fcons (XCONS (second_best)->car, Qnil);
	  break;
	}
    }

  return newlist;
}

/* Return a pointer to struct font_info of font FONT_IDX of frame F.  */
struct font_info *
ns_get_font_info (f, font_idx)
     FRAME_PTR f;
     int font_idx;
{
  return (FRAME_NS_FONT_TABLE (f) + font_idx);
}

Lisp_Object
ns_new_font (f, fontname)
     struct frame *f;
     register char *fontname;
{
  struct font_info *fontp
    = fs_load_font (f, FRAME_NS_FONT_TABLE (f), CHARSET_ASCII, fontname, -1);

  if (!fontp)
    return Qnil;

  f->output_data.ns->font = (XFontStruct *) (fontp->font);
#if 0
  f->output_data.ns->font_baseline
    = (f->output_data.ns->font->ascent + fontp->baseline_offset);
  f->output_data.ns->fontset = -1;
#endif
  
  /* Compute the scroll bar width in character columns.  */
  if (f->scroll_bar_pixel_width > 0)
    {
      int wid = FONT_WIDTH (f->output_data.ns->font);
      f->scroll_bar_cols = (f->scroll_bar_pixel_width + wid-1) / wid;
    }
  else
    {
      int wid = FONT_WIDTH (f->output_data.ns->font);
      f->scroll_bar_cols = (14 + wid - 1) / wid;
    }

  /* Now make the frame display the given font.  */
  if (FRAME_NS_WINDOW (f) != 0)
    {
      ns_frame_update_line_height (f);
      x_set_window_size (f, 0, f->width, f->height);
    }
  else
    /* If we are setting a new frame's font for the first time,
       there are no faces yet, so this font's height is the line height.  */
    f->output_data.ns->line_height = FONT_HEIGHT (f->output_data.ns->font);

  return build_string (fontp->full_name);
}

static int ns_clear_frame(void)
   {
   struct frame *f=(updating_frame ? updating_frame : selected_frame);
   id view=f->output_data.ns->view;
   int i;
   NSRect r;

   if (f!=updating_frame || !lockfocused)
      {
      [view lockFocus];
      if (f==updating_frame) lockfocused=1;
      }

   ns_dumpcursor(f,-1,-1);
   curs_x=curs_y=0;

   [[view window] display];

   if (f!=updating_frame)
      {
      ns_dumpcursor (f,f->cursor_x,f->cursor_y);
      [view unlockFocus];
      [[view window] flushWindow];
      PSFlush();
      }
   return 0;
   }

static int ns_clear_end_of_line(int first_unused)
   {
   struct frame *f=(updating_frame ? updating_frame : selected_frame);
   id view=f->output_data.ns->view;
   NSRect r;

   if (curs_y < 0 || curs_y >= f->height) return 0;
   if (first_unused <= 0) return 0;
   if (first_unused > f->width) first_unused = f->width;

   if (curs_y == f->phys_cursor_y &&
       curs_x <= f->phys_cursor_x && f->phys_cursor_x < first_unused)
      ns_dumpcursor(f,-1,-1);
   ns_dumpglyphs(f,curs_x,curs_y,0,first_unused-curs_x,2);

   if (f!=updating_frame)
      {
      ns_dumpglyphs(f,0,0,0,0,-1);
      ns_dumpcursor(f,f->cursor_x,f->cursor_y);
      }
   return 0;
   }

static int ns_ins_del_lines(int vpos, int n)
   {
   struct frame *f=(updating_frame ? updating_frame : selected_frame);
   id view=f->output_data.ns->view;
   int height;
   struct face *face = FRAME_DEFAULT_FACE(f);
   NSPoint p;
   NSRect r,s;

   curs_x = 0;
   curs_y = vpos;

   if (curs_y >= flexlines) return 0;

   if (n>0)
      {
      height=f->output_data.ns->line_height*n;
      ns_chars_to_rect(f,curs_x,curs_y,f->width-1,flexlines-1,&r);
      s=r;
      p=r.origin;

      r.size.height-=height;
      p.y          +=height;
      s.size.height =height;
      }
   else if (n<0)
      {
      height=f->output_data.ns->line_height*(-n);
      ns_chars_to_rect(f,curs_x,curs_y,f->width-1,flexlines-1,&r);
      s=r;
      p=r.origin;

      r.size.height-=height;
      r.origin.y   +=height;
      s.origin.y    =s.origin.y+s.size.height-height;
      s.size.height =height;
      }

   if (f!=updating_frame || !lockfocused)
      {
      [view lockFocus];
      if (f==updating_frame) lockfocused=1;
      }

   ns_dumpcursor(f,-1,-1);
   if (r.size.height>0) NSCopyBits(DPSNullObject , r , p);

   if (s.size.height>0)
      {
      [NS_FACE_BACKGROUND(face) set];
      NSRectFill(s);
      }

   if (f!=updating_frame)
      {
      ns_dumpcursor(f,f->cursor_x,f->cursor_y);
      [view unlockFocus];
      [[view window] flushWindow];
      PSFlush();
      }

   return 0;
   }

static int ns_change_line_highlight(int new_highlight, int vpos,
                                     int first_unused_hpos)
   {
   highlight = new_highlight;
   curs_x = 0;
   curs_y = vpos;
   ns_clear_end_of_line (updating_frame->width);
   return 0;
   }

static int ns_insert_glyphs(GLYPH *start, int len)
   {
   abort();
   return 0;
   }

static int ns_write_glyphs(GLYPH *start, int len)
   {
   struct frame *f=(updating_frame ? updating_frame : selected_frame);

   if (f!=updating_frame)
      {
      curs_x = f->cursor_x;
      curs_y = f->cursor_y;
      }

   if (curs_y == f->phys_cursor_y && curs_x <= f->phys_cursor_x
       && curs_x + len > f->phys_cursor_x)
      ns_dumpcursor(f,-1,-1);
   ns_dumpglyphs(f,curs_x,curs_y,start,len,highlight);

   if (f!=updating_frame)
      {
      ns_dumpglyphs(f,0,0,0,0,-1);
      ns_dumpcursor(f,f->cursor_x+len,f->cursor_y);
      }
   else
      curs_x += len;

   return 0;
   }

static int ns_delete_glyphs(GLYPH *start,int len)
   {
   abort();
   return 0;
   }

static int ns_ring_bell(void)
   {
   NSBeep();
   return 0;
   }

static int ns_reset_terminal_modes(void)
   {
   return 0;
   }

static int ns_set_terminal_modes(void)
   {
   return 0;
   }

static int ns_update_begin(struct frame *f)
   {
   flexlines = f->height;
   highlight = 0;
   lockfocused=0;
   if (f == mouse_face_mouse_frame)
      {
      /* Don't do highlighting for mouse motion during the update.  */
      mouse_face_defer = 1;

      /* If the frame needs to be redrawn,
	 simply forget about any prior mouse highlighting.  */
      if (FRAME_GARBAGED_P (f))
        mouse_face_window = Qnil;

      if (!NILP (mouse_face_window))
         {
         int firstline, lastline, i;
         struct window *w = XWINDOW (mouse_face_window);

         /* Find the first, and the last+1, lines affected by redisplay.  */
         for (firstline = 0; firstline < f->height; firstline++)
	    if (FRAME_DESIRED_GLYPHS (f)->enable[firstline])
               break;

         lastline = f->height;
         for (i = f->height - 1; i >= 0; i--)
	    {
            if (FRAME_DESIRED_GLYPHS (f)->enable[i])
               break;
            else
               lastline = i;
	    }

         /* Can we tell that this update does not affect the window
            where the mouse highlight is?  If so, no need to turn off.
            Likewise, don't do anything if the frame is garbaged;
            in that case, the FRAME_CURRENT_GLYPHS that we would use
            are all wrong, and we will redisplay that line anyway.  */
         if (! (firstline > (XFASTINT (w->top) + window_internal_height (w))
                || lastline < XFASTINT (w->top)))
	    /* Otherwise turn off the mouse highlight now.  */
	    clear_mouse_face ();
         }
      }
   return 0;
   }

static int ns_update_end(struct frame *f)
   {
   ns_dumpglyphs(f,0,0,0,0,-1);
   ns_dumpcursor(f,curs_x,curs_y);
   if (lockfocused)
      {
      id view=f->output_data.ns->view;
      [view unlockFocus];
      [[view window] flushWindow];
      PSFlush();
      lockfocused=0;
      }
   if (f == mouse_face_mouse_frame)
     mouse_face_defer = 0;
   return 0;
   }

static int ns_frame_up_to_date(struct frame *f)
{
  if (mouse_face_deferred_gc || (f == mouse_face_mouse_frame))
    {
      NSRect r;
      id view = mouse_face_mouse_frame->output_data.ns->view;
      NSPoint position;

      position = [[view window] mouseLocationOutsideOfEventStream];
      position = [view convertPoint:position fromView:nil];
      r = [view bounds];
      if ([view mouse:position inRect:r] && !f->iconified &&
          !f->async_iconified)
        {
          note_mouse_highlight (mouse_face_mouse_frame,
                                mouse_face_mouse_x,
                                mouse_face_mouse_y);
          ns_set_mouse_tracking (view);
        }
      else if (mouse_face_tracked_view == view)
        {
          // clear_mouse_face ();
          ns_remove_mouse_tracking ();
        }

      mouse_face_deferred_gc = 0;
    }
}

static int ns_set_terminal_window(int n)
   {
   struct frame *f=(updating_frame ? updating_frame : selected_frame);

   flexlines = ((n > 0) && (n <= f->height)) ? n : f->height;
   return 0;
   }

void ns_send_appdefined (int value)
   {
   int i;

   /* Only post this event if we haven't already posted one.  This will end
      the [NXApp run] main loop after having processed all events queued at
	  this moment.  */

   if (!send_appdefined)
      abort ();
   else
      {
      NSEvent *nxev;

      nxev = [NSEvent otherEventWithType:NSApplicationDefined 
				location:NSMakePoint(0, 0)
			   modifierFlags:0 
			       timestamp:0 
			    windowNumber:[[NSApp mainWindow] windowNumber]
				 context:[NSApp context]
				 subtype:0
				   data1:value
				   data2:0];

      /* Post an application defined event on the event queue.  When this is
         recieved the [NXApp run] will return, thus having processed all
         events which are currently queued.  */
      [NSApp postEvent:nxev atStart:NO];

      /* We only need one NX_APPDEFINED event to stop NXApp from running.  */
      send_appdefined = NO;

      if (timed_entry)
         {
         [timed_entry invalidate]; [timed_entry release];;
         timed_entry = 0;
         }

      if (cursor_blink_entry)
         {
         [cursor_blink_entry invalidate]; [cursor_blink_entry release];;
         cursor_blink_entry = 0;
         }

	  select_readfds = 0;
	  select_writefds = 0;
	  select_exceptfds = 0;
	  
	  {
		NSEnumerator *fenum;
		NSFileHandle *fh;

		fenum = [selectingFileHandles objectEnumerator];
		while ( fh = [fenum nextObject] ) {
		  [[NSNotificationCenter defaultCenter] 
			removeObserver:NSApp 
				  name:NSFileHandleDataAvailableNotification
				object:fh];
		  [fh release];
		}
		[selectingFileHandles release];
		selectingFileHandles = nil;
	  }
      }
   }

/* Post an event to ourself and keep reading events until we read it back
   again.  In effect process all events which were waiting.  */
static int ns_read_socket (int sd, struct input_event *bufp,
                           int numchars, int waitp, int expected)
   {
   int nevents;
#ifdef AUTORELEASE
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
   if (send_appdefined) abort ();

   /* We must always send one NX_APPDEFINED event to ourself, otherwise
      [NXApp run] will never exit.  */
   send_appdefined = YES;

   if (!waitp)
      {
      /* Post an application defined event on the event queue.  When this is
         recieved the [NXApp run] will return, thus having processed all
         events which are currently queued, if any.  */
      ns_send_appdefined (-1);
      }

   events = bufp;
   eventsleft = numchars;

NS_DURING
   [NSApp run];
NS_HANDLER
   NSLog([localException description]);
   if ([localException name] != NSInternalInconsistencyException
       || ![[localException reason] isEqualToString:@"Buffer empty and needy"])
     [localException raise];
NS_ENDHANDLER

   nevents = numchars - eventsleft;
   eventsleft = 0;
   events = 0;
#ifdef AUTORELEASE
   [pool release];
#endif
   return nevents;
   }

static int ns_reassert_line_highlight(int new, int vpos)
   {
   highlight = new;
   return 0;
   }

static void ns_mouse_position (struct frame **fp, int insist,
			       Lisp_Object *bar_window,
                               enum scroll_bar_part *part,
                               Lisp_Object *x, Lisp_Object *y,
                               unsigned long *time)
   {
   id view;
   NSPoint position;
   int xchar, ychar;

   Lisp_Object frame, tail;

   /* Clear the mouse-moved flag for every frame on this display.  */
   FOR_EACH_FRAME (tail, frame)
     if (FRAME_NS_DISPLAY (XFRAME (frame)) == FRAME_NS_DISPLAY (*fp))
       XFRAME (frame)->mouse_moved = 0;

   if (last_mouse_frame) *fp=last_mouse_frame;
   view=(*fp)->output_data.ns->view;

   position = [[view window] mouseLocationOutsideOfEventStream];
   position = [view convertPoint:position fromView:nil];
   pixel_to_glyph_coords(*fp, (int)rint(position.x), (int)rint(position.y),
                            &xchar, &ychar, 0, 1);
   ns_chars_to_rect(*fp, xchar, ychar, xchar, ychar, &last_mouse_glyph);
   if (bar_window) *bar_window = Qnil;
   if (part) *part = 0;
   if (x) XSET (*x, Lisp_Int, (int)rint(position.x));
   if (y) XSET (*y, Lisp_Int, (int)rint(position.y));
   if (time) *time = last_mouse_movement_time;
   }

// FIXME/cl multidisplay
static void ns_frame_rehighlight(struct frame *frame)
   {
   struct frame *f=0;

   if (ns_focus_frame)
      {
      f = (GC_FRAMEP (FRAME_FOCUS_FRAME (ns_focus_frame))
           ? XFRAME (FRAME_FOCUS_FRAME (ns_focus_frame))
           : ns_focus_frame);
      if (!FRAME_LIVE_P (f))
         {
         FRAME_FOCUS_FRAME (ns_focus_frame) = Qnil;
         f = ns_focus_frame;
         }
      }

  if (f != ns_highlight_frame)
     {
     if (f)
        [[f->output_data.ns->view window] makeKeyAndOrderFront:NSApp];
/*     else
        resign key window */
     }
   }

static void ns_frame_raise_lower(struct frame *f, int raise)
   {
   if (raise)
      ns_raise_frame(f);
   else
      ns_lower_frame(f);
   }

static void ns_set_vertical_scroll_bar(struct window *window,
                                       int portion, int whole, int position)
   {
   Lisp_Object win;
   NSRect r,s, v;
   struct frame *f= XFRAME (WINDOW_FRAME (window));
   NSView *view=f->output_data.ns->view;
   int top = XINT (window->top);
   int left = WINDOW_VERTICAL_SCROLL_BAR_COLUMN (window);
   int height = WINDOW_VERTICAL_SCROLL_BAR_HEIGHT (window);
   EmacsScroller *bar;

   XSETWINDOW (win, window);
   if (FRAME_SCROLL_BAR_PIXEL_WIDTH (f) > 0)
     {
       ns_chars_to_rect (f, left, top, left, top+height-1, &r);
       r.size.width = FRAME_SCROLL_BAR_PIXEL_WIDTH (f);
     }
   else
     ns_chars_to_rect (f, left, top,
                       left + (FRAME_SCROLL_BAR_COLS (f) - 1),
                       top + height - 1, &r);
   [view convertRect:r toView:[view superview]];
   

   // the parent view is flipped, so we need to flip y value
   v = [view frame];
   r.origin.y = v.size.height - r.size.height - r.origin.y;
   r.origin.x++;

   // if (r.size.width*2.5>=r.size.height)
   if (window->height < 3) // we want at least 3 lines to display a scrollbar
     {
       if (!NILP (window->vertical_scroll_bar))
         {
           bar = XNS_SCROLL_BAR(window->vertical_scroll_bar);
	   [bar removeFromSuperview];
	   window->vertical_scroll_bar = Qnil;
         }
       return;
     }
   
   if (NILP (window->vertical_scroll_bar))
      {
      bar=[[EmacsScroller alloc] initFrame:r window:win];
      VOID_TO_LISP (window->vertical_scroll_bar, bar);
      }
   else
      {
      bar= XNS_SCROLL_BAR(window->vertical_scroll_bar);
      [bar setFrame:r];
      }

   [bar setPosition:position portion:portion whole:whole];
   }

/* The following three hooks are used when we're doing a thorough
   redisplay of the frame.  We don't explicitly know which scroll bars
   are going to be deleted, because keeping track of when windows go
   away is a real pain - "Can you say set-window-configuration, boys
   and girls?"  Instead, we just assert at the beginning of redisplay
   that *all* scroll bars are to be removed, and then save a scroll bar
   from the fiery pit when we actually redisplay its window.  */

/* Arrange for all scroll bars on FRAME to be removed at the next call
   to `*judge_scroll_bars_hook'.  A scroll bar may be spared if
   `*redeem_scroll_bar_hook' is applied to its window before the judgement.  */
static void ns_condemn_scroll_bars(struct frame *f)
   {
   int i;
   id view;
   NSArray *subviews = [[f->output_data.ns->view superview] subviews];
   for (i=[subviews count]-1; i>=0; i--)
      {
      view=[subviews objectAtIndex:i];
      if (![view isKindOfClass:[EmacsScroller class]]) continue;
      [view condemn];
      }
   }

/* Unmark WINDOW's scroll bar for deletion in this judgement cycle.
   Note that WINDOW isn't necessarily condemned at all.  */
static void ns_redeem_scroll_bar(struct window *window)
   {
   id bar;
   if (!NILP(window->vertical_scroll_bar))
      {
      bar=XNS_SCROLL_BAR (window->vertical_scroll_bar);
      [bar reprieve];
      }
   }

/* Remove all scroll bars on FRAME that haven't been saved since the
   last call to `*condemn_scroll_bars_hook'.  */
static void ns_judge_scroll_bars(struct frame *f)
   {
   int i;
   id view;
   NSArray *subviews = [[f->output_data.ns->view superview] subviews];
   for (i=[subviews count]-1; i>=0; i--)
      {
      view=[subviews objectAtIndex:i];
      if (![view isKindOfClass:[EmacsScroller class]]) continue;
      [view judge];
      }
   }

static Lisp_Object append2(Lisp_Object list, Lisp_Object item)
   {
   Lisp_Object array[2];
   array[0]=list;
   array[1]=Fcons(item,Qnil);
   return Fnconc(2,&array[0]);
   }

int ns_check_available (void)
   {
   int ret=1;

   if (ret)
      {
      NXEventHandle handle=NXOpenEventStatus();
      if (handle)
         NXCloseEventStatus(handle);
      else
         ret=0;
      }

   return ret;
   }

static int ns_initialized;

/* Start the Application and get things rolling.  */
struct ns_display_info *
ns_term_init (Lisp_Object display_name)
{
  extern Lisp_Object Fset_input_mode(Lisp_Object,Lisp_Object,
                                     Lisp_Object,Lisp_Object);
  struct ns_display_info *dpyinfo;
#ifdef AUTORELEASE
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];  
#endif
  if (!ns_initialized)
    {
      ns_initialize ();
      ns_initialized = 1;
    }

  [EmacsApp sharedApplication];
  if ((ns_current_display = NSApp) == 0)
    return 0;

  dpyinfo = (struct ns_display_info *)
    xmalloc (sizeof (struct ns_display_info));
   bzero (dpyinfo, sizeof (struct ns_display_info));

#ifdef MULTI_KBOARD
  dpyinfo->kboard = all_kboards;
#endif

  dpyinfo->next = ns_display_list;
  ns_display_list = dpyinfo;
  
  /* Put it on ns_display_name_list */
  ns_display_name_list = Fcons (Fcons (display_name, Qnil),
                                ns_display_name_list);
  dpyinfo->name_list_element = XCONS (ns_display_name_list)->car;
  
      {
      const char *value=[[[NSUserDefaults standardUserDefaults] objectForKey:@"Menus"] cString];
      if (!value || strcasecmp(value,"NO"))
         set_frame_menubar(selected_frame,1);
      }

      {
      const char *value, *parameter;
      if (value=[[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:parameter="ShrinkSpace"]] cString])
         {
         double f;
         if (strcasecmp(value,"YES")==0)
            ns_shrink_space=make_float(0.75);
         else if (strcasecmp(value,"NO")==0)
            ns_shrink_space=make_float(1.0);
         else if ((f=atof(value))>0.0)
            ns_shrink_space=make_float(f);
         else fprintf(stderr, "Bad value for default \"%s\": \"%s\"\n",
                      parameter,value);
         }

      if (value=[[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:parameter="AlternateIsMeta"]] cString])
         {
         if (strcasecmp(value,"YES")==0)
            ns_alternate_is_meta=Qt;
         else if (strcasecmp(value,"NO")==0)
            ns_alternate_is_meta=Qnil;
         else if (strcasecmp(value,"LEFT")==0)
            ns_alternate_is_meta=Qleft;
         else if (strcasecmp(value,"RIGHT")==0)
            ns_alternate_is_meta=Qright;
         else fprintf(stderr, "Bad value for default \"%s\": \"%s\"\n",
                      parameter,value);
         }

      if (value=[[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:parameter="UseOpenPanel"]] cString])
         {
         if (strcasecmp(value,"YES")==0)
            ns_use_open_panel=YES;
         else if (strcasecmp(value,"NO")==0)
            ns_use_open_panel=NO;
         else fprintf(stderr, "Bad value for default \"%s\": \"%s\"\n",
                      parameter,value);
         }

      if (value=[[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:parameter="UseYesNoPanel"]] cString])
         {
         if (strcasecmp(value,"YES")==0)
            ns_use_yes_no_panel=YES;
         else if (strcasecmp(value,"NO")==0)
            ns_use_yes_no_panel=NO;
         else fprintf(stderr, "Bad value for default \"%s\": \"%s\"\n",
                      parameter,value);
         }

      if (value=[[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:parameter="ISOLatin"]] cString])
         {
         if (strcasecmp(value,"YES")==0)
            ns_iso_latin=Qt;
         else if (strcasecmp(value,"NO")==0)
            ns_iso_latin=Qnil;
         else fprintf(stderr, "Bad value for default \"%s\": \"%s\"\n",
                      parameter,value);
         }

      if (value=[[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:parameter="CursorBlinkRate"]] cString])
         {
         double f;
         if (strcasecmp(value,"NO")==0)
            ns_cursor_blink_rate=Qnil;
         else if (strcasecmp(value,"YES")==0)
            ns_cursor_blink_rate=make_float(0.5);
         else if ((f=atof(value))>0)
            ns_cursor_blink_rate=make_float(f);
         else fprintf(stderr, "Bad value for default \"%s\": \"%s\"\n",
                      parameter,value);
         }
      }

   keymap_init();

#if 0
      {
      id cl;
      char *fname=alloca(XSTRING(Vdata_directory)->size+10);
      
      strcpy(fname,XSTRING(Vdata_directory)->data);
      strcat(fname,"Emacs.clr");
      cl=[[NSColorList alloc] initWithName:@"Emacs" fromFile:[NSString stringWithCString:fname]];
      if (cl==nil)
         fatal ("Could not find %s.\n", fname);
      [[NSColorList availableColorLists] addObject:cl];
      }
#else
      {
      id cl;
      Lisp_Object tem, tem1;
      extern Lisp_Object Vsource_directory;

	  cl = [NSColorList colorListNamed:@"Emacs"];

	  if ( cl == nil ) {
		// first try data_dir, then invocation-dir
		// and finally source-directory/etc
		tem1 = tem =
		  Fexpand_file_name (build_string ("Emacs.clr"), Vdata_directory);
		if (NILP (Ffile_exists_p (tem)))
		  {
			tem = Fexpand_file_name (build_string ("Emacs.clr"),
									 Vinvocation_directory);
			if (NILP (Ffile_exists_p (tem)))
			  {
				Lisp_Object newdir =
				  Fexpand_file_name (build_string ("etc/"),
									 Vsource_directory);
				tem = Fexpand_file_name (build_string ("Emacs.clr"),
										 newdir);
			  }
		  }

		cl=[[NSColorList alloc] initWithName:@"Emacs" fromFile:[NSString stringWithCString:XSTRING (tem)->data]];
		if (cl==nil)
		  fatal ("Could not find %s.\n", XSTRING (tem1)->data);
		[cl writeToFile:nil];
	  }
	  

      }
#endif

      {
      char c[1024];
      PSnextrelease(1024,c);
      Vwindow_system_version = build_string(c);
      }

  mouse_face_mouse_frame = 0;
  mouse_face_deferred_gc = 0;
  mouse_face_beg_row = mouse_face_beg_col = -1;
  mouse_face_end_row = mouse_face_end_col = -1;
  mouse_face_face_id = 0;
  mouse_face_window = Qnil;
  mouse_face_mouse_x = mouse_face_mouse_y = 0;
  mouse_face_defer = 0;
  mouse_face_mouse_row = -1;
  mouse_face_tracked_view = nil;
  
   // FIXME/cl check
   // change_keyboard_wait_descriptor(-1);
   delete_keyboard_wait_descriptor (0);

   [NSApp run];

#ifdef AUTORELEASE
   [pool release];
#endif

   return dpyinfo;
}

/* Set up use of NS before we make the first connection.  */

ns_initialize ()
{
  clear_frame_hook = ns_clear_frame;
  clear_end_of_line_hook = ns_clear_end_of_line;
  ins_del_lines_hook = ns_ins_del_lines;
  change_line_highlight_hook = ns_change_line_highlight;
  insert_glyphs_hook = ns_insert_glyphs;
  write_glyphs_hook = ns_write_glyphs;
  delete_glyphs_hook = ns_delete_glyphs;
  update_begin_hook = ns_update_begin;
  update_end_hook = ns_update_end;
  ring_bell_hook = ns_ring_bell;
  reset_terminal_modes_hook = ns_reset_terminal_modes;
  set_terminal_modes_hook = ns_set_terminal_modes;
  set_terminal_window_hook = ns_set_terminal_window;
  read_socket_hook = ns_read_socket;
  frame_up_to_date_hook = ns_frame_up_to_date;
  cursor_to_hook = ns_cursor_to;
  reassert_line_highlight_hook = ns_reassert_line_highlight;
  mouse_position_hook = ns_mouse_position;
  frame_rehighlight_hook = ns_frame_rehighlight;
  frame_raise_lower_hook = ns_frame_raise_lower;
  set_vertical_scroll_bar_hook = ns_set_vertical_scroll_bar;
  condemn_scroll_bars_hook = ns_condemn_scroll_bars;
  redeem_scroll_bar_hook = ns_redeem_scroll_bar;
  judge_scroll_bars_hook = ns_judge_scroll_bars;

  scroll_region_ok = 1;
  char_ins_del_ok = 0;
  line_ins_del_ok = 1;
  fast_clear_end_of_line = 1;
  memory_below_frame = 0;
  baud_rate = 38400;

  /* No interupt input under NS */
  Fset_input_mode (Qnil, Qnil, Qt, Qnil);
}

char *
x_get_keysym_name (keysym)
    int keysym;
{
  /* Make static so we can always return it */
  static char value[100];

  sprintf(value, "%c", keysym);

  return value;
}

void syms_of_nsterm ()
   {
   DEFVAR_LISP("ns-input-file", &ns_input_file,
               "The file specified in the last NS event.");
   ns_input_file=Qnil;

   DEFVAR_LISP("ns-input-ascii", &ns_input_ascii,
               "The data received in the last NS drag event..");
   ns_input_ascii=Qnil;

   DEFVAR_LISP("ns-input-font", &ns_input_font,
               "The font specified in the last NS event.");
   ns_input_font=Qnil;

   DEFVAR_LISP("ns-input-fontsize", &ns_input_fontsize,
               "The fontsize specified in the last NS event.");
   ns_input_fontsize=Qnil;

   DEFVAR_LISP ("ns-input-line", &ns_input_line,
                "The line specified in the last NS event.");
   ns_input_line=Qnil;

   DEFVAR_LISP ("ns-input-color", &ns_input_color,
                "The color specified in the last NS event.");
   ns_input_color=Qnil;

   DEFVAR_LISP ("ns-alternate-is-meta", &ns_alternate_is_meta,
   "This variable describes what the effect of the alternate key is under NS.\n\
nil means that the alternate key is not interpreted by Emacs at all,\n\
t means that the alternate key is used as meta key,\n\
left means that the left alternate key only is interpreted as meta key,\n\
right means that the right alternate key only is interpreted as meta key.\n\
(This variable should only be read, never set.)");
   ns_alternate_is_meta=Qt;

   DEFVAR_LISP ("ns-iso-latin", &ns_iso_latin,
   "If non-nil use the ISO Latin 8859/1 encoding.  Otherwise use the NS encoding.\n\
(This variable should only be read, never set.)");
   ns_iso_latin=Qnil;

   DEFVAR_LISP ("ns-shrink-space", &ns_shrink_space,
   "Amount by which spacing between lines is compressed.\n\
(This variable should only be read, never set.)");
   ns_shrink_space=make_float(0.75);

   DEFVAR_LISP ("ns-cursor-blink-rate", &ns_cursor_blink_rate,
   "Rate at which the Emacs cursor blinks (in seconds).\n\
Set to nil to disable blinking.");
   ns_cursor_blink_rate=Qnil;

   DEFVAR_BOOL ("ns-use-open-panel", &ns_use_open_panel,
     "*Non-nil means to use ns-read-file-name whenever read-file-name is called.");
   ns_use_open_panel=NO;

   DEFVAR_BOOL ("ns-use-yes-no-panel", &ns_use_yes_no_panel,
     "*Non-nil means to use ns-yes-or-no-p whenever yes-or-no-p or y-or-n-p are called.");
   ns_use_yes_no_panel=NO;

  staticpro (&ns_display_name_list);
  ns_display_name_list = Qnil;
  
   }

static void timeout_handler (NSTimer *timedEntry, double now, void *userData)
   {
   /* The timeout specified to ns_select has passed.  */
   ns_send_appdefined (-2);
   }

static void cursor_blink_handler (NSTimer *cursorBlinkEntry, double now,
                                  void *userData)
   {
   if (!ns_highlight_frame) return;
   if (ns_highlight_frame->output_data.ns->current_cursor==no_highlight)
      {
      Lisp_Object tem=get_frame_param(ns_highlight_frame, Qcursor_type);
      ns_highlight_frame->output_data.ns->desired_cursor=ns_lisp_to_cursor_type(tem);
      }
   else
      {
      ns_highlight_frame->output_data.ns->desired_cursor=no_highlight;
      }

   ns_dumpglyphs(ns_highlight_frame,0,0,0,0,-1);
   ns_dumpcursor(ns_highlight_frame,ns_highlight_frame->cursor_x,
                 ns_highlight_frame->cursor_y);
   }

/* One of the file selectors which has been added with a DPSAddFD by
   ns_select has finished a read, has data waiting on it or has finished a
   write.  Let ns_select know by sending it an event.  */

static void fd_handler (int fd, void *data)
   {
   ns_send_appdefined (fd);
   }

NSFileHandle *ns_setupselect(int fd)
{
  id __fd = [[NSFileHandle allocWithZone:NULL] initWithFileDescriptor:fd
													   closeOnDealloc:NO];
  [[NSNotificationCenter defaultCenter] 
	addObserver:NSApp
	   selector:@selector(fd_handler:)
#ifdef WAIT_FOR_DATA
	    name:NSFileHandleDataAvailableNotification
#else
	    name:NSFileHandleReadCompletionNotification
#endif
	  object:__fd];

  [__fd 
#ifdef WAIT_FOR_DATA
    waitForDataInBackgroundAndNotifyForModes:
#else
	   readInBackgroundAndNotifyForModes:
#endif
		   [NSArray arrayWithObjects:NSDefaultRunLoopMode, nil]];
  return __fd;
}
 

int ns_select (int nfds, fd_set *readfds, fd_set *writefds,
               fd_set *exceptfds, struct timeval *timeout)
{
  int i, j, tfds;
  double time;
  NSEvent *ev;
  struct timezone tz;
  struct timeval curtime;
#ifdef AUTORELEASE
  NSAutoreleasePool *pool = nil;
#endif
  NSFileHandle *fh;

  if (ns_current_display == nil) {
    return select (nfds, readfds, writefds, exceptfds, timeout);
  }

//  pool = [[NSAutoreleasePool alloc] init];
  
  select_nfds = nfds;
  select_readfds = readfds;
  select_writefds = writefds;
  select_exceptfds = exceptfds;
  tfds = 0;

  if ( selectingFileHandles == nil )
    selectingFileHandles = [[NSMutableArray allocWithZone:0] init];
  
  if (readfds) 
	for (i = 0; i < nfds; i++) 
	  if (FD_ISSET (i, readfds)) {
		if (i >= tfds) 
		  tfds = i + 1;
		fh = ns_setupselect(i);
		[selectingFileHandles addObject:fh];
      }
  
  if (writefds) 
    for (i = 0; i < nfds; i++) 
      if (FD_ISSET (i, writefds)) {
		if (i >= tfds) 
		  tfds = i + 1;
		fh = ns_setupselect(i);
		[selectingFileHandles addObject:fh];
      }
  
  if (exceptfds) 
    for (i = 0; i < nfds; i++) 
      if (FD_ISSET (i, exceptfds)) {
		if (i >= tfds) 
		  tfds = i + 1;
		fh = ns_setupselect(i);
		[selectingFileHandles addObject:fh];
      }

  nfds = tfds;

  if (timeout)
    {
      time = ((double) timeout->tv_sec) + ((double) timeout->tv_usec) / 1000000.0;
      gettimeofday (&curtime, &tz);
      timeout->tv_sec += curtime.tv_sec;
      timeout->tv_usec += curtime.tv_usec;
      /* Set a DPSTimedEntry as timeout.  */
      timed_entry = [[NSTimer scheduledTimerWithTimeInterval:time target:NSApp selector:@selector(timeout_handler:) userInfo:0 repeats:YES] retain];
      }

   if (NUMBERP(ns_cursor_blink_rate))
      {
      if (ns_highlight_frame &&
          ns_highlight_frame->output_data.ns->current_cursor==no_highlight)
         {
         Lisp_Object tem=get_frame_param(ns_highlight_frame, Qcursor_type);
         ns_highlight_frame->output_data.ns->desired_cursor=ns_lisp_to_cursor_type(tem);
         ns_dumpglyphs(ns_highlight_frame,0,0,0,0,-1);
         ns_dumpcursor(ns_highlight_frame,ns_highlight_frame->cursor_x,
                       ns_highlight_frame->cursor_y);
         }
      cursor_blink_entry = [[NSTimer scheduledTimerWithTimeInterval:XFLOATINT(ns_cursor_blink_rate) target:NSApp selector:@selector(cursor_blink_handler:) userInfo:0 repeats:YES] retain];
      }

   /* Let Application dispatch events until it recieves an event of the type
      NX_APPDEFINED, which should only be sent by fd_handler or
      timeout_handler.  */
   gobble_input (timeout ? 1 : 0);
   ev = last_appdefined_event;

   if ([ev type] != NSApplicationDefined) abort ();
   
   i = [ev data1];
   if (i == -2)
     {
       /* The NX_APPDEFINED event we recieved was the result of a timeout.  */
#ifdef AUTORELEASE
       [pool release];
#endif
      return 0;
      }
  else if (i == -1)
     {
       if (!timeout) {
#ifdef AUTORELEASE
		 [pool release];
#endif
		 return 0;
       } else
		 {
		   /* The NX_APPDEFINED event we recieved was the result of at least
			  one real input event arriving.  */
		   errno = EINTR;
#ifdef AUTORELEASE
		   [pool release];
#endif
		   return -1;
		 }
     }
  else if (i < 0 || i >= nfds)
     {
     abort ();
     }

   if (readfds)
      if (FD_ISSET (i, readfds))
         {
         FD_ZERO (readfds);
         FD_SET (i,readfds);
         }
      else
         FD_ZERO (readfds);

   if (writefds)
      if (FD_ISSET (i, writefds))
         {
         FD_ZERO (writefds);
         FD_SET (i,writefds);
         }
      else
         FD_ZERO (writefds);

   if (exceptfds)
      if (FD_ISSET (i, exceptfds))
         {
         FD_ZERO (exceptfds);
         FD_SET (i,exceptfds);
         }
      else
         FD_ZERO (exceptfds);

#ifdef AUTORELEASE
   [pool release];
#endif
   return 1;
   }

@implementation EmacsApp

- (void)timeout_handler: (NSTimer *)timedEntry
{
  /* The timeout specified to ns_select has passed.  */
  ns_send_appdefined (-2);
}

- (void)fd_handler:(NSNotification *)notification
   {
	 ns_send_appdefined ([[notification object] fileDescriptor]); 
   }

# if 0
- (int)runModalForWindow:(NSWindow *)theWindow
   {

     NSModalSession session = [NSApp beginModalSessionForWindow:theWindow];
     for (;;) {
       if ([NSApp runModalSession:session] != NSRunContinuesResponse)
	 break;
     }
     [NSApp endModalSession:session];
#if 0
   if ([self isRunning])
      return [super runModalForWindow:theWindow];
   else
      {
      int ret;
      ret=[super runModalForWindow:theWindow];
      return ret;
      }
#endif
   }
#endif

- (void)stopModal
{
  [super stopModal];
}

- (void)stopModalWithCode:(int)returnCode
{
  [super stopModalWithCode:returnCode];
}

- (void)abortModal
{
  [super abortModal];
}

- (int)runModalSession:(NSModalSession)session
   {
   if ([self isRunning])
      return [super runModalSession:session];
   else
      {
      int ret;
      ret=[super runModalSession:session];
      return ret;
      }
   }

-(int)openFile:(char *)fileName onHost:(char *)host atTrueLine:(int)line
   {
   return [self openFile:fileName onHost:host fromTrueLine:line to:line];
   }

-(int)openFile:(char *)fileName onHost:(char *)host fromTrueLine:(int)startLine to:(int)endLine;
   {
   struct frame *emacsframe=selected_frame;
   NSEvent *e=[NSApp currentEvent];

   if (eventsleft<=0) return NO;
   ns_input_file=append2(ns_input_file,build_string(fileName));

   if (startLine==endLine)
      ns_input_line=(startLine>=0) ? make_number(startLine) : Qnil;
   else
      ns_input_line=Fcons(make_number(startLine),make_number(endLine));

   events->kind=non_ascii_keystroke;
   events->modifiers=0;
   events->code=KEY_NS_OPEN_FILE_LINE;
   EV_TRAILER(e);
   return YES;
   }

- (int)application:sender openFile:(NSString *)file
   {
   struct frame *emacsframe=selected_frame;
   NSEvent *e=[NSApp currentEvent];

   if (eventsleft<=0) return NO;
   ns_input_file=append2(ns_input_file,build_string([file cString]));
   events->kind=non_ascii_keystroke;
   events->modifiers=0;
   events->code=KEY_NS_OPEN_FILE;
   EV_TRAILER(e);
   return YES;
   }

- (int)application:sender openTempFile:(NSString *)file;
   {
   struct frame *emacsframe=selected_frame;
   NSEvent *e=[NSApp currentEvent];

   if (eventsleft<=0) return NO;
   ns_input_file=append2(ns_input_file,build_string([file cString]));
   events->kind=non_ascii_keystroke;
   events->modifiers=0;
   events->code=KEY_NS_OPEN_TEMP_FILE;
   EV_TRAILER(e);
   return YES;
   }

- init
{
  [super init];
  [self setDelegate:self];
  return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
   {
   /* XXX Actually NXFilenamePboardType should be in there.  Unfortunately
      it is broken badly by some serious problems in the services code.  Disabling
      it breaks some services.  Unfortunately leaving it in there breaks a lot
      more at this time. XXX */
   
     NSApplication *theApplication = [notification object];
     ns_send_types = [[NSArray arrayWithObject:NSStringPboardType] retain];
     ns_return_types = [[NSArray arrayWithObject:NSStringPboardType] retain];
     ns_drag_types = [[NSArray arrayWithObjects:NSStringPboardType, NSTabularTextPboardType, NSFilenamesPboardType, NSColorPboardType, NSFontPboardType, nil] retain];

}

/* Stop ourself from running as soon as we have finished initialization.  We
   will actually run in ns_select's call to NXGetOrPeekEvent ().  */
- (void)applicationDidFinishLaunching:(NSNotification *)notification
   {
   NSApplication *theApplication = [notification object];
   [NSColor setIgnoresAlpha:NO];   

   send_appdefined = YES;
   ns_send_appdefined (-2);

  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(powerOff:)
	   name:NSWorkspaceWillPowerOffNotification
	  object:nil];


}

/* The function ns_select should remove all these events.  */
- (void)sendEvent:(NSEvent *)theEvent;
   {
     if ( [theEvent type] == NSApplicationDefined ) {
       last_appdefined_event = theEvent;
       [self stop:self];
     } else {
       [super sendEvent:theEvent];
     }
   }

- (void)powerOff:(NSNotificationCenter *)powerOff
   {
   /* XXX This does not work yet XXX */
   struct frame *emacsframe=selected_frame;
   NSEvent *e=[NSApp currentEvent];

   if (eventsleft<=0) return;
   events->kind=non_ascii_keystroke;
   events->modifiers=0;
   events->code=KEY_NS_POWER_OFF;
   EV_TRAILER(e);
   return;
   }

- menuDown:sender
   {
   if (selected_frame && selected_frame->output_data.ns->view)
      return [selected_frame->output_data.ns->view menuDown:sender];
   return nil;
   }

- (NSEvent *)getNextEvent: (int) mask
                 waitFor: (double) timeout
               threshold: (int) level
{
  if (!fake_event_p)
    return [super nextEventMatchingMask:mask untilDate:[NSDate dateWithTimeIntervalSinceNow:timeout] inMode:NSEventTrackingRunLoopMode dequeue:YES];

  fake_event_p = NO;
  return fake_event;
}

@end

@implementation EmacsView
- (void)changeFont:(id)sender
   {
   NSEvent *e=[[self window] currentEvent];
   struct face *face=FRAME_DEFAULT_FACE(emacsframe);
   id newFont;
   float size;

   if (eventsleft<=0) return;

   if (newFont=[sender convertFont:face->font->nsfont])
      {
      events->kind=non_ascii_keystroke;
      events->modifiers=0;
      events->code=KEY_NS_CHANGE_FONT;

      size=[newFont pointSize];
      if (size==rint(size))
         ns_input_fontsize=make_number((int)rint(size));
      else
         ns_input_fontsize=make_float(size);
      ns_input_font=build_string([[newFont fontName] cString]);
      EV_TRAILER(e);
      }
}

- (BOOL)acceptsFirstResponder
   {
   return YES;
   }

- (void)resetCursorRects
   {
   NSRect visible;
   if (!NSIsEmptyRect(visible = [self visibleRect]))
      [self addCursorRect:visible cursor:[NSCursor IBeamCursor]];
}

- (void)keyDown:(NSEvent *)theEvent 
   {
   int code;
   enum event_kind kind;
   int flags;

   if ( [theEvent type] != NSKeyDown ) 
     // Rhapsody is giving me an up and a down event for the arrow keys
     return;

   if (eventsleft <= 0)
      return;

   [NSCursor setHiddenUntilMouseMoves:YES];

   code=[[theEvent charactersIgnoringModifiers] characterAtIndex:0];
   kind=non_ascii_keystroke;
   flags=[theEvent modifierFlags];

   events->modifiers=0;
   if (flags & NSHelpKeyMask)
      {
      events->modifiers |= hyper_modifier;
      }
   if (flags & NSCommandKeyMask)
      {
      events->modifiers |= super_modifier;
      }
   if (!NILP(ns_alternate_is_meta) &&
       ((EQ(ns_alternate_is_meta,Qt) && (flags & NSAlternateKeyMask))||
        (EQ(ns_alternate_is_meta,Qleft) && (flags & NSAlternateKeyMask) && (flags & NSAlternateKeyMask))||
        (EQ(ns_alternate_is_meta,Qright) && (flags & NSAlternateKeyMask) && (flags & NSAlternateKeyMask))))
      {
      events->modifiers |= meta_modifier;
      flags&=~(NSAlternateKeyMask|NSAlternateKeyMask|NSAlternateKeyMask);
      code = char_from_key([theEvent keyCode],flags);
      }
   if ((flags & NSControlKeyMask) && (flags & NSShiftKeyMask))
     {
       events->modifiers |= ctrl_modifier;
       code |= 64;
       flags &= ~ (NSControlKeyMask | NSShiftKeyMask);
     }
   if ((flags & NSControlKeyMask) &&
       (code == char_from_key([theEvent keyCode],flags&~NSControlKeyMask)))
      {
      events->modifiers |= ctrl_modifier;
      flags&=~NSControlKeyMask;
      }
   if ((flags & NSShiftKeyMask) &&
       (code == char_from_key([theEvent keyCode],flags&~NSShiftKeyMask)))
      {
      events->modifiers |= shift_modifier;
      flags&=~NSShiftKeyMask;
      }

   if ((flags & NSNumericPadKeyMask) &&
       (char_is_type([theEvent keyCode],NSNumericPadKeyMask)))
      {
#define ARROW_KEY_HACK
#ifdef ARROW_KEY_HACK
      switch (code) {
      case NSDownArrowFunctionKey:
	code = 268566703;
	break;
      case NSUpArrowFunctionKey:
	code = 268566701;
	break;
      case NSLeftArrowFunctionKey:
	code = 268566700;
	break;
      case NSRightArrowFunctionKey:
	code = 268566702;
	break;
      default:
	code |= (1<<28)|(2<<16);
      }
#else
      code |= (1<<28)|(2<<16);
#endif
      }
#ifdef NOT_IMPLEMENTED
#error EventConversion: the '.data.key.charSet' field of NXEvent does not have an exact translation to an NSEvent method.  Possibly use [[theEvent characters] canBeConvertedToEncoding:...]
   else if ((theEvent.data.key.charSet==NX_DINGBATSSET) ||
#error EventConversion: the '.data.key.charSet' field of NXEvent does not have an exact translation to an NSEvent method.  Possibly use [[theEvent characters] canBeConvertedToEncoding:...]
            (theEvent.data.key.charSet==254))
      {
      code |= (1<<28)|(1<<16);
      }
#endif
   else
      {
      if ((code<0x20)&&(([theEvent modifierFlags]&NSControlKeyMask)==0))
         code |= (1<<28)|(3<<16);
      else if (code==0x7f)
         code |= (1<<28)|(3<<16);
      else
         kind=ascii_keystroke;
      }

   if (kind==ascii_keystroke && !NILP(ns_iso_latin) && (code>=0) && (code<256))
      code=ns2isomap[code];
   events->kind=kind;
   events->code=code;
   EV_TRAILER (theEvent);
}

/* This is what happens when the user presses the mouse button.  */
- (void)mouseDown:(NSEvent *)theEvent 
   {
   int x, y;
   NSPoint position;

   if (eventsleft <= 0) return;

   last_mouse_frame=emacsframe;
#if 0
   switch (EV_UDMODIFIERS(theEvent))
      {
    case up_modifier:
      break;
    case down_modifier:
      break;
      }
#endif

   position=[theEvent locationInWindow];
   position = [self convertPoint:position fromView:nil];
   events->kind = mouse_click;
   events->code = EV_BUTTON(theEvent);
   XSET (events->x, Lisp_Int, (int)rint(position.x));
   XSET (events->y, Lisp_Int, (int)rint(position.y));
   events->modifiers = EV_MODIFIERS (theEvent) | EV_UDMODIFIERS (theEvent);
   EV_TRAILER (theEvent);
}

/* This is what happens when the user releases the mouse button.  */
- (void)mouseUp:(NSEvent *)theEvent 
   {
   [self mouseDown:theEvent];
}

- (void)rightMouseDown:(NSEvent *)theEvent 
   {
   [self mouseDown:theEvent];
}

- (void)rightMouseUp:(NSEvent *)theEvent 
   {
   [self mouseDown:theEvent];
}

/* Tell emacs the mouse has moved.  */
- (void)mouseMoved:(NSEvent *)e 
{
  NSPoint p=[e locationInWindow];

  p = [self convertPoint:p fromView:nil];
  last_mouse_movement_time = EV_TIMESTAMP (e);

  note_mouse_movement (emacsframe, p.x, p.y);
  if (emacsframe->mouse_moved && send_appdefined)
    ns_send_appdefined (-1);
}

- (void)mouseDragged:(NSEvent *)e 
   {
   [self mouseMoved:e];
}

- (void)rightMouseDragged:(NSEvent *)e 
   {
   [self mouseMoved:e];
}

- (BOOL)windowShouldClose:(id)sender
   {
   NSEvent *e=[[self window] currentEvent];

   if (ns_window_num<=1) return NO;
   if (eventsleft <= 0) return NO;
   events->kind=delete_window_event;
   events->modifiers=0;
   events->code=0;
   EV_TRAILER (e);
   /* Don't close this window, let this be done from lisp code.  */
   return NO;
   }

#if 1
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
   {
   NSRect r;
   char *size;
   int rows,cols;
   int vbextra=FRAME_HAS_VERTICAL_SCROLL_BARS(emacsframe) ?
               rint(FRAME_SCROLL_BAR_PIXEL_WIDTH (emacsframe) > 0
                    ? FRAME_SCROLL_BAR_PIXEL_WIDTH (emacsframe)
                    : (FRAME_SCROLL_BAR_COLS(emacsframe)
                       *FONT_WIDTH(emacsframe->output_data.ns->font))) : 0;

   cols=rint((frameSize.width-
              emacsframe->output_data.ns->border_width-
              2*emacsframe->output_data.ns->internal_border_width-
              vbextra)/FONT_WIDTH(emacsframe->output_data.ns->font));
   if (cols<MINWIDTH) cols=MINWIDTH;
   frameSize.width=(cols*FONT_WIDTH(emacsframe->output_data.ns->font)+
                     emacsframe->output_data.ns->border_width+
                     2*emacsframe->output_data.ns->internal_border_width+
                     vbextra);

   rows=rint((frameSize.height-
              emacsframe->output_data.ns->border_height-
              2*emacsframe->output_data.ns->internal_border_width)/
             emacsframe->output_data.ns->line_height);
   if (rows<MINHEIGHT) rows=MINHEIGHT;
   frameSize.height=(rows*emacsframe->output_data.ns->line_height+
                      emacsframe->output_data.ns->border_height+
                      2*emacsframe->output_data.ns->internal_border_width);

   r = [[self window] frame];
   if (r.size.height == frameSize.height && r.size.width == frameSize.width)
      {
      if (old_title!=0)
         {
         [[self window] setTitle:[NSString stringWithCString:old_title]];
         xfree(old_title);
         old_title=0;
         }
      }
   else
      {
      if (old_title==0)
         {
         const char *t=[[[self window] title] cString];
         old_title=(char *) xmalloc(strlen(t)+1);
         strcpy(old_title,t);
         }
      size=alloca(strlen(old_title)+20);
      sprintf(size,"%s (%dx%d)",old_title,cols,rows);
      [[self window] setTitle:[NSString stringWithCString:size]];
      }
   return frameSize;
   }
#endif

- (void)windowDidResize:(NSNotification *)notification
   {
   NSWindow *theWindow = [notification object];
    if (old_title!=0)
      {
      [[self window] setTitle:[NSString stringWithCString:old_title]];
      xfree(old_title);
      old_title=0;
      }
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
  int val;
  ns_highlight_frame=emacsframe;
  if ((val=ns_lisp_to_cursor_type(get_frame_param(emacsframe, Qcursor_type)))>=0)
    {
      emacsframe->output_data.ns->desired_cursor=val;
      ns_dumpglyphs(emacsframe,0,0,0,0,-1);
      ns_dumpcursor(emacsframe,emacsframe->cursor_x,emacsframe->cursor_y);
    }

}

- (void)windowDidResignKey:(NSNotification *)notification
   {
   NSWindow *theWindow = [notification object];
    emacsframe->output_data.ns->desired_cursor = hollow_box;
   ns_dumpglyphs(emacsframe,0,0,0,0,-1);
   ns_dumpcursor(emacsframe,emacsframe->cursor_x,emacsframe->cursor_y);
   if (ns_highlight_frame==emacsframe)
      ns_highlight_frame=0;
}

- (void)windowWillMiniaturize:sender
{
  NSScreen *screen = [[self window] screen];
  
#ifdef NOT_IMPLEMENTED
  if (NUMBERP (emacsframe->output_data.ns->icon_top) &&
      NUMBERP (emacsframe->output_data.ns->icon_left))
    [miniwindow setFrameTopLeftPoint:NSMakePoint(SCREENMAXBOUND(XFLOATINT (emacsframe->output_data.ns->icon_left)), SCREENMAXBOUND([screen frame].size.height -
                                XFLOATINT (emacsframe->output_data.ns->icon_top)))];
#endif
  [self setMiniwindowImage];
}

- (BOOL)isFlipped
{
  return YES;
}

- (BOOL)isOpaque
{
  return YES;
}

- initFrameFromEmacs:(struct frame *)f
   {
   NSRect r, wr;
   Lisp_Object tem;
   NSWindow * win;
   int vbextra=FRAME_HAS_VERTICAL_SCROLL_BARS(f) ?
               rint(FRAME_SCROLL_BAR_PIXEL_WIDTH (f) > 0
                    ? FRAME_SCROLL_BAR_PIXEL_WIDTH (f)
                    : (FRAME_SCROLL_BAR_COLS (f)
                       *FONT_WIDTH(f->output_data.ns->font))) : 0;

   r.origin.x   =f->output_data.ns->internal_border_width;
   r.origin.y   =f->output_data.ns->internal_border_width;
   r.size.width =rint(FONT_WIDTH(f->output_data.ns->font)*f->width);
   r.size.height=rint(f->output_data.ns->line_height*f->height);
   [self initWithFrame:r];

   f->output_data.ns->view=self;
   emacsframe=f;
   old_title=0;
   
   r.origin.x=r.origin.y=0;
   r.size.width +=2*f->output_data.ns->internal_border_width+vbextra;
   r.size.height+=2*f->output_data.ns->internal_border_width;

   win=[[NSWindow alloc] initWithContentRect:r styleMask:NSResizableWindowMask|NSMiniaturizableWindowMask|
                                  NSClosableWindowMask backing:(NILP(get_frame_param(f,Qbuffered)) ?
                                NSBackingStoreRetained :NSBackingStoreBuffered) defer:YES];

   wr = [win frame];
   f->output_data.ns->border_width=wr.size.width-r.size.width;
   f->output_data.ns->border_height=wr.size.height-r.size.height;

   [win setAcceptsMouseMovedEvents:YES];
   [win setDelegate:self];
   [win useOptimizedDrawing:YES];

   [[win contentView] addSubview:self];
   [[self superview] setAutoresizesSubviews:NO];

   if (ns_drag_types)
      {
      [self registerForDraggedTypes:ns_drag_types];
      }

   tem=f->name;
   if (!NILP(tem)) [win setTitle:[NSString stringWithCString:XSTRING(tem)->data]];

   tem=f->icon_name;
   if (!NILP(tem)) [win setMiniwindowTitle:[NSString stringWithCString:XSTRING(tem)->data]];

       {
       NSScreen *screen=[win screen];

       if (screen!=0)
          [win setFrameTopLeftPoint:NSMakePoint(BOUND(-SCREENMAX,f->output_data.ns->left,SCREENMAX), BOUND(-SCREENMAX,[screen frame].size.height
                                   -f->output_data.ns->top,SCREENMAX))];
       }

   [win makeFirstResponder:self];
   [win setBackgroundColor:NS_FACE_BACKGROUND(FRAME_DEFAULT_FACE(emacsframe))];

   [self allocateGState];
   [self setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

   ns_adjust_size(emacsframe);

///   [win makeKeyAndOrderFront:self];
//   [win display];

   ns_window_num++;

#if 0
      {
      Lisp_Object rest;
      struct frame *f;
      
      for (rest=Vframe_list; CONSP(rest); rest=XCONS(rest)->cdr)
         if (FRAME_NS_P(f=XFRAME(XCONS(rest)->car)))
            [[f->output_data.ns->view window] setCloseButton:NSApp to:(ns_window_num>1)];
      }
#endif
   return self;
   }

- (void)windowDidMove:sender
   {
   NSWindow *win=[self window];
   NSRect r;
   NSScreen *screen;

   if (!emacsframe->output_data.ns) return ;
   r = [win frame];
   screen=[win screen];
   if (screen!=0)
      {
      emacsframe->output_data.ns->left=r.origin.x;
      emacsframe->output_data.ns->top=[screen frame].size.height-
                                   (r.origin.y+r.size.height);
      }
   /* Terminate the event loop.  */
   if (send_appdefined) ns_send_appdefined (-1);
   return;
   }

- (void)windowDidDeminiaturize:sender
   {
   NSEvent *e=[[self window] currentEvent];
   NSRect r;
   NSScreen *screen = [[self window] screen];

   if (!emacsframe->output_data.ns) return;
   emacsframe->async_visible   = 1;
   emacsframe->async_iconified = 0;
   windows_or_buffers_changed++;
   // save the position where the user left the miniwindow
#ifdef NOT_IMPLEMENTED
   r = [[[self window] counterpart] frame];
   XSETINT (emacsframe->output_data.ns->icon_top,
            [screen frame].size.height - NSMaxY(r));
   XSETINT (emacsframe->output_data.ns->icon_left, NSMinX(r));
#endif
   if ([[self window] windowNumber] > 0)
     ns_adjust_tracking_rects (emacsframe);
   return;
   }

- (void)windowDidExpose:sender
   {
   if (!emacsframe->output_data.ns) return;
   emacsframe->async_visible = 1;
   SET_FRAME_GARBAGED (emacsframe);
   /* Terminate the event loop.  */
   if (send_appdefined) ns_send_appdefined (-1);
   return;
   }

- (void)windowDidMiniaturize:sender
   {
   if (!emacsframe->output_data.ns) return;
   if (emacsframe->output_data.ns->view == mouse_face_tracked_view)
     ns_remove_mouse_tracking ();
   emacsframe->async_iconified = 1;
   /* Terminate the event loop.  */
   if (send_appdefined) ns_send_appdefined (-1);
   return;
   }

- (void)mouseEntered:(NSEvent *)theEvent 
{
  NSPoint p=[theEvent locationInWindow];
  NSRect r;

  p = [self convertPoint:p fromView:nil];
  last_mouse_movement_time = EV_TIMESTAMP (theEvent);

  if ([theEvent trackingNumber] == FRAME_TRACKNUM ) {
    if (emacsframe && emacsframe->auto_raise
	&& !emacsframe->iconified && !emacsframe->async_iconified)
      {
	[[self window] makeKeyAndOrderFront:NSApp];
      }
  } else if ([theEvent trackingNumber] == WINDOW_TRACKNUM ) {
    note_mouse_movement (emacsframe, p.x, p.y);
    
    note_mouse_highlight (emacsframe, p.x, p.y);
    ns_set_mouse_tracking (self);
  } else if ([theEvent trackingNumber] == MOUSE_FACE_TRACKNUM ) {
    // this can't happen, I guess... (cl)
    note_mouse_movement (emacsframe, p.x, p.y);
    
    note_mouse_highlight (emacsframe, p.x, p.y);
    ns_set_mouse_tracking (self);
  }
  return;
}

- (void)mouseExited:(NSEvent *)theEvent 
{
  NSPoint p=[theEvent locationInWindow];
  NSRect r;

  last_mouse_movement_time = EV_TIMESTAMP (theEvent);

  if ([theEvent trackingNumber] == FRAME_TRACKNUM ) {
    if (emacsframe && emacsframe->auto_lower
	&& !emacsframe->iconified && !emacsframe->async_iconified)
      {
	[[self window] orderBack:NSApp]; /* XXX unfocus ! */
      }
  } else if ([theEvent trackingNumber] == WINDOW_TRACKNUM ) {
    if (self == mouse_face_tracked_view)
      ns_remove_mouse_tracking ();
    if (emacsframe == mouse_face_mouse_frame)
      clear_mouse_face ();
  } else if ([theEvent trackingNumber] == MOUSE_FACE_TRACKNUM ) {
    p = [self convertPoint:p fromView:nil];
    
    note_mouse_movement (emacsframe, p.x, p.y);
    
    note_mouse_highlight (emacsframe, p.x, p.y);
    r = [self bounds];
    if (emacsframe == mouse_face_mouse_frame &&
	[self mouse:p inRect:r] && !mouse_face_defer &&
	!mouse_face_deferred_gc)
      ns_set_mouse_tracking (self);
    else if (self == mouse_face_tracked_view)
      ns_remove_mouse_tracking ();
  }
  return;
}

- menuDown:sender
   {
   NSEvent *theEvent;
   NSPoint p;
   int x,y;
   EmacsMenuObject *obj;

   if (eventsleft<=0) return self;
   theEvent=[[self window] currentEvent];
   ns_menu_path=Qnil;

   for(obj=[sender representedObject]; obj!=nil;
       obj=[[obj supercell] representedObject])
      ns_menu_path = Fcons([obj value],ns_menu_path);

   p = [[self window] mouseLocationOutsideOfEventStream];
   p = [self convertPoint:p fromView:nil];

   events->kind = mouse_click;
   XSET (events->code, Lisp_Int, 0);
   events->modifiers=EV_MODIFIERS(theEvent)|down_modifier;
   XSET (events->x, Lisp_Int, (int)rint(p.x));
   XSET (events->y, Lisp_Int, -1);
   EV_TRAILER(theEvent);

   return self;
   }

- (void)drawRect:(NSRect)rects
   {
   if (!emacsframe->output_data.ns) return;

   emacsframe->async_visible = 1;
   emacsframe->async_iconified = 0;
   ns_adjust_size(emacsframe);

   /* Terminate the event loop.  */
   if (send_appdefined) ns_send_appdefined (-1);
   return ;
   }

/* NXDraggingDestination protocol methods.  Actually this is not really a
   protocol, but a category of Object.  O well...  */

-(unsigned int) draggingEntered:(id <NSDraggingInfo>) sender
   {
   return NSDragOperationGeneric;
   }

-(BOOL)performDragOperation:(id <NSDraggingInfo>) sender
   {
   id pb;
   int i,x,y;
   NSString *type;
   NSEvent *theEvent=[[self window] currentEvent];
   NSPoint position;

   position=[theEvent locationInWindow];
   position = [self convertPoint:position fromView:nil];
   pixel_to_glyph_coords (emacsframe, (int)rint(position.x),
                             (int)rint(position.y), &x, &y, 0, 1);

   pb = [sender draggingPasteboard];
   type = [pb availableTypeFromArray:ns_drag_types];
   if (type==0)
     {
       return NO;
     }
   else if ([type isEqualToString:NSFilenamesPboardType])
     {
       NSArray *files;
       NSEnumerator *fenum;
       NSString *file;

       if (!(files = [pb propertyListForType:type]))
         return NO;
	 
       fenum = [files objectEnumerator];
       while ( file = [fenum nextObject] ) {
	 events->kind=non_ascii_keystroke;
	 events->code=KEY_NS_DRAG_FILE;
	 XSET(events->x, Lisp_Int, x);
	 XSET(events->y, Lisp_Int, y);
	 ns_input_file=append2(ns_input_file, build_string([file cString]));
	 events->modifiers=EV_MODIFIERS(theEvent);
	 EV_TRAILER(theEvent);
       }
	 

       return YES;
     }
   else if ([type isEqualToString:NSStringPboardType] 
	    || [type isEqualToString:NSTabularTextPboardType])
     {
      NSString *data;

      if (! (data = [pb stringForType:type]))
         return NO;

      events->kind=non_ascii_keystroke;
      events->code=KEY_NS_DRAG_ASCII;
      XSET(events->x, Lisp_Int, x);
      XSET(events->y, Lisp_Int, y);
      ns_input_ascii=build_string([data cString]);
      events->modifiers=EV_MODIFIERS(theEvent);
      EV_TRAILER(theEvent);

      return YES;
      }
   else if ([type isEqualToString:NSColorPboardType])
      {
      NSColor * c=[NSColor colorFromPasteboard:pb];
      events->kind=non_ascii_keystroke;
      events->code=KEY_NS_DRAG_COLOR;
      XSET(events->x, Lisp_Int, x);
      XSET(events->y, Lisp_Int, y);
      ns_input_color=ns_color_to_lisp(c);
      events->modifiers=EV_MODIFIERS(theEvent);
      EV_TRAILER(theEvent);
      return YES;
      }
   else
      {
      error("Invalid data type in dragging pasteboard.");
      return NO;
      }
   }

- validRequestorForSendType:(NSString *)typeSent returnType:(NSString *)typeReturned
   {
   int i;


   if ( [ns_send_types indexOfObjectIdenticalTo:typeSent] != NSNotFound )
     return self;

   if ( [ns_return_types indexOfObjectIdenticalTo:typeSent] != NSNotFound )
     return self;

   return [[self window] validRequestorForSendType:typeSent returnType:typeSent];
   }

- setMiniwindowImage
{
  id image = [[self window] miniwindowImage];
  if (image == emacsframe->output_data.ns->miniimage)
    return self;
  if (image && [image isKindOfClass:[EmacsImage class]])
    [image release];
  [[self window] setMiniwindowImage:emacsframe->output_data.ns->miniimage];
  return self;
}
@end

@implementation EmacsScroller
- initFrame:(NSRect )r window:(Lisp_Object)nwin
   {
   struct frame *f;
   id view;

   [super initWithFrame:r];
   [self setTarget:self];
   [self setAction:@selector(scrollerMoved:)];
   [self setArrowsPosition:NSScrollerArrowsNone];
#ifdef NOT_IMPLEMENTED
   [self setAutosizing:NSViewMinXMargin|NSViewHeightSizable];
   [self setAutodisplay:YES];
#endif
   [self setContinuous:YES];
   [self setEnabled:YES];

   win=nwin;
   staticpro(&win);
   condemned=NO;

   f=XFRAME(XWINDOW (win)->frame);
   if (FRAME_LIVE_P(f))
      {
      view=f->output_data.ns->view;
      [[[view window] contentView] addSubview:self];
      }

   [self setFrame:r];
   return self;
   }

- (void)setFrame:(NSRect)r
   {
   struct frame *f=XFRAME(XWINDOW (win)->frame);
   id view=FRAME_LIVE_P(f) ? f->output_data.ns->view : 0;
   NSRect s,t;

   s = [self frame];
   t=r;
   [super setFrame:t];
   if (NSEqualRects(t , s) || !view) return;
   ns_reset_clip(view);

      {
      int i;
      id sview=[self superview];
      NSArray *subs = [sview subviews];
      NSView *v;

      [sview lockFocus];
      [NS_FACE_BACKGROUND(FRAME_DEFAULT_FACE(f)) set];
      NSRectFill(s);
      [sview unlockFocus];
      [self display];

      for (i=[subs count]-1; i>=0; i--)
         {
         v=[subs objectAtIndex:i];
         if (v==view || v==self) continue;
         t = [v frame];
         if (NSIsEmptyRect(NSIntersectionRect(t , s))) continue;
         [v display];
         }
      }

   return;
   }

- (void)dealloc
   {
   [self setFrame:[self frame]];
   if (!NILP(win)) XWINDOW (win)->vertical_scroll_bar = Qnil;
//   staticunpro(&win);
   { [super dealloc]; return; };
   }

#ifndef NOT_IMPLEMENTED
- scrollerMoved:sender
   {
   NSEvent *e=[[self window] currentEvent];
   if (eventsleft <= 0) return nil;
   events->kind = scroll_bar_click;
   events->part = scroll_bar_handle;
   if (_curValue>0.999)
      {
      XSET (events->x, Lisp_Int, SHRT_MAX);
      XSET (events->y, Lisp_Int, SHRT_MAX);
      }
   else
      {
      XSET (events->x, Lisp_Int, SHRT_MAX*(_curValue*(1.0-_percent)));
      XSET (events->y, Lisp_Int, SHRT_MAX);
      }
   events->code=0;
   events->modifiers=EV_MODIFIERS(e) | up_modifier;
   events->frame_or_window=win;
   events->timestamp=EV_TIMESTAMP (e);
   events++;
   eventsleft--;
   if (send_appdefined) ns_send_appdefined (-1);
   return self;
   }
#endif

- setPosition:(int) position portion:(int) portion whole:(int) whole
   {
   if (portion>=whole)
      [self setFloatValue:0.0 knobProportion:1.0];
   else
      {
      double start=((double)position)/whole;
      double end=((double)position+portion)/whole;
      [self setFloatValue:start/(1.0-(end-start)) knobProportion:end-start];
      }
   }

- condemn
   {
   condemned=YES;
   return self;
   }

- reprieve
   {
   condemned=NO;
   return self;
   }

- judge
   {
     if ( condemned ) {
       [self removeFromSuperview];
       [self release];
     }
   }

/* Asynchronous mouse tracking for scroller.  This allow us to dispatch
   mouseDragged events without going into a modal loop.  */

- (void)mouseDown:(NSEvent *)e 
{
  NSRect r;

  /* Fake a NX_LMOUSEUP event in the next call to
     `getNextEvent:waitFor:threshold:'.  This is made from our super's
     trackKnob: method which will then exit it's modal loop after calling
     our `scrollerMoved:' method.  */
  fake_event_p = YES;

  fake_event = [NSEvent mouseEventWithType:NX_LMOUSEUP
				  location:[e locationInWindow] 
			     modifierFlags:[e modifierFlags] 
				 timestamp:[e timestamp] 
			      windowNumber:[e windowNumber]
				   context:[e context]
			       eventNumber:[e eventNumber]
				clickCount:[e clickCount]
				  pressure:[e pressure]];  

  /* Get the rect of the Scroller's knob in the screens coordinate system.  */
  r = [self rectForPart:NSScrollerKnob];
  [self convertRect:r toView:nil];

  if (NSMinY(r) <= [e locationInWindow].y && [e locationInWindow].y <= NSMaxY(r))
    {
      /* Compute the relative offset in the knob of the mousedown.  */
      last_mouse_offset = ([e locationInWindow].y - NSMinY(r)) / NSHeight(r);
    }
  else
    {
      /* XXX The mouse down is outside the knob, so pretend it's in the
         middle of the knob.  Since the knob will move there.  */
      last_mouse_offset = 0.5;
    }

  return [super mouseDown: fake_event];
}

- (void)mouseDragged:(NSEvent *)e 
{
  NSRect r;
  NSPoint location;

  /* Get the rect of the Scroller's knob in the screens coordinate system.  */
  r = [self rectForPart:NSScrollerKnob];
  r = [self convertRect:r toView:nil];

  /* First we generate a NX_LMOUSEDOWN event on the position the mouse last
     was.  */

  /* Make the mousedown happen at the same relative offset from the bottom
     of the knob as the initial mousedown.  */

  /* Fake a NX_LMOUSEUP event in the next call to
     `getNextEvent:waitFor:threshold:'.  This is called from our super's
     trackKnob: method which will then exit it's modal loop after calling
     our `scrollerMoved:' method.  */
  fake_event_p = YES;

  /* Move the x coordinate of the mouse up event into the frame of
     the scrollbar handle.  */

  location = NSMakePoint(r.origin.x + r.size.width / 2, 
			   NSMinY(r) + last_mouse_offset * NSHeight(r));

  fake_event = [NSEvent mouseEventWithType:NX_LMOUSEDOWN
				  location:[e locationInWindow] 
			     modifierFlags:[e modifierFlags] 
				 timestamp:[e timestamp] 
			      windowNumber:[e windowNumber]
				   context:[e context]
			       eventNumber:[e eventNumber]
				clickCount:[e clickCount]
				  pressure:[e pressure]];  

  return [super mouseDown:fake_event];
}

@end


