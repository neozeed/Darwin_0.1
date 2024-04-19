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
 * Lookup various things
 * Copyright (C) 1989 by NeXT, Inc.
 */
#include "ni_server.h"
#include <stdio.h>
#include <arpa/inet.h>
#include <ctype.h>
#include <string.h>
#include "ni_globals.h"
#include "getstuff.h"
#include "system.h"

#define NI_SEPARATOR '/'
#define DEFAULT_MAX_READALL_PROXIES 0	/* Feature's off by default */
#define NAME_READALL_PROXIES "readall_proxies"
#define READALL_PROXIES_UNLIMITED_VALUE	"unlimited"
#define READALL_PROXIES_STRICT	"strict"
#define DEFAULT_READALL_PROXIES_STRICT	TRUE

/* Number of privileged ports */
#define ABSOLUTE_MAX_SUBTHREADS 1024
#define NAME_SUBTHREADS "subthreads"

#define MAX_LATENCY 2*60*60	/* Two hour maximum (in seconds) */
#define MIN_LATENCY 1		/* One second minimum */
#define NAME_UPDATE_LATENCY	"update_latency"

#define MAX_CUWAIT 10*60*60	/* Ten hour maximum (in seconds) */
#define MIN_CUWAIT 60		/* 1 minute minumum XXX for testing XXX */
#define NAME_CLEANUPWAIT	"cleanup_wait"

#define NAME_FORCED_ROOT "isRoot"
#define NAME_CLONE_READALL "cloneReplyReadall"
#define NAME_SANITYCHECK "sanitycheck"

/*
 * Lookup "name"s address - returns it in net format
 */
unsigned long getaddress(void *ni, ni_name name)
{
	ni_id node;
	ni_id root;
	ni_idlist idlist;
	ni_namelist nl;
	u_long addr;
	
	if (ni_root(ni, &root) != NI_OK) return (0);

	NI_INIT(&idlist);
	if (ni_lookup(ni, &root, NAME_NAME, NAME_MACHINES, &idlist) != NI_OK)
		return (0);

	node.nii_object = idlist.ni_idlist_val[0];
	ni_idlist_free(&idlist);
	
	NI_INIT(&idlist);
	if (ni_lookup(ni, &node, NAME_NAME, name, &idlist) != NI_OK)
		return (0);

	node.nii_object = idlist.ni_idlist_val[0];
	ni_idlist_free(&idlist);

	NI_INIT(&nl);
	if (ni_lookupprop(ni, &node, NAME_IP_ADDRESS, &nl) != NI_OK)
		return (0);

	if (nl.ni_namelist_len > 0) addr = inet_addr(nl.ni_namelist_val[0]);
	else addr = 0;

	ni_namelist_free(&nl);
	return (addr);
}


/*
 * Get name and tag of master server
 */
int getmaster(void *ni, ni_name *master, ni_name *domain)
{
	ni_id root;
	ni_namelist nl;
	ni_name sep;

	if (ni_root(ni, &root) != NI_OK)
	{
		sys_msg(debug, LOG_ALERT, "Can't get master: no root directory");
		return (0);
	}

	NI_INIT(&nl);
	if (ni_lookupprop(ni, &root, NAME_MASTER, &nl) != NI_OK)
	{
		sys_msg(debug, LOG_ALERT,
			"Can't get master: no %s property", NAME_MASTER);
		return (0);
	}

	if (nl.ni_namelist_len == 0)
	{
		ni_namelist_free(&nl);
		sys_msg(debug, LOG_ALERT,
			"Can't get master: no values in %s property", NAME_MASTER);
		return (0);
	}

	sep = strchr(nl.ni_namelist_val[0], NI_SEPARATOR);
	if (sep == NULL)
	{
		ni_namelist_free(&nl);
		sys_msg(debug, LOG_ALERT,
			"Can't get master: no '%c' in value '%s'",
			NI_SEPARATOR, nl.ni_namelist_val[0]);
		return (0);
	}

	*sep = 0;
	if (master != NULL) *master = ni_name_dup(nl.ni_namelist_val[0]);
	if (domain != NULL) *domain = ni_name_dup(sep + 1);

	ni_namelist_free(&nl);
	return (1);
}

/*
 * Get master server's address (and domain) -- address is in net format
 */
unsigned long getmasteraddr(void *ni, ni_name *domain)
{
	unsigned long addr;
	ni_name master = NULL;

	if (getmaster(ni, &master, domain))
	{
		addr = getaddress(ni, master);
		ni_name_free(&master);
	}
	else addr = 0;

	return (addr);
}


/*
 * Lookup "name"s network
 */
static struct in_addr getnetwork(void *ni, ni_name name)
{
	ni_id node;
	ni_id root;
	ni_idlist idlist;
	ni_namelist nl;
	struct in_addr addr;

	addr.s_addr = 0;
	if (ni_root(ni, &root) != NI_OK) return (addr);

	NI_INIT(&idlist);
	if (ni_lookup(ni, &root, NAME_NAME, NAME_NETWORKS, &idlist) != NI_OK)
		return (addr);

	node.nii_object = idlist.ni_idlist_val[0];
	ni_idlist_free(&idlist);
	
	NI_INIT(&idlist);
	if (ni_lookup(ni, &node, NAME_NAME, name, &idlist) != NI_OK)
		return (addr);

	node.nii_object = idlist.ni_idlist_val[0];
	ni_idlist_free(&idlist);

	NI_INIT(&nl);
	if (ni_lookupprop(ni, &node, NAME_ADDRESS, &nl) != NI_OK)
		return (addr);

	if (nl.ni_namelist_len > 0)
		addr = inet_makeaddr(inet_network(nl.ni_namelist_val[0]), 0);

	ni_namelist_free(&nl);
	return (addr);
}

static int network_match(struct in_addr n, struct in_addr h)
{
	union
	{
		char s_byte[4];
		u_long s_address;
	} net, host;

	net.s_address = n.s_addr;
	host.s_address = h.s_addr;
	
	if (n.s_addr == 0) return (0);

	if (net.s_byte[0] != host.s_byte[0]) return (0);
	if (net.s_byte[1] == 0) return (1);

	if (net.s_byte[1] != host.s_byte[1]) return (0);
	if (net.s_byte[2] == 0) return (1);

	if (net.s_byte[2] != host.s_byte[2]) return (0);
	return (1);
}

int is_trusted_network(void *ni, struct sockaddr_in *host)
{
	struct in_addr network;
	ni_id root;
	int i;
	char *val, *temp;
	ni_namelist nl;
	ni_status status;

	status = ni_root(ni, &root);
	if (status != NI_OK)
	{
		/* Something is seriously wrong. Don't trust anybody. */
		sys_msg(debug, LOG_ERR,
			"trusted_networks for tag %s: cannot get root - %s",
			ni_tagname(ni), ni_error(status));
		return (0);
	}

	NI_INIT(&nl);
	if (ni_lookupprop(ni, &root, NAME_TRUSTED_NETWORKS, &nl) != NI_OK)
	{
		/*  Property doesn't exist, so we trust everybody */
		return (1);
	}

	for (i = 0; i < nl.ni_namelist_len; i++)
	{
		val = nl.ni_namelist_val[i];
		if (isdigit(*val)) {
			/* Network address in line */
			/* Make sure 1-byte address (e.g. "192") has a trailing "." */
			if (NULL == strchr(val, '.'))
			{
				temp = malloc(strlen(val) + 2);
				strcpy(temp, val);
				strcat(temp, ".");
				network = inet_makeaddr(inet_network(temp), 0);
				free(temp);
			}
			else network = inet_makeaddr(inet_network(val), 0);
		}
		else
		{
			/* Network specified by name */
			network = getnetwork(ni, val);
		}

		if (network_match(network, host->sin_addr))
		{
			ni_namelist_free(&nl);
			return (1);
		}
	}

	ni_namelist_free(&nl);

	if (sys_ismyaddress(host->sin_addr.s_addr))
	{
		/* Always trust local connections */
		return (1);
	}

	sys_msg(debug, LOG_NOTICE,
		"rejected connection from untrusted host %s",
		inet_ntoa(host->sin_addr));

	return (0);
}

static int get_intForKey(void *ni, char *name, int def, int min, int max)
{
	ni_id root;
	ni_namelist nl;
	int i, len;

	if (ni_root(ni, &root) != NI_OK) return(def);

	if (ni_lookupprop(ni, &root, name, &nl) != NI_OK)
		return(def);

	if (nl.ni_namelist_len == 0)
	{
		ni_namelist_free(&nl);
		return(def);
	}

	len = strlen(nl.ni_namelist_val[0]);
	if (len == 0)
	{
		sys_msg(debug, LOG_ERR,
			"no value for property %s",
			"using default %d", name, def);
		ni_namelist_free(&nl);
		return(def);
	}

	/* "unlimited" is a special case */
	if (!strcmp(nl.ni_namelist_val[0], "unlimited")) return -1;

	if (!((nl.ni_namelist_val[0][0] == '+') ||
		(nl.ni_namelist_val[0][0] == '-') ||
		isdigit(nl.ni_namelist_val[0][0])))
	{
		sys_msg(debug, LOG_ERR,
			"bad integer value for property %s",
			"using default %d", name, def);

		ni_namelist_free(&nl);
		return(def);
	}

	for (i = 1; i < len; i++)
	{
		if (!isdigit(nl.ni_namelist_val[0][i]))
		{
			sys_msg(debug, LOG_ERR,
				"bad integer value for property %s,",
				"using default %d", name, def);

			ni_namelist_free(&nl);
			return(def);
		}
	}

	i = atoi(nl.ni_namelist_val[0]);
	ni_namelist_free(&nl);

	/* -1 is a special case */
	if (i == -1) return i;

	if (i < min)
	{
		sys_msg(debug, LOG_ERR,
			"value %d for property %s is less than minimum allowed (%d),",
			"using minimum %d", i, name, min, min);

		return min;
	}

	if (i > max)
	{
		sys_msg(debug, LOG_ERR,
			"value %d for property %s is greater than maximum allowed (%d),",
			"using maximum %d", i, name, max, max);

		return max;
	}

	return i;
}

void get_readall_info(void *ni, int *proxies, bool_t *strict)
{
	ni_id root;
	ni_namelist nl;
	ni_status status;

	*proxies = get_intForKey(ni, NAME_READALL_PROXIES,
		DEFAULT_MAX_READALL_PROXIES, 0, MAX_READALL_PROXIES);

	*strict = DEFAULT_READALL_PROXIES_STRICT;

	status = ni_root(ni, &root);
 	if (status != NI_OK) return;

	status = ni_lookupprop(ni, &root, NAME_READALL_PROXIES, &nl);
 	if (status != NI_OK) return;

	if (nl.ni_namelist_len < 2) 
	{
		ni_namelist_free(&nl);
		return;
	}

	*strict = (!strcasecmp(nl.ni_namelist_val[1], READALL_PROXIES_STRICT));

	ni_namelist_free(&nl);

	switch (*proxies)
	{
		case -1:	/* Unlimited */
			sys_msg(debug, LOG_WARNING,
				"using unlimited %sreadall proxies",
				*strict ? "strict " : "");
			break;

		case 0:		/* Default: no proxies */
			break;

		default:	/* Anything else, report */
			sys_msg(debug, LOG_NOTICE,
				"maximum %d %sreadall prox%s", *proxies,
				*strict ? "strict " : "", (*proxies == 1) ? "y" : "ies");
		break;
	}

	return;
}

int get_cleanupwait(void *ni)
{
	int n;

	n = get_intForKey(ni, NAME_CLEANUPWAIT, CLEANUPWAIT,
		MIN_CUWAIT, MAX_CUWAIT);

	if (n != CLEANUPWAIT) {
		sys_msg(debug, LOG_NOTICE,
			"using using cleanup wait of %d second%s", n,
			1 == n ? "" : "s");
	}

	return n;
}

int get_update_latency(void *ni)
{
	int n;

	n = get_intForKey(ni, NAME_UPDATE_LATENCY, UPDATE_LATENCY_SECS,
		MIN_LATENCY, MAX_LATENCY);

	if (n == -1) n = UPDATE_LATENCY_SECS;

	if (n != UPDATE_LATENCY_SECS) {
		sys_msg(debug, LOG_NOTICE,
			"using using cleanup update latency of %d second%s", n,
			1 == n ? "" : "s");
	}

	return n;
}

int get_max_subthreads(void *ni)
{
	int n;

	n = get_intForKey(ni, NAME_SUBTHREADS, MAX_SUBTHREADS,
		0, ABSOLUTE_MAX_SUBTHREADS);

	if (n == -1) n = ABSOLUTE_MAX_SUBTHREADS;

	if (n != MAX_SUBTHREADS) {
		sys_msg(debug, LOG_NOTICE,
			"maximum %d notify subthread%s", n,
			(n == 1) ? "" : "s");
	}

	return n;
}

static bool_t get_boolForKey(void *ni, ni_name name, bool_t def)
{
	ni_id root;
	ni_namelist nl;
	bool_t ret;

	ret = def;

	if (ni_root(ni, &root) != NI_OK)
		return(ret);

	if (ni_lookupprop(ni, &root, name, &nl) != NI_OK)
		return(ret);

	if (nl.ni_namelist_len == 0)
	{
		ni_namelist_free(&nl);
		return(ret);
	}

	if (!strcmp(nl.ni_namelist_val[0], "YES")) ret = TRUE;
	else if (!strcmp(nl.ni_namelist_val[0], "yes")) ret = TRUE;
	else if (!strcmp(nl.ni_namelist_val[0], "Yes")) ret = TRUE;
	else if (!strcmp(nl.ni_namelist_val[0], "1")) ret = TRUE;
	else if (!strcmp(nl.ni_namelist_val[0], "Y")) ret = TRUE;
	else if (!strcmp(nl.ni_namelist_val[0], "y")) ret = TRUE;
	else if (!strcmp(nl.ni_namelist_val[0], "NO")) ret = FALSE;
	else if (!strcmp(nl.ni_namelist_val[0], "no")) ret = FALSE;
	else if (!strcmp(nl.ni_namelist_val[0], "No")) ret = FALSE;
	else if (!strcmp(nl.ni_namelist_val[0], "0")) ret = FALSE;
	else if (!strcmp(nl.ni_namelist_val[0], "N")) ret = FALSE;
	else if (!strcmp(nl.ni_namelist_val[0], "n")) ret = FALSE;

	ni_namelist_free(&nl);
	return(ret);
}

bool_t get_forced_root(void *ni)
{
	return get_boolForKey(ni, NAME_FORCED_ROOT, FALSE);
}

/*
 * Allow clones to reply to a readall request. If the cloneReplyReadall
 * property is present in the root directory, clones may reply to readall
 * requests.
 */

bool_t get_clone_readall(void *ni)
{
	return get_boolForKey(ni, NAME_CLONE_READALL, FALSE);
}

bool_t
get_sanitycheck(void *ni)
{
	return get_boolForKey(ni, NAME_SANITYCHECK, FALSE);
}
