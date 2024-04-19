/* config.h for Windows NT */

#ifndef __config
#define __config

/*
 * Windows NT Configuration Values
 */
# define MCAST				/* Enable Multicast Support */															/*	98/06/01  */
# undef  OPEN_BCAST_SOCKET		/* for	ntp_io.c */ 																	/*	98/06/01  *//*	98/06/03  */
# undef  UDP_WILDCARD_DELIVERY	/* for	ntp_io.c */ 																	/*	98/06/01  */
# define REFCLOCK				/* from ntpd.mak */
# define CLOCK_LOCAL			/* from ntpd.mak */
/* # define CLOCK_SHM			 * from ntpd.mak */																	/*	98/06/01  */
/* # define CLOCK_PALISADE		 * from ntpd.mak */																	/*	98/06/26  */
# undef  DES				/* from libntp.mak */																	/*	98/05/28  */
# undef  MD5				/* from libntp.mak */																	/*	98/05/28  */
# define NTP_LITTLE_ENDIAN		/* from libntp.mak */
# define SYSLOG_FILE			/* from libntp.mak */
# define HAVE_PROTOTYPES		/* from ntpq.mak */
# define USE_PROTOTYPES 		/* for ntp_types.h */																	/*	98/05/29  */
# define SIZEOF_INT 4			/* for ntp_types.h */
# define SYSV_TIMEOFDAY 		/* for ntp_unixtime.h */
# define HAVE_NET_IF_H
# define QSORT_USES_VOID_P
# define HAVE_MEMMOVE
# define volatile
# define STDC_HEADERS
# define NEED_S_CHAR_TYPEDEF
# define SIZEOF_SIGNED_CHAR 1
# define HAVE_NO_NICE
# define NOKMEM
# define PRESET_TICK (every / 10)
# define PRESET_TICKADJ 50
# define RETSIGTYPE void
# define NTP_POSIX_SOURCE
# define HAVE_SETVBUF
# define HAVE_VSPRINTF
# ifndef STR_SYSTEM
#  define STR_SYSTEM "WINDOWS/NT"
# endif

#endif /* __config */
