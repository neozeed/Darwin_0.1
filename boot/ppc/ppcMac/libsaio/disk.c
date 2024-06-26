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
 * Mach Operating System
 * Copyright (c) 1990 Carnegie-Mellon University
 * Copyright (c) 1989 Carnegie-Mellon University
 * All rights reserved.  The CMU software License Agreement specifies
 * the terms and conditions for use and redistribution.
 */

/*
 *						INTEL CORPORATION PROPRIETARY INFORMATION
 *
 *		This software is supplied under the terms of a license	agreement or
 *		nondisclosure agreement with Intel Corporation and may not be copied
 *		nor disclosed except in accordance with the terms of that agreement.
 *
 *		Copyright 1988, 1989 Intel Corporation
 */

/*
 * Copyright 1993 NeXT Computer, Inc.
 * All rights reserved.
 */

#define DRIVER_PRIVATE

//#include "/usr/include/setjmp.h"
#import "sys/types.h"
#import <bsd/dev/disk.h>
#import <bsd/sys/errno.h>
// #import ARCH_INCLUDE(bsd/dev/, disk.h)
#import "libsaio.h"
#import "memory.h"
#import <SecondaryLoader.h>

extern int gBootPartition;

static Biosread(int biosdev, int secno);
static read_label(char *name, int biosdev, daddr_t *boff, int partition);
void diskActivityHook(void);

/* diskinfo unpacking */
#define SPT(di) 		((di)&0xff)
#define HEADS(di)		((((di)>>8)&0xff)+1)
#define SPC(di) 		(SPT(di)*HEADS(di))
#define BPS 			512 	/* sector size of the device */
#define N_CACHE_SECS	(BIOS_LEN / BPS)

#define HW_BSIZE		512
#define DISKLABEL		15		/* sector num of disk label */

char *devsw[] = {
		"sd",
		"hd",
		"fd",
		NULL
};

struct diskinfo {
		int 	spt;					/* sectors per track */
		int 	spc;					/* sectors per cylinder */
} diskinfo;

char	*b[NBUFS];
daddr_t blknos[NBUFS];
struct	iob iob[NFILES];
int label_secsize;
static int label_cached;

// TEMPORARY
static unsigned int get_diskinfo (int dev)
{
	return (100 << 16) | 100;
}


void
devopen(name, io)
		char			* name;
		struct iob		* io;
{
		long	di;

		//printf ("devopen ('%s')\n", name);

		di = get_diskinfo(io->biosdev);
		if (di == 0) {
			io->i_error = ENXIO;
			return;
		}

		/* initialize disk parameters -- spt and spc */
		io->i_error = 0;
		io->dirbuf_blkno = -1;

		diskinfo.spt = SPT(di);
		diskinfo.spc = diskinfo.spt * HEADS(di);
		if (read_label(name, io->biosdev, &io->i_boff, io->partition) < 0)
		{
				io->i_error = EIO;
		}

//		printf ("devopen returns i_error=%d\n", io->i_error);
}

void devflush()
{
		Biosread(0,-1);
}


int devread(io)
		struct iob *io;
{
	long sector;
	int offset;
	int dev;

	io->i_flgs |= F_RDDATA;

	/* assume the best */
	io->i_error = 0;

	dev = io->i_ino.i_dev;
	sector = io->i_bn * (label_secsize/HW_BSIZE);

	//printf ("devread (bn=%d, sector=%d)\n", io->i_bn, sector);
	VCALL(ReadPartitionBlocks) (kReadRawDisk/*gBootPartition*/, io->i_ma, sector,
								(io->i_cc + kBlockSize - 1) / kBlockSize);
	io->i_flgs &= ~F_TYPEMASK;

	return io->i_cc;
}

#if i386
struct bios_error_info {
	int errno;
	const char *string;
};

#define ECC_CORRECTED_ERR 0x11

static struct bios_error_info bios_errors[] = {
	{0x10, "Media error"},
	{0x11, "Corrected ECC error"},
	{0x20, "Controller or device error"},
	{0x40, "Seek failed"},
	{0x80, "Device timeout"},
	{0xAA, "Drive not ready"},
	{0x00, 0}
};

static const char *
bios_error(int errno)
{
	struct bios_error_info *bp;
	
	for (bp = bios_errors; bp->errno; bp++) {
		if (bp->errno == errno)
			return bp->string;
	}
	return "Error 0x%02x";
}
#endif /* i386 */
/* A haque: Biosread(0,-1) means flush the sector cache.
 */
#if 0
// intbuf is the whole buffer, biosbuf is the current cached sector
static char * const intbuf = (char *)ptov(BIOS_ADDR);
char *biosbuf;

static int
Biosread(int biosdev, int secno)
{
		static int xbiosdev, xcyl=-1, xhead, xsec, xnsecs;

		int 	rc;
		int 	cyl, head, sec;
		int 	spt, spc;
		int tries = 0;

		if (biosdev == 0 && secno == -1) {
			xcyl = -1;
			label_cached = 0;
			return 0;
		}
		spt = diskinfo.spt;
		spc = diskinfo.spc;

		cyl = secno / spc;
		head = (secno % spc) / spt;
		sec = secno % spt;

		if (biosdev == xbiosdev && cyl == xcyl && head == xhead &&
				sec >= xsec && sec < (xsec + xnsecs))
		{		// this sector is in intbuf cache
				biosbuf = intbuf + (BPS * (sec-xsec));
				return 0;
		}

		xcyl = cyl;
		label_cached = 1;
		xhead = head;
		xsec = sec;
		xbiosdev = biosdev;
		xnsecs = ((sec + N_CACHE_SECS) > spt) ? (spt - sec) : N_CACHE_SECS;
		biosbuf = intbuf;

		while ((rc = biosread(biosdev,cyl,head,sec, xnsecs)) && (++tries < 5))
		{
			if (rc == ECC_CORRECTED_ERR) {
				/* Ignore corrected ECC errors */
				break;
			}
#ifndef SMALL
				error("  Disk error: %s\n", bios_error(rc), rc);
				error("    Block %d, Cyl %d Head %d Sector %d\n",
					secno, cyl, head, sec);
#endif
				sleep(1);		// on disk errors, bleh!
		}
		diskActivityHook();
		return rc;
}
#else		// TEMPORARY
static int
Biosread(int biosdev, int secno)
{
	return 0;
}
#endif

// extern char name[];

#ifndef SMALL
static int
read_label(
		char			*name,
		int 			biosdev,
		daddr_t 		*boff,
		int 			partition
)
{
	struct disk_label *dlp;
	static int cached_boff;

	if (label_cached) {
		*boff = cached_boff;
		return 0;
	}

	/* Read the NeXT disk label.
		 * Since we can't count on it fitting in the sector cache,
		 * we'll put it elsewhere.
		 */
	dlp = (struct disk_label *)malloc(sizeof(*dlp) + kBlockSize);
//printf("devopen: gBootPartition=%d, DISKLABEL=%d\n", gBootPartition, DISKLABEL);
	VCALL(ReadPartitionBlocks) (gBootPartition, dlp, DISKLABEL,
								(sizeof (dlp) + kBlockSize - 1) / kBlockSize);
	byte_swap_disklabel_in(dlp);
		
		/* Check label */
		
	if (dlp->dl_version != DL_V3) {
		error("bad disk label magic\n");
		goto error;
	}
			
	label_secsize = dlp->dl_secsize;
		
	if ((dlp->dl_part[partition].p_base) < 0) {
		error("no such partition\n");
		goto error;
	}

//printf("devopen: secsize=%d, front=%d, partition=%d, base=%d\n", dlp->dl_secsize, dlp->dl_front, partition, dlp->dl_part[partition].p_base);

	*boff = cached_boff = dlp->dl_front + dlp->dl_part[partition].p_base;
	label_cached = 1;

	if (!strcmp(name,"$LBL")) strcpy(name, dlp->dl_bootfile);

	free((char *)dlp);
	return 0;

error:
	free((char *)dlp);
	return -1;
}

#endif	SMALL


/* replace this function if you want to change
 * the way disk activity is indicated to the user.
 */

void
diskActivityHook(void)
{
}
