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
#import "Server.h"
#import <sys/types.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <sys/socket.h>
#import <net/if.h>
#import <sys/ioctl.h>
#import <rpc/types.h>
#import <rpc/xdr.h>
#import <rpc/auth.h>
#import <rpc/clnt.h>
#import <rpc/svc.h>
#import "nfs_prot.h"
#import "automount.h"
#import "log.h"
#import "mount.h"
#import "String.h"

#define LIFE_LATENCY 120
#define DEATH_LATENCY 60

#ifndef __APPLE__
#import <libc.h>
#endif

extern u_short getport(struct sockaddr_in *, u_long, u_long, u_int);

static char *
mnt_strerror(int s)
{
	if (s == 0) return "No error";
	if (s == 1) return "Not owner";
	if (s == 2) return "No such file or directory";
	if (s == 5) return "I/O error";
	if (s == 13) return "Permission denied";
	if (s == 20) return "Not a directory";
	if (s == 22) return "Invalid argument";
	if (s == 63) return "Filename too long";
	if (s == 10004) return "Operation not supported";
	return "Server failure";
}

@implementation Server

+ (BOOL)isMyAddress:(unsigned int)a mask:(unsigned int)m
{
	struct ifconf ifc;
	struct ifreq *ifr;
	char buf[1024];
	int offset, addrlen;
	int sock;
	unsigned int me;

	me = htonl(INADDR_LOOPBACK);
	if ((a & m) == (me & m)) return YES;

	sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (sock < 0) return NO;

	ifc.ifc_len = sizeof(buf);
	ifc.ifc_buf = buf;

	if (ioctl(sock, SIOCGIFCONF, (char *)&ifc) < 0)
	{
		close(sock);
		return NO;
	}

	addrlen = sizeof(struct ifreq) - IFNAMSIZ;
	offset = 0;

	while (offset <= ifc.ifc_len)
	{
		ifr = (struct ifreq *)(ifc.ifc_buf + offset);
#ifdef __APPLE__
		offset += IFNAMSIZ;
		if (ifr->ifr_addr.sa_len > addrlen) offset += ifr->ifr_addr.sa_len;
		else offset += addrlen;
#else
		offset += sizeof(struct ifreq);
#endif
		if (ifr->ifr_addr.sa_family != AF_INET) continue;
		if (ioctl(sock, SIOCGIFFLAGS, ifr) < 0) continue;

		if ((ifr->ifr_flags & IFF_UP) && (!(ifr->ifr_flags & IFF_LOOPBACK)))
		{
			me = ((struct sockaddr_in *)&(ifr->ifr_addr))->sin_addr.s_addr;
			if ((a & m) == (me & m))
			{
				close(sock);
				return YES;
			}
		}
	}

	close(sock);
	return NO;
}

+ (BOOL)isMyAddress:(String *)addr
{
	if (addr == nil) return NO;
	return [Server isMyAddress:inet_addr([addr value]) mask:(unsigned int)-1];
}

+ (BOOL)isMyNetwork:(String *)net
{
	char *s, *p;
	unsigned int bits, a, i, x, m;

	if (net == nil) return NO;

	s = malloc([net length] + 1);
	strcpy(s, [net value]);
	p = strchr(s, '/');
	if (p == NULL) 
	{
		free(s);
		return [Server isMyAddress:net];
	}

	*p = '\0';
	p++;
	bits = atoi(p);
	if (bits == 0)
	{
		free(s);
		return [Server isMyAddress:net];
	}

	a = inet_addr(s);
	free(s);

	bits = 33 - bits;
	m = 0;
	for (i = 1, x = 1; i < bits; i++, x *= 2) m |= x;
	m = ~m;

	return [Server isMyAddress:a mask:m];
}

- (Server *)initWithName:(String *)servername
{
	struct hostent *h;
	char hn[1024];

	[super init];

	if (servername == nil)
	{
		[self release];
		return nil;
	}

	pings = 5;
	timeout = 4;

	gethostname(hn, 1024);
	isLocalHost = NO;
	if ((!strcmp(hn, [servername value]))
		|| (!strcmp("localhost", [servername value])))
	{
		isLocalHost = YES;
		myname = [servername retain];
		address = htonl(INADDR_LOOPBACK);
		port = 0;

		return self;
	}

	h = gethostbyname([servername value]);
	if (h == NULL)
	{
		[self release];
		return nil;
	}

	myname = [servername retain];
	bcopy(h->h_addr, &address, sizeof(unsigned long));

	port = 0;
	mountClient = NULL;
	isDead = NO;

	last_tv.tv_sec = 0;
	last_tv.tv_usec = 0;

	return self;
}

- (void)setTimeout:(unsigned int)t
{
	if (t == 0) timeout = 1;
	else timeout = t;
}

- (String *)name
{
	return myname;
}

- (BOOL)isLocalHost
{
	return isLocalHost;
}

- (unsigned long)address
{
	return address;
}

- (void)reset
{
	port = 0;
	isDead = NO;
}

- (unsigned short)nfsPort
{
	struct sockaddr_in sin;
	struct timeval tv;
	CLIENT *cl;
	int s, delta;

	gettimeofday(&tv, NULL);
	delta = tv.tv_sec - last_tv.tv_sec;
	if (delta > LIFE_LATENCY) port = 0;

	if (port != 0) return port;

	if (mountClient != NULL)
	{
		cl = (CLIENT *)mountClient;
		auth_destroy(cl->cl_auth);
		clnt_destroy(cl);
	}

	mountClient = NULL;

	if (isDead && (delta < DEATH_LATENCY))
	{
		sys_msg(debug, LOG_ERR,
			"Assuming %s is still unavailable (%d seconds remain)",
			[myname value], DEATH_LATENCY - delta);
		return 0;
	}

	isDead = NO;

	bzero((char *)&sin, sizeof(sin));
	sin.sin_family = AF_INET;
	sin.sin_addr.s_addr = address;
	sin.sin_port = 0;

	port = getport(&sin, NFS_PROGRAM, NFS_VERSION, IPPROTO_UDP);
	last_tv = tv;

	if (port == 0)
	{
		sys_msg(debug, LOG_ERR, "Can't get NFS port for %s", [myname value]);
		isDead = YES;
		return 0;
	}

	bzero((char *)&sin, sizeof(sin));
	sin.sin_family = AF_INET;
	sin.sin_addr.s_addr = address;

	tv.tv_sec = timeout / pings;
	if (tv.tv_sec == 0) tv.tv_sec = 1;
	tv.tv_usec = 0;

	s = RPC_ANYSOCK;

	cl = clntudp_create(&sin, MOUNTPROG, MOUNTVERS, tv, &s);
	if (cl == NULL)
	{
		sys_msg(debug, LOG_ERR, "Can't create MOUNTPROG client: %s",
			clnt_spcreateerror("clntudp_create"));
		return 0;
	}

	cl->cl_auth = authunix_create_default();
	mountClient = (void *)cl;

	return port;
}

- (unsigned int)getHandle:(void *)fh forFile:(String *)filename
{
	int status;
	struct timeval tv;
	char *dir;
	struct fhstatus fhs;
	CLIENT *cl;

	[self nfsPort];
	if (port == 0) return NFSERR_NXIO;
	if (mountClient == NULL) return NFSERR_NXIO;

	tv.tv_sec = timeout;
	if (tv.tv_sec == 0) tv.tv_sec = 1;
	tv.tv_usec = 0;

	dir = [filename value];
	cl = (CLIENT *)mountClient;
	status = clnt_call(cl, MOUNTPROC_MNT, xdr_dirpath, &dir,
		xdr_fhstatus, &fhs, tv);

	if (status != RPC_SUCCESS)
	{
		sys_msg(debug, LOG_ERR, "RPC mount %s:%s failed: %s",
			[myname value], [filename value], clnt_sperrno(status));
		return NFSERR_NXIO;
	}

	if (fhs.fhs_status != 0)
	{
		sys_msg(debug, LOG_ERR, "mount %s:%s - %s",
			[myname value], [filename value], mnt_strerror(fhs.fhs_status));
		return fhs.fhs_status;
	}

	bcopy(fhs.fhstatus_u.fhs_fhandle, fh, FHSIZE);
	return 0;
}

- (void)dealloc
{
	if (mountClient != NULL) clnt_destroy((CLIENT *)mountClient);
	[super dealloc];
}

@end
