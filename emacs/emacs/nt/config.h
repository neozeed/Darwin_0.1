/* GNU Emacs site configuration template file.  -*- C -*-
   Copyright (C) 1988, 1993, 1994 Free Software Foundation, Inc.

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


/* No code in Emacs #includes config.h twice, but some of the code
   intended to work with other packages as well (like gmalloc.c) 
   think they can include it as many times as they like.  */
#ifndef EMACS_CONFIG_H
#define EMACS_CONFIG_H


/* These are all defined in the top-level Makefile by configure.
   They're here only for reference.  */

/* Define LISP_FLOAT_TYPE if you want emacs to support floating-point
   numbers. */
#undef LISP_FLOAT_TYPE

/* Define GNU_MALLOC if you want to use the *new* GNU memory allocator. */
#undef GNU_MALLOC

/* Define REL_ALLOC if you want to use the relocating allocator for
   buffer space. */
#undef REL_ALLOC
  
/* Define HAVE_X_WINDOWS if you want to use the X window system.  */
#undef HAVE_X_WINDOWS

/* Define HAVE_X11 if you want to use version 11 of X windows.
   Otherwise, Emacs expects to use version 10.  */
#undef HAVE_X11

/* Define if using an X toolkit.  */
#undef USE_X_TOOLKIT

/* Define this if you're using XFree386.  */
#undef HAVE_XFREE386

/* Define HAVE_X_MENU if you want to use the X window menu system.
   This appears to work on some machines that support X
   and not on others.  */
#undef HAVE_X_MENU

/* Define if we have the X11R6 or newer version of Xt.  */
#undef HAVE_X11XTR6

/* Define if netdb.h declares h_errno.  */
#undef HAVE_H_ERRNO

/* Nowadays we have frame objects even if we support only ASCII terminals.  */
#define MULTI_FRAME

/* If we're using any sort of window system, define some consequences.  */
#ifdef HAVE_X_WINDOWS
#define MULTI_KBOARD
#define HAVE_FACES
#define HAVE_MOUSE
#endif

/* Define USE_TEXT_PROPERTIES to support visual and other properties
   on text. */
#define USE_TEXT_PROPERTIES

/* Define USER_FULL_NAME to return a string
   that is the user's full name.
   It can assume that the variable `pw'
   points to the password file entry for this user.

   At some sites, the pw_gecos field contains
   the user's full name.  If neither this nor any other
   field contains the right thing, use pw_name,
   giving the user's login name, since that is better than nothing.  */
#define USER_FULL_NAME pw->pw_gecos

/* Define AMPERSAND_FULL_NAME if you use the convention
   that & in the full name stands for the login id.  */
#undef AMPERSAND_FULL_NAME

/* Things set by --with options in the configure script.  */

/* Define to support POP mail retrieval.  */
#undef MAIL_USE_POP

/* Define to support Kerberos-authenticated POP mail retrieval.  */
#undef KERBEROS

/* Define to support using a Hesiod database to find the POP server.  */
#undef HESIOD

/* Some things figured out by the configure script, grouped as they are in
   configure.in.  */
#ifndef _ALL_SOURCE  /* suppress warning if this is pre-defined */
#undef _ALL_SOURCE
#endif
#undef HAVE_SYS_SELECT_H
#undef HAVE_SYS_TIMEB_H
#undef HAVE_SYS_TIME_H
#undef HAVE_UNISTD_H
#undef HAVE_UTIME_H
#undef STDC_HEADERS
#undef TIME_WITH_SYS_TIME

#undef HAVE_LIBDNET
#undef HAVE_LIBRESOLV

#undef HAVE_ALLOCA_H

#undef HAVE_GETTIMEOFDAY
#undef HAVE_GETHOSTNAME
#undef HAVE_DUP2
#undef HAVE_RENAME
#undef HAVE_CLOSEDIR

#undef TM_IN_SYS_TIME
#undef HAVE_TM_ZONE
#undef HAVE_TZNAME

#undef const

#undef HAVE_LONG_FILE_NAMES

#undef CRAY_STACKSEG_END

#undef UNEXEC_SRC

#undef HAVE_LIBXBSD
#undef HAVE_XRMSETDATABASE
#undef HAVE_XSCREENRESOURCESTRING
#undef HAVE_XSCREENNUMBEROFSCREEN
#undef HAVE_XSETWMPROTOCOLS

#undef HAVE_MKDIR
#undef HAVE_RMDIR
#undef HAVE_RANDOM
#undef HAVE_LRAND48
#undef HAVE_BCOPY
#undef HAVE_BCMP
#undef HAVE_LOGB
#undef HAVE_FREXP
#undef HAVE_FMOD
#undef HAVE_FTIME
#undef HAVE_RES_INIT /* For -lresolv on Suns.  */
#undef HAVE_SETSID
#undef HAVE_FPATHCONF
#undef HAVE_SELECT
#undef HAVE_MKTIME
#undef HAVE_EACCESS
#undef HAVE_GETPAGESIZE
#undef HAVE_INET_SOCKETS

#undef HAVE_AIX_SMT_EXP

/* Define if you have the ANSI `strerror' function.
   Otherwise you must have the variable `char *sys_errlist[]'.  */
#undef HAVE_STRERROR

#undef HAVE_UTIMES

/* Define if `sys_siglist' is declared by <signal.h>.  */
#undef SYS_SIGLIST_DECLARED

/* Define if `struct utimbuf' is declared by <utime.h>.  */
#undef HAVE_STRUCT_UTIMBUF

/* Define if `struct timeval' is declared by <sys/time.h>.  */
#undef HAVE_TIMEVAL

/* If using GNU, then support inline function declarations. */
#ifdef __GNUC__
#define INLINE __inline__
#else
#define INLINE
#endif

#undef EMACS_CONFIGURATION

#undef EMACS_CONFIG_OPTIONS

/* The configuration script defines opsysfile to be the name of the
   s/SYSTEM.h file that describes the system type you are using.  The file
   is chosen based on the configuration name you give.

   See the file ../etc/MACHINES for a list of systems and the
   configuration names to use for them.

   See s/template.h for documentation on writing s/SYSTEM.h files.  */
#undef config_opsysfile 
#include "s/windowsnt.h"

/* The configuration script defines machfile to be the name of the
   m/MACHINE.h file that describes the machine you are using.  The file is
   chosen based on the configuration name you give.

   See the file ../etc/MACHINES for a list of machines and the
   configuration names to use for them.

   See m/template.h for documentation on writing m/MACHINE.h files.  */
#undef config_machfile
#include "m/intel386.h"

/* These typedefs shouldn't appear when alloca.s or Makefile.in
   includes config.h.  */
#ifndef NOT_C_CODE
#ifndef SPECIAL_EMACS_INT
typedef long EMACS_INT;
typedef unsigned long EMACS_UINT;
#endif
#endif

/* Load in the conversion definitions if this system
   needs them and the source file being compiled has not
   said to inhibit this.  There should be no need for you
   to alter these lines.  */

#ifdef SHORTNAMES
#ifndef NO_SHORTNAMES
#include "../shortnames/remap.h"
#endif /* not NO_SHORTNAMES */
#endif /* SHORTNAMES */

/* If no remapping takes place, static variables cannot be dumped as
   pure, so don't worry about the `static' keyword. */
#ifdef NO_REMAP
#undef static
#endif

/* Define `subprocesses' should be defined if you want to
   have code for asynchronous subprocesses
   (as used in M-x compile and M-x shell).
   These do not work for some USG systems yet;
   for the ones where they work, the s/SYSTEM.h file defines this flag.  */

#ifndef VMS
#ifndef USG
/* #define subprocesses */
#endif
#endif

/* Define LD_SWITCH_SITE to contain any special flags your loader may need.  */
#undef LD_SWITCH_SITE

/* Define C_SWITCH_SITE to contain any special flags your compiler needs.  */
#undef C_SWITCH_SITE

/* Define LD_SWITCH_X_SITE to contain any special flags your loader
   may need to deal with X Windows.  For instance, if you've defined
   HAVE_X_WINDOWS above and your X libraries aren't in a place that
   your loader can find on its own, you might want to add "-L/..." or
   something similar.  */
#undef LD_SWITCH_X_SITE

/* Define LD_SWITCH_X_SITE_AUX with an -R option
   in case it's needed (for Solaris, for example).  */
#undef LD_SWITCH_X_SITE_AUX

/* Define C_SWITCH_X_SITE to contain any special flags your compiler
   may need to deal with X Windows.  For instance, if you've defined
   HAVE_X_WINDOWS above and your X include files aren't in a place
   that your compiler can find on its own, you might want to add
   "-I/..." or something similar.  */
#undef C_SWITCH_X_SITE

/* Define STACK_DIRECTION here, but not if m/foo.h did.  */
#ifndef STACK_DIRECTION
#undef STACK_DIRECTION
#endif

/* Define the return type of signal handlers if the s-xxx file
   did not already do so.  */
#define RETSIGTYPE void

/* SIGTYPE is the macro we actually use.  */
#ifndef SIGTYPE
#define SIGTYPE RETSIGTYPE
#endif

/* The rest of the code currently tests the CPP symbol BSTRING.
   Override any claims made by the system-description files.
   Note that on some SCO version it is possible to have bcopy and not bcmp.  */
#undef BSTRING
#if defined (HAVE_BCOPY) && defined (HAVE_BCMP)
#define BSTRING
#endif

/* Non-ANSI C compilers usually don't have volatile.  */
#ifndef HAVE_VOLATILE
#ifndef __STDC__
#define volatile
#endif
#endif

/* Some of the files of Emacs which are intended for use with other
   programs assume that if you have a config.h file, you must declare
   the type of getenv.

   This declaration shouldn't appear when alloca.s or Makefile.in
   includes config.h.  */
#ifndef NOT_C_CODE
extern char *getenv ();
#endif

#endif /* EMACS_CONFIG_H */
