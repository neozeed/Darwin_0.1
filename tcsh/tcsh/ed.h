/* $Header: /CVSRoot/CoreOS/Commands/Other/tcsh/tcsh/ed.h,v 1.1.1.2 1998/11/05 01:13:05 wsanchez Exp $ */
/*
 * ed.h: Editor declarations and globals
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
#ifndef _h_ed
#define _h_ed

#ifndef EXTERN
# define EXTERN extern
#endif

#define TABSIZE		8	/* usually 8 spaces/tab */
#define MAXMACROLEVELS	10	/* max number of nested kbd macros */

#ifdef WINNT
/* 256 + 24 (fkeys) +  4 (arrow) + 2 (ins/del) +2 (pgup/dn) +2 (home/end) */
# define NT_NUM_KEYS	290
#else /* !WINNT */
# define NT_NUM_KEYS	256
#endif /* !WINNT */

extern int errno;

/****************************************************************************/
/* stuff for the different states returned by the character editor routines */
/****************************************************************************/

#define CCRETVAL	char	/* size needed for the different char editor */
 /* return values */

#define KEYCMD   unsigned char	/* size needed to index into CcFuncTbl */
 /* Must be unsigned 		       */

typedef CCRETVAL(*PFCmd) __P((int));	/* pointer to function returning CCRETVAL */

struct KeyFuncs {		/* for the "bind" shell command */
    char   *name;		/* function name for bind command */
    int     func;		/* function numeric value */
    char   *desc;		/* description of function */
};

extern PFCmd CcFuncTbl[];	/* table of available commands */
extern KEYCMD CcKeyMap[];	/* keymap table, each index into above tbl */
extern KEYCMD CcAltMap[];	/* Alt keymap table */
extern KEYCMD CcEmacsMap[];	/* keymap table for Emacs default bindings */
extern KEYCMD CcViCmdMap[];	/* for Vi command mode defaults */
extern struct KeyFuncs FuncNames[];	/* string names vs. CcFuncTbl indices */

extern KEYCMD NumFuns;		/* number of KEYCMDs in above table */

#define	CC_ERROR		100	/* there should NOT be 100 different... */
#define CC_FATAL		101	/* fatal error: inconsistant, must
					 * reset */
#define	CC_NORM			0
#define	CC_NEWLINE		1
#define	CC_EOF			2
#define	CC_COMPLETE		3
#define	CC_LIST_CHOICES		4
#define	CC_LIST_GLOB		5
#define CC_EXPAND_GLOB		6
#define	CC_HELPME		9
#define CC_CORRECT		10
#define CC_WHICH		11
#define CC_ARGHACK		12
#define CC_CORRECT_L		13
#define CC_REFRESH		14
#define CC_EXPAND_VARS		15
#define CC_NORMALIZE_PATH	16
#define CC_LIST_ALL		17
#define CC_COMPLETE_ALL		18
#define CC_COMPLETE_FWD		19
#define CC_COMPLETE_BACK	20
#define CC_NORMALIZE_COMMAND	21

typedef struct {
    Char *buf;
    int   len;
} CStr;

typedef union Xmapval {		/* value passed to the Xkey routines */
    KEYCMD cmd;
    CStr str;
} XmapVal;

#define XK_NOD	-1		/* Internal tree node */
#define XK_CMD	 0		/* X-key was an editor command */
#define XK_STR	 1		/* X-key was a string macro */
#define XK_EXE	 2		/* X-key was a unix command */

/****************************/
/* Editor state and buffers */
/****************************/

EXTERN KEYCMD *CurrentKeyMap;	/* current command key map */
EXTERN int inputmode;		/* insert, replace, replace1 mode */
EXTERN Char GettingInput;	/* true if getting an input line (mostly) */
EXTERN Char NeedsRedraw;	/* for editor and twenex error messages */
EXTERN Char InputBuf[INBUFSIZE];	/* the real input data */
EXTERN Char *LastChar, *Cursor;	/* point to the next open space */
EXTERN Char *InputLim;		/* limit of size of InputBuf */
EXTERN Char MetaNext;		/* flags for ^V and ^[ functions */
EXTERN Char AltKeyMap;		/* Using alternative command map (for vi mode) */
EXTERN Char VImode;		/* true if running in vi mode (PWP 6-27-88) */
EXTERN Char *Mark;		/* the emacs "mark" (dot is Cursor) */
EXTERN Char DoingArg;		/* true if we have an argument */
EXTERN int Argument;		/* "universal" argument value */
EXTERN KEYCMD LastCmd;		/* previous command executed */
EXTERN Char KillBuf[INBUFSIZE];	/* kill buffer */
EXTERN Char *LastKill;		/* points to end of kill buffer */

EXTERN Char UndoBuf[INBUFSIZE];
EXTERN Char *UndoPtr;
EXTERN int  UndoSize;
EXTERN int  UndoAction;

EXTERN Char HistBuf[INBUFSIZE];	/* history buffer */
EXTERN Char *LastHist;		/* points to end of history buffer */
EXTERN int Hist_num;		/* what point up the history we are at now. */
EXTERN Char WhichBuf[INBUFSIZE];	/* buffer for which command */
EXTERN Char *LastWhich;		/* points to end of which buffer */
EXTERN Char *CursWhich;		/* points to the cursor point in which buf */
EXTERN int HistWhich;		/* Hist_num is saved in this */
EXTERN char Expand;		/* true if we are expanding a line */
extern Char HistLit;		/* true if history lines are shown literal */
EXTERN Char CurrentHistLit;	/* Literal status of current show history line */

/*
 * These are truly extern
 */
extern int MacroLvl;

EXTERN Char *KeyMacro[MAXMACROLEVELS];

EXTERN Char **Display;		/* display buffer seed vector */
EXTERN int CursorV,		/* real cursor vertical (line) */
        CursorH,		/* real cursor horisontal (column) */
        TermV,			/* number of real screen lines
				 * (sizeof(DisplayBuf) / width */
        TermH;			/* screen width */
EXTERN Char **Vdisplay;		/* new buffer */

/* Variables that describe terminal ability */
EXTERN int T_Lines, T_Cols;	/* Rows and Cols of the terminal */
EXTERN Char T_CanIns;		/* true if I can insert characters */
EXTERN Char T_CanDel;		/* dito for delete characters */
EXTERN Char T_Tabs;		/* true if tty interface is passing tabs */
EXTERN Char T_Margin;		
#define MARGIN_AUTO  1		/* term has auto margins */
#define MARGIN_MAGIC 2		/* concept glitch */
EXTERN speed_t T_Speed;		/* Tty input Baud rate */
EXTERN Char T_CanCEOL;		/* true if we can clear to end of line */
EXTERN Char T_CanUP;		/* true if this term can do reverse linefeen */
EXTERN Char T_HasMeta;		/* true if we have a meta key */

/* note the extra characters in the Strchr() call in this macro */
#define isword(c)	(Isalpha(c)||Isdigit(c)||Strchr(word_chars,c))
#define min(x,y)	(((x)<(y))?(x):(y))
#define max(x,y)	(((x)>(y))?(x):(y))

/*
 * Terminal dependend data structures
 */
typedef struct {
#ifdef WINNT
    int dummy;
#else /* !WINNT */
# if defined(POSIX) || defined(TERMIO)
#  ifdef POSIX
    struct termios d_t;
#  else
    struct termio d_t;
#  endif /* POSIX */
# else /* SGTTY */
#  ifdef TIOCGETP
    struct sgttyb d_t;
#  endif /* TIOCGETP */
#  ifdef TIOCGETC
    struct tchars d_tc;
#  endif /* TIOCGETC */
#  ifdef TIOCGPAGE
    struct ttypagestat d_pc;
#  endif /* TIOCGPAGE */
#  ifdef TIOCLGET
    int d_lb;
#  endif /* TIOCLGET */
# endif /* POSIX || TERMIO */
# ifdef TIOCGLTC
    struct ltchars d_ltc;
# endif /* TIOCGLTC */
#endif /* WINNT */
} ttydata_t;

#define MODE_INSERT	0
#define MODE_REPLACE	1
#define MODE_REPLACE_1	2

#define EX_IO	0	/* while we are executing	*/
#define ED_IO	1	/* while we are editing		*/
#define TS_IO	2	/* new mode from terminal	*/
#define QU_IO	2	/* used only for quoted chars	*/
#define NN_IO	3	/* The number of entries	*/

#if defined(POSIX) || defined(TERMIO)
# define M_INPUT	0
# define M_OUTPUT	1
# define M_CONTROL	2
# define M_LINED	3
# define M_CHAR		4
# define M_NN		5
#else /* GSTTY */
# define M_CONTROL	0
# define M_LOCAL	1
# define M_CHAR		2
# define M_NN		3
#endif /* TERMIO */
typedef struct { 
    char *t_name;
    int  t_setmask;
    int  t_clrmask;
} ttyperm_t[NN_IO][M_NN];

extern ttyperm_t ttylist;
#include "ed.decls.h"

#endif /* _h_ed */
