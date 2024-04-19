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
/*	LDAPAgent.m
	LDAP agent main implementation
	Copyright (C) 1997 Luke Howard. All rights reserved.
	Luke Howard, March 1997.
 */


#define AGENT	self

#import <assert.h>

#import <string.h>
#import <stdlib.h>
#import <sys/param.h>
#import <sys/signal.h>
#import <mach/mach.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

#if NS_TARGET_MAJOR == 3
#import <foundation/NSLock.h>
#else
#import <Foundation/NSLock.h>
#endif

#ifdef OIDTABLE
#if NS_TARGET_MAJOR == 3
#import <foundation/NSDictionary.h>
#else
#import <Foundation/NSDictionary.h>
#endif 
#endif OIDTABLE

#import "Controller.h"
#import "Syslog.h"
#import "LUPrivate.h"
#import "stringops.h"
#import "DNSAgent.h"
#import "FFParser.h"

#import "LDAPAgent.h"
#import "LDAPAttributes.h"
#import "LUArray+LDAP.h"
#ifdef OIDTABLE
#import "LDAPAgent+ConfigurableSchema.h"
#else
#import "LDAPAgent+FixedSchema.h"
#endif
#define forever for (;;)

extern char *nettoa(unsigned long);

/* function to rebind after referrals */
static int do_rebind( LDAP *session, char **whop, char **credp, int *methodp, int freeit, void *arg);

static LDAPAgent *_sharedLDAPAgent = nil;

static inline char *stpcpy(char *dest, const char *src)
{
	while ((*dest++ = *src++) != '\0')
		/* Do nothing. */ ;
	return dest - 1;
}


@implementation LDAPAgent 

+ alloc
{
	char str[128];

	if (_sharedLDAPAgent != nil)
	{
		[_sharedLDAPAgent retain];
		return _sharedLDAPAgent;
	}

	_sharedLDAPAgent = [super alloc];
	_sharedLDAPAgent = [_sharedLDAPAgent init];
	if (_sharedLDAPAgent == nil)
		return nil;

	sprintf(str, "Allocated LDAPAgent 0x%x\n", (int)_sharedLDAPAgent);
	[lookupLog syslogDebug:str];

	return _sharedLDAPAgent;
}

- init
{
	int lstatus;

	if (didInit)
		return self;

	[super init];

	rebindTries = 0;
	sleepTime = 0;
	memset(&searchBases, 0, sizeof(searchBases));

	configuration = nil;

	parser = [[FFParser alloc] init];
	threadLock = [[NSRecursiveLock alloc] init];

	if ([self getConfiguration] == NO)
	{
		[self dealloc];
		return nil;
	}

	lstatus = [self openConnection];
	switch (lstatus)
	{
		case LDAP_SUCCESS:
			break;
		case LDAP_SERVER_DOWN:
			[self rebind];
			break;
		default:
			[self dealloc];
			return nil;
			break;
	}

	[self resetStatistics];

	return self;
}

- reInit
{
	/* Marc suggested this method could be called upon receipt of a SIGHUP. */
	int lstatus;

	[self lock];

	[self closeConnection];

	if ([self getConfiguration] == NO)
	{
		[self unlock];
		return nil;
	}

	lstatus = [self openConnection];
	switch (lstatus)
	{
		case LDAP_SUCCESS:
			break;
		case LDAP_SERVER_DOWN:
			[self rebind];
			break;
		default:
			[self unlock];
			return nil;
			break;
	}

	[self resetStatistics];
	[self unlock];

	return self;
}

- (BOOL)getConfiguration
{
#ifdef OIDTABLE
	if ([self loadSchema] == NO)
	{
		return NO;
	}
#endif

	if (configuration != nil)
	{
		[configuration release];
	}
	
	/*
	 * Ask the controller for the configuration, which may look in
	 * NetInfo and flat files.
	 */
	
	configuration = [controller configurationForAgent:"LDAPAgent"];

	/*
	 * If the controller doesn't return anything, look at the DNS
	 * SRV record for _ldap._tcp.
	 */
	if (configuration == nil)
		configuration = [self getDNSConfiguration];

	/*
	 * If DNS didn't return anything, then punt on the server "_ldap".
	 */
	if (configuration != nil)
	{
		if ([configuration valuesForKey:CONFIG_KEY_LDAPHOST] == NULL)
		{
			[lookupLog syslogError:"LDAPAgent: a value for the configuration key "
				CONFIG_KEY_LDAPHOST" is required"];
			return NO;
		}
	}
	else
	{
		configuration = [[LUDictionary alloc] init];
		[configuration setValue:"ldap" forKey:CONFIG_KEY_LDAPHOST];
	}

	bindName = [configuration valueForKey:CONFIG_KEY_BINDDN];
	bindCredentials = [configuration valueForKey:CONFIG_KEY_BINDPW];

	timelimit = [controller config:configuration int:CONFIG_KEY_TIMELIMIT default:0];
	port = [controller config:configuration int:CONFIG_KEY_PORT default:LDAP_PORT];

	deref = [self config:configuration deref:CONFIG_KEY_DEREF default:LDAP_DEREF_NEVER];
	scope = [self config:configuration scope:CONFIG_KEY_SCOPE default:LDAP_SCOPE_SUBTREE];

	[self initValidationLatency];
	[self initSearchBases];
	[self initSchema];
	
	return YES;
}

- (int)config:(LUDictionary *)dict deref:(char *)key default:(int)def
{
	char *sDeref;

	if (dict == nil) return def;
	sDeref = [dict valueForKey:key];
	if (sDeref == NULL) return def;

	if (streq(sDeref, "never") || streq(sDeref, "NEVER"))
	{
		deref = LDAP_DEREF_NEVER;
	}
	else if (streq(sDeref, "search") || streq(sDeref, "SEARCH"))
	{
		deref = LDAP_DEREF_SEARCHING;
	}
	else if (streq(sDeref, "find") || streq(sDeref, "FIND"))
	{
		deref = LDAP_DEREF_FINDING;
	}
	else if (streq(sDeref, "always") || streq(sDeref, "ALWAYS"))
	{
		deref = LDAP_DEREF_ALWAYS;
	}
	else
	{
		deref = def;
	}
	
	return deref;
}

- (int)config:(LUDictionary *)dict scope:(char *)key default:(int)def
{
	int searchScope;
	char *sScope;
	
	if (dict == nil) return def;
	sScope = [dict valueForKey:key];
	if (sScope == NULL) return def;

	if (streq(sScope, "sub") || streq(sScope, "SUB"))
	{
		searchScope = LDAP_SCOPE_SUBTREE;
	}
	else if (streq(sScope, "one") || streq(sScope, "ONE"))
	{
		searchScope = LDAP_SCOPE_ONELEVEL;
	}
	else if (streq(sScope, "base") || streq(sScope, "BASE"))
	{
		searchScope = LDAP_SCOPE_BASE;
	}
	else
	{
		searchScope = def;
	}
	
	return searchScope;
}

- (BOOL)isValid:(LUDictionary *)item
{
	/*
	 * see draft-ietf-asid-cache-01.txt, Howes & Howard for information
	 * on the ttl attribute and cache validation in general.
         */
	time_t ttl;
	time_t age, fetchTime;
	BOOL isValid;
	
	if (item == nil)
		return NO;
		
	fetchTime = [item unsignedLongForKey:"_lookup_LDAP_timestamp"];
	ttl = [item unsignedLongForKey:"_lookup_LDAP_time_to_live"];
	age = time(0) - fetchTime;
	
	/*
	 * cache validate heuristics. We honour TTL over modifyTimestamp as it's
	 * less expensive.
	 */
	if (ttl > 0)
	{
		if (age < ttl)
			isValid = YES;
		else
			isValid = NO;
	}
	else if (age < validationLatency)
	{
		isValid = YES;
	}
	else
	{
		unsigned long currentStamp, itemStamp;
		
		itemStamp = [item unsignedLongForKey:"_lookup_LDAP_modify_timestamp"];
	
		if (itemStamp == 0)
		{
			/* 
			 * This server isn't keeping modify timestamps. Let's just
			 * assume the entry isn't valid.
			 */
			 isValid = NO;
		}
		else
		{
			/*
			 * Fetch the current modify timestamp for the entry. 
			 */
			currentStamp = [self currentModifyTimestampForEntry:item];
				
			if (currentStamp > itemStamp)
				isValid = NO;
			else
				isValid = YES;
		}
	}
	
	return isValid;
}

- (const char *)name
{
	return "Lightweight_Directory_Access_Protocol";
}

- (const char *)shortName
{
	return "LDAPAgent";
}

- (LUDictionary *)configuration
{
	return configuration;
}

- (LUDictionary *)statistics
{
	[statistics setValue:ldap_err2string(ldap_get_lderrno(ld, NULL, NULL)) forKey:"last_error"];
	return statistics;
}

- (void)resetStatistics
{
	char sPort[32];

	[statistics release];
	statistics = [[LUDictionary alloc] init];

	[statistics setBanner:"LDAPAgent statistics"];
	[statistics setValue:"Lightweight_Directory_Access_Protocol" forKey:"information_system"];

	sprintf(sPort, "%d", port);
	[statistics setValue:sPort forKey:CONFIG_KEY_PORT];

	[statistics setValue:(bindName != NULL && *bindName != '\0' ? bindName : "<none>") forKey:CONFIG_KEY_BINDDN];

	[statistics setValue:(defaultBase != NULL && *defaultBase != '\0' ? defaultBase : "") forKey:CONFIG_KEY_BASEDN];

	[statistics mergeKey:CONFIG_KEY_LDAPHOST from:configuration];
}

- (void)closeConnection
{
	/* 
	 * it's not essential to obtain the lock here, but it's OK
	 * for paranoia.
	 */
	[self lock];

	if (ld != NULL)
	{
		ldap_unbind(ld);
		ld = NULL;
	}

	[self unlock];
}

- (LDAP *)session
{
	assert(ld != NULL);
	return ld;
}

- (void)dealloc
{
	int i;
	char str[128];
	
	[statistics release];
	statistics = nil;

	[parser release];
	parser = nil;

	[self closeConnection];

	[configuration release];
	configuration = nil;

	[threadLock release];
	threadLock = nil;
	
	for (i = 0; i < NCATEGORIES; i++)
	{
		if (searchBases[i] != NULL)
			free(searchBases[i]);
	}

#ifdef OIDTABLE
	[self releaseSchema];
#endif

        sprintf(str, "Deallocated LDAPAgent 0x%x\n", (int)self);
        [lookupLog syslogDebug:str];

	[super dealloc];

	_sharedLDAPAgent = nil;
}

- (int)openConnection
{
	int lstatus;
	char *ldaphostlist = NULL;
	char **ldaphosts, **hostPtr;

	/* we don't obtain a lock here as the caller will have done so for us. 
	 * we only lock around the exposed entry points to LDAPAgent.
	 */
	ldaphosts = [configuration valuesForKey:CONFIG_KEY_LDAPHOST];
	for (hostPtr = ldaphosts; *hostPtr != NULL; hostPtr++)
	{
		if (ldaphostlist == NULL)
		{
			ldaphostlist = copyString(*hostPtr);
		}
		else
		{
			ldaphostlist = concatString(ldaphostlist, " ");
			ldaphostlist = concatString(ldaphostlist, *hostPtr);
		}
	}

#ifdef notdef
	ld = ldap_init(ldaphostlist, port);
#else
	ld = ldap_open(ldaphostlist, port);
#endif 

	if (ld == NULL)
	{
		[lookupLog syslogError:"LDAPAgent: couldn't open connection to LDAP server"]; 
		freeString(ldaphostlist);
		
		return LDAP_LOCAL_ERROR;
	}

	if (timelimit > 0)
	{
		ldap_set_option(ld, LDAP_OPT_TIMELIMIT, (void *)&timelimit);
	}

	ldap_set_option(ld, LDAP_OPT_DEREF, (void *)&deref);
	ldap_set_rebind_proc(ld, do_rebind, (void *)self);

	lstatus = ldap_simple_bind_s(ld, bindName, bindCredentials);
	if (lstatus != LDAP_SUCCESS)
	{
		[lookupLog syslogError:"LDAPAgent: couldn't bind to LDAP server"];
		ldap_unbind(ld);
		free(ldaphostlist);
		return lstatus;
	}
	timeout.tv_sec = timelimit;
	timeout.tv_usec = 0;

	freeString(ldaphostlist);
	
	return LDAP_SUCCESS;
}

- (time_t)currentModifyTimestampForEntry:(LUDictionary *)item
{
	char *attrs[2] = { NameForKey(OID_MODIFYTIMESTAMP), NULL };
	LDAPMessage *res, *e;
	time_t ret = 0;
	char **vals;
	char *dn;

	char *filter = [self filterWithClass:NULL];

	dn = [item valueForKey:"_lookup_LDAP_dn"];

	[self lock];

	res = [self search:dn filter:filter attributes:attrs sizelimit:1];

	e = ldap_first_entry(ld, res);
	if (e == NULL)
	{
		[self unlock];
		return 0;
	}	

	vals = ldap_get_values(ld, e, NameForKey(OID_MODIFYTIMESTAMP));
	if (vals == NULL)
	{
		[self unlock];
		return 0;
	}
	
	sscanf(vals[0], "%lu", &ret);

	ldap_value_free(vals);
	ldap_msgfree(res);
	free(filter);

	[self unlock];

	return ret;
}

- (LDAPMessage *)search:(char *)base
	filter:(char *)filter
	attributes:(char **)attrs
	sizelimit:(int)sizelimit
{
	LDAPMessage *res;
	int lstatus;

	/* we don't lock here as the caller will have obtained the lock */
	assert(ld != NULL);
		
	ldap_set_option(ld, LDAP_OPT_SIZELIMIT, (void *)&sizelimit);

	lstatus = ldap_search_st(
		ld,
		base,
		scope,
		filter,
		attrs,
		0,
		(timeout.tv_sec == 0) ? NULL : &timeout,
		&res);

	switch (lstatus)
	{
		case LDAP_SUCCESS:
		case LDAP_SIZELIMIT_EXCEEDED:
		case LDAP_TIMELIMIT_EXCEEDED:
			break;
		case LDAP_PARTIAL_RESULTS:
//		case LDAP_NO_RESULTS_RETURNED:
//		case LDAP_REFERRAL:
			return NULL;
		case LDAP_SERVER_DOWN:
			/* attempt to rebind */
			[self rebind];
			return [self search:base filter:filter attributes:attrs sizelimit:sizelimit];
			break;
		default:
			[lookupLog syslogError:ldap_err2string(lstatus)];
			return NULL;
	}


	return res;
}

- (void)rebind
{
	/*
	 * These heuristics are very similar to NetInfo.
	 */

	sleepTime = LDAP_SLEEPTIME;
	rebindTries = 0;

	[self closeConnection];
	forever 
	{
		if (rebindTries < LDAP_MAXCONNTRIES)
		{
			[lookupLog syslogInfo:"LDAPAgent: server down, attempting to rebind"];
		}
		else
		{
			char msg[256];
			sprintf(msg, "LDAPAgent: server down, attempting to rebind "
				"(sleeping %d seconds)", sleepTime);
			if (sleepTime < LDAP_MAXSLEEPTIME)
				{
				sleepTime *= 2;
				}
			[lookupLog syslogInfo:msg];
			/* thread_switch() should avoid blocking other threads. */
			thread_switch(THREAD_NULL, SWITCH_OPTION_WAIT, sleepTime * 1000);
		}
		rebindTries++;

		if ([self openConnection] == LDAP_SUCCESS)
		{
			[lookupLog syslogInfo:"LDAPAgent: rebound to server"];
			return;
		}
	}
	/* not reached */
	return;
}

- (void)lock
{
	[threadLock lock];
}

- (void)unlock
{
	[threadLock unlock];
}

- (void)initSearchBases
{
	int i;
	LUDictionary *config;
	
	for (i = 0; i < NCATEGORIES; i++)
	{
		config = [controller configurationForAgent:"LDAPAgent" category:i];
		if (config != nil)
		{
			char *b;
			b = [config valueForKey:CONFIG_KEY_BASEDN];
			
			if (searchBases[i] != NULL)
				free(searchBases[i]);
				
			if (b != NULL)
				searchBases[i] = copyString(b);
				
			[config release];	
		}
	}

	defaultBase = [configuration valueForKey:CONFIG_KEY_BASEDN];
}

- (char *)searchBaseForCategory:(LUCategory)cat
{
	char *searchBase;
	
	searchBase = searchBases[cat];
	if (searchBase == NULL)
		searchBase = defaultBase;
	
	return searchBase;
}

- (void)initValidationLatency
{
	BOOL globalHasAge;
	BOOL agentHasAge;
	time_t agentAge;
	time_t globalAge;
	LUDictionary *config;
	
	agentAge = 0;
	agentHasAge = NO;
	if ([configuration valueForKey:CONFIG_KEY_LATENCY] != NULL)
	{
		agentAge = [configuration unsignedLongForKey:CONFIG_KEY_LATENCY];
		agentHasAge = YES;
	}

	globalAge = 0;
	globalHasAge = NO;
	config = [controller configurationForAgent:NULL];
	if (config != nil)
	{
		if ([config valueForKey:CONFIG_KEY_LATENCY] != NULL)
		{
			globalAge = [config unsignedLongForKey:CONFIG_KEY_LATENCY];
			globalHasAge = YES;
		}
		[config release];
	}

	validationLatency = LDAP_DEFAULT_LATENCY;

	if (agentHasAge) validationLatency = agentAge;
	else if (globalHasAge) validationLatency = globalAge;
	
	return;
}


- (LUDictionary *)itemWithAttribute:(oid_name_t)aKey
	value:(char *)aVal
	category:(LUCategory)cat
{
	LUDictionary *item;
	oid_name_t k[2];
	char *v[2];

	k[0] = aKey;
	k[1] = NULL;
	
	v[0] = aVal;
	v[1] = NULL;
	
	item = [self itemWithAttributes:k values:v category:(LUCategory)cat];

	return item;
}

- (char *)filterWithClass:(char *)clazz
{
	return [self filterWithClass:clazz attributes:NULL values:NULL];
}

- (char *)filterWithClass:(char *)clazz
	attributes:(oid_name_t *)attributes
	values:(char **)values
{
	/*
	 * We do a first pass to allocate the memory to avoid repeated
	 * calls to realloc().
	 */
	 
	char *filter;
	oid_name_t *aptr;
	char **vptr;
	register int len;
	
	/* (objectclass= */
	len = 1 + strlen(NameForKey(OID_OBJECTCLASS)) + 1;

	if (clazz == NULL)
		clazz = "*";
			
	/* clazz) */
	len += strlen(clazz) + 1;
	
	if (attributes != NULL)
	{
		/* (&) */
		len += 3;
		
		for (	aptr = attributes, vptr = values;
			*aptr != NULL;
			aptr++, vptr++)
		{
			/* (attribute=value) */
			len += 1 + strlen(NameForKey(*aptr)) + 1 + strlen(*vptr) + 1;
		}	
	}
	
	filter = (char *)malloc(len + 1); /* \0 */
	assert(filter != NULL);
	
	if (attributes == NULL)
	{
		sprintf(filter, "(%s=%s)", NameForKey(OID_OBJECTCLASS), clazz);
	}
	else
	{
		register char *cp;
		
		cp = stpcpy(filter, "(&(");
		cp = stpcpy(cp, NameForKey(OID_OBJECTCLASS));
		cp = stpcpy(cp, "=");
		cp = stpcpy(cp, clazz);
		cp = stpcpy(cp, ")");
				
		for (	aptr = attributes, vptr = values;
			*aptr != NULL;
			aptr++, vptr++)
		{
			cp = stpcpy(cp, "(");
			cp = stpcpy(cp, NameForKey(*aptr));
			cp = stpcpy(cp, "=");
			cp = stpcpy(cp, *vptr);
			cp = stpcpy(cp, ")");
		}
		(void) stpcpy(cp, ")");
	}
	
	return filter;	
}

- (LUDictionary *)itemWithAttributes:(oid_name_t *)aKey
	values:(char **)aVal
	category:(LUCategory)cat
{
	char *filter;
	LUArray *a;
	LUDictionary *d = nil;
	LDAPMessage *res;
	char *base;
	
	filter = [self filterWithClass:nisClasses[cat]
		attributes:aKey
		values:aVal];
	
	base = [self searchBaseForCategory:cat];
	
	[self lock];
	
	res = [self search:base filter:filter attributes:nisAttributes[cat] sizelimit:1];
	a = [[LUArray alloc] initWithLDAPEntry:res agent:self category:cat stamp:NO];
	
	if (a != nil)
	{
		d = [[a objectAtIndex:0] retain];
		[a release];
	}

	[self unlock];
	
	free(filter);
	
	return d;
}

- (LUArray *)allItemsWithCategory:(LUCategory)cat
{
	char *filter;
	LUArray *a;
	LDAPMessage *res;
	char *base;
	
	filter = [self filterWithClass:nisClasses[cat]
		attributes:NULL
		values:NULL];
	base = [self searchBaseForCategory:cat];
	
	[self lock];
	
	res = [self search:base filter:filter attributes:nisAttributes[cat] sizelimit:LDAP_NO_LIMIT];
	a = [[LUArray alloc] initWithLDAPEntry:res agent:self category:cat stamp:YES];

	[self unlock];

	free(filter);
	
	return a;
}

- (LUDictionary *)getDNSConfiguration
{
	/*
	 * At the moment there is a substantial requirement that DNS
	 * be running and maintained with information about LDAP
	 * servers.
	 */

	LUDictionary *config;
	DNSAgent *dnsAgent;
	LUDictionary *srvRecords;
	char *domain;
	char **servers, **ports;
	char **pServer, **pPort;
	char *dn;
	
	dnsAgent = [[DNSAgent alloc] init];

	srvRecords = [dnsAgent hostsWithService:"_ldap" protocol:"_tcp"];
	
	domain = [srvRecords valueForKey:"_lookup_domain"];
	servers = [srvRecords valuesForKey:"target"];
	ports = [srvRecords valuesForKey:"port"];

	if (domain == NULL || servers == NULL || ports == NULL)
	{
		[dnsAgent release];
		[srvRecords release];
		return nil;
	}

	dn = [self dnsDomainToDn:domain];
	if (dn == NULL)
	{
		[dnsAgent release];
		[srvRecords release];
		return nil;
	}
	
	config = [[LUDictionary alloc] init];
	
	pServer = servers;

	for (pPort = ports; *pPort != NULL; pPort++)
	{
		char *hostport;
		
		hostport = copyString(*pServer);
		hostport = concatString(hostport, ":");
		hostport = concatString(hostport, *pPort);

		[config mergeValue:hostport forKey:CONFIG_KEY_LDAPHOST];

		freeString(hostport);

		pServer++;
	}

	[config setValue:dn forKey:CONFIG_KEY_BASEDN];

	[srvRecords release];
	[dnsAgent release];
	freeString(dn);

	return config;
}

- (char *)dnsDomainToDn:(char *)domain
{
	char **exploded_domain;
	char **p;
	char *dn = NULL;
	
	exploded_domain = explode(domain, '.');
	if (exploded_domain == NULL)
		return NULL;

	for (p = exploded_domain; *p != NULL; p++)
	{
		if (dn == NULL)
		{
			// dc=
			dn = copyString("dc=");
		}
		else
		{
			// ,dc=
			dn = concatString(dn, ",dc=");
		}

		dn = concatString(dn, *p);
	}

	freeList(exploded_domain);
	
	return dn;
}

/*
 * dynamically bind attributes and class names to their meanings (denoted
 * canonically by their OIDs).
 *
 * The file oidtable.plist is placed in /usr/lib/netinfo/lookupd/LDAPAgent.bundle
 * and read on startup. This file also generates LDAPSchema.[hm], but without
 * any compile-time dependencies on the actual attribute names. genOIDs is
 * used to turn a dictionary into a set of global variables.
 *
 * By updating oidtable.plist the attributes can be changed to reflect, say,
 * organization specific policies.
 * 
 * There is a performance hit because:
 *
 *	(a) the oidtable.plist hashtable must be consulted for *every* OID
 *	    to string conversion. (we could fix this easily...)
 *
 *	(b) all attributes for an entry are fetched. Specifically, a desired
 *	    attribute list is not sent. This may have implications for LDAP
 *	    v3 servers which will not return operational attributes used
 *	    here for cache validation. You need to #define LDAPV3 for this.
 *
 * The performance hit for (a) seems to be negligble.
 *
 * Otherwise:
 *
 * We figure the schema is unlikely to change much (after all, it was written
 * by the author, and is on its way to becoming an RFC) and so, like the NetInfo
 * C library, we hard code attribute/class names and the corresponding filters
 * into the agent. We also optimize a little but storing an array of only the
 * required attributes to be fetched on each LDAP search. This is the author's
 * preferred solution.
 */	

/*
 * Users
 */
 
- (LUDictionary *)userWithName:(char *)name
{
	return [self itemWithAttribute:OID_UID value:name category:LUCategoryUser];
}

- (LUDictionary *)userWithNumber:(int *)number
{
	char str[32];

	sprintf(str, "%d", *number);
	return [self itemWithAttribute:OID_UIDNUMBER value:str category:LUCategoryUser];
}

- (LUArray *)allUsers
{
	return [self allItemsWithCategory:LUCategoryUser];
}

/*
 * Groups
 */

- (LUDictionary *)groupWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryGroup];
}

- (LUDictionary *)groupWithNumber:(int *)number
{
	char str[32];

	sprintf(str, "%d", *number);
	return [self itemWithAttribute:OID_GIDNUMBER value:str
		category:LUCategoryGroup];
}

- (LUArray *)allGroups
{
	return [self allItemsWithCategory:LUCategoryGroup];
}

- (LUArray *)allGroupsWithUser:(char *)name
{
	LUArray *allWithUser = nil;
	LUDictionary *user;
	char *filter, *v[2];
	oid_name_t k[2];
	LDAPMessage *res;
	char *base;

	/*
	 * lookup the groups with the user
	 */
	k[0] = OID_MEMBERUID;
	k[1] = NULL;

	v[0] = name;
	v[1] = NULL;

	filter = [self filterWithClass:nisClasses[LUCategoryGroup]
		attributes:k values:v];
	base = [self searchBaseForCategory:LUCategoryGroup];

	[self lock];
	
	res = [self search:base filter:filter attributes:nisAttributes[LUCategoryGroup] sizelimit:LDAP_NO_LIMIT];
	allWithUser = [[LUArray alloc] initWithLDAPEntry:res agent:self category:LUCategoryGroup
stamp:YES];
			
	free(filter);
	[self unlock];

	/*
	 * lookup the user with the group. Do we really need to do this?
	 * After all, initgroups() gets passed the base GID. But it's
	 * not federated over multiple nameservices, so perhaps this is
	 * a good thing.
	 */
	user = [self userWithName:name];
	if (user != nil)
	{
		char **vals = [user valuesForKey:"gid"];
		if (vals != NULL)
		{
			LUDictionary *group;
			int nvals = [user countForKey:"gid"];
			
			if (nvals < 0) nvals = 0;

			group = [self itemWithAttribute:OID_GIDNUMBER value:vals[0]
					category:LUCategoryGroup];

			if (group != nil)
			{
				if (allWithUser == nil)
				{
					allWithUser = [[LUArray alloc] init];
				}
				
				if ([allWithUser containsObject:group] == NO)
				{
					LUDictionary *vstamp;

					/* copy over the validation data */
					vstamp = [[LUDictionary alloc] init];
					[vstamp setBanner:"LDAPAgent validation stamp"];
					[vstamp setValue:"LDAP" forKey:"_lookup_info_system"];
					[vstamp mergeKey:"_lookup_LDAP_timestamp" from:group];
					[vstamp mergeKey:"_lookup_LDAP_time_to_live" from:group];
					[vstamp mergeKey:"_lookup_LDAP_dn" from:group];
					[vstamp mergeKey:"_lookup_LDAP_modify_timestamp" from:group];
						
					[allWithUser addValidationStamp:vstamp];
					[vstamp release];
					
					[allWithUser addObject:group];
				}
				[group release];
			}
		}
		[user release];
	}

	if (allWithUser != nil && [allWithUser count] == 0)
	{
		[allWithUser release];
		allWithUser = nil;
	}

	return allWithUser;	
}

/*
 * Hosts
 */

- (LUDictionary *)hostWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryHost];
}

- (LUDictionary *)hostWithInternetAddress:(struct in_addr *)addr
{
	char str[32];

	/* definitely not MP safe. Maybe not threadsafe. */
	sprintf(str, "%s", inet_ntoa(*addr));
	return [self itemWithAttribute:OID_IPHOSTNUMBER value:str
		category:LUCategoryHost];
}

- (LUDictionary *)hostWithEthernetAddress:(struct ether_addr *)addr
{
	/*
	 * The schema specifies the canonical Ethernet address as the
	 * only one permitted, however we can be lax.
	 */
	char **etherAddrs = NULL;
	LUDictionary *ether;
	int i, len;

	/* Try all possible variations on leading zeros in the address */
	etherAddrs = [self variationsOfEthernetAddress:addr];
	len = listLength(etherAddrs);
	for (i = 0; i < len; i++)
	{
		ether = [self itemWithAttribute:OID_MACADDRESS value:etherAddrs[i]
			category:LUCategoryEthernet];

		if (ether != nil)
		{
			freeList(etherAddrs);
			etherAddrs = NULL;
			return ether;
		}
	}
	freeList(etherAddrs);
	etherAddrs = NULL;
	return nil;
}

- (LUArray *)allHosts
{
	return [self allItemsWithCategory:LUCategoryHost];
}

/*
 * Networks
 */

- (LUDictionary *)networkWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryNetwork];
}

- (LUDictionary *)networkWithInternetAddress:(struct in_addr *)addr
{
	char str[32];

	sprintf(str, "%s", nettoa(addr->s_addr));
	return [self itemWithAttribute:OID_IPNETWORKNUMBER value:str
		category:LUCategoryNetwork];
}

- (LUArray *)allNetworks
{
	return [self allItemsWithCategory:LUCategoryNetwork];
}

/*
 * Services
 */

- (LUDictionary *)serviceWithName:(char *)name
        protocol:(char *)prot
{
	LUDictionary *item;
	oid_name_t k[3];
	char *v[3];
		
	k[0] = OID_CN;
	k[1] = (prot == NULL) ? NULL : OID_IPSERVICEPROTOCOL;
	k[2] = NULL;
	
	v[0] = name;
	v[1] = prot;
	v[2] = NULL;
	
	item = [self itemWithAttributes:k values:v
		category:LUCategoryService];

	return item;
}

- (LUDictionary *)serviceWithNumber:(int *)number
        protocol:(char *)prot
{
	LUDictionary *item;
	char str[32];
	oid_name_t k[3];
	char *v[3];
	
	sprintf(str, "%d", *number);
	
	k[0] = OID_IPSERVICEPORT;
	k[1] = (prot == NULL) ? NULL : OID_IPSERVICEPROTOCOL;
	k[2] = NULL;
	
	v[0] = str;
	v[1] = prot;
	v[2] = NULL;
	
	item = [self itemWithAttributes:k values:v
		category:LUCategoryService];
	
	return item;
}

- (LUArray *)allServices
{
	return [self allItemsWithCategory:LUCategoryService];
}

/*
 * Protocols
 */
- (LUDictionary *)protocolWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryProtocol];
}

- (LUDictionary *)protocolWithNumber:(int *)number
{
	char str[32];

	sprintf(str, "%d", *number);
	return [self itemWithAttribute:OID_IPPROTOCOLNUMBER value:str
		category:LUCategoryProtocol];
}

- (LUArray *)allProtocols 
{
	return [self allItemsWithCategory:LUCategoryProtocol];
}

- (LUDictionary *)rpcWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryRpc];
}

- (LUDictionary *)rpcWithNumber:(int *)number
{
	char str[32];

	sprintf(str, "%d", *number);
	return [self itemWithAttribute:OID_ONCRPCNUMBER value:str
		category:LUCategoryRpc];
}

- (LUArray *)allRpcs
{
	return [self allItemsWithCategory:LUCategoryRpc];
}


- (LUDictionary *)mountWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryMount];
}

- (LUArray *)allMounts
{
	return [self allItemsWithCategory:LUCategoryMount];
}

- (LUDictionary *)printerWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryPrinter ];
}

- (LUArray *)allPrinters
{
	return [self allItemsWithCategory:LUCategoryPrinter];
}

- (LUDictionary *)bootparamsWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryBootparam];
}

- (LUArray *)allBootparams
{
	return [self allItemsWithCategory:LUCategoryBootparam];
}


- (LUDictionary *)bootpWithInternetAddress:(struct in_addr *)addr
{
	char str[32];

	sprintf(str, "%s", nettoa(addr->s_addr));
	return [self itemWithAttribute:OID_IPHOSTNUMBER value:str
		category:LUCategoryBootp];
}

- (LUDictionary *)bootpWithEthernetAddress:(struct ether_addr *)addr
{
	char **etherAddrs = NULL;
	LUDictionary *bootp;
	int i, len;

	/* Try all possible variations on leading zeros in the address */
	etherAddrs = [self variationsOfEthernetAddress:addr];
	len = listLength(etherAddrs);
	for (i = 0; i < len; i++)
	{
		bootp = [self itemWithAttribute:OID_MACADDRESS value:etherAddrs[i]
			category:LUCategoryBootp];

		if (bootp != nil)
		{
			freeList(etherAddrs);
			etherAddrs = NULL;
			return bootp;
		}
	}
	freeList(etherAddrs);
	etherAddrs = NULL;
	return nil;
}

- (LUDictionary *)aliasWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryAlias];
}

- (LUArray *)allAliases
{
	return [self allItemsWithCategory:LUCategoryAlias];
}

- (LUDictionary *)netgroupWithName:(char *)name
{
	return [self itemWithAttribute:OID_CN value:name
		category:LUCategoryNetgroup];
}

- (LUArray *)allNetgroups
{
	return [self allItemsWithCategory:LUCategoryNetgroup];
}

- (BOOL)inNetgroup:(char *)group
        host:(char *)host
        user:(char *)user
        domain:(char *)domain
{
	LUDictionary *ng;
	BOOL bRes = NO;

	ng = [self netgroupWithName:group];
	if (ng != nil &&
		[ng hasValue:host forKey:"hosts"] &&
		[ng hasValue:user forKey:"users"] &&
		[ng hasValue:domain forKey:"domains"])
	{
		bRes = YES;
	}
	[ng release];
	return bRes;
}

@end

/* rebinding after a referral ensures that credentials are passed onto
 * other servers. This is not related to the rebinding we implement
 * after an LDAP server crashes.
 */
static int do_rebind( LDAP *session, char **whop, char **credp, int *methodp, int freeit, void *arg)
{
	LUDictionary *configuration;
	LDAPAgent *agent = (LDAPAgent *)arg;

	/*
	 * We don't retain the agent because agents are never destroyed.
	 */
	configuration = [agent configuration];

	*whop = [configuration valueForKey:CONFIG_KEY_BINDDN];
	*credp = [configuration valueForKey:CONFIG_KEY_BINDPW];
	*methodp = LDAP_AUTH_SIMPLE;

	return LDAP_SUCCESS;
}

