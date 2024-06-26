/*	$OpenBSD: cd.c,v 1.9 1996/11/03 23:16:09 bitblt Exp $	*/
/*	$NetBSD: cd.c,v 1.15 1996/03/01 01:58:58 jtc Exp $	*/

/*-
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Kenneth Almquist.
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
#if 0
static char sccsid[] = "@(#)cd.c	8.2 (Berkeley) 5/4/95";
#else
static char rcsid[] = "$OpenBSD: cd.c,v 1.9 1996/11/03 23:16:09 bitblt Exp $";
#endif
#endif /* not lint */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>


/*
 * The cd and pwd commands.
 */

#include "shell.h"
#include "var.h"
#include "nodes.h"	/* for jobs.h */
#include "jobs.h"
#include "options.h"
#include "output.h"
#include "memalloc.h"
#include "error.h"
#include "exec.h"
#include "redir.h"
#include "mystring.h"
#include "show.h"
#include "cd.h"

STATIC int docd __P((char *, int));
STATIC char *getcomponent __P((void));
STATIC void updatepwd __P((char *));

char *curdir = NULL;		/* current working directory */
char *prevdir;			/* previous working directory */
STATIC char *cdcomppath;

int
cdcmd(argc, argv)
	int argc;
	char **argv; 
{
	char *dest;
	char *path;
	char *p;
	struct stat statb;
	int print = 0;

	nextopt(nullstr);
	if ((dest = *argptr) == NULL && (dest = bltinlookup("HOME", 1)) == NULL)
		error("HOME not set");
	if (*dest == '\0')
		dest = ".";
	if (dest[0] == '-' && dest[1] == '\0') {
		dest = prevdir ? prevdir : curdir;
		print = 1;
		if (!dest)
			dest = ".";
	}
	if (*dest == '/' || (path = bltinlookup("CDPATH", 1)) == NULL)
		path = nullstr;
	while ((p = padvance(&path, dest)) != NULL) {
		if (stat(p, &statb) >= 0 && S_ISDIR(statb.st_mode)) {
			if (!print) {
				/*
				 * XXX - rethink
				 */
				if (p[0] == '.' && p[1] == '/')
					p += 2;
				print = strcmp(p, dest);
			}
			if (docd(p, print) >= 0)
				return 0;

		}
	}
	error("can't cd to %s", dest);
	/*NOTREACHED*/
	return 0;
}


/*
 * Actually do the chdir.  In an interactive shell, print the
 * directory name if "print" is nonzero.
 */

STATIC int
docd(dest, print)
	char *dest;
	int print;
{

	TRACE(("docd(\"%s\", %d) called\n", dest, print));
	INTOFF;
	if (chdir(dest) < 0) {
		INTON;
		return -1;
	}
	updatepwd(dest);
	INTON;
	if (print && iflag)
		out1fmt("%s\n", stackblock());
	return 0;
}


/*
 * Get the next component of the path name pointed to by cdcomppath.
 * This routine overwrites the string pointed to by cdcomppath.
 */

STATIC char *
getcomponent() {
	register char *p;
	char *start;

	if ((p = cdcomppath) == NULL)
		return NULL;
	start = cdcomppath;
	while (*p != '/' && *p != '\0')
		p++;
	if (*p == '\0') {
		cdcomppath = NULL;
	} else {
		*p++ = '\0';
		cdcomppath = p;
	}
	return start;
}



/*
 * Update curdir (the name of the current directory) in response to a
 * cd command.  We also call hashcd to let the routines in exec.c know
 * that the current directory has changed.
 */

void hashcd();

STATIC void
updatepwd(dir)
	char *dir;
	{
	char *new;
	char *p;

	hashcd();				/* update command hash table */
	cdcomppath = stalloc(strlen(dir) + 1);
	scopy(dir, cdcomppath);
	STARTSTACKSTR(new);
	if (*dir != '/') {
		if (curdir == NULL)
			return;
		p = curdir;
		while (*p)
			STPUTC(*p++, new);
		if (p[-1] == '/')
			STUNPUTC(new);
	}
	while ((p = getcomponent()) != NULL) {
		if (equal(p, "..")) {
			while (new > stackblock() && (STUNPUTC(new), *new) != '/');
		} else if (*p != '\0' && ! equal(p, ".")) {
			STPUTC('/', new);
			while (*p)
				STPUTC(*p++, new);
		}
	}
	if (new == stackblock())
		STPUTC('/', new);
	STACKSTRNUL(new);
	INTOFF;
	if (prevdir)
		ckfree(prevdir);
	prevdir = curdir;
	curdir = savestr(stackblock());
	INTON;
}



int
pwdcmd(argc, argv)
	int argc;
	char **argv; 
{
	getpwd();
	out1str(curdir);
	out1c('\n');
	return 0;
}




#define MAXPWD MAXPATHLEN

/*
 * Find out what the current directory is. If we already know the current
 * directory, this routine returns immediately.
 */
void
getpwd()
{
	char buf[MAXPWD];

	if (curdir)
		return;
	/*
	 * Things are a bit complicated here; we could have just used
	 * getcwd, but traditionally getcwd is implemented using popen
	 * to /bin/pwd. This creates a problem for us, since we cannot
	 * keep track of the job if it is being ran behind our backs.
	 * So we re-implement getcwd(), and we suppress interrupts
	 * throughout the process. This is not completely safe, since
	 * the user can still break out of it by killing the pwd program.
	 * We still try to use getcwd for systems that we know have a
	 * c implementation of getcwd, that does not open a pipe to
	 * /bin/pwd.
	 */
#if defined(__NetBSD__) || defined(__OpenBSD__) || defined(__svr4__) || defined(__NeXT__)
	if (getcwd(buf, sizeof(buf)) == NULL)
		error("getcwd() failed: %s", strerror(errno));
	curdir = savestr(buf);
#else
	{
		char *p;
		int i;
		int status;
		struct job *jp;
		int pip[2];

		INTOFF;
		if (pipe(pip) < 0)
			error("Pipe call failed");
		jp = makejob((union node *)NULL, 1);
		if (forkshell(jp, (union node *)NULL, FORK_NOJOB) == 0) {
			(void) close(pip[0]);
			if (pip[1] != 1) {
				close(1);
				copyfd(pip[1], 1);
				close(pip[1]);
			}
			(void) execl("/bin/pwd", "pwd", (char *)0);
			error("Cannot exec /bin/pwd");
		}
		(void) close(pip[1]);
		pip[1] = -1;
		p = buf;
		while ((i = read(pip[0], p, buf + MAXPWD - p)) > 0
		     || (i == -1 && errno == EINTR)) {
			if (i > 0)
				p += i;
		}
		(void) close(pip[0]);
		pip[0] = -1;
		status = waitforjob(jp);
		if (status != 0)
			error((char *)0);
		if (i < 0 || p == buf || p[-1] != '\n')
			error("pwd command failed");
		p[-1] = '\0';
	}
	curdir = savestr(buf);
	INTON;
#endif
}
