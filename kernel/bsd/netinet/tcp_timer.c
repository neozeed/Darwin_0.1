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

/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1982, 1986, 1988, 1990, 1993, 1995
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
 *
 *	@(#)tcp_timer.c	8.2 (Berkeley) 5/24/95
 */

#ifndef TUBA_INCLUDE
#include <sys/param.h>
#include <sys/systm.h>
#include <sys/malloc.h>
#include <sys/mbuf.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/protosw.h>
#include <sys/errno.h>

#include <net/if.h>
#include <net/route.h>

#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/in_pcb.h>
#include <netinet/ip_var.h>
#include <netinet/tcp.h>
#include <netinet/tcp_fsm.h>
#include <netinet/tcp_seq.h>
#include <netinet/tcp_timer.h>
#include <netinet/tcp_var.h>
#include <netinet/tcpip.h>

#include <kern/kdebug.h>

#if KDEBUG

#define DBG_FNC_TCP_FAST	NETDBG_CODE(DBG_NETTCP, (5 << 8))
#define DBG_FNC_TCP_SLOW	NETDBG_CODE(DBG_NETTCP, (5 << 8) | 1)

#endif

int	tcp_keepidle = TCPTV_KEEP_IDLE;
int	tcp_keepintvl = TCPTV_KEEPINTVL;
int	tcp_keepcnt = TCPTV_KEEPCNT;		/* max idle probes */
int	tcp_maxpersistidle = TCPTV_KEEP_IDLE;	/* max idle time in persist */
int	tcp_maxidle;
#else /* TUBA_INCLUDE */

extern	int tcp_maxpersistidle;
#endif /* TUBA_INCLUDE */

extern struct	inpcb	*tcp_hash_array[];

struct	inpcb	time_wait_slots[N_TIME_WAIT_SLOTS];
int		cur_tw_slot = 0;

#if DELACK_BITMASK_ON
u_long		delack_bitmask[N_TCP_HASH_ELEMENTS / 32];
u_long		current_active_connections = 0;
u_long		last_active_conn_count = 0;

#endif

void	add_to_time_wait(tp) 
	struct tcpcb	*tp;
{
	int		tw_slot;

	remque((queue_t) tp->t_inpcb);

	if (tp->t_timer[TCPT_2MSL] == 0) 
	    tp->t_timer[TCPT_2MSL] = 1;
	else 
	    if (tp->t_timer[TCPT_2MSL] >= N_TIME_WAIT_SLOTS)
		tp->t_timer[TCPT_2MSL] = N_TIME_WAIT_SLOTS -1;

	tw_slot = tp->t_timer[TCPT_2MSL] - 1 + cur_tw_slot; 

	if (tw_slot >= N_TIME_WAIT_SLOTS) 
		tw_slot -=  N_TIME_WAIT_SLOTS; 

	insque((queue_t) tp->t_inpcb, (queue_t) &time_wait_slots[tw_slot]);

}




/*
 * Fast timeout routine for processing delayed acks
 */
void
tcp_fasttimo()
{
    register struct inpcb *inp;
    register struct tcpcb *tp;

#if DELACK_BITMASK_ON
    register u_long			i,j;
    register u_long			temp_mask;
    register u_long			elem_base = 0;
#endif
    int s = splnet();


#if KDEBUG
    register int checked = 0;
#endif
    KERNEL_DEBUG(DBG_FNC_TCP_FAST | DBG_FUNC_START, 0,0,0,0,0);

#if DELACK_BITMASK_ON

    if ((current_active_connections > DELACK_BITMASK_THRESH) &&
	(last_active_conn_count > DELACK_BITMASK_THRESH)) {
	for (i=0; i < (N_TCP_HASH_ELEMENTS / 32); i++) {
	    if (delack_bitmask[i]) {
		temp_mask = 1;
		for (j=0; j < 32; j++) {
		    if (temp_mask & delack_bitmask[i]) {
			inp = tcp_hash_array[elem_base + j];
			for (; inp != 0; inp = inp->hash_next) {
#if KDEBUG
			    checked++;
#endif
			    if ((tp = (struct tcpcb *)inp->inp_ppcb) && (tp->t_flags & TF_DELACK)) {
				tp->t_flags &= ~TF_DELACK;
				tp->t_flags |= TF_ACKNOW;
				tcpstat.tcps_delack++;
				(void) tcp_output(tp);
			    }
			}
		    }
		    temp_mask <<=  1;
		}
		delack_bitmask[i] = 0;
	    }
	    elem_base += 32;
	}
    }
    else 
#endif
    {
	inp = tcb.inp_next;
	if (inp)
	    for (; inp != &tcb; inp = inp->inp_next)
		if ((tp = (struct tcpcb *)inp->inp_ppcb) &&
		    (tp->t_flags & TF_DELACK)) {
		    tp->t_flags &= ~TF_DELACK;
		    tp->t_flags |= TF_ACKNOW;
		    tcpstat.tcps_delack++;
		    (void) tcp_output(tp);
		}

    }

#if DELACK_BITMASK_ON
    last_active_conn_count = current_active_connections;
#endif

    splx(s);
#if KDEBUG
    KERNEL_DEBUG(DBG_FNC_TCP_FAST | DBG_FUNC_END, checked,tcpstat.tcps_delack,0,0,0);
#endif
}

/*
 * Tcp protocol timeout routine called every 500 ms.
 * Updates the timers in all active tcb's and
 * causes finite state machine actions if timers expire.
 */
void
tcp_slowtimo()
{
	register struct inpcb *ip, *ipnxt;
	register struct tcpcb *tp;
	int s = splnet();
	register int i;
#if KDEBUG
	register int checked = 0;
#endif
	KERNEL_DEBUG(DBG_FNC_TCP_SLOW | DBG_FUNC_START, 0,0,0,0,0);

	tcp_maxidle = tcp_keepcnt * tcp_keepintvl;
	/*
	 * Search through tcb's and update active timers.
	 */
	if (ip = tcb.inp_next) {
	  for (; ip != &tcb; ip = ipnxt) {
#if KDEBUG
	        checked++;
#endif
		ipnxt = ip->inp_next;
		tp = intotcpcb(ip);
		if (tp == 0 || tp->t_state == TCPS_LISTEN)
		    continue;
		for (i = 0; i < TCPT_NTIMERS; i++) {
		    if (tp->t_timer[i] && --tp->t_timer[i] == 0) {
			(void) tcp_usrreq(tp->t_inpcb->inp_socket,
					  PRU_SLOWTIMO, (struct mbuf *)0,
					  (struct mbuf *)i, (struct mbuf *)0);
			if (ipnxt->inp_prev != ip)
			    goto tpgone;
		    }
		}
		tp->t_idle++;
		if (tp->t_rtt)
		    tp->t_rtt++;
	    tpgone:
		;
	  }
	}
#if KDEBUG
	KERNEL_DEBUG(DBG_FNC_TCP_SLOW | DBG_FUNC_NONE, checked,0,0,0,0);

	checked = 0;
#endif
	/*
	 * Process the items in the current time-wait slot
	 */

	for (ip = time_wait_slots[cur_tw_slot].inp_next;
	     ip != &time_wait_slots[cur_tw_slot];
	     ip = ipnxt)
	{
#if KDEBUG
	        checked++;
#endif
		ipnxt = ip->inp_next;
		tp = intotcpcb(ip);
		tp->t_timer[TCPT_2MSL] = 0;
		(void) tcp_usrreq(ip->inp_socket,
				  PRU_SLOWTIMO, (struct mbuf *)0,
				  (struct mbuf *) TCPT_2MSL, (struct mbuf *)0);
	}

	time_wait_slots[cur_tw_slot].inp_next = &time_wait_slots[cur_tw_slot];
	time_wait_slots[cur_tw_slot].inp_prev = &time_wait_slots[cur_tw_slot];
	if (++cur_tw_slot >= N_TIME_WAIT_SLOTS)
		cur_tw_slot = 0;

	tcp_iss += TCP_ISSINCR/PR_SLOWHZ;		/* increment iss */
#ifdef TCP_COMPAT_42
	if ((int)tcp_iss < 0)
		tcp_iss = TCP_ISSINCR;			/* XXX */
#endif
	tcp_now++;					/* for timestamps */
	splx(s);

#if KDEBUG
	KERNEL_DEBUG(DBG_FNC_TCP_SLOW | DBG_FUNC_END, checked, cur_tw_slot,0,0,0);
#endif
}
#ifndef TUBA_INCLUDE

/*
 * Cancel all timers for TCP tp.
 */
void
tcp_canceltimers(tp)
	struct tcpcb *tp;
{
	register int i;

	for (i = 0; i < TCPT_NTIMERS; i++)
		tp->t_timer[i] = 0;
}

int	tcp_backoff[TCP_MAXRXTSHIFT + 1] =
    { 1, 2, 4, 8, 16, 32, 64, 64, 64, 64, 64, 64, 64 };

int tcp_totbackoff = 511;	/* sum of tcp_backoff[] */

/*
 * TCP timer processing.
 */
struct tcpcb *
tcp_timers(tp, timer)
	register struct tcpcb *tp;
	int timer;
{
	register int rexmt;

	switch (timer) {

	/*
	 * 2 MSL timeout in shutdown went off.  If we're closed but
	 * still waiting for peer to close and connection has been idle
	 * too long, or if 2MSL time is up from TIME_WAIT, delete connection
	 * control block.  Otherwise, check again in a bit.
	 */
	case TCPT_2MSL:
		if (tp->t_state != TCPS_TIME_WAIT &&
		    tp->t_idle <= tcp_maxidle) {
			tp->t_timer[TCPT_2MSL] = tcp_keepintvl;

			add_to_time_wait(tp);
		}
		else
			tp = tcp_close(tp);
		break;

	/*
	 * Retransmission timer went off.  Message has not
	 * been acked within retransmit interval.  Back off
	 * to a longer retransmit interval and retransmit one segment.
	 */
	case TCPT_REXMT:
		if (++tp->t_rxtshift > TCP_MAXRXTSHIFT) {
			tp->t_rxtshift = TCP_MAXRXTSHIFT;
			tcpstat.tcps_timeoutdrop++;
			tp = tcp_drop(tp, tp->t_softerror ?
			    tp->t_softerror : ETIMEDOUT);
			break;
		}
		tcpstat.tcps_rexmttimeo++;
		rexmt = TCP_REXMTVAL(tp) * tcp_backoff[tp->t_rxtshift];
		TCPT_RANGESET(tp->t_rxtcur, rexmt,
		    tp->t_rttmin, TCPTV_REXMTMAX);
		tp->t_timer[TCPT_REXMT] = tp->t_rxtcur;
		/*
		 * If losing, let the lower level know and try for
		 * a better route.  Also, if we backed off this far,
		 * our srtt estimate is probably bogus.  Clobber it
		 * so we'll take the next rtt measurement as our srtt;
		 * move the current srtt into rttvar to keep the current
		 * retransmit times until then.
		 */
		if (tp->t_rxtshift > TCP_MAXRXTSHIFT / 4) {
			in_losing(tp->t_inpcb);
			tp->t_rttvar += (tp->t_srtt >> TCP_RTT_SHIFT);
			tp->t_srtt = 0;
		}
		tp->snd_nxt = tp->snd_una;
		/*
		 * If timing a segment in this window, stop the timer.
		 */
		tp->t_rtt = 0;
		/*
		 * Close the congestion window down to one segment
		 * (we'll open it by one segment for each ack we get).
		 * Since we probably have a window's worth of unacked
		 * data accumulated, this "slow start" keeps us from
		 * dumping all that data as back-to-back packets (which
		 * might overwhelm an intermediate gateway).
		 *
		 * There are two phases to the opening: Initially we
		 * open by one mss on each ack.  This makes the window
		 * size increase exponentially with time.  If the
		 * window is larger than the path can handle, this
		 * exponential growth results in dropped packet(s)
		 * almost immediately.  To get more time between 
		 * drops but still "push" the network to take advantage
		 * of improving conditions, we switch from exponential
		 * to linear window opening at some threshhold size.
		 * For a threshhold, we use half the current window
		 * size, truncated to a multiple of the mss.
		 *
		 * (the minimum cwnd that will give us exponential
		 * growth is 2 mss.  We don't allow the threshhold
		 * to go below this.)
		 */
		{
		u_int win = min(tp->snd_wnd, tp->snd_cwnd) / 2 / tp->t_maxseg;
		if (win < 2)
			win = 2;
		tp->snd_cwnd = tp->t_maxseg;
		tp->snd_ssthresh = win * tp->t_maxseg;
		tp->t_dupacks = 0;
		}
		(void) tcp_output(tp);
		break;

	/*
	 * Persistance timer into zero window.
	 * Force a byte to be output, if possible.
	 */
	case TCPT_PERSIST:
		tcpstat.tcps_persisttimeo++;
		/*
		 * Hack: if the peer is dead/unreachable, we do not
		 * time out if the window is closed.  After a full
		 * backoff, drop the connection if the idle time
		 * (no responses to probes) reaches the maximum
		 * backoff that we would use if retransmitting.
		 */
		if (tp->t_rxtshift == TCP_MAXRXTSHIFT &&
		    (tp->t_idle >= tcp_maxpersistidle ||
		    tp->t_idle >= TCP_REXMTVAL(tp) * tcp_totbackoff)) {
			tcpstat.tcps_persistdrop++;
			tp = tcp_drop(tp, ETIMEDOUT);
			break;
		}
		tcp_setpersist(tp);
		tp->t_force = 1;
		(void) tcp_output(tp);
		tp->t_force = 0;
		break;

	/*
	 * Keep-alive timer went off; send something
	 * or drop connection if idle for too long.
	 */
	case TCPT_KEEP:
		tcpstat.tcps_keeptimeo++;
		if (tp->t_state < TCPS_ESTABLISHED)
			goto dropit;
		if (tp->t_inpcb->inp_socket->so_options & SO_KEEPALIVE &&
		    tp->t_state <= TCPS_CLOSE_WAIT) {
		    	if (tp->t_idle >= tcp_keepidle + tcp_maxidle)
				goto dropit;
			/*
			 * Send a packet designed to force a response
			 * if the peer is up and reachable:
			 * either an ACK if the connection is still alive,
			 * or an RST if the peer has closed the connection
			 * due to timeout or reboot.
			 * Using sequence number tp->snd_una-1
			 * causes the transmitted zero-length segment
			 * to lie outside the receive window;
			 * by the protocol spec, this requires the
			 * correspondent TCP to respond.
			 */
			tcpstat.tcps_keepprobe++;
#ifdef TCP_COMPAT_42
			/*
			 * The keepalive packet must have nonzero length
			 * to get a 4.2 host to respond.
			 */
			tcp_respond(tp, tp->t_template, (struct mbuf *)NULL,
			    tp->rcv_nxt - 1, tp->snd_una - 1, 0);
#else
			tcp_respond(tp, tp->t_template, (struct mbuf *)NULL,
			    tp->rcv_nxt, tp->snd_una - 1, 0);
#endif
			tp->t_timer[TCPT_KEEP] = tcp_keepintvl;
		} else
			tp->t_timer[TCPT_KEEP] = tcp_keepidle;
		break;
	dropit:
		tcpstat.tcps_keepdrops++;
		tp = tcp_drop(tp, ETIMEDOUT);
		break;
	}
	return (tp);
}
#endif /* TUBA_INCLUDE */