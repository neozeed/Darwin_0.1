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
 * Copyright 1993 NeXT Computer, Inc.
 * All rights reserved.
 */

#import "libsa.h"
#import "saio_types.h"
#import "saio.h"
#import "libsaio.h"


int localPrintf(const char *format, ...)
{
    va_list ap;
    char *val;
    
    val = 0;
    va_start(ap, format);
    localVPrintf(format, ap);
    va_end(ap);
    return 0;
}

BOOL verbose_mode;

int verbose(const char *format, ...)
{
    va_list ap;
    
    if (verbose_mode) {
	va_start(ap, format);
	localVPrintf(format, ap);
	va_end(ap);
    }
    return(0);
}

int error(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    errorV(format, ap);
    va_end(ap);
    return(0);
}
