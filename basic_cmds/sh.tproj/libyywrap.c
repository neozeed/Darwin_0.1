/*	$OpenBSD: libyywrap.c,v 1.4 1996/12/10 22:22:03 millert Exp $	*/

/* libyywrap - flex run-time support library "yywrap" function */

/* $Header: /CVSRoot/CoreOS/Commands/NeXT/basic_cmds/sh.tproj/libyywrap.c,v 1.1.1.1 1997/10/11 19:40:29 wsanchez Exp $ */

#include <sys/cdefs.h>

int yywrap __P((void));

int
yywrap()
	{
	return 1;
	}
