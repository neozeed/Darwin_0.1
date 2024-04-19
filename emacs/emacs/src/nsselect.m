/* NS Selection processing for emacs
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

#import <AppKit/AppKit.h>

#include "config.h"
#include "lisp.h"
#include "nsgui.h"
#include "nsterm.h"
#include "dispextern.h"
#include "frame.h"
#include "blockinput.h"
#include "termhooks.h"

#define CUT_BUFFER_SUPPORT

Lisp_Object QPRIMARY, QSECONDARY, QTEXT, QFILE_NAME;

static Lisp_Object Vns_sent_selection_hooks;
static Lisp_Object Vns_lost_selection_hooks;
static Lisp_Object Vselection_alist;
static Lisp_Object Vselection_converter_alist;

NSString *NXSecondaryPboard;

static NSString *symbol_to_nsstring (Lisp_Object sym)
   {
   CHECK_SYMBOL(sym,0);
   if (EQ (sym, QPRIMARY))     return NSGeneralPboard;
   if (EQ (sym, QSECONDARY))   return NXSecondaryPboard;
   if (EQ (sym, QTEXT))        return NSStringPboardType;
   return [NSString stringWithCString:XSYMBOL(sym)->name->data];
   }

static Lisp_Object ns_string_to_symbol (NSString *t)
   {
   if ([t isEqualToString:NSGeneralPboard])
     return QPRIMARY;
   if ([t isEqualToString:NXSecondaryPboard])
       return QSECONDARY;
   if ([t isEqualToString:NSStringPboardType])
     return QTEXT;
   if ([t isEqualToString:NSFilenamesPboardType])
     return QFILE_NAME;
   if ([t isEqualToString:NSTabularTextPboardType])
     return QTEXT;
   return intern([t cString]);
   }

static Lisp_Object clean_local_selection_data (Lisp_Object obj)
   {
   if (CONSP (obj)
       && INTEGERP (XCONS (obj)->car)
       && CONSP (XCONS (obj)->cdr)
       && INTEGERP (XCONS (XCONS (obj)->cdr)->car)
       && NILP (XCONS (XCONS (obj)->cdr)->cdr))
      obj = Fcons (XCONS (obj)->car, XCONS (obj)->cdr);

   if (CONSP (obj)
       && INTEGERP (XCONS (obj)->car)
       && INTEGERP (XCONS (obj)->cdr))
      {
      if (XINT (XCONS (obj)->car) == 0)
         return XCONS (obj)->cdr;
      if (XINT (XCONS (obj)->car) == -1)
         return make_number (- XINT (XCONS (obj)->cdr));
      }

   if (VECTORP (obj))
      {
      int i;
      int size = XVECTOR (obj)->size;
      Lisp_Object copy;

      if (size == 1)
         return clean_local_selection_data (XVECTOR (obj)->contents [0]);
      copy = Fmake_vector (size, Qnil);
      for (i = 0; i < size; i++)
         XVECTOR (copy)->contents [i]
            = clean_local_selection_data (XVECTOR (obj)->contents [i]);
      return copy;
      }

   return obj;
   }

Lisp_Object ns_string_from_pasteboard(id pb)
   {
   NSString *type;
   Lisp_Object ret;
   int l;
   NSString *d;

   type= [pb availableTypeFromArray:ns_return_types];
   if (type==0) return Qnil;
   if (! (d = [pb stringForType:type]))
     return Qnil;
//      Fsignal (Qerror, Fcons (build_string ("pasteboard doesn't contain valid data"), Qnil));
   ret=build_string([d cString]);
   return ret;
   }

void ns_declare_pasteboard(id pb)
   {
   [pb declareTypes:ns_send_types owner:NSApp];
   }

void ns_undeclare_pasteboard(id pb)
   {
   [pb declareTypes:[NSArray array] owner:nil];
   }

void ns_string_to_pasteboard(id pb,Lisp_Object str)
   {
   int i;

   if (EQ (str, Qnil))
      {
      [pb declareTypes:[NSArray array] owner:nil];
      }
   else
      {
	NSEnumerator *tenum;
	NSString *type;
      CHECK_STRING(str, 0);
      [pb declareTypes:ns_send_types owner:nil];

      tenum = [ns_send_types objectEnumerator];
      while ( type = [tenum nextObject] )
	[pb setString:[NSString stringWithCString:XSTRING(str)->data
					   length:XSTRING(str)->size]
	      forType:type];
      }
   }

static Lisp_Object ns_get_local_selection(Lisp_Object selection_name,
                                          Lisp_Object target_type)
   {
   Lisp_Object local_value;
   Lisp_Object handler_fn, value, type, check;
   int count;

   local_value = assq_no_quit (selection_name, Vselection_alist);

   if (NILP (local_value)) return Qnil;

   count = specpdl_ptr - specpdl;
   specbind (Qinhibit_quit, Qt);
   CHECK_SYMBOL (target_type, 0);
   handler_fn = Fcdr (Fassq (target_type, Vselection_converter_alist));
   if (!NILP (handler_fn))
      value=call3(handler_fn, selection_name, target_type,
                  XCONS (XCONS (local_value)->cdr)->car);
   else
      value=Qnil;
   unbind_to (count, Qnil);

   check=value;
   if (CONSP(value) && SYMBOLP(XCONS (value)->car))
      {
      type=XCONS(value)->car;
      check=XCONS(value)->cdr;
      }

   if (STRINGP (check) || VECTORP (check) || SYMBOLP (check)
       || INTEGERP (check) || NILP (value))
      return value;

   if (CONSP (check)
       && INTEGERP (XCONS (check)->car)
       && (INTEGERP (XCONS (check)->cdr)||
           (CONSP (XCONS (check)->cdr)
            && INTEGERP (XCONS (XCONS (check)->cdr)->car)
            && NILP (XCONS (XCONS (check)->cdr)->cdr))))
      return value;

   return Fsignal (Qerror,
                   Fcons (build_string ("invalid data returned by selection-conversion function"),
                          Fcons (handler_fn, Fcons (value, Qnil))));
   }

static Lisp_Object ns_get_foreign_selection(Lisp_Object symbol, Lisp_Object target)
   {
   id pb;
   pb=[NSPasteboard pasteboardWithName:symbol_to_nsstring(symbol)];
   return ns_string_from_pasteboard(pb);
   }

void ns_handle_selection_request(struct input_event *event)
   {
   id pb=(id)event->x;
   NSString *type=(NSString *)event->y;
   Lisp_Object selection_name,selection_data,target_symbol,data;
   Lisp_Object successful_p,rest;

   selection_name=ns_string_to_symbol([pb name]);
   target_symbol=ns_string_to_symbol(type);
   selection_data= assq_no_quit (selection_name, Vselection_alist);
   successful_p=Qnil;

   if (NILP (selection_data)) goto DONE;

   data = ns_get_local_selection (selection_name, target_symbol);
   if (!NILP(data))
      {
      if (STRINGP(data))
         [pb setString:[NSString stringWithCString:XSTRING(data)->data length:XSTRING(data)->size] forType:type];
      successful_p=Qt;
      }

 DONE:
   if (!EQ(Vns_sent_selection_hooks,Qunbound))
      {
      for(rest=Vns_sent_selection_hooks;CONSP(rest); rest=Fcdr(rest))
         call3 (Fcar(rest), selection_name, target_symbol, successful_p);
      }
   }

void ns_handle_selection_clear(struct input_event *event)
   {
   id pb=(id)event->x;
   Lisp_Object selection_name,selection_data,rest;

   selection_name=ns_string_to_symbol([pb name]);
   selection_data=assq_no_quit (selection_name, Vselection_alist);
   if (NILP(selection_data)) return;

   if (EQ (selection_data, Fcar (Vselection_alist)))
     Vselection_alist = Fcdr (Vselection_alist);
   else
      {
      for (rest = Vselection_alist; !NILP (rest); rest = Fcdr (rest))
         if (EQ (selection_data, Fcar (Fcdr (rest))))
	    Fsetcdr(rest,Fcdr(Fcdr(rest)));
      }

   if (!EQ(Vns_lost_selection_hooks,Qunbound))
      {
      for(rest=Vns_lost_selection_hooks;CONSP(rest); rest=Fcdr(rest))
         call1 (Fcar(rest), selection_name);
      }
   }

DEFUN ("ns-own-selection-internal", Fns_own_selection_internal,
       Sns_own_selection_internal, 2, 2, 0, "Assert a selection.\n\
For more details see the window system specific function.")
  (selection_name, selection_value)
Lisp_Object selection_name,selection_value;
   {
   id pb;
   Lisp_Object old_value, new_value;

   check_ns();
   CHECK_SYMBOL (selection_name, 0);
   if (NILP (selection_value)) error ("selection-value may not be nil.");
   pb=[NSPasteboard pasteboardWithName:symbol_to_nsstring(selection_name)];
   ns_declare_pasteboard(pb);
   old_value=assq_no_quit (selection_name, Vselection_alist);
   new_value= Fcons(selection_name, Fcons(selection_value, Qnil));
   if (NILP(old_value))
      Vselection_alist=Fcons(new_value,Vselection_alist);
   else
      Fsetcdr(old_value,Fcdr(new_value));
   /* XXX An evil hack, but a necessary one I fear XXX */
      {
      struct input_event ev;
      ev.kind=selection_request_event;
      ev.modifiers=0;
      ev.code=0;
      ev.x=(int)pb;
      ev.y=(int)NSStringPboardType;
      ns_handle_selection_request(&ev);
      }
   return selection_value;
   }

DEFUN ("ns-disown-selection-internal", Fns_disown_selection_internal,
       Sns_disown_selection_internal, 1, 2, 0,
       "If we own the selection SELECTION, disown it.")
  (selection_name, time)
Lisp_Object selection_name,time;
   {
   id pb;
   check_ns();
   CHECK_SYMBOL (selection_name, 0);
   if (NILP(assq_no_quit (selection_name, Vselection_alist))) return Qnil;

   pb=[NSPasteboard pasteboardWithName:symbol_to_nsstring(selection_name)];
   ns_undeclare_pasteboard(pb);
   return Qt;
   }

DEFUN ("ns-selection-exists-p", Fns_selection_exists_p, Sns_selection_exists_p,
       0, 1, 0, "Whether there is an owner for the given selection.\n\
The arg should be the name of the selection in question, typically one of\n\
the symbols `PRIMARY', `SECONDARY', or `CLIPBOARD'.\n\
\(Those are literal upper-case symbol names.)\n\
For convenience, the symbol nil is the same as `PRIMARY',\n\
and t is the same as `SECONDARY'.)")
  (selection)
Lisp_Object selection;
   {
   id pb;
   NSArray *types;

   check_ns();
   CHECK_SYMBOL (selection, 0);
   if (EQ (selection, Qnil)) selection = QPRIMARY;
   if (EQ (selection, Qt)) selection = QSECONDARY;
   pb=[NSPasteboard pasteboardWithName:symbol_to_nsstring(selection)];
   types=[pb types];
   return ([types count] == 0) ? Qnil : Qt;
   }

DEFUN ("ns-selection-owner-p", Fns_selection_owner_p, Sns_selection_owner_p,
       0, 1, 0,
  "Whether the current Emacs process owns the given selection.\n\
The arg should be the name of the selection in question, typically one of\n\
the symbols `PRIMARY', `SECONDARY', or `CLIPBOARD'.\n\
\(Those are literal upper-case symbol names.)\n\
For convenience, the symbol nil is the same as `PRIMARY',\n\
and t is the same as `SECONDARY'.)")
  (selection)
Lisp_Object selection;
   {
   check_ns();
   CHECK_SYMBOL (selection, 0);
   if (EQ (selection, Qnil)) selection = QPRIMARY;
   if (EQ (selection, Qt)) selection = QSECONDARY;
   return (NILP (Fassq (selection, Vselection_alist))) ? Qnil : Qt;
   }

DEFUN ("ns-get-selection-internal", Fns_get_selection_internal,
       Sns_get_selection_internal, 2, 2, 0,
  "Return text selected from some pasteboard.\n\
SELECTION is a symbol, typically `PRIMARY', `SECONDARY', or `CLIPBOARD'.\n\
\(Those are literal upper-case symbol names.)\n\
TYPE is the type of data desired, typically `STRING'.")
  (selection_name, target_type)
Lisp_Object selection_name, target_type;
   {
   Lisp_Object val;

   check_ns();
   CHECK_SYMBOL(selection_name, 0);
   CHECK_SYMBOL(target_type,0);
   val= ns_get_local_selection(selection_name,target_type);
   if (NILP(val))
      val= ns_get_foreign_selection(selection_name,target_type);
   if (CONSP(val) && SYMBOLP (Fcar(val)))
      {
      val = Fcdr(val);
      if (CONSP (val) && NILP (Fcdr(val)))
         val = Fcar(val);
      }
   val = clean_local_selection_data (val);
   return val;
   }

#ifdef CUT_BUFFER_SUPPORT
DEFUN ("ns-get-cut-buffer-internal", Fns_get_cut_buffer_internal,
       Sns_get_cut_buffer_internal, 1, 1, 0,
  "Returns the value of the named cut buffer.")
  (buffer)
Lisp_Object buffer;
   {
   id pb;
   check_ns();
   pb=[NSPasteboard pasteboardWithName:symbol_to_nsstring(buffer)];
   return ns_string_from_pasteboard(pb);
   }

DEFUN ("ns-rotate-cut-buffers-internal", Fns_rotate_cut_buffers_internal,
       Sns_rotate_cut_buffers_internal, 1, 1, 0,
   "Rotate the values of the cut buffers by the given number of steps;\n\
 positive means move values forward, negative means backward.")
  (n)
     Lisp_Object n;
   {
   /* XXX This function is unimplemented under NeXTstep XXX */
   return Qnil;
   }

DEFUN ("ns-store-cut-buffer-internal", Fns_store_cut_buffer_internal,
       Sns_store_cut_buffer_internal, 2, 2, 0,
  "Sets the value of the named cut buffer (typically CUT_BUFFER0).")
  (buffer, string)
Lisp_Object buffer, string;
   {
   id pb;
   check_ns();
   pb=[NSPasteboard pasteboardWithName:symbol_to_nsstring(buffer)];
   ns_string_to_pasteboard(pb,string);
   return Qnil;
   }
#endif

void nxatoms_of_nsselect (void)
   {
   NXSecondaryPboard=@"NeXT secondary pasteboard name";
   }

void syms_of_nsselect (void)
   {
     QPRIMARY   = intern ("PRIMARY");	staticpro (&QPRIMARY);
     QSECONDARY = intern ("SECONDARY");	staticpro (&QSECONDARY);
     QTEXT      = intern ("TEXT"); 	staticpro (&QTEXT);
     QFILE_NAME = intern ("FILE_NAME"); 	staticpro (&QFILE_NAME);

   defsubr (&Sns_disown_selection_internal);
   defsubr (&Sns_get_selection_internal);
   defsubr (&Sns_own_selection_internal);
   defsubr (&Sns_selection_exists_p);
   defsubr (&Sns_selection_owner_p);
#ifdef CUT_BUFFER_SUPPORT
   defsubr (&Sns_get_cut_buffer_internal);
   defsubr (&Sns_rotate_cut_buffers_internal);
   defsubr (&Sns_store_cut_buffer_internal);
#endif

  Vselection_alist = Qnil;
  staticpro (&Vselection_alist);

  DEFVAR_LISP ("ns-sent-selection-hooks", &Vns_sent_selection_hooks,
    "A list of functions to be called when Emacs answers a selection request.\n\
The functions are called with four arguments:\n\
  - the selection name (typically `PRIMARY', `SECONDARY', or `CLIPBOARD');\n\
  - the selection-type which Emacs was asked to convert the\n\
    selection into before sending (for example, `STRING' or `LENGTH');\n\
  - a flag indicating success or failure for responding to the request.\n\
We might have failed (and declined the request) for any number of reasons,\n\
including being asked for a selection that we no longer own, or being asked\n\
to convert into a type that we don't know about or that is inappropriate.\n\
This hook doesn't let you change the behavior of Emacs's selection replies,\n\
it merely informs you that they have happened.");
  Vns_sent_selection_hooks = Qnil;

  DEFVAR_LISP ("selection-converter-alist", &Vselection_converter_alist,
    "An alist associating X Windows selection-types with functions.\n\
These functions are called to convert the selection, with three args:\n\
the name of the selection (typically `PRIMARY', `SECONDARY', or `CLIPBOARD');\n\
a desired type to which the selection should be converted;\n\
and the local selection value (whatever was given to `x-own-selection').\n\
\n\
The function should return the value to send to the X server\n\
\(typically a string).  A return value of nil\n\
means that the conversion could not be done.\n\
A return value which is the symbol `NULL'\n\
means that a side-effect was executed,\n\
and there is no meaningful selection value.");
  Vselection_converter_alist = Qnil;

  DEFVAR_LISP ("ns-lost-selection-hooks", &Vns_lost_selection_hooks,
    "A list of functions to be called when Emacs loses an X selection.\n\
\(This happens when some other X client makes its own selection\n\
or when a Lisp program explicitly clears the selection.)\n\
The functions are called with one argument, the selection type\n\
\(a symbol, typically `PRIMARY', `SECONDARY', or `CLIPBOARD').");
  Vns_lost_selection_hooks = Qnil;

   }
