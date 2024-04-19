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
 * nibindd glue 
 * Copyright 1989-94, NeXT Computer Inc.
 */
#include <netinfo/ni.h>
#include <sys/socket.h>
#include <stdio.h>
#include <string.h>

/*
 * Initiate nibindd connection
 */
void *
nibind_new(
	   struct in_addr *addr
	   )
{
	struct sockaddr_in sin;
	int sock = RPC_ANYSOCK;

	sin.sin_port = 0;
	sin.sin_family = AF_INET;
	bzero(sin.sin_zero, sizeof(sin.sin_zero));
	sin.sin_addr = *addr;
	return ((void *)clnttcp_create(&sin, NIBIND_PROG, NIBIND_VERS, 
				       &sock, 0, 0));
}

/*
 * List registered netinfods
 */
ni_status
nibind_listreg(
	       void *nb,
	       nibind_registration **regvec,
	       unsigned *reglen
	       )
{
	nibind_listreg_res *res;

	res = nibind_listreg_1(NULL, nb);
	if (res == NULL) {
 		return (NI_FAILED);
	}
	if (res->status == NI_OK) {
		*regvec = res->nibind_listreg_res_u.regs.regs_val;
		*reglen = res->nibind_listreg_res_u.regs.regs_len;
	}
	return (res->status);
}

/*
 * Create a master netinfod
 */
ni_status
nibind_createmaster(
		    void *nb,
		    ni_name tag
		    )
{
	ni_status *status;

	status = nibind_createmaster_1(&tag, nb);
	if (status == NULL) {
		return (NI_FAILED);
	}
	return (*status);
}
	
/*
 * Create a clone netinfod
 */
ni_status
nibind_createclone(
		   void *nb,
		   ni_name tag,
		   ni_name master_name,
		   struct in_addr *master_addr,
		   ni_name master_tag
		   )
{
	ni_status *status;
	nibind_clone_args args;

	args.tag = tag;
	args.master_name = master_name;
	args.master_addr = master_addr->s_addr;
	args.master_tag = master_tag;

	/* XDR will swap the master address if this is a little-endian system. */
	/* We swap it to host order first, so that XDR will swap it back to */
	/* network byte order. */
	args.master_addr = ntohl(args.master_addr);

	status = nibind_createclone_1(&args, nb);
	if (status == NULL) {
		return (NI_FAILED);
	}
	return (*status);
}

/*
 * Destroy a netinfod
 */
ni_status
nibind_destroydomain(
		     void *nb,
		     ni_name tag
		     )
{
	ni_status *status;

	status = nibind_destroydomain_1(&tag, nb);
	if (status == NULL) {
		return (NI_FAILED);
	}
	return (*status);
}
		   

/*
 * Free up connection to nibindd
 */
void
nibind_free(
	    void *nb
	    )
{
	clnt_destroy(((CLIENT *)nb));
}
