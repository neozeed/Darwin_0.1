/*
 * zle_main.c - main routines for line editor
 *
 * This file is part of zsh, the Z shell.
 *
 * Copyright (c) 1992-1997 Paul Falstad
 * All rights reserved.
 *
 * Permission is hereby granted, without written agreement and without
 * license or royalty fees, to use, copy, modify, and distribute this
 * software and to distribute modified versions of this software for any
 * purpose, provided that the above copyright notice and the following
 * two paragraphs appear in all copies of this software.
 *
 * In no event shall Paul Falstad or the Zsh Development Group be liable
 * to any party for direct, indirect, special, incidental, or consequential
 * damages arising out of the use of this software and its documentation,
 * even if Paul Falstad and the Zsh Development Group have been advised of
 * the possibility of such damage.
 *
 * Paul Falstad and the Zsh Development Group specifically disclaim any
 * warranties, including, but not limited to, the implied warranties of
 * merchantability and fitness for a particular purpose.  The software
 * provided hereunder is on an "as is" basis, and Paul Falstad and the
 * Zsh Development Group have no obligation to provide maintenance,
 * support, updates, enhancements, or modifications.
 *
 */

#include "zle.mdh"
#include "zle_main.pro"

/* != 0 if we're done editing */

/**/
int done;

/* location of mark */

/**/
int mark;

/* last character pressed */

/**/
int c;

/* the binding for this key */

/**/
Thingy bindk;

/* insert mode/overwrite mode flag */

/**/
int insmode;

static int eofchar, eofsent;
static long keytimeout;

#ifdef HAVE_SELECT
/* Terminal baud rate */

static int baud;
#endif

/* flags associated with last command */

/**/
int lastcmd;

/* the status line, and its length */

/**/
char *statusline;
/**/
int statusll;

/* The current history line and cursor position for the top line *
 * on the buffer stack.                                          */

/**/
int stackhist, stackcs;

/* != 0 if we are making undo records */

/**/
int undoing;

/* current modifier status */

/**/
struct modifier zmod;

/* Current command prefix status.  This is normally 0.  Prefixes set *
 * this to 1.  Each time round the main loop, this is checked: if it *
 * is 0, the modifier status is reset; if it is 1, the modifier      *
 * status is left unchanged, and this flag is reset to 0.  The       *
 * effect is that several prefix commands can be executed, and have  *
 * cumulative effect, but any other command execution will clear the *
 * modifiers.                                                        */

/**/
int prefixflag;

/* != 0 if there is a pending beep (usually indicating an error) */

/**/
int feepflag;

/* set up terminal */

#ifdef __APPLE__
__private_extern__
#endif
/**/
void
setterm(void)
{
    struct ttyinfo ti;

#if defined(CLOBBERS_TYPEAHEAD) && defined(FIONREAD)
    int val;

    ioctl(SHTTY, FIONREAD, (char *)&val);
    if (val)
	return;
#endif

/* sanitize the tty */
#ifdef HAS_TIO
    shttyinfo.tio.c_lflag |= ICANON | ECHO;
# ifdef FLUSHO
    shttyinfo.tio.c_lflag &= ~FLUSHO;
# endif
#else				/* not HAS_TIO */
    shttyinfo.sgttyb.sg_flags = (shttyinfo.sgttyb.sg_flags & ~CBREAK) | ECHO;
    shttyinfo.lmodes &= ~LFLUSHO;
#endif

    attachtty(mypgrp);
    ti = shttyinfo;
#ifdef HAS_TIO
    if (unset(FLOWCONTROL))
	ti.tio.c_iflag &= ~IXON;
    ti.tio.c_lflag &= ~(ICANON | ECHO
# ifdef FLUSHO
			| FLUSHO
# endif
	);
# ifdef TAB3
    ti.tio.c_oflag &= ~TAB3;
# else
#  ifdef OXTABS
    ti.tio.c_oflag &= ~OXTABS;
#  else
    ti.tio.c_oflag &= ~XTABS;
#  endif
# endif
    ti.tio.c_oflag |= ONLCR;
    ti.tio.c_cc[VQUIT] =
# ifdef VDISCARD
	ti.tio.c_cc[VDISCARD] =
# endif
# ifdef VSUSP
	ti.tio.c_cc[VSUSP] =
# endif
# ifdef VDSUSP
	ti.tio.c_cc[VDSUSP] =
# endif
# ifdef VSWTCH
	ti.tio.c_cc[VSWTCH] =
# endif
# ifdef VLNEXT
	ti.tio.c_cc[VLNEXT] =
# endif
	VDISABLEVAL;
# if defined(VSTART) && defined(VSTOP)
    if (unset(FLOWCONTROL))
	ti.tio.c_cc[VSTART] = ti.tio.c_cc[VSTOP] = VDISABLEVAL;
# endif
    eofchar = ti.tio.c_cc[VEOF];
    ti.tio.c_cc[VMIN] = 1;
    ti.tio.c_cc[VTIME] = 0;
    ti.tio.c_iflag |= (INLCR | ICRNL);
 /* this line exchanges \n and \r; it's changed back in getkey
	so that the net effect is no change at all inside the shell.
	This double swap is to allow typeahead in common cases, eg.

	% bindkey -s '^J' 'echo foo^M'
	% sleep 10
	echo foo<return>  <--- typed before sleep returns

	The shell sees \n instead of \r, since it was changed by the kernel
	while zsh wasn't looking. Then in getkey() \n is changed back to \r,
	and it sees "echo foo<accept line>", as expected. Without the double
	swap the shell would see "echo foo\n", which is translated to
	"echo fooecho foo<accept line>" because of the binding.
	Note that if you type <line-feed> during the sleep the shell just sees
	\n, which is translated to \r in getkey(), and you just get another
	prompt. For type-ahead to work in ALL cases you have to use
	stty inlcr.

	Unfortunately it's IMPOSSIBLE to have a general solution if both
	<return> and <line-feed> are mapped to the same character. The shell
	could check if there is input and read it before setting it's own
	terminal modes but if we get a \n we don't know whether to keep it or
	change to \r :-(
	*/

#else				/* not HAS_TIO */
    ti.sgttyb.sg_flags = (ti.sgttyb.sg_flags | CBREAK) & ~ECHO & ~XTABS;
    ti.lmodes &= ~LFLUSHO;
    eofchar = ti.tchars.t_eofc;
    ti.tchars.t_quitc =
	ti.ltchars.t_suspc =
	ti.ltchars.t_flushc =
	ti.ltchars.t_dsuspc = ti.ltchars.t_lnextc = -1;
#endif

#if defined(TTY_NEEDS_DRAINING) && defined(TIOCOUTQ) && defined(HAVE_SELECT)
    if (baud) {			/**/
	int n = 0;

	while ((ioctl(SHTTY, TIOCOUTQ, (char *)&n) >= 0) && n) {
	    struct timeval tv;

	    tv.tv_sec = n / baud;
	    tv.tv_usec = ((n % baud) * 1000000) / baud;
	    select(0, NULL, NULL, NULL, &tv);
	}
    }
#endif

    settyinfo(&ti);
}

static char *kungetbuf;
static int kungetct, kungetsz;

/**/
void
ungetkey(int ch)
{
    if (kungetct == kungetsz)
	kungetbuf = realloc(kungetbuf, kungetsz *= 2);
    kungetbuf[kungetct++] = ch;
}

/**/
void
ungetkeys(char *s, int len)
{
    s += len;
    while (len--)
	ungetkey(*--s);
}

#if defined(pyr) && defined(HAVE_SELECT)
static int
breakread(int fd, char *buf, int n)
{
    fd_set f;

    FD_ZERO(&f);
    FD_SET(fd, &f);
    return (select(fd + 1, (SELECT_ARG_2_T) & f, NULL, NULL, NULL) == -1 ?
	    EOF : read(fd, buf, n));
}

# define read    breakread
#endif

/**/
int
getkey(int keytmout)
{
    char cc;
    unsigned int ret;
    long exp100ths;
    int die = 0, r, icnt = 0;
    int old_errno = errno;

#ifdef HAVE_SELECT
    fd_set foofd;

#else
# ifdef HAS_TIO
    struct ttyinfo ti;

# endif
#endif

    if (kungetct)
	ret = STOUC(kungetbuf[--kungetct]);
    else {
	if (keytmout) {
	    if (keytimeout > 500)
		exp100ths = 500;
	    else if (keytimeout > 0)
		exp100ths = keytimeout;
	    else
		exp100ths = 0;
#ifdef HAVE_SELECT
	    if (exp100ths) {
		struct timeval expire_tv;

		expire_tv.tv_sec = exp100ths / 100;
		expire_tv.tv_usec = (exp100ths % 100) * 10000L;
		FD_ZERO(&foofd);
		FD_SET(SHTTY, &foofd);
		if (select(SHTTY+1, (SELECT_ARG_2_T) & foofd,
			   NULL, NULL, &expire_tv) <= 0)
		    return EOF;
	    }
#else
# ifdef HAS_TIO
	    ti = shttyinfo;
	    ti.tio.c_lflag &= ~ICANON;
	    ti.tio.c_cc[VMIN] = 0;
	    ti.tio.c_cc[VTIME] = exp100ths / 10;
#  ifdef HAVE_TERMIOS_H
	    tcsetattr(SHTTY, TCSANOW, &ti.tio);
#  else
	    ioctl(SHTTY, TCSETA, &ti.tio);
#  endif
	    r = read(SHTTY, &cc, 1);
#  ifdef HAVE_TERMIOS_H
	    tcsetattr(SHTTY, TCSANOW, &shttyinfo.tio);
#  else
	    ioctl(SHTTY, TCSETA, &shttyinfo.tio);
#  endif
	    return (r <= 0) ? EOF : cc;
# endif
#endif
	}
	while ((r = read(SHTTY, &cc, 1)) != 1) {
	    if (r == 0) {
		/* The test for IGNOREEOF was added to make zsh ignore ^Ds
		   that were typed while commands are running.  Unfortuantely
		   this caused trouble under at least one system (SunOS 4.1).
		   Here shells that lost their xterm (e.g. if it was killed
		   with -9) didn't fail to read from the terminal but instead
		   happily continued to read EOFs, so that the above read
		   returned with 0, and, with IGNOREEOF set, this caused
		   an infinite loop.  The simple way around this was to add
		   the counter (icnt) so that this happens 20 times and than
		   the shell gives up (yes, this is a bit dirty...). */
		if (isset(IGNOREEOF) && icnt++ < 20)
		    continue;
		stopmsg = 1;
		zexit(1, 0);
	    }
	    icnt = 0;
	    if (errno == EINTR) {
		die = 0;
		if (!errflag && !retflag && !breaks)
		    continue;
		errflag = 0;
		errno = old_errno;
		return EOF;
	    } else if (errno == EWOULDBLOCK) {
		fcntl(0, F_SETFL, 0);
	    } else if (errno == EIO && !die) {
		ret = opts[MONITOR];
		opts[MONITOR] = 1;
		attachtty(mypgrp);
		refresh();	/* kludge! */
		opts[MONITOR] = ret;
		die = 1;
	    } else if (errno != 0) {
		zerr("error on TTY read: %e", NULL, errno);
		stopmsg = 1;
		zexit(1, 0);
	    }
	}
	if (cc == '\r')		/* undo the exchange of \n and \r determined by */
	    cc = '\n';		/* setterm() */
	else if (cc == '\n')
	    cc = '\r';

	ret = STOUC(cc);
    }
    if (vichgflag) {
	if (vichgbufptr == vichgbufsz)
	    vichgbuf = realloc(vichgbuf, vichgbufsz *= 2);
	vichgbuf[vichgbufptr++] = ret;
    }
    errno = old_errno;
    return ret;
}

/* Read a line.  It is returned metafied. */

/**/
unsigned char *
zleread(char *lp, char *rp, int ha)
{
    unsigned char *s;
    int old_errno = errno;
    int tmout = getiparam("TMOUT");

#ifdef HAVE_SELECT
    long costmult;
    struct timeval tv;
    fd_set foofd;

    baud = getiparam("BAUD");
    costmult = (baud) ? 3840000L / baud : 0;
    tv.tv_sec = 0;
#endif

    /* ZLE doesn't currently work recursively.  This is needed in case a *
     * select loop is used in a function called from ZLE.  vared handles *
     * this differently itself.                                          */
    if(zleactive) {
	char *pptbuf;
	int pptlen;

	pptbuf = unmetafy(promptexpand(lp, 0, NULL, NULL), &pptlen);
	write(2, (WRITE_ARG_2_T)pptbuf, pptlen);
	free(pptbuf);
	return (unsigned char *)shingetline();
    }

    keytimeout = getiparam("KEYTIMEOUT");
    if (!shout) {
	if (SHTTY != -1)
	    init_shout();

	if (!shout)
	    return NULL;
	/* We could be smarter and default to a system read. */

	/* If we just got a new shout, make sure the terminal is set up. */
	if (termflags & TERM_UNKNOWN)
	    init_term();
    }

    fflush(shout);
    fflush(stderr);
    intr();
    insmode = unset(OVERSTRIKE);
    eofsent = 0;
    resetneeded = 0;
    lpptbuf = promptexpand(lp, 1, NULL, NULL);
    pmpt_attr = txtchange;
    rpptbuf = promptexpand(rp, 1, NULL, NULL);
    rpmpt_attr = txtchange;
    histallowed = ha;
    PERMALLOC {
	histline = curhist;
#ifdef HAVE_SELECT
	FD_ZERO(&foofd);
#endif
	undoing = 1;
	line = (unsigned char *)zalloc((linesz = 256) + 2);
	virangeflag = lastcmd = done = cs = ll = mark = 0;
	curhistline = NULL;
	vichgflag = 0;
	viinsbegin = 0;
	statusline = NULL;
	selectkeymap("main", 1);
	fixsuffix();
	if ((s = (unsigned char *)getlinknode(bufstack))) {
	    setline((char *)s);
	    zsfree((char *)s);
	    if (stackcs != -1) {
		cs = stackcs;
		stackcs = -1;
		if (cs > ll)
		    cs = ll;
	    }
	    if (stackhist != -1) {
		histline = stackhist;
		stackhist = -1;
	    }
	}
	initundo();
	if (isset(PROMPTCR))
	    putc('\r', shout);
	if (tmout)
	    alarm(tmout);
	zleactive = 1;
	resetneeded = 1;
	errflag = retflag = 0;
	lastcol = -1;
	initmodifier(&zmod);
	prefixflag = 0;
	feepflag = 0;
	refresh();
	while (!done && !errflag) {

	    statusline = NULL;
	    vilinerange = 0;
	    reselectkeymap();
	    bindk = getkeycmd();
	    if (!ll && isfirstln && c == eofchar) {
		eofsent = 1;
		break;
	    }
	    if (bindk) {
		execzlefunc(bindk);
		handleprefixes();
		/* for vi mode, make sure the cursor isn't somewhere illegal */
		if (invicmdmode() && cs > findbol() &&
		    (cs == ll || line[cs] == '\n'))
		    cs--;
		if (undoing)
		    handleundo();
	    } else {
		errflag = 1;
		break;
	    }
#ifdef HAVE_SELECT
	    if (baud && !(lastcmd & ZLE_MENUCMP)) {
		FD_SET(SHTTY, &foofd);
		if ((tv.tv_usec = cost * costmult) > 500000)
		    tv.tv_usec = 500000;
		if (!kungetct && select(SHTTY+1, (SELECT_ARG_2_T) & foofd,
					NULL, NULL, &tv) <= 0)
		    refresh();
	    } else
#endif
		if (!kungetct)
		    refresh();
	    handlefeep();
	}
	statusline = NULL;
	invalidatelist();
	trashzle();
	free(lpptbuf);
	free(rpptbuf);
	zleactive = 0;
	alarm(0);
    } LASTALLOC;
    zsfree(curhistline);
    freeundo();
    if (eofsent) {
	free(line);
	line = NULL;
    } else {
	line[ll++] = '\n';
	line = (unsigned char *) metafy((char *) line, ll, META_REALLOC);
    }
    forget_edits();
    errno = old_errno;
    return line;
}

/* execute a widget */

/**/
void
execzlefunc(Thingy func)
{
    Widget w;

    if(func->flags & DISABLED) {
	/* this thingy is not the name of a widget */
	char *nm = niceztrdup(func->nam);
	char *msg = tricat("No such widget `", nm, "'");

	zsfree(nm);
	showmsg(msg);
	zsfree(msg);
	feep();
    } else if((w = func->widget)->flags & WIDGET_INT) {
	int wflags = w->flags;

	if(!(wflags & ZLE_KEEPSUFFIX))
	    removesuffix();
	if(!(wflags & ZLE_MENUCMP)) {
	    fixsuffix();
	    invalidatelist();
	}
	if (wflags & ZLE_LINEMOVE)
	    vilinerange = 1;
	if(!(wflags & ZLE_LASTCOL))
	    lastcol = -1;
	w->u.fn();
	lastcmd = wflags;
    } else {
	List l = getshfunc(w->u.fnnam);

	if(l == &dummy_list) {
	    /* the shell function doesn't exist */
	    char *nm = niceztrdup(w->u.fnnam);
	    char *msg = tricat("No such shell function `", nm, "'");

	    zsfree(nm);
	    showmsg(msg);
	    zsfree(msg);
	    feep();
	} else {
	  startparamscope();
	  makezleparams();
	  doshfunc(l, NULL, 0, 1);
	  endparamscope();
	  lastcmd = 0;
	}
    }
}

/* initialise command modifiers */

/**/
static void
initmodifier(struct modifier *mp)
{
    mp->flags = 0;
    mp->mult = 1;
    mp->tmult = 1;
    mp->vibuf = 0;
}

/* Reset command modifiers, unless the command just executed was a prefix. *
 * Also set zmult, if the multiplier has been amended.                     */

/**/
static void
handleprefixes(void)
{
    if (prefixflag) {
	prefixflag = 0;
	if(zmod.flags & MOD_TMULT) {
	    zmod.flags |= MOD_MULT;
	    zmod.mult = zmod.tmult;
	}
    } else
	initmodifier(&zmod);
}

/* vared: edit (literally) a parameter value */

/**/
static int
bin_vared(char *name, char **args, char *ops, int func)
{
    char *s;
    char *t;
    Param pm;
    int create = 0;
    char *p1 = NULL, *p2 = NULL;

    /* all options are handled as arguments */
    while (*args && **args == '-') {
	while (*++(*args))
	    switch (**args) {
	    case 'c':
		/* -c option -- allow creation of the parameter if it doesn't
		yet exist */
		create = 1;
		break;
	    case 'p':
		/* -p option -- set main prompt string */
		if ((*args)[1])
		    p1 = *args + 1, *args = "" - 1;
		else if (args[1])
		    p1 = *(++args), *args = "" - 1;
		else {
		    zwarnnam(name, "prompt string expected after -%c", NULL,
			     **args);
		    return 1;
		}
		break;
	    case 'r':
		/* -r option -- set right prompt string */
		if ((*args)[1])
		    p2 = *args + 1, *args = "" - 1;
		else if (args[1])
		    p2 = *(++args), *args = "" - 1;
		else {
		    zwarnnam(name, "prompt string expected after -%c", NULL,
			     **args);
		    return 1;
		}
		break;
	    case 'h':
		/* -h option -- enable history */
		ops['h'] = 1;
		break;
	    default:
		/* unrecognised option character */
		zwarnnam(name, "unknown option: %s", *args, 0);
		return 1;
	    }
	args++;
    }

    /* check we have a parameter name */
    if (!*args) {
	zwarnnam(name, "missing variable", NULL, 0);
	return 1;
    }
    /* handle non-existent parameter */
    if (!(s = getsparam(args[0]))) {
	if (create)
	    createparam(args[0], PM_SCALAR);
	else {
	    zwarnnam(name, "no such variable: %s", args[0], 0);
	    return 1;
	}
    }

    if(zleactive) {
	zwarnnam(name, "ZLE cannot be used recursively (yet)", NULL, 0);
	return 1;
    }

    /* edit the parameter value */
    PERMALLOC {
	pushnode(bufstack, ztrdup(s));
    } LASTALLOC;
    t = (char *) zleread(p1, p2, ops['h']);
    if (!t || errflag) {
	/* error in editing */
	errflag = 0;
	return 1;
    }
    /* strip off trailing newline, if any */
    if (t[strlen(t) - 1] == '\n')
	t[strlen(t) - 1] = '\0';
    /* final assignment of parameter value */
    pm = (Param) paramtab->getnode(paramtab, args[0]);
    if (pm && PM_TYPE(pm->flags) == PM_ARRAY) {
	char **a;

	PERMALLOC {
	    a = spacesplit(t, 1);
	} LASTALLOC;
	setaparam(args[0], a);
    } else
	setsparam(args[0], t);
    return 0;
}

/**/
void
describekeybriefly(void)
{
    char *seq, *str, *msg, *is;
    Thingy func;

    if (statusline)
	return;
    statusline = "Describe key briefly: _";
    statusll = strlen(statusline);
    refresh();
    seq = getkeymapcmd(curkeymap, &func, &str);
    statusline = NULL;
    if(!*seq)
	return;
    msg = bindztrdup(seq);
    msg = appstr(msg, " is ");
    if (!func)
	is = bindztrdup(str);
    else
	is = niceztrdup(func->nam);
    msg = appstr(msg, is);
    zsfree(is);
    showmsg(msg);
    zsfree(msg);
}

#define MAXFOUND 4

struct findfunc {
    Thingy func;
    int found;
    char *msg;
};

/**/
static void
scanfindfunc(char *seq, Thingy func, char *str, void *magic)
{
    struct findfunc *ff = magic;

    if(func != ff->func)
	return;
    if (!ff->found++)
	ff->msg = appstr(ff->msg, " is on");
    if(ff->found <= MAXFOUND) {
	char *b = bindztrdup(seq);

	ff->msg = appstr(ff->msg, " ");
	ff->msg = appstr(ff->msg, b);
	zsfree(b);
    }
}

/**/
void
whereis(void)
{
    struct findfunc ff;

    if (!(ff.func = executenamedcommand("Where is: ")))
	return;
    ff.found = 0;
    ff.msg = niceztrdup(ff.func->nam);
    scankeymap(curkeymap, 1, scanfindfunc, &ff);
    if (!ff.found)
	ff.msg = appstr(ff.msg, " is not bound to any key");
    else if(ff.found > MAXFOUND)
	ff.msg = appstr(ff.msg, " et al");
    showmsg(ff.msg);
    zsfree(ff.msg);
}

/**/
void
trashzle(void)
{
    if (zleactive) {
	/* This refresh() is just to get the main editor display right and *
	 * get the cursor in the right place.  For that reason, we disable *
	 * list display (which would otherwise result in infinite          *
	 * recursion [at least, it would if refresh() didn't have its      *
	 * extra `inlist' check]).                                         */
	int sl = showinglist;
	showinglist = 0;
	refresh();
	showinglist = sl;
	moveto(nlnct, 0);
	if (clearflag && tccan(TCCLEAREOD)) {
	    tcout(TCCLEAREOD);
	    clearflag = 0;
	}
	if (postedit)
	    fprintf(shout, "%s", postedit);
	fflush(shout);
	resetneeded = 1;
	settyinfo(&shttyinfo);
    }
    if (errflag)
	kungetct = 0;
}

static struct builtin bintab[] = {
    BUILTIN("bindkey", 0, bin_bindkey, 0, -1, 0, "evaMldDANmrsLR", NULL),
    BUILTIN("vared",   0, bin_vared,   1,  7, 0, NULL,             NULL),
    BUILTIN("zle",     0, bin_zle,     0, -1, 0, "lDANL",          NULL),
};

/**/
int
boot_zle(Module m)
{
    /* Set up editor entry points */
    trashzleptr = trashzle;
    gotwordptr = gotword;
    refreshptr = refresh;
    spaceinlineptr = spaceinline;
    zlereadptr = zleread;

    /* initialise the thingies */
    init_thingies();

    /* miscellaneous initialisations */
    stackhist = stackcs = -1;
    kungetbuf = (char *) zalloc(kungetsz = 32);

    /* initialise the keymap system */
    init_keymaps();

    addbuiltins(m->nam, bintab, sizeof(bintab)/sizeof(*bintab));
    return 0;
}

#ifdef MODULE

/**/
int
cleanup_zle(Module m)
{
    int i;

    if(zleactive) {
	zerrnam(m->nam, "can't unload the zle module while zle is active",
	    NULL, 0);
	return 1;
    }

    deletebuiltins(m->nam, bintab, sizeof(bintab)/sizeof(*bintab));
    cleanup_keymaps();
    deletehashtable(thingytab);

    zfree(vichgbuf, vichgbufsz);
    zfree(kungetbuf, kungetsz);
    free_isrch_spots();

    zfree(cutbuf.buf, cutbuf.len);
    for(i = KRINGCT; i--; )
	zfree(kring[i].buf, kring[i].len);
    for(i = 35; i--; )
	zfree(vibuf[i].buf, vibuf[i].len);

    /* editor entry points */
    trashzleptr = noop_function;
    gotwordptr = noop_function;
    refreshptr = noop_function;
    spaceinlineptr = noop_function_int;
    zlereadptr = fallback_zleread;

    return 0;
}

#endif /* MODULE */
