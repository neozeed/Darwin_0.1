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
 * interfaces.h
 * - get the list of inet interfaces in the system
 */

/*
 * Modification History
 * 02/23/98	Dieter Siegmund (dieter@apple.com)
 * - initial version
 */

#import <sys/socket.h>
#import <net/if.h>
#import <netinet/in.h>
#import <netinet/in_systm.h>
#import <netinet/ip.h>
#import <netinet/udp.h>
#import <netinet/bootp.h>
#import <net/if_arp.h>
#import <netinet/if_ether.h>
#import <net/if_dl.h>
#import <mach/boolean.h>
#import <sys/param.h>

typedef struct {
    char 		name[IFNAMSIZ + 1]; /* eg. en0 */

    boolean_t		inet_valid;
    short		flags;
    struct in_addr	addr;
    struct in_addr	mask;
    struct in_addr	netaddr;
    struct in_addr	broadcast;
    u_char		hostname[MAXHOSTNAMELEN + 1];

    boolean_t		link_valid;
    struct sockaddr_dl	link;
} interface_t;

typedef struct {
    interface_t *	list;
    int			count;
} interface_list_t;

interface_list_t * 	if_init();
interface_t * 		if_first_broadcast_inet(interface_list_t * intface);
interface_t *		if_lookupbyname(interface_list_t * intface, 
					const char * name);
interface_t *		if_lookupbylinkindex(interface_list_t * intface, 
					     int link_index);
interface_t *		if_lookupbyip(interface_list_t * intface,
				      struct in_addr iaddr);
interface_t *		if_lookupbysubnet(interface_list_t * intface, 
					  struct in_addr iaddr);
void			if_free(interface_list_t * * if_p);
