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
 * Notification thread routines.
 * Copyright (C) 1989 by NeXT, Inc.
 *
 * The notification thread runs only on the master. It notifies
 * clone servers about changes to the database or resynchronization
 * requests from the master.
 */
#include "ni_server.h"
#include <sys/socket.h>
#include <sys/time.h>
#include <mach/cthreads.h>
#include <stdio.h>
#include "system.h"
#include "ni_globals.h"
#include "mm.h"
#include "getstuff.h"
#include "notify.h"
#include "socket_lock.h"
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>

const char *procname(int);
const bool_t takes_arg(int);

unsigned int clone_count = 0;
extern char VERS_NUM[];

#define NI_SEPARATOR '/' /* Separator used in NetInfo property values */

#define NOTIFY_TIMEOUT 60 /* Time to wait before giving up on clone */

/*
 * The notification thread knows about the clone servers through
 * this data structure.
 */
typedef struct client_node *clone_list;
struct client_node {
	ni_name name;		/* host name of clone */
	unsigned long addr;	/* IP address of clone - in network byte order*/
	ni_name tag;		/* Which database served by clone (by tag) */
	mutex_t lock;		/* Try only one update per clone */
	condition_t cond;	/* Wake up other waiting updates */
	long lastupdate;	/* Serialize updates */
	bool_t up_to_date;	/* Clone's up-to-date due to readall */
	clone_list next;	/* next clone */
};

#define NO_SEQUENCE_NUMBER  -1

/*
 * This union encodes all possible arguments involved in NetInfo write
 * calls.
 */
typedef union write_any_args {
	ni_create_args create_args;
	ni_destroy_args destroy_args;
	ni_proplist_stuff write_args;
	ni_createprop_args createprop_args;
	ni_prop_args destroyprop_args;
	ni_propname_args renameprop_args;
	ni_writeprop_args writeprop_args;
	ni_createname_args createname_args;
	ni_nameindex_args destroy_name_args;
	ni_writename_args writename_args;
} write_any_args;

/*
 * This union encodes all possible results from NetInfo write calls.
 */
typedef union write_any_res {
	ni_create_res create_res;
	ni_id_res destroy_res;
	ni_id_res write_res;
	ni_id_res createprop_res;
	ni_id_res destroyprop_res;
	ni_id_res renameprop_res;
	ni_id_res writeprop_res;
	ni_id_res createname_res;
	ni_id_res destroyname_res;
	ni_id_res writename_res;
} write_any_res;


/*
 * We store the XDR routines associated with each NetInfo write call
 * in a table with this data structure for each entry.
 */
typedef struct xdr_table_entry {
	unsigned proc;		/* procedure number of write call */
	unsigned insize;	/* size of input arguments */
	xdrproc_t xdr_in;	/* xdr routine for input arguments */
	unsigned outsize;	/* size of output results */
	xdrproc_t xdr_out;	/* xdr routine for output results */
} xdr_table_entry;

/*
 * Macro used to initialize the table
 */
#define PUSH(proc, arg_type, res_type) \
	{ proc, sizeof(arg_type), xdr_##arg_type, \
	  sizeof(res_type), xdr_##res_type }


/*
 * The table itself
 */
static const xdr_table_entry xdr_table[] = {
	PUSH(_NI_CREATE, ni_create_args, ni_create_res),
	PUSH(_NI_DESTROY, ni_destroy_args, ni_id_res),
	PUSH(_NI_WRITE, ni_proplist_stuff, ni_id_res),
	PUSH(_NI_CREATEPROP, ni_createprop_args, ni_id_res),
	PUSH(_NI_DESTROYPROP, ni_prop_args, ni_id_res),
	PUSH(_NI_RENAMEPROP, ni_propname_args, ni_id_res),
	PUSH(_NI_WRITEPROP, ni_writeprop_args, ni_id_res),
	PUSH(_NI_CREATENAME, ni_createname_args, ni_id_res),
	PUSH(_NI_WRITEPROP, ni_writeprop_args, ni_id_res),
	PUSH(_NI_CREATENAME, ni_createname_args, ni_id_res),
	PUSH(_NI_DESTROYNAME, ni_nameindex_args, ni_id_res),
	PUSH(_NI_WRITENAME, ni_writename_args, ni_id_res),
	PUSH(_NI_RESYNC, void, ni_status),
};
#undef PUSH	
#define XDR_TABLE_SIZE (sizeof(xdr_table)/sizeof(xdr_table[0]))	


static const xdr_table_entry *xdr_table_lookup(unsigned);

/*
 * The list of notifications to be sent out
 */
typedef struct notify_node *notify_list;
struct notify_node {
	unsigned proc;		/* the procedure to execute on the clone */
	unsigned checksum;	/* checksum after applying this operation */
	write_any_args args;	/* the arguments to supply */
	clone_list newlist;	/* new list of clones, if proc is RESYNC */
	notify_list next;	/* next item on list */
};


/*
 * Arguments to the notify() thread
 */
typedef struct notify_args {
       clone_list list;		/* list of clone servers */
       unsigned checksum;	/* checksum of master database */
} notify_args;


static void notify(notify_args *);


/*
 * The queue of notifications to be sent
 */
static volatile notify_list notifications;

/*
 * For locking the queue 
 */
static mutex_t notify_mutex = (mutex_t)NULL;
static condition_t notify_condition;
/*
 * For tracking the status of update-distributing subthreads.
 */
static mutex_t subthread_mutex;
static condition_t subthread_condition;
static volatile int notify_subthread_count = 0;
static volatile long next_update_number = 0;

typedef struct {
    clone_list	 clones;
    notify_list  updates;
    long	 seqno;
} fork_push_args;

static void push(clone_list, notify_list updates, long seq);
static void fork_push(clone_list, notify_list updates, long seq);
static void push_thread_stub(fork_push_args *);

unsigned count_procs(notify_list);
bool_t udp_getregister(ni_name, ni_name, struct sockaddr_in,
		       struct timeval,  nibind_getregister_res *, char *);
bool_t tcp_getregister(ni_name, ni_name, struct sockaddr_in,
		       struct timeval,  nibind_getregister_res *, char *);

clone_list global_clone_list = NULL;	/* Assumes there's only one! */

/*
 * Destroys a client handle with locks
 */
static void
clnt_destroy_lock(
		  CLIENT *cl,
		  int sock
		  )
{
	socket_lock();
	clnt_destroy(cl);
	(void)close(sock);
	socket_unlock();
}

/*
 * Frees up a clone list
 */
static void
freeclonelist(
	      clone_list clist
	      )
{
	clone_list l;

	while (clist != NULL) {
		l = clist;
		clist = clist->next;
		ni_name_free(&l->name);
		ni_name_free(&l->tag);
		mutex_free(l->lock);
		condition_free(l->cond);
		MM_FREE(l);
	}
		
}

/*
 * Does this entry serve the "." domain?
 * Return the name and tag of the server if it does serve "."
 */
static unsigned
servesdot(
	  ni_entry entry,
	  ni_name *name,
	  ni_name *tag
	  )
{
	ni_name sep;
	ni_name slashname;	
	unsigned addr;
	ni_namelist nl;
	ni_index i;
	ni_id id;
	
	if (entry.names == NULL) {
		return (0);
	}
	id.nii_object = entry.id;
	for (i = 0; i < entry.names->ninl_len; i++) {
		slashname = entry.names->ninl_val[i];
		sep = index(slashname, NI_SEPARATOR);
		if (sep == NULL) {
			continue;
		}

		if (!ni_name_match_seg(NAME_DOT, slashname, sep - slashname)) {
			continue;
		}

		NI_INIT(&nl);
		if (ni_lookupprop(db_ni, &id, NAME_IP_ADDRESS, &nl) != NI_OK) {
			continue;
		}
		if (nl.ninl_len == 0) {
			continue;
		}
		addr = inet_addr(nl.ninl_val[0]);
		ni_namelist_free(&nl);

		*tag = ni_name_dup(sep + 1);

		NI_INIT(&nl);
		if (ni_lookupprop(db_ni, &id, NAME_NAME, &nl) != NI_OK) {
			*name = NULL;
		} else {
			if (nl.ninl_len > 0) {
				*name = ni_name_dup(nl.ninl_val[0]);
			}
			ni_namelist_free(&nl);
		}
		return (addr);
	}
	return (0);
}

/*
 * Reads the list of clone servers from the database
 */
static clone_list
getclonelist()
{
	ni_id id;
	ni_index i;
	unsigned addr;
	struct in_addr x;
	clone_list new;
	clone_list clist;
	ni_name name = NULL;
	ni_name tag = NULL;
	ni_idlist idlist;
	ni_entrylist entries;

	clone_count = 0;	 /* Start off assuming none to simplify code */
	if (ni_root(db_ni, &id) != NI_OK) {
		return (NULL);
	}

	NI_INIT(&idlist);
	if (ni_lookup(db_ni, &id, NAME_NAME, NAME_MACHINES, &idlist) !=
	    NI_OK) {
		return (NULL);
	}
	id.nii_object = idlist.niil_val[0];
	ni_idlist_free(&idlist);
	if (ni_list_const(db_ni, &id, NAME_SERVES, &entries) != NI_OK) {
		return (NULL);
	}
	clist = NULL;
	for (i = 0; i < entries.niel_len; i++) {
		addr = servesdot(entries.niel_val[i], &name, &tag);
		if (addr == 0) continue;
		x.s_addr = addr;

		/*
		 * Don't notify self
		 */
		if ((sys_ismyaddress(addr)) && (!strcmp(tag, db_tag)))
		{
			ni_name_free(&name);
			ni_name_free(&tag);
			continue;
		}

		clone_count++;
		MM_ALLOC(new);
		new->name = name;
		new->addr = addr;
		new->tag = tag;
		new->lastupdate = 0;
		new->lock = mutex_alloc();
		new->cond = condition_alloc();
		new->up_to_date = TRUE;
		new->next = clist;
		clist = new;
	}
	ni_list_const_free(db_ni);
	return (clist);
}


/*
 * Is there a notifier thread running?
 */
static int have_notifier;


/*
 * Starts up a notification thread. Is smart enough not to start one
 * if the clone list is empty.
 */
int
notify_start(
	     void
	     )
{
	notify_args *args;
	clone_list clist;

	clist = getclonelist();
	global_clone_list = clist;
	if (clist == NULL) {
		/*
		 * No need for notifier
		 */
		return (0);
	}

	MM_ALLOC(args);
	args->list = clist;
	args->checksum = db_checksum;
	notify_mutex = mutex_alloc();
	notify_condition = condition_alloc();
	subthread_mutex = mutex_alloc();
	subthread_condition = condition_alloc();
	cthread_detach(cthread_fork((cthread_fn_t)notify, (any_t)args));
	have_notifier++;
	return (1);
}


/*
 * Send out a resync notification. This procedure is special-cased
 * because the master updates its list of clone servers when it gets
 * a resync call.
 */
void
notify_resync(
	      void
	      )
{
	notify_args *args;
	clone_list clist;

	clist = getclonelist();
	global_clone_list = clist;
	get_readall_info(db_ni, &max_readall_proxies, &strict_proxies);
	max_subthreads = get_max_subthreads(db_ni);
	update_latency_secs = get_update_latency(db_ni);
	if (!have_notifier) {
		if (clist != NULL) {
			MM_ALLOC(args);
			args->list = clist;
			args->checksum = db_checksum;
			notify_mutex = mutex_alloc();
			notify_condition = condition_alloc();
			subthread_mutex = mutex_alloc();
			subthread_condition = condition_alloc();
			have_notifier++;
			cthread_detach(cthread_fork((cthread_fn_t)notify, 
						    (any_t)args));
		}
	} else {
		notify_clients(_NI_RESYNC, clist);
	}
}

/*
 * The notification thread
 */
static void
notify(
       notify_args *args
       )
{
	clone_list l;
	notify_list newlist;
	notify_list lastelt;
	struct timeval tv;
	CLIENT *cl;
	int sock;
	struct sockaddr_in sin;
	nibind_getregister_res res;
	bool_t notify_waited = FALSE;
	enum clnt_stat cstat;
	int clones_skipped = 0;

	tv.tv_sec = NOTIFY_TIMEOUT;
	tv.tv_usec = 0;
	sin.sin_family = AF_INET;
	MM_ZERO(sin.sin_zero);

	/*
	 * First, tell everybody that you've crashed
	 */
	sys_msg(debug, LOG_INFO, "ni_crashed notification starting {%u}: %d clone%s",
	       db_checksum, count_clones(), 1 == count_clones() ? "" : "s");
	cthread_set_name(cthread_self(), "notify-crashed");
	for (l = args->list; l != NULL; l = l->next) {
		sin.sin_port = 0;
		sin.sin_addr.s_addr = l->addr;
		if (! (udp_getregister(l->name, l->tag, sin, tv, &res,
				       "ni_crashed") ||
		       tcp_getregister(l->name, l->tag, sin, tv, &res,
				       "ni_crashed"))) {
			/* the *_getregister functions do their own logging */
			clones_skipped++;
			continue;
		}

		if (res.status != NI_OK) {
			sys_msg(debug, LOG_WARNING,
			       "ni_crashed found %s/%s unregistered",
			       inet_ntoa(sin.sin_addr), l->tag);
			clones_skipped++;
			continue;
		}

		sin.sin_port = htons(
			res.nibind_getregister_res_u.addrs.tcp_port);
		sock = socket_connect(&sin, NI_PROG, NI_VERS);
		if (sock < 0) {
			sys_msg(debug, LOG_WARNING, "ni_crashed can't connect to "
			       "%s/%s - %m",
			       inet_ntoa(sin.sin_addr), l->tag);
			clones_skipped++;
			continue;
		}
		/*
		 * Protect the main thread from using the set of ALL known
		 * RPC file descriptors (svc_fdset) by excluding those FDs
		 * associated with the client side operations.
		 */
		FD_SET(sock, &clnt_fdset);	/* protect client socket */
		cl = clnttcp_create(&sin, NI_PROG, NI_VERS, &sock, 0, 0);
		if (cl == NULL) {
			sys_msg(debug, LOG_WARNING, "ni_crashed can't create "
			       "%s/%s%s",
			       inet_ntoa(sin.sin_addr), l->tag,
			       clnt_spcreateerror(""));
			clones_skipped++;
			socket_close(sock);
			FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
			continue;
		}
		cstat = clnt_call(cl, _NI_CRASHED, xdr_u_int,
				  &args->checksum, xdr_void, NULL, tv);
		if (RPC_SUCCESS != cstat) {
			sys_msg(debug, LOG_WARNING, "ni_crashed can't send "
			       "to %s/%s - %s",
			       inet_ntoa(sin.sin_addr), l->tag,
			       clnt_sperrno(cstat));
			clones_skipped++;
		} else {
			sys_msg(debug, LOG_DEBUG,
			       "ni_crashed to %s[%s]/%s:%hu",
			       l->name, inet_ntoa(sin.sin_addr), l->tag,
			       ntohs(sin.sin_port));
		}
		clnt_destroy_lock(cl, sock);
		FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
	}
	if (0 == clones_skipped) {
	    sys_msg(debug, LOG_INFO, "ni_crashed sent");
	} else {
	    sys_msg(debug, LOG_INFO, "ni_crashed sent; %d clone%s skipped",
		   clones_skipped, (1 == clones_skipped ? "" : "s"));
	}
	clones_skipped = 0;
	cthread_set_name(cthread_self(), "notify");
	/*
	 * Now, should wait for things to be added to the
	 * update queue and send them off to its clients.
	 */

	tv.tv_usec = 0;
	mutex_lock(notify_mutex);
	for (;;) {
		condition_wait(notify_condition, notify_mutex);
		/*
		** GRS 2/12/92 - Force a ten-second latency after each ping
		** to help combining adjacent operations into grouped updates.
		*/
		tv.tv_sec = update_latency_secs;
		mutex_unlock(notify_mutex);
		select(0, NULL, NULL, NULL, &tv);	/* i.e., tvsleep(tv) */
		mutex_lock(notify_mutex);
		while (notifications != NULL) {
			if (notifications->proc == _NI_RESYNC) {
			    /* 
			    ** GRS 2/12/92 - Since this operation affects 
			    ** the clone list, we need to wait for all 
			    ** current threads to die off before proceeding.
			    */
			    mutex_unlock(notify_mutex);
			    mutex_lock(subthread_mutex);
			    cthread_set_name(cthread_self(), "notify-resync");
			    if (0 != notify_subthread_count) {
				sys_msg(debug, LOG_DEBUG,
				       "resync waiting on %d thread%s",
				       notify_subthread_count,
				       1 == notify_subthread_count ?
					    "" : "s");
				notify_waited = TRUE;
			    } else {
				notify_waited = FALSE;
			    }
			    while (notify_subthread_count) {
				/* Wait for some threads to die */
				condition_wait(subthread_condition, 
				    subthread_mutex);
			    }
			    mutex_unlock(subthread_mutex);
			    mutex_lock(notify_mutex);
			    /* Perform the resync operation */
			    if (notify_waited) {
				sys_msg(debug, LOG_DEBUG,
				       "resync continuing");
			    }
			    freeclonelist(args->list);
			    args->list = notifications->newlist;
			    lastelt = notifications;
			    notifications = notifications->next;
			    lastelt->next = NULL;
			    mutex_unlock(notify_mutex);
			    push(args->list, lastelt, next_update_number = 0);
			    mutex_lock(notify_mutex);
			} else { /* Non-resync update */
			    mutex_unlock(notify_mutex);
			    mutex_lock(subthread_mutex);
			    if (notify_subthread_count >= max_subthreads) {
				sys_msg(debug, LOG_DEBUG,
				       "update %d awaiting a thread",
				       next_update_number);
			    }
			    while (notify_subthread_count >= max_subthreads) {
				/* Wait for some threads to die */
				condition_wait(subthread_condition, 
				    subthread_mutex);
			    }
			    mutex_unlock(subthread_mutex);
			    mutex_lock(notify_mutex);
			    /* Lop off a bunch of notifications */
			    newlist = notifications; 
			    lastelt = NULL;
			    while (newlist && (newlist->proc != _NI_RESYNC)) {
				lastelt = newlist;
				newlist = newlist->next;
			    }
			    if (lastelt) {
				lastelt->next = NULL;
				fork_push(args->list, notifications, 
				    next_update_number);
			    }
			    notifications = newlist;
			}
			next_update_number++;
		}
	}
	mutex_unlock(notify_mutex);
}

int
have_notifications_pending(void)
{
	int	num_threads;
	
	if (notifications != NULL) {
		/*
		* List is not empty
		*/
		return (1);
	}
	if (!subthread_mutex) {
	    return 0;
	}
	mutex_lock(subthread_mutex);
	num_threads = notify_subthread_count;
	mutex_unlock(subthread_mutex);
	return (num_threads != 0);
}

/*
 * Notify the clone servers of a change to the database.
 * 	proc = procedure to execute on clone
 *	args = arguments to procedure
 * XXX: procedure is a misnomer - should be notify_clones
 */
void
notify_clients(
	       unsigned proc,
	       void *args
	       )
{
	notify_list *l;
	const xdr_table_entry *ent;

	if (!have_notifier) {
		if (!notify_start()) {
			return;
		}
	}

	ent = xdr_table_lookup(proc);
	if (ent == NULL) {
		return;
	}
	mutex_lock(notify_mutex);
	for (l = (notify_list *)&notifications; *l != NULL; l = &(*l)->next) {
	}
	MM_ALLOC(*l);
	(*l)->proc = proc;
	if (proc == _NI_RESYNC) {
		(*l)->newlist = (clone_list)args;
	} else {
		bcopy(args, &(*l)->args, ent->insize);
		bzero(args, ent->insize);
	}
	(*l)->checksum = db_checksum;
	(*l)->next = NULL;
	condition_signal(notify_condition);
	mutex_unlock(notify_mutex);
}



/*
 * Tries to execute the procedure on each of the clone servers
 */
static void
push(
     clone_list list,
     notify_list updates,
     long seq
     )
{
	write_any_res res;
	const xdr_table_entry *ent = NULL;
	int sock;
	struct sockaddr_in sin;
	struct timeval tv;
	CLIENT *cl;
	clone_list l;
	nibind_getregister_res gres;
	notify_list this;
	enum clnt_stat clstat;
	int low_level_success;	/* Did we get the low-level stuff done? */
	char *msg_stage;	/* Stage of operation for error message */
	char *msg;		/* And a message for the ages */
	unsigned clones_skipped = 0;	/* How many clones we skipped */
	unsigned clones_current = 0;	/* Clones we would have skipped */
	int nprocs;
	int i;		/* Temporary loop counter */

	nprocs = count_procs(updates);
	sys_msg(debug, LOG_INFO, "update %d starting: %d clone%s, %d operation%s",
	       seq, count_clones(), 1 == count_clones() ? "" : "s",
	       nprocs, 1 == nprocs ? "" : "s");
	tv.tv_sec = NOTIFY_TIMEOUT;
	tv.tv_usec = 0;
	sin.sin_family = AF_INET;
	MM_ZERO(sin.sin_zero);
	for (l = list; l != NULL; l = l->next) {

		/*
		 * Wait for any other threads that are pushing
		 * earlier updates to catch up to this clone
		 */

		mutex_lock(l->lock);
		while ((l->lastupdate < (seq - 1)) &&
		       (l->lastupdate != NO_SEQUENCE_NUMBER)) {
		    condition_wait(l->cond, l->lock);
		}

		sin.sin_port = 0;
		sin.sin_addr.s_addr = l->addr;

		/*
		 * If this clone has failed on the push of an earlier 
		 * sequence number, drop it from this update.  It will
		 * have to wait until a resync to set l->lastupdate = 0.
		 */

		if (l->lastupdate == NO_SEQUENCE_NUMBER) {
		    /*
		     * If a clone misses an update and then does a
		     * readall, it'll be marked up_to_date, and should
		     * then resume getting notifications.
		     */
		    if (!l->up_to_date) {
			/* Skip this clone, indeed */
			mutex_unlock(l->lock);
			condition_broadcast(l->cond);
			sys_msg(debug, LOG_DEBUG,
			       "update %d: skipping %s[%s]/%s:%hu",
			       seq, l->name,
			       inet_ntoa(sin.sin_addr), l->tag,
			       ntohs(sin.sin_port));
		 	clones_skipped++;
			continue;
		    } else {
			/* Need to include this clone */
			clones_current++;
		    }
		}

		/*
		 * Connect to the clone
		 */
		low_level_success = 0;	/* Assume this low-level stuff bombs */
		msg_stage = "binder contacting";
		if (! (udp_getregister(l->name, l->tag, sin, tv, &gres,
				       "notify") ||
		       tcp_getregister(l->name, l->tag, sin, tv, &gres,
				       "notify"))) {
			msg = "couldn't getregister";
			goto cleanup_locks;
		}
		if (gres.status != NI_OK) {
			/* XXX We use NORESPONSE for more than just parent */
			msg = NI_NORESPONSE == gres.status ?
				"No response from clone" :
				(char *)ni_error(gres.status);
			goto cleanup_locks;
		}
		sin.sin_port =
			htons(gres.nibind_getregister_res_u.addrs.tcp_port);
		msg_stage = "contacting";
		msg = "Couldn't get system resources ("
		      "socket or TCP connection)";
		sock = socket_connect(&sin, NI_PROG, NI_VERS);
		if (sock < 0) {
			goto cleanup_locks;
		}
		FD_SET(sock, &clnt_fdset);	/* protect client socket */
		cl = clnttcp_create(&sin, NI_PROG, NI_VERS, &sock, 0, 0);
		if (cl == NULL) {
			socket_close(sock);
			FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
			msg = clnt_spcreateerror("netinfo daemon");
			goto cleanup_locks;
		}

		/*
		 * Push coalesed changes to the clone
		 */
		low_level_success = 1;
		for (this = updates, i = 0; this; this = this->next, i++) {
		    ent = xdr_table_lookup(this->proc);
		    if (ent == NULL) {
			    abort(); /* Should never happen */
		    }
		    bzero(&res, ent->outsize);
		    if (takes_arg(this->proc)) {
			sys_msg(debug, LOG_DEBUG,
			       0 == ((nprocs - i) % 50) ?
				    "update %d: %s %u to %s[%s]/%s:%hu {%u}, "
					"%d procs to go" :
				    "update %d: %s %u to %s[%s]/%s:%hu {%u}",
			       seq, procname(this->proc),
			       /* Next line just grabs first arg */
			       this->args.create_args.id.nii_object,
			       l->name, inet_ntoa(sin.sin_addr), l->tag,
			       ntohs(sin.sin_port), this->checksum,
			       nprocs - i);
		    } else {
			sys_msg(debug, LOG_DEBUG,
			       0 == ((nprocs - i) % 50) ?
				    "update %d: %s to %s[%s]/%s:%hu {%u}, "
					"%d procs to go" :
				    "update %d: %s to %s[%s]/%s:%hu {%u}",
			       seq, procname(this->proc), l->name,
			       inet_ntoa(sin.sin_addr), l->tag,
			       ntohs(sin.sin_port), this->checksum,
			       nprocs - i);
		    }

		    clstat = clnt_call(cl, this->proc, ent->xdr_in,
		    		       &this->args, ent->xdr_out, &res, tv);
		    if (clstat != RPC_SUCCESS) {
			struct sockaddr_in us;
			int count;
		    
			count = sizeof(us);
			if (0 != getsockname(sock, (struct sockaddr *)&us,
					     &count)) {
			    us.sin_port = htons(-1);
			}
			sys_msg(debug, LOG_ERR,  
			       "update %d: %s from port %hu to %s[%s]/%s:%hu "
			       "RPC error - %s", seq,
			       procname(this->proc), ntohs(us.sin_port),
			       l->name, inet_ntoa(sin.sin_addr), l->tag,
			       ntohs(sin.sin_port), clnt_sperrno(clstat));
			clnt_destroy_lock(cl, sock);
			FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
			goto cleanup_locks;	/* Shouldn't do others */
		    }
		    /*
		     * Next line uses the write_res part of the union
		     * just 'cuz.  No, it's probably not a write, but
		     * it doesn't really matter: all the constituent types
		     * of the union have status as their first member.
		     */
		    if (res.write_res.status != NI_OK) {
			struct sockaddr_in us;
			int count;
		    
			count = sizeof(us);
			if (0 != getsockname(sock, (struct sockaddr *)&us,
					     &count)) {
			    us.sin_port = htons(-1);
			}
			sys_msg(debug, LOG_ERR,  
				"update %d: %s from port %hu to %s[%s]/%s:%hu "
				"failed - %s", seq,
				procname(this->proc), ntohs(us.sin_port),
				l->name, inet_ntoa(sin.sin_addr), l->tag,
				ntohs(sin.sin_port),
				ni_error(res.write_res.status));
			clnt_destroy_lock(cl, sock);
			FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
			goto cleanup_locks;	/* Shouldn't do others */
		    }
		}

		/*
		 * Push was successful - reset this clone's sequence number
		 */

		clnt_destroy_lock(cl, sock);
		FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
		l->lastupdate = seq;
		l->up_to_date = TRUE;
		mutex_unlock(l->lock);
		condition_broadcast(l->cond);
		continue;
	    
		/*
		 * Push failed - give up on this clone
		 */

cleanup_locks:
		l->lastupdate = NO_SEQUENCE_NUMBER;
		l->up_to_date = FALSE;
		mutex_unlock(l->lock);
		condition_broadcast(l->cond);
		if (!low_level_success) {
		    sys_msg(debug, LOG_ERR, 
			       "update %d to %s[%s]/%s failed during %s - "
			       "%s", seq,
			       l->name, inet_ntoa(sin.sin_addr), l->tag,
			       msg_stage, msg);
		}
	}

	/*
	 * Clean up
	 */
	while (updates) {
	    ent = xdr_table_lookup(updates->proc);
	    xdr_free(ent->xdr_in, (void *)&updates->args);
	    this = updates->next;
	    MM_FREE(updates);
	    updates = this;
	}
	if (0 == clones_skipped && 0 == clones_current) {
	    sys_msg(debug, LOG_INFO, "update %d sent", seq);
	} else if (0 == clones_skipped && 0 != clones_current) {
	    sys_msg(debug, LOG_INFO,
		   "update %d sent; %d clone%s included per TS enhancement",
		   seq, clones_current, (1 == clones_current ? "" : "s"));
	} else if (0 != clones_skipped && 0 == clones_current) {
	    sys_msg(debug, LOG_INFO, "update %d sent; %d clone%s skipped", seq,
		   clones_skipped, (1 == clones_skipped ? "" : "s"));
	} else {	/* 0 != clones_current && 0 != clones_skipped */
	    sys_msg(debug, LOG_INFO, "update %d sent; %d clone%s skipped, "
		   "%d clone%s included per TS enhancement", seq,
		   clones_skipped, (1 == clones_skipped ? "" : "s"),
		   clones_current, (1 == clones_current ? "" : "s"));
	}
}

/*
 * Do a push in a separate thread
 */
static void
fork_push(
     clone_list clones,
     notify_list updates,
     long seq
     )
{
    fork_push_args *args;
    
    if (!(args = (fork_push_args *) malloc(sizeof(fork_push_args)))) {
	return;
    }
    args->updates = updates;
    args->clones = clones;
    args->seqno = seq;
    mutex_lock(subthread_mutex);
    cthread_detach(cthread_fork((cthread_fn_t)push_thread_stub, (any_t)args));
    notify_subthread_count++;
    mutex_unlock(subthread_mutex);
    return;
}
    
static void 
push_thread_stub(
    fork_push_args *args
    )
{
    char buf[8 + strlen("4294967296")];

    (void)sprintf(buf, "notify-%ld", args->seqno);
    cthread_set_name(cthread_self(), buf);
    push(args->clones, args->updates, args->seqno);
    MM_FREE(args);
    mutex_lock(subthread_mutex);
    notify_subthread_count--;
    condition_signal(subthread_condition);
    mutex_unlock(subthread_mutex);
    cthread_exit((void *) 0);
}
    
/*
 * Looks up the XDR information for the given procedure
 */
static const xdr_table_entry *
xdr_table_lookup(
		 unsigned proc
		 )
{
	int i;

	for (i = 0; i < XDR_TABLE_SIZE; i++) {
		if (xdr_table[i].proc == proc) {
			return (&xdr_table[i]);
		}
	}
	return (NULL);
}

const char *
procname(int procnum)
{
    static char *procname_array[] = {
	"ping",
	"statistics",
	"root",
	"self",
	"parent",
	"create",
	"destroy",
	"read",
	"write",
	"children",
	"lookup",
	"list",
	"createprop",
	"destroyprop",
	"readprop",
	"writeprop",
	"renameprop",
	"listprops",
	"createname",
	"destroyname",
	"readname",
	"writename",
	"rparent",
	"listall",
	"bind",
	"readall",
	"crashed",
	"resync",
	"lookupread"};
    return(procnum < (sizeof(procname_array) / sizeof(*procname_array)) ?
	   procname_array[procnum] :
	   "*UNKNOWN*");
}

int
notifications_pending(void)
{
    int	i;
    notify_list n;

    if ((mutex_t)NULL == notify_mutex) {
	return(0);	/* If mutex is unitialized, nothing's pending */
    }
    mutex_lock(notify_mutex);
    for (i = 0, n = notifications; NULL != n; n = n->next) {
	i++;
    }
    mutex_unlock(notify_mutex);

    return(i);
}

/* Encapsulate the implementations, rather than making the variables visible */
int
count_notify_subthreads(void)
{
    return(notify_subthread_count);
}

int
count_clones(void)
{
    return(clone_count);
}

const bool_t
takes_arg(int procnum)
{
    switch (procnum) {
    case _NI_RESYNC:
    case _NI_RPARENT:
    case _NI_ROOT:
    case _NI_STATISTICS:
    case _NI_PING: {
	return(FALSE);
	break; }
    default: {
	return(TRUE);
	break; }
    }
}

unsigned
count_procs(notify_list updates)
{
    int	i;
    notify_list n;
    
    for (i = 0, n = updates; n != NULL; n = n->next) {
	i++;
    }
    return(i);
}

bool_t
udp_getregister(ni_name name, ni_name tag, struct sockaddr_in sin,
		struct timeval tv, nibind_getregister_res *res, char *caller)
{
	int sock;
	CLIENT *cl;
	enum clnt_stat clstat;
	char *msg_stage;
	char *msg;

	sin.sin_port = 0;

	msg_stage = "opening (UDP)";
	sock = socket_open(&sin, NIBIND_PROG, NIBIND_VERS);
	if (sock < 0) {
		msg = "socket_open failed";
		goto failed;
	} 
	msg_stage = "creating (UDP)";
	FD_SET(sock, &clnt_fdset);	/* protect client socket */
	cl = clntudp_create(&sin, NIBIND_PROG, NIBIND_VERS, 
			    tv, &sock);
	if (cl == NULL) {
		msg = clnt_spcreateerror("binder daemon");
		socket_close(sock);
		FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
		goto failed;
	}
	msg_stage = "connecting (UDP)";
	if ((clstat = clnt_call(cl, NIBIND_GETREGISTER,
				xdr_ni_name, &tag,
				xdr_nibind_getregister_res,
				res, tv)) != RPC_SUCCESS)  {
		msg = clnt_sperrno(clstat);
		clnt_destroy_lock(cl, sock);
		FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
		goto failed;
	}

	clnt_destroy_lock(cl, sock);
	FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
	return(TRUE);

    failed:
	sys_msg(debug, LOG_WARNING, "%s's udp binder connection to %s[%s]/%s "
	       "failed during %s - %s", caller, name, inet_ntoa(sin.sin_addr),
	       tag, msg_stage, msg);
	return(FALSE);
}

bool_t
tcp_getregister(ni_name name, ni_name tag, struct sockaddr_in sin,
		struct timeval tv, nibind_getregister_res *res, char *caller)
{
	int sock;
	CLIENT *cl;
	enum clnt_stat clstat;
	char *msg_stage;
	char *msg;

	sin.sin_port = 0;

	msg_stage = "opening (TCP)";
	sock = socket_connect(&sin, NIBIND_PROG, NIBIND_VERS);
	if (sock < 0) {
		msg = "socket_connect failed";
		goto failed;
	}
	msg_stage = "creating (TCP)";
	FD_SET(sock, &clnt_fdset);	/* protect client socket */
	cl = clnttcp_create(&sin, NIBIND_PROG, NIBIND_VERS, 
			    &sock,  0, 0);
	if (cl == NULL) {
		msg = clnt_spcreateerror("binder daemon");
		socket_close(sock);
		FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
		goto failed;
	}
	msg_stage = "connecting (TCP)";
	if ((clstat = clnt_call(cl, NIBIND_GETREGISTER,
				xdr_ni_name, &tag, xdr_nibind_getregister_res,
				res, tv)) != RPC_SUCCESS)  {
		msg = clnt_sperrno(clstat);
		clnt_destroy_lock(cl, sock);
		FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
		goto failed;
	}

	clnt_destroy_lock(cl, sock);
	FD_CLR(sock, &clnt_fdset);	/* unprotect client socket */
	return(TRUE);

    failed:
	sys_msg(debug, LOG_WARNING, "%s's tcp binder connection to %s[%s]/%s "
	       "failed during %s - %s", caller, name, inet_ntoa(sin.sin_addr),
	       tag, msg_stage, msg);
	return(FALSE);
}

/*
 * When a clone completes a readall successfully, we should note that
 * it's current (i.e., up_to_date), so that additional updates that
 * arrive before the next resync cleanup time are propagated.
 */
void
notify_mark_clone(const unsigned long addr)
{
    clone_list clone;
    clone_list found_clone = NULL;
    struct in_addr t_addr;
    /*
     * Find the clone that did the readall.  Mark it as current.
     * XXX If there are multiple interfaces for this clone's host,
     * and the readall came from an interface not listed as running
     * a clone (in the master's /machines), then it's not on our
     * clone list, and it won't be marked as up_to_date.  If there
     * are multiple clones running on one host, we haven't enough
     * information to distinguish among them: all we have is the
     * address of the requesting clone, not its tag.  So, we punt
     * on that one, too. XXX
     */
     for (clone = global_clone_list; clone != NULL; clone = clone->next) {
	/*
	 * Search for the clone (a pain and linear; but should be infrequent).
	 */
	if (addr == clone->addr) {
	    if (NULL == found_clone) {
		found_clone = clone;
	    } else {
		/* Already have one! */
		t_addr.s_addr = addr;
		sys_msg(debug, LOG_DEBUG,
		       "Multiple clones at %s[%s]; can't mark up_to_date",
		       clone->name, inet_ntoa(t_addr));
		return;
	    }
	}
    }
    if (NULL == found_clone) {
	t_addr.s_addr = addr;
	sys_msg(debug, LOG_INFO, "readall completed from unregistered clone at %s",
	       inet_ntoa(t_addr));
	return;
    }

    /* Found exactly one clone for this address.  Mark it up_to_date. */
    t_addr.s_addr = addr;
    mutex_lock(found_clone->lock);
    found_clone->up_to_date = TRUE;
    sys_msg(debug, LOG_INFO, "clone %s[%s]/%s marked current; was%s being skipped",
	   found_clone->name, inet_ntoa(t_addr), found_clone->tag,
	   NO_SEQUENCE_NUMBER == found_clone->lastupdate ? "" : "n't");
    mutex_unlock(found_clone->lock);
}
