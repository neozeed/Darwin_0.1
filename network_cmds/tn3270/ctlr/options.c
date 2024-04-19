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
/*-
 * Copyright (c) 1988, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef lint
static char sccsid[] = "@(#)options.c	8.1 (Berkeley) 6/6/93";
#endif /* not lint */

/*
 * this file contains the definitions, initialization, and processing of
 *	commands to handle the various local options (APL ON, etc.)
 */

#include "options.h"

#include "../general/globals.h"
#include "declare.h"

void
OptInit()
{
    register int i;

    OptAPLmode = 0;
    OptNullProcessing = 1;		/* improved null processing */
    OptZonesMode = 0;		/* zones mode off */
    OptEnterNL = 0;		/* regular enter/new line keys */
    OptColFieldTab = 0;		/* regular column/field tab keys */
    OptPacing = 1;			/* do pacing */
    OptAlphaInNumeric = 0;		/* allow alpha in numeric fields */
    for (i = 0; i < sizeof OptColTabs; i++) {
	OptColTabs[i] = ((i%8) == 0);	/* every 8 columns */
    }
    OptHome = 0;
    OptLeftMargin = 0;
    OptWordWrap = 0;
}

OptOrder(pointer, count, control)
unsigned char *pointer;
int count;
int control;
{
    int i, j, character, origCount;

    origCount = count;

    if (count == 0) {
	return(0);
    }
    character = *pointer&0xff;
    pointer++;
    count--;
    switch (character) {
    case 0xa0:
	OptAPLmode = 1;
	break;
    case 0x61:
	OptAPLmode = 0;
	break;
    case 0x95:
	OptNullProcessing = 0;
	break;
    case 0xd5:
	OptNullProcessing = 1;
	break;
    case 0xa9:
	OptZonesMode = 1;
	break;
    case 0xe9:
	OptZonesMode = 0;
	break;
    case 0x85:
	OptEnterNL = 1;
	break;
    case 0xc5:
	OptEnterNL = 0;
	break;
    case 0x83:
	OptColFieldTab = 1;
	break;
    case 0xc3:
	OptColFieldTab = 0;
	break;
    case 0x97:
	OptPacing = 0;
	break;
    case 0xd7:
	OptPacing = 1;
	break;
    case 0xa5:
	OptAlphaInNumeric = 1;
	break;
    case 0xe5:
	OptAlphaInNumeric = 0;
	break;
    case 0xe3:
	if (!control && count < 30) {
	    return(0);		/* want more! */
	}
	for (i = 0; i < sizeof OptColTabs; i++) {
	    OptColTabs[i] = 0;
	}
	if (!count) {
	    break;
	}
	j = (*pointer&0xff)-0x40;
	count--;
	pointer++;
	if (j < 0 || j >= 24) {
	    break;
	}
	OptHome = j;
	if (!count) {
	    break;
	}
	j = (*pointer&0xff)-0x40;
	count--;
	pointer++;
	if (j < 0 || j >= 80) {
	    break;
	}
	OptLeftMargin = j;
	if (!count) {
	    break;
	}
	i = count;
	if (i > 28) {
	    i = 28;
	}
	while (i) {
	    j = (*pointer&0xff)-0x40;
	    if (j < 0 || j >= sizeof OptColTabs) {
		break;
	    }
	    OptColTabs[j] = 1;
	    i --;
	    pointer++;
	    count--;
	}
	break;
    case 0xa6:
	OptWordWrap = 1;
	break;
    case 0xe6:
	OptWordWrap = 0;
	break;
    default:
	break;
    }
    return(origCount - count);
}
