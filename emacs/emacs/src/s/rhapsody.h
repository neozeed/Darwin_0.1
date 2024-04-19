/* Configuration file for the Rhapsody system.
   Copyright (C) 1997 Free Software Foundation, Inc.

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

/* We give these symbols the numeric values found in <sys/param.h> to
   avoid warnings about redefined macros.  */
#define BSD 199506
#define BSD4_3 1
#define BSD4_4 1

#include "bsd4-3.h"

/* SYSTEM_TYPE should indicate the kind of system you are using.
   It sets the Lisp variable system-type.  We'll need to undo the bsd one. */

#undef SYSTEM_TYPE
#define SYSTEM_TYPE "apple-rhapsody"

#ifndef NeXT
#define NeXT
#endif

#ifndef RHAPSODY
#define RHAPSODY
#endif

#define HAVE_ALLOCA

#define HAVE_MACH_MACH_H

#define SYSTEM_MALLOC

#define WAIT_USE_INT

#define SOCKLEN_TYPE int

#define GETPGRP_NO_ARG

#define TERMCAP_FILE "/usr/share/misc/termcap"

#define PENDING_OUTPUT_COUNT(FILE) ((FILE)->_p - (FILE)->_bf._base)

#define A_OUT_H_FILE <sys/exec.h>

/* Data type of load average, as read out of kmem.  */
#define LOAD_AVE_TYPE long

/* Convert that into an integer that is 100 for a load average of 1.0  */
#define LOAD_AVE_CVT(x) (int) (((double)(x)) * 100.0 / FSCALE)

#define UNEXEC unexnext.o

/* Definitions for how to compile & link.  */

/* Link this program just by running cc.  */
#define ORDINARY_LINK

/* #define C_SWITCH_SYSTEM */

#ifdef HAVE_NS
#define LD_SWITCH_SYSTEM -X  -sectcreate __ICON __header ${srcdir}/emacs.iconheader -segprot __ICON r r -sectcreate __ICON app ${srcdir}/bitmaps/emacs.tiff -sectcreate __ICON text ${srcdir}/bitmaps/text.tiff -sectcreate __ICON bibfile ${srcdir}/bitmaps/bibfile.tiff -sectcreate __ICON cfile ${srcdir}/bitmaps/cfile.tiff -sectcreate __ICON elfile ${srcdir}/bitmaps/elfile.tiff -sectcreate __ICON elcfile ${srcdir}/bitmaps/elfile.tiff -sectcreate __ICON hfile ${srcdir}/bitmaps/hfile.tiff -sectcreate __ICON mfile ${srcdir}/bitmaps/mfile.tiff -sectcreate __ICON texfile ${srcdir}/bitmaps/texfile.tiff -sectcreate __ICON lfile ${srcdir}/bitmaps/lfile.tiff -sectcreate __ICON yfile ${srcdir}/bitmaps/yfile.tiff -sectcreate __ICON f90file ${srcdir}/bitmaps/f90file.tiff

#define LIBS_SYSTEM -framework AppKit

#define HAVE_MENUS

#endif

/* We don't have a g library, so override the -lg LIBS_DEBUG switch */
#define LIBS_DEBUG

/* Adding -lm confuses the dynamic linker, so omit it. */
#define LIB_MATH

/* Definitions for how to dump.  */

#define START_FILES pre-crt0.o

/* start_of_text isn't actually used, so make it compile without error.  */
#define TEXT_START (0)

/* This seems to be right for end_of_text, but it may not be used anyway.  */
#define TEXT_END get_etext()

/* This seems to be right for end_of_data, but it may not be used anyway.  */
#define DATA_END get_edata()

