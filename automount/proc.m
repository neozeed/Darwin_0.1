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
#import "automount.h"
#import "NFSHeaders.h"
#import <syslog.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import "Controller.h"
#import "Map.h"
#import "log.h"
#import "Vnode.h"
#import "String.h"

#ifndef __APPLE__
#define nfsproc_create_2_svc nfsproc_create_2
#define nfsproc_getattr_2_svc nfsproc_getattr_2
#define nfsproc_link_2_svc nfsproc_link_2
#define nfsproc_lookup_2_svc nfsproc_lookup_2
#define nfsproc_mkdir_2_svc nfsproc_mkdir_2
#define nfsproc_null_2_svc nfsproc_null_2
#define nfsproc_read_2_svc nfsproc_read_2
#define nfsproc_readdir_2_svc nfsproc_readdir_2
#define nfsproc_readlink_2_svc nfsproc_readlink_2
#define nfsproc_remove_2_svc nfsproc_remove_2
#define nfsproc_rename_2_svc nfsproc_rename_2
#define nfsproc_rmdir_2_svc nfsproc_rmdir_2
#define nfsproc_root_2_svc nfsproc_root_2
#define nfsproc_setattr_2_svc nfsproc_setattr_2
#define nfsproc_statfs_2_svc nfsproc_statfs_2
#define nfsproc_symlink_2_svc nfsproc_symlink_2
#define nfsproc_write_2_svc nfsproc_write_2
#define nfsproc_writecache_2_svc nfsproc_writecache_2
#endif

int _rpcpmstart;	/* Started by a port monitor ? */
int _rpcfdtype;		/* Whether Stream or Datagram ? */
int _rpcsvcdirty;	/* Still serving ? */

extern void send_pid_to_parent(void);
extern int doing_timeout;

extern int debug;
extern int debug_proc;

Vnode *new_mount_dir;

#import <stdio.h>
struct debug_file_handle
{
	unsigned int i[8];
};

char *
fhtoc(nfs_fh *fh)
{
	static char str[32];
	struct debug_file_handle *dfh;

	dfh = (struct debug_file_handle *)fh;

	sprintf(str, "%u", dfh->i[0]);
	return str;
}

/*
 * add up sizeof (valid + fileid + name + cookie) - strlen(name)
 */
#define ENTRYSIZE (3 * BYTES_PER_XDR_UNIT + NFS_COOKIESIZE)

/*
 * sizeof(status + eof)
 */
#define JUNKSIZE (2 * BYTES_PER_XDR_UNIT)

attrstat *
nfsproc_getattr_2_svc(nfs_fh *fh, struct svc_req *req)
{
	static attrstat astat;
	struct file_handle *ifh;
	Vnode *n;

	ifh = (struct file_handle *)fh;

	sys_msg(debug_proc, LOG_DEBUG, "-> getattr");
	sys_msg(debug_proc, LOG_DEBUG, "    fh = %s", fhtoc(fh));

	n = [controller vnodeWithID:ifh->node_id];
	if (n == nil)
	{
		sys_msg(debug, LOG_ERR, "getattr for non-existent file handle %s",
			fhtoc(fh));
		astat.status = NFSERR_NOENT;
	}
	else astat.status = [n nfsStatus];

	if (astat.status != NFS_OK)
	{
		sys_msg(debug_proc, LOG_DEBUG, "<- getattr (error %d)", astat.status);
		return(&astat);
	}

	sys_msg(debug_proc, LOG_DEBUG, "    name = %s", [[n name] value]);

	astat.attrstat_u.attributes = [n attributes];
	sys_msg(debug_proc, LOG_DEBUG, "<- getattr");
	return(&astat);
}

/* Does something */
diropres *
nfsproc_lookup_2_svc(diropargs *args, struct svc_req *req)
{
	static diropres res;
	struct file_handle *ifh;
	Vnode *n;
	String *s;

	ifh = (struct file_handle *)&(args->dir);

	sys_msg(debug_proc, LOG_DEBUG, "-> lookup");
	sys_msg(debug_proc, LOG_DEBUG, "    dir fh = %s", fhtoc(&(args->dir)));
	sys_msg(debug_proc, LOG_DEBUG, "    file = %s", args->name);

	n = [controller vnodeWithID:ifh->node_id];
	if (n == nil)
	{
		sys_msg(debug, LOG_ERR, "lookup for non-existent file handle %s",
			fhtoc(&(args->dir)));
		res.status = NFSERR_NOENT;
	}
	else res.status = [n nfsStatus];
	if (res.status != NFS_OK)
	{
		sys_msg(debug_proc, LOG_DEBUG, "<- lookup (error %d)", res.status);
		return(&res);
	}

	s = [String uniqueString:args->name];
	n = [n lookup:s];
	[s release];

	if (n == nil) res.status = NFSERR_NOENT;
	else res.status = [n nfsStatus];
	if (res.status != NFS_OK)
	{
		sys_msg(debug_proc, LOG_DEBUG, "<- lookup (1)");
		return(&res);
	}

	[n getFileHandle:(nfs_fh *)&res.diropres_u.diropres.file];

	sys_msg(debug_proc, LOG_DEBUG, "    return fh = %s",
		fhtoc(&res.diropres_u.diropres.file));

	res.diropres_u.diropres.attributes = [n attributes];

	sys_msg(debug_proc, LOG_DEBUG, "<- lookup");
	return(&res);
}

readlinkres *
nfsproc_readlink_2_svc(nfs_fh *fh, struct svc_req *req)
{
	static readlinkres res;
	struct file_handle *ifh;
	Vnode *n;
	unsigned int status;

	ifh = (struct file_handle *)fh;

	sys_msg(debug_proc, LOG_DEBUG, "-> readlink");
	sys_msg(debug_proc, LOG_DEBUG, "    fh = %s", fhtoc(fh));

	if (doing_timeout) return NULL;

	n = [controller vnodeWithID:ifh->node_id];
	if (n == nil)
	{
		sys_msg(debug, LOG_ERR, "readlink for non-existent file handle %s",
			fhtoc(fh));
		res.status = NFSERR_NOENT;
	}
	else if ([n type] != NFLNK) res.status = NFSERR_ISDIR;
	else res.status = [n nfsStatus];

	if (res.status != NFS_OK)
	{
		return(&res);
		sys_msg(debug_proc, LOG_DEBUG, "<- readlink (1)");
	}

	status = 0;

	if (([n type] == NFLNK) && (![n mounted]))
	{
		status = [[n map] mount:n];
		if (status != 0)
		{
			res.status = NFSERR_NOENT;
			sys_msg(debug_proc, LOG_DEBUG, "<- readlink (2)");
			return(&res);
		}
	}

	sys_msg(debug_proc, LOG_DEBUG, "    name = %s", [[n name] value]);
	sys_msg(debug_proc, LOG_DEBUG, "    link = %s", [[n link] value]);

	res.readlinkres_u.data = [[n link] value];
	sys_msg(debug_proc, LOG_DEBUG, "<- readlink");
	return(&res);
}

/* Does something */
readdirres *
nfsproc_readdir_2_svc(readdirargs *args, struct svc_req *req)
{
	static readdirres res;
	Vnode *n, *v;
	struct entry *e, *nexte;
	struct entry **entp;
	unsigned int cookie, count, entrycount, i, nlist;
	struct file_handle *ifh;
	Array *list;
	String *s;

	ifh = (struct file_handle *)&(args->dir);
	cookie = *(unsigned int*)args->cookie;

	sys_msg(debug_proc, LOG_DEBUG, "-> readdir");
	sys_msg(debug_proc, LOG_DEBUG, "    dir fh = %s", fhtoc(&(args->dir)));
	sys_msg(debug_proc, LOG_DEBUG, "    cookie = %u", cookie);
	sys_msg(debug_proc, LOG_DEBUG, "    count = %u", args->count);

	/*
	 * Free up old stuff
	 */
	e = res.readdirres_u.reply.entries;
	while (e != NULL)
	{
		nexte = e->nextentry;
		free(e);
		e = nexte;
	}
	res.readdirres_u.reply.entries = NULL;

	n = [controller vnodeWithID:ifh->node_id];
	if (n == nil)
	{
		sys_msg(debug, LOG_ERR, "readdir for non-existent file handle %s",
			fhtoc(&(args->dir)));
		res.status = NFSERR_NOENT;
	}
	else if ([n type] != NFDIR) res.status = NFSERR_NOTDIR;
	else res.status = [n nfsStatus];
	if (res.status != NFS_OK)
	{
		sys_msg(debug_proc, LOG_DEBUG, "<- readdir (1)");
		return(&res);
	}

	sys_msg(debug_proc, LOG_DEBUG, "    name = %s", [[n name] value]);

	list = [n dirlist];
	nlist = [list count];

	count = JUNKSIZE;

	entrycount = 0;
	entp = &res.readdirres_u.reply.entries;

	for (i = cookie; i < nlist; i++)
	{
		v = [list objectAtIndex:i];

		if (i == 0) s = dot;
		else if (i == 1) s = dotdot;
		else s = [v name];

		count += ENTRYSIZE;
		count += [s length];
		if (count > args->count)
		{
			sys_msg(debug_proc, LOG_DEBUG, "        BREAK");
			break;
		}

		sys_msg(debug_proc, LOG_DEBUG, "        %4u: %u %s",
			cookie, [v nodeID], [s value]);

		*entp = (struct entry *) malloc(sizeof(struct entry));
		bzero(*entp, sizeof(struct entry));

		(*entp)->fileid = [v nodeID];
		(*entp)->name = [s value];
		*(unsigned int*)((*entp)->cookie) = ++cookie;
		(*entp)->nextentry = NULL;
		entp = &(*entp)->nextentry;
	}

	if (i < nlist) res.readdirres_u.reply.eof = FALSE;
	else res.readdirres_u.reply.eof = TRUE;

	sys_msg(debug_proc, LOG_DEBUG, "    eof = %s",
		res.readdirres_u.reply.eof ? "TRUE" : "FALSE");

	[list release];

	sys_msg(debug_proc, LOG_DEBUG, "<- readdir");
	return(&res);
}
	
statfsres *
nfsproc_statfs_2_svc(nfs_fh *fh, struct svc_req *req)
{
	static statfsres res;

	sys_msg(debug_proc, LOG_DEBUG, "-> statfs");

	res.status = NFS_OK;
	res.statfsres_u.reply.tsize = 512;
	res.statfsres_u.reply.bsize = 512;
	res.statfsres_u.reply.blocks = 0;
	res.statfsres_u.reply.bfree = 0;
	res.statfsres_u.reply.bavail = 0;

	sys_msg(debug_proc, LOG_DEBUG, "<- statfs");
	return(&res);
}

/*
 * These routines do nothing - they should never even be called!
 */
void *
nfsproc_null_2_svc(void *x, struct svc_req *req)
{
	sys_msg(debug_proc, LOG_DEBUG, "-- null");
	return((void *)NULL);
}

attrstat *
nfsproc_setattr_2_svc(sattrargs *args, struct svc_req *req)
{
	static attrstat astat;

	sys_msg(debug_proc, LOG_DEBUG, "-- setattr");
	 astat.status = NFSERR_ROFS;
	return(&astat);
}

void *
nfsproc_root_2_svc(void *x, struct svc_req *req)
{
	sys_msg(debug_proc, LOG_DEBUG, "-- root");
	return(NULL);
}

readres *
nfsproc_read_2_svc(readargs *args, struct svc_req *req)
{
	static readres res;

	sys_msg(debug_proc, LOG_DEBUG, "-- read");
	res.status = NFSERR_ISDIR;	/* XXX: should return better error */
	return(&res);
}

void *
nfsproc_writecache_2_svc(void *x, struct svc_req *req)
{
	sys_msg(debug_proc, LOG_DEBUG, "-- writecache");
	return(NULL);
}	

attrstat *
nfsproc_write_2_svc(writeargs *args, struct svc_req *req)
{
	static attrstat res;

	sys_msg(debug_proc, LOG_DEBUG, "-- write");
	res.status = NFSERR_ROFS;	/* XXX: should return better error */
	return(&res);
}

diropres *
nfsproc_create_2_svc(createargs *args, struct svc_req *req)
{
	static diropres res;

	sys_msg(debug_proc, LOG_DEBUG, "-- create");
	res.status = NFSERR_ROFS;
	return(&res);
}

nfsstat *
nfsproc_remove_2_svc(diropargs *args, struct svc_req *req)
{
	static nfsstat status;

	sys_msg(debug_proc, LOG_DEBUG, "-- remove");
	status = NFSERR_ROFS;
	return(&status);
}

nfsstat *
nfsproc_rename_2_svc(renameargs *args, struct svc_req *req)
{
	static nfsstat status;

	sys_msg(debug_proc, LOG_DEBUG, "-- rename");
	status = NFSERR_ROFS;
	return(&status);
}

nfsstat *
nfsproc_link_2_svc(linkargs *args, struct svc_req *req)
{
	static nfsstat status;

	sys_msg(debug_proc, LOG_DEBUG, "-- link");
	status = NFSERR_ROFS;
	return(&status);
}

nfsstat *
nfsproc_symlink_2_svc(symlinkargs *args, struct svc_req *req)
{
	static nfsstat status;

	sys_msg(debug_proc, LOG_DEBUG, "-- symlink");
	status = NFSERR_ROFS;
	return(&status);
}

diropres *
nfsproc_mkdir_2_svc(createargs *args, struct svc_req *req)
{
	static diropres res;

	sys_msg(debug_proc, LOG_DEBUG, "-- mkdir");
	res.status = NFSERR_ROFS;
	return(&res);
}

nfsstat *
nfsproc_rmdir_2_svc(diropargs *args, struct svc_req *req)
{
	static nfsstat status;

	sys_msg(debug_proc, LOG_DEBUG, "-- rmdir");
	status = NFSERR_ROFS;
	return(&status);
}
