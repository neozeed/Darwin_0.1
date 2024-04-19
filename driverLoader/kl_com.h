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
/* Copyright (c) 1991 NeXT Computer, Inc.  All rights reserved.
 *
 * kl_com.h -- interface to kern_loader communication module.
 *
 * HISTORY
 * 07-Dec-91	Doug Mitchell at NeXT
 *	Cloned from DOS project source.
 */

/*
 * return codes from kl_com_get_state()
 */
typedef	int klc_server_state;
#define KSS_LOADED	1
#define KSS_ALLOCATED	2
#define KSS_UNKNOWN	3


extern int kl_com_add(const char *path_name, const char *server_name);
extern int kl_com_delete(const char *server_name);
extern int kl_com_load(const char *server_name);
extern int kl_com_unload(const char *server_name);
extern void kl_com_wait();
extern klc_server_state kl_com_get_state(const char *server_name);
