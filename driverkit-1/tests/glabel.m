/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * Portions Copyright (c) 1999 Apple Computer, Inc.  All Rights
 * Reserved.  This file contains Original Code and/or Modifications of
 * Original Code as defined in and that are subject to the Apple Public
 * Source License Version 1.1 (the "License").  You may not use this file
 * except in compliance with the License.  Please obtain a copy of the
 * License at http://www.apple.com/publicsource and read it before using
 * this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON- INFRINGEMENT.  Please see the
 * License for the specific language governing rights and limitations
 * under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * glabel.m
 * This does not currently work because of a bug in DO (dealing with
 * returning more than a page of data).
 */

#import <bsd/sys/types.h> 
#import <remote/NXConnection.h>
#import <driverkit/IODiskPartition.h>
#import <stdio.h>
#import <libc.h>
#import "defaults.h"
#import "buflib.h"

void usage(char **argv);
void exit(int exitcode);

int main(int argc, char **argv) {

	char *hostname=HOST_DEFAULT;
	char *devname=DEVICE_DEFAULT;
	int arg;
	char c;
	id targetId;
	IOReturn rtn;
	char outstr[100];
	struct disk_label label;
	
	/*
	 * Get standard defaults from environment or defaults.h
	 */
	get_default_t("hostname", &hostname, HOST_DEFAULT);
	get_default_t("devname", &devname, DEVICE_DEFAULT);

	for(arg=1; arg<argc; arg++) {
		c = argv[arg][0];
		switch(c) {
		    case 'h':
		    	hostname = &argv[arg][2];
			break;
		    case 'd':
		    	devname = &argv[arg][2];
			break;
		    default:
		    	usage(argv);
		}
	}
	
	targetId = [NXConnection connectToName:devname
					 onHost:hostname];
	if(targetId == nil) {
		printf("connectToName:%s failed\n", devname);
		exit(1);
	}
	rtn = [targetId readLabel:&label];
	if(rtn) {
		sprintf(outstr, "Error on readLabel: %s\n",
			[targetId stringFromReturn:rtn]);
		printf(outstr);
		exit(1);
	}
	else {
		/*
		 * dump some label shit here
		 */
		printf("\tdl_version    0x%x\n", label.dl_version);
		printf("\tdl_label      %s\n",   label.dl_label);
		printf("\tdl_dt.d_name  %s\n",    label.dl_dt.d_name);
		printf("\tdl_dt.d_type  %s\n",    label.dl_dt.d_type);
	}
	exit(0);

} /* main() */

void usage(char **argv) {
	printf("usage: %s [h=hostname] [d=devname]\n", argv[0]);
	exit(1);
}




