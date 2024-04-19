/*	$NetBSD: error.c,v 1.4 1997/11/21 08:36:00 lukem Exp $	*/

/*
 * Copyright (c) 1983, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Edward Wang at The University of California, Berkeley.
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

#include <sys/cdefs.h>
#ifndef lint
#if 0
static char sccsid[] = "@(#)error.c	8.1 (Berkeley) 6/6/93";
#else
__RCSID("$NetBSD: error.c,v 1.4 1997/11/21 08:36:00 lukem Exp $");
#endif
#endif /* not lint */

#include "defs.h"
#include "context.h"
#include "char.h"

#define ERRLINES 10			/* number of lines for errwin */

void
#if __STDC__
error(const char *fmt, ...)
#else
error(fmt, va_alist)
	char *fmt;
	va_dcl
#endif
{
	va_list ap;
#if __STDC__
	va_start(ap, fmt);
#else
	va_start(ap);
#endif
	verror(fmt, ap);
	va_end(ap);
}

void
verror(fmt, ap)
	const char *fmt;
	va_list ap;
{
	struct context *x;
	struct ww *w;

	for (x = &cx; x != 0 && x->x_type != X_FILE; x = x->x_link)
		;
	if (x == 0) {
		if (terse)
			wwbell();
		else {
			wwvprintf(cmdwin, fmt, ap);
			wwputs("  ", cmdwin);
		}
		return;
	}
	if (x->x_noerr)
		return;
	if ((w = x->x_errwin) == 0) {
		char buf[512];

		(void) snprintf(buf, sizeof(buf), "Errors from %s",
		    x->x_filename);
		if ((w = x->x_errwin = openiwin(ERRLINES, buf)) == 0) {
			wwputs("Can't open error window.  ", cmdwin);
			x->x_noerr = 1;
			return;
		}
	}
	if (more(w, 0) == 2) {
		x->x_noerr = 1;
		return;
	}
	wwprintf(w, "line %d: ", x->x_lineno);
	wwvprintf(w, fmt, ap);
	wwputc('\n', w);
}

void
err_end()
{
	if (cx.x_type == X_FILE && cx.x_errwin != 0) {
		if (!cx.x_noerr)
			waitnl(cx.x_errwin);
		closeiwin(cx.x_errwin);
		cx.x_errwin = 0;
	}
}
