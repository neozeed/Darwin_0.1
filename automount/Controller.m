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
#import "Controller.h"
#import "automount.h"
#import "Server.h"
#import "String.h"
#import "Vnode.h"
#import "FstabMap.h"
#import "FileMap.h"
#import "NIMap.h"
#import "log.h"
#import <unistd.h>
#import <stdio.h>
#import <syslog.h>
#import <stdlib.h>
#import <string.h>
#import <errno.h>
#import <sys/socket.h>
#import <sys/param.h>
#import <sys/types.h>
#import <sys/stat.h>
#import "nfs_prot.h"
#import <mach/cthreads.h>
#import <arpa/nameser.h>
#import <netinfo/ni.h>
#import <resolv.h>
#ifdef __APPLE__
extern int mount(const char *, const char *, int, void *);
extern int unmount(const char *, int);
#else
#import <libc.h>
#import <sys/file.h>
extern int getpid(void);
extern int mkdir(const char *, int);
extern int chdir(const char *);
#endif

#define HOSTINFO "/usr/bin/hostinfo"
#define RHAPSODY_SYSTEM "/System/Library/Frameworks/System.framework"
#define OPENSTEP_SYSTEM "/NextLibrary/Frameworks/System.framework"
#define OS_NEXTSTEP 0
#define OS_OPENSTEP 1
#define OS_RHAPSODY 2

extern void nfs_program_2();

@implementation Controller

- (Controller *)init:(char *)dir
{
	Vnode *root;
	char str[1024], *p;
	FILE *pf;
	float vers;
	struct stat sb;

	[super init];

	node_table_count = 0;
	server_table_count = 0;
	map_table_count = 0;

	node_id = 2;

	controller = self;

	mountDirectory = [String uniqueString:dir];
	rootMap = [[Map alloc] initWithParent:nil directory:mountDirectory];

	root = [rootMap root];

	transp = svcudp_create(RPC_ANYSOCK);
	if (transp == NULL)
	{
		sys_msg(debug, LOG_ERR, "Cannot create UDP service");
		[self release];
		return nil;
	}

	if (!svc_register(transp, NFS_PROGRAM, NFS_VERSION, nfs_program_2, 0))
	{
		sys_msg(debug, LOG_ERR, "svc_register failed");
		[self release];
		return nil;
	}

	gethostname(str, 1024);
	p = strchr(str, '.');
	if (p != NULL) *p = '\0';
	hostName = [String uniqueString:str];

	hostDNSDomain = nil;
	res_init();
	if (_res.options & RES_INIT)
	{
		hostDNSDomain = [String uniqueString:_res.defdname];
	}

	hostArchitecture = [String uniqueString:__ARCHITECTURE__];

	hostByteOrder = nil;

#ifdef __BIG_ENDIAN__
	hostByteOrder = [String uniqueString:"big"];
#else
	hostByteOrder = [String uniqueString:"little"];
#endif

	if (stat(RHAPSODY_SYSTEM, &sb) == 0)
	{
		hostOS = [String uniqueString:"rhapsody"];
		osType = OS_RHAPSODY;
	}
	else if (stat(OPENSTEP_SYSTEM, &sb) == 0)
	{
		hostOS = [String uniqueString:"openstep"];
		osType = OS_OPENSTEP;
	}
	else
	{
		hostOS = [String uniqueString:"nextstep"];
		osType = OS_NEXTSTEP;
	}

	pf = popen(HOSTINFO, "r");
	fscanf(pf, "%*[^\n]%*c");
	if (osType == OS_RHAPSODY) fscanf(pf, "%*s%*s%*s%*s%f", &vers);
	else fscanf(pf, "%*s%*s%f", &vers);
	pclose(pf);
	
	sprintf(str, "%g", vers);
	hostOSVersion = [String uniqueString:str];
	hostOSVersionMajor = vers;
	p = strchr(str, '.');
	if (p == NULL) hostOSVersionMinor = 0;
	else hostOSVersionMinor = atoi(p+1);

	return self;
}

- (BOOL)createPath:(String *)path
{
	int i, p;
	char *s, t[1024];
	int status;

	if (path == nil) return YES;
	if ([path length] == 0) return YES;

	p = 0;
	s = [path value];

	chdir("/");

	while (s != NULL)
	{
		if (s[0] == '/')
		{
			p++;
			s++;
		}
		for (i = 0; (s[i] != '/') && (s[i] != '\0'); i++) t[i] = s[i];
		t[i] = '\0';
		if (i == 0)
		{
			s = [path scan:'/' pos:&p];
			continue;
		}

		status = mkdir(t, 0755);
		if (status == -1)
		{
			 if (errno == EEXIST) status = 0;
			 if (errno == EISDIR) status = 0;
		}

		if (status != 0) return NO;

		chdir(t);
		s = [path scan:'/' pos:&p];
	}

	chdir("/");
	return YES;
}

- (void)registerVnode:(Vnode *)v
{
	[v setNodeID:node_id];

	if (node_table_count == 0)
		node_table = (node_table_entry *)malloc(sizeof(node_table_entry));
	else
		node_table = (node_table_entry *)realloc(node_table,
			(node_table_count + 1) * sizeof(node_table_entry));

	node_table[node_table_count].node_id = node_id;
	node_table[node_table_count].node = v;

	node_table_count++;
	node_id++;
}

- (Vnode *)vnodeWithID:(unsigned int)n
{
	int i;
	Vnode *v;

	for (i = 0; i < node_table_count; i++)
	{
		if (node_table[i].node_id == n)
		{
			v = node_table[i].node;
			[v resetTime];
			return v;
		}
	}

	return nil;
}

- (void)destroyVnode:(Vnode *)v
{
	int i;
	unsigned int n, count;
	BOOL searching;
	Array *kids;
	Vnode *p;

	n = [v nodeID];

	searching = YES;
	for (i = 0; (i < node_table_count) && searching; i++)
	{
		if (node_table[i].node == v) searching = NO;
	}

	if (searching)
	{
		sys_msg(debug, LOG_ERR, "Unreferenced Vnode %u (%s)",
			n, [[v path] value]);
		return;
	}

	for(; i < node_table_count; i++) node_table[i-1] = node_table[i];

	node_table_count--;
	if (node_table_count == 0)
		free(node_table);
	else
		node_table = (node_table_entry *)realloc(node_table,
		node_table_count * sizeof(node_table_entry));

	kids = [v children];
	if (kids == nil) count = 0;
	else count = [kids count];

	for (i = count - 1; i >= 0; i--)
		[self destroyVnode:[kids objectAtIndex:i]];

	p = [v parent];
	if (p != nil) [p removeChild:v];
	[v release];
}

- (unsigned int)automount:(Vnode *)v directory:(String *)dir args:(int)mntargs
{
	struct nfs_args args;
	struct sockaddr_in sin;
	struct file_handle fh;
	char str[MAXPATHLEN + 64];
	String *src;
	int status;

	[self createPath:dir];

	src = [v source];

	bzero(&sin, sizeof(struct sockaddr_in));
	sin.sin_family = AF_INET;
	sin.sin_port = htons(transp->xp_port);
	sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

	bzero(&args, sizeof(args));

#ifdef __APPLE__
	args.addr = (struct sockaddr *)&sin;
	args.version = NFS_ARGSVERSION;
	args.addrlen = sizeof(struct sockaddr_in);
	args.sotype = SOCK_DGRAM;
	args.proto = IPPROTO_UDP;
	args.readdirsize = NFS_READDIRSIZE;
	args.maxgrouplist = NFS_MAXGRPS;
	args.readahead = NFS_DEFRAHEAD;
	args.fhsize = sizeof(nfs_fh);
	args.flags = NFSMNT_INT | NFSMNT_TIMEO | NFSMNT_RETRANS;
	args.wsize = NFS_WSIZE;
	args.rsize = NFS_RSIZE;
#else
	args.addr = (struct sockaddr_in *)&sin;
	args.flags = NFSMNT_INT | NFSMNT_TIMEO | NFSMNT_RETRANS;
	args.wsize = NFS_WSIZE;
	args.rsize = NFS_RSIZE;
#endif

	args.timeo = 1;
	args.retrans = 5;

	bzero(&fh, sizeof(nfs_fh));
	fh.node_id = [v nodeID];

	args.fh = (u_char *)&fh; 
	sprintf(str, "automount %s [%d]", [src value], getpid());
	args.hostname = str;

	sys_msg(debug, LOG_DEBUG, "Mounting map %s on %s",
		[src value], [dir value]);

#ifdef __APPLE__
	status = mount("nfs", [dir value], mntargs, &args);
#else
	status = mount(MOUNT_NFS, [dir value], mntargs, (caddr_t)&args);
#endif
	if (status != 0)
	{
		sys_msg(debug, LOG_ERR, "Can't mount map %s on %s: %s",
			[src value], [dir value], strerror(errno));
		return 1;
	}

	[v setMounted:YES];
#ifndef __APPLE__
	[self mtabUpdate:v];
#endif

	return 0;
}

- (BOOL)isFile:(String *)name
{
	struct stat sb;
	int status;

	if (name == nil) return NO;

	status = stat([name value], &sb);
	if (status != 0)
	{
		sys_msg(debug, LOG_ERR, "%s: %s", [name value], strerror(errno));
		return NO;
	}

	if (!(sb.st_mode & S_IFREG))
	{
		sys_msg(debug, LOG_ERR, "%s: Not a file", [name value]);
		return NO;
	}

	return YES;
}

- (unsigned int)autoMap:(Map *)map name:(String *)name directory:(String *)dir
{
	Vnode *maproot;
	unsigned int status;

	maproot = [map root];
	[maproot setSource:name];
	[maproot setLink:dir];

	if (map_table_count == 0)
		map_table = (map_table_entry *)malloc(sizeof(map_table_entry));
	else
		map_table = (map_table_entry *)realloc(map_table,
			(map_table_count + 1) * sizeof(map_table_entry));

	map_table[map_table_count].name = [name retain];
	map_table[map_table_count].dir = [dir retain];
	map_table[map_table_count].map = map;

	map_table_count++;

	status = [self automount:maproot directory:dir args:[map mountArgs]];
	if (status != 0) return status;

	status = [map didAutoMount];
	return status;
}

- (unsigned int)mountmap:(String *)mapname directory:(String *)dir
{
	Vnode *root, *p;
	Map *map;
	char *s, *t;
	String *parent, *mountpt;

	root = [rootMap root];
	s = malloc([dir length] + 1);
	sprintf(s, "%s", [dir value]);
	t = strrchr(s, '/');
	if (t == NULL) 
	{
		sys_msg(debug, LOG_ERR, "Invalid directory \"%s\"", [dir value]);
		free(s);
		return 1;
	}

	*t++ = '\0';
	parent = [String uniqueString:s];
	mountpt = [String uniqueString:t];
	free(s);
	p = [rootMap createVnodePath:parent from:root];
	[parent release];

	sys_msg(debug, LOG_DEBUG, "Initializing map \"%s\"", [mapname value]);
	if (strcmp([mapname value], "-fstab") == 0)
	{
		map = [[FstabMap alloc]
			initWithParent:p directory:mountpt from:mapname];
	}
	else if (strncmp([mapname value], "/", 1))
	{
		map = [[NIMap alloc]
			initWithParent:p directory:mountpt from:mapname];
	}
	else if ([self isFile:mapname])
	{
		map = [[FileMap alloc]
			initWithParent:p directory:mountpt from:mapname];
	}
	else if (strcmp([mapname value], "-null") == 0)
	{
		map = [[Map alloc] initWithParent:p directory:mountpt];
	}
	else
	{
		sys_msg(debug, LOG_ERR, "Unknown map \"%s\"", [mapname value]);
		return 1;
	}

	[mountpt release];

	if (map == nil)
	{
		sys_msg(debug, LOG_ERR, "Map \"%s\" failed to initialize",
			[mapname value]);
		return 1;
	}

	return [self autoMap:map name:mapname directory:dir];
}

- (Map *)rootMap
{
	return rootMap;
}

- (unsigned int)nfsmount:(Vnode *)v
{
	struct sockaddr_in sin;
	struct nfs_args args;
	char str[1024];
	struct file_handle fh;
	Server *s;
	unsigned int status;

	if ([v mounted])
	{
		sys_msg(debug_mount, LOG_DEBUG, "%s is already mounted",
			[[v link] value]);
		[v setNfsStatus:NFS_OK];
		return 0;
	}

	if ([v source] == nil)
	{
		[v setMounted:YES];
		return 0;
	}

	s = [v server];
	if (s == nil)
	{
		sys_msg(debug, LOG_ERR, "No file server for %s", [[v link] value]);
		[v setNfsStatus:NFSERR_NXIO];
		return 1;
	}

	if (![v mountPathCreated])
	{
		if (![self createPath:[v link]])
		{
			sys_msg(debug, LOG_ERR, "Can't create mount point %s",
				[[v link] value]);
			[v setNfsStatus:NFSERR_IO];
			return 1;
		}
		[v setMountPathCreated:YES];
	}

	sprintf(str, "%s:%s", [[s name] value], [[v source] value]);

	[s setTimeout:[v mntTimeout]];
	sys_msg(debug_mount, LOG_DEBUG, "Fetching NFS filehandle for %s", str);
	status = [s getHandle:(nfs_fh *)&fh forFile:[v source]];
	if (status != 0)
	{
		[v setNfsStatus:status];
		return 1;
	}

	bzero(&sin, sizeof(struct sockaddr_in));
	sin.sin_family = AF_INET;
	sin.sin_port = htons([s nfsPort]);
	sin.sin_addr.s_addr = [s address];

	args = [v nfsArgs];
#ifdef __APPLE__
	args.addr = (struct sockaddr *)&sin;
#else
	args.addr = (struct sockaddr_in *)&sin;
#endif
	args.fh = (u_char *)&fh; 
	args.hostname = str;

	sys_msg(debug, LOG_DEBUG, "Mounting %s on %s",
		str, [[v link] value]);

#ifdef __APPLE__
	status = mount("nfs", [[v link] value], [v mntArgs], &args);
#else
	status = mount(MOUNT_NFS, [[v link] value], [v mntArgs], (caddr_t)&args);
#endif
	if (status != 0)
	{
		sys_msg(debug, LOG_ERR, "Can't mount %s on %s: %s",
			str, [[v link] value], strerror(errno));
		[v setNfsStatus:NFSERR_IO];
		return 1;
	}

	sys_msg(debug_mount, LOG_DEBUG, "Completed mounting %s on %s",
		str, [[v link] value]);

	/* Tell the node that it was mounted */
	[v setMounted:YES];
#ifndef __APPLE__
	[self mtabUpdate:v];
#endif

	return 0;
}

- (Server *)serverWithName:(String *)name
{
	int i;
	Server *s;

	for (i = 0; i < server_table_count; i++)
	{
		if ([name equal:server_table[i].name])
			return server_table[i].server;
	}

	s = [[Server alloc] initWithName:name];
	if (s == nil)
	{
		sys_msg(debug, LOG_ERR, "Unknown server: %s", [name value]);
		return nil;
	}

	if (server_table_count == 0)
		server_table = (server_table_entry *)malloc(sizeof(server_table_entry));
	else
		server_table = (server_table_entry *)realloc(server_table,
			(server_table_count + 1) * sizeof(server_table_entry));

	server_table[server_table_count].name = [name retain];
	server_table[server_table_count].server = s;

	server_table_count++;

	return s;
}

- (void)timeout
{
	int i;
	
	/* Tell maps to try to unmount */
	for (i = 0; i < map_table_count; i++) [map_table[i].map timeout];
}

- (void)showNode:(int)n
{
	char msg[1024];
	Vnode *v;

	v = node_table[n].node;
	msg[0] = '\0';

	sprintf(msg, "%4d", n);
	strcat(msg, ": ");
	strcat(msg, [[v name] value]);
	if ([v type] == NFLNK)
	{
		if ([v mounted]) strcat(msg, " <-- ");
		else strcat(msg, " ... ");

		strcat(msg, [[[v server] name] value]);
		strcat(msg, ":");
		strcat(msg, [[v source] value]);
	}

	sys_msg(debug, LOG_DEBUG, "%s", msg);
}

- (void)reInit
{
}

- (void)dealloc
{
	int i;
	int status;
	Vnode *v;

	chdir("/");

	/* unmount normal NFS mounts */
	for (i = node_table_count - 1; i >= 0; i--)
	{
		v = node_table[i].node;

		if ([v server] == nil) continue;
		if ([v source] == nil) [v setMounted:NO];
		if ([[v server] isLocalHost]) [v setMounted:NO];

		if (![v mounted]) continue;

#ifdef __APPLE__
		status = unmount([[v link] value], 0);
		if (status != 0)
		{
			status = unmount([[v link] value], MNT_FORCE);
		}
#else
		status = unmount([[v link] value]);
#endif

		if (status == 0)	
		{
			[v setMounted:NO];
#ifndef __APPLE__
			[self mtabUpdate:v];
#endif
			sys_msg(debug, LOG_DEBUG, "Unmounted %s", [[v link] value]);
		}
		else
		{
			sys_msg(debug, LOG_DEBUG, "Unmount failed for %s: %s",
				[[v link] value], strerror(errno));
		}
	}
	
	/* unmount automounter */
	for (i = node_table_count - 1; i >= 0; i--)
	{
		v = node_table[i].node;

		if ([v server] != nil) continue;
		if (![v mounted]) continue;
		if ([v link] == nil) continue;

#ifdef __APPLE__
		status = unmount([[v link] value], 0);
		if (status != 0)
		{
			status = unmount([[v link] value], MNT_FORCE);
		}
#else
		status = unmount([[v link] value]);
#endif
		if (status == 0)	
		{
			[v setMounted:NO];
#ifndef __APPLE__
			[self mtabUpdate:v];
#endif
			sys_msg(debug, LOG_DEBUG, "Unmounted %s", [[v link] value]);
		}
		else
		{
			sys_msg(debug, LOG_DEBUG, "Unmount failed for %s: %s",
				[[v link] value], strerror(errno));
		}
	}
	
	for (i = 0; i < map_table_count; i++)
	{
		[map_table[i].name release];
		[map_table[i].dir release];
		[map_table[i].map release];
	}
	free(map_table);

	for (i = 0; i < node_table_count; i++)
	{
		[node_table[i].node release];
	}
	free(node_table);

	for (i = 0; i < server_table_count; i++)
	{
		[server_table[i].name release];
		[server_table[i].server release];
	}
	free(server_table);

	if (hostName != nil) [hostName release];
	if (hostDNSDomain != nil) [hostDNSDomain release];
	if (hostArchitecture != nil) [hostArchitecture release];
	if (hostByteOrder != nil) [hostByteOrder release];
	if (hostOS != nil) [hostOS release];
	if (hostOSVersion != nil) [hostOSVersion release];

	[super dealloc];
}

- (unsigned int)attemptUnmount:(Vnode *)v
{
	int status;

	if (v == nil) return EINVAL;

	if (![v mounted]) return 0;

	if ([v type] != NFLNK) return EINVAL;

	if ([v source] == nil)
	{
		[v setMounted:NO];
		return 0;
	}

	sys_msg(debug_mount, LOG_DEBUG, "Attempting to unmount %s",
		[[v link] value]);
#ifdef __APPLE__
	status = unmount([[v link] value], 0);
#else
	status = unmount([[v link] value]);
#endif
	if (status == 0)
	{
		sys_msg(debug, LOG_DEBUG, "Unmounted %s", [[v link] value]);
		[v setMounted:NO];
#ifndef __APPLE__
		[self mtabUpdate:v];
#endif
		return 0;
	}

	sys_msg(debug_mount, LOG_DEBUG, "Unmount %s failed: %s",
		[[v link] value], strerror(errno));

	[v resetMountTime];
	return 1;
}

- (void)printTree
{
	int i;

	for (i = 0; i < map_table_count; i++)
	{
		sys_msg(debug, LOG_DEBUG, "Map %s   Directory %s",
			[map_table[i].name value], [map_table[i].dir value]);

		[self printNode:[map_table[i].map root] level:0];
	}
}

- (void)printNode:(Vnode *)v level:(unsigned int)l
{
	unsigned int i, len;
	Array *kids;
	char msg[1024];

	if (v == nil) return;

	msg[0] = '\0';
	strcat(msg, "  ");

	len = l * 4;
	for (i = 0; i < len; i++) strcat(msg, " ");

	strcat(msg, [[v name] value]);
	if ([v type] == NFLNK)
	{
		if ([v mounted]) strcat(msg, " <-- ");
		else strcat(msg, " ... ");

		strcat(msg, [[[v server] name] value]);
		if ([v source] != nil)
		{
			strcat(msg, ":");
			strcat(msg, [[v source] value]);
		}
	}

	sys_msg(debug, LOG_DEBUG, "%s", msg);

	kids = [v children];
	len = 0;
	if (kids != nil) len = [kids count];

	for (i = 0; i < len; i++)
	{
		[self printNode:[kids objectAtIndex:i] level:l+1];
		usleep(100);
	}
}

- (String *)mountDirectory
{
	return mountDirectory;
}

- (String *)hostName
{
	return hostName;
}

- (String *)hostDNSDomain
{
	return hostDNSDomain;
}

- (String *)hostArchitecture
{
	return hostArchitecture;
}

- (String *)hostByteOrder
{
	return hostByteOrder;
}

- (String *)hostOS
{
	return hostOS;
}

- (String *)hostOSVersion
{
	return hostOSVersion;
}

- (int)hostOSVersionMajor
{
	return hostOSVersionMajor;
}

- (int)hostOSVersionMinor
{
	return hostOSVersionMinor;
}

#ifndef __APPLE__
- (void)mtabUpdate:(Vnode *)v
{
	FILE *f, *g;
	char line[1024], target[1024];
	unsigned int vid, pid, len;

	vid = [v nodeID];
	pid = getpid();

	if ([v server] == nil)
	{
		sprintf(target, "<automount>:%s \"%s\" nfs auto %u %u",
			[[[v map] name] value], [[v link] value], vid, pid);
	}
	else
	{
		sprintf(target, "%s:%s \"%s\" nfs auto %u %u",
			[[[v server] name] value], [[v source] value],
			[[v link] value], vid, pid);
	}

	if ([v mounted])
	{
		f = fopen("/etc/mtab", "a");
		if (f == NULL)
		{
			sys_msg(debug, LOG_ERR, "Can't write /etc/mtab: %s",
				strerror(errno));
			return;
		}

		fprintf(f, "%s\n", target);
		fclose(f);
		return;
	}

	f = fopen("/etc/mtab", "r");
	if (f == NULL)
	{
		sys_msg(debug, LOG_ERR, "Can't read /etc/mtab: %s", strerror(errno));
		return;
	}

	g = fopen("/etc/auto_mtab", "w");
	if (f == NULL)
	{
		sys_msg(debug, LOG_ERR, "Can't create /etc/auto_mtab: %s",
			strerror(errno));
		return;
	}

	len = strlen(target);

	while (fgets(line, 1024, f))
	{
		if (strncmp(line, target, len)) fprintf(g, "%s", line);
	}

	fclose(f);
	fclose(g);
	rename("/etc/auto_mtab", "/etc/mtab");
}
#endif

@end
