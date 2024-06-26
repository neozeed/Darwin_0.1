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
 * Copyright (c) 1992, 1993, 1994, 1995, 1996
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
 * Code by Matt Thomas, Digital Equipment Corporation
 *	with an awful lot of hacking by Jeffrey Mogul, DECWRL
 */

#ifndef lint
static const char rcsid[] =
    "@(#) $Header: /CVSRoot/CoreOS/Commands/NeXT/network_cmds/tcpdump.tproj/print-llc.c,v 1.1.1.1.52.2 1999/03/16 17:23:35 wsanchez Exp $";
#endif

#include <sys/param.h>
#include <sys/time.h>

#include <netinet/in.h>

#include <ctype.h>
#include <netdb.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>

#include "interface.h"
#include "addrtoname.h"
#include "extract.h"			/* must come after interface.h */

#include "llc.h"

static struct tok cmd2str[] = {
	{ LLC_UI,	"ui" },
	{ LLC_TEST,	"test" },
	{ LLC_XID,	"xid" },
	{ LLC_UA,	"ua" },
	{ LLC_DISC,	"disc" },
	{ LLC_DM,	"dm" },
	{ LLC_SABME,	"sabme" },
	{ LLC_FRMR,	"frmr" },
	{ 0,		NULL }
};

/*
 * Returns non-zero IFF it succeeds in printing the header
 */
int
llc_print(const u_char *p, u_int length, u_int caplen,
	  const u_char *esrc, const u_char *edst)
{
	struct llc llc;
	register u_short et;
	register int ret;

	if (caplen < 3) {
		(void)printf("[|llc]");
		default_print((u_char *)p, caplen);
		return(0);
	}

	/* Watch out for possible alignment problems */
	memcpy((char *)&llc, (char *)p, min(caplen, sizeof(llc)));

	if (llc.ssap == LLCSAP_GLOBAL && llc.dsap == LLCSAP_GLOBAL) {
		ipx_print(p, length);
		return (1);
	}
#ifdef notyet
	else if (p[0] == 0xf0 && p[1] == 0xf0)
		netbios_print(p, length);
#endif
	if (llc.ssap == LLCSAP_ISONS && llc.dsap == LLCSAP_ISONS
	    && llc.llcui == LLC_UI) {
		isoclns_print(p + 3, length - 3, caplen - 3, esrc, edst);
		return (1);
	}

	if (llc.ssap == LLCSAP_SNAP && llc.dsap == LLCSAP_SNAP
	    && llc.llcui == LLC_UI) {
		if (caplen < sizeof(llc)) {
		    (void)printf("[|llc-snap]");
		    default_print((u_char *)p, caplen);
		    return (0);
		}
		if (vflag)
			(void)printf("snap %s ", protoid_string(llc.llcpi));

		caplen -= sizeof(llc);
		length -= sizeof(llc);
		p += sizeof(llc);

		/* This is an encapsulated Ethernet packet */
		et = EXTRACT_16BITS(&llc.ethertype[0]);
		ret = ether_encap_print(et, p, length, caplen);
		if (ret)
			return (ret);
	}

	if ((llc.ssap & ~LLC_GSAP) == llc.dsap) {
		if (eflag)
			(void)printf("%s ", llcsap_string(llc.dsap));
		else
			(void)printf("%s > %s %s ",
					etheraddr_string(esrc),
					etheraddr_string(edst),
					llcsap_string(llc.dsap));
	} else {
		if (eflag)
			(void)printf("%s > %s ",
				llcsap_string(llc.ssap & ~LLC_GSAP),
				llcsap_string(llc.dsap));
		else
			(void)printf("%s %s > %s %s ",
				etheraddr_string(esrc),
				llcsap_string(llc.ssap & ~LLC_GSAP),
				etheraddr_string(edst),
				llcsap_string(llc.dsap));
	}

	if ((llc.llcu & LLC_U_FMT) == LLC_U_FMT) {
		const char *m;
		char f;
		m = tok2str(cmd2str, "%02x", LLC_U_CMD(llc.llcu));
		switch ((llc.ssap & LLC_GSAP) | (llc.llcu & LLC_U_POLL)) {
		    case 0:			f = 'C'; break;
		    case LLC_GSAP:		f = 'R'; break;
		    case LLC_U_POLL:		f = 'P'; break;
		    case LLC_GSAP|LLC_U_POLL:	f = 'F'; break;
		    default:			f = '?'; break;
		}

		printf("%s/%c", m, f);

		p += 3;
		length -= 3;
		caplen -= 3;

		if ((llc.llcu & ~LLC_U_POLL) == LLC_XID) {
		    if (*p == LLC_XID_FI) {
			printf(": %02x %02x", p[1], p[2]);
			p += 3;
			length -= 3;
			caplen -= 3;
		    }
		}
	} else {
		char f;
		llc.llcis = ntohs(llc.llcis);
		switch ((llc.ssap & LLC_GSAP) | (llc.llcu & LLC_U_POLL)) {
		    case 0:			f = 'C'; break;
		    case LLC_GSAP:		f = 'R'; break;
		    case LLC_U_POLL:		f = 'P'; break;
		    case LLC_GSAP|LLC_U_POLL:	f = 'F'; break;
		    default:			f = '?'; break;
		}

		if ((llc.llcu & LLC_S_FMT) == LLC_S_FMT) {
			static char *llc_s[] = { "rr", "rej", "rnr", "03" };
			(void)printf("%s (r=%d,%c)",
				llc_s[LLC_S_CMD(llc.llcis)],
				LLC_IS_NR(llc.llcis),
				f);
		} else {
			(void)printf("I (s=%d,r=%d,%c)",
				LLC_I_NS(llc.llcis),
				LLC_IS_NR(llc.llcis),
				f);
		}
		p += 4;
		length -= 4;
		caplen -= 4;
	}
	(void)printf(" len=%d", length);
	if (caplen > 0) {
		default_print_unaligned(p, caplen);
	}
	return(1);
}
