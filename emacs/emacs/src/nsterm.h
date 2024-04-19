/* Definitions and headers for communication with NeXTstep
   Copyright (C) 1989, 1993 Free Software Foundation, Inc.

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
the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */

#include "config.h"

#ifdef HAVE_NS

#ifdef __OBJC__
#import <AppKit/AppKit.h>
#import <Foundation/NSDistantObject.h>

@interface NSMenu (UndocumentedMenu)
- (void)_restoreInitialMenuPos;
- (void)_saveInitialMenuPos;
@end

@interface NSSavePanel (UndocumentedSavePanel)
- (BOOL)_validateNames:(char *)name checkBrowser:(BOOL)check;
@end

/* These two interfaces were ruthlessly stolen from John C. Randolph */
@interface NSView (windowButtons)
- _setMask:(unsigned int) mask;
@end

@interface NSWindow (windowButtons)
- toggleClose:sender;
- toggleMiniaturize:sender;
- setCloseButton:sender to:(BOOL)bool;
- setMiniaturizeButton:sender to:(BOOL)bool;
- showCloseButton:sender;
- showMiniaturizeButton:sender;
- hideCloseButton:sender;
- hideMiniaturizeButton:sender;
- updateBorder;
@end

@protocol Interrupt
-(oneway void)interrupt;
@end

@protocol BaseValueGetting
-(int)numSubValues;
-(id <BaseValueGetting>)subValueAt:(int)nValue;
-(id <BaseValueGetting>)subValueAt:(int)nValue withFlags:(out unsigned *)pFlags andName:(out char **)pName;
-(id <BaseValueGetting>)subValueNamed:(in char *)valueName index:(out int *)index;
-(id <BaseValueGetting>)subValueFor:(id <BaseValueGetting>)value from:(int *)from index:(int *)index;
@end

@protocol Value <BaseValueGetting>
-(char *)valueName;
-(unsigned)size;
-(unsigned)scalerValueFrom:(unsigned)from;
-(float)floatValueFrom:(unsigned)from;
-(char *)enumValueFrom:(unsigned)from;
-(char *)stringValueFrom:(unsigned)from;
-(char *)functionValueFrom:(unsigned)from;
-(unsigned)addressFrom:(unsigned)from;
-(unsigned)addressFrom:(unsigned)from isValid:(out int *)isValid;
-(unsigned)flags;
-(char *)typeName;
-(int)castToTypeNamed:(in char *)typeName from:(unsigned)from;
@end

@protocol Frame <BaseValueGetting>
-(int)hasSymbols;
-(char *)functionName;
-(char *)functionNameAndHasSymbols:(int *)hasSymbols;
-(unsigned)frame;
-(unsigned)pc;
-(char *)fileNameAndLine:(unsigned *)line;
-(int)frameNumber;
@end

@protocol Breakpoint
-(char *)fileName;
-(int)line;
-(BOOL)enabled;
-(char *)commands;
-(char *)condition;
-(char *)expression;
-(char *)function;
@end


#define ISPOINTER   (1 << 0)
#define ISENUM      (1 << 1)
#define ISSCALER    (1 << 2)
#define ISFLOAT     (1 << 3)
#define ISDOUBLE    (1 << 4)
#define ISAGGREGATE (1 << 5)
#define ISCHAR	    (1 << 6)
#define ISARRAY     (1 << 7)
#define ISSIGNED    (1 << 8)
#define ISOBJECT    (1 << 9)
#define ISSTRING    (1 << 10)
#define ISFUNC      (1 << 11)

@protocol PBUser
-(oneway void)openFile:(char *)fileName onHost:(char *)hostName atTrueLine:(int)line;
-(oneway void)openFile:(char *)fileName onHost:(char *)hostName fromTrueLine:(int)startLine to:(int)endLine;
@end

@interface EmacsApp :NSApplication
   {
   id emacsListener;
   }

-(int)openFile:(char *)fileName onHost:(char *)hostName atTrueLine:(int)line;
-(int)openFile:(char *)fileName onHost:(char *)hostName fromTrueLine:(int)startLine to:(int)endLine;
- (int)application:sender openFile:(NSString *)filename;
- (int)application:sender openTempFile:(NSString *)filename;

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
- (void)applicationDidFinishLaunching:(NSNotification *)notification;

-menuDown:sender;

#if 0
- (void)pasteboardChangedOwner:(NSPasteboard *)sender;
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
#endif
@end

@interface EmacsView :NSView
   {
   struct frame *emacsframe;
   char *old_title;
   }

- menuDown:sender;
- initFrameFromEmacs:(struct frame *)f;
- setMiniwindowImage;

@end

@interface EmacsMenu :NSMenu
   {
   int minmarked;
   id supercell;
   BOOL wasVisible;
   }

- addItem:(Lisp_Object)val string:(Lisp_Object)aString bind:(Lisp_Object)bind;

- (id <NSMenuItem>)addMinItemWithTitle:(NSString *)aString 
				action:(SEL)aSelector 
			 keyEquivalent:(NSString *)charCode;

- adjustMap:(Lisp_Object)keymap;
- (void)adjustKey:(Lisp_Object)key binding:(Lisp_Object)bind;
- (void)adjustKey:(Lisp_Object)key binding:(Lisp_Object)bind string:(Lisp_Object)string;
- findCell:(Lisp_Object)value;
- (int)findCellNumber:(Lisp_Object)value;
- transferCell:(id)cell to:newmenu;

- removeCell:cell;

- supercell;
- setSupercell:(id) nsupercell;

- mark;
- freeMarked;

- swapin;
- swapout;
@end

@interface EmacsMenuObject:NSObject
{
  Lisp_Object value;
  id supercell;
}

- (Lisp_Object)value;
- setValue:(Lisp_Object)nvalue;
- supercell;
- setSupercell:(id) nsupercell;
@end

#if 1
// this is from 4.1
@interface EmacsMenuCard : NSPopUpButton
-init;
-addTitle: (char *)name;
-addItem:  (char *)name value:(Lisp_Object)val enabled:(BOOL)enabled;
@end

@interface EmacsMenuPanel: NSPanel
   {
   NSMutableArray *list;
   int maxwidth;
   }
- initFromMenu:(Lisp_Object)menu;
- addItem:(char *)str value:(Lisp_Object)val enabled:(BOOL)enabled at:(int)pane;
- addTitle:(char *)str to:(int)pane;
- (int)cards;
- (Lisp_Object)runMenuAt:(float)x:(float)y;
@end
#else
// this is from 4.1.2
@interface EmacsPopupMenu:EmacsMenu
   {}
- (BOOL)windowShouldClose:(id)sender;
- menuFromKeymap:sender;
- menuFromList:sender;
- addItem:(Lisp_Object)val string:(Lisp_Object)aString bind:(Lisp_Object)bind;
- initFromMenu:(Lisp_Object)def;
- (Lisp_Object)runMenuAt:(float)x:(float)y;
@end
#endif

@interface EmacsDialogPanel:NSPanel
   {
   NSTextField *command;
   NSTextField *title;
   NSMatrix *matrix;
   int rows,cols;
   }
- initFromContents:(Lisp_Object)menu;
- addButton:(char *)str value:(Lisp_Object)val row:(int)row;
- addString:(char *)str row:(int)row;
- addSplit;
- (Lisp_Object)runDialogAt:(float)x:(float)y;
@end

@interface EmacsImage : NSImage
{
  id imageListNext;
  int refCount;
  NSImage *stippleRep;
}
+ allocInitFromFile:(Lisp_Object)file;
- reference;
- imageListSetNext:(id)arg;
- imageListNext;
- (void)dealloc;
- initFromXBM:(unsigned char *)bits width:(int)w height:(int)h;
- initFromSkipXBM:(unsigned char *)bits width:(int)w height:(int)h
           length:(int)length;
- prepareForStippling;
- (NSImage *)stippleRep;
@end

@interface EmacsFilePanel:NSOpenPanel
  {
  BOOL allowCreate,allowOld,allowDir;
  }
- setAllowCreate:(BOOL)ifAllowCreate;
- setAllowOld:(BOOL)ifAllowOld;
- setAllowDir:(BOOL)ifAllowDir;
@end

@interface EmacsScroller:NSScroller
   {
   Lisp_Object win;

   /* The offset to the bottom of the knob of the last mouse
      down normalized to the knob height.  */
   float last_mouse_offset;

   BOOL condemned;
   }
- initFrame:(NSRect )r window:(Lisp_Object)win;
- (void)setFrame:(NSRect)r;
- (void)dealloc;

- scrollerMoved:sender;
- setPosition:(int) position portion:(int) portion whole:(int) whole;

- condemn;
- reprieve;
- judge;
@end

extern id ns_current_display;
extern id ns_emacscolors;
extern int ns_use_open_panel;
extern int ns_use_yes_no_panel;
extern Lisp_Object ns_alternate_is_meta,ns_iso_latin,ns_cursor_blink_rate;
extern Lisp_Object ns_shrink_space;
extern Lisp_Object ns_menu_path;
extern unsigned char *ns2isomap;
extern unsigned char *iso2nsmap;
extern NSArray *ns_send_types,*ns_return_types;
extern struct frame *ns_highlight_frame;
extern struct frame *ns_focus_frame;
extern struct frame *ns_focus_event_frame;
#endif

enum ns_highlight_kinds
   {
   no_highlight=0,
   filled_box,
   hollow_box,
   bar,
   line
   };

struct ns_display_info
{
  /* Chain of all ns_display_info structures.  */
  struct ns_display_info *next;

  /* This is a cons cell of the form (NAME . FONT-LIST-CACHE).
     The same cons cell also appears in ns_display_name_list.  */
  Lisp_Object name_list_element;


  /* A table of all the fonts we have already loaded.  */
  struct font_info *font_table;

  /* The current capacity of x_font_table.  */
  int font_table_size;

  /* The number of fonts actually stored in x_font_table.
     font_table[n] is used and valid iff 0 <= n < n_fonts.
     0 <= n_fonts <= font_table_size.  */
  int n_fonts;

#ifdef MULTI_KBOARD
  struct kboard *kboard;
#endif
};

/* This is a chain of structures for all the NS displays currently in use.  */
extern struct ns_display_info *ns_display_list;

extern Lisp_Object ns_display_name_list;

extern struct ns_display_info *ns_display_info_for_display ();
extern struct ns_display_info *ns_display_info_for_name ();

extern struct ns_display_info *ns_term_init ();

struct ns_output
   {
#ifdef __OBJC__
   id view;
   id miniimage;
   NSColor * current_cursor_color;
   NSColor * desired_cursor_color;
   NSColor *foreground_color;
   NSColor *background_color;
#else
   void *view;
   void *miniimage;
   void *current_cursor_color;
   void *desired_cursor_color;
#endif
//   struct face *face;
   XFontStruct *font;
   float top;
   float left;
   Lisp_Object icon_top;
   Lisp_Object icon_left;
   int line_height;
   float internal_border_width;
   float border_width, border_height;
   enum ns_highlight_kinds current_cursor, desired_cursor;

   /* The size of the extra width currently allotted for vertical
      scroll bars, in pixels.  */
   int vertical_scroll_bar_extra;
   
  /* Table of parameter faces for this frame.  Any NS resources (pixel
      values, fonts) referred to here have been allocated explicitly
      for this face, and should be freed if we change the face.  */
   struct face **param_faces;
   int n_param_faces;

   /* Table of computed faces for this frame.  These are the faces
      whose indexes go into the upper bits of a glyph, computed by
      combining the parameter faces specified by overlays, text
      properties, and what have you.  The NS resources mentioned here
      are all shared with parameter faces.  */
   struct face **computed_faces;
   int n_computed_faces;                /* How many are valid */
   int size_computed_faces;     /* How many are allocated */

  /* This is the Emacs structure for the NS display this frame is on.  */
  struct ns_display_info *display_info;

};

#define FRAME_FOREGROUND_COLOR(f) ((f)->output_data.ns->foreground_color)
#define FRAME_BACKGROUND_COLOR(f) ((f)->output_data.ns->background_color)
#define NS_FACE_FOREGROUND(f) ((NSColor *)f->foreground)
#define NS_FACE_BACKGROUND(f) ((NSColor *)f->background)
#define NS_FONT_WIDTH(f)	((f)->width)
#ifndef COMPILING_MULTI_TERM
#define FONT_WIDTH(f)	((f)->width)
#define FONT_HEIGHT(f)	((f)->height)

/* Get at the computed faces of an NS window frame.  */
#define FRAME_PARAM_FACES(f) ((f)->output_data.ns->param_faces)
#define FRAME_N_PARAM_FACES(f) ((f)->output_data.ns->n_param_faces)
#define FRAME_DEFAULT_PARAM_FACE(f) (FRAME_PARAM_FACES (f)[0])
#define FRAME_MODE_LINE_PARAM_FACE(f) (FRAME_PARAM_FACES (f)[1])

#define FRAME_COMPUTED_FACES(f) ((f)->output_data.ns->computed_faces)
#define FRAME_N_COMPUTED_FACES(f) ((f)->output_data.ns->n_computed_faces)
#define FRAME_SIZE_COMPUTED_FACES(f) ((f)->output_data.ns->size_computed_faces)
#define FRAME_DEFAULT_FACE(f) ((f)->output_data.ns->computed_faces[0])
#define FRAME_MODE_LINE_FACE(f) ((f)->output_data.ns->computed_faces[1])
#endif /* ! COMPILING_MULTI_TERM */

/* Return the window associated with the frame F.  */
#define FRAME_NS_WINDOW(f) ((f)->output_data.ns->view)

#ifndef COMPILING_MULTI_TERM
#define FRAME_FONT(f) ((f)->output_data.ns->font)
#endif /* ! COMPILING_MULTI_TERM */
#define NS_FRAME_FONT(f) ((f)->output_data.ns->face)
#define NS_FRAME_INTERNAL_BORDER_WIDTH(f) ((f)->output_data.ns->internal_border_width)
#define FRAME_INTERNAL_BORDER_WIDTH(f) NS_FRAME_INTERNAL_BORDER_WIDTH(f)
#define NS_FRAME_LINE_HEIGHT(f) ((f)->output_data.ns->line_height)
#define FRAME_LINE_HEIGHT(f) NS_FRAME_LINE_HEIGHT(f)

/* This gives the ns_display_info structure for the display F is on.  */
#define FRAME_NS_DISPLAY_INFO(f) ((f)->output_data.ns->display_info)

/* This is the `Display *' which frame F is on.  */
#define FRAME_NS_DISPLAY(f) (0)

/* These two really ought to be called FRAME_PIXEL_{WIDTH,HEIGHT}.  */
#define NS_PIXEL_WIDTH(f) (x_pixel_width (f))
#define NS_PIXEL_HEIGHT(f) (x_pixel_height (f))
#define PIXEL_WIDTH(f) NS_PIXEL_WIDTH(f)
#define PIXEL_HEIGHT(f) NS_PIXEL_HEIGHT(f)


/* Manipulating pixel sizes and character sizes.
   Knowledge of which factors affect the overall size of the window should
   be hidden in these macros, if that's possible.

   Return the upper/left pixel position of the character cell on frame F
   at ROW/COL.  */
#define CHAR_TO_PIXEL_ROW(f, row) \
  ((f)->output_data.ns->internal_border_width \
   + (row) * (f)->output_data.ns->line_height)
#define CHAR_TO_PIXEL_COL(f, col) \
  ((f)->output_data.ns->internal_border_width \
   + (col) * FONT_WIDTH ((f)->output_data.ns->font))

/* Return the pixel width/height of frame F if it has
   WIDTH columns/HEIGHT rows.  */
#define CHAR_TO_PIXEL_WIDTH(f, width) \
  (CHAR_TO_PIXEL_COL (f, width) \
   + (f)->output_data.ns->vertical_scroll_bar_extra \
   + (f)->output_data.ns->internal_border_width)
#define CHAR_TO_PIXEL_HEIGHT(f, height) \
  (CHAR_TO_PIXEL_ROW (f, height) \
   + (f)->output_data.ns->internal_border_width)


#define FRAME_NS_FONT_TABLE(f) (FRAME_NS_DISPLAY_INFO (f)->font_table)


#ifndef COMPILING_MULTI_TERM
#define FRAME_DESIRED_CURSOR(f) ((f)->output_data.ns->desired_cursor)
#endif /* ! COMPILING_MULTI_TERM */

extern Lisp_Object ns_new_font();
extern struct font_info *ns_load_font();
extern Lisp_Object ns_list_fonts ();
extern struct font_info *ns_get_font_info ();

extern void check_ns(void);
extern void ns_set_frame_parameters();
extern void ns_display_menu_bar();
extern Lisp_Object ns_map_event_to_object ();
extern Lisp_Object ns_string_from_pasteboard();
extern void ns_string_to_pasteboard();
extern int ns_lisp_to_cursor_type();
extern struct frame *ns_focus_frame;

extern void *ns_alloc_autorelease_pool();
extern void ns_release_autorelease_pool(void *pool);

/* Create the first two computed faces for a frame -- the ones that
   have GC's.  */
extern void ns_init_frame_faces (/* FRAME_PTR */);

/* Free the resources for the faces associated with a frame.  */
extern void ns_free_frame_faces (/* FRAME_PTR */);

/* Given a frame and a face name, return the face's ID number, or
   zero if it isn't a recognized face name.  */
extern int ns_face_name_id_number (/* FRAME_PTR, Lisp_Object */);

/* Return non-zero if FONT1 and FONT2 have the same size bounding box.
   We assume that they're both character-cell fonts.  */
extern int same_size_fonts (/* XFontStruct *, XFontStruct * */);

/* Recompute the GC's for the default and modeline faces.
   We call this after changing frame parameters on which those GC's
   depend.  */
extern void ns_recompute_basic_faces (/* FRAME_PTR */);

/* Return the face ID associated with a buffer position POS.  Store
   into *ENDPTR the next position at which a different face is
   needed.  This does not take account of glyphs that specify their
   own face codes.  F is the frame in use for display, and W is a
   window displaying the current buffer.

   REGION_BEG, REGION_END delimit the region, so it can be highlighted.  */
extern int ns_compute_char_face (/* FRAME_PTR frame,
                                    struct window *w,
                                    int pos,
                                    int region_beg, int region_end,
                                    int *endptr */);
/* Return the face ID to use to display a special glyph which selects
   FACE_CODE as the face ID, assuming that ordinarily the face would
   be BASIC_FACE.  F is the frame.  */
extern int ns_compute_glyph_face (/* FRAME_PTR, int */);

#define BEANS 0xfabacaea
#define MINWIDTH 10
#define MINHEIGHT 10

#ifdef __OBJC__
#define XNS_SCROLL_BAR(vec) ((id) LISP_TO_VOID (vec))
#else
#define XNS_SCROLL_BAR(vec) LISP_TO_VOID (vec)
#endif

/* Screen max coordinate
 Using larger coordinates causes movewindow/placewindow to abort */
#define SCREENMAX 16000

/* Little utility macro */
#define BOUND(min,x,max) (((x)<(min)) ? (min) : (((x)>(max)) ? (max) : (x)))
#define SCREENMAXBOUND(x) (BOUND(-SCREENMAX,x,SCREENMAX))

#endif
