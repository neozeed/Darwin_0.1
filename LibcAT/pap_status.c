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
 *      Copyright (c) 1998 Apple Computer, Inc. 
 *
 *      The information contained herein is subject to change without
 *      notice and  should not be  construed as a commitment by Apple
 *      Computer, Inc. Apple Computer, Inc. assumes no responsibility
 *      for any errors that may appear.
 *
 *      Confidential and Proprietary to Apple Computer, Inc.
 *
 * $Id: pap_status.c,v 1.7.26.3 1999/03/16 15:49:23 wsanchez Exp $
 */

#include <h/sysglue.h>
#include <fcntl.h>
#include <at/appletalk.h>
#include <at/pap.h>
#include <at/atp.h>
#include <at/nbp.h>
#include <at/at_pap.h>

#include <mach/cthreads.h>

#ifndef PR_2206317_FIXED
#define	SET_ERRNO(e)	(cthread_set_errno_self(e), errno = e)
#else
#define	SET_ERRNO(e)	cthread_set_errno_self(e)
#endif

char	*pap_status(tuple)
at_nbptuple_t	*tuple;
{
	int		fd;
	u_char		rdata[512];
	int		tmpErrno;
	char		*pap_status_get();
	int userdata;
	u_char	*puserdata = (u_char *)&userdata;
	at_resp_t resp;
	at_retry_t retry;

	if (tuple == NULL) {
		SET_ERRNO(EINVAL);
		return (NULL);
	}
	
	if (_nbp_validate_entity_(&tuple->enu_entity,0,1)==0){/*nometa,zone ok*/
		SET_ERRNO(EINVAL);
		return (NULL);
	}

	pap_status_update("=", P_NOEXIST, strlen(P_NOEXIST));

	fd = atp_open(NULL);
	if (fd < 0)
		return(NULL);

	puserdata[0] = 0;
	puserdata[1] = AT_PAP_TYPE_SEND_STATUS;
	puserdata[2] = 0;
	puserdata[3] = 0;
	retry.interval = 2;
	retry.retries = 5;
	resp.bitmap = 0x01;
	resp.resp[0].iov_base = rdata;
	resp.resp[0].iov_len = sizeof(rdata);

	for (;;) {
		if (atp_sendreq(fd, &tuple->enu_addr, 0, 0, userdata, 0, 0, 0,
				&resp, &retry, 0) < 0) {
			tmpErrno = cthread_errno();
			atp_close(fd);
			SET_ERRNO(tmpErrno);
			return(NULL);
		}
		puserdata = (u_char *)&resp.userdata[0];
		if (puserdata[1] != AT_PAP_TYPE_SEND_STS_REPLY) {
			puserdata = (u_char *)&userdata;
			continue;
		}
		atp_close(fd);
		pap_status_update(tuple->enu_entity.type.str, 
			&rdata[5], rdata[4]);
		return(pap_status_get());
	}
}

