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
 * Copyright (c) 1992, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 * All rights reserved.
 *
 * This code is derived from software donated to Berkeley by
 * Jan-Simon Pendry.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)pt_tcp.c	8.5 (Berkeley) 4/28/95
 */

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <strings.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/syslog.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#include "portald.h"

/*
 * Key will be tcp/host/port[/"priv"]
 * Create a TCP socket connected to the
 * requested host and port.
 * Some trailing suffix values have special meanings.
 * An unrecognised suffix is an error.
 */
int portal_tcp(pcr, key, v, kso, fdp)
	struct portal_cred *pcr;
	char *key;
	char **v;
	int kso;
	int *fdp;
{
	char host[MAXHOSTNAMELEN];
	char port[MAXHOSTNAMELEN];
	char *p = key + (v[1] ? strlen(v[1]) : 0);
	char *q;
	struct hostent *hp;
	struct servent *sp;
	struct in_addr **ipp;
	struct in_addr *ip[2];
	struct in_addr ina;
	int s_port;
	int priv = 0;
	struct sockaddr_in sain;

	q = strchr(p, '/');
	if (q == 0 || q - p >= sizeof(host))
		return (EINVAL);
	*q = '\0';
	strcpy(host, p);
	p = q + 1;

	q = strchr(p, '/');
	if (q)
		*q = '\0';
	if (strlen(p) >= sizeof(port))
		return (EINVAL);
	strcpy(port, p);
	if (q) {
		p = q + 1;
		if (strcmp(p, "priv") == 0) {
			if (pcr->pcr_uid == 0)
				priv = 1;
			else
				return (EPERM);
		} else {
			return (EINVAL);
		}
	}

	hp = gethostbyname(host);
	if (hp != 0) {
		ipp = (struct in_addr **) hp->h_addr_list;
	} else {
		ina.s_addr = inet_addr(host);
		if (ina.s_addr == INADDR_NONE)
			return (EINVAL);
		ip[0] = &ina;
		ip[1] = 0;
		ipp = ip;
	}

	sp = getservbyname(port, "tcp");
	if (sp != 0)
		s_port = sp->s_port;
	else {
		s_port = strtoul(port, &p, 0);
		if (s_port == 0 || *p != '\0')
			return (EINVAL);
		s_port = htons(s_port);
	}

	memset(&sain, 0, sizeof(sain));
	sain.sin_len = sizeof(sain);
	sain.sin_family = AF_INET;
	sain.sin_port = s_port;

	while (ipp[0]) {
		int so;

		if (priv)
			so = rresvport((int *) 0);
		else
			so = socket(AF_INET, SOCK_STREAM, 0);
		if (so < 0) {
			syslog(LOG_ERR, "socket: %m");
			return (errno);
		}

		sain.sin_addr = *ipp[0];
		if (connect(so, (struct sockaddr *) &sain, sizeof(sain)) == 0) {
			*fdp = so;
			return (0);
		}
		(void) close(so);

		ipp++;
	}

	return (errno);
}