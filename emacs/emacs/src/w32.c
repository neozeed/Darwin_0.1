/* Utility and Unix shadow routines for GNU Emacs on the Microsoft W32 API.
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.

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
Boston, MA 02111-1307, USA.

   Geoff Voelker (voelker@cs.washington.edu)                         7-29-94
*/


#include <stddef.h> /* for offsetof */
#include <stdlib.h>
#include <stdio.h>
#include <io.h>
#include <errno.h>
#include <fcntl.h>
#include <ctype.h>
#include <signal.h>
#include <sys/time.h>

/* must include CRT headers *before* config.h */
#include "config.h"
#undef access
#undef chdir
#undef chmod
#undef creat
#undef ctime
#undef fopen
#undef link
#undef mkdir
#undef mktemp
#undef open
#undef rename
#undef rmdir
#undef unlink

#undef close
#undef dup
#undef dup2
#undef pipe
#undef read
#undef write

#include "lisp.h"

#include <pwd.h>

#include <windows.h>

#ifdef HAVE_SOCKETS	/* TCP connection support, if kernel can do it */
#include <sys/socket.h>
#undef socket
#undef bind
#undef connect
#undef htons
#undef ntohs
#undef inet_addr
#undef gethostname
#undef gethostbyname
#undef getservbyname
#undef shutdown
#endif

#include "w32.h"
#include "ndir.h"
#include "w32heap.h"
 
extern Lisp_Object Vw32_downcase_file_names;
extern Lisp_Object Vw32_generate_fake_inodes;
extern Lisp_Object Vw32_get_true_file_attributes;

static char startup_dir[MAXPATHLEN];

/* Get the current working directory.  */
char *
getwd (char *dir)
{
#if 0
  if (GetCurrentDirectory (MAXPATHLEN, dir) > 0)
    return dir;
  return NULL;
#else
  /* Emacs doesn't actually change directory itself, and we want to
     force our real wd to be where emacs.exe is to avoid unnecessary
     conflicts when trying to rename or delete directories.  */
  strcpy (dir, startup_dir);
  return dir;
#endif
}

#ifndef HAVE_SOCKETS
/* Emulate gethostname.  */
int
gethostname (char *buffer, int size)
{
  /* NT only allows small host names, so the buffer is 
     certainly large enough.  */
  return !GetComputerName (buffer, &size);
}
#endif /* HAVE_SOCKETS */

/* Emulate getloadavg.  */
int
getloadavg (double loadavg[], int nelem)
{
  int i;

  /* A faithful emulation is going to have to be saved for a rainy day.  */
  for (i = 0; i < nelem; i++) 
    {
      loadavg[i] = 0.0;
    }
  return i;
}

/* Emulate getpwuid, getpwnam and others.  */

#define PASSWD_FIELD_SIZE 256

static char the_passwd_name[PASSWD_FIELD_SIZE];
static char the_passwd_passwd[PASSWD_FIELD_SIZE];
static char the_passwd_gecos[PASSWD_FIELD_SIZE];
static char the_passwd_dir[PASSWD_FIELD_SIZE];
static char the_passwd_shell[PASSWD_FIELD_SIZE];

static struct passwd the_passwd = 
{
  the_passwd_name,
  the_passwd_passwd,
  0,
  0,
  0,
  the_passwd_gecos,
  the_passwd_dir,
  the_passwd_shell,
};

int 
getuid () 
{ 
  return the_passwd.pw_uid;
}

int 
geteuid () 
{ 
  /* I could imagine arguing for checking to see whether the user is
     in the Administrators group and returning a UID of 0 for that
     case, but I don't know how wise that would be in the long run.  */
  return getuid (); 
}

int 
getgid () 
{ 
  return the_passwd.pw_gid;
}

int 
getegid () 
{ 
  return getgid ();
}

struct passwd *
getpwuid (int uid)
{
  if (uid == the_passwd.pw_uid)
    return &the_passwd;
  return NULL;
}

struct passwd *
getpwnam (char *name)
{
  struct passwd *pw;
  
  pw = getpwuid (getuid ());
  if (!pw)
    return pw;

  if (stricmp (name, pw->pw_name))
    return NULL;

  return pw;
}

void
init_user_info ()
{
  /* Find the user's real name by opening the process token and
     looking up the name associated with the user-sid in that token.

     Use the relative portion of the identifier authority value from
     the user-sid as the user id value (same for group id using the
     primary group sid from the process token). */

  char            user_sid[256], name[256], domain[256];
  DWORD           length = sizeof (name), dlength = sizeof (domain), trash;
  HANDLE          token = NULL;
  SID_NAME_USE    user_type;

  if (OpenProcessToken (GetCurrentProcess (), TOKEN_QUERY, &token)
      && GetTokenInformation (token, TokenUser,
			      (PVOID) user_sid, sizeof (user_sid), &trash)
      && LookupAccountSid (NULL, *((PSID *) user_sid), name, &length,
			   domain, &dlength, &user_type))
    {
      strcpy (the_passwd.pw_name, name);
      /* Determine a reasonable uid value. */
      if (stricmp ("administrator", name) == 0)
	{
	  the_passwd.pw_uid = 0;
	  the_passwd.pw_gid = 0;
	}
      else
	{
	  SID_IDENTIFIER_AUTHORITY * pSIA;

	  pSIA = GetSidIdentifierAuthority (*((PSID *) user_sid));
	  /* I believe the relative portion is the last 4 bytes (of 6)
	     with msb first. */
	  the_passwd.pw_uid = ((pSIA->Value[2] << 24) +
			       (pSIA->Value[3] << 16) +
			       (pSIA->Value[4] << 8)  +
			       (pSIA->Value[5] << 0));
	  /* restrict to conventional uid range for normal users */
	  the_passwd.pw_uid = the_passwd.pw_uid % 60001;

	  /* Get group id */
	  if (GetTokenInformation (token, TokenPrimaryGroup,
				   (PVOID) user_sid, sizeof (user_sid), &trash))
	    {
	      SID_IDENTIFIER_AUTHORITY * pSIA;

	      pSIA = GetSidIdentifierAuthority (*((PSID *) user_sid));
	      the_passwd.pw_gid = ((pSIA->Value[2] << 24) +
				   (pSIA->Value[3] << 16) +
				   (pSIA->Value[4] << 8)  +
				   (pSIA->Value[5] << 0));
	      /* I don't know if this is necessary, but for safety... */
	      the_passwd.pw_gid = the_passwd.pw_gid % 60001;
	    }
	  else
	    the_passwd.pw_gid = the_passwd.pw_uid;
	}
    }
  /* If security calls are not supported (presumably because we
       are running under Windows 95), fallback to this. */
  else if (GetUserName (name, &length))
    {
      strcpy (the_passwd.pw_name, name);
      if (stricmp ("administrator", name) == 0)
	the_passwd.pw_uid = 0;
      else
	the_passwd.pw_uid = 123;
      the_passwd.pw_gid = the_passwd.pw_uid;
    }
  else
    {
      strcpy (the_passwd.pw_name, "unknown");
      the_passwd.pw_uid = 123;
      the_passwd.pw_gid = 123;
    }

  /* Ensure HOME and SHELL are defined. */
  if (getenv ("HOME") == NULL)
    putenv ("HOME=c:/");
  if (getenv ("SHELL") == NULL)
    putenv (os_subtype == OS_WIN95 ? "SHELL=command" : "SHELL=cmd");

  /* Set dir and shell from environment variables. */
  strcpy (the_passwd.pw_dir, getenv ("HOME"));
  strcpy (the_passwd.pw_shell, getenv ("SHELL"));

  if (token)
    CloseHandle (token);
}

int
random ()
{
  /* rand () on NT gives us 15 random bits...hack together 30 bits.  */
  return ((rand () << 15) | rand ());
}

void
srandom (int seed)
{
  srand (seed);
}


/* Normalize filename by converting all path separators to
   the specified separator.  Also conditionally convert upper
   case path name components to lower case.  */

static void
normalize_filename (fp, path_sep)
     register char *fp;
     char path_sep;
{
  char sep;
  char *elem;

  /* Always lower-case drive letters a-z, even if the filesystem
     preserves case in filenames.
     This is so filenames can be compared by string comparison
     functions that are case-sensitive.  Even case-preserving filesystems
     do not distinguish case in drive letters.  */
  if (fp[1] == ':' && *fp >= 'A' && *fp <= 'Z')
    {
      *fp += 'a' - 'A';
      fp += 2;
    }

  if (NILP (Vw32_downcase_file_names))
    {
      while (*fp)
	{
	  if (*fp == '/' || *fp == '\\')
	    *fp = path_sep;
	  fp++;
	}
      return;
    }

  sep = path_sep;		/* convert to this path separator */
  elem = fp;			/* start of current path element */

  do {
    if (*fp >= 'a' && *fp <= 'z')
      elem = 0;			/* don't convert this element */

    if (*fp == 0 || *fp == ':')
      {
	sep = *fp;		/* restore current separator (or 0) */
	*fp = '/';		/* after conversion of this element */
      }

    if (*fp == '/' || *fp == '\\')
      {
	if (elem && elem != fp)
	  {
	    *fp = 0;		/* temporary end of string */
	    _strlwr (elem);	/* while we convert to lower case */
	  }
	*fp = sep;		/* convert (or restore) path separator */
	elem = fp + 1;		/* next element starts after separator */
	sep = path_sep;
      }
  } while (*fp++);
}

/* Destructively turn backslashes into slashes.  */
void
dostounix_filename (p)
     register char *p;
{
  normalize_filename (p, '/');
}

/* Destructively turn slashes into backslashes.  */
void
unixtodos_filename (p)
     register char *p;
{
  normalize_filename (p, '\\');
}

/* Remove all CR's that are followed by a LF.
   (From msdos.c...probably should figure out a way to share it,
   although this code isn't going to ever change.)  */
int
crlf_to_lf (n, buf)
     register int n;
     register unsigned char *buf;
{
  unsigned char *np = buf;
  unsigned char *startp = buf;
  unsigned char *endp = buf + n;

  if (n == 0)
    return n;
  while (buf < endp - 1)
    {
      if (*buf == 0x0d)
	{
	  if (*(++buf) != 0x0a)
	    *np++ = 0x0d;
	}
      else
	*np++ = *buf++;
    }
  if (buf < endp)
    *np++ = *buf++;
  return np - startp;
}

/* Parse the root part of file name, if present.  Return length and
    optionally store pointer to char after root.  */
static int
parse_root (char * name, char ** pPath)
{
  char * start = name;

  if (name == NULL)
    return 0;

  /* find the root name of the volume if given */
  if (isalpha (name[0]) && name[1] == ':')
    {
      /* skip past drive specifier */
      name += 2;
      if (IS_DIRECTORY_SEP (name[0]))
	name++;
    }
  else if (IS_DIRECTORY_SEP (name[0]) && IS_DIRECTORY_SEP (name[1]))
    {
      int slashes = 2;
      name += 2;
      do
        {
	  if (IS_DIRECTORY_SEP (*name) && --slashes == 0)
	    break;
	  name++;
	}
      while ( *name );
      if (IS_DIRECTORY_SEP (name[0]))
	name++;
    }

  if (pPath)
    *pPath = name;

  return name - start;
}

/* Get long base name for name; name is assumed to be absolute.  */
static int
get_long_basename (char * name, char * buf, int size)
{
  WIN32_FIND_DATA find_data;
  HANDLE dir_handle;
  int len = 0;

  dir_handle = FindFirstFile (name, &find_data);
  if (dir_handle != INVALID_HANDLE_VALUE)
    {
      if ((len = strlen (find_data.cFileName)) < size)
	memcpy (buf, find_data.cFileName, len + 1);
      else
	len = 0;
      FindClose (dir_handle);
    }
  return len;
}

/* Get long name for file, if possible (assumed to be absolute).  */
BOOL
w32_get_long_filename (char * name, char * buf, int size)
{
  char * o = buf;
  char * p;
  char * q;
  char full[ MAX_PATH ];
  int len;

  len = strlen (name);
  if (len >= MAX_PATH)
    return FALSE;

  /* Use local copy for destructive modification.  */
  memcpy (full, name, len+1);
  unixtodos_filename (full);

  /* Copy root part verbatim.  */
  len = parse_root (full, &p);
  memcpy (o, full, len);
  o += len;
  size -= len;

  do
    {
      q = p;
      p = strchr (q, '\\');
      if (p) *p = '\0';
      len = get_long_basename (full, o, size);
      if (len > 0)
	{
	  o += len;
	  size -= len;
	  if (p != NULL)
	    {
	      *p++ = '\\';
	      if (size < 2)
		return FALSE;
	      *o++ = '\\';
	      size--;
	      *o = '\0';
	    }
	}
      else
	return FALSE;
    }
  while (p != NULL && *p);

  return TRUE;
}


/* Routines that are no-ops on NT but are defined to get Emacs to compile.  */

int 
sigsetmask (int signal_mask) 
{ 
  return 0;
}

int 
sigblock (int sig) 
{ 
  return 0;
}

int 
setpgrp (int pid, int gid) 
{ 
  return 0;
}

int 
alarm (int seconds) 
{ 
  return 0;
}

int 
unrequest_sigio (void) 
{ 
  return 0;
}

int 
request_sigio (void) 
{ 
  return 0;
}

#define REG_ROOT "SOFTWARE\\GNU\\Emacs"

LPBYTE 
w32_get_resource (key, lpdwtype)
    char *key;
    LPDWORD lpdwtype;
{
  LPBYTE lpvalue;
  HKEY hrootkey = NULL;
  DWORD cbData;
  BOOL ok = FALSE;
  
  /* Check both the current user and the local machine to see if 
     we have any resources.  */
  
  if (RegOpenKeyEx (HKEY_CURRENT_USER, REG_ROOT, 0, KEY_READ, &hrootkey) == ERROR_SUCCESS)
    {
      lpvalue = NULL;

      if (RegQueryValueEx (hrootkey, key, NULL, NULL, NULL, &cbData) == ERROR_SUCCESS 
	  && (lpvalue = (LPBYTE) xmalloc (cbData)) != NULL 
	  && RegQueryValueEx (hrootkey, key, NULL, lpdwtype, lpvalue, &cbData) == ERROR_SUCCESS)
	{
	  return (lpvalue);
	}

      if (lpvalue) xfree (lpvalue);
	
      RegCloseKey (hrootkey);
    } 
  
  if (RegOpenKeyEx (HKEY_LOCAL_MACHINE, REG_ROOT, 0, KEY_READ, &hrootkey) == ERROR_SUCCESS)
    {
      lpvalue = NULL;
	
      if (RegQueryValueEx (hrootkey, key, NULL, NULL, NULL, &cbData) == ERROR_SUCCESS
	  && (lpvalue = (LPBYTE) xmalloc (cbData)) != NULL
	  && RegQueryValueEx (hrootkey, key, NULL, lpdwtype, lpvalue, &cbData) == ERROR_SUCCESS)
	{
	  return (lpvalue);
	}
	
      if (lpvalue) xfree (lpvalue);
	
      RegCloseKey (hrootkey);
    } 
  
  return (NULL);
}

char *get_emacs_configuration (void);
extern Lisp_Object Vsystem_configuration;

void
init_environment ()
{
  /* Check for environment variables and use registry if they don't exist */
  {
    int i;
    LPBYTE lpval;
    DWORD dwType;

    static char * env_vars[] = 
    {
      "HOME",
      "PRELOAD_WINSOCK",
      "emacs_dir",
      "EMACSLOADPATH",
      "SHELL",
      "CMDPROXY",
      "EMACSDATA",
      "EMACSPATH",
      "EMACSLOCKDIR",
      /* We no longer set INFOPATH because Info-default-directory-list
	 is then ignored.  We use a hook in winnt.el instead.  */
      /*      "INFOPATH", */
      "EMACSDOC",
      "TERM",
    };

    for (i = 0; i < (sizeof (env_vars) / sizeof (env_vars[0])); i++) 
      {
	if (!getenv (env_vars[i])
	    && (lpval = w32_get_resource (env_vars[i], &dwType)) != NULL)
	  {
	    if (dwType == REG_EXPAND_SZ)
	      {
		char buf1[500], buf2[500];

		ExpandEnvironmentStrings ((LPSTR) lpval, buf1, 500);
		_snprintf (buf2, 499, "%s=%s", env_vars[i], buf1);
		putenv (strdup (buf2));
	      }
	    else if (dwType == REG_SZ)
	      {
		char buf[500];
		  
		_snprintf (buf, 499, "%s=%s", env_vars[i], lpval);
		putenv (strdup (buf));
	      }

	    xfree (lpval);
	  }
      }
  }

  /* Rebuild system configuration to reflect invoking system.  */
  Vsystem_configuration = build_string (EMACS_CONFIGURATION);

  /* Another special case: on NT, the PATH variable is actually named
     "Path" although cmd.exe (perhaps NT itself) arranges for
     environment variable lookup and setting to be case insensitive.
     However, Emacs assumes a fully case sensitive environment, so we
     need to change "Path" to "PATH" to match the expectations of
     various elisp packages.  We do this by the sneaky method of
     modifying the string in the C runtime environ entry.

     The same applies to COMSPEC.  */
  {
    char ** envp;

    for (envp = environ; *envp; envp++)
      if (_strnicmp (*envp, "PATH=", 5) == 0)
	memcpy (*envp, "PATH=", 5);
      else if (_strnicmp (*envp, "COMSPEC=", 8) == 0)
	memcpy (*envp, "COMSPEC=", 8);
  }

  /* Remember the initial working directory for getwd, then make the
     real wd be the location of emacs.exe to avoid conflicts when
     renaming or deleting directories.  (We also don't call chdir when
     running subprocesses for the same reason.)  */
  if (!GetCurrentDirectory (MAXPATHLEN, startup_dir))
    abort ();

  {
    char *p;
    char modname[MAX_PATH];

    if (!GetModuleFileName (NULL, modname, MAX_PATH))
      abort ();
    if ((p = strrchr (modname, '\\')) == NULL)
      abort ();
    *p = 0;

    SetCurrentDirectory (modname);
  }

  init_user_info ();
}

/* We don't have scripts to automatically determine the system configuration
   for Emacs before it's compiled, and we don't want to have to make the
   user enter it, so we define EMACS_CONFIGURATION to invoke this runtime
   routine.  */

static char configuration_buffer[32];

char *
get_emacs_configuration (void)
{
  char *arch, *oem, *os;

  /* Determine the processor type.  */
  switch (get_processor_type ()) 
    {

#ifdef PROCESSOR_INTEL_386
    case PROCESSOR_INTEL_386:
    case PROCESSOR_INTEL_486:
    case PROCESSOR_INTEL_PENTIUM:
      arch = "i386";
      break;
#endif

#ifdef PROCESSOR_INTEL_860
    case PROCESSOR_INTEL_860:
      arch = "i860";
      break;
#endif

#ifdef PROCESSOR_MIPS_R2000
    case PROCESSOR_MIPS_R2000:
    case PROCESSOR_MIPS_R3000:
    case PROCESSOR_MIPS_R4000:
      arch = "mips";
      break;
#endif

#ifdef PROCESSOR_ALPHA_21064
    case PROCESSOR_ALPHA_21064:
      arch = "alpha";
      break;
#endif

    default:
      arch = "unknown";
      break;
    }

  /* Let oem be "*" until we figure out how to decode the OEM field.  */
  oem = "*";

  os = (GetVersion () & OS_WIN95) ? "windows95" : "nt";

  sprintf (configuration_buffer, "%s-%s-%s%d.%d", arch, oem, os,
	   get_w32_major_version (), get_w32_minor_version ());
  return configuration_buffer;
}

#include <sys/timeb.h>

/* Emulate gettimeofday (Ulrich Leodolter, 1/11/95).  */
void 
gettimeofday (struct timeval *tv, struct timezone *tz)
{
  struct _timeb tb;
  _ftime (&tb);

  tv->tv_sec = tb.time;
  tv->tv_usec = tb.millitm * 1000L;
  if (tz) 
    {
      tz->tz_minuteswest = tb.timezone;	/* minutes west of Greenwich  */
      tz->tz_dsttime = tb.dstflag;	/* type of dst correction  */
    }
}

/* ------------------------------------------------------------------------- */
/* IO support and wrapper functions for W32 API. */
/* ------------------------------------------------------------------------- */

/* Place a wrapper around the MSVC version of ctime.  It returns NULL
   on network directories, so we handle that case here.  
   (Ulrich Leodolter, 1/11/95).  */
char *
sys_ctime (const time_t *t)
{
  char *str = (char *) ctime (t);
  return (str ? str : "Sun Jan 01 00:00:00 1970");
}

/* Emulate sleep...we could have done this with a define, but that
   would necessitate including windows.h in the files that used it.
   This is much easier.  */
void
sys_sleep (int seconds)
{
  Sleep (seconds * 1000);
}

/* Internal MSVC functions for low-level descriptor munging */
extern int __cdecl _set_osfhnd (int fd, long h);
extern int __cdecl _free_osfhnd (int fd);

/* parallel array of private info on file handles */
filedesc fd_info [ MAXDESC ];

typedef struct volume_info_data {
  struct volume_info_data * next;

  /* time when info was obtained */
  DWORD     timestamp;

  /* actual volume info */
  char *    root_dir;
  DWORD     serialnum;
  DWORD     maxcomp;
  DWORD     flags;
  char *    name;
  char *    type;
} volume_info_data;

/* Global referenced by various functions.  */
static volume_info_data volume_info;

/* Vector to indicate which drives are local and fixed (for which cached
   data never expires).  */
static BOOL fixed_drives[26];

/* Consider cached volume information to be stale if older than 10s,
   at least for non-local drives.  Info for fixed drives is never stale.  */
#define DRIVE_INDEX( c ) ( (c) <= 'Z' ? (c) - 'A' : (c) - 'a' )
#define VOLINFO_STILL_VALID( root_dir, info )		\
  ( ( isalpha (root_dir[0]) &&				\
      fixed_drives[ DRIVE_INDEX (root_dir[0]) ] )	\
    || GetTickCount () - info->timestamp < 10000 )

/* Cache support functions.  */

/* Simple linked list with linear search is sufficient.  */
static volume_info_data *volume_cache = NULL;

static volume_info_data *
lookup_volume_info (char * root_dir)
{
  volume_info_data * info;

  for (info = volume_cache; info; info = info->next)
    if (stricmp (info->root_dir, root_dir) == 0)
      break;
  return info;
}

static void
add_volume_info (char * root_dir, volume_info_data * info)
{
  info->root_dir = strdup (root_dir);
  info->next = volume_cache;
  volume_cache = info;
}


/* Wrapper for GetVolumeInformation, which uses caching to avoid
   performance penalty (~2ms on 486 for local drives, 7.5ms for local
   cdrom drive, ~5-10ms or more for remote drives on LAN).  */
volume_info_data *
GetCachedVolumeInformation (char * root_dir)
{
  volume_info_data * info;
  char default_root[ MAX_PATH ];

  /* NULL for root_dir means use root from current directory.  */
  if (root_dir == NULL)
    {
      if (GetCurrentDirectory (MAX_PATH, default_root) == 0)
	return NULL;
      parse_root (default_root, &root_dir);
      *root_dir = 0;
      root_dir = default_root;
    }

  /* Local fixed drives can be cached permanently.  Removable drives
     cannot be cached permanently, since the volume name and serial
     number (if nothing else) can change.  Remote drives should be
     treated as if they are removable, since there is no sure way to
     tell whether they are or not.  Also, the UNC association of drive
     letters mapped to remote volumes can be changed at any time (even
     by other processes) without notice.
   
     As a compromise, so we can benefit from caching info for remote
     volumes, we use a simple expiry mechanism to invalidate cache
     entries that are more than ten seconds old.  */

#if 0
  /* No point doing this, because WNetGetConnection is even slower than
     GetVolumeInformation, consistently taking ~50ms on a 486 (FWIW,
     GetDriveType is about the only call of this type which does not
     involve network access, and so is extremely quick).  */

  /* Map drive letter to UNC if remote. */
  if ( isalpha( root_dir[0] ) && !fixed[ DRIVE_INDEX( root_dir[0] ) ] )
    {
      char remote_name[ 256 ];
      char drive[3] = { root_dir[0], ':' };

      if (WNetGetConnection (drive, remote_name, sizeof (remote_name))
	  == NO_ERROR)
	/* do something */ ;
    }
#endif

  info = lookup_volume_info (root_dir);

  if (info == NULL || ! VOLINFO_STILL_VALID (root_dir, info))
  {
    char  name[ 256 ];
    DWORD serialnum;
    DWORD maxcomp;
    DWORD flags;
    char  type[ 256 ];

    /* Info is not cached, or is stale. */
    if (!GetVolumeInformation (root_dir,
			       name, sizeof (name),
			       &serialnum,
			       &maxcomp,
			       &flags,
			       type, sizeof (type)))
      return NULL;

    /* Cache the volume information for future use, overwriting existing
       entry if present.  */
    if (info == NULL)
      {
	info = (volume_info_data *) xmalloc (sizeof (volume_info_data));
	add_volume_info (root_dir, info);
      }
    else
      {
	free (info->name);
	free (info->type);
      }

    info->name = strdup (name);
    info->serialnum = serialnum;
    info->maxcomp = maxcomp;
    info->flags = flags;
    info->type = strdup (type);
    info->timestamp = GetTickCount ();
  }

  return info;
}

/* Get information on the volume where name is held; set path pointer to
   start of pathname in name (past UNC header\volume header if present).  */
int
get_volume_info (const char * name, const char ** pPath)
{
  char temp[MAX_PATH];
  char *rootname = NULL;  /* default to current volume */
  volume_info_data * info;

  if (name == NULL)
    return FALSE;

  /* find the root name of the volume if given */
  if (isalpha (name[0]) && name[1] == ':')
    {
      rootname = temp;
      temp[0] = *name++;
      temp[1] = *name++;
      temp[2] = '\\';
      temp[3] = 0;
    }
  else if (IS_DIRECTORY_SEP (name[0]) && IS_DIRECTORY_SEP (name[1]))
    {
      char *str = temp;
      int slashes = 4;
      rootname = temp;
      do
        {
	  if (IS_DIRECTORY_SEP (*name) && --slashes == 0)
	    break;
	  *str++ = *name++;
	}
      while ( *name );

      *str++ = '\\';
      *str = 0;
    }

  if (pPath)
    *pPath = name;
    
  info = GetCachedVolumeInformation (rootname);
  if (info != NULL)
    {
      /* Set global referenced by other functions.  */
      volume_info = *info;
      return TRUE;
    }
  return FALSE;
}

/* Determine if volume is FAT format (ie. only supports short 8.3
   names); also set path pointer to start of pathname in name.  */
int
is_fat_volume (const char * name, const char ** pPath)
{
  if (get_volume_info (name, pPath))
    return (volume_info.maxcomp == 12);
  return FALSE;
}

/* Map filename to a legal 8.3 name if necessary. */
const char *
map_w32_filename (const char * name, const char ** pPath)
{
  static char shortname[MAX_PATH];
  char * str = shortname;
  char c;
  char * path;
  const char * save_name = name;

  if (is_fat_volume (name, &path)) /* truncate to 8.3 */
    {
      register int left = 8;	/* maximum number of chars in part */
      register int extn = 0;	/* extension added? */
      register int dots = 2;	/* maximum number of dots allowed */

      while (name < path)
	*str++ = *name++;	/* skip past UNC header */

      while ((c = *name++))
        {
	  switch ( c )
	    {
	    case '\\':
	    case '/':
	      *str++ = '\\';
	      extn = 0;		/* reset extension flags */
	      dots = 2;		/* max 2 dots */
	      left = 8;		/* max length 8 for main part */
	      break;
	    case ':':
	      *str++ = ':';
	      extn = 0;		/* reset extension flags */
	      dots = 2;		/* max 2 dots */
	      left = 8;		/* max length 8 for main part */
	      break;
	    case '.':
	      if ( dots )
	        {
		  /* Convert path components of the form .xxx to _xxx,
		     but leave . and .. as they are.  This allows .emacs
		     to be read as _emacs, for example.  */

		  if (! *name ||
		      *name == '.' ||
		      IS_DIRECTORY_SEP (*name))
		    {
		      *str++ = '.';
		      dots--;
		    }
		  else
		    {
		      *str++ = '_';
		      left--;
		      dots = 0;
		    }
		}
	      else if ( !extn )
	        {
		  *str++ = '.';
		  extn = 1;		/* we've got an extension */
		  left = 3;		/* 3 chars in extension */
		}
	      else
	        {
		  /* any embedded dots after the first are converted to _ */
		  *str++ = '_';
		}
	      break;
	    case '~':
	    case '#':			/* don't lose these, they're important */
	      if ( ! left )
		str[-1] = c;		/* replace last character of part */
	      /* FALLTHRU */
	    default:
	      if ( left )
	        {
		  *str++ = tolower (c);	/* map to lower case (looks nicer) */
		  left--;
		  dots = 0;		/* started a path component */
		}
	      break;
	    }
	}
      *str = '\0';
    }
  else
    {
      strcpy (shortname, name);
      unixtodos_filename (shortname);
    }

  if (pPath)
    *pPath = shortname + (path - save_name);

  return shortname;
}

/* Emulate the Unix directory procedures opendir, closedir, 
   and readdir.  We can't use the procedures supplied in sysdep.c,
   so we provide them here.  */

struct direct dir_static;       /* simulated directory contents */
static HANDLE dir_find_handle = INVALID_HANDLE_VALUE;
static int    dir_is_fat;
static char   dir_pathname[MAXPATHLEN+1];
static WIN32_FIND_DATA dir_find_data;

DIR *
opendir (char *filename)
{
  DIR *dirp;

  /* Opening is done by FindFirstFile.  However, a read is inherent to
     this operation, so we defer the open until read time.  */

  if (!(dirp = (DIR *) malloc (sizeof (DIR))))
    return NULL;
  if (dir_find_handle != INVALID_HANDLE_VALUE)
    return NULL;

  dirp->dd_fd = 0;
  dirp->dd_loc = 0;
  dirp->dd_size = 0;

  strncpy (dir_pathname, map_w32_filename (filename, NULL), MAXPATHLEN);
  dir_pathname[MAXPATHLEN] = '\0';
  dir_is_fat = is_fat_volume (filename, NULL);

  return dirp;
}

void
closedir (DIR *dirp)
{
  /* If we have a find-handle open, close it.  */
  if (dir_find_handle != INVALID_HANDLE_VALUE)
    {
      FindClose (dir_find_handle);
      dir_find_handle = INVALID_HANDLE_VALUE;
    }
  xfree ((char *) dirp);
}

struct direct *
readdir (DIR *dirp)
{
  /* If we aren't dir_finding, do a find-first, otherwise do a find-next. */
  if (dir_find_handle == INVALID_HANDLE_VALUE)
    {
      char filename[MAXNAMLEN + 3];
      int ln;

      strcpy (filename, dir_pathname);
      ln = strlen (filename) - 1;
      if (!IS_DIRECTORY_SEP (filename[ln]))
	strcat (filename, "\\");
      strcat (filename, "*");

      dir_find_handle = FindFirstFile (filename, &dir_find_data);

      if (dir_find_handle == INVALID_HANDLE_VALUE)
	return NULL;
    }
  else
    {
      if (!FindNextFile (dir_find_handle, &dir_find_data))
	return NULL;
    }
  
  /* Emacs never uses this value, so don't bother making it match
     value returned by stat().  */
  dir_static.d_ino = 1;
  
  dir_static.d_reclen = sizeof (struct direct) - MAXNAMLEN + 3 +
    dir_static.d_namlen - dir_static.d_namlen % 4;
  
  dir_static.d_namlen = strlen (dir_find_data.cFileName);
  strcpy (dir_static.d_name, dir_find_data.cFileName);
  if (dir_is_fat)
    _strlwr (dir_static.d_name);
  else if (!NILP (Vw32_downcase_file_names))
    {
      register char *p;
      for (p = dir_static.d_name; *p; p++)
	if (*p >= 'a' && *p <= 'z')
	  break;
      if (!*p)
	_strlwr (dir_static.d_name);
    }
  
  return &dir_static;
}


/* Shadow some MSVC runtime functions to map requests for long filenames
   to reasonable short names if necessary.  This was originally added to
   permit running Emacs on NT 3.1 on a FAT partition, which doesn't support 
   long file names.  */

int
sys_access (const char * path, int mode)
{
  return _access (map_w32_filename (path, NULL), mode);
}

int
sys_chdir (const char * path)
{
  return _chdir (map_w32_filename (path, NULL));
}

int
sys_chmod (const char * path, int mode)
{
  return _chmod (map_w32_filename (path, NULL), mode);
}

int
sys_creat (const char * path, int mode)
{
  return _creat (map_w32_filename (path, NULL), mode);
}

FILE *
sys_fopen(const char * path, const char * mode)
{
  int fd;
  int oflag;
  const char * mode_save = mode;

  /* Force all file handles to be non-inheritable.  This is necessary to
     ensure child processes don't unwittingly inherit handles that might
     prevent future file access. */

  if (mode[0] == 'r')
    oflag = O_RDONLY;
  else if (mode[0] == 'w' || mode[0] == 'a')
    oflag = O_WRONLY | O_CREAT | O_TRUNC;
  else
    return NULL;

  /* Only do simplistic option parsing. */
  while (*++mode)
    if (mode[0] == '+')
      {
	oflag &= ~(O_RDONLY | O_WRONLY);
	oflag |= O_RDWR;
      }
    else if (mode[0] == 'b')
      {
	oflag &= ~O_TEXT;
	oflag |= O_BINARY;
      }
    else if (mode[0] == 't')
      {
	oflag &= ~O_BINARY;
	oflag |= O_TEXT;
      }
    else break;

  fd = _open (map_w32_filename (path, NULL), oflag | _O_NOINHERIT, 0644);
  if (fd < 0)
    return NULL;

  return _fdopen (fd, mode_save);
}

/* This only works on NTFS volumes, but is useful to have.  */
int
sys_link (const char * old, const char * new)
{
  HANDLE fileh;
  int   result = -1;
  char oldname[MAX_PATH], newname[MAX_PATH];

  if (old == NULL || new == NULL)
    {
      errno = ENOENT;
      return -1;
    }

  strcpy (oldname, map_w32_filename (old, NULL));
  strcpy (newname, map_w32_filename (new, NULL));

  fileh = CreateFile (oldname, 0, 0, NULL, OPEN_EXISTING,
		      FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (fileh != INVALID_HANDLE_VALUE)
    {
      int wlen;

      /* Confusingly, the "alternate" stream name field does not apply
         when restoring a hard link, and instead contains the actual
         stream data for the link (ie. the name of the link to create).
         The WIN32_STREAM_ID structure before the cStreamName field is
         the stream header, which is then immediately followed by the
         stream data.  */

      struct {
	WIN32_STREAM_ID wid;
	WCHAR wbuffer[MAX_PATH];	/* extra space for link name */
      } data;

      wlen = MultiByteToWideChar (CP_ACP, MB_PRECOMPOSED, newname, -1,
				  data.wid.cStreamName, MAX_PATH);
      if (wlen > 0)
	{
	  LPVOID context = NULL;
	  DWORD wbytes = 0;

	  data.wid.dwStreamId = BACKUP_LINK;
	  data.wid.dwStreamAttributes = 0;
	  data.wid.Size.LowPart = wlen * sizeof(WCHAR);
	  data.wid.Size.HighPart = 0;
	  data.wid.dwStreamNameSize = 0;

	  if (BackupWrite (fileh, (LPBYTE)&data,
			   offsetof (WIN32_STREAM_ID, cStreamName)
			   + data.wid.Size.LowPart,
			   &wbytes, FALSE, FALSE, &context)
	      && BackupWrite (fileh, NULL, 0, &wbytes, TRUE, FALSE, &context))
	    {
	      /* succeeded */
	      result = 0;
	    }
	  else
	    {
	      /* Should try mapping GetLastError to errno; for now just
		 indicate a general error (eg. links not supported).  */
	      errno = EINVAL;  // perhaps EMLINK?
	    }
	}

      CloseHandle (fileh);
    }
  else
    errno = ENOENT;

  return result;
}

int
sys_mkdir (const char * path)
{
  return _mkdir (map_w32_filename (path, NULL));
}

/* Because of long name mapping issues, we need to implement this
   ourselves.  Also, MSVC's _mktemp returns NULL when it can't generate
   a unique name, instead of setting the input template to an empty
   string.

   Standard algorithm seems to be use pid or tid with a letter on the
   front (in place of the 6 X's) and cycle through the letters to find a
   unique name.  We extend that to allow any reasonable character as the
   first of the 6 X's.  */
char *
sys_mktemp (char * template)
{
  char * p;
  int i;
  unsigned uid = GetCurrentThreadId ();
  static char first_char[] = "abcdefghijklmnopqrstuvwyz0123456789!%-_@#";

  if (template == NULL)
    return NULL;
  p = template + strlen (template);
  i = 5;
  /* replace up to the last 5 X's with uid in decimal */
  while (--p >= template && p[0] == 'X' && --i >= 0)
    {
      p[0] = '0' + uid % 10;
      uid /= 10;
    }

  if (i < 0 && p[0] == 'X')
    {
      i = 0;
      do
	{
	  int save_errno = errno;
	  p[0] = first_char[i];
	  if (sys_access (template, 0) < 0)
	    {
	      errno = save_errno;
	      return template;
	    }
	}
      while (++i < sizeof (first_char));
    }

  /* Template is badly formed or else we can't generate a unique name,
     so return empty string */
  template[0] = 0;
  return template;
}

int
sys_open (const char * path, int oflag, int mode)
{
  /* Force all file handles to be non-inheritable. */
  return _open (map_w32_filename (path, NULL), oflag | _O_NOINHERIT, mode);
}

int
sys_rename (const char * oldname, const char * newname)
{
  char temp[MAX_PATH];
  DWORD attr;

  /* MoveFile on Windows 95 doesn't correctly change the short file name
     alias in a number of circumstances (it is not easy to predict when
     just by looking at oldname and newname, unfortunately).  In these
     cases, renaming through a temporary name avoids the problem.

     A second problem on Windows 95 is that renaming through a temp name when
     newname is uppercase fails (the final long name ends up in
     lowercase, although the short alias might be uppercase) UNLESS the
     long temp name is not 8.3.

     So, on Windows 95 we always rename through a temp name, and we make sure
     the temp name has a long extension to ensure correct renaming.  */

  strcpy (temp, map_w32_filename (oldname, NULL));

  if (os_subtype == OS_WIN95)
    {
      char * p;

      if (p = strrchr (temp, '\\'))
	p++;
      else
	p = temp;
      /* Force temp name to require a manufactured 8.3 alias - this
	 seems to make the second rename work properly. */
      strcpy (p, "_rename_temp.XXXXXX");
      sys_mktemp (temp);
      if (rename (map_w32_filename (oldname, NULL), temp) < 0)
	return -1;
    }

  /* Emulate Unix behaviour - newname is deleted if it already exists
     (at least if it is a file; don't do this for directories).
     However, don't do this if we are just changing the case of the file
     name - we will end up deleting the file we are trying to rename!  */
  newname = map_w32_filename (newname, NULL);

  /* TODO: Use GetInformationByHandle (on NT) to ensure newname and temp
     do not refer to the same file, eg. through share aliases.  */
  if (stricmp (newname, temp) != 0
      && (attr = GetFileAttributes (newname)) != -1
      && (attr & FILE_ATTRIBUTE_DIRECTORY) == 0)
    {
      _chmod (newname, 0666);
      _unlink (newname);
    }

  return rename (temp, newname);
}

int
sys_rmdir (const char * path)
{
  return _rmdir (map_w32_filename (path, NULL));
}

int
sys_unlink (const char * path)
{
  return _unlink (map_w32_filename (path, NULL));
}

static FILETIME utc_base_ft;
static long double utc_base;
static int init = 0;

static time_t
convert_time (FILETIME ft)
{
  long double ret;

  if (!init)
    {
      /* Determine the delta between 1-Jan-1601 and 1-Jan-1970. */
      SYSTEMTIME st;

      st.wYear = 1970;
      st.wMonth = 1;
      st.wDay = 1;
      st.wHour = 0;
      st.wMinute = 0;
      st.wSecond = 0;
      st.wMilliseconds = 0;

      SystemTimeToFileTime (&st, &utc_base_ft);
      utc_base = (long double) utc_base_ft.dwHighDateTime
	* 4096 * 1024 * 1024 + utc_base_ft.dwLowDateTime;
      init = 1;
    }

  if (CompareFileTime (&ft, &utc_base_ft) < 0)
    return 0;

  ret = (long double) ft.dwHighDateTime * 4096 * 1024 * 1024 + ft.dwLowDateTime;
  ret -= utc_base;
  return (time_t) (ret * 1e-7);
}

#if 0
/* in case we ever have need of this */
void
convert_from_time_t (time_t time, FILETIME * pft)
{
  long double tmp;

  if (!init)
    {
      /* Determine the delta between 1-Jan-1601 and 1-Jan-1970. */
      SYSTEMTIME st;

      st.wYear = 1970;
      st.wMonth = 1;
      st.wDay = 1;
      st.wHour = 0;
      st.wMinute = 0;
      st.wSecond = 0;
      st.wMilliseconds = 0;

      SystemTimeToFileTime (&st, &utc_base_ft);
      utc_base = (long double) utc_base_ft.dwHighDateTime
	* 4096 * 1024 * 1024 + utc_base_ft.dwLowDateTime;
      init = 1;
    }

  /* time in 100ns units since 1-Jan-1601 */
  tmp = (long double) time * 1e7 + utc_base;
  pft->dwHighDateTime = (DWORD) (tmp / (4096.0 * 1024 * 1024));
  pft->dwLowDateTime = (DWORD) (tmp - pft->dwHighDateTime);
}
#endif

#if 0
/* No reason to keep this; faking inode values either by hashing or even
   using the file index from GetInformationByHandle, is not perfect and
   so by default Emacs doesn't use the inode values on Windows.
   Instead, we now determine file-truename correctly (except for
   possible drive aliasing etc).  */

/*  Modified version of "PJW" algorithm (see the "Dragon" compiler book). */
static unsigned
hashval (const unsigned char * str)
{
  unsigned h = 0;
  while (*str)
    {
      h = (h << 4) + *str++;
      h ^= (h >> 28);
    }
  return h;
}

/* Return the hash value of the canonical pathname, excluding the
   drive/UNC header, to get a hopefully unique inode number. */
static DWORD
generate_inode_val (const char * name)
{
  char fullname[ MAX_PATH ];
  char * p;
  unsigned hash;

  /* Get the truly canonical filename, if it exists.  (Note: this
     doesn't resolve aliasing due to subst commands, or recognise hard
     links.  */
  if (!w32_get_long_filename ((char *)name, fullname, MAX_PATH))
    abort ();

  parse_root (fullname, &p);
  /* Normal W32 filesystems are still case insensitive. */
  _strlwr (p);
  return hashval (p);
}

#endif

/* MSVC stat function can't cope with UNC names and has other bugs, so
   replace it with our own.  This also allows us to calculate consistent
   inode values without hacks in the main Emacs code. */
int
stat (const char * path, struct stat * buf)
{
  char * name;
  WIN32_FIND_DATA wfd;
  HANDLE fh;
  DWORD fake_inode;
  int permission;
  int len;
  int rootdir = FALSE;

  if (path == NULL || buf == NULL)
    {
      errno = EFAULT;
      return -1;
    }

  name = (char *) map_w32_filename (path, &path);
  /* must be valid filename, no wild cards */
  if (strchr (name, '*') || strchr (name, '?'))
    {
      errno = ENOENT;
      return -1;
    }

  /* Remove trailing directory separator, unless name is the root
     directory of a drive or UNC volume in which case ensure there
     is a trailing separator. */
  len = strlen (name);
  rootdir = (path >= name + len - 1
	     && (IS_DIRECTORY_SEP (*path) || *path == 0));
  name = strcpy (alloca (len + 2), name);

  if (rootdir)
    {
      if (!IS_DIRECTORY_SEP (name[len-1]))
	strcat (name, "\\");
      if (GetDriveType (name) < 2)
	{
	  errno = ENOENT;
	  return -1;
	}
      memset (&wfd, 0, sizeof (wfd));
      wfd.dwFileAttributes = FILE_ATTRIBUTE_DIRECTORY;
      wfd.ftCreationTime = utc_base_ft;
      wfd.ftLastAccessTime = utc_base_ft;
      wfd.ftLastWriteTime = utc_base_ft;
      strcpy (wfd.cFileName, name);
    }
  else
    {
      if (IS_DIRECTORY_SEP (name[len-1]))
	name[len - 1] = 0;

      /* (This is hacky, but helps when doing file completions on
	 network drives.)  Optimize by using information available from
	 active readdir if possible.  */
      if (dir_find_handle != INVALID_HANDLE_VALUE
	  && (len = strlen (dir_pathname)),
	  strnicmp (name, dir_pathname, len) == 0
	  && IS_DIRECTORY_SEP (name[len])
	  && stricmp (name + len + 1, dir_static.d_name) == 0)
	{
	  /* This was the last entry returned by readdir.  */
	  wfd = dir_find_data;
	}
      else
	{
	  fh = FindFirstFile (name, &wfd);
	  if (fh == INVALID_HANDLE_VALUE)
	    {
	      errno = ENOENT;
	      return -1;
	    }
	  FindClose (fh);
	}
    }

  if (wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
    {
      buf->st_mode = _S_IFDIR;
      buf->st_nlink = 2;	/* doesn't really matter */
      fake_inode = 0;		/* this doesn't either I think */
    }
  else if (!NILP (Vw32_get_true_file_attributes))
    {
      /* This is more accurate in terms of gettting the correct number
	 of links, but is quite slow (it is noticable when Emacs is
	 making a list of file name completions). */
      BY_HANDLE_FILE_INFORMATION info;

      /* No access rights required to get info.  */
      fh = CreateFile (name, 0, 0, NULL, OPEN_EXISTING, 0, NULL);

      if (GetFileInformationByHandle (fh, &info))
	{
	  switch (GetFileType (fh))
	    {
	    case FILE_TYPE_DISK:
	      buf->st_mode = _S_IFREG;
	      break;
	    case FILE_TYPE_PIPE:
	      buf->st_mode = _S_IFIFO;
	      break;
	    case FILE_TYPE_CHAR:
	    case FILE_TYPE_UNKNOWN:
	    default:
	      buf->st_mode = _S_IFCHR;
	    }
	  buf->st_nlink = info.nNumberOfLinks;
	  /* Might as well use file index to fake inode values, but this
	     is not guaranteed to be unique unless we keep a handle open
	     all the time (even then there are situations where it is
	     not unique).  Reputedly, there are at most 48 bits of info
	     (on NTFS, presumably less on FAT). */
	  fake_inode = info.nFileIndexLow ^ info.nFileIndexHigh;
	  CloseHandle (fh);
	}
      else
	{
	  errno = EACCES;
	  return -1;
	}
    }
  else
    {
      /* Don't bother to make this information more accurate.  */
      buf->st_mode = _S_IFREG;
      buf->st_nlink = 1;
      fake_inode = 0;
    }

#if 0
  /* Not sure if there is any point in this.  */
  if (!NILP (Vw32_generate_fake_inodes))
    fake_inode = generate_inode_val (name);
  else if (fake_inode == 0)
    {
      /* For want of something better, try to make everything unique.  */
      static DWORD gen_num = 0;
      fake_inode = ++gen_num;
    }
#endif

  /* MSVC defines _ino_t to be short; other libc's might not.  */
  if (sizeof (buf->st_ino) == 2)
    buf->st_ino = fake_inode ^ (fake_inode >> 16);
  else
    buf->st_ino = fake_inode;

  /* consider files to belong to current user */
  buf->st_uid = the_passwd.pw_uid;
  buf->st_gid = the_passwd.pw_gid;

  /* volume_info is set indirectly by map_w32_filename */
  buf->st_dev = volume_info.serialnum;
  buf->st_rdev = volume_info.serialnum;


  buf->st_size = wfd.nFileSizeLow;

  /* Convert timestamps to Unix format. */
  buf->st_mtime = convert_time (wfd.ftLastWriteTime);
  buf->st_atime = convert_time (wfd.ftLastAccessTime);
  if (buf->st_atime == 0) buf->st_atime = buf->st_mtime;
  buf->st_ctime = convert_time (wfd.ftCreationTime);
  if (buf->st_ctime == 0) buf->st_ctime = buf->st_mtime;

  /* determine rwx permissions */
  if (wfd.dwFileAttributes & FILE_ATTRIBUTE_READONLY)
    permission = _S_IREAD;
  else
    permission = _S_IREAD | _S_IWRITE;
  
  if (wfd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
    permission |= _S_IEXEC;
  else
    {
      char * p = strrchr (name, '.');
      if (p != NULL
	  && (stricmp (p, ".exe") == 0 ||
	      stricmp (p, ".com") == 0 ||
	      stricmp (p, ".bat") == 0 ||
	      stricmp (p, ".cmd") == 0))
	permission |= _S_IEXEC;
    }

  buf->st_mode |= permission | (permission >> 3) | (permission >> 6);

  return 0;
}

#ifdef HAVE_SOCKETS

/* Wrappers for  winsock functions to map between our file descriptors
   and winsock's handles; also set h_errno for convenience.

   To allow Emacs to run on systems which don't have winsock support
   installed, we dynamically link to winsock on startup if present, and
   otherwise provide the minimum necessary functionality
   (eg. gethostname). */

/* function pointers for relevant socket functions */
int (PASCAL *pfn_WSAStartup) (WORD wVersionRequired, LPWSADATA lpWSAData);
void (PASCAL *pfn_WSASetLastError) (int iError);
int (PASCAL *pfn_WSAGetLastError) (void);
int (PASCAL *pfn_socket) (int af, int type, int protocol);
int (PASCAL *pfn_bind) (SOCKET s, const struct sockaddr *addr, int namelen);
int (PASCAL *pfn_connect) (SOCKET s, const struct sockaddr *addr, int namelen);
int (PASCAL *pfn_ioctlsocket) (SOCKET s, long cmd, u_long *argp);
int (PASCAL *pfn_recv) (SOCKET s, char * buf, int len, int flags);
int (PASCAL *pfn_send) (SOCKET s, const char * buf, int len, int flags);
int (PASCAL *pfn_closesocket) (SOCKET s);
int (PASCAL *pfn_shutdown) (SOCKET s, int how);
int (PASCAL *pfn_WSACleanup) (void);

u_short (PASCAL *pfn_htons) (u_short hostshort);
u_short (PASCAL *pfn_ntohs) (u_short netshort);
unsigned long (PASCAL *pfn_inet_addr) (const char * cp);
int (PASCAL *pfn_gethostname) (char * name, int namelen);
struct hostent * (PASCAL *pfn_gethostbyname) (const char * name);
struct servent * (PASCAL *pfn_getservbyname) (const char * name, const char * proto);
  
/* SetHandleInformation is only needed to make sockets non-inheritable. */
BOOL (WINAPI *pfn_SetHandleInformation) (HANDLE object, DWORD mask, DWORD flags);
#ifndef HANDLE_FLAG_INHERIT
#define HANDLE_FLAG_INHERIT	1
#endif

HANDLE winsock_lib;
static int winsock_inuse;

BOOL
term_winsock (void)
{
  if (winsock_lib != NULL && winsock_inuse == 0)
    {
      /* Not sure what would cause WSAENETDOWN, or even if it can happen
	 after WSAStartup returns successfully, but it seems reasonable
	 to allow unloading winsock anyway in that case. */
      if (pfn_WSACleanup () == 0 ||
	  pfn_WSAGetLastError () == WSAENETDOWN)
	{
	  if (FreeLibrary (winsock_lib))
	  winsock_lib = NULL;
	  return TRUE;
	}
    }
  return FALSE;
}

BOOL
init_winsock (int load_now)
{
  WSADATA  winsockData;

  if (winsock_lib != NULL)
    return TRUE;

  pfn_SetHandleInformation = NULL;
  pfn_SetHandleInformation
    = (void *) GetProcAddress (GetModuleHandle ("kernel32.dll"),
			       "SetHandleInformation");

  winsock_lib = LoadLibrary ("wsock32.dll");

  if (winsock_lib != NULL)
    {
      /* dynamically link to socket functions */

#define LOAD_PROC(fn) \
      if ((pfn_##fn = (void *) GetProcAddress (winsock_lib, #fn)) == NULL) \
        goto fail;

      LOAD_PROC( WSAStartup );
      LOAD_PROC( WSASetLastError );
      LOAD_PROC( WSAGetLastError );
      LOAD_PROC( socket );
      LOAD_PROC( bind );
      LOAD_PROC( connect );
      LOAD_PROC( ioctlsocket );
      LOAD_PROC( recv );
      LOAD_PROC( send );
      LOAD_PROC( closesocket );
      LOAD_PROC( shutdown );
      LOAD_PROC( htons );
      LOAD_PROC( ntohs );
      LOAD_PROC( inet_addr );
      LOAD_PROC( gethostname );
      LOAD_PROC( gethostbyname );
      LOAD_PROC( getservbyname );
      LOAD_PROC( WSACleanup );

#undef LOAD_PROC

      /* specify version 1.1 of winsock */
      if (pfn_WSAStartup (0x101, &winsockData) == 0)
        {
	  if (winsockData.wVersion != 0x101)
	    goto fail;

	  if (!load_now)
	    {
	      /* Report that winsock exists and is usable, but leave
		 socket functions disabled.  I am assuming that calling
		 WSAStartup does not require any network interaction,
		 and in particular does not cause or require a dial-up
		 connection to be established. */

	      pfn_WSACleanup ();
	      FreeLibrary (winsock_lib);
	      winsock_lib = NULL;
	    }
	  winsock_inuse = 0;
	  return TRUE;
	}

    fail:
      FreeLibrary (winsock_lib);
      winsock_lib = NULL;
    }

  return FALSE;
}


int h_errno = 0;

/* function to set h_errno for compatability; map winsock error codes to
   normal system codes where they overlap (non-overlapping definitions
   are already in <sys/socket.h> */
static void set_errno ()
{
  if (winsock_lib == NULL)
    h_errno = EINVAL;
  else
    h_errno = pfn_WSAGetLastError ();

  switch (h_errno)
    {
    case WSAEACCES:		h_errno = EACCES; break;
    case WSAEBADF: 		h_errno = EBADF; break;
    case WSAEFAULT:		h_errno = EFAULT; break;
    case WSAEINTR: 		h_errno = EINTR; break;
    case WSAEINVAL:		h_errno = EINVAL; break;
    case WSAEMFILE:		h_errno = EMFILE; break;
    case WSAENAMETOOLONG: 	h_errno = ENAMETOOLONG; break;
    case WSAENOTEMPTY:		h_errno = ENOTEMPTY; break;
    }
  errno = h_errno;
}

static void check_errno ()
{
  if (h_errno == 0 && winsock_lib != NULL)
    pfn_WSASetLastError (0);
}

/* [andrewi 3-May-96] I've had conflicting results using both methods,
   but I believe the method of keeping the socket handle separate (and
   insuring it is not inheritable) is the correct one. */

//#define SOCK_REPLACE_HANDLE

#ifdef SOCK_REPLACE_HANDLE
#define SOCK_HANDLE(fd) ((SOCKET) _get_osfhandle (fd))
#else
#define SOCK_HANDLE(fd) ((SOCKET) fd_info[fd].hnd)
#endif

int
sys_socket(int af, int type, int protocol)
{
  int fd;
  long s;
  child_process * cp;

  if (winsock_lib == NULL)
    {
      h_errno = ENETDOWN;
      return INVALID_SOCKET;
    }

  check_errno ();

  /* call the real socket function */
  s = (long) pfn_socket (af, type, protocol);
  
  if (s != INVALID_SOCKET)
    {
      /* Although under NT 3.5 _open_osfhandle will accept a socket
	 handle, if opened with SO_OPENTYPE == SO_SYNCHRONOUS_NONALERT,
	 that does not work under NT 3.1.  However, we can get the same
	 effect by using a backdoor function to replace an existing
	 descriptor handle with the one we want. */

      /* allocate a file descriptor (with appropriate flags) */
      fd = _open ("NUL:", _O_RDWR);
      if (fd >= 0)
        {
#ifdef SOCK_REPLACE_HANDLE
	  /* now replace handle to NUL with our socket handle */
	  CloseHandle ((HANDLE) _get_osfhandle (fd));
	  _free_osfhnd (fd);
	  _set_osfhnd (fd, s);
	  /* setmode (fd, _O_BINARY); */
#else
	  /* Make a non-inheritable copy of the socket handle. */
	  {
	    HANDLE parent;
	    HANDLE new_s = INVALID_HANDLE_VALUE;

	    parent = GetCurrentProcess ();

	    /* Apparently there is a bug in NT 3.51 with some service
	       packs, which prevents using DuplicateHandle to make a
	       socket handle non-inheritable (causes WSACleanup to
	       hang).  The work-around is to use SetHandleInformation
	       instead if it is available and implemented. */
	    if (!pfn_SetHandleInformation
		|| !pfn_SetHandleInformation ((HANDLE) s,
					      HANDLE_FLAG_INHERIT,
					      HANDLE_FLAG_INHERIT))
	      {
		DuplicateHandle (parent,
				 (HANDLE) s,
				 parent,
				 &new_s,
				 0,
				 FALSE,
				 DUPLICATE_SAME_ACCESS);
		pfn_closesocket (s);
		s = (SOCKET) new_s;
	      }
	    fd_info[fd].hnd = (HANDLE) s;
	  }
#endif

	  /* set our own internal flags */
	  fd_info[fd].flags = FILE_SOCKET | FILE_BINARY | FILE_READ | FILE_WRITE;

	  cp = new_child ();
	  if (cp)
	    {
	      cp->fd = fd;
	      cp->status = STATUS_READ_ACKNOWLEDGED;

	      /* attach child_process to fd_info */
	      if (fd_info[ fd ].cp != NULL)
		{
		  DebPrint (("sys_socket: fd_info[%d] apparently in use!\n", fd));
		  abort ();
		}

	      fd_info[ fd ].cp = cp;

	      /* success! */
	      winsock_inuse++;	/* count open sockets */
	      return fd;
	    }

	  /* clean up */
	  _close (fd);
	}
      pfn_closesocket (s);
      h_errno = EMFILE;
    }
  set_errno ();

  return -1;
}


int
sys_bind (int s, const struct sockaddr * addr, int namelen)
{
  if (winsock_lib == NULL)
    {
      h_errno = ENOTSOCK;
      return SOCKET_ERROR;
    }

  check_errno ();
  if (fd_info[s].flags & FILE_SOCKET)
    {
      int rc = pfn_bind (SOCK_HANDLE (s), addr, namelen);
      if (rc == SOCKET_ERROR)
	set_errno ();
      return rc;
    }
  h_errno = ENOTSOCK;
  return SOCKET_ERROR;
}


int
sys_connect (int s, const struct sockaddr * name, int namelen)
{
  if (winsock_lib == NULL)
    {
      h_errno = ENOTSOCK;
      return SOCKET_ERROR;
    }

  check_errno ();
  if (fd_info[s].flags & FILE_SOCKET)
    {
      int rc = pfn_connect (SOCK_HANDLE (s), name, namelen);
      if (rc == SOCKET_ERROR)
	set_errno ();
      return rc;
    }
  h_errno = ENOTSOCK;
  return SOCKET_ERROR;
}

u_short
sys_htons (u_short hostshort)
{
  return (winsock_lib != NULL) ?
    pfn_htons (hostshort) : hostshort;
}

u_short
sys_ntohs (u_short netshort)
{
  return (winsock_lib != NULL) ?
    pfn_ntohs (netshort) : netshort;
}

unsigned long
sys_inet_addr (const char * cp)
{
  return (winsock_lib != NULL) ?
    pfn_inet_addr (cp) : INADDR_NONE;
}

int
sys_gethostname (char * name, int namelen)
{
  if (winsock_lib != NULL)
    return pfn_gethostname (name, namelen);

  if (namelen > MAX_COMPUTERNAME_LENGTH)
    return !GetComputerName (name, &namelen);

  h_errno = EFAULT;
  return SOCKET_ERROR;
}

struct hostent *
sys_gethostbyname(const char * name)
{
  struct hostent * host;

  if (winsock_lib == NULL)
    {
      h_errno = ENETDOWN;
      return NULL;
    }

  check_errno ();
  host = pfn_gethostbyname (name);
  if (!host)
    set_errno ();
  return host;
}

struct servent *
sys_getservbyname(const char * name, const char * proto)
{
  struct servent * serv;

  if (winsock_lib == NULL)
    {
      h_errno = ENETDOWN;
      return NULL;
    }

  check_errno ();
  serv = pfn_getservbyname (name, proto);
  if (!serv)
    set_errno ();
  return serv;
}

int
sys_shutdown (int s, int how)
{
  int rc;

  if (winsock_lib == NULL)
    {
      h_errno = ENETDOWN;
      return SOCKET_ERROR;
    }

  check_errno ();
  if (fd_info[s].flags & FILE_SOCKET)
    {
      int rc = pfn_shutdown (SOCK_HANDLE (s), how);
      if (rc == SOCKET_ERROR)
	set_errno ();
      return rc;
    }
  h_errno = ENOTSOCK;
  return SOCKET_ERROR;
}

#endif /* HAVE_SOCKETS */


/* Shadow main io functions: we need to handle pipes and sockets more
   intelligently, and implement non-blocking mode as well. */

int
sys_close (int fd)
{
  int rc;

  if (fd < 0 || fd >= MAXDESC)
    {
      errno = EBADF;
      return -1;
    }

  if (fd_info[fd].cp)
    {
      child_process * cp = fd_info[fd].cp;

      fd_info[fd].cp = NULL;

      if (CHILD_ACTIVE (cp))
        {
	  /* if last descriptor to active child_process then cleanup */
	  int i;
	  for (i = 0; i < MAXDESC; i++)
	    {
	      if (i == fd)
		continue;
	      if (fd_info[i].cp == cp)
		break;
	    }
	  if (i == MAXDESC)
	    {
#ifdef HAVE_SOCKETS
	      if (fd_info[fd].flags & FILE_SOCKET)
		{
#ifndef SOCK_REPLACE_HANDLE
		  if (winsock_lib == NULL) abort ();

		  pfn_shutdown (SOCK_HANDLE (fd), 2);
		  rc = pfn_closesocket (SOCK_HANDLE (fd));
#endif
		  winsock_inuse--; /* count open sockets */
		}
#endif
	      delete_child (cp);
	    }
	}
    }

  /* Note that sockets do not need special treatment here (at least on
     NT and Windows 95 using the standard tcp/ip stacks) - it appears that
     closesocket is equivalent to CloseHandle, which is to be expected
     because socket handles are fully fledged kernel handles. */
  rc = _close (fd);

  if (rc == 0)
    fd_info[fd].flags = 0;

  return rc;
}

int
sys_dup (int fd)
{
  int new_fd;

  new_fd = _dup (fd);
  if (new_fd >= 0)
    {
      /* duplicate our internal info as well */
      fd_info[new_fd] = fd_info[fd];
    }
  return new_fd;
}


int
sys_dup2 (int src, int dst)
{
  int rc;

  if (dst < 0 || dst >= MAXDESC)
    {
      errno = EBADF;
      return -1;
    }

  /* make sure we close the destination first if it's a pipe or socket */
  if (src != dst && fd_info[dst].flags != 0)
    sys_close (dst);
  
  rc = _dup2 (src, dst);
  if (rc == 0)
    {
      /* duplicate our internal info as well */
      fd_info[dst] = fd_info[src];
    }
  return rc;
}

/* From callproc.c  */
extern Lisp_Object Vbinary_process_input;
extern Lisp_Object Vbinary_process_output;

/* Unix pipe() has only one arg */
int
sys_pipe (int * phandles)
{
  int rc;
  unsigned flags;
  child_process * cp;

  /* make pipe handles non-inheritable; when we spawn a child, we
     replace the relevant handle with an inheritable one.  Also put
     pipes into binary mode; we will do text mode translation ourselves
     if required.  */
  rc = _pipe (phandles, 0, _O_NOINHERIT | _O_BINARY);

  if (rc == 0)
    {
      flags = FILE_PIPE | FILE_READ;
      if (!NILP (Vbinary_process_output))
	flags |= FILE_BINARY;
      fd_info[phandles[0]].flags = flags;

      flags = FILE_PIPE | FILE_WRITE;
      if (!NILP (Vbinary_process_input))
	flags |= FILE_BINARY;
      fd_info[phandles[1]].flags = flags;
    }

  return rc;
}

/* From ntproc.c */
extern Lisp_Object Vw32_pipe_read_delay;

/* Function to do blocking read of one byte, needed to implement
   select.  It is only allowed on sockets and pipes. */
int
_sys_read_ahead (int fd)
{
  child_process * cp;
  int rc;

  if (fd < 0 || fd >= MAXDESC)
    return STATUS_READ_ERROR;

  cp = fd_info[fd].cp;

  if (cp == NULL || cp->fd != fd || cp->status != STATUS_READ_READY)
    return STATUS_READ_ERROR;

  if ((fd_info[fd].flags & (FILE_PIPE | FILE_SOCKET)) == 0
      || (fd_info[fd].flags & FILE_READ) == 0)
    {
      DebPrint (("_sys_read_ahead: internal error: fd %d is not a pipe or socket!\n", fd));
      abort ();
    }
  
  cp->status = STATUS_READ_IN_PROGRESS;
  
  if (fd_info[fd].flags & FILE_PIPE)
    {
      rc = _read (fd, &cp->chr, sizeof (char));

      /* Give subprocess time to buffer some more output for us before
	 reporting that input is available; we need this because Windows 95
	 connects DOS programs to pipes by making the pipe appear to be
	 the normal console stdout - as a result most DOS programs will
	 write to stdout without buffering, ie.  one character at a
	 time.  Even some W32 programs do this - "dir" in a command
	 shell on NT is very slow if we don't do this. */
      if (rc > 0)
	{
	  int wait = XINT (Vw32_pipe_read_delay);

	  if (wait > 0)
	    Sleep (wait);
	  else if (wait < 0)
	    while (++wait <= 0)
	      /* Yield remainder of our time slice, effectively giving a
		 temporary priority boost to the child process. */
	      Sleep (0);
	}
    }
#ifdef HAVE_SOCKETS
  else if (fd_info[fd].flags & FILE_SOCKET)
    rc = pfn_recv (SOCK_HANDLE (fd), &cp->chr, sizeof (char), 0);
#endif
  
  if (rc == sizeof (char))
    cp->status = STATUS_READ_SUCCEEDED;
  else
    cp->status = STATUS_READ_FAILED;

  return cp->status;
}

int
sys_read (int fd, char * buffer, unsigned int count)
{
  int nchars;
  int to_read;
  DWORD waiting;
  char * orig_buffer = buffer;

  if (fd < 0 || fd >= MAXDESC)
    {
      errno = EBADF;
      return -1;
    }

  if (fd_info[fd].flags & (FILE_PIPE | FILE_SOCKET))
    {
      child_process *cp = fd_info[fd].cp;

      if ((fd_info[fd].flags & FILE_READ) == 0)
        {
	  errno = EBADF;
	  return -1;
	}

      nchars = 0;

      /* re-read CR carried over from last read */
      if (fd_info[fd].flags & FILE_LAST_CR)
	{
	  if (fd_info[fd].flags & FILE_BINARY) abort ();
	  *buffer++ = 0x0d;
	  count--;
	  nchars++;
	}

      /* presence of a child_process structure means we are operating in
	 non-blocking mode - otherwise we just call _read directly.
	 Note that the child_process structure might be missing because
	 reap_subprocess has been called; in this case the pipe is
	 already broken, so calling _read on it is okay. */
      if (cp)
        {
	  int current_status = cp->status;

	  switch (current_status)
	    {
	    case STATUS_READ_FAILED:
	    case STATUS_READ_ERROR:
	      /* report normal EOF */
	      return 0;

	    case STATUS_READ_READY:
	    case STATUS_READ_IN_PROGRESS:
	      DebPrint (("sys_read called when read is in progress\n"));
	      errno = EWOULDBLOCK;
	      return -1;

	    case STATUS_READ_SUCCEEDED:
	      /* consume read-ahead char */
	      *buffer++ = cp->chr;
	      count--;
	      nchars++;
	      cp->status = STATUS_READ_ACKNOWLEDGED;
	      ResetEvent (cp->char_avail);

	    case STATUS_READ_ACKNOWLEDGED:
	      break;

	    default:
	      DebPrint (("sys_read: bad status %d\n", current_status));
	      errno = EBADF;
	      return -1;
	    }

	  if (fd_info[fd].flags & FILE_PIPE)
	    {
	      PeekNamedPipe ((HANDLE) _get_osfhandle (fd), NULL, 0, NULL, &waiting, NULL);
	      to_read = min (waiting, (DWORD) count);
      
	      nchars += _read (fd, buffer, to_read);
	    }
#ifdef HAVE_SOCKETS
	  else /* FILE_SOCKET */
	    {
	      if (winsock_lib == NULL) abort ();

	      /* do the equivalent of a non-blocking read */
	      pfn_ioctlsocket (SOCK_HANDLE (fd), FIONREAD, &waiting);
	      if (waiting == 0 && nchars == 0)
	        {
		  h_errno = errno = EWOULDBLOCK;
		  return -1;
		}

	      if (waiting)
	        {
		  /* always use binary mode for sockets */
		  int res = pfn_recv (SOCK_HANDLE (fd), buffer, count, 0);
		  if (res == SOCKET_ERROR)
		    {
		      DebPrint(("sys_read.recv failed with error %d on socket %ld\n",
				pfn_WSAGetLastError (), SOCK_HANDLE (fd)));
		      set_errno ();
		      return -1;
		    }
		  nchars += res;
		}
	    }
#endif
	}
      else
	nchars += _read (fd, buffer, count);

      /* Perform text mode translation if required.  */
      if ((fd_info[fd].flags & FILE_BINARY) == 0)
	{
	  nchars = crlf_to_lf (nchars, orig_buffer);
	  /* If buffer contains only CR, return that.  To be absolutely
	     sure we should attempt to read the next char, but in
	     practice a CR to be followed by LF would not appear by
	     itself in the buffer.  */
	  if (nchars > 1 && orig_buffer[nchars - 1] == 0x0d)
	    {
	      fd_info[fd].flags |= FILE_LAST_CR;
	      nchars--;
	    }
	  else
	    fd_info[fd].flags &= ~FILE_LAST_CR;
	}
    }
  else
    nchars = _read (fd, buffer, count);

  return nchars;
}

/* For now, don't bother with a non-blocking mode */
int
sys_write (int fd, const void * buffer, unsigned int count)
{
  int nchars;

  if (fd < 0 || fd >= MAXDESC)
    {
      errno = EBADF;
      return -1;
    }

  if (fd_info[fd].flags & (FILE_PIPE | FILE_SOCKET))
    {
      if ((fd_info[fd].flags & FILE_WRITE) == 0)
	{
	  errno = EBADF;
	  return -1;
	}

      /* Perform text mode translation if required.  */
      if ((fd_info[fd].flags & FILE_BINARY) == 0)
	{
	  char * tmpbuf = alloca (count * 2);
	  unsigned char * src = (void *)buffer;
	  unsigned char * dst = tmpbuf;
	  int nbytes = count;

	  while (1)
	    {
	      unsigned char *next;
	      /* copy next line or remaining bytes */
	      next = _memccpy (dst, src, '\n', nbytes);
	      if (next)
		{
		  /* copied one line ending with '\n' */
		  int copied = next - dst;
		  nbytes -= copied;
		  src += copied;
		  /* insert '\r' before '\n' */
		  next[-1] = '\r';
		  next[0] = '\n';
		  dst = next + 1;
		  count++;
		}	    
	      else
		/* copied remaining partial line -> now finished */
		break;
	    }
	  buffer = tmpbuf;
	}
    }

#ifdef HAVE_SOCKETS
  if (fd_info[fd].flags & FILE_SOCKET)
    {
      if (winsock_lib == NULL) abort ();
      nchars =  pfn_send (SOCK_HANDLE (fd), buffer, count, 0);
      if (nchars == SOCKET_ERROR)
        {
	  DebPrint(("sys_read.send failed with error %d on socket %ld\n",
		    pfn_WSAGetLastError (), SOCK_HANDLE (fd)));
	  set_errno ();
	}
    }
  else
#endif
    nchars = _write (fd, buffer, count);

  return nchars;
}


void
term_ntproc ()
{
#ifdef HAVE_SOCKETS
  /* shutdown the socket interface if necessary */
  term_winsock ();
#endif
}

void
init_ntproc ()
{
#ifdef HAVE_SOCKETS
  /* Initialise the socket interface now if available and requested by
     the user by defining PRELOAD_WINSOCK; otherwise loading will be
     delayed until open-network-stream is called (w32-has-winsock can
     also be used to dynamically load or reload winsock).

     Conveniently, init_environment is called before us, so
     PRELOAD_WINSOCK can be set in the registry. */

  /* Always initialize this correctly. */
  winsock_lib = NULL;

  if (getenv ("PRELOAD_WINSOCK") != NULL)
    init_winsock (TRUE);
#endif

  /* Initial preparation for subprocess support: replace our standard
     handles with non-inheritable versions. */
  {
    HANDLE parent;
    HANDLE stdin_save =  INVALID_HANDLE_VALUE;
    HANDLE stdout_save = INVALID_HANDLE_VALUE;
    HANDLE stderr_save = INVALID_HANDLE_VALUE;

    parent = GetCurrentProcess ();

    /* ignore errors when duplicating and closing; typically the
       handles will be invalid when running as a gui program. */
    DuplicateHandle (parent, 
		     GetStdHandle (STD_INPUT_HANDLE), 
		     parent,
		     &stdin_save, 
		     0, 
		     FALSE, 
		     DUPLICATE_SAME_ACCESS);
    
    DuplicateHandle (parent,
		     GetStdHandle (STD_OUTPUT_HANDLE),
		     parent,
		     &stdout_save,
		     0,
		     FALSE,
		     DUPLICATE_SAME_ACCESS);
    
    DuplicateHandle (parent,
		     GetStdHandle (STD_ERROR_HANDLE),
		     parent,
		     &stderr_save,
		     0,
		     FALSE,
		     DUPLICATE_SAME_ACCESS);
    
    fclose (stdin);
    fclose (stdout);
    fclose (stderr);

    if (stdin_save != INVALID_HANDLE_VALUE)
      _open_osfhandle ((long) stdin_save, O_TEXT);
    else
      _open ("nul", O_TEXT | O_NOINHERIT | O_RDONLY);
    _fdopen (0, "r");

    if (stdout_save != INVALID_HANDLE_VALUE)
      _open_osfhandle ((long) stdout_save, O_TEXT);
    else
      _open ("nul", O_TEXT | O_NOINHERIT | O_WRONLY);
    _fdopen (1, "w");

    if (stderr_save != INVALID_HANDLE_VALUE)
      _open_osfhandle ((long) stderr_save, O_TEXT);
    else
      _open ("nul", O_TEXT | O_NOINHERIT | O_WRONLY);
    _fdopen (2, "w");
  }

  /* unfortunately, atexit depends on implementation of malloc */
  /* atexit (term_ntproc); */
  signal (SIGABRT, term_ntproc);

  /* determine which drives are fixed, for GetCachedVolumeInformation */
  {
    /* GetDriveType must have trailing backslash. */
    char drive[] = "A:\\";

    /* Loop over all possible drive letters */
    while (*drive <= 'Z')
    {
      /* Record if this drive letter refers to a fixed drive. */
      fixed_drives[DRIVE_INDEX (*drive)] = 
	(GetDriveType (drive) == DRIVE_FIXED);

      (*drive)++;
    }
  }
}

/* end of nt.c */
