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
 * OSPF support contributed by Jeffrey Honig (jch@mitchell.cit.cornell.edu)
 */

#ifndef lint
static const char rcsid[] =
    "@(#) $Header: /CVSRoot/CoreOS/Commands/NeXT/network_cmds/tcpdump.tproj/print-ospf.c,v 1.1.1.1.52.2 1999/03/16 17:23:36 wsanchez Exp $ (LBL)";
#endif

#include <sys/param.h>
#include <sys/time.h>
#include <sys/socket.h>

#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/ip_var.h>

#include <ctype.h>
#include <stdio.h>

#include "interface.h"
#include "addrtoname.h"

#include "ospf.h"

struct bits {
	u_int32_t bit;
	const char *str;
};

static const struct bits ospf_option_bits[] = {
	{ OSPF_OPTION_T,	"T" },
	{ OSPF_OPTION_E,	"E" },
	{ OSPF_OPTION_MC,	"MC" },
	{ 0,			NULL }
};

static const struct bits ospf_rla_flag_bits[] = {
	{ RLA_FLAG_B,		"B" },
	{ RLA_FLAG_E,		"E" },
	{ RLA_FLAG_W1,		"W1" },
	{ RLA_FLAG_W2,		"W2" },
	{ 0,			NULL }
};

static struct tok type2str[] = {
	{ OSPF_TYPE_UMD,	"umd" },
	{ OSPF_TYPE_HELLO,	"hello" },
	{ OSPF_TYPE_DB,		"dd" },
	{ OSPF_TYPE_LSR,	"ls_req" },
	{ OSPF_TYPE_LSU,	"ls_upd" },
	{ OSPF_TYPE_LSA,	"ls_ack" },
	{ 0,			NULL }
};

static char tstr[] = " [|ospf]";

/* Forwards */
static inline void ospf_print_seqage(u_int32_t, time_t);
static inline void ospf_print_bits(const struct bits *, u_char);
static void ospf_print_ls_type(u_int, const struct in_addr *,
    const struct in_addr *, const char *);
static int ospf_print_lshdr(const struct lsa_hdr *);
static int ospf_print_lsa(const struct lsa *);
static int ospf_decode_v2(const struct ospfhdr *, const u_char *);

static inline void
ospf_print_seqage(register u_int32_t seq, register time_t us)
{
	register time_t sec = us % 60;
	register time_t mins = (us / 60) % 60;
	register time_t hour = us / 3600;

	printf(" S %X age ", seq);
	if (hour)
		printf("%u:%02u:%02u",
		    (u_int32_t) hour, (u_int32_t) mins, (u_int32_t) sec);
	else if (mins)
		printf("%u:%02u", (u_int32_t) mins, (u_int32_t) sec);
	else
		printf("%u", (u_int32_t) sec);
}


static inline void
ospf_print_bits(register const struct bits *bp, register u_char options)
{
	register char sep = ' ';

	do {
		if (options & bp->bit) {
			printf("%c%s", sep, bp->str);
			sep = '/';
		}
	} while ((++bp)->bit);
}

static void
ospf_print_ls_type(register u_int ls_type,
    register const struct in_addr *ls_stateid,
    register const struct in_addr *ls_router, register const char *fmt)
{

	switch (ls_type) {

	case LS_TYPE_ROUTER:
		printf(" rtr %s ", ipaddr_string(ls_router));
		break;

	case LS_TYPE_NETWORK:
		printf(" net dr %s if %s",
		    ipaddr_string(ls_router),
		    ipaddr_string(ls_stateid));
		break;

	case LS_TYPE_SUM_IP:
		printf(" sum %s abr %s",
		    ipaddr_string(ls_stateid),
		    ipaddr_string(ls_router));
		break;

	case LS_TYPE_SUM_ABR:
		printf(" abr %s rtr %s",
		    ipaddr_string(ls_router),
		    ipaddr_string(ls_stateid));
		break;

	case LS_TYPE_ASE:
		printf(" ase %s asbr %s",
		    ipaddr_string(ls_stateid),
		    ipaddr_string(ls_router));
		break;

	case LS_TYPE_GROUP:
		printf(" group %s rtr %s",
		    ipaddr_string(ls_stateid),
		    ipaddr_string(ls_router));
		break;

	default:
		putchar(' ');
		printf(fmt, ls_type);
		break;
	}
}

static int
ospf_print_lshdr(register const struct lsa_hdr *lshp)
{

	TCHECK(lshp->ls_type);
	printf(" {");						/* } (ctags) */

	TCHECK(lshp->ls_options);
	ospf_print_bits(ospf_option_bits, lshp->ls_options);
	TCHECK(lshp->ls_seq);
	ospf_print_seqage(ntohl(lshp->ls_seq), ntohs(lshp->ls_age));
	ospf_print_ls_type(lshp->ls_type, &lshp->ls_stateid, &lshp->ls_router,
	    "ls_type %d");

	return (0);
trunc:
	return (1);
}


/*
 * Print a single link state advertisement.  If truncated return 1, else 0.
 */
static int
ospf_print_lsa(register const struct lsa *lsap)
{
	register const u_char *ls_end;
	register const struct rlalink *rlp;
	register const struct tos_metric *tosp;
	register const struct in_addr *ap;
	register const struct aslametric *almp;
	register const struct mcla *mcp;
	register const u_int32_t *lp;
	register int j, k;

	if (ospf_print_lshdr(&lsap->ls_hdr))
		return (1);
	TCHECK(lsap->ls_hdr.ls_length);
	ls_end = (u_char *)lsap + ntohs(lsap->ls_hdr.ls_length);
	switch (lsap->ls_hdr.ls_type) {

	case LS_TYPE_ROUTER:
		TCHECK(lsap->lsa_un.un_rla.rla_flags);
		ospf_print_bits(ospf_rla_flag_bits,
		    lsap->lsa_un.un_rla.rla_flags);

		TCHECK(lsap->lsa_un.un_rla.rla_count);
		j = ntohs(lsap->lsa_un.un_rla.rla_count);
		TCHECK(lsap->lsa_un.un_rla.rla_link);
		rlp = lsap->lsa_un.un_rla.rla_link;
		while (j--) {
			register struct rlalink *rln =
			    (struct rlalink *)((u_char *)(rlp + 1) +
			    ((rlp->link_toscount) * sizeof(*tosp)));

			TCHECK(*rln);
			printf(" {");				/* } (ctags) */
			switch (rlp->link_type) {

			case RLA_TYPE_VIRTUAL:
				printf(" virt");
				/* Fall through */

			case RLA_TYPE_ROUTER:
				printf(" nbrid %s if %s",
				    ipaddr_string(&rlp->link_id),
				    ipaddr_string(&rlp->link_data));
				break;

			case RLA_TYPE_TRANSIT:
				printf(" dr %s if %s",
				    ipaddr_string(&rlp->link_id),
				    ipaddr_string(&rlp->link_data));
				break;

			case RLA_TYPE_STUB:
				printf(" net %s mask %s",
				    ipaddr_string(&rlp->link_id),
				    ipaddr_string(&rlp->link_data));
				break;

			default:
								/* { (ctags) */
				printf(" ??RouterLinksType %d?? }",
				    rlp->link_type);
				return (0);
			}
			printf(" tos 0 metric %d", ntohs(rlp->link_tos0metric));
			tosp = (struct tos_metric *)
			    ((sizeof rlp->link_tos0metric) + (u_char *) rlp);
			for (k = 0; k < (int) rlp->link_toscount; ++k, ++tosp) {
				TCHECK(*tosp);
				printf(" tos %d metric %d",
				    tosp->tos_type,
				    ntohs(tosp->tos_metric));
			}
								/* { (ctags) */
			printf(" }");
			rlp = rln;
		}
		break;

	case LS_TYPE_NETWORK:
		TCHECK(lsap->lsa_un.un_nla.nla_mask);
		printf(" mask %s rtrs",
		    ipaddr_string(&lsap->lsa_un.un_nla.nla_mask));
		ap = lsap->lsa_un.un_nla.nla_router;
		while ((u_char *)ap < ls_end) {
			TCHECK(*ap);
			printf(" %s", ipaddr_string(ap));
			++ap;
		}
		break;

	case LS_TYPE_SUM_IP:
		TCHECK(lsap->lsa_un.un_nla.nla_mask);
		printf(" mask %s",
		    ipaddr_string(&lsap->lsa_un.un_sla.sla_mask));
		/* Fall through */

	case LS_TYPE_SUM_ABR:
		TCHECK(lsap->lsa_un.un_sla.sla_tosmetric);
		lp = lsap->lsa_un.un_sla.sla_tosmetric;
		while ((u_char *)lp < ls_end) {
			register u_int32_t ul;

			TCHECK(*lp);
			ul = ntohl(*lp);
			printf(" tos %d metric %d",
			    (ul & SLA_MASK_TOS) >> SLA_SHIFT_TOS,
			    ul & SLA_MASK_METRIC);
			++lp;
		}
		break;

	case LS_TYPE_ASE:
		TCHECK(lsap->lsa_un.un_nla.nla_mask);
		printf(" mask %s",
		    ipaddr_string(&lsap->lsa_un.un_asla.asla_mask));

		TCHECK(lsap->lsa_un.un_sla.sla_tosmetric);
		almp = lsap->lsa_un.un_asla.asla_metric;
		while ((u_char *)almp < ls_end) {
			register u_int32_t ul;

			TCHECK(almp->asla_tosmetric);
			ul = ntohl(almp->asla_tosmetric);
			printf(" type %d tos %d metric %d",
			    (ul & ASLA_FLAG_EXTERNAL) ? 2 : 1,
			    (ul & ASLA_MASK_TOS) >> ASLA_SHIFT_TOS,
			    (ul & ASLA_MASK_METRIC));
			TCHECK(almp->asla_forward);
			if (almp->asla_forward.s_addr) {
				printf(" forward %s",
				    ipaddr_string(&almp->asla_forward));
			}
			TCHECK(almp->asla_tag);
			if (almp->asla_tag.s_addr) {
				printf(" tag %s",
				    ipaddr_string(&almp->asla_tag));
			}
			++almp;
		}
		break;

	case LS_TYPE_GROUP:
		/* Multicast extensions as of 23 July 1991 */
		mcp = lsap->lsa_un.un_mcla;
		while ((u_char *)mcp < ls_end) {
			TCHECK(mcp->mcla_vid);
			switch (ntohl(mcp->mcla_vtype)) {

			case MCLA_VERTEX_ROUTER:
				printf(" rtr rtrid %s",
				    ipaddr_string(&mcp->mcla_vid));
				break;

			case MCLA_VERTEX_NETWORK:
				printf(" net dr %s",
				    ipaddr_string(&mcp->mcla_vid));
				break;

			default:
				printf(" ??VertexType %u??",
				    (u_int32_t)ntohl(mcp->mcla_vtype));
				break;
			}
		++mcp;
		}
	}

								/* { (ctags) */
	fputs(" }", stdout);
	return (0);
trunc:
	fputs(" }", stdout);
	return (1);
}

static int
ospf_decode_v2(register const struct ospfhdr *op,
    register const u_char *dataend)
{
	register const struct in_addr *ap;
	register const struct lsr *lsrp;
	register const struct lsa_hdr *lshp;
	register const struct lsa *lsap;
	register char sep;
	register int i;

	switch (op->ospf_type) {

	case OSPF_TYPE_UMD:
		/*
		 * Rob Coltun's special monitoring packets;
		 * do nothing
		 */
		break;

	case OSPF_TYPE_HELLO:
		if (vflag) {
			TCHECK(op->ospf_hello.hello_deadint);
			ospf_print_bits(ospf_option_bits,
			    op->ospf_hello.hello_options);
			printf(" mask %s int %d pri %d dead %u",
			    ipaddr_string(&op->ospf_hello.hello_mask),
			    ntohs(op->ospf_hello.hello_helloint),
			    op->ospf_hello.hello_priority,
			    (u_int32_t)ntohl(op->ospf_hello.hello_deadint));
		}
		TCHECK(op->ospf_hello.hello_dr);
		if (op->ospf_hello.hello_dr.s_addr != 0)
			printf(" dr %s",
			    ipaddr_string(&op->ospf_hello.hello_dr));
		TCHECK(op->ospf_hello.hello_bdr);
		if (op->ospf_hello.hello_bdr.s_addr != 0)
			printf(" bdr %s",
			    ipaddr_string(&op->ospf_hello.hello_bdr));
		if (vflag) {
			printf(" nbrs");
			ap = op->ospf_hello.hello_neighbor;
			while ((u_char *)ap < dataend) {
				TCHECK(*ap);
				printf(" %s", ipaddr_string(ap));
				++ap;
			}
		}
		break;	/* HELLO */

	case OSPF_TYPE_DB:
		TCHECK(op->ospf_db.db_options);
		ospf_print_bits(ospf_option_bits, op->ospf_db.db_options);
		sep = ' ';
		TCHECK(op->ospf_db.db_flags);
		if (op->ospf_db.db_flags & OSPF_DB_INIT) {
			printf("%cI", sep);
			sep = '/';
		}
		if (op->ospf_db.db_flags & OSPF_DB_MORE) {
			printf("%cM", sep);
			sep = '/';
		}
		if (op->ospf_db.db_flags & OSPF_DB_MASTER) {
			printf("%cMS", sep);
			sep = '/';
		}
		TCHECK(op->ospf_db.db_seq);
		printf(" S %X", (u_int32_t)ntohl(op->ospf_db.db_seq));

		if (vflag) {
			/* Print all the LS adv's */
			lshp = op->ospf_db.db_lshdr;

			while (!ospf_print_lshdr(lshp)) {
							/* { (ctags) */
				printf(" }");
				++lshp;
			}
		}
		break;

	case OSPF_TYPE_LSR:
		if (vflag) {
			lsrp = op->ospf_lsr;
			while ((u_char *)lsrp < dataend) {
				TCHECK(*lsrp);
				printf(" {");		/* } (ctags) */
				ospf_print_ls_type(ntohl(lsrp->ls_type),
				    &lsrp->ls_stateid,
				    &lsrp->ls_router,
				    "LinkStateType %d");
							/* { (ctags) */
				printf(" }");
				++lsrp;
			}
		}
		break;

	case OSPF_TYPE_LSU:
		if (vflag) {
			lsap = op->ospf_lsu.lsu_lsa;
			TCHECK(op->ospf_lsu.lsu_count);
			i = ntohl(op->ospf_lsu.lsu_count);
			while (i--) {
				if (ospf_print_lsa(lsap))
					goto trunc;
				lsap = (struct lsa *)((u_char *)lsap +
				    ntohs(lsap->ls_hdr.ls_length));
			}
		}
		break;


	case OSPF_TYPE_LSA:
		if (vflag) {
			lshp = op->ospf_lsa.lsa_lshdr;

			while (!ospf_print_lshdr(lshp)) {
							/* { (ctags) */
				printf(" }");
				++lshp;
			}
		}
		break;

	default:
		printf("v2 type %d", op->ospf_type);
		break;
	}
	return (0);
trunc:
	return (1);
}

void
ospf_print(register const u_char *bp, register u_int length,
    register const u_char *bp2)
{
	register const struct ospfhdr *op;
	register const struct ip *ip;
	register const u_char *dataend;
	register const char *cp;

	op = (struct ospfhdr *)bp;
	ip = (struct ip *)bp2;
	/* Print the source and destination address  */
	(void) printf("%s > %s:",
	    ipaddr_string(&ip->ip_src),
	    ipaddr_string(&ip->ip_dst));

	/* If the type is valid translate it, or just print the type */
	/* value.  If it's not valid, say so and return */
	TCHECK(op->ospf_type);
	cp = tok2str(type2str, "type%d", op->ospf_type);
	printf(" OSPFv%d-%s %d:", op->ospf_version, cp, length);
	if (*cp == 't')
		return;

	TCHECK(op->ospf_len);
	if (length != ntohs(op->ospf_len)) {
		printf(" [len %d]", ntohs(op->ospf_len));
		return;
	}
	dataend = bp + length;

	/* Print the routerid if it is not the same as the source */
	TCHECK(op->ospf_routerid);
	if (ip->ip_src.s_addr != op->ospf_routerid.s_addr)
		printf(" rtrid %s", ipaddr_string(&op->ospf_routerid));

	TCHECK(op->ospf_areaid);
	if (op->ospf_areaid.s_addr != 0)
		printf(" area %s", ipaddr_string(&op->ospf_areaid));
	else
		printf(" backbone");

	if (vflag) {
		/* Print authentication data (should we really do this?) */
		TCHECK2(op->ospf_authdata[0], sizeof(op->ospf_authdata));
		switch (ntohs(op->ospf_authtype)) {

		case OSPF_AUTH_NONE:
			break;

		case OSPF_AUTH_SIMPLE:
			printf(" auth \"");
			(void)fn_printn(op->ospf_authdata,
			    sizeof(op->ospf_authdata), NULL);
			printf("\"");
			break;

		default:
			printf(" ??authtype-%d??", ntohs(op->ospf_authtype));
			return;
		}
	}
	/* Do rest according to version.	 */
	switch (op->ospf_version) {

	case 2:
		/* ospf version 2 */
		if (ospf_decode_v2(op, dataend))
			goto trunc;
		break;

	default:
		printf(" ospf [version %d]", op->ospf_version);
		break;
	}			/* end switch on version */

	return;
trunc:
	fputs(tstr, stdout);
}
