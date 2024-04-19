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
#import "FileMap.h"
#import "Controller.h"
#import "Vnode.h"
#import "Server.h"
#import "String.h"
#import "automount.h"
#import "log.h"
#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#import <syslog.h>
#import <sys/mount.h>

@implementation FileMap

- (void)loadMounts
{
	FILE *fp;
	char line[1024], cloc[1024], copts[1024], csrc[1024];
	String *src, *loc, *opts;
	Array *options;
	int n;

	if (dataStore == nil) return;

	fp = fopen([dataStore value], "r");
	if (fp == NULL)
	{
		sys_msg(debug, LOG_ERR, "%s: %s", [dataStore value], strerror(errno));
		return;
	}

	while (fgets(line, 1024, fp) != NULL)
	{
		n = sscanf(line, "%s %s %s", cloc, copts, csrc);
		if (n != 3)
		{
			sys_msg(debug, LOG_ERR, "Bad input line in map %s: %s",
				[dataStore value], line);
			continue;
		}

		src = [String uniqueString:csrc];
		loc = [String uniqueString:cloc];
		opts = [String uniqueString:copts];

		options = [opts explode:','];

		[self newMount:src dir:loc opts:options];

		[src release];
		[loc release];
		[opts release];
		[options release];
	}

	fclose(fp);
}

@end