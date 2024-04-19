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
	LUDictionary.m
	
	Copyright (c) 1995, NeXT Computer Inc.
	All rights reserved.
	Written by Marc Majka
 */

#import "LUDictionary.h"
#import "LUAgent.h"
#import "nilib2.h"
#import "stringops.h"
#import <stdlib.h>
#import <sys/types.h>
#import <sys/time.h>

typedef struct {
	LUCategory cat;
	time_t ttl;
	struct timeval access;
	unsigned int hits;
} _private_data;


@implementation LUDictionary

- (void)setBanner:(char *)str
{
	if (banner != NULL) freeString(banner);
	banner = NULL;
	if (str != NULL) banner = copyString(str);
}

- (char *)banner
{
	return banner;
}

- (LUDictionary *)init
{
	char str[64];

	[super init];
	count = 0;
	prop = (lu_property *)malloc(sizeof(lu_property) * (count + 1));
	agent = nil;
	retainCount = 1;
	_data = (void *)malloc(sizeof(_private_data));

	((_private_data *)_data)->cat = LUCategoryNull;
	((_private_data *)_data)->ttl = 0;
	((_private_data *)_data)->hits = 0;

	sprintf(str, "D-0x%x", (int)self);
	banner = copyString(str);

	negative = NO;

	gettimeofday(&(((_private_data *)_data)->access), (struct timezone *)NULL);

	return self;
}

- (void)setCategory:(LUCategory)category
{
	((_private_data *)_data)->cat = category;
}

- (LUCategory)category
{
	return ((_private_data *)_data)->cat;
}

- (BOOL)isEqual:(LUDictionary *)dict
{
	int i, j, alen, blen;
	char **avals, **bvals;

	if (![dict isMemberOfClass:[LUDictionary class]]) return NO;

	if (self == dict) return YES;

	if (count != [dict count]) return NO;

	for (i = 0; i < count; i++)
	{
		if (strcmp(prop[i].key, [dict keyAtIndex:i])) return NO;
		alen = prop[i].len;
		blen = [dict countAtIndex:i];

		if (alen != blen) return NO;

		avals = prop[i].val;
		bvals = [dict valuesAtIndex:i];

		for (j = 0; j < alen; j++) if (strcmp(avals[j], bvals[j])) return NO;
	}

	return YES;
}

- (unsigned int)cacheHits
{
	return ((_private_data *)_data)->hits;
}

- (void)setCacheHits:(unsigned int)n
{
	((_private_data *)_data)->hits = n;
}

- (unsigned int)cacheHit
{
	return ((_private_data *)_data)->hits++;
}

- (time_t)timeToLive
{
	return ((_private_data *)_data)->ttl;
}

- (void)setTimeToLive:(time_t)seconds
{
	((_private_data *)_data)->ttl = seconds;
}

- (void)setNegative:(BOOL)neg
{
	negative = neg;
}

- (BOOL)isNegative
{
	return negative;
}

- (unsigned int)retainCount
{
	return retainCount;
}

- retain
{
	retainCount++;
	return self;
}

- (void)release
{
	retainCount--;
	if (retainCount == 0) [self dealloc];
}

- (void)dealloc
{
	int i;

	for (i = 0; i < count; i++)
	{
		freeList(prop[i].val);
		prop[i].val = NULL;
		freeString(prop[i].key);
		prop[i].key = NULL;
		prop[i].len = 0;
	}
	if (prop != NULL) free(prop);
	prop = NULL;

	agent = nil;
	free(_data);
	freeString(banner);
	banner = NULL;

	[super dealloc];
}

- (void)setAgent:(id)source
{
	if (source == nil) return;
	agent = source;
}

- (id)agent
{
	return agent;
}

- (unsigned int)indexForKey:(char *)key
{
	unsigned int top, bot, mid, range;
	int comp;

	if (count == 0) return IndexNull;
	top = count - 1;
	bot = 0;
	mid = top / 2;

	range = top - bot;
	while (range > 1)
	{
		comp = strcmp(key, prop[mid].key);
		if (comp == 0) return mid;
		else if (comp < 0) top = mid;
		else bot = mid;

		range = top - bot;
		mid = bot + (range / 2);
	}

	if (strcmp(key, prop[top].key) == 0) return top;
	if (strcmp(key, prop[bot].key) == 0) return bot;
	return IndexNull;
}

- (unsigned int)addKey:(char *)key
{
	unsigned int top, bot, mid, range;
	int comp, i;

	if (count == 0)
	{
		count++;
		prop = (lu_property *)realloc(prop, sizeof(lu_property) * (count + 1));
		prop[0].key = copyString(key);
		prop[0].val = (char **)malloc(sizeof(char *));
		prop[0].val[0] = NULL;
		prop[0].len = 0;
		return 0;
	}

	top = count - 1;
	bot = 0;
	mid = top / 2;

	range = top - bot;
	while (range > 1)
	{
		comp = strcmp(key, prop[mid].key);
		if (comp == 0) return mid;
		else if (comp < 0) top = mid;
		else bot = mid;

		range = top - bot;
		mid = bot + (range / 2);
	}

	if (strcmp(key, prop[top].key) == 0) return top;
	if (strcmp(key, prop[bot].key) == 0) return bot;

	if (strcmp(key, prop[bot].key) < 0) mid = bot;
	else if (strcmp(key, prop[top].key) > 0) mid = top + 1;
	else mid = top;

	count++;
	prop = (lu_property *)realloc(prop, sizeof(lu_property) * (count + 1));
	for (i = count; i > mid; i--) prop[i] = prop[i - 1];
	prop[mid].key = copyString(key);
	prop[mid].val = (char **)malloc(sizeof(char *));
	prop[mid].val[0] = NULL;
	prop[mid].len = 0;

	return mid;
}

- (char *)keyAtIndex:(unsigned int)where
{
	if (where == IndexNull) return NULL;
	if (where >= count) return NULL;
	return prop[where].key;
}

- (unsigned int)count
{
	return count;
}

- (void)setValue:(char *)val forKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;

	where = [self addKey:key];

	if (val == NULL) return;
	[self setValue:val atIndex:where];
}

- (void)setValue:(char *)val atIndex:(unsigned int)where
{
	if (where == IndexNull) return;
	if (where >= count) return;

	if (prop[where].len == 1)
	{
		if (val == NULL)
		{
			[self removeValuesAtIndex:where];
			return;
		}
		free(prop[where].val[0]);
		prop[where].val[0] = copyString(val);
		return;
	}

	[self removeValuesAtIndex:where];
	[self addValue:val atIndex:where];
}
	
- (void)setValues:(char **)vals forKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;
	
	where = [self addKey:key];

	[self setValues:vals atIndex:where];
}

- (void)setValues:(char **)vals atIndex:(unsigned int)where
{
	int i, n;

	if (where == IndexNull) return;
	if (where >= count) return;

	n = prop[where].len;
	[self removeValuesAtIndex:where];

	if (vals == NULL) return;

	free(prop[where].val);
	for (n = 0; vals[n] != NULL; n++);
	prop[where].val = (char **)malloc((n + 1) * sizeof(char *));
	for (i = 0; i < n; i++) prop[where].val[i] = copyString(vals[i]);
	prop[where].val[n] = NULL;

	prop[where].len = n;
}
	
- (void)addValues:(char **)vals forKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;
	
	where = [self addKey:key];

	[self addValues:vals atIndex:where];
}

- (void)addValues:(char **)vals atIndex:(unsigned int)where
{
	int i, l, n;

	if (where == IndexNull) return;
	if (where >= count) return;
	if (vals == NULL) return;

	l = prop[where].len;
	for (n = 0; vals[n] != NULL; n++);
	prop[where].val =
		(char **)realloc(prop[where].val, sizeof(char *) * (l + n + 1));

	for (i = 0; i < n; i++) prop[where].val[l + i] = copyString(vals[i]);
	prop[where].val[l + n] = NULL;
	prop[where].len = l + n;
}
	
- (void)setValues:(char **)vals forKey:(char *)key count:(unsigned int)len
{
	unsigned int where;

	if (key == NULL) return;
	
	where = [self addKey:key];

	[self setValues:vals atIndex:where count:len];
}

- (void)setValues:(char **)vals
	atIndex:(unsigned int)where
	count:(unsigned int)len
{
	int i;

	if (where == IndexNull) return;
	if (where >= count) return;

	[self removeValuesAtIndex:where];

	if (vals == NULL) return;
	if (len == 0) return;

	free(prop[where].val);
	prop[where].val = (char **)malloc((len + 1) * sizeof(char *));
	for (i = 0; i < len; i++) prop[where].val[i] = copyString(vals[i]);
	prop[where].val[len] = NULL;
	prop[where].len = len;
}
	
- (void)addValues:(char **)vals forKey:(char *)key count:(unsigned int)len
{
	unsigned int where;

	if (key == NULL) return;
	
	where = [self addKey:key];

	[self addValues:vals atIndex:where count:len];
}

- (void)addValues:(char **)vals
	atIndex:(unsigned int)where
	count:(unsigned int)len
{
	int i, l;

	if (where == IndexNull) return;
	if (where >= count) return;
	if (vals == NULL) return;

	l = prop[where].len;
	prop[where].val =
		(char **)realloc(prop[where].val, sizeof(char *) * (l + len + 1));

	for (i = 0; i < len; i++) prop[where].val[i+l] = copyString(vals[i]);
	prop[where].val[l + len] = NULL;
	prop[where].len = l + len;
}
	
- (void)removeKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;
	
	where = [self indexForKey:key];
	[self removeIndex:where];
}

- (void)removeIndex:(unsigned int)where
{
	unsigned int i;

	if (where == IndexNull) return;
	if (where >= count) return;

	freeList(prop[where].val);
	freeString(prop[where].key);
	prop[where].key = NULL;

	for (i = where + 1; i < count; i++) prop[i - 1] = prop[i];
	count--;
	prop = (lu_property *)realloc(prop, (sizeof(lu_property) * (count + 1)));
}

- (void)addValue:(char *)val forKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;
	if (val == NULL) return;
	
	where = [self addKey:key];

	[self addValue:val atIndex:where];
}

- (void)addValue:(char *)val atIndex:(unsigned int)where
{
	int l;

	if (where == IndexNull) return;
	if (where >= count) return;
	if (val == NULL) return;

	l = prop[where].len;
	prop[where].val =
		(char **)realloc(prop[where].val, sizeof(char *) * (l + 1 + 1));

	prop[where].val[l] = copyString(val);
	prop[where].val[l + 1] = NULL;
	prop[where].len = l + 1;
}

- (void)mergeValues:(char **)vals forKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;
	
	where = [self addKey:key];

	[self mergeValues:vals atIndex:where];
}

- (void)mergeValues:(char **)vals atIndex:(unsigned int)where
{
	int i, len;

	if (vals == NULL) return;
	if (where == IndexNull) return;
	if (where >= count) return;

	len = listLength(vals);

	for (i = 0; i < len; i++)
		[self mergeValue:vals[i] atIndex:where];
}

- (void)mergeValue:(char *)val forKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;
	if (val == NULL) return;
	
	where = [self addKey:key];

	[self mergeValue:val atIndex:where];
}

- (void)mergeValue:(char *)val atIndex:(unsigned int)where
{
	int i, len;

	if (val == NULL) return;
	if (where == IndexNull) return;
	if (where >= count) return;

	len = prop[where].len;

	for (i = 0; i < len; i++)
	{
		if (strcmp(prop[where].val[i], val) == 0) return;
	}

	len = prop[where].len;
	prop[where].val =
		(char **)realloc(prop[where].val, sizeof(char *) * (len + 1 + 1));

	prop[where].val[len] = copyString(val);
	prop[where].val[len + 1] = NULL;
	prop[where].len = len + 1;
}

- (void)removeValue:(char *)val forKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return;
	if (val == NULL) return;
	
	where = [self indexForKey:key];
	[self removeValue:val atIndex:where];
}


- (void)removeValue:(char *)val atIndex:(unsigned int)where
{
	int i, n, x;

	if (val == NULL) return;
	if (where == IndexNull) return;
	if (where >= count) return;

	n = prop[where].len;
	x = -1;

	for (i = 0; i < n; i++)
	{
		if (strcmp(prop[where].val[i], val))
		{
			x = i;
			break;
		}
	}

	if (x < 0) return;

	freeString(prop[where].val[x]);
	prop[where].val[x] = NULL;

	for (i = x + 1; i < n; i++) prop[where].val[i - 1] = prop[where].val[i];
	prop[where].len--;
	n = prop[where].len;
	prop[where].val =
		(char **)realloc(prop[where].val, sizeof(char *) * (n + 1));
}

- (void)removeValuesForKey:(char *)key
{
	unsigned int where;

	where = [self indexForKey:key];
	[self removeValuesAtIndex:where];
}

- (void)removeValuesAtIndex:(unsigned int)where
{
	if (where == IndexNull) return;
	if (where >= count) return;

	if (prop[where].len > 0)
	{
		freeList(prop[where].val);
		prop[count].val = (char **)malloc(sizeof(char *));
		prop[count].val[0] = NULL;
		prop[where].len = 0;
	}
}

- (char **)valuesForKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return NULL;
	where = [self indexForKey:key];
	return [self valuesAtIndex:where];
}
	
- (char **)valuesAtIndex:(unsigned int)where
{
	if (where == IndexNull) return NULL;
	if (where >= count) return NULL;
	if (prop[where].len == 0) return NULL;
	return prop[where].val;
}

- (int)intForKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return 0;
	where = [self indexForKey:key];
	if (where == IndexNull) return 0;
	if (where >= count) return 0;
	if (prop[where].len == 0) return 0;
	if (prop[where].val[0] == NULL) return 0;
	return atoi(prop[where].val[0]);
}
	
- (unsigned long)unsignedLongForKey:(char *)key
{
	unsigned int where;
	unsigned long t;

	if (key == NULL) return 0;
	where = [self indexForKey:key];
	if (where == IndexNull) return 0;
	if (where >= count) return 0;
	if (prop[where].len == 0) return 0;
	if (prop[where].val[0] == NULL) return 0;
	sscanf(prop[where].val[0], "%lu", &t);
	return t;
}
	
- (char *)valueForKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return NULL;
	where = [self indexForKey:key];
	return [self valueAtIndex:where];
}
	
- (char *)valueAtIndex:(unsigned int)where
{
	if (where == IndexNull) return NULL;
	if (where >= count) return NULL;
	if (prop[where].len == 0) return NULL;
	return prop[where].val[0];
}

- (unsigned int)countForKey:(char *)key
{
	unsigned int where;

	if (key == NULL) return IndexNull;
	where = [self indexForKey:key];
	return [self countAtIndex:where];
}
	
- (unsigned int)countAtIndex:(unsigned int)where
{
	if (where == IndexNull) return IndexNull;
	if (where >= count) return IndexNull;
	return prop[where].len;
}

- (void)resetAge
{
	gettimeofday(&(((_private_data *)_data)->access), (struct timezone *)NULL);
}

- (time_t)age
{
	struct timeval now;	
	time_t age;

	gettimeofday(&now, (struct timezone *)NULL);

	age = now.tv_sec - ((_private_data *)_data)->access.tv_sec;
	return age;
}

- (void)print
{
	[self print:stdout];
}

- (void)print:(FILE *)f
{
	unsigned int i, j, len;
	time_t age, remaining;
	char **p;
	_private_data *pvt;

	pvt = (_private_data *)_data;

	fprintf(f, "Dictionary: \"%s\"\n", banner);
 
	for (i = 0; i < count; i++)
	{
		fprintf(f, "%s:", [self keyAtIndex:i]);
		p = [self valuesAtIndex:i];
		len = [self countAtIndex:i];
		for (j = 0; j < len; j++) fprintf(f, " %s", p[j]);
		fprintf(f, "\n");
	}

	if (pvt->cat == LUCategoryNull)
	{
		fprintf(f, "\n");
		return;
	}

	if (agent == nil)
	{
		if (pvt->cat < NCATEGORIES)
			fprintf(f, "+ Category: %u\n", (unsigned int)pvt->cat);
		else
			fprintf(f, "+ Category: ?\n");
	}
	else fprintf(f, "+ Category: %s\n", [agent categoryName:pvt->cat]);

	age = [self age];
	if (pvt->ttl == (time_t)-1)
	{
		fprintf(f, "+ Time to live: -immortal-\n");
		fprintf(f, "+ Age: %lu\n", age);
	}
	else
	{
		fprintf(f, "+ Time to live: %lu\n", pvt->ttl);

		if (age > pvt->ttl)
		{
			fprintf(f, "+ Age: %lu (expired)\n", age);
		}
		else
		{
			remaining = pvt->ttl - age;
			fprintf(f, "+ Age: %lu (expires in %lu seconds)\n",
				[self age], remaining);
		}
	}

	fprintf(f, "+ Negative: %s\n", negative ? "Yes" : "No");
	fprintf(f, "+ Cache hits: %u\n", pvt->hits);
	fprintf(f, "+ Retain count: %u\n", [self retainCount]);

	fprintf(f, "\n");
}

- (ni_proplist *)niProplist
{
	unsigned int i, j, len;
	char **p, *key;
	ni_proplist *pl;

	pl = (ni_proplist *)malloc(sizeof(ni_proplist));
	NI_INIT(pl);

	for (i = 0; i < count; i++)
	{
		if (!strncmp([self keyAtIndex:i], "_lookup", 7)) continue;

		key = [self keyAtIndex:i];
		nipl_createprop(pl, key);

		p = [self valuesAtIndex:i];
		len = [self countAtIndex:i];

		for (j = 0; j < len; j++) nipl_appendprop(pl, key, p[j]);
	}

	return pl;
}
@end
