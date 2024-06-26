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
 * system routine definitions
 * Copyright (C) 1989 by NeXT, Inc.
 */
#include <syslog.h>

#ifndef NULL
#define NULL ((void *)0)
#endif

#define DEBUG_NONE 0
#define DEBUG_STDERR 1
#define DEBUG_SYSLOG 2
#define DEBUG_ALL (DEBUG_STDERR & DEBUG_SYSLOG)

char *sys_hostname(void);
unsigned long sys_address(void);
unsigned long sys_netmask(void);
int sys_ismyaddress(unsigned long);

void sys_msg(int, int, char *, ...);
void sys_openlog(char *, int, int);
int sys_standalone(void);
int sys_spawn(const char *, ...);
long sys_time(void);

int setsid(void);
int daemon(int nochdir, int noclose);