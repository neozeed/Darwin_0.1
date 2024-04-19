/* Markers: examining, setting and killing.
   Copyright (C) 1985 Free Software Foundation, Inc.

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
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */


#include <config.h>
#include "lisp.h"
#include "buffer.h"

/* Operations on markers. */

DEFUN ("marker-buffer", Fmarker_buffer, Smarker_buffer, 1, 1, 0,
  "Return the buffer that MARKER points into, or nil if none.\n\
Returns nil if MARKER points into a dead buffer.")
  (marker)
     register Lisp_Object marker;
{
  register Lisp_Object buf;
  CHECK_MARKER (marker, 0);
  if (XMARKER (marker)->buffer)
    {
      XSETBUFFER (buf, XMARKER (marker)->buffer);
      /* Return marker's buffer only if it is not dead.  */
      if (!NILP (XBUFFER (buf)->name))
	return buf;
    }
  return Qnil;
}

DEFUN ("marker-position", Fmarker_position, Smarker_position, 1, 1, 0,
  "Return the position MARKER points at, as a character number.")
  (marker)
     Lisp_Object marker;
{
  register Lisp_Object pos;
  register int i;
  register struct buffer *buf;

  CHECK_MARKER (marker, 0);
  if (XMARKER (marker)->buffer)
    {
      buf = XMARKER (marker)->buffer;
      i = XMARKER (marker)->bufpos;

      if (i > BUF_GPT (buf) + BUF_GAP_SIZE (buf))
	i -= BUF_GAP_SIZE (buf);
      else if (i > BUF_GPT (buf))
	i = BUF_GPT (buf);

      if (i < BUF_BEG (buf) || i > BUF_Z (buf))
	abort ();

      XSETFASTINT (pos, i);
      return pos;
    }
  return Qnil;
}

DEFUN ("set-marker", Fset_marker, Sset_marker, 2, 3, 0,
  "Position MARKER before character number POSITION in BUFFER.\n\
BUFFER defaults to the current buffer.\n\
If POSITION is nil, makes marker point nowhere.\n\
Then it no longer slows down editing in any buffer.\n\
Returns MARKER.")
  (marker, position, buffer)
     Lisp_Object marker, position, buffer;
{
  register int charno;
  register struct buffer *b;
  register struct Lisp_Marker *m;

  CHECK_MARKER (marker, 0);
  /* If position is nil or a marker that points nowhere,
     make this marker point nowhere.  */
  if (NILP (position)
      || (MARKERP (position) && !XMARKER (position)->buffer))
    {
      unchain_marker (marker);
      return marker;
    }

  CHECK_NUMBER_COERCE_MARKER (position, 1);
  if (NILP (buffer))
    b = current_buffer;
  else
    {
      CHECK_BUFFER (buffer, 1);
      b = XBUFFER (buffer);
      /* If buffer is dead, set marker to point nowhere.  */
      if (EQ (b->name, Qnil))
	{
	  unchain_marker (marker);
	  return marker;
	}
    }

  charno = XINT (position);
  m = XMARKER (marker);

  if (charno < BUF_BEG (b))
    charno = BUF_BEG (b);
  if (charno > BUF_Z (b))
    charno = BUF_Z (b);
  if (charno > BUF_GPT (b)) charno += BUF_GAP_SIZE (b);
  m->bufpos = charno;

  if (m->buffer != b)
    {
      unchain_marker (marker);
      m->buffer = b;
      m->chain = BUF_MARKERS (b);
      BUF_MARKERS (b) = marker;
    }
  
  return marker;
}

/* This version of Fset_marker won't let the position
   be outside the visible part.  */

Lisp_Object 
set_marker_restricted (marker, pos, buffer)
     Lisp_Object marker, pos, buffer;
{
  register int charno;
  register struct buffer *b;
  register struct Lisp_Marker *m;

  CHECK_MARKER (marker, 0);
  /* If position is nil or a marker that points nowhere,
     make this marker point nowhere.  */
  if (NILP (pos) ||
      (MARKERP (pos) && !XMARKER (pos)->buffer))
    {
      unchain_marker (marker);
      return marker;
    }

  CHECK_NUMBER_COERCE_MARKER (pos, 1);
  if (NILP (buffer))
    b = current_buffer;
  else
    {
      CHECK_BUFFER (buffer, 1);
      b = XBUFFER (buffer);
      /* If buffer is dead, set marker to point nowhere.  */
      if (EQ (b->name, Qnil))
	{
	  unchain_marker (marker);
	  return marker;
	}
    }

  charno = XINT (pos);
  m = XMARKER (marker);

  if (charno < BUF_BEGV (b))
    charno = BUF_BEGV (b);
  if (charno > BUF_ZV (b))
    charno = BUF_ZV (b);
  if (charno > BUF_GPT (b))
    charno += BUF_GAP_SIZE (b);
  m->bufpos = charno;

  if (m->buffer != b)
    {
      unchain_marker (marker);
      m->buffer = b;
      m->chain = BUF_MARKERS (b);
      BUF_MARKERS (b) = marker;
    }
  
  return marker;
}

/* This is called during garbage collection,
   so we must be careful to ignore and preserve mark bits,
   including those in chain fields of markers.  */

unchain_marker (marker)
     register Lisp_Object marker;
{
  register Lisp_Object tail, prev, next;
  register EMACS_INT omark;
  register struct buffer *b;

  b = XMARKER (marker)->buffer;
  if (b == 0)
    return;

  if (EQ (b->name, Qnil))
    abort ();

  tail = BUF_MARKERS (b);
  prev = Qnil;
  while (XSYMBOL (tail) != XSYMBOL (Qnil))
    {
      next = XMARKER (tail)->chain;
      XUNMARK (next);

      if (XMARKER (marker) == XMARKER (tail))
	{
	  if (NILP (prev))
	    {
	      BUF_MARKERS (b) = next;
	      /* Deleting first marker from the buffer's chain.  Crash
		 if new first marker in chain does not say it belongs
		 to the same buffer, or at least that they have the same
		 base buffer.  */
	      if (!NILP (next) && b->text != XMARKER (next)->buffer->text)
		abort ();
	    }
	  else
	    {
	      omark = XMARKBIT (XMARKER (prev)->chain);
	      XMARKER (prev)->chain = next;
	      XSETMARKBIT (XMARKER (prev)->chain, omark);
	    }
	  break;
	}
      else
	prev = tail;
      tail = next;
    }
  XMARKER (marker)->buffer = 0;
}

/* Return the buffer position of marker MARKER, as a C integer.  */

int
marker_position (marker)
     Lisp_Object marker;
{
  register struct Lisp_Marker *m = XMARKER (marker);
  register struct buffer *buf = m->buffer;
  register int i = m->bufpos;

  if (!buf)
    error ("Marker does not point anywhere");

  if (i > BUF_GPT (buf) + BUF_GAP_SIZE (buf))
    i -= BUF_GAP_SIZE (buf);
  else if (i > BUF_GPT (buf))
    i = BUF_GPT (buf);

  if (i < BUF_BEG (buf) || i > BUF_Z (buf))
    abort ();

  return i;
}

DEFUN ("copy-marker", Fcopy_marker, Scopy_marker, 1, 2, 0,
  "Return a new marker pointing at the same place as MARKER.\n\
If argument is a number, makes a new marker pointing\n\
at that position in the current buffer.\n\
The optional argument TYPE specifies the insertion type of the new marker;\n\
see `marker-insertion-type'.")
  (marker, type)
     register Lisp_Object marker, type;
{
  register Lisp_Object new;

  if (INTEGERP (marker) || MARKERP (marker))
    {
      new = Fmake_marker ();
      Fset_marker (new, marker,
		   (MARKERP (marker) ? Fmarker_buffer (marker) : Qnil));
      XMARKER (new)->insertion_type = !NILP (type);
      return new;
    }
  else
    marker = wrong_type_argument (Qinteger_or_marker_p, marker);
}

DEFUN ("marker-insertion-type", Fmarker_insertion_type,
       Smarker_insertion_type, 1, 1, 0,
  "Return insertion type of MARKER: t if it stays after inserted text.\n\
nil means the marker stays before text inserted there.")
  (marker)
     register Lisp_Object marker;
{
  register Lisp_Object buf;
  CHECK_MARKER (marker, 0);
  return XMARKER (marker)->insertion_type ? Qt : Qnil;
}

DEFUN ("set-marker-insertion-type", Fset_marker_insertion_type,
       Sset_marker_insertion_type, 2, 2, 0,
  "Set the insertion-type of MARKER to TYPE.\n\
If TYPE is t, it means the marker advances when you insert text at it.\n\
If TYPE is nil, it means the marker stays behind when you insert text at it.")
  (marker, type)
     Lisp_Object marker, type;
{
  CHECK_MARKER (marker, 0);

  XMARKER (marker)->insertion_type = ! NILP (type);
  return type;
}

DEFUN ("buffer-has-markers-at", Fbuffer_has_markers_at, Sbuffer_has_markers_at,
  1, 1, 0,
  "Return t if there are markers pointing at POSITION in the currentbuffer.")
  (position)
      Lisp_Object position;
{
  register Lisp_Object tail;
  register int charno;

  charno = XINT (position);

  if (charno < BEG)
    charno = BEG;
  if (charno > Z)
    charno = Z;
  if (charno > GPT) charno += GAP_SIZE;

  for (tail = BUF_MARKERS (current_buffer);
       XSYMBOL (tail) != XSYMBOL (Qnil);
       tail = XMARKER (tail)->chain)
    if (XMARKER (tail)->bufpos == charno)
      return Qt;

  return Qnil;
}

syms_of_marker ()
{
  defsubr (&Smarker_position);
  defsubr (&Smarker_buffer);
  defsubr (&Sset_marker);
  defsubr (&Scopy_marker);
  defsubr (&Smarker_insertion_type);
  defsubr (&Sset_marker_insertion_type);
  defsubr (&Sbuffer_has_markers_at);
}
