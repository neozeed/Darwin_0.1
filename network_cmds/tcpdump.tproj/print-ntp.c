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
 * Copyright (c) 1990, 1991, 1992, 1993, 1994, 1995, 1996
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
 * Format and print ntp packets.
 *	By Jeffrey Mogul/DECWRL
 *	loosely based on print-bootp.c
 */

#ifndef lint
static const char rcsid[] =
    "@(#) $Header: /CVSRoot/CoreOS/Commands/NeXT/network_cmds/tcpdump.tproj/print-ntp.c,v 1.1.1.1.52.2 1999/03/16 17:23:36 wsanchez Exp $ (LBL)";
#endif

#include <sys/param.h>
#include <sys/time.h>
#include <sys/socket.h>

#if __STDC__
struct mbuf;
struct rtentry;
#endif
#include <net/if.h>

#include <netinet/in.h>
#include <netinet/if_ether.h>

#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include "interface.h"
#include "addrtoname.h"
#undef MODEMASK					/* Solaris sucks */
#include "ntp.h"

static void p_sfix(const struct s_fixedpt *);
static void p_ntp_time(const struct l_fixedpt *);
static void p_ntp_delta(const struct l_fixedpt *, const struct l_fixedpt *);

/*
 * Print ntp requests
 */
void
ntp_print(register const u_char *cp, u_int length)
{
	register const struct ntpdata *bp;
	int mode, version, leapind;
	static char rclock[5];

	bp = (struct ntpdata *)cp;
	/* Note funny sized packets */
	if (length != sizeof(struct ntpdata))
		(void)printf(" [len=%d]", length);

	TCHECK(bp->status);

	version = (int)(bp->status & VERSIONMASK) >> 3;
	printf(" v%d", version);

	leapind = bp->status & LEAPMASK;
	switch (leapind) {

	case NO_WARNING:
		break;

	case PLUS_SEC:
		fputs(" +1s", stdout);
		break;

	case MINUS_SEC:
		fputs(" -1s", stdout);
		break;
	}

	mode = bp->status & MODEMASK;
	switch (mode) {

	case MODE_UNSPEC:	/* unspecified */
		fputs(" unspec", stdout);
		break;

	case MODE_SYM_ACT:	/* symmetric active */
		fputs(" sym_act", stdout);
		break;

	case MODE_SYM_PAS:	/* symmetric passive */
		fputs(" sym_pas", stdout);
		break;

	case MODE_CLIENT:	/* client */
		fputs(" client", stdout);
		break;

	case MODE_SERVER:	/* server */
		fputs(" server", stdout);
		break;

	case MODE_BROADCAST:	/* broadcast */
		fputs(" bcast", stdout);
		break;

	case MODE_RES1:		/* reserved */
		fputs(" res1", stdout);
		break;

	case MODE_RES2:		/* reserved */
		fputs(" res2", stdout);
		break;

	}

	TCHECK(bp->stratum);
	printf(" strat %d", bp->stratum);

	TCHECK(bp->ppoll);
	printf(" poll %d", bp->ppoll);

	/* Can't TCHECK bp->precision bitfield so bp->distance + 0 instead */
	TCHECK2(bp->distance, 0);
	printf(" prec %d", bp->precision);

	if (!vflag)
		return;

	TCHECK(bp->distance);
	fputs(" dist ", stdout);
	p_sfix(&bp->distance);

	TCHECK(bp->dispersion);
	fputs(" disp ", stdout);
	p_sfix(&bp->dispersion);

	TCHECK(bp->refid);
	fputs(" ref ", stdout);
	/* Interpretation depends on stratum */
	switch (bp->stratum) {

	case UNSPECIFIED:
		printf("(unspec)");
		break;

	case PRIM_REF:
		strncpy(rclock, (char *)&(bp->refid), 4);
		rclock[4] = '\0';
		fputs(rclock, stdout);
		break;

	case INFO_QUERY:
		printf("%s INFO_QUERY", ipaddr_string(&(bp->refid)));
		/* this doesn't have more content */
		return;

	case INFO_REPLY:
		printf("%s INFO_REPLY", ipaddr_string(&(bp->refid)));
		/* this is too complex to be worth printing */
		return;

	default:
		printf("%s", ipaddr_string(&(bp->refid)));
		break;
	}

	TCHECK(bp->reftime);
	putchar('@');
	p_ntp_time(&(bp->reftime));

	TCHECK(bp->org);
	fputs(" orig ", stdout);
	p_ntp_time(&(bp->org));

	TCHECK(bp->rec);
	fputs(" rec ", stdout);
	p_ntp_delta(&(bp->org), &(bp->rec));

	TCHECK(bp->xmt);
	fputs(" xmt ", stdout);
	p_ntp_delta(&(bp->org), &(bp->xmt));

	return;

trunc:
	fputs(" [|ntp]", stdout);
}

static void
p_sfix(register const struct s_fixedpt *sfp)
{
	register int i;
	register int f;
	register float ff;

	i = ntohs(sfp->int_part);
	f = ntohs(sfp->fraction);
	ff = f / 65536.0;	/* shift radix point by 16 bits */
	f = ff * 1000000.0;	/* Treat fraction as parts per million */
	printf("%d.%06d", i, f);
}

#define	FMAXINT	(4294967296.0)	/* floating point rep. of MAXINT */

static void
p_ntp_time(register const struct l_fixedpt *lfp)
{
	register int32_t i;
	register u_int32_t uf;
	register u_int32_t f;
	register float ff;

	i = ntohl(lfp->int_part);
	uf = ntohl(lfp->fraction);
	ff = uf;
	if (ff < 0.0)		/* some compilers are buggy */
		ff += FMAXINT;
	ff = ff / FMAXINT;	/* shift radix point by 32 bits */
	f = ff * 1000000000.0;	/* treat fraction as parts per billion */
	printf("%u.%09d", i, f);
}

/* Prints time difference between *lfp and *olfp */
static void
p_ntp_delta(register const struct l_fixedpt *olfp,
	    register const struct l_fixedpt *lfp)
{
	register int32_t i;
	register u_int32_t uf;
	register u_int32_t ouf;
	register u_int32_t f;
	register float ff;
	int signbit;

	i = ntohl(lfp->int_part) - ntohl(olfp->int_part);

	uf = ntohl(lfp->fraction);
	ouf = ntohl(olfp->fraction);

	if (i > 0) {		/* new is definitely greater than old */
		signbit = 0;
		f = uf - ouf;
		if (ouf > uf)	/* must borrow from high-order bits */
			i -= 1;
	} else if (i < 0) {	/* new is definitely less than old */
		signbit = 1;
		f = ouf - uf;
		if (uf > ouf)	/* must carry into the high-order bits */
			i += 1;
		i = -i;
	} else {		/* int_part is zero */
		if (uf > ouf) {
			signbit = 0;
			f = uf - ouf;
		} else {
			signbit = 1;
			f = ouf - uf;
		}
	}

	ff = f;
	if (ff < 0.0)		/* some compilers are buggy */
		ff += FMAXINT;
	ff = ff / FMAXINT;	/* shift radix point by 32 bits */
	f = ff * 1000000000.0;	/* treat fraction as parts per billion */
	if (signbit)
		putchar('-');
	else
		putchar('+');
	printf("%d.%09d", i, f);
}
