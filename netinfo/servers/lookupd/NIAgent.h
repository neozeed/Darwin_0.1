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
	NIAgent.h

	NetInfo lookup agent for lookupd
	
	Copyright (c) 1995, NeXT Computer Inc.
	All rights reserved.
 */

#import "LUDictionary.h"
#import "LUArray.h"
#import "LUAgent.h"
#import "LUNIDomain.h"
#import "LUGlobal.h"

#if NS_TARGET_MAJOR == 3
#import <foundation/NSLock.h>
#import <foundation/NSArray.h>
#else
#import <Foundation/NSArray.h>
#import <Foundation/NSLock.h>
#endif

@interface NIAgent : LUAgent
{
	LUDictionary *stats;
	NSMutableArray *globalChain;
	NSMutableArray *chain[NCATEGORIES];
	NSRecursiveLock *threadLock;
}

+ (LUNIDomain *)domainWithName:(char *)domainName;
+ (NIAgent *)reallyAlloc;

- (NIAgent *)initWithLocalHierarchy;

- (BOOL)isSecurityEnabledForOption:(char *)option;
- (BOOL)isNetwareEnabled;

- (LUNIDomain *)domainAtIndex:(unsigned int)where;

@end

