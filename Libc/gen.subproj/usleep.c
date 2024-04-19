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
/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
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


#include <sys/time.h>
#include <signal.h>
#include <unistd.h>

#define	TICK	10000		/* system clock resolution in microseconds */

static void sleephandler __P((int));
static volatile int ringring;

void
usleep(useconds)
	unsigned int useconds;
{
	struct itimerval itv, oitv;
	struct sigaction act, oact;
	sigset_t set, oset;

	if (!useconds)
		return;

	sigemptyset(&set);
	sigaddset(&set, SIGALRM);
	sigprocmask(SIG_BLOCK, &set, &oset);

	act.sa_handler = sleephandler;
	act.sa_flags = 0;
	sigemptyset(&act.sa_mask);
#if defined(__DYNAMIC__)
        _dyld_lookup_and_bind_fully("_usleep", NULL, NULL);
        _sigaction_nobind(SIGALRM, &act, &oact);
#else
	sigaction(SIGALRM, &act, &oact);
#endif
	timerclear(&itv.it_interval);
	itv.it_value.tv_sec = useconds / 1000000;
	itv.it_value.tv_usec = useconds % 1000000;
	setitimer(ITIMER_REAL, &itv, &oitv);

	if (timerisset(&oitv.it_value)) {
		if (timercmp(&oitv.it_value, &itv.it_value, >)) {
			timersub(&oitv.it_value, &itv.it_value, &oitv.it_value);
		} else {
			itv.it_value = oitv.it_value;
			/*
			 * This is a hack, but we must have time to return
			 * from the setitimer after the alarm or else it'll
			 * be restarted.  And, anyway, sleep never did
			 * anything more than this before.
			 */
			oitv.it_value.tv_sec = 0;
			oitv.it_value.tv_usec = 2 * TICK;

			setitimer(ITIMER_REAL, &itv, NULL);
		}
	}

	set = oset;
	sigdelset(&set, SIGALRM);
	ringring = 0;
 	(void) sigsuspend(&set);

	if (!ringring) {
		struct itimerval nulltv;
		/*
		 * Interrupted by other signal; allow for pending 
		 * SIGALRM to be processed before resetting handler,
		 * after first turning off the timer.
		 */
		timerclear(&nulltv.it_interval);
		timerclear(&nulltv.it_value);
		(void) setitimer(ITIMER_REAL, &nulltv, NULL);
	}
	sigprocmask(SIG_SETMASK, &oset, NULL);
#if defined(__DYNAMIC__)
        _sigaction_nobind(SIGALRM, &oact, NULL);
#else
        sigaction(SIGALRM, &oact, NULL);
#endif
	(void) setitimer(ITIMER_REAL, &oitv, NULL);
}

/* ARGSUSED */
static void
sleephandler(sig)
	int sig;
{
	ringring = 1;
}
