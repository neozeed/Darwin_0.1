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

/* 	Copyright (c) 1992 NeXT Computer, Inc.  All rights reserved. 
 *
 * FBConsole.h - FrameBuffer based console implementation definitions
 *
 *
 * HISTORY
 * 01 Sep 92	Joe Pasqua
 *      Created. 
 */

// Notes:
// * This module is the interface to a console implementation that writes
//   to a raw frame buffer. If you have such a device, you can use this
//   code to help implement your console support.
// * Currently we support 16 and 32 bpp displays.

#ifdef	DRIVER_PRIVATE

#import	<mach/boolean.h>
#import <driverkit/displayDefs.h>
#import	<bsd/dev/i386/ConsoleSupport.h>

extern IOConsoleInfo *FBAllocateConsole(IODisplayInfo *display);

#endif	/* DRIVER_PRIVATE */
