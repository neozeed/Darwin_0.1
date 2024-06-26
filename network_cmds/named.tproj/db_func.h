/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * "Portions Copyright (c) 1999 Apple Computer, Inc.  All Rights
 * Reserved.  This file contains Original Code and/or Modifications of
 * Original Code as defined in and that are subject to the Apple Public
 * Source License Version 1.0 (the 'License').  You may not use this file
 * except in compliance with the License.  Please obtain a copy of the
 * License at http://www.apple.com/publicsource and read it before using
 * this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
 * License for the specific language governing rights and limitations
 * under the License."
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/* db_proc.h - prototypes for functions in db_*.c
 *
 * $Id: db_func.h,v 1.1.1.1.52.2 1999/03/16 17:22:24 wsanchez Exp $
 */

/* ++from db_update.c++ */
extern int		db_update __P((char name[],
				       struct databuf *odp,
				       struct databuf *newdp,
				       int flags,
				       struct hashbuf *htp)),
			findMyZone __P((struct namebuf *np, int class));
/* --from db_update.c-- */

/* ++from db_reload.c++ */
extern void		db_reload __P((void));
/* --from db_reload.c-- */

/* ++from db_save.c++ */
extern struct namebuf	*savename __P((const char *, int));
#ifdef DMALLOC
extern struct databuf	*savedata_tagged __P((char *, int,
					      int, int, u_int32_t,
					      u_char *, int));
#define savedata(class, type, ttl, data, size) \
	savedata_tagged(__FILE__, __LINE__, class, type, ttl, data, size)
#else
extern struct databuf	*savedata __P((int, int, u_int32_t,
				       u_char *, int));
#endif
extern struct hashbuf	*savehash __P((struct hashbuf *));
/* --from db_save.c-- */

/* ++from db_dump.c++ */
extern int		db_dump __P((struct hashbuf *, FILE *, int, char *)),
			zt_dump __P((FILE *)),
			atob __P((char *, int, char *, int, int *));
extern void		doachkpt __P((void)),
			doadump __P((void));
#ifdef ALLOW_UPDATES
extern void		zonedump __P((struct zoneinfo *));
#endif
extern u_int		db_getclev __P((const char *));
/* --from db_dump.c-- */

/* ++from db_load.c++ */
extern void		endline __P((FILE *)),
			get_netlist __P((FILE *, struct netinfo **,
					 int, char *)),
			free_netlist __P((struct netinfo **));
extern int		getword __P((char *, int, FILE *)),
			getnum __P((FILE *, const char *, int)),
			db_load __P((const char *, const char *,
				     struct zoneinfo *, const char *)),
			position_on_netlist __P((struct in_addr,
						 struct netinfo *));
extern struct netinfo	*addr_on_netlist __P((struct in_addr,
					      struct netinfo *));
/* --from db_load.c-- */

/* ++from db_glue.c++ */
extern const char	*sin_ntoa __P((const struct sockaddr_in *));
extern void		panic __P((int, const char *)),
			buildservicelist __P((void)),
			buildprotolist __P((void)),
			gettime __P((struct timeval *)),
			getname __P((struct namebuf *, char *, int));
extern int		servicenumber __P((char *)),
			protocolnumber __P((char *)),
			my_close __P((int)),
			my_fclose __P((FILE *)),
#ifdef GEN_AXFR
			get_class __P((char *)),
#endif
			writemsg __P((int, u_char *, int)),
			dhash __P((const u_char *, int)),
			nhash __P((const char *)),
			samedomain __P((const char *, const char *));
extern char		*protocolname __P((int)),
			*servicename __P((u_int16_t, char *)),
			*savestr __P((const char *));
extern const char	*inet_etoa __P((const struct sockaddr_in *));
#ifndef BSD
extern int		getdtablesize __P((void));
#endif
extern struct databuf	*rm_datum __P((struct databuf *,
				       struct namebuf *,
				       struct databuf *));
extern struct namebuf	*rm_name __P((struct namebuf *, 
				      struct namebuf **,
				      struct namebuf *));
#ifdef INVQ
extern void		addinv __P((struct namebuf *, struct databuf *)),
			rminv __P((struct databuf *));
struct invbuf		*saveinv __P((void));
#endif
#ifdef LOC_RR
extern u_int32_t	loc_aton __P((const char *ascii, u_char *binary));
extern char *		loc_ntoa __P((const u_char *binary, char *ascii));
#endif
extern char *		ctimel __P((long));
extern struct in_addr	data_inaddr __P((const u_char *data));
/* --from db_glue.c-- */

/* ++from db_lookup.c++ */
extern struct namebuf	*nlookup __P((const char *, struct hashbuf **,
				      const char **, int));
extern int		match __P((struct databuf *, int, int));
/* --from db_lookup.c-- */

/* ++from db_secure.c++ */
#ifdef SECURE_ZONES
extern int		build_secure_netlist __P((struct zoneinfo *));
#endif
/* --from db_secure.c-- */
