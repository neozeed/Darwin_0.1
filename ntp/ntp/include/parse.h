/*
 * $Header: /CVSRoot/CoreOS/Services/ntp/ntp/include/parse.h,v 1.1.1.2 1998/10/30 22:18:03 wsanchez Exp $
 *
 * $Id: parse.h,v 1.1.1.2 1998/10/30 22:18:03 wsanchez Exp $
 *
 * Copyright (C) 1989-1998 by Frank Kardel
 * Friedrich-Alexander Universität Erlangen-Nürnberg, Germany
 *                                    
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __PARSE_H__
#define __PARSE_H__
#if	!(defined(lint) || defined(__GNUC__))
  static char parsehrcsid[]="$Id: parse.h,v 1.1.1.2 1998/10/30 22:18:03 wsanchez Exp $";
#endif

#include "ntp_types.h"

#include "parse_conf.h"

/*
 * we use the following datastructures in two modes
 * either in the NTP itself where we use NTP time stamps at some places
 * or in the kernel, where only struct timeval will be used.
 */
#undef PARSEKERNEL
#if defined(KERNEL) || defined(_KERNEL)
#ifndef PARSESTREAM
#define PARSESTREAM
#endif
#endif
#if defined(PARSESTREAM) && defined(HAVE_SYS_STREAM_H)
#define PARSEKERNEL
#endif
#ifdef PARSEKERNEL
#ifndef _KERNEL
extern caddr_t kmem_alloc P((unsigned int));
extern caddr_t kmem_free P((caddr_t, unsigned int));
extern unsigned int splx P((unsigned int));
extern unsigned int splhigh P((void));
extern unsigned int splclock P((void));
#define MALLOC(_X_) (char *)kmem_alloc(_X_)
#define FREE(_X_, _Y_) kmem_free((caddr_t)_X_, _Y_)
#else
#include <sys/kmem.h>
#define MALLOC(_X_) (char *)kmem_alloc(_X_, KM_SLEEP)
#define FREE(_X_, _Y_) kmem_free((caddr_t)_X_, _Y_)
#endif
#else
#define MALLOC(_X_) malloc(_X_)
#define FREE(_X_, _Y_) free(_X_)
#endif

#if defined(PARSESTREAM) && defined(HAVE_SYS_STREAM_H)
#include <sys/stream.h>
#include <sys/stropts.h>
#else	/* STREAM */
#include <stdio.h>
#include "ntp_syslog.h"
#ifdef	DEBUG
extern int debug;
#define DD_PARSE 5
#define DD_RAWDCF 4
#define parseprintf(LEVEL, ARGS) if (debug > LEVEL) printf ARGS
#else	/* DEBUG */
#define parseprintf(LEVEL, ARGS)
#endif	/* DEBUG */
#endif	/* PARSESTREAM */

#if defined(timercmp) && defined(__GNUC__)
#undef timercmp
#define	timercmp(tvp, uvp, cmp)	\
	((tvp)->tv_sec cmp (uvp)->tv_sec || \
	 ((tvp)->tv_sec == (uvp)->tv_sec && (tvp)->tv_usec cmp (uvp)->tv_usec))
#endif

#ifndef TIMES10
#define TIMES10(_X_)	(((_X_) << 3) + ((_X_) << 1))
#endif

/*
 * state flags
 */
#define PARSEB_POWERUP            0x00000001 /* no synchronisation */
#define PARSEB_NOSYNC             0x00000002 /* timecode currently not confirmed */

/*
 * time zone information
 */
#define PARSEB_ANNOUNCE           0x00000010 /* switch time zone warning (DST switch) */
#define PARSEB_DST                0x00000020 /* DST in effect */
#define PARSEB_UTC		  0x00000040 /* UTC time */

/*
 * leap information
 */
#define PARSEB_LEAPDEL		  0x00000100 /* LEAP deletion warning */
#define PARSEB_LEAPADD		  0x00000200 /* LEAP addition warning */
#define PARSEB_LEAPS		  0x00000300 /* LEAP warnings */
#define PARSEB_LEAPSECOND	  0x00000400 /* actual leap second */
/*
 * optional status information
 */
#define PARSEB_ALTERNATE	  0x00001000 /* alternate antenna used */
#define PARSEB_POSITION		  0x00002000 /* position available */
#define PARSEB_MESSAGE            0x00004000 /* addtitional message data */
/*
 * feature information
 */
#define PARSEB_S_LEAP		  0x00010000 /* supports LEAP */
#define PARSEB_S_ANTENNA	  0x00020000 /* supports antenna information */
#define PARSEB_S_PPS     	  0x00040000 /* supports PPS time stamping */
#define PARSEB_S_POSITION	  0x00080000 /* supports position information (GPS) */

/*
 * time stamp availability
 */
#define PARSEB_TIMECODE		  0x10000000 /* valid time code sample */
#define PARSEB_PPS		  0x20000000 /* valid PPS sample */

#define PARSE_TCINFO		(PARSEB_ANNOUNCE|PARSEB_POWERUP|PARSEB_NOSYNC|PARSEB_DST|\
				 PARSEB_UTC|PARSEB_LEAPS|PARSEB_ALTERNATE|PARSEB_S_LEAP|\
				 PARSEB_S_LOCATION|PARSEB_TIMECODE|PARSEB_MESSAGE)

#define PARSE_POWERUP(x)        ((x) & PARSEB_POWERUP)
#define PARSE_NOSYNC(x)         (((x) & (PARSEB_POWERUP|PARSEB_NOSYNC)) == PARSEB_NOSYNC)
#define PARSE_SYNC(x)           (((x) & (PARSEB_POWERUP|PARSEB_NOSYNC)) == 0)
#define PARSE_ANNOUNCE(x)       ((x) & PARSEB_ANNOUNCE)
#define PARSE_DST(x)            ((x) & PARSEB_DST)
#define PARSE_UTC(x)		((x) & PARSEB_UTC)
#define PARSE_LEAPADD(x)	(PARSE_SYNC(x) && (((x) & PARSEB_LEAPS) == PARSEB_LEAPADD))
#define PARSE_LEAPDEL(x)	(PARSE_SYNC(x) && (((x) & PARSEB_LEAPS) == PARSEB_LEAPDEL))
#define PARSE_ALTERNATE(x)	((x) & PARSEB_ALTERNATE)
#define PARSE_LEAPSECOND(x)	(PARSE_SYNC(x) && ((x) & PARSEB_LEAP_SECOND))

#define PARSE_S_LEAP(x)		((x) & PARSEB_S_LEAP)
#define PARSE_S_ANTENNA(x)	((x) & PARSEB_S_ANTENNA)
#define PARSE_S_PPS(x)		((x) & PARSEB_S_PPS)
#define PARSE_S_POSITION(x)	((x) & PARSEB_S_POSITION)

#define PARSE_TIMECODE(x)	((x) & PARSEB_TIMECODE)
#define PARSE_PPS(x)		((x) & PARSEB_PPS)
#define PARSE_POSITION(x)	((x) & PARSEB_POSITION)
#define PARSE_MESSAGE(x)	((x) & PARSEB_MESSAGE)

/*
 * operation flags - lower nibble contains fudge flags
 */
#define PARSE_STATISTICS    0x08  /* enable statistics */
#define PARSE_LEAP_DELETE   0x04  /* delete leap */
#define PARSE_FIXED_FMT     0x10  /* fixed format */
#define PARSE_PPSCLOCK      0x20  /* try to get PPS time stamp via ppsclock ioctl */

/*
 * size of buffers
 */
#define PARSE_TCMAX	    400	  /* maximum addition data size */

typedef union timestamp
{
  struct timeval tv;		/* timeval - kernel view */
  l_fp           fp;		/* fixed point - ntp view */
} timestamp_t;

/*
 * standard time stamp structure
 */
struct parsetime
{
  u_long  parse_status;	/* data status - CVT_OK, CVT_NONE, CVT_FAIL ... */
  timestamp_t	 parse_time;	/* PARSE timestamp */
  timestamp_t	 parse_stime;	/* telegram sample timestamp */
  timestamp_t	 parse_ptime;	/* PPS time stamp */
  long           parse_usecerror;	/* sampled usec error */
  u_long	 parse_state;	/* current receiver state */
  unsigned short parse_format;	/* format code */
  unsigned short parse_msglen;	/* length of message */
  unsigned char  parse_msg[PARSE_TCMAX]; /* original messages */
};

typedef struct parsetime parsetime_t;

/*---------- STREAMS interface ----------*/

#ifdef HAVE_SYS_STREAM_H
/*
 * ioctls
 */
#define PARSEIOC_ENABLE		(('D'<<8) + 'E')
#define PARSEIOC_DISABLE	(('D'<<8) + 'D')
#define PARSEIOC_SETFMT         (('D'<<8) + 'f')
#define PARSEIOC_GETFMT	        (('D'<<8) + 'F')
#define PARSEIOC_SETCS	        (('D'<<8) + 'C')
#define PARSEIOC_TIMECODE	(('D'<<8) + 'T')

#endif

/*------ IO handling flags (sorry) ------*/

#define PARSE_IO_CSIZE	0x00000003
#define PARSE_IO_CS5	0x00000000
#define PARSE_IO_CS6	0x00000001
#define PARSE_IO_CS7	0x00000002 
#define PARSE_IO_CS8	0x00000003 

/*
 * ioctl structure
 */
union parsectl 
{
  struct parsegettc
    {
      u_long         parse_state;	/* last state */
      u_long         parse_badformat; /* number of bad packets since last query */
      unsigned short parse_format;/* last decoded format */
      unsigned short parse_count;	/* count of valid time code bytes */
      char           parse_buffer[PARSE_TCMAX+1]; /* timecode buffer */
    } parsegettc;

  struct parseformat
    {
      unsigned short parse_format;/* number of examined format */
      unsigned short parse_count;	/* count of valid string bytes */
      char           parse_buffer[PARSE_TCMAX+1]; /* format code string */
    } parseformat;

  struct parsesetcs
    {
      u_long         parse_cs;	/* character size (needed for stripping) */
    } parsesetcs;
};
  
typedef union parsectl parsectl_t;

/*------ for conversion routines --------*/

struct parse			/* parse module local data */
{
  int            parse_flags;	/* operation and current status flags */
  
  int		 parse_ioflags;	   /* io handling flags (5-8 Bit control currently) */

  /*
   * private data - fixed format only
   */
  unsigned short parse_plen;	/* length of private data */
  void          *parse_pdata;	/* private data pointer */

  /*
   * time code input buffer (from RS232 or PPS)
   */
  unsigned short parse_index;	/* current buffer index */
  char          *parse_data;    /* data buffer */
  unsigned short parse_dsize;	/* size of data buffer */
  unsigned short parse_lformat;	/* last format used */
  u_long         parse_lstate;	/* last state code */
  char          *parse_ldata;	/* last data buffer */
  unsigned short parse_ldsize;	/* last data buffer length */
  u_long         parse_badformat;	/* number of unparsable pakets */
  
  timestamp_t    parse_lastchar; /* last time a character was received */
  parsetime_t    parse_dtime;	/* external data prototype */
};

typedef struct parse parse_t;

struct clocktime		/* clock time broken up from time code */
{
  long day;
  long month;
  long year;
  long hour;
  long minute;
  long second;
  long usecond;
  long utcoffset;	/* in seconds */
  time_t utctime;	/* the actual time - alternative to date/time */
  u_long flags;		/* current clock status */
};

typedef struct clocktime clocktime_t;

/*
 * parser related return/error codes
 */
#define CVT_MASK	 (unsigned)0x0000000F /* conversion exit code */
#define   CVT_NONE	 (unsigned)0x00000001 /* format not applicable */
#define   CVT_FAIL	 (unsigned)0x00000002 /* conversion failed - error code returned */
#define   CVT_OK	 (unsigned)0x00000004 /* conversion succeeded */
#define   CVT_SKIP	 (unsigned)0x00000008 /* conversion succeeded */
#define CVT_ADDITIONAL   (unsigned)0x00000010 /* additional data is available */
#define CVT_BADFMT	 (unsigned)0x00000100 /* general format error - (unparsable) */
#define CVT_BADDATE      (unsigned)0x00000200 /* date field incorrect */
#define CVT_BADTIME	 (unsigned)0x00000400 /* time field incorrect */

/*
 * return codes used by special input parsers
 */
#define PARSE_INP_SKIP  0x00	/* discard data - may have been consumed */
#define PARSE_INP_TIME  0x01	/* time code assembled */
#define PARSE_INP_PARSE 0x02	/* parse data using normal algorithm */
#define PARSE_INP_DATA  0x04	/* additional data to pass up */
#define PARSE_INP_SYNTH 0x08	/* just pass up synthesized time */

/*
 * PPS edge info
 */
#define SYNC_ZERO	0x00
#define SYNC_ONE	0x01

struct clockformat
{
  /* special input protocol - implies fixed format */
  u_long	(*input)   P((parse_t *, unsigned int, timestamp_t *));
  /* conversion routine */
  u_long        (*convert) P((unsigned char *, int, struct format *, clocktime_t *, void *));
  /* routine for handling RS232 sync events (time stamps) */
  /* PPS input routine */
  u_long        (*syncpps) P((parse_t *, int, timestamp_t *));
  /* time code synthesizer */

  void           *data;		/* local parameters */
  const char     *name;		/* clock format name */
  unsigned short  length;	/* maximum length of data packet */
  unsigned short  plen;		/* length of private data - implies fixed format */
};

typedef struct clockformat clockformat_t;

/*
 * parse interface
 */
extern int  parse_ioinit P((parse_t *));
extern void parse_ioend P((parse_t *));
extern int  parse_ioread P((parse_t *, unsigned int, timestamp_t *));
extern int  parse_iopps P((parse_t *, int, timestamp_t *));
extern void parse_iodone P((parse_t *));
extern int  parse_timecode P((parsectl_t *, parse_t *));
extern int  parse_getfmt P((parsectl_t *, parse_t *));
extern int  parse_setfmt P((parsectl_t *, parse_t *));
extern int  parse_setcs P((parsectl_t *, parse_t *));

extern unsigned int parse_restart P((parse_t *, unsigned int));
extern unsigned int parse_addchar P((parse_t *, unsigned int));
extern unsigned int parse_end P((parse_t *));

extern int Strok P((const unsigned char *, const unsigned char *));
extern int Stoi P((const unsigned char *, long *, int));

extern time_t parse_to_unixtime P((clocktime_t *, u_long *));
extern u_long updatetimeinfo P((parse_t *, u_long));
extern void syn_simple P((parse_t *, timestamp_t *, struct format *, u_long));
extern u_long pps_simple P((parse_t *, int, timestamp_t *));
extern u_long pps_one P((parse_t *, int, timestamp_t *));
extern u_long pps_zero P((parse_t *, int, timestamp_t *));
extern int parse_timedout P((parse_t *, timestamp_t *, struct timeval *));

#endif

/*
 * History:
 *
 * $Log: parse.h,v $
 * Revision 1.1.1.2  1998/10/30 22:18:03  wsanchez
 * Import of ntp 4.0.73e13
 *
 * Revision 4.4  1998/06/14 21:09:27  kardel
 * Sun acc cleanup
 *
 * Revision 4.3  1998/06/13 11:49:25  kardel
 * STREAM macro gone in favor of HAVE_SYS_STREAM_H
 *
 * Revision 4.2  1998/06/12 15:14:25  kardel
 * fixed prototypes
 *
 * Revision 4.1  1998/05/24 10:07:59  kardel
 * removed old data structure cruft (new input model)
 * new PARSE_INP* macros for input handling
 * removed old SYNC_* macros from old input model
 * (struct clockformat): removed old parse functions in favor of the
 * new input model
 * updated prototypes
 *
 * form V3 3.31 - log info deleted 1998/04/11 kardel
 */
