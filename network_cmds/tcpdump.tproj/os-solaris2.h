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
/*
 * Copyright (c) 1993, 1994, 1995, 1996
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that: (1) source code distributions
 * retain the above copyright notice and this paragraph in its entirety, (2)
 * distributions including binary code include the above copyright notice and
 * this paragraph in its entirety in the documentation or other materials
 * provided with the distribution, and (3) all advertising materials mentioning
 * features or use of this software display the following acknowledgement:
 * ``This product includes software developed by the University of California,
 * Lawrence Berkeley Laboratory and its contributors.'' Neither the name of
 * the University nor the names of its contributors may be used to endorse
 * or promote products derived from this software without specific prior
 * written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 * @(#) $Header: /CVSRoot/CoreOS/Commands/NeXT/network_cmds/tcpdump.tproj/os-solaris2.h,v 1.1.1.1.52.2 1999/03/16 17:23:33 wsanchez Exp $ (LBL)
 */

/* Prototypes missing in SunOS 5 */
int	daemon(int, int);
int	dn_expand(u_char *, u_char *, u_char *, u_char *, int);
int	dn_skipname(u_char *, u_char *);
int	flock(int, int);
int	getdtablesize(void);
int	gethostname(char *, int);
int	getpagesize(void);
char	*getusershell(void);
char	*getwd(char *);
int	iruserok(u_int, int, char *, char *);
#ifdef __STDC__
struct	utmp;
void	login(struct utmp *);
#endif
int	logout(const char *);
int	res_query(char *, int, int, u_char *, int);
int	setenv(const char *, const char *, int);
#if defined(_STDIO_H) && defined(HAVE_SETLINEBUF)
int	setlinebuf(FILE *);
#endif
int	sigblock(int);
int	sigsetmask(int);
char    *strerror(int);
int	snprintf(char *, size_t, const char *, ...);
int	strcasecmp(const char *, const char *);
void	unsetenv(const char *);
#ifdef __STDC__
struct	timeval;
#endif
int	utimes(const char *, struct timeval *);
