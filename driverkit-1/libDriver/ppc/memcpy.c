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
/* Copyright (c) 1992 by NeXT Computer, Inc.
 *
 *      File:   memcpy.c 
 *
 * HISTORY
 * 16-Aug-93  John Immordino at NeXT
 *      Created.
 */

#import <driverkit/driverTypes.h>

void _IOCopyMemory(char *src, char *dst, unsigned copyLen, 
	unsigned copyUnitSize)
{
    
    unsigned i;
    
    if (src == NULL || dst == NULL || src == dst || copyLen == 0)
    	return;

    /* 
     * Just copy bytes.  Punt for now, optimize this later if we 
     * ever use driverkit with m68k.  Assembly routines for byte-wide
     * and int-wide copy are in mk/machdep/m68k/libc.s
     */
    for (i = 0 ; i < copyLen ; ++i)
    	dst[i] = src[i];
}