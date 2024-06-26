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
	LUDictionary.h
	
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
#import "LUGlobal.h"

typedef struct {
	char *key;
	unsigned int len;
	char **val;
} lu_property;

@interface LUDictionary : NSObject
{
	id agent;
	unsigned int retainCount;
	lu_property *prop;
	unsigned int count;
	void *_data;
	char *banner;
	BOOL negative;
	NSRecursiveLock *lock;
}

- (BOOL)isEqual:(LUDictionary *)dict;

- (void)setAgent:(id)source;
- (id)agent;

- (unsigned int)indexForKey:(char *)key;
- (char *)keyAtIndex:(unsigned int)where;
- (unsigned int)count;

- (void)setValue:(char *)val forKey:(char *)key;
- (void)setValue:(char *)val atIndex:(unsigned int)where;

- (void)setValues:(char **)vals forKey:(char *)key;
- (void)setValues:(char **)vals atIndex:(unsigned int)where;

- (void)addValues:(char **)vals forKey:(char *)key;
- (void)addValues:(char **)vals atIndex:(unsigned int)where;

- (void)setValues:(char **)vals forKey:(char *)key count:(unsigned int)len;
- (void)setValues:(char **)vals
	atIndex:(unsigned int)where
	count:(unsigned int)len;

- (void)addValues:(char **)vals forKey:(char *)key count:(unsigned int)len;
- (void)addValues:(char **)vals
	atIndex:(unsigned int)where
	count:(unsigned int)len;

- (void)mergeValue:(char *)val forKey:(char *)key;
- (void)mergeValue:(char *)val atIndex:(unsigned int)where;
- (void)mergeValues:(char **)vals forKey:(char *)key;
- (void)mergeValues:(char **)vals atIndex:(unsigned int)where;

- (unsigned int)addKey:(char *)key;
- (void)mergeKey:(char *)key from:(LUDictionary *)key;
- (BOOL)hasValue:(char *)value forKey:(char *)key;

- (void)removeKey:(char *)key;
- (void)removeIndex:(unsigned int)where;

- (void)addValue:(char *)val forKey:(char *)key;
- (void)addValue:(char *)val atIndex:(unsigned int)where;

- (void)swapValuesAtIndex:(unsigned int)a
	andIndex:(unsigned int)b
	forKey:(char *)key;

- (void)swapValuesAtIndex:(unsigned int)a
	andIndex:(unsigned int)b
	atIndex:(unsigned int)where;

- (void)insertValue:(char *)val forKey:(char *)key atIndex:(unsigned int)x;
- (void)insertValue:(char *)val
	atIndex:(unsigned int)where
	atIndex:(unsigned int)x;

- (void)removeValue:(char *)val forKey:(char *)key;
- (void)removeValue:(char *)val atIndex:(unsigned int)where;

- (void)removeValuesForKey:(char *)key;
- (void)removeValuesAtIndex:(unsigned int)where;

- (char **)valuesForKey:(char *)key;
- (char **)valuesAtIndex:(unsigned int)where;

- (int)intForKey:(char *)key;
- (unsigned long)unsignedLongForKey:(char *)key;

- (char *)valueForKey:(char *)key;
- (char *)valueAtIndex:(unsigned int)where;

- (unsigned int)countForKey:(char *)key;
- (unsigned int)countAtIndex:(unsigned int)where;

- (void)setBanner:(char *)str;
- (char *)banner;

- (void)setNegative:(BOOL)neg;
- (BOOL)isNegative;

- (void)print;
- (void)print:(FILE *)f;

@end
