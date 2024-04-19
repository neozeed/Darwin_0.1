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
/*	$Header: /CVSRoot/CoreOS/Commands/NeXT/bootstrap_cmds/migcom.tproj/write.h,v 1.1.1.1.8.2 1999/03/16 16:12:03 wsanchez Exp $	*/
/*
 * HISTORY
 * 07-Apr-89  Richard Draves (rpd) at Carnegie-Mellon University
 *	Extensive revamping.  Added polymorphic arguments.
 *	Allow multiple variable-sized inline arguments in messages.
 *
 * 27-May-87  Richard Draves (rpd) at Carnegie-Mellon University
 *	Created.
 */

#ifndef	_WRITE_H
#define	_WRITE_H

#include <stdio.h>
#include "statement.h"

extern void WriteHeader(/* FILE *file, statement_t *stats */);
extern void WriteUser(/* FILE *file, statement_t *stats */);
extern void WriteUserIndividual(/* statement_t *stats */);
extern void WriteServer(/* FILE *file, statement_t *stats */);
#if	NeXT
extern void WriteHandler(/* FILE *file, statement_t *stats */);
#endif	NeXT

#endif	_WRITE_H
