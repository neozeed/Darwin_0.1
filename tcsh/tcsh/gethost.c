/* $Header: /CVSRoot/CoreOS/Commands/Other/tcsh/tcsh/gethost.c,v 1.1.1.2 1998/11/05 01:13:07 wsanchez Exp $ */
/*
 * gethost.c: Create version file from prototype
 */
/*-
 * Copyright (c) 1980, 1991 The Regents of the University of California.
 * All rights reserved.
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
#include "sh.h"

RCSID("$Id: gethost.c,v 1.1.1.2 1998/11/05 01:13:07 wsanchez Exp $")

#ifdef SCO
# define perror __perror
# define rename __rename
# define getopt __getopt
# define system __system
#endif
#include <stdio.h>
#ifdef SCO
# undef perror
# undef rename
# undef getopt
# undef system
#endif

#include <ctype.h>

/* Some people don't bother to declare these */
#if defined(SUNOS4) || defined(ibm032)
extern int fprintf();
extern int fclose();
#endif /* SUNOS4 || ibm032 */

#define ISSPACE(p)	(isspace((unsigned char) (p)) && (p) != '\n')

/* 
 * We cannot do that, because some compilers like #line and others
 * like # <lineno>
 * #define LINEDIRECTIVE 
 */

static const char *keyword[] =
{
    "vendor",
#define T_VENDOR	0
    "hosttype",
#define T_HOSTTYPE	1
    "machtype",
#define T_MACHTYPE	2
    "ostype",
#define T_OSTYPE	3
    "newdef",
#define T_NEWDEF	4
    "enddef",
#define T_ENDDEF	5
    "newcode",
#define T_NEWCODE	6
    "endcode",
#define T_ENDCODE	7
    "comment",
#define T_COMMENT	8
    "macro",
#define T_MACRO		9
    NULL
#define T_NONE		10
};

#define S_DISCARD	0
#define S_COMMENT	1
#define S_CODE		2
#define S_KEYWORD	3

static int findtoken __P((char *));
static char *gettoken __P((char **, char  *));

int main __P((int, char *[]));

/* findtoken():
 *	Return the token number of the given token
 */
static int
findtoken(ptr)
    char *ptr;
{
    int i;

    if (ptr == NULL || *ptr == '\0')
	return T_NONE;

    for (i = 0; keyword[i] != NULL; i++)
	if (strcmp(keyword[i], ptr) == 0)
	    return i;

    return T_NONE;
}


/* gettoken():
 *	Get : delimited token and remove leading/trailing blanks/newlines
 */
static char *
gettoken(pptr, token)
    char **pptr;
    char  *token;
{
    char *ptr = *pptr;
    char *tok = token;

    for (; *ptr && ISSPACE(*ptr); ptr++)
	continue;

    for (; *ptr && *ptr != ':'; *tok++ = *ptr++)
	continue;

    if (*ptr == ':')
	ptr++;
    else
	tok--;

    for (tok--; tok >= token && *tok && ISSPACE(*tok); tok--)
	continue;

    *++tok = '\0';

    *pptr = ptr;
    return token;
}
	

int
main(argc, argv)
    int argc;
    char *argv[];
{
    char line[INBUFSIZE];
    char *pname;
    char *fname = "stdin";
    char *ptr, *tok;
    char defs[INBUFSIZE];
    char stmt[INBUFSIZE];
    FILE *fp = stdin;
    int lineno = 0;
    int inprocess = 0;
    int token, state;
    int errs = 0;

    if ((pname = strrchr(argv[0], '/')) == NULL)
	pname = argv[0];
    else
	pname++;

    if (argc > 2) {
	(void) fprintf(stderr, "Usage: %s [<filename>]\n", pname);
	return 1;
    }

    if (argc == 2)
	if ((fp = fopen(fname = argv[1], "r")) == NULL) {
	    (void) fprintf(stderr, "%s: Cannot open `%s'\n", pname, fname);
	    return 1;
	}

    state = S_DISCARD;

    while ((ptr = fgets(line, sizeof(line), fp)) != NULL) {
	lineno++;
	switch (token = findtoken(gettoken(&ptr, defs))) {
	case T_NEWCODE:
	    state = S_CODE;
	    break;

	case T_ENDCODE:
	    state = S_DISCARD;
	    break;

	case T_COMMENT:
	    state = S_COMMENT;
	    break;

	case T_NEWDEF:
	    state = S_KEYWORD;
	    break;

	case T_ENDDEF:
	    state = S_DISCARD;
	    break;

	case T_VENDOR:
	    state = S_KEYWORD;
	    break;

	case T_HOSTTYPE:
	    state = S_KEYWORD;
	    break;

	case T_MACHTYPE:
	    state = S_KEYWORD;
	    break;

	case T_OSTYPE:
	    state = S_KEYWORD;
	    break;

	case T_MACRO:
	    if (gettoken(&ptr, defs) == NULL) {
		(void) fprintf(stderr, "%s: \"%s\", %d: Missing macro name\n",
			       pname, fname, lineno);
		break;
	    }
	    if (gettoken(&ptr, stmt) == NULL) {
		(void) fprintf(stderr, "%s: \"%s\", %d: Missing macro body\n",
			       pname, fname, lineno);
		break;
	    }
	    (void) fprintf(stdout, "\n#if %s\n# define %s\n#endif\n\n", stmt,
			   defs);
	    break;

	case T_NONE:
	    if (state != S_CODE && defs && *defs != '\0') {
		(void) fprintf(stderr, "%s: \"%s\", %d: Discarded\n",
			       pname, fname, lineno);
		if (++errs == 30) {
		    (void) fprintf(stderr, "%s: Too many errors\n", pname);
		    return 1;
		}
		break;
	    }
	    (void) fprintf(stdout, "%s", line);
	    break;

	default:
	    (void) fprintf(stderr, "%s: \"%s\", %d: Unexpected token\n",
			   pname, fname, lineno);
	    return 1;
	}

	switch (state) {
	case S_DISCARD:
	    if (inprocess) {
		inprocess = 0;
		(void) fprintf(stdout, "#endif\n");
	    }
	    break;

	case S_KEYWORD:
	    tok = gettoken(&ptr, defs);
	    if (token == T_NEWDEF) {
		if (inprocess) {
		    (void) fprintf(stderr, "%s: \"%s\", %d: Missing enddef\n",
				   pname, fname, lineno);
		    return 1;
		}
		if (tok == NULL) {
		    (void) fprintf(stderr, "%s: \"%s\", %d: No defs\n",
				   pname, fname, lineno);
		    return 1;
		}
		(void) fprintf(stdout, "\n\n");
#ifdef LINEDIRECTIVE
		(void) fprintf(stdout, "# %d \"%s\"\n", lineno + 1, fname);
#endif /* LINEDIRECTIVE */
		(void) fprintf(stdout, "#if %s\n", defs);
		inprocess = 1;
	    }
	    else {
		if (tok && *tok)
		    (void) fprintf(stdout, "# if (%s) && !defined(_%s_)\n",
				   defs, keyword[token]);
		else
		    (void) fprintf(stdout, "# if !defined(_%s_)\n", 
				   keyword[token]);

		if (gettoken(&ptr, stmt) == NULL) {
		    (void) fprintf(stderr, "%s: \"%s\", %d: No statement\n",
				   pname, fname, lineno);
		    return 1;
		}
		(void) fprintf(stdout, "# define _%s_\n", keyword[token]);
		(void) fprintf(stdout, "    %s = %s;\n", keyword[token], stmt);
		(void) fprintf(stdout, "# endif\n");
	    }
	    break;

	case S_COMMENT:
	    if (gettoken(&ptr, defs))
		(void) fprintf(stdout, "    /* %s */\n", defs);
	    break;

	case S_CODE:
	    if (token == T_NEWCODE) {
#ifdef LINEDIRECTIVE
		(void) fprintf(stdout, "# %d \"%s\"\n", lineno + 1, fname);
#endif /* LINEDIRECTIVE */
	    }
	    break;

	default:
	    (void) fprintf(stderr, "%s: \"%s\", %d: Unexpected state\n",
			   pname, fname, lineno);
	    return 1;
	}
    }

    if (inprocess) {
	(void) fprintf(stderr, "%s: \"%s\", %d: Missing enddef\n",
		       pname, fname, lineno);
	return 1;
    }

    if (fp != stdin)
	(void) fclose(fp);

    return 0;
}
