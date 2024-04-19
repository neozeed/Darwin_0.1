/*
 * Copyright 1995-1999 Apple Computer, Inc. All rights reserved.
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
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Christos Zoulas of Cornell University.
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

/*
 * hist.c: History access functions
 */
#include "sys.h"
#include <stdlib.h>
#include "el.h"

/* hist_init():
 *	Initialization function.
 */
protected int
hist_init(el)
    EditLine *el;
{
    el->el_history.fun  = NULL;
    el->el_history.ref  = NULL;
    el->el_history.buf   = (char *) el_malloc(EL_BUFSIZ);
    el->el_history.last  = el->el_history.buf;
    return 0;
}


/* hist_end():
 *	clean up history;
 */
protected void
hist_end(el)
    EditLine *el;
{
    el_free((ptr_t) el->el_history.buf);
    el->el_history.buf   = NULL;
}


/* hist_set():
 *	Set new history interface
 */
protected int
hist_set(el, fun, ptr)
    EditLine *el;
    hist_fun_t fun;
    ptr_t ptr;

{
    el->el_history.ref = ptr;
    el->el_history.fun = fun;
    return 0;
}


/* hist_get():
 *	Get a history line and update it in the buffer.
 *	eventno tells us the event to get.
 */
protected el_action_t
hist_get(el)
    EditLine *el;
{
    const char    *hp;
    int     h;

    if (el->el_history.eventno == 0) {	/* if really the current line */
	(void) strncpy(el->el_line.buffer, el->el_history.buf, EL_BUFSIZ);
	el->el_line.lastchar = el->el_line.buffer + 
		(el->el_history.last - el->el_history.buf);

#ifdef KSHVI
    if (el->el_map.type == MAP_VI)
	el->el_line.cursor = el->el_line.buffer;
    else
#endif /* KSHVI */
	el->el_line.cursor = el->el_line.lastchar;

	return CC_REFRESH;
    }

    if (el->el_history.ref == NULL)
	return CC_ERROR;

    hp = HIST_FIRST(el);

    if (hp == NULL)
	return CC_ERROR;

    for (h = 1; h < el->el_history.eventno; h++)
	if ((hp = HIST_NEXT(el)) == NULL) {
	    el->el_history.eventno = h;
	    return CC_ERROR;
	}

    (void) strncpy(el->el_line.buffer, hp, EL_BUFSIZ);
    el->el_line.lastchar = el->el_line.buffer + strlen(el->el_line.buffer);

    if (el->el_line.lastchar > el->el_line.buffer) {
	if (el->el_line.lastchar[-1] == '\n')
	    el->el_line.lastchar--;
	if (el->el_line.lastchar[-1] == ' ')
	    el->el_line.lastchar--;
	if (el->el_line.lastchar < el->el_line.buffer)
	    el->el_line.lastchar = el->el_line.buffer;
    }

#ifdef KSHVI
    if (el->el_map.type == MAP_VI)
	el->el_line.cursor = el->el_line.buffer;
    else
#endif /* KSHVI */
	el->el_line.cursor = el->el_line.lastchar;

    return CC_REFRESH;
}

/* hist_list()
 *	List history entries
 */
protected int
/*ARGSUSED*/
hist_list(el, argc, argv)
    EditLine *el;
    int argc;
    char **argv;
{
    const char *str;

    if (el->el_history.ref == NULL)
	return -1;
    for (str = HIST_LAST(el); str != NULL; str = HIST_PREV(el))
	(void) fprintf(el->el_outfile, "%d %s", el->el_history.ev->num, str);
    return 0;
}
