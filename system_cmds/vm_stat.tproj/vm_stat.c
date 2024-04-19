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
 *	File:	vm_stat.c
 *	Author:	Avadis Tevanian, Jr.
 *
 *	Copyright (C) 1986, Avadis Tevanian, Jr.
 *
 *
 *	Display Mach VM statistics.
 *
 ************************************************************************
 * HISTORY
 *  6-Jun-86  Avadis Tevanian, Jr. (avie) at Carnegie-Mellon University
 *	Use official Mach interface.
 *
 ************************************************************************
 */

#include <stdio.h>

#include <mach/mach.h>

struct vm_statistics	vm_stat, last;
int	percent;


int	delay;
char	*pgmname;

main(argc, argv)
	int	argc;
	char	*argv[];
{
	pgmname = argv[0];
	delay = 0;
#ifdef NeXT_MOD	
	setlinebuf (stdout);
#endif NeXT_MOD
	if (argc == 2) {
		if (sscanf(argv[1], "%d", &delay) != 1)
			usage();
		if (delay < 0)
			usage();
	}

	if (delay == 0) {
		snapshot();
	}
	else {
		while (1) {
			print_stats();
			sleep(delay);
		}
	}
}

usage()
{
	fprintf(stderr, "usage: %s [ repeat-interval ]\n", pgmname);
	exit(1);
}

banner()
{
	get_stats(&vm_stat);
	printf("Mach Virtual Memory Statistics: ");
	printf("(page size of %d bytes, cache hits %d%%)\n",
				vm_stat.pagesize, percent);
	printf("%6s %6s %4s %4s %8s %8s %8s %8s %8s %8s\n",
		"free",
		"active",
		"inac",
		"wire",
		"faults",
		"copy",
		"zerofill",
		"reactive",
		"pageins",
		"pageout");
	bzero(&last, sizeof(last));
}
snapshot()
{

	get_stats(&vm_stat);
	printf("Mach Virtual Memory Statistics: (page size of %d bytes)\n",
				vm_stat.pagesize);
	pstat("Pages free:", vm_stat.free_count);
	pstat("Pages active:", vm_stat.active_count);
	pstat("Pages inactive:", vm_stat.inactive_count);
	pstat("Pages wired down:", vm_stat.wire_count);
	pstat("\"Translation faults\":", vm_stat.faults);
	pstat("Pages copy-on-write:", vm_stat.cow_faults);
	pstat("Pages zero filled:", vm_stat.zero_fill_count);
	pstat("Pages reactivated:", vm_stat.reactivations);
	pstat("Pageins:", vm_stat.pageins);
	pstat("Pageouts:", vm_stat.pageouts);
	printf("Object cache: %d hits of %d lookups (%d%% hit rate)\n",
			vm_stat.hits, vm_stat.lookups, percent);
}

pstat(str, n)
	char	*str;
	int	n;
{
	printf("%-25s %10d.\n", str, n);
}

print_stats()
{
	static count = 0;

	if (count++ == 0)
		banner();

	if (count > 20)
		count = 0;

	get_stats(&vm_stat);
	printf("%6d %6d %4d %4d %8d %8d %8d %8d %8d %8d\n",
		vm_stat.free_count,
		vm_stat.active_count,
		vm_stat.inactive_count,
		vm_stat.wire_count,
		vm_stat.faults - last.faults,
		vm_stat.cow_faults - last.cow_faults,
		vm_stat.zero_fill_count - last.zero_fill_count,
		vm_stat.reactivations - last.reactivations,
		vm_stat.pageins - last.pageins,
		vm_stat.pageouts - last.pageouts);
	last = vm_stat;
}

get_stats(stat)
	struct vm_statistics	*stat;
{
	if (vm_statistics(current_task(), stat) != KERN_SUCCESS) {
		fprintf(stderr, "%s: failed to get statistics.\n", pgmname);
		exit(2);
	}
	if (stat->lookups == 0)
		percent = 0;
	else
		percent = (stat->hits*100)/stat->lookups;
}
