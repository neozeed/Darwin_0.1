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
 * Sun RPC is a product of Sun Microsystems, Inc. and is provided for
 * unrestricted use provided that this legend is included on all tape
 * media and as a part of the software program in whole or part.  Users
 * may copy or modify Sun RPC without charge, but are not authorized
 * to license or distribute it to anyone else except as part of a product or
 * program developed by the user.
 *
 * SUN RPC IS PROVIDED AS IS WITH NO WARRANTIES OF ANY KIND INCLUDING THE
 * WARRANTIES OF DESIGN, MERCHANTIBILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE, OR ARISING FROM A COURSE OF DEALING, USAGE OR TRADE PRACTICE.
 *
 * Sun RPC is provided with no support and without any obligation on the
 * part of Sun Microsystems, Inc. to assist in its use, correction,
 * modification or enhancement.
 *
 * SUN MICROSYSTEMS, INC. SHALL HAVE NO LIABILITY WITH RESPECT TO THE
 * INFRINGEMENT OF COPYRIGHTS, TRADE SECRETS OR ANY PATENTS BY SUN RPC
 * OR ANY PART THEREOF.
 *
 * In no event will Sun Microsystems, Inc. be liable for any lost revenue
 * or profits or other special, indirect and consequential damages, even if
 * Sun has been advised of the possibility of such damages.
 *
 * Sun Microsystems, Inc.
 * 2550 Garcia Avenue
 * Mountain View, California  94043
 */
#ifndef lint
/*static char sccsid[] = "from: @(#)rpc.rstatd.c 1.1 86/09/25 Copyr 1984 Sun Micro";*/
/*static char sccsid[] = "from: @(#)rstat_proc.c	2.2 88/08/01 4.0 RPCSRC";*/
static char rcsid[] = "$Id: rstat_proc.c,v 1.1.1.1.52.2 1999/03/16 17:23:14 wsanchez Exp $";
#endif

/*
 * rstat service:  built with rstat.x and derived from rpc.rstatd.c
 *
 * Copyright (c) 1984 by Sun Microsystems, Inc.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>
#include <kvm.h>
#include <limits.h>
#include <rpc/rpc.h>
#include <sys/socket.h>
#include <nlist.h>
#include <syslog.h>
#include <sys/errno.h>
#include <sys/param.h>
#ifdef BSD
#include <sys/vmmeter.h>
#include <sys/dkstat.h>
#else
#include <sys/dk.h>
#endif
#include <net/if.h>

#undef FSHIFT			 /* Use protocol's shift and scale values */
#undef FSCALE
#undef DK_NDRIVE
#undef CPUSTATES
#undef if_ipackets
#undef if_ierrors
#undef if_opackets
#undef if_oerrors
#undef if_collisions
#include <rpcsvc/rstat.h>

#ifdef BSD
#define BSD_CPUSTATES	5	/* Use protocol's idea of CPU states */
int	cp_xlat[CPUSTATES] = { CP_USER, CP_NICE, CP_SYS, CP_IDLE };
#endif

struct nlist nl[] = {
#define	X_CPTIME	0
	{ "_cp_time" },
#define	X_CNT		1
	{ "_cnt" },
#define	X_IFNET		2
	{ "_ifnet" },
#define	X_DKXFER	3
	{ "_dk_xfer" },
#define	X_BOOTTIME	4
	{ "_boottime" },
#define X_HZ		5
	{ "_hz" },
#ifdef vax
#define	X_AVENRUN	6
	{ "_avenrun" },
#endif
	"",
};
int firstifnet, numintfs;	/* chain of ethernet interfaces */
int stats_service();

extern int from_inetd;
int sincelastreq = 0;		/* number of alarms since last request */
extern int closedown;
kvm_t *kfd;

union {
    struct stats s1;
    struct statsswtch s2;
    struct statstime s3;
} stats_all;

void updatestat();
static stat_is_init = 0;
extern int errno;

#ifndef FSCALE
#define FSCALE (1 << 8)
#endif

#ifndef BSD
/*
 * BSD has the kvm facility for getting info from the
 * kernel. If you aren't on BSD, this surfices.
 */
int kmem;

kvm_read(kfd, off, addr, size)
	void *kfd;
        unsigned long off, size;
        char *addr;
{
        int len;
	if (lseek(kmem, off, 0) == -1)
                return(-1);
	return(read(kmem, addr, size));
}

kvm_nlist(kfd, nl)
	void *kfd;
        struct nlist *nl;
{
	int n = nlist("/vmunix", nl);
	if (nl[0].n_value == 0)
                return(n);

	if ((kmem = open("/dev/kmem", 0)) < 0)
                return(-1);
        return(0);
}
#endif

stat_init()
{
    stat_is_init = 1;
    setup();
    updatestat();
    (void) signal(SIGALRM, updatestat);
    alarm(1);
}

statstime *
rstatproc_stats_3()
{
    if (! stat_is_init)
        stat_init();
    sincelastreq = 0;
    return(&stats_all.s3);
}

statsswtch *
rstatproc_stats_2()
{
    if (! stat_is_init)
        stat_init();
    sincelastreq = 0;
    return(&stats_all.s2);
}

stats *
rstatproc_stats_1()
{
    if (! stat_is_init)
        stat_init();
    sincelastreq = 0;
    return(&stats_all.s1);
}

u_int *
rstatproc_havedisk_3()
{
    static u_int have;

    if (! stat_is_init)
        stat_init();
    sincelastreq = 0;
    have = havedisk();
	return(&have);
}

u_int *
rstatproc_havedisk_2()
{
    return(rstatproc_havedisk_3());
}

u_int *
rstatproc_havedisk_1()
{
    return(rstatproc_havedisk_3());
}

void
updatestat()
{
	int off, i, hz;
	struct vmmeter cnt;
	struct ifnet ifnet;
	double avrun[3];
	struct timeval tm, btm;
#ifdef BSD
	int cp_time[BSD_CPUSTATES];
#endif

#ifdef DEBUG
	fprintf(stderr, "entering updatestat\n");
#endif
	if (sincelastreq >= closedown) {
#ifdef DEBUG
                fprintf(stderr, "about to closedown\n");
#endif
                if (from_inetd)
                        exit(0);
                else {
                        stat_is_init = 0;
                        return;
                }
	}
	sincelastreq++;

	if (kvm_read(kfd, (long)nl[X_HZ].n_value, (char *)&hz, sizeof hz) !=
	    sizeof hz) {
		syslog(LOG_ERR, "rstat: can't read hz from kmem\n");
		exit(1);
	}
#ifdef BSD
 	if (kvm_read(kfd, (long)nl[X_CPTIME].n_value, (char *)cp_time,
		     sizeof (cp_time))
	    != sizeof (cp_time)) {
		syslog(LOG_ERR, "rstat: can't read cp_time from kmem\n");
		exit(1);
	}
	for (i = 0; i < CPUSTATES; i++)
		stats_all.s1.cp_time[i] = cp_time[cp_xlat[i]];
#else
 	if (kvm_read(kfd, (long)nl[X_CPTIME].n_value,
		     (char *)stats_all.s1.cp_time,
		     sizeof (stats_all.s1.cp_time))
	    != sizeof (stats_all.s1.cp_time)) {
		syslog(LOG_ERR, "rstat: can't read cp_time from kmem\n");
		exit(1);
	}
#endif
#ifdef vax
 	if (kvm_read(kfd, (long)nl[X_AVENRUN].n_value, (char *)avrun,
		     sizeof (avrun)) != sizeof (avrun)) {
		syslog(LOG_ERR, "rstat: can't read avenrun from kmem\n");
		exit(1);
	}
#endif
#ifdef BSD
        (void)getloadavg(avrun, sizeof(avrun) / sizeof(avrun[0]));
#endif
	stats_all.s2.avenrun[0] = avrun[0] * FSCALE;
	stats_all.s2.avenrun[1] = avrun[1] * FSCALE;
	stats_all.s2.avenrun[2] = avrun[2] * FSCALE;
 	if (kvm_read(kfd, (long)nl[X_BOOTTIME].n_value,
		     (char *)&btm, sizeof (stats_all.s2.boottime))
	    != sizeof (stats_all.s2.boottime)) {
		syslog(LOG_ERR, "rstat: can't read boottime from kmem\n");
		exit(1);
	}
	stats_all.s2.boottime.tv_sec = btm.tv_sec;
	stats_all.s2.boottime.tv_usec = btm.tv_usec;


#ifdef DEBUG
	fprintf(stderr, "%d %d %d %d\n", stats_all.s1.cp_time[0],
	    stats_all.s1.cp_time[1], stats_all.s1.cp_time[2], stats_all.s1.cp_time[3]);
#endif

 	if (kvm_read(kfd, (long)nl[X_CNT].n_value, (char *)&cnt, sizeof cnt) !=
	    sizeof cnt) {
		syslog(LOG_ERR, "rstat: can't read cnt from kmem\n");
		exit(1);
	}
	stats_all.s1.v_pgpgin = cnt.v_pgpgin;
	stats_all.s1.v_pgpgout = cnt.v_pgpgout;
	stats_all.s1.v_pswpin = cnt.v_pswpin;
	stats_all.s1.v_pswpout = cnt.v_pswpout;
	stats_all.s1.v_intr = cnt.v_intr;
	gettimeofday(&tm, (struct timezone *) 0);
	stats_all.s1.v_intr -= hz*(tm.tv_sec - btm.tv_sec) +
	    hz*(tm.tv_usec - btm.tv_usec)/1000000;
	stats_all.s2.v_swtch = cnt.v_swtch;

 	if (kvm_read(kfd, (long)nl[X_DKXFER].n_value,
		     (char *)stats_all.s1.dk_xfer,
		     sizeof (stats_all.s1.dk_xfer))
	    != sizeof (stats_all.s1.dk_xfer)) {
		syslog(LOG_ERR, "rstat: can't read dk_xfer from kmem\n");
		exit(1);
	}

	stats_all.s1.if_ipackets = 0;
	stats_all.s1.if_opackets = 0;
	stats_all.s1.if_ierrors = 0;
	stats_all.s1.if_oerrors = 0;
	stats_all.s1.if_collisions = 0;
	for (off = firstifnet, i = 0; off && i < numintfs; i++) {
		if (kvm_read(kfd, off, (char *)&ifnet, sizeof ifnet) !=
		    sizeof ifnet) {
			syslog(LOG_ERR, "rstat: can't read ifnet from kmem\n");
			exit(1);
		}
		stats_all.s1.if_ipackets += ifnet.if_data.ifi_ipackets;
		stats_all.s1.if_opackets += ifnet.if_data.ifi_opackets;
		stats_all.s1.if_ierrors += ifnet.if_data.ifi_ierrors;
		stats_all.s1.if_oerrors += ifnet.if_data.ifi_oerrors;
		stats_all.s1.if_collisions += ifnet.if_data.ifi_collisions;
		off = (int) ifnet.if_next;
	}
	gettimeofday((struct timeval *)&stats_all.s3.curtime,
		(struct timezone *) 0);
	alarm(1);
}

setup()
{
	struct ifnet ifnet;
	int off;
	char errbuf[_POSIX2_LINE_MAX];

	kfd = kvm_openfiles(NULL, NULL, NULL, O_RDONLY, errbuf);
	if (kfd == NULL) {
		syslog(LOG_ERR, "rstat: %s", errbuf);
		exit (1);
	}

	if (kvm_nlist(kfd, nl) != 0) {
		syslog(LOG_ERR, "rstatd: Can't get namelist.");
		exit (1);
        }

	if (kvm_read(kfd, (long)nl[X_IFNET].n_value, &firstifnet,
                     sizeof(int)) != sizeof(int))  {
		syslog(LOG_ERR, "rstat: can't read firstifnet from kmem\n");
		exit(1);
        }

	numintfs = 0;
	for (off = firstifnet; off;) {
		if (kvm_read(kfd, off, (char *)&ifnet, sizeof ifnet) !=
		    sizeof ifnet) {
			syslog(LOG_ERR, "rstat: can't read ifnet from kmem\n");
			exit(1);
		}
		numintfs++;
		off = (int) ifnet.if_next;
	}
}

/*
 * returns true if have a disk
 */
int
havedisk()
{
	int i, cnt;
	long  xfer[DK_NDRIVE];

	if (kvm_nlist(kfd, nl) != 0) {
		syslog(LOG_ERR, "rstatd: Can't get namelist.");
		exit (1);
        }

	if (kvm_read(kfd, (long)nl[X_DKXFER].n_value,
		     (char *)xfer, sizeof xfer) != sizeof xfer) {
		syslog(LOG_ERR, "rstat: can't read kmem\n");
		exit(1);
	}
	cnt = 0;
	for (i=0; i < DK_NDRIVE; i++)
		cnt += xfer[i];
	return (cnt != 0);
}

void
rstat_service(rqstp, transp)
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

	case RSTATPROC_STATS:
		xdr_argument = xdr_void;
		xdr_result = xdr_statstime;
                switch (rqstp->rq_vers) {
                case RSTATVERS_ORIG:
                        local = (char *(*)()) rstatproc_stats_1;
                        break;
                case RSTATVERS_SWTCH:
                        local = (char *(*)()) rstatproc_stats_2;
                        break;
                case RSTATVERS_TIME:
                        local = (char *(*)()) rstatproc_stats_3;
                        break;
                default:
                        svcerr_progvers(transp, RSTATVERS_ORIG, RSTATVERS_TIME);
                        goto leave;
                        /*NOTREACHED*/
                }
		break;

	case RSTATPROC_HAVEDISK:
		xdr_argument = xdr_void;
		xdr_result = xdr_u_int;
                switch (rqstp->rq_vers) {
                case RSTATVERS_ORIG:
                        local = (char *(*)()) rstatproc_havedisk_1;
                        break;
                case RSTATVERS_SWTCH:
                        local = (char *(*)()) rstatproc_havedisk_2;
                        break;
                case RSTATVERS_TIME:
                        local = (char *(*)()) rstatproc_havedisk_3;
                        break;
                default:
                        svcerr_progvers(transp, RSTATVERS_ORIG, RSTATVERS_TIME);
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
