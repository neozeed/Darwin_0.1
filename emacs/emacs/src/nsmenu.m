/* NeXTstep menu module
   Copyright (C) 1986, 1988, 1993 Free Software Foundation, Inc.

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
#include "frame.h"
#include "buffer.h"
#include "window.h"
#include "keyboard.h"
#include "commands.h"
#include "blockinput.h"
#include "nsgui.h"
#include "nsterm.h"
#include "dispextern.h"
#include "termhooks.h"

#define MenuStagger 10.0

extern Lisp_Object Qundefined;
extern Lisp_Object Qmenu_enable;

Lisp_Object ns_menu_path;

DEFUN ("x-popup-menu",Fx_popup_menu, Sx_popup_menu, 1, 2, 0,
  "Pop up a deck-of-cards menu and return user's selection.\n\
POSITION is a position specification.  This is either a mouse button event\n\
or a list ((XOFFSET YOFFSET) WINDOW)\n\
where XOFFSET and YOFFSET are positions in pixels from the top left\n\
corner of WINDOW's frame.  (WINDOW may be a frame object instead of a window.)\n\
This controls the position of the center of the first line\n\
in the first pane of the menu, not the top left of the menu as a whole.\n\
\n\
MENU is a specifier for a menu.  For the simplest case, MENU is a keymap.\n\
The menu items come from key bindings that have a menu string as well as\n\
a definition; actually, the \"definition\" in such a key binding looks like\n\
\(STRING . REAL-DEFINITION).  To give the menu a title, put a string into\n\
the keymap as a top-level element.\n\n\
You can also use a list of keymaps as MENU.\n\
  Then each keymap makes a separate pane.\n\
When MENU is a keymap or a list of keymaps, the return value\n\
is a list of events.\n\n\
Alternatively, you can specify a menu of multiple panes\n\
  with a list of the form (TITLE PANE1 PANE2...),\n\
where each pane is a list of form (TITLE ITEM1 ITEM2...).\n\
Each ITEM is normally a cons cell (STRING . VALUE);\n\
but a string can appear as an item--that makes a nonselectable line\n\
in the menu.\n\
With this form of menu, the return value is VALUE from the chosen item.")
  (position, menu)
     Lisp_Object position, menu;
   {
   id panel;
   Lisp_Object window,x,y,tem;
   struct frame *f;
   NSPoint p;
#ifdef AUTORELEASE
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif

   if (NILP(position))
      {
      /* Don't create a menu.  Just precalculate the keyboard equivalents */
      return Qnil;
      }

   if (CONSP(ns_menu_path))
      {
      Lisp_Object ret=XCONS(ns_menu_path)->car;
      ns_menu_path=XCONS(ns_menu_path)->cdr;
      return ret;
      }

   check_ns();

   if (EQ (position, Qt))
      {
      /* Use the mouse's current position.  */
      struct frame *new_f=0;

      if (mouse_position_hook)
         (*mouse_position_hook) (&new_f, 0, 0, 0, &x, &y, 0);
      if (new_f != 0)
         XSETFRAME (window, new_f);
      else
         {
         window = selected_window;
         x = make_number(0);
         y = make_number(0);
         }
      }
   else
      {
      CHECK_CONS (position,0);
      tem = Fcar (position);
      if (XTYPE (tem) == Lisp_Cons)
         {
         window = Fcar (Fcdr (position));
         x = Fcar(tem);
         y = Fcar(Fcdr (tem));
         }
      else
         {
         tem = Fcar (Fcdr (position));
         window = Fcar (tem);
         tem = Fcar (Fcdr (Fcdr (tem)));
         x = Fcar (tem);
         y = Fcdr (tem);
         }
      }

   CHECK_NUMBER (x,0);
   CHECK_NUMBER (y,0);

   if (FRAMEP (window))
      {
      f = XFRAME (window);

      p.x = 0;
      p.y = 0;
      }
   else
      {
      CHECK_LIVE_WINDOW (window, 0);
      f = XFRAME (WINDOW_FRAME (XWINDOW (window)));

      p.x = ((int)(f->output_data.ns->font->width) * XWINDOW (window)->left);
      p.y = (f->output_data.ns->line_height * XWINDOW (window)->top);
      }

   p.x+=XINT(x); p.y+=XINT(y);
   p = [f->output_data.ns->view convertPoint:p toView:nil];
   p = [[f->output_data.ns->view window] convertBaseToScreen:p];
   panel=[[EmacsMenuPanel alloc] initFromMenu:menu];

   tem=[panel runMenuAt:p.x:p.y];
   [panel close];
   [[selected_frame->output_data.ns->view window] makeKeyWindow];
#ifdef AUTORELEASE
   [pool release];
#endif
   return tem;
   }

DEFUN ("x-popup-dialog", Fx_popup_dialog, Sx_popup_dialog, 2, 2, 0,
  "Pop up a dialog box and return user's selection.\n\
POSITION specifies which frame to use.\n\
This is normally a mouse button event or a window or frame.\n\
If POSITION is t, it means to use the frame the mouse is on.\n\
The dialog box appears in the middle of the specified frame.\n\
\n\
CONTENTS specifies the alternatives to display in the dialog box.\n\
It is a list of the form (TITLE ITEM1 ITEM2...).\n\
Each ITEM is a cons cell (STRING . VALUE).\n\
The return value is VALUE from the chosen item.\n\n\
An ITEM may also be just a string--that makes a nonselectable item.\n\
An ITEM may also be nil--that means to put all preceding items\n\
on the left of the dialog box and all following items on the right.\n\
\(By default, approximately half appear on each side.)")
  (position, contents)
     Lisp_Object position, contents;
   {
   id dialog;
   Lisp_Object window,tem;
   struct frame *f;
   NSPoint p;
#ifdef AUTORELEASE
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif

   check_ns();
   if (EQ (position, Qt))
      {
      window = selected_window;
      }
   else if (CONSP (position))
      {
      Lisp_Object tem;
      tem = Fcar (position);
      if (XTYPE (tem) == Lisp_Cons)
         window = Fcar (Fcdr (position));
      else
         {
         tem = Fcar (Fcdr (position));  /* EVENT_START (position) */
         window = Fcar (tem);	     /* POSN_WINDOW (tem) */
         }
      }
   else if (FRAMEP (position))
      {
      window = position;
      }
   else
      {
      CHECK_LIVE_WINDOW (position,0);
      window = position;
      }

   if (FRAMEP (window))
      f = XFRAME (window);
   else
      {
      CHECK_LIVE_WINDOW (window, 0);
      f = XFRAME (WINDOW_FRAME (XWINDOW (window)));
      }
   p.x = (int)f->output_data.ns->left +
         ((int)(f->output_data.ns->font->width) * f->width)/2;
   p.y = (int)f->output_data.ns->top +
         (f->output_data.ns->line_height * f->height)/2;
   dialog=[[EmacsDialogPanel alloc] initFromContents:contents];

   tem=[dialog runDialogAt:p.x:p.y];
   [dialog close];
   [[selected_frame->output_data.ns->view window] makeKeyWindow];
#ifdef AUTORELEASE
   [pool release];
#endif
   return tem;
   }

void x_free_frame_menubar (struct frame *f)
   {
   id menu=[NSApp mainMenu];

   [menu mark];
   [menu freeMarked];
   }

void set_frame_menubar (struct frame *f, int first_time, int deep_p)
{
  int i,len;
  Lisp_Object items,tail,key,string;
  id menu=[NSApp mainMenu];

  /** I guess on PPC an NSMenu can get created automatically? **/
  if ([menu isKindOfClass:[EmacsMenu class]] == NO) 
    menu = nil;

  if ( first_time && menu ) { 
    // remove everything
    while ( [[menu itemArray] count] )
      [menu removeItem:[[menu itemArray] objectAtIndex:0]];
  }
  
  if (f!=selected_frame)
    return;

  if (menu==nil) {
    menu=[[[EmacsMenu alloc] initWithTitle:
	    [[NSProcessInfo processInfo] processName]] autorelease];

#ifndef RHAPSODY
    [NSApp setMainMenu:menu];
#endif
  }

  if (NILP (items=FRAME_MENU_BAR_ITEMS (f)))
    items = FRAME_MENU_BAR_ITEMS (f) = menu_bar_items(FRAME_MENU_BAR_ITEMS(f));

  [menu mark];

  for(i=0;i<XVECTOR(items)->size;i+=4) {
    key=XVECTOR(items)->contents[i];
    string=XVECTOR(items)->contents[i+1];
    for(tail=XVECTOR(items)->contents[i+2];CONSP(tail);tail=XCONS(tail)->cdr)
      [menu adjustKey:key binding:XCONS(tail)->car string:string];
  }
  
  [menu freeMarked];

#ifdef RHAPSODY
  [NSApp setMainMenu:menu];
#endif
}

DEFUN ("x-reset-menu",Fx_reset_menu, Sx_reset_menu, 0, 0, 0,
  "Cause the NS menu to be re-calculated.")
   ()
   {
#ifdef AUTORELEASE
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
   set_frame_menubar(selected_frame,1, 0);
#ifdef AUTORELEASE
   [pool release];
#endif
   return Qnil;
   }

Lisp_Object ns_map_event_to_object (struct input_event *event, struct frame *f)
   {
   if (CONSP(ns_menu_path))
      {
      Lisp_Object ret=XCONS(ns_menu_path)->car;
      ns_menu_path=XCONS(ns_menu_path)->cdr;
      return ret;
      }
   return Qnil;
   }

syms_of_nsmenu ()
   {
   ns_menu_path=Qnil;
   staticpro(&ns_menu_path);
   defsubr (&Sx_popup_menu);
   defsubr (&Sx_popup_dialog);
   defsubr (&Sx_reset_menu);
   }

@implementation EmacsMenuObject


- init
   {
   [super init];
   value=Qnil;
//   staticpro(&value);
   supercell=nil;
   return self;
   }

- (void)dealloc
{
//  staticunpro(&value);
  [super dealloc]; 
  return;
}

- (Lisp_Object) value
   {
   return value;
   }

- setValue:(Lisp_Object)nvalue
   {
   value=nvalue;
   return self;
   }

- supercell
   {
   return supercell;
   }

- setSupercell:(id) nsupercell
   {
   supercell=nsupercell;
   return self;
   }

@end

@implementation EmacsMenu
- (void)submenuAction:(id)sender
{
}

- init
   {
   [super init];
   minmarked=0;
   wasVisible=NO;
   return self;
   }

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent 
   {
   if (selected_frame && selected_frame->output_data.ns->view)
      [selected_frame->output_data.ns->view keyDown:theEvent];
   return YES;
   }

- addItem:(Lisp_Object)val string:(Lisp_Object)aString bind:(Lisp_Object)bind
   {
   unsigned int key=0;
   id cell;
   NSString *title, *keyEq;
   EmacsMenuObject *obj;

   if (!NILP(bind))
      {
      Lisp_Object tail,vec;
      for(tail=Fwhere_is_internal(bind,Qnil,Qnil,Qt);
          XTYPE(tail)==Lisp_Cons;tail=XCONS(tail)->cdr)
         {
         vec=XCONS(tail)->car;
         if (!VECTORP(vec) ||
             XVECTOR(vec)->size!=1 ||
             XTYPE(XVECTOR(vec)->contents[0])!=Lisp_Int)
            continue;
         key=XFASTINT(XVECTOR(vec)->contents[0]);
         if ((key&(alt_modifier|hyper_modifier|super_modifier))==super_modifier)
            {
            key=NILP(ns_iso_latin) ? (key&0xff) : iso2nsmap[key&0xff];
            break;
            }
         else
            {
            key=0;
            }
         }
      }

   title = [NSString stringWithCString:XSTRING(aString)->data];

   keyEq = key == 0 ? @"" : [NSString stringWithFormat:@"%c", key];
   cell = [self addMinItemWithTitle:title
			     action:@selector(menuDown:)
					 keyEquivalent:keyEq];

   obj = [[[EmacsMenuObject alloc] init] autorelease];
   [obj setValue:val];
   [obj setSupercell:supercell];

   [cell setRepresentedObject:obj];
   
   return cell;
   }

- supercell
   {
   return supercell;
   }

- setSupercell:(id) nsupercell
   {
   supercell=nsupercell;
   return self;
   }

- mark
   {
#if 0
     NSEnumerator *ienum;
     id <NSMenuItem> item;

     ienum = [[self itemArray] objectEnumerator];
     while ( item = [ienum nextObject] )
       if ([item hasSubmenu]) 
	 [[item target] mark];
#endif
     minmarked=0;

     return self;
   }

- freeMarked
{
   int i;
   id cell;
   NSArray *items = [self itemArray];

   i = [items count];
   while (i > minmarked
	  && ((cell=[items objectAtIndex:--i])!=nil))
     {
       if ([cell hasSubmenu]) 
	 [[cell target] swapout];
       [self removeItem:cell];
     }


   for (i=0;i < [items count];i++) {
     cell = [items objectAtIndex:i];

     // Special case, see note in adjustKey:
     if ([cell hasSubmenu]
	 && ([[cell title] isEqualToString:@"Buffers"]
	     || [[cell title] isEqualToString:@"Windows"]))
       [[cell target] freeMarked];
   }
   
   [self sizeToFit];

   return self;
}

- findCell:(Lisp_Object)value
   {
     NSEnumerator *ienum;
     id <NSMenuItem> item;

     ienum = [[self itemArray] objectEnumerator];
     while ( item = [ienum nextObject] )
       if ( [[item representedObject] value] == value )
	 return item;

     return nil;
   }

- (int)findCellNumber:(Lisp_Object)value
   {
     id cell;
     NSArray *items = [self itemArray];
     NSEnumerator *ienum;
     int i;
     
     for (i=0; i < [items count];i++) {
       cell = [items objectAtIndex:i];
       if ([[cell representedObject] value]==value) 
	 return i;
     }
     return -1;
   }

- (id <NSMenuItem>)addMinItemWithTitle:(NSString *)aString 
				action:(SEL)aSelector 
			 keyEquivalent:(NSString *)charCode
{
  return [self insertItemWithTitle:aString 
			    action:aSelector 
		     keyEquivalent:charCode 
			   atIndex:minmarked];;

}

- transferCell:(id)cell to:newmenu
   {
     if (cell!=nil)
       {
	 EmacsMenuObject *obj = [cell representedObject];
	 id <NSMenuItem> newcell;

	 newcell = [newmenu addMinItemWithTitle:[cell title]
					 action:[cell action]
				  keyEquivalent:[cell keyEquivalent]];

	 [newcell setRepresentedObject:obj];

	 if ( [cell hasSubmenu] ) {
	   NSArray *array = [NSArray arrayWithArray:[[cell target] itemArray]];
	   NSEnumerator *senum = [array objectEnumerator];
	   id tcell, submenu;

	   submenu=[[EmacsMenu alloc] initWithTitle:[cell title]];
	   [submenu setSupercell:newcell];         
	   [newmenu setSubmenu:submenu forItem:newcell];

	   while (tcell = [senum nextObject])
	     [[cell target] transferCell:tcell to:submenu];

	 }

	 [self removeCell:cell];
	 return newcell;
       }
     return nil;
   }

- removeCell:cell
   {
     int i = [self findCellNumber:[[cell representedObject] value]];

     if ( i != -1 ) {
       [self removeItem:cell];

       if (i<minmarked) 
	 minmarked--;
     }
   }

- adjustMap:(Lisp_Object)keymap;
{
   Lisp_Object item;

   for (keymap=XCONS(keymap)->cdr;
        XTYPE (keymap) == Lisp_Cons;
        keymap = XCONS (keymap)->cdr)
      {
      item = XCONS (keymap)->car;
      if (XTYPE(item) == Lisp_Cons)
         [self adjustKey:XCONS(item)->car binding: XCONS(item)->cdr];
      else if (VECTORP(item))
         {
         int len = XVECTOR (item)->size,c;
         for (c=0; c<len; c++)
            [self adjustKey:c binding:XVECTOR(item)->contents[c]];
         }
      }
   return self;
}

- (void)adjustKey:(Lisp_Object)key binding:(Lisp_Object)bind
   {
   if (XTYPE(bind) == Lisp_Cons)
      [self adjustKey:key binding:XCONS(bind)->cdr string:XCONS(bind)->car];
   else if (EQ (bind, Qundefined))
      [self removeCell:[self findCell:key]];
   return;
   }

- (void)adjustKey:(Lisp_Object)key binding:(Lisp_Object)bind string:(Lisp_Object)string
   {
   int i;
   id cell=nil, oldcell;

   if (XTYPE(string)!=Lisp_String)
      return;
   
   if ([[self itemArray] count] > minmarked 
       && ((cell=[[self itemArray] objectAtIndex:minmarked])!=nil) 
       && ([[cell representedObject] value]==key)) {
     /** 
       if already have the same menu item, in the same place, keep it.
       Because things are so slow under OpenStep, we'll asume that
       the subItems have not changed. We'll special case Buffers, Windows,
       and Services

       This could be a problem if someone changes a menu after the first time
       it's created. Does this ever happen?
       **/

     if ( strcmp(XSTRING(string)->data, "Buffers") == 0 
	  || strcmp(XSTRING(string)->data, "Windows") == 0 )
       ; // fall through and update the menu
     else { //skip it
       minmarked++;
       return;
     }
   } else if (XTYPE(bind)==Lisp_Cons && XCONS(bind)->car==Qkeymap)
     cell = [self addItem:key string:string bind:Qnil];
   else
     cell = [self addItem:key string:string bind:bind];

   if (XTYPE(bind)==Lisp_Cons && XCONS(bind)->car==Qkeymap) {
     id nmenu;
      
     if (![cell hasSubmenu]) {
       nmenu=[[EmacsMenu alloc] initWithTitle:[NSString stringWithCString:XSTRING(string)->data]];
       [nmenu setSupercell:cell];         
       [self setSubmenu:nmenu forItem:cell];
     } else {
       nmenu=[cell target];
     }

     [nmenu mark];
     [nmenu adjustMap:bind];
   } else {
     if ([cell hasSubmenu]) {
       [self removeCell:cell];
       cell=[self addItem:key string:string bind:bind];
     }
   }
   
   if (![[cell title] isEqualToString
	  :[NSString stringWithCString:XSTRING(string)->data]]) {
     [cell setTitle:[NSString stringWithCString:XSTRING(string)->data]];
   }
   
   minmarked++;
   }

- swapout
{
#ifndef NOT_IMPLEMENTED
   int i;
   id cell;
   NSArray *items = [self itemArray];

//   wasVisible=[self isVisible];
//   [self orderOut:self];
   for (i=0; i < [items count];i++) {
     cell = [items objectAtIndex:i];
     if ([cell hasSubmenu]) [[cell target] swapout];
   }
#endif
}

- swapin
{
#ifndef NOT_IMPLEMENTED
   int i;
   id cell;
   NSArray *items = [self itemArray];

//   if (wasVisible)
//      {
//      [self orderFront:self];
//      }

   for (i=0; i < [items count];i++) {
     cell = [items objectAtIndex:i];
     if ([cell hasSubmenu]) [[cell target] swapin];
   }
#endif
}
@end

@implementation EmacsMenuCard
- init
   {
   [super init];
   [self setTitle:@""];
   [self setFont:[NSFont userFixedPitchFontOfSize:0]];
   [self setPullsDown:!(NO)];
   [self setTarget:self];
   [self setAction:@selector(clicked:)];
   [self setAlignment:NSCenterTextAlignment];
   return self;
   }

- addTitle: (char *)name
{
  [self setTitle:[NSString stringWithCString:name]];
  return self;
}

- addItem: (char *)name value:(Lisp_Object)val enabled:(BOOL)enabled
{
  NSSize s;
  NSRect r;
  id item;
  
//      [(item=[popup addItem:[self title]]) setTag:Qundefined];
//      [item setAlignment:NSCenterTextAlignment];
//      [self setAlignment:NSCenterTextAlignment];
//      s = [item cellSize];
//      [self setFrameSize:s];

  [self addItemWithTitle:[NSString stringWithCString:name]];
  item = [self itemAtIndex:[self numberOfItems]-1];
  [item setTag:(int)val];
#ifndef RHAPSODY
  [item setImagePosition:NSNoImage];
  [item setAlignment:NSLeftTextAlignment];
#endif
  if (!enabled) {
    [item setEnabled:NO];
  }
#ifndef RHAPSODY
   s = [item cellSize];
   r = [self frame];
   if (s.width > r.size.width)
     [self setFrameSize:NSMakeSize(s.width, r.size.height)];
#endif
   return self;
}

- (void)clicked:sender
{
  Lisp_Object seltag;
  id selected;

  if ( (selected = [self selectedItem]) && [selected tag] ) {
    seltag = (Lisp_Object)[selected tag];
    if (! EQ(seltag,Qundefined))
      [NSApp stopModalWithCode:seltag];
  }
}
@end

@implementation EmacsMenuPanel
- initWithContentRect:(NSRect)contentRect 
	    styleMask:(unsigned int)aStyle 
	      backing:(NSBackingStoreType)backingType 
		defer:(BOOL)flag
   {
   aStyle=NSTitledWindowMask;
   flag=YES;
   list=nil;
   maxwidth=0;
   [super initWithContentRect:contentRect 
		    styleMask:aStyle|NSClosableWindowMask 
		      backing:backingType 
			defer:flag];
   [self setOneShot:YES];
   [self setReleasedWhenClosed:YES];
   [self setHidesOnDeactivate:YES];
   return self;
   }

- (BOOL)windowShouldClose:(id)sender
   {
   [NSApp stopModalWithCode:Qnil];
   return NO;
   }

static void process_keymap(id window,Lisp_Object keymap,Lisp_Object prefix,
                           char *name)
   {
   Lisp_Object tail,pending_maps,tem;
   int card;

   pending_maps=Qnil;

   card = [window cards];
   if (name) [window addTitle:name to:card];

   for (tail=keymap; XTYPE(tail)==Lisp_Cons; tail=XCONS(tail)->cdr)
      {
      Lisp_Object item=XCONS(tail)->car,item1,item2,def,enabled;
      if (XTYPE(item)==Lisp_Cons)
         {
         item1=XCONS(item)->cdr;
         if (XTYPE(item1)==Lisp_Cons)
            {
            item2=XCONS(item1)->car;
            if (XTYPE(item2)==Lisp_String)
               {
               def=XCONS(item1)->cdr;
               enabled=Qt;
               if (XTYPE(def)==Lisp_Symbol)
                  {
                  tem=Fget(def,Qmenu_enable);
                  if (!NILP(tem)) enabled=Feval(tem);
                  }
               if (XSTRING (item2)->data[0] == '@' && !NILP(Fkeymapp(def)))
                  pending_maps = Fcons(Fcons(def,Fcons(item2, XCONS(item)->car)),
                                       pending_maps);
               else
                  [window addItem:XSTRING(item2)->data
                          value:Freverse(Fcons(XCONS(item)->car,prefix))
                          enabled:!NILP(enabled) at:card];
               }
            }
         }
      else if (VECTORP(item))
         {
         int len=XVECTOR(item)->size;
         int c;
         for(c=0; c<len; c++)
            {
            Lisp_Object character;
            XSETFASTINT(character, c);
            item1=XVECTOR(item)->contents[c];
            if (XTYPE(item1)==Lisp_Cons)
               {
               item2=XCONS(item1)->car;
               if (XTYPE(item2)==Lisp_String)
                  {
                  def=XCONS(item1)->cdr;
                  enabled=Qt;
                  if (XTYPE(def)==Lisp_Symbol)
                     {
                     tem=Fget(def,Qmenu_enable);
                     if (!NILP(tem)) enabled=Feval(tem);
                     }
                  if (XSTRING (item2)->data[0] == '@' && !NILP(Fkeymapp(def)))
                     pending_maps = Fcons(Fcons(def,Fcons(item2, XCONS(item)->car)),
                                          pending_maps);
                  else
                     [window addItem:XSTRING(item2)->data
                             value:Freverse(Fcons(XCONS(item)->car,prefix))
                             enabled:!NILP(enabled) at:card];
                  }
               }
            }
         }
      }

   for(tail=pending_maps;XTYPE(tail)==Lisp_Cons;tail=XCONS(tail)->cdr)
      {
      tem=XCONS(tail)->car;
      process_keymap(window,XCONS(tem)->car,
                     Fcons(XCONS(XCONS(tem)->cdr)->cdr,prefix),
                     (char *)XSTRING(XCONS(XCONS(tem)->cdr)->car)->data +1);
      }
   }

void process_list(id window,Lisp_Object list)
   {
   Lisp_Object tail,pane,tem;
   int card;

   card = [window cards];
   for(;XTYPE(list)==Lisp_Cons;list=XCONS(list)->cdr)
      {
      pane=XCONS(list)->car;
      if (XTYPE(pane)!=Lisp_Cons || XTYPE(XCONS(pane)->car)!=Lisp_String) continue;
      for(tail=pane;XTYPE(tail)==Lisp_Cons;tail=XCONS(tail)->cdr)
         {
         tem=XCONS(tail)->car;
         if (XTYPE(tem)==Lisp_String)
            {
	      if (tail!=pane)		/* Not very first item? */
		  [window addItem:XSTRING(tem)->data value:Qnil
	                  enabled:NO at:card];
	      else
		  [window addTitle:XSTRING(tem)->data to:card];
            }
         else if (XTYPE(tem)==Lisp_Cons || XTYPE(XCONS(tem)->car)==Lisp_String)
            {
            [window addItem:XSTRING(XCONS(tem)->car)->data value:XCONS(tem)->cdr
                    enabled:YES at:card];
            }
         }
      }
   }


- addItem:(char *)str value:(Lisp_Object)val enabled:(BOOL)enabled at:(int)pane
   {
   int row;
   EmacsMenuCard *card;
   NSRect area;

   row = [list count];
   for(;row<=pane;row++)
      {
      [list addObject:card=[[EmacsMenuCard alloc] init]];
      [[self contentView] addSubview:card];
#ifndef RHAPSODY
      area.size = [[card cell] cellSize];
      if (area.size.width > maxwidth)  maxwidth=area.size.width;
      area.origin.x = MenuStagger*pane;
      area.origin.y = area.size.height*pane;
      [card setFrame:area];
#endif
      }
   card = [list objectAtIndex:pane];
   [card addItem:str value:val enabled:enabled];
   area = [card frame];
   if (area.size.width > maxwidth)  maxwidth=area.size.width;
   }

- addTitle:(char *)str to:(int)pane
   {
   int row;
   EmacsMenuCard *card;
   NSRect area;

   row = [list count];
   for(;row<=pane;row++)
      {
      [list addObject:card=[[EmacsMenuCard alloc] init]];
      [[self contentView] addSubview:card];
#ifndef RHAPSODY
      area.size = [[card cell] cellSize];
      if (area.size.width > maxwidth)  maxwidth=area.size.width;
      area.origin.x = MenuStagger*pane;
      area.origin.y = area.size.height*pane;
      [card setFrame:area];
#endif
      }

   card = [list objectAtIndex:pane];
   [card addTitle:str];
#ifndef RHAPSODY
   area.size = [[card cell] cellSize];
   if (area.size.width > maxwidth)  maxwidth=area.size.width;
#endif
   }

- initFromMenu:(Lisp_Object)menu
   {
   Lisp_Object title;
   NSSize spacing = {0,0};
   [super init];

      {
      list=[[NSMutableArray alloc] init];
#ifdef NOT_IMPLEMENTED
#error ViewConversion: '[NSView setFlipped:]' is obsolete; you must override 'isFlipped' instead of setting externally. However, [NSImage setFlipped:] is not obsolete. If that is what you are using here, no change is needed.
      [[self contentView] setFlipped:YES];
#endif
      }

   if (!NILP (Fkeymapp(menu)))
      {
      int i,j;
      Lisp_Object keymap = get_keymap(menu);
      process_keymap(self,keymap,Qnil,0);
      title = map_prompt(keymap);
      }
   else if (XTYPE(menu)==Lisp_Cons && !NILP(Fkeymapp (Fcar(menu))))
      {
      Lisp_Object tem,keymap;
      for(title=Qnil;XTYPE(menu) == Lisp_Cons;menu = Fcdr(menu))
         {
         keymap=get_keymap(Fcar(menu));
         process_keymap(self,keymap,Qnil,0);
         tem = map_prompt (keymap);
         if (NILP(title) && !NILP(tem)) title=tem;
         }
      }
   else
      {
      Lisp_Object tem;
      title=Fcar(menu);
      process_list(self,Fcdr(menu));
      }

   if (XTYPE(title)==Lisp_String) [self setTitle:[NSString stringWithCString:XSTRING(title)->data]];

      {
      int i;
      NSRect r,s,t;

      t = [(EmacsMenuCard *)[list objectAtIndex:0] frame];
      for (i=0; i<[list count]; i++)
	  [[list objectAtIndex:i] 
		  setFrameSize:NSMakeSize(maxwidth, t.size.height)];

      r = [self frame];
      s = [(NSView *)[self contentView] frame];
      r.size.height += t.size.height*i-s.size.height;
      r.size.width  += maxwidth+(i-1)*MenuStagger-s.size.width;
      [self setFrame:r display:YES];
      }

   return self;
   }

- (void)dealloc
   {
   [list release];
   [super dealloc]; 
   return;
   }

- (int)cards
   {
   return [list count];
   }

- (Lisp_Object)runMenuAt:(float)x:(float)y
   {
   NSEvent *e;
   NSModalSession session;
   NSRect r;
   int ret;

   if ([list count] == 0)
     return Qnil;
   
   r = [(EmacsMenuCard *)[list objectAtIndex:0] frame];
   r.origin = [[self contentView] convertPoint:r.origin toView:nil];

   [self setFrameOrigin:NSMakePoint(x-r.size.width/2.0, y-r.origin.y+r.size.height/2.0)];

   [self orderFront:NSApp];

   session = [NSApp beginModalSessionForWindow:self];
   [self setHidesOnDeactivate:YES];
   while ((ret=[NSApp runModalSession:session])==NSRunContinuesResponse)
      (e = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:(!1)]);

   [NSApp endModalSession:session];

   return (Lisp_Object)ret;
   }
@end

@implementation EmacsDialogPanel

#define SPACER		8.0
#define ICONSIZE	50.0
#define TEXTHEIGHT	20.0

- initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)backingType defer:(BOOL)flag
   {
   NSSize spacing = {SPACER,SPACER};
   NSRect area;
   char this_cmd_name[80];
   id cell,tem;

   aStyle=NSTitledWindowMask;
   flag=YES;
   rows=0;
   cols=1;
   [super initWithContentRect:contentRect styleMask:aStyle backing:backingType defer:flag];
#ifdef NOT_IMPLEMENTED
#error ViewConversion: '[NSView setFlipped:]' is obsolete; you must override 'isFlipped' instead of setting externally. However, [NSImage setFlipped:] is not obsolete. If that is what you are using here, no change is needed.
   [[self contentView] setFlipped:YES];
#endif
   [[self contentView] setAutoresizesSubviews:YES];

   area.origin.x   = SPACER;
   area.origin.y   = SPACER;
   area.size.width = ICONSIZE;
   area.size.height= ICONSIZE;
   {
	tem = [[NSButton alloc] initWithFrame:area];
	[tem setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	[tem setTag:0];
	[tem setTarget:nil];
	[tem setAction:NULL];
	[tem setKeyEquivalent:@""];
	[tem setEnabled:NO];
	}
   [[self contentView] addSubview:tem];
   [tem setBordered:NO];

   if (XTYPE(this_command)==Lisp_Symbol)
      {
      int i;

      strcpy(this_cmd_name,XSYMBOL(this_command)->name->data);
      if (this_cmd_name[0] >= 'a' && this_cmd_name[0] <= 'z')
	 this_cmd_name[0] = this_cmd_name[0]-'a'+'A';
      for (i=0; this_cmd_name[i] != '\0'; i++)
	 {
	 if (this_cmd_name[i] == '-')
	    {
	    this_cmd_name[i]=' ';
	    if (this_cmd_name[i+1] >= 'a' && this_cmd_name[i+1] <= 'z')
	       this_cmd_name[i+1] = this_cmd_name[i+1]-'a'+'A';
	    }
	 }
      }
   else
      strcpy(this_cmd_name,"Emacs");
   area.origin.x   = ICONSIZE+2*SPACER;
   area.origin.y   = ICONSIZE/2-10+SPACER;
   area.size.width = 400;
   area.size.height= TEXTHEIGHT;
   command = [[NSTextField alloc] initWithFrame:area];
   [[self contentView] addSubview:command];
   [command setStringValue:[NSString stringWithCString:this_cmd_name]];
   [command setDrawsBackground:NO];
   [command setBezeled:NO];
   [command setSelectable:NO];
   [command setFont:[NSFont systemFontOfSize:18.0]];

   area.origin.x   = 0;
   area.origin.y   = ICONSIZE+2*SPACER;
   area.size.width = 400;
   area.size.height= 2;
   tem = [[NSBox alloc] initWithFrame:area];
   [[self contentView] addSubview:tem];
   [tem setTitlePosition:NSNoTitle];
   [tem setAutoresizingMask:NSViewWidthSizable];

   area.origin.x   = 2*SPACER;
   area.origin.y  += 2*SPACER;
   area.size.width = 400;
   area.size.height= TEXTHEIGHT;
   title = [[NSTextField alloc] initWithFrame:area];
   [[self contentView] addSubview:title];
   [title setDrawsBackground:NO];
   [title setBezeled:NO];
   [title setSelectable:NO];
   [title setFont:[NSFont systemFontOfSize:14.0]];

   cell = [[NSButtonCell alloc] initTextCell:@""];
   // Make it look like nothing's here
   [cell setBordered:NO];
   [cell setEnabled:NO];
   [cell setCellAttribute:NSCellIsInsetButton to:8];

   matrix = [[NSMatrix alloc] initWithFrame:contentRect 
				       mode:NSHighlightModeMatrix 
				  prototype:cell 
			       numberOfRows:0 
			    numberOfColumns:1];
   [[self contentView] addSubview:matrix];
   [matrix setFrameOrigin:NSMakePoint(SPACER, area.origin.y+TEXTHEIGHT+2*SPACER)];
   [matrix setIntercellSpacing:spacing];

   [self setOneShot:YES];
   [self setReleasedWhenClosed:YES];
   [self setHidesOnDeactivate:YES];
   return self;
   }

- (BOOL)windowShouldClose:(id)sender
   {
   [NSApp stopModalWithCode:Qnil];
   return NO;
   }

void process_dialog(id window,Lisp_Object list)
   {
   Lisp_Object item;
   int row;

   row=0;
   for(;XTYPE(list)==Lisp_Cons;list=XCONS(list)->cdr)
      {
      item=XCONS(list)->car;
      if (XTYPE(item)==Lisp_String)
	 {
	 [window addString:XSTRING(item)->data row:row];
	 row++;
         }
      else if (XTYPE(item)==Lisp_Cons)
         {
         [window addButton:XSTRING(XCONS(item)->car)->data
		 value:XCONS(item)->cdr row:row];
	 row++;
         }
      else if (NILP(item))
	 {
	 [window addSplit];
	 row=0;
	 }
      }
   }


- addButton:(char *)str value:(Lisp_Object)val row:(int)row
   {
   id cell;
       
   if (row >= rows)
      {
      [matrix addRow];
      rows++;
      }
   cell = [matrix cellAtRow:row column:cols-1];
   [cell setTarget:self];
   [cell setAction:@selector(clicked:)];
   [cell setTitle:[NSString stringWithCString:str]];
   [cell setTag:(int)val];
   [cell setBordered:YES];
   [cell setEnabled:YES];
   }

- addString:(char *)str row:(int)row
   {
   id cell;
       
   if (row >= rows)
      {
      [matrix addRow];
      rows++;
      }
   cell = [matrix cellAtRow:row column:cols-1];
   // No setAction here.  Disabled buttons can't trigger actions
   [cell setTitle:[NSString stringWithCString:str]];
   [cell setBordered:YES];
   [cell setEnabled:NO];
   }

- addSplit
   {
   [matrix addColumn];
   cols++;
   }

- clicked:sender
{
  NSArray *sellist=nil;
  Lisp_Object seltag;

  sellist=[sender selectedCells];
  if ([sellist count]<1) 
    return self;

  seltag = (Lisp_Object)[[sellist objectAtIndex:0] tag];
  if (! EQ(seltag,Qundefined))
    [NSApp stopModalWithCode:seltag];
  return self;
}

- initFromContents:(Lisp_Object)contents
   {
   Lisp_Object head;
   [super init];

   if (XTYPE(contents)==Lisp_Cons)
      {
      Lisp_Object tem;
      head=Fcar(contents);
      process_dialog(self,Fcdr(contents));
      }

   if (XTYPE(head)==Lisp_String)
      [title setStringValue:[NSString stringWithCString:XSTRING(head)->data]];

      {
      int i;
      NSRect r,s,t;

      if (cols == 1 && rows > 1)	// Never told where to split
	 {
	 [matrix addColumn];
	 for (i=0; i<rows/2; i++)
	    {
	    [matrix putCell:[matrix cellAtRow:(rows+1)/2 column:0] atRow:i column:1];
	    [matrix removeRow:(rows+1)/2];
	    }
	 }
      [matrix sizeToFit];
      [title sizeToFit];
      [command sizeToFit];

      t = [matrix frame];
      r = [title frame];
      if (r.size.width+r.origin.x > t.size.width+t.origin.x)
	 {
	 t.origin.x   = r.origin.x;
	 t.size.width = r.size.width;
	 }
      r = [command frame];
      if (r.size.width+r.origin.x > t.size.width+t.origin.x)
	 {
	 t.origin.x   = r.origin.x;
	 t.size.width = r.size.width;
	 }

      r = [self frame];
      s = [(NSView *)[self contentView] frame];
      r.size.height += t.origin.y+t.size.height+SPACER-s.size.height;
      r.size.width  += t.origin.x+t.size.width +SPACER-s.size.width;
      [self setFrame:r display:NO];
      }

   return self;
   }

- (void)dealloc
   {
   [matrix release];
   { [super dealloc]; return; };
   }

- (Lisp_Object)runDialogAt:(float)x:(float)y
   {
   NSEvent *e;
   NSModalSession session;
   NSRect r;
   int ret;

//    [[list objectAt:0] getFrame:&r];
//    [[self contentView] convertPoint:&r.origin toView:nil];

//    [[self moveTo: x-r.size.width/2.0: y+r.size.height/2.0]
//     orderFront:NXApp];

   [self center];
   [self orderFront:NSApp];

   session = [NSApp beginModalSessionForWindow:self];
   while ((ret=[NSApp runModalSession:session])==NSRunContinuesResponse)
      (e = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:(!1)]);
   [NSApp endModalSession:session];

   return (Lisp_Object)ret;
   }

@end
