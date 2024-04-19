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
/*-
 *  Copyright (c) 1993 John Brezak
 *  All rights reserved.
 * 
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR `AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef lint
static char rcsid[] = "$Id: rusers_proc.c,v 1.2.34.2 1999/03/16 17:23:16 wsanchez Exp $";
#endif /* not lint */

#include <signal.h>
#include <sys/types.h>
#include <sys/time.h>
#include <utmp.h>
#include <stdio.h>
#include <syslog.h>
#include <rpc/rpc.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/stat.h>
#ifdef XIDLE
#include <setjmp.h>
#include <X11/Xlib.h>
#include <X11/extensions/xidle.h>
#endif
#include <rpcsvc/rusers.h>	/* New version */
#include <rpcsvc/rnusers.h>	/* Old version */

#define	IGNOREUSER	"sleeper"

#ifdef OSF
#define _PATH_UTMP UTMP_FILE
#endif

#ifndef _PATH_UTMP
#define _PATH_UTMP "/var/run/utmp"
#endif

#ifndef _PATH_DEV
#define _PATH_DEV "/dev"
#endif

#ifndef UT_LINESIZE
#define UT_LINESIZE sizeof(((struct utmp *)0)->ut_line)
#endif
#ifndef UT_NAMESIZE
#define UT_NAMESIZE sizeof(((struct utmp *)0)->ut_name)
#endif
#ifndef UT_HOSTSIZE
#define UT_HOSTSIZE sizeof(((struct utmp *)0)->ut_host)
#endif

typedef char ut_line_t[UT_LINESIZE];
typedef char ut_name_t[UT_NAMESIZE];
typedef char ut_host_t[UT_HOSTSIZE];

struct rusers_utmp utmps[MAXUSERS];
struct utmpidle *utmp_idlep[MAXUSERS];
struct utmpidle utmp_idle[MAXUSERS];
ut_line_t line[MAXUSERS];
ut_name_t name[MAXUSERS];
ut_host_t host[MAXUSERS];

extern int from_inetd;

FILE *ufp;

#ifdef XIDLE
Display *dpy;

static jmp_buf openAbort;

static void
abortOpen ()
{
    longjmp (openAbort, 1);
}

XqueryIdle(char *display)
{
        int first_event, first_error;
        Time IdleTime;

        (void) signal (SIGALRM, abortOpen);
        (void) alarm ((unsigned) 10);
        if (!setjmp (openAbort)) {
                if (!(dpy= XOpenDisplay(display))) {
                        syslog(LOG_ERR, "Cannot open display %s", display);
                        return(-1);
                }
                if (XidleQueryExtension(dpy, &first_event, &first_error)) {
                        if (!XGetIdleTime(dpy, &IdleTime)) {
                                syslog(LOG_ERR, "%s: Unable to get idle time.", display);
                                return(-1);
                        }
                }
                else {
                        syslog(LOG_ERR, "%s: Xidle extension not loaded.", display);
                        return(-1);
                }
                XCloseDisplay(dpy);
        }
        else {
                syslog(LOG_ERR, "%s: Server grabbed for over 10 seconds.", display);
                return(-1);
        }
        (void) signal (SIGALRM, SIG_DFL);
        (void) alarm ((unsigned) 0);

        IdleTime /= 1000;
        return((IdleTime + 30) / 60);
}
#endif

static u_int
getidle(char *tty, char *display)
{
        struct stat st;
        char devname[PATH_MAX];
        time_t now;
        u_long idle;
        
        /*
         * If this is an X terminal or console, then try the
         * XIdle extension
         */
#ifdef XIDLE
        if (display && *display && (idle = XqueryIdle(display)) >= 0)
                return(idle);
#endif
        idle = 0;
        if (*tty == 'X') {
                u_long kbd_idle, mouse_idle;
#if	!defined(i386)
                kbd_idle = getidle("kbd", NULL);
#else
#if (__GNUC__ >= 2)
#warning i386 console hack here
#endif
                kbd_idle = getidle("vga", NULL);
#endif
                mouse_idle = getidle("mouse", NULL);
                idle = (kbd_idle < mouse_idle)?kbd_idle:mouse_idle;
        }
        else {
                sprintf(devname, "%s/%s", _PATH_DEV, tty);
                if (stat(devname, &st) < 0) {
#ifdef DEBUG
                        printf("%s: %s\n", devname, strerror(errno));
#endif
                        return(-1);
                }
                time(&now);
#ifdef DEBUG
                printf("%s: now=%d atime=%d\n", devname, now,
                       st.st_atime);
#endif
                idle = now - st.st_atime;
                idle = (idle + 30) / 60; /* secs->mins */
        }
        if (idle < 0) idle = 0;

        return(idle);
}
        
int *
rusers_num()
{
        int num_users = 0;
	struct utmp usr;

        ufp = fopen(_PATH_UTMP, "r");
        if (!ufp) {
                syslog(LOG_ERR, "%m");
                return(0);
        }

        /* only entries with both name and line fields */
        while (fread((char *)&usr, sizeof(usr), 1, ufp) == 1)
                if (*usr.ut_name && *usr.ut_line &&
		    strncmp(usr.ut_name, IGNOREUSER,
                            sizeof(usr.ut_name))
#ifdef OSF
                    && usr.ut_type == USER_PROCESS
#endif
                    ) {
                        num_users++;
                }

        fclose(ufp);
        return(&num_users);
}

static utmp_array *
do_names_3(int all)
{
        static utmp_array ut;
	struct utmp usr;
        int nusers = 0;
        
        bzero((char *)&ut, sizeof(ut));
        ut.utmp_array_val = &utmps[0];
        
	ufp = fopen(_PATH_UTMP, "r");
        if (!ufp) {
                syslog(LOG_ERR, "%m");
                return(&ut);
        }

        /* only entries with both name and line fields */
        while (fread((char *)&usr, sizeof(usr), 1, ufp) == 1 &&
               nusers < MAXUSERS)
                if (*usr.ut_name && *usr.ut_line &&
		    strncmp(usr.ut_name, IGNOREUSER,
                            sizeof(usr.ut_name))
#ifdef OSF
                    && usr.ut_type == USER_PROCESS
#endif
                    ) {
                        utmps[nusers].ut_type = RUSERS_USER_PROCESS;
                        utmps[nusers].ut_time =
                                usr.ut_time;
                        utmps[nusers].ut_idle =
                                getidle(usr.ut_line, usr.ut_host);
                        utmps[nusers].ut_line = line[nusers];
                        strncpy(line[nusers], usr.ut_line, sizeof(line[nusers]));
                        utmps[nusers].ut_user = name[nusers];
                        strncpy(name[nusers], usr.ut_name, sizeof(name[nusers]));
                        utmps[nusers].ut_host = host[nusers];
                        strncpy(host[nusers], usr.ut_host, sizeof(host[nusers]));
                        nusers++;
                }
        ut.utmp_array_len = nusers;

        fclose(ufp);
        return(&ut);
}

utmp_array *
rusersproc_names_3()
{
        return(do_names_3(0));
}

utmp_array *
rusersproc_allnames_3()
{
        return(do_names_3(1));
}

static struct utmpidlearr *
do_names_2(int all)
{
        static struct utmpidlearr ut;
	struct utmp usr;
        int nusers = 0;
        
        bzero((char *)&ut, sizeof(ut));
        ut.uia_arr = utmp_idlep;
        ut.uia_cnt = 0;
        
	ufp = fopen(_PATH_UTMP, "r");
        if (!ufp) {
                syslog(LOG_ERR, "%m");
                return(&ut);
        }

        /* only entries with both name and line fields */
        while (fread((char *)&usr, sizeof(usr), 1, ufp) == 1 &&
               nusers < MAXUSERS)
                if (*usr.ut_name && *usr.ut_line &&
		    strncmp(usr.ut_name, IGNOREUSER,
                            sizeof(usr.ut_name))
#ifdef OSF
                    && usr.ut_type == USER_PROCESS
#endif
                    ) {
                        utmp_idlep[nusers] = &utmp_idle[nusers];
                        utmp_idle[nusers].ui_utmp.ut_time =
                                usr.ut_time;
                        utmp_idle[nusers].ui_idle =
                                getidle(usr.ut_line, usr.ut_host);
                        strncpy(utmp_idle[nusers].ui_utmp.ut_line, usr.ut_line, sizeof(utmp_idle[nusers].ui_utmp.ut_line));
                        strncpy(utmp_idle[nusers].ui_utmp.ut_name, usr.ut_name, sizeof(utmp_idle[nusers].ui_utmp.ut_name));
                        strncpy(utmp_idle[nusers].ui_utmp.ut_host, usr.ut_host, sizeof(utmp_idle[nusers].ui_utmp.ut_host));
                        nusers++;
                }

        ut.uia_cnt = nusers;
        fclose(ufp);
        return(&ut);
}

struct utmpidlearr *
rusersproc_names_2()
{
        return(do_names_2(0));
}

struct utmpidlearr *
rusersproc_allnames_2()
{
        return(do_names_2(1));
}

void
rusers_service(rqstp, transp)
	struct svc_req *rqstp;
	SVCXPRT *transp;
{
	union {
		int fill;
	} argument;
	char *result;
	bool_t (*xdr_argument)(), (*xdr_result)();
	char *(*local)();

	switch (rqstp->rq_proc) {
	case NULLPROC:
		(void)svc_sendreply(transp, xdr_void, (char *)NULL);
		goto leave;

	case RUSERSPROC_NUM:
		xdr_argument = xdr_void;
		xdr_result = xdr_int;
                switch (rqstp->rq_vers) {
                case RUSERSVERS_3:
                case RUSERSVERS_IDLE:
                        local = (char *(*)()) rusers_num;
                        break;
                default:
                        svcerr_progvers(transp, RUSERSVERS_IDLE, RUSERSVERS_3);
                        goto leave;
                        /*NOTREACHED*/
                }
		break;

	case RUSERSPROC_NAMES:
		xdr_argument = xdr_void;
		xdr_result = xdr_utmp_array;
                switch (rqstp->rq_vers) {
                case RUSERSVERS_3:
                        local = (char *(*)()) rusersproc_names_3;
                        break;

                case RUSERSVERS_IDLE:
                        xdr_result = xdr_utmpidlearr;
                        local = (char *(*)()) rusersproc_names_2;
                        break;

                default:
                        svcerr_progvers(transp, RUSERSVERS_IDLE, RUSERSVERS_3);
                        goto leave;
                        /*NOTREACHED*/
                }
		break;

	case RUSERSPROC_ALLNAMES:
		xdr_argument = xdr_void;
		xdr_result = xdr_utmp_array;
                switch (rqstp->rq_vers) {
                case RUSERSVERS_3:
                        local = (char *(*)()) rusersproc_allnames_3;
                        break;

                case RUSERSVERS_IDLE:
                        xdr_result = xdr_utmpidlearr;
                        local = (char *(*)()) rusersproc_allnames_2;
                        break;

                default:
                        svcerr_progvers(transp, RUSERSVERS_IDLE, RUSERSVERS_3);
                        goto leave;
                        /*NOTREACHED*/
                }
		break;

	default:
		svcerr_noproc(transp);
		goto leave;
	}
	bzero((char *)&argument, sizeof(argument));
	if (!svc_getargs(transp, xdr_argument, &argument)) {
		svcerr_decode(transp);
		goto leave;
	}
	result = (*local)(&argument, rqstp);
	if (result != NULL && !svc_sendreply(transp, xdr_result, result)) {
		svcerr_systemerr(transp);
	}
	if (!svc_freeargs(transp, xdr_argument, &argument)) {
		(void)fprintf(stderr, "unable to free arguments\n");
		exit(1);
	}
leave:
        if (from_inetd)
                exit(0);
}
