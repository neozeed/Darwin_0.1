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
#ifndef __VNODE_H__
#define __VNODE_H__

#import "automount.h"
#import "RRObject.h"
#import "Array.h"
#import "NFSHeaders.h"

@class Server;
@class String;
@class Map;

struct file_handle
{
	unsigned int node_id;
	char zero[NFS_FHSIZE - sizeof(unsigned int)];
};

@interface Vnode : RRObject
{
	String *path;
	String *name;
	String *src;
	String *link;
	Server *server;
	BOOL mounted;
	BOOL mountPathCreated;
	Vnode *supernode;
	Map *map;
	Array *dirlist;
	Array *subnodes;
	Array *submounts;
	struct fattr attributes;
	int mntArgs;
	struct nfs_args nfsArgs;
	unsigned int mountTime;
	unsigned int timeToLive;
	int mntTimeout;
	unsigned int nfsStatus;
}

- (String *)path;

- (String *)name;
- (void)setName:(String *)n;

- (String *)link;
- (void)setLink:(String *)l;

- (String *)source;
- (void)setSource:(String *)s;

- (Server *)server;
- (void)setServer:(Server *)s;

- (Map *)map;
- (void)setMap:(Map *)m;

- (struct fattr)attributes;
- (void)setAttributes:(struct fattr)a;

- (void)resetTime;
- (void)resetMountTime;

- (ftype)type;
- (void)setType:(ftype)t;

- (unsigned int)mode;
- (void)setMode:(unsigned int)m;

- (unsigned int)nodeID;
- (void)setNodeID:(unsigned int)n;

- (void)setupOptions:(Array *)o;
- (struct nfs_args)nfsArgs;
- (int)mntArgs;
- (void)addMntArg:(int)arg;
- (int)mntTimeout;

- (BOOL)mounted;
- (void)setMounted:(BOOL)m;

- (unsigned int)mountTime;
- (unsigned int)mountTimeToLive;

- (BOOL)mountPathCreated;
- (void)setMountPathCreated:(BOOL)m;

- (unsigned int)nfsStatus;
- (void)setNfsStatus:(unsigned int)s;

- (void)getFileHandle:(nfs_fh *)fh;

- (Vnode *)lookup:(String *)name;

- (Vnode *)parent;
- (void)setParent:(Vnode *)p;

- (Array *)children;
- (void)addChild:(Vnode *)child;
- (void)removeChild:(Vnode *)child;

- (Array *)dirlist;

@end

#endif __VNODE_H__
