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
	LUArray.h
	
	Copyright (c) 1995, NeXT Computer Inc.
	All rights reserved.
 */

#if NS_TARGET_MAJOR == 3
#import <foundation/NSObject.h>
#import <foundation/NSLock.h>
#else
#import <Foundation/NSObject.h>
#import <Foundation/NSLock.h>
#endif

#import <stdio.h>

@interface LUArray : NSObject
{
	id *obj;
	unsigned int retainCount;
	unsigned int count;
	id *validationStamps;
	unsigned int validationStampCount;
	char *banner;
	NSRecursiveLock *lock;
}

- (LUArray *)init;
- (void)releaseObjects;
- (void)releaseValidationStamps;

- (unsigned int)indexForObject:(id)anObject;
- (BOOL)containsObject:(id)anObject;

- (unsigned int)count;

- (void)addObject:(id)anObject;
- (void)insertObject:(id)anObject atIndex:(unsigned int)where;

- (void)removeObject:(id)anObject;
- (void)removeObjectAtIndex:(unsigned int)where;

- (void)replaceObjectAtIndex:(unsigned int)where withObject:(id)anObject;

- (id)objectAtIndex:(unsigned int)where;

- (void)addValidationStamp:(id)anObject;
- (unsigned int)validationStampCount;
- (id)validationStampAtIndex:(unsigned int)where;

- (void)setBanner:(char *)str;
- (char *)banner;

- (void)print;
- (void)print:(FILE *)f;

@end
