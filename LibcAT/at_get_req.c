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
 *	Copyright (c) 1988, 1989, 1998 Apple Computer, Inc. 
 *
 *	The information contained herein is subject to change without
 *	notice and  should not be  construed as a commitment by Apple
 *	Computer, Inc. Apple Computer, Inc. assumes no responsibility
 *	for any errors that may appear.
 *
 *	Confidential and Proprietary to Apple Computer, Inc.
 *
 * $Id: at_get_req.c,v 1.9.26.3 1999/03/16 15:49:20 wsanchez Exp $
 */
	
/*
 8-17-93 jjs restored lib interface removed in A/UX 3.0
 10-9-93 tan added nowait option
*/
	
/* @(#)atp_get_req.c: 1.0, 1.0; 7/29/93; Copyright 1988-89, Apple Computer, Inc. */
	
#include <h/sysglue.h>
#include <at/appletalk.h>
#include <at/atp.h>
#include <at/ddp.h>
#include <signal.h>
#include <unistd.h>

#include <at/nbp.h>
#include <at/asp_errno.h>

#include <mach/cthreads.h>

#include "at_proto.h"

#ifndef PR_2206317_FIXED
#define	SET_ERRNO(e)	(cthread_set_errno_self(e), errno = e)
#else
#define	SET_ERRNO(e)	cthread_set_errno_self(e)
#endif

#define      REQ_ARRIVED(p)    (!*((char *) p))  
	
/*
 * atp_getreq()
 * 
 * Description: ATP get request routine, see A/UX manual section 3.
 *
 * returns:  0 upon success
 *          -1 if error occurred, errno set to reflect errors as follows:
 *			EMSGSIZE - If message size was invalid
 *
 */
int
atp_getreq(fd, src, reqbuf, reqlen, userdata, xo, tid, bitmap, nowait)
	int		fd;
	at_inet_t	*src;
	char		*reqbuf;
	int		*reqlen, *userdata, *xo;
	u_short		*tid;
	u_char		*bitmap;
	int		nowait;
{
	char		cbuf[DDP_DATAGRAM_SIZE+ATP_HDR_SIZE];
	char		*pcbuf = cbuf;
	int		len;
	at_atp_t	*atphdr;
	at_ddp_t	*ddphdr;
	int		i;

	if (nowait) {
		/*
		 * take a look to see if there's any event
		 */
		if (atp_look(fd) < 0) {
			SET_ERRNO(EAGAIN);
			return (-1);
		}
	}

	/*
	 * get and check the event byte for request indicator
	 */
	while (1) {
		if ((i = read(fd, reqbuf, 1)) == -1)
			return (-1);
		if (i == 1) {
			if (REQ_ARRIVED(reqbuf)) 
				break;
		}
	}
	
	/* request has arrived, get it */
	
	if ((len = ATPgetreq(fd, cbuf, sizeof(cbuf))) < 0)
		return (-1);
	
	atphdr = (at_atp_t *)(&cbuf[DDP_X_HDR_SIZE]);  
	ddphdr = (at_ddp_t *) cbuf;
	
	/* fill in user return info */
	*reqlen = len - (DDP_X_HDR_SIZE + ATP_HDR_SIZE);
	pcbuf += (DDP_X_HDR_SIZE + ATP_HDR_SIZE); /* pcbuf -> user data */
	if (*reqlen < 0) {
		SET_ERRNO(EMSGSIZE);
		return(-1);
	}
	memcpy(reqbuf, pcbuf, *reqlen);		/* copy user data */
	UAS_UAS(src->net, ddphdr->src_net);
	src->node   = ddphdr->src_node;
	src->socket = ddphdr->src_socket;
	if (userdata)
		*userdata = *(unsigned *)atphdr->user_bytes;

	*tid	= UAS_VALUE(atphdr->tid);
	*xo 	= atphdr->xo ? 1 : 0; 
	*bitmap	= atphdr->bitmap;
	
	return (0);
}
