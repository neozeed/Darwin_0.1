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
 * Copyright (c) 1991, 1992, 1993, 1994, 1995, 1996
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that the above copyright notice and this paragraph are
 * duplicated in all such forms and that any documentation,
 * advertising materials, and other materials related to such
 * distribution and use acknowledge that the software was developed
 * by the University of California, Lawrence Berkeley Laboratory,
 * Berkeley, CA.  The name of the University may not be used to
 * endorse or promote products derived from this software without
 * specific prior written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 * Initial contribution from Jeff Honig (jch@MITCHELL.CIT.CORNELL.EDU).
 */

#ifndef lint
static const char rcsid[] =
    "@(#) $Header: /CVSRoot/CoreOS/Commands/NeXT/network_cmds/tcpdump.tproj/print-egp.c,v 1.1.1.1.52.2 1999/03/16 17:23:34 wsanchez Exp $ (LBL)";
#endif

#include <sys/param.h>
#include <sys/time.h>
#include <sys/uio.h>
#include <sys/socket.h>

#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>

#include <netdb.h>
#include <stdio.h>

#include "interface.h"
#include "addrtoname.h"

struct egp_packet {
	u_char  egp_version;
#define	EGP_VERSION	2
	u_char  egp_type;
#define  EGPT_ACQUIRE	3
#define  EGPT_REACH	5
#define  EGPT_POLL	2
#define  EGPT_UPDATE	1
#define  EGPT_ERROR	8
	u_char  egp_code;
#define  EGPC_REQUEST	0
#define  EGPC_CONFIRM	1
#define  EGPC_REFUSE	2
#define  EGPC_CEASE	3
#define  EGPC_CEASEACK	4
#define  EGPC_HELLO	0
#define  EGPC_HEARDU	1
	u_char  egp_status;
#define  EGPS_UNSPEC	0
#define  EGPS_ACTIVE	1
#define  EGPS_PASSIVE	2
#define  EGPS_NORES	3
#define  EGPS_ADMIN	4
#define  EGPS_GODOWN	5
#define  EGPS_PARAM	6
#define  EGPS_PROTO	7
#define  EGPS_INDET	0
#define  EGPS_UP	1
#define  EGPS_DOWN	2
#define  EGPS_UNSOL	0x80
	u_short  egp_checksum;
	u_short  egp_as;
	u_short  egp_sequence;
	union {
		u_short  egpu_hello;
		u_char egpu_gws[2];
		u_short  egpu_reason;
#define  EGPR_UNSPEC	0
#define  EGPR_BADHEAD	1
#define  EGPR_BADDATA	2
#define  EGPR_NOREACH	3
#define  EGPR_XSPOLL	4
#define  EGPR_NORESP	5
#define  EGPR_UVERSION	6
	} egp_handg;
#define  egp_hello  egp_handg.egpu_hello
#define  egp_intgw  egp_handg.egpu_gws[0]
#define  egp_extgw  egp_handg.egpu_gws[1]
#define  egp_reason  egp_handg.egpu_reason
	union {
		u_short  egpu_poll;
		u_int32_t egpu_sourcenet;
	} egp_pands;
#define  egp_poll  egp_pands.egpu_poll
#define  egp_sourcenet  egp_pands.egpu_sourcenet
};

char *egp_acquire_codes[] = {
	"request",
	"confirm",
	"refuse",
	"cease",
	"cease_ack"
};

char *egp_acquire_status[] = {
	"unspecified",
	"active_mode",
	"passive_mode",
	"insufficient_resources",
	"administratively_prohibited",
	"going_down",
	"parameter_violation",
	"protocol_violation"
};

char *egp_reach_codes[] = {
	"hello",
	"i-h-u"
};

char *egp_status_updown[] = {
	"indeterminate",
	"up",
	"down"
};

char *egp_reasons[] = {
	"unspecified",
	"bad_EGP_header_format",
	"bad_EGP_data_field_format",
	"reachability_info_unavailable",
	"excessive_polling_rate",
	"no_response",
	"unsupported_version"
};

static void
egpnrprint(register const struct egp_packet *egp, register u_int length)
{
	register const u_char *cp;
	u_int32_t addr;
	register u_int32_t net;
	register u_int netlen;
	int gateways, distances, networks;
	int t_gateways;
	char *comma;

	addr = egp->egp_sourcenet;
	if (IN_CLASSA(addr)) {
		net = addr & IN_CLASSA_NET;
		netlen = 1;
	} else if (IN_CLASSB(addr)) {
		net = addr & IN_CLASSB_NET;
		netlen = 2;
	} else if (IN_CLASSC(addr)) {
		net = addr & IN_CLASSC_NET;
		netlen = 3;
	} else {
		net = 0;
		netlen = 0;
	}
	cp = (u_char *)(egp + 1);

	t_gateways = egp->egp_intgw + egp->egp_extgw;
	for (gateways = 0; gateways < t_gateways; ++gateways) {
		/* Pickup host part of gateway address */
		addr = 0;
		TCHECK2(cp[0], 4 - netlen);
		switch (netlen) {

		case 1:
			addr = *cp++;
			/* fall through */
		case 2:
			addr = (addr << 8) | *cp++;
			/* fall through */
		case 3:
			addr = (addr << 8) | *cp++;
		}
		addr |= net;
		TCHECK2(cp[0], 1);
		distances = *cp++;
		printf(" %s %s ",
		       gateways < (int)egp->egp_intgw ? "int" : "ext",
		       ipaddr_string(&addr));

		comma = "";
		putchar('(');
		while (--distances >= 0) {
			TCHECK2(cp[0], 2);
			printf("%sd%d:", comma, (int)*cp++);
			comma = ", ";
			networks = *cp++;
			while (--networks >= 0) {
				/* Pickup network number */
				TCHECK2(cp[0], 1);
				addr = (u_int32_t)*cp++ << 24;
				if (IN_CLASSB(addr)) {
					TCHECK2(cp[0], 1);
					addr |= (u_int32_t)*cp++ << 16;
				} else if (!IN_CLASSA(addr)) {
					TCHECK2(cp[0], 2);
					addr |= (u_int32_t)*cp++ << 16;
					addr |= (u_int32_t)*cp++ << 8;
				}
				printf(" %s", ipaddr_string(&addr));
			}
		}
		putchar(')');
	}
	return;
trunc:
	fputs("[|]", stdout);
}

void
egp_print(register const u_char *bp, register u_int length,
	  register const u_char *bp2)
{
	register const struct egp_packet *egp;
	register const struct ip *ip;
	register int status;
	register int code;
	register int type;

	egp = (struct egp_packet *)bp;
	ip = (struct ip *)bp2;
        (void)printf("%s > %s: egp: ",
		     ipaddr_string(&ip->ip_src),
		     ipaddr_string(&ip->ip_dst));

	if (egp->egp_version != EGP_VERSION) {
		printf("[version %d]", egp->egp_version);
		return;
	}
	printf("as:%d seq:%d", ntohs(egp->egp_as), ntohs(egp->egp_sequence));

	type = egp->egp_type;
	code = egp->egp_code;
	status = egp->egp_status;

	switch (type) {
	case EGPT_ACQUIRE:
		printf(" acquire");
		switch (code) {
		case EGPC_REQUEST:
		case EGPC_CONFIRM:
			printf(" %s", egp_acquire_codes[code]);
			switch (status) {
			case EGPS_UNSPEC:
			case EGPS_ACTIVE:
			case EGPS_PASSIVE:
				printf(" %s", egp_acquire_status[status]);
				break;

			default:
				printf(" [status %d]", status);
				break;
			}
			printf(" hello:%d poll:%d",
			       ntohs(egp->egp_hello),
			       ntohs(egp->egp_poll));
			break;

		case EGPC_REFUSE:
		case EGPC_CEASE:
		case EGPC_CEASEACK:
			printf(" %s", egp_acquire_codes[code]);
			switch (status ) {
			case EGPS_UNSPEC:
			case EGPS_NORES:
			case EGPS_ADMIN:
			case EGPS_GODOWN:
			case EGPS_PARAM:
			case EGPS_PROTO:
				printf(" %s", egp_acquire_status[status]);
				break;

			default:
				printf("[status %d]", status);
				break;
			}
			break;

		default:
			printf("[code %d]", code);
			break;
		}
		break;

	case EGPT_REACH:
		switch (code) {

		case EGPC_HELLO:
		case EGPC_HEARDU:
			printf(" %s", egp_reach_codes[code]);
			if (status <= EGPS_DOWN)
				printf(" state:%s", egp_status_updown[status]);
			else
				printf(" [status %d]", status);
			break;

		default:
			printf("[reach code %d]", code);
			break;
		}
		break;

	case EGPT_POLL:
		printf(" poll");
		if (egp->egp_status <= EGPS_DOWN)
			printf(" state:%s", egp_status_updown[status]);
		else
			printf(" [status %d]", status);
		printf(" net:%s", ipaddr_string(&egp->egp_sourcenet));
		break;

	case EGPT_UPDATE:
		printf(" update");
		if (status & EGPS_UNSOL) {
			status &= ~EGPS_UNSOL;
			printf(" unsolicited");
		}
		if (status <= EGPS_DOWN)
			printf(" state:%s", egp_status_updown[status]);
		else
			printf(" [status %d]", status);
		printf(" %s int %d ext %d",
		       ipaddr_string(&egp->egp_sourcenet),
		       egp->egp_intgw,
		       egp->egp_extgw);
		if (vflag)
			egpnrprint(egp, length);
		break;

	case EGPT_ERROR:
		printf(" error");
		if (status <= EGPS_DOWN)
			printf(" state:%s", egp_status_updown[status]);
		else
			printf(" [status %d]", status);

		if (ntohs(egp->egp_reason) <= EGPR_UVERSION)
			printf(" %s", egp_reasons[ntohs(egp->egp_reason)]);
		else
			printf(" [reason %d]", ntohs(egp->egp_reason));
		break;

	default:
		printf("[type %d]", type);
		break;
	}
}
