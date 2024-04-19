/*
 * ntp_refclock - processing support for reference clocks
 */
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#ifdef HAVE_SYS_IOCTL_H
#include <sys/ioctl.h>
#endif /* HAVE_SYS_IOCTL_H */

#include "ntpd.h"
#include "ntp_io.h"
#include "ntp_unixtime.h"
#include "ntp_refclock.h"
#include "ntp_stdlib.h"

#ifdef REFCLOCK

#ifdef TTYCLK
#include <sys/clkdefs.h>
#endif /* TTYCLK */

#ifdef PPS
#include <sys/ppsclock.h>
#endif /* PPS */

/*
 * Reference clock support is provided here by maintaining the fiction
 * that the clock is actually a peer. As no packets are exchanged with a
 * reference clock, however, we replace the transmit, receive and packet
 * procedures with separate code to simulate them. Routines
 * refclock_transmit() and refclock_receive() maintain the peer
 * variables in a state analogous to an actual peer and pass reference
 * clock data on through the filters. Routines refclock_peer() and
 * refclock_unpeer() are called to initialize and terminate reference
 * clock associations. A set of utility routines is included to open
 * serial devices, process sample data, edit input lines to extract
 * embedded timestamps and to peform various debugging functions.
 *
 * The main interface used by these routines is the refclockproc
 * structure, which contains for most drivers the decimal equivalants of
 * the year, day, month, hour, second and millisecond/microsecond
 * decoded from the ASCII timecode. Additional information includes the
 * receive timestamp, exception report, statistics tallies, etc. In
 * addition, there may be a driver-specific unit structure used for
 * local control of the device.
 *
 * The support routines are passed a pointer to the peer structure,
 * which is used for all peer-specific processing and contains a pointer
 * to the refclockproc structure, which in turn containes a pointer to
 * the unit structure, if used. In addition, some routines expect an
 * address in the dotted quad form 127.127.t.u, where t is the clock
 * type and u the unit. A table typeunit[type][unit] contains the peer
 * structure pointer for each configured clock type and unit.
 *
 * Most drivers support the 1-pps signal provided by some radios and
 * connected via a level converted described in the gadget directory.
 * The signal is captured using a separate, dedicated serial port and
 * the tty_clk line discipline/streams modules described in the kernel
 * directory. For the highest precision, the signal is captured using
 * the carrier-detect line of the same serial port using the ppsclock
 * streams module described in the ppsclock directory.
 */
#define MAXUNIT 	4	/* max units */
#ifndef CLKLDISC
#define CLKLDISC	10	/* XXX temp tty_clk line discipline */
#endif

/*
 * The refclock configuration table. Imported from refclock_conf
 */
extern	struct	refclock *refclock_conf[];
extern	u_char	num_refclock_conf;

/*
 * Imported from the I/O module
 */
extern	struct	interface *any_interface;
extern	struct	interface *loopback_interface;

#ifdef PPS
int fdpps;			/* pps file descriptor */
#endif /* PPS */

/*
 * Imported from the timer module
 */
extern	u_long	current_time;

/*
 * Imported from the main and peer modules.
 */
extern	int debug;

/*
 * Imported from ntp_config module
 */
extern char pps_device[];	/* PPS device name */

/*
 * Type/unit peer index. Used to find the peer structure for control and
 * debugging. When all clock drivers have been converted to new style,
 * this dissapears.
 */
static struct peer *typeunit[REFCLK_MAX + 1][MAXUNIT];

/*
 * Forward declarations
 */
#ifdef QSORT_USES_VOID_P
static int refclock_cmpl_fp P((const void *, const void *));
#else
static int refclock_cmpl_fp P((const double *, const double *));
#endif

/*
 * refclock_report - note the occurance of an event
 *
 * This routine presently just remembers the report and logs it, but
 * does nothing heroic for the trap handler. It tries to be a good
 * citizen and bothers the system log only if things change.
 */
void
refclock_report(
	struct peer *peer,
	int code
	)
{
	struct refclockproc *pp;

	if (!(pp = peer->procptr))
		return;
	if (code == CEVNT_BADREPLY)
		pp->badformat++;
	if (code == CEVNT_BADTIME)
		pp->baddata++;
	if (code == CEVNT_TIMEOUT)
		pp->noreply++;
	if (pp->currentstatus != code) {
		pp->currentstatus = code;
		pp->lastevent = code;
		if (code == CEVNT_FAULT)
			msyslog(LOG_ERR,
				"clock %s event '%s' (0x%02x)",
				refnumtoa(peer->srcadr.sin_addr.s_addr),
				ceventstr(code), code);
		else {
			NLOG(NLOG_CLOCKEVENT)
				msyslog(LOG_INFO,
				"clock %s event '%s' (0x%02x)",
				refnumtoa(peer->srcadr.sin_addr.s_addr),
				ceventstr(code), code);
		}
	}
#ifdef DEBUG
	if (debug)
		printf("clock %s event '%s' (0x%02x)\n",
			refnumtoa(peer->srcadr.sin_addr.s_addr),
			ceventstr(code), code);
#endif
}


/*
 * init_refclock - initialize the reference clock drivers
 *
 * This routine calls each of the drivers in turn to initialize internal
 * variables, if necessary. Most drivers have nothing to say at this
 * point.
 */
void
init_refclock(void)
{
	int i, j;

	for (i = 0; i < (int)num_refclock_conf; i++) {
		if (refclock_conf[i]->clock_init != noentry)
			(refclock_conf[i]->clock_init)();
		for (j = 0; j < MAXUNIT; j++)
			typeunit[i][j] = 0;
	}
}


/*
 * refclock_newpeer - initialize and start a reference clock
 *
 * This routine allocates and initializes the interface structure which
 * supports a reference clock in the form of an ordinary NTP peer. A
 * driver-specific support routine completes the initialization, if
 * used. Default peer variables which identify the clock and establish
 * its reference ID and stratum are set here. It returns one if success
 * and zero if the clock address is invalid or already running,
 * insufficient resources are available or the driver declares a bum
 * rap.
 */
int
refclock_newpeer(
	struct peer *peer	/* peer structure pointer */
	)
{
	struct refclockproc *pp;
	u_char clktype;
	int unit;

	/*
	 * Check for valid clock address. If already running, shut it
	 * down first.
	 */
	if (!ISREFCLOCKADR(&peer->srcadr)) {
		msyslog(LOG_ERR,
			"refclock_newpeer: clock address %s invalid",
			ntoa(&peer->srcadr));
		return (0);
	}
	clktype = (u_char)REFCLOCKTYPE(&peer->srcadr);
	unit = REFCLOCKUNIT(&peer->srcadr);
	if (clktype >= num_refclock_conf || unit > MAXUNIT ||
		refclock_conf[clktype]->clock_start == noentry) {
		msyslog(LOG_ERR,
			"refclock_newpeer: clock type %d invalid\n",
			clktype);
		return (0);
	}
	refclock_unpeer(peer);

	/*
	 * Allocate and initialize interface structure
	 */
	if (!(pp = (struct refclockproc *)
		  emalloc(sizeof(struct refclockproc))))
		return (0);
	memset((char *)pp, 0, sizeof(struct refclockproc));
	typeunit[clktype][unit] = peer;
	peer->procptr = pp;

	/*
	 * Initialize structures
	 */
	peer->refclktype = clktype;
	peer->refclkunit = unit;
	peer->flags |= FLAG_REFCLOCK;
	peer->stratum = STRATUM_REFCLOCK;
	peer->refid = peer->srcadr.sin_addr.s_addr;
	peer->maxpoll = peer->minpoll;

	pp->type = clktype;
	pp->timestarted = current_time;
	pp->nstages = NSTAGE;
	pp->nskeep = NSTAGE * 3 / 5;

	/*
	 * If the interface has been set to any_interface, set it to the
	 * loopback address if we have one. This is so that peers which
	 * are unreachable are easy to see in the peer display.
	 */
	if (peer->dstadr == any_interface && loopback_interface != 0)
		peer->dstadr = loopback_interface;

	/*
	 * Set peer.pmode based on the hmode. For appearances only.
	 */
	switch (peer->hmode) {

		case MODE_ACTIVE:
		peer->pmode = MODE_PASSIVE;
		break;

		default:
		peer->pmode = MODE_SERVER;
		break;
	}

	/*
	 * Do driver dependent initialization. The above defaults
	 * can be wiggled, then finish up for consistency.
	 */
	if (!((refclock_conf[clktype]->clock_start)(unit, peer))) {
		free(pp);
		return (0);
	}
	peer->hpoll = peer->minpoll;
	peer->ppoll = peer->maxpoll;
	if (peer->stratum <= 1)
		peer->refid = pp->refid;
	else
		peer->refid = peer->srcadr.sin_addr.s_addr;
	return (1);
}


/*
 * refclock_unpeer - shut down a clock
 */
void
refclock_unpeer(
	struct peer *peer	/* peer structure pointer */
	)
{
	u_char clktype;
	int unit;

	/*
	 * Wiggle the driver to release its resources, then give back
	 * the interface structure.
	 */
	if (!peer->procptr)
		return;
	clktype = peer->refclktype;
	unit = peer->refclkunit;
	if (refclock_conf[clktype]->clock_shutdown != noentry)
		(refclock_conf[clktype]->clock_shutdown)(unit, peer);
	free(peer->procptr);
	peer->procptr = 0;
}


/*
 * refclock_transmit - simulate the transmit procedure
 *
 * This routine implements the NTP transmit procedure for a reference
 * clock. This provides a mechanism to call the driver at the NTP poll
 * interval, as well as provides a reachability mechanism to detect a
 * broken radio or other madness.
 */
void
refclock_transmit(
	struct peer *peer	/* peer structure pointer */
	)
{
	struct refclockproc *pp;
	u_char clktype;
	int unit;
	int hpoll;

	pp = peer->procptr;
	clktype = peer->refclktype;
	unit = peer->refclkunit;
	peer->sent++;

	/*
	 * This is a ripoff of the peer transmit routine, but specialized
	 * for reference clocks. We do a little less protocol here and
	 * call the driver-specific transmit routine.
	 */
	hpoll = peer->hpoll;
	if (peer->burst == 0) {
		u_char oreach;
#ifdef DEBUG
		if (debug)
			printf("refclock_transmit: %s at %ld\n",
				ntoa(&(peer->srcadr)), current_time);
#endif

		/*
		 * Update reachability and poll variables like the
		 * network code.
		 */
		oreach = peer->reach;
		if (oreach & 0x01)
			peer->valid++;
		if (oreach & 0x80)
			peer->valid--;
				peer->reach <<= 1;
		if (peer->reach == 0) {
			if (oreach != 0) {
				report_event(EVNT_UNREACH, peer);
				peer->timereachable = current_time;
				peer_clear(peer);
			}
		} else {
			if ((oreach & 0x03) == 0) {
				clock_filter(peer, 0., 0., MAXDISPERSE);
				clock_select();
			}
			if (peer->valid <= 2) {
				hpoll--;
			} else if (peer->valid > NTP_SHIFT - 2)
				hpoll++;
			if (peer->flags & FLAG_BURST)
				peer->burst = pp->nstages;
		}
		peer->outdate = current_time;
	}
	get_systime(&peer->xmt);
	if (refclock_conf[clktype]->clock_poll != noentry)
		(refclock_conf[clktype]->clock_poll)(unit, peer);
	if (peer->burst > 0 && peer->unreach < NTP_UNREACH)
		peer->burst--;
	poll_update(peer, hpoll);
}


/*
 * Compare two doubles - used with qsort()
 */
#ifdef QSORT_USES_VOID_P
static int
refclock_cmpl_fp(
	const void *p1,
	const void *p2
	)
{
	const double *dp1 = (const double *)p1;
	const double *dp2 = (const double *)p2;

	if (*dp1 < *dp2)
		return (-1);
	if (*dp1 > *dp2)
		return (1);
	return (0);
}
#else
static int
refclock_cmpl_fp(
	const double *dp1,
	const double *dp2
	)
{
	if (*dp1 < *dp2)
		return (-1);
	if (*dp1 > *dp2)
		return (1);
	return (0);
}
#endif


/*
 * refclock_process_offset - process a pile of offset samples from the clock
 *
 * This routine uses the given offset and receive time stamp
 * and fill the appropriate filter buffers further processing is left to
 * refclock_sample
 */
int
refclock_process_offset(
			struct refclockproc *pp,
			l_fp offset,
			l_fp lastrec,
			double fudge
			)
{
	double doffset;
	
	pp->lastref = offset;
	pp->lastrec = lastrec;
	pp->dispersion = pp->skew = 0;
	L_SUB(&offset, &lastrec);
	LFPTOD(&offset, doffset);
	pp->filter[pp->coderecv++ % pp->nstages] = doffset +
	    fudge;
	return (1);
}

/*
 * refclock_process - process a pile of samples from the clock
 *
 * This routine converts the timecode in the form days, hours, miinutes,
 * seconds, milliseconds/microseconds to internal timestamp format.
 * Further processing is then delegated to refclock sample
 */
int
refclock_process(
	struct refclockproc *pp
	)
{
	l_fp offset;

	/*
	 * Compute the timecode timestamp from the days, hours, minutes,
	 * seconds and milliseconds/microseconds of the timecode. Use
	 * clocktime() for the aggregate seconds and the msec/usec for
	 * the fraction, when present. Note that this code relies on the
	 * filesystem time for the years and does not use the years of
	 * the timecode.
	 */
	if (!clocktime(pp->day, pp->hour, pp->minute, pp->second, GMT,
		pp->lastrec.l_ui, &pp->yearstart, &offset.l_ui))
		return (0);
	if (pp->usec) {
		TVUTOTSF(pp->usec, offset.l_uf);
	} else {
		MSUTOTSF(pp->msec, offset.l_uf);
	}
	return refclock_process_offset(pp, offset, pp->lastrec, pp->fudgetime1);
}

/*
 * refclock_sample - process a pile of samples from the clock
 *
 * This routine converts the timecode in the form days, hours, minutes,
 * seconds, milliseconds/microseconds to internal timestamp format. It
 * then calculates the difference from the receive timestamp and
 * assembles the samples in a shift register. It implements a recursive
 * median filter to suppress spikes in the data, as well as determine a
 * rough dispersion estimate. A configuration constant time adjustment
 * fudgetime1 can be added to the final offset to compensate for various
 * systematic errors. The routine returns one if success and zero if
 * failure due to invalid timecode data or very noisy offsets.
 *
 */
void
refclock_sample(
	struct refclockproc *pp
	)
{
	int i, j, k;
	double offset, disp;
	double off[MAXSTAGE];

	/*
	 * Copy the raw offsets and sort into ascending order.
	 */
	for (j = 0; j < pp->nstages && (u_int)j < pp->coderecv; j++)														/*	98/06/04  */
		off[j] = pp->filter[j];
	qsort((char *)off, (u_int)j, sizeof(double), refclock_cmpl_fp);

	/*
	 * Reject the furthest from the median of the samples until
	 * nskeep samples remain.
	 */
	i = 0;
	k = j;
	if (k > pp->nskeep)
		k = pp->nskeep;
	while ((j - i) > k) {
		offset = off[(j + i) / 2];
		if (off[j - 1] - offset < offset - off[i])
			i++;	/* reject low end */
		else
			j--;	/* reject high end */
	}

	/*
	 * Determine the offset, delay and variance. If the
	 * error is too large, return sad; otherwise return joy.
	 */
	pp->delay = 0;
	disp = offset = 0;
	for (; i < j; i++) {
		offset += off[i];
		disp += SQUARE(off[i]);
	}
	offset /= k; disp /= k;
	pp->offset = offset;
	pp->skew += disp - SQUARE(offset);
#ifdef DEBUG
	if (debug)
		printf("refclock_sample: offset %.6f bound %.6f error %.6f\n",
			pp->offset, pp->dispersion, SQRT(pp->skew));
#endif
}


/*
 * refclock_receive - simulate the receive and packet procedures
 *
 * This routine simulates the NTP receive and packet procedures for a
 * reference clock. This provides a mechanism in which the ordinary NTP
 * filter, selection and combining algorithms can be used to suppress
 * misbehaving radios and to mitigate between them when more than one is
 * available for backup.
 */
void
refclock_receive(
	struct peer *peer	/* peer structure pointer */
	)
{
	struct refclockproc *pp;

#ifdef DEBUG
	if (debug)
		printf("refclock_receive: at %lu %s\n",
			current_time, ntoa(&peer->srcadr));
#endif

	/*
	 * Do a little sanity dance and update the peer structure. Groom
	 * the median filter samples and give the data to the clock
	 * filter.
	 */
	peer->received++;
	pp = peer->procptr;
	peer->processed++;
	peer->timereceived = current_time;
	peer->leap = pp->leap;
	if (peer->leap == LEAP_NOTINSYNC) {
		refclock_report(peer, CEVNT_FAULT);
		return;
	}
	if (peer->reach == 0)
		report_event(EVNT_REACH, peer);
	peer->reach |= 1;
	peer->reftime = peer->org = pp->lastrec;
	get_systime(&peer->rec);
	refclock_sample(pp);
	clock_filter(peer, pp->offset, pp->delay, LOGTOD(peer->precision) +
		pp->dispersion + SQRT(pp->skew));
	clock_select();
	record_peer_stats(&peer->srcadr, ctlpeerstatus(peer),
	   peer->offset, peer->delay, peer->dispersion,
	   SQRT(peer->skew));
}

/*
 * refclock_gtlin - groom next input line and extract timestamp
 *
 * This routine processes the timecode received from the clock and
 * removes the parity bit and control characters. If a timestamp is
 * present in the timecode, as produced by the tty_clk line
 * discipline/streams module, it returns that as the timestamp;
 * otherwise, it returns the buffer timestamp. The routine return code
 * is the number of characters in the line.
 */
int
refclock_gtlin(
	struct recvbuf *rbufp,	/* receive buffer pointer */
	char *lineptr,		/* current line pointer */
	int bmax,		/* remaining characters in line */
	l_fp *tsptr 	/* pointer to timestamp returned */
	)
{
	char *dpt, *dpend, *dp;
	int i;
	l_fp trtmp, tstmp;
	char c;
#ifdef TIOCDCDTIMESTAMP
	struct timeval dcd_time;
#endif

	/*
	 * Check for the presence of a timestamp left by the tty_clock
	 * line discipline/streams module and, if present, use that
	 * instead of the buffer timestamp captured by the I/O routines.
	 * We recognize a timestamp by noting its value is earlier than
	 * the buffer timestamp, but not more than one second earlier.
	 */
	dpt = (char *)&rbufp->recv_space;
	dpend = dpt + rbufp->recv_length;
	trtmp = rbufp->recv_time;

#ifdef TIOCDCDTIMESTAMP
	if(ioctl(rbufp->fd, TIOCDCDTIMESTAMP, &dcd_time) != -1) {
		TVTOTS(&dcd_time, &tstmp);
		tstmp.l_ui += JAN_1970;
		L_SUB(&trtmp, &tstmp);
		if (trtmp.l_ui == 0) {
#ifdef DEBUG
			if (debug > 1) {
				printf(
					"refclock_gtlin: fd %d DCDTIMESTAMP %s",
					rbufp->fd, lfptoa(&tstmp, 6));
				printf(" sigio %s\n", lfptoa(&trtmp,
					6));
			}
#endif
			trtmp = tstmp;
		} else
			trtmp = rbufp->recv_time;
	}
	else
	/* XXX fallback to old method if kernel refuses TIOCDCDTIMESTAMP */
#endif  /* TIOCDCDTIMESTAMP */
	if (dpend >= dpt + 8) {
		if (buftvtots(dpend - 8, &tstmp)) {
			L_SUB(&trtmp, &tstmp);
			if (trtmp.l_ui == 0) {
#ifdef DEBUG
				if (debug > 1) {
					printf(
						"refclock_gtlin: fd %d ldisc %s",
						rbufp->fd, lfptoa(&trtmp,
						6));
					get_systime(&trtmp);
					L_SUB(&trtmp, &tstmp);
					printf(" sigio %s\n", lfptoa(&trtmp, 6));
				}
#endif
				dpend -= 8;
				trtmp = tstmp;
			} else
				trtmp = rbufp->recv_time;
		}
	}

	/*
	 * Edit timecode to remove control chars. Don't monkey with the
	 * line buffer if the input buffer contains no ASCII printing
	 * characters.
	 */
	if (dpend - dpt > bmax - 1)
		dpend = dpt + bmax - 1;
	for (dp = lineptr; dpt < dpend; dpt++) {
		c = *dpt & 0x7f;
		if (c >= ' ')
			*dp++ = c;
	}
	i = dp - lineptr;
	if (i > 0)
		*dp = '\0';
#ifdef DEBUG
	if (debug > 1 && i > 0)
		printf("refclock_gtlin: fd %d time %s timecode %d %s\n",
			rbufp->fd, ulfptoa(&trtmp, 6), i, lineptr);
#endif
	*tsptr = trtmp;
	return (i);
}

/*
 * The following code does not apply to WINNT & VMS ...
 */
#ifndef SYS_VXWORKS
#if defined(HAVE_TERMIOS) || defined(HAVE_SYSV_TTYS) || defined(HAVE_BSD_TTYS)

/*
 * refclock_open - open serial port for reference clock
 *
 * This routine opens a serial port for I/O and sets default options. It
 * returns the file descriptor if success and zero if failure.
 */
int
refclock_open(
	char *dev,		/* device name pointer */
	int speed,		/* serial port speed (code) */
	int flags		/* line discipline flags */
	)
{
	int fd;
#ifdef HAVE_TERMIOS
	struct termios ttyb, *ttyp;
#endif /* HAVE_TERMIOS */
#ifdef HAVE_SYSV_TTYS
	struct termio ttyb, *ttyp;
#endif /* HAVE_SYSV_TTYS */
#ifdef HAVE_BSD_TTYS
	struct sgttyb ttyb, *ttyp;
#endif /* HAVE_BSD_TTYS */
#ifdef TIOCMGET
	u_long ltemp;
#endif /* TIOCMGET */

	/*
	 * Open serial port and set default options
	 */
#ifdef O_NONBLOCK
	fd = open(dev, O_RDWR | O_NONBLOCK, 0777);
#else
	fd = open(dev, O_RDWR, 0777);
#endif
	if (fd == -1) {
		msyslog(LOG_ERR, "refclock_open: %s: %m", dev);
		return (0);
	}

	/*
	 * The following sections initialize the serial line port in
	 * canonical (line-oriented) mode and set the specified line
	 * speed, 8 bits and no parity. The modem control, break, erase
	 * and kill functions are normally disabled. There is a
	 * different section for each terminal interface, as selected at
	 * compile time.
	 */
	ttyp = &ttyb;

#ifdef HAVE_TERMIOS
	/*
	 * POSIX serial line parameters (termios interface)
	 */
	if (tcgetattr(fd, ttyp) < 0) {
		msyslog(LOG_ERR,
			"refclock_open: fd %d tcgetattr %m", fd);
		return (0);
	}

	/*
	 * Set canonical mode and local connection; set specified speed,
	 * 8 bits and no parity; map CR to NL; ignore break.
	 */
	ttyp->c_iflag = IGNBRK | IGNPAR | ICRNL;
	ttyp->c_oflag = 0;
	ttyp->c_cflag = CS8 | CLOCAL | CREAD;
	(void)cfsetispeed(&ttyb, (u_int)speed);
	(void)cfsetospeed(&ttyb, (u_int)speed);
	ttyp->c_lflag = ICANON;
	ttyp->c_cc[VERASE] = ttyp->c_cc[VKILL] = '\0';

	/*
	 * Some special cases
	 */
	if (flags & LDISC_RAW) {
		ttyp->c_iflag = 0;
		ttyp->c_lflag = 0;
	}
#ifdef TIOCMGET
	/*
	 * If we have modem control, check to see if modem leads are
	 * active; if so, set remote connection. This is necessary for
	 * the kernel pps mods to work.
	 */
	ltemp = 0;
	if (ioctl(fd, TIOCMGET, (char *)&ltemp) < 0)
		msyslog(LOG_ERR,
			"refclock_open: fd %d TIOCMGET failed: %m", fd);
#ifdef DEBUG
	if (debug)
		printf("refclock_open: fd %d modem status %lx\n",
			fd, ltemp);
#endif
	if (ltemp & TIOCM_DSR)
		ttyp->c_cflag &= ~CLOCAL;
#endif /* TIOCMGET */
	if (tcsetattr(fd, TCSANOW, ttyp) < 0) {
		msyslog(LOG_ERR,
			"refclock_open: fd %d TCSANOW failed: %m", fd);
		return (0);
	}
	if (tcflush(fd, TCIOFLUSH) < 0) {
		msyslog(LOG_ERR,
			"refclock_open: fd %d TCIOFLUSH failed: %m", fd);
		return (0);
	}
#endif /* HAVE_TERMIOS */

#ifdef HAVE_SYSV_TTYS

	/*
	 * System V serial line parameters (termio interface)
	 *
	 */
	if (ioctl(fd, TCGETA, ttyp) < 0) {
		msyslog(LOG_ERR,
			"refclock_open: fd %d TCGETA failed: %m", fd);
		return (0);
	}

	/*
	 * Set canonical mode and local connection; set specified speed,
	 * 8 bits and no parity; map CR to NL; ignore break.
	 */
	ttyp->c_iflag = IGNBRK | IGNPAR | ICRNL;
	ttyp->c_oflag = 0;
	ttyp->c_cflag = speed | CS8 | CLOCAL | CREAD;
	ttyp->c_lflag = ICANON;
	ttyp->c_cc[VERASE] = ttyp->c_cc[VKILL] = '\0';

	/*
	 * Some special cases
	 */
	if (flags & LDISC_RAW) {
		ttyp->c_iflag = 0;
		ttyp->c_lflag = 0;
	}
#ifdef TIOCMGET
	/*
	 * If we have modem control, check to see if modem leads are
	 * active; if so, set remote connection. This is necessary for
	 * the kernel pps mods to work.
	 */
	ltemp = 0;
	if (ioctl(fd, TIOCMGET, (char *)&ltemp) < 0)
		msyslog(LOG_ERR,
			"refclock_open: fd %d TIOCMGET failed: %m", fd);
#ifdef DEBUG
	if (debug)
		printf("refclock_open: fd %d modem status %lx\n",
			fd, ltemp);
#endif
	if (ltemp & TIOCM_DSR)
		ttyp->c_cflag &= ~CLOCAL;
#endif /* TIOCMGET */
	if (ioctl(fd, TCSETA, ttyp) < 0) {
		msyslog(LOG_ERR,
			"refclock_open: fd %d TCSETA failed: %m", fd);
		return (0);
	}
#endif /* HAVE_SYSV_TTYS */

#ifdef HAVE_BSD_TTYS

	/*
	 * 4.3bsd serial line parameters (sgttyb interface)
	 */
	if (ioctl(fd, TIOCGETP, (char *)ttyp) < 0) {
		msyslog(LOG_ERR,
			"refclock_open: fd %d TIOCGETP %m", fd);
		return (0);
	}
	ttyp->sg_ispeed = ttyp->sg_ospeed = speed;
	ttyp->sg_flags = EVENP | ODDP | CRMOD;
	if (ioctl(fd, TIOCSETP, (char *)ttyp) < 0) {
		msyslog(LOG_ERR,
			"refclock_open: TIOCSETP failed: %m");
		return (0);
	}
#endif /* HAVE_BSD_TTYS */
	if (!refclock_ioctl(fd, flags)) {
		(void)close(fd);
		msyslog(LOG_ERR,
			"refclock_open: fd %d ioctl fails", fd);
		return (0);
	}
	if (strcmp(dev, pps_device) == 0)
		(void)refclock_ioctl(fd, LDISC_PPS);
	return (fd);
}
#endif /* HAVE_TERMIOS || HAVE_SYSV_TTYS || HAVE_BSD_TTYS */
#endif /* SYS_VXWORKS */

/*
 * refclock_ioctl - set serial port control functions
 *
 * This routine attempts to hide the internal, system-specific details
 * of serial ports. It can handle POSIX (termios), SYSV (termio) and BSD
 * (sgtty) interfaces with varying degrees of success. The routine sets
 * up the tty_clk and ppsclock streams module/line discipline, if
 * compiled in the daemon and requested in the call. The routine returns
 * one if success and zero if failure.
 */
int
refclock_ioctl(
	int fd, 		/* file descriptor */
	int flags		/* line discipline flags */
	)
{
	/* simply return 1 if no UNIX line discipline is supported */
#ifndef SYS_VXWORKS
#if defined(HAVE_TERMIOS) || defined(HAVE_SYSV_TTYS) || defined(HAVE_BSD_TTYS)

#ifdef HAVE_TERMIOS
	struct termios ttyb, *ttyp;
#endif /* HAVE_TERMIOS */
#ifdef HAVE_SYSV_TTYS
	struct termio ttyb, *ttyp;
#endif /* HAVE_SYSV_TTYS */
#ifdef HAVE_BSD_TTYS
	struct sgttyb ttyb, *ttyp;
#endif /* HAVE_BSD_TTYS */

#ifdef DEBUG
	if (debug)
		printf("refclock_ioctl: fd %d flags %x\n", fd, flags);
#endif

	/*
	 * The following sections select optional features, such as
	 * modem control, line discipline and so forth. Some require
	 * specific operating system support in the form of streams
	 * modules, which can be loaded and unloaded at run time without
	 * rebooting the kernel, or line discipline modules, which must
	 * be compiled in the kernel. The streams modules require System
	 * V STREAMS support, while the line discipline modules require
	 * 4.3bsd or later. The checking frenzy is attenuated here,
	 * since the device is already open.
	 *
	 * Note that both the clk and ppsclock modules are optional; the
	 * dang thing still works, but the accuracy improvement using
	 * them will not be available. The ppsclock module is associated
	 * with a specific, declared line and should be used only once.
	 *
	 * Use the LDISC_PPS option ONLY with Sun baseboard ttya or
	 * ttyb. Using it with the SPIF multipexor crashes the kernel.
	 */
	if (flags == 0)
		return (1);
#if !(defined(HAVE_TERMIOS) || defined(HAVE_BSD_TTYS))
	if (flags & (LDISC_CLK | LDISC_PPS | LDISC_ACTS)) {
		msyslog(LOG_ERR,
			"refclock_ioctl: unsupported terminal interface");
		return (0);
	}
#endif /* HAVE_TERMIOS HAVE_BSD_TTYS */
	ttyp = &ttyb;
#ifdef STREAM
#ifdef TTYCLK
	/*
	 * The TTYCLK option provides timestamping at the driver level.
	 * It requires the tty_clk streams module and System V STREAMS
	 * support. If not available, don't complain.
	 */
	if (flags & (LDISC_CLK | LDISC_CLKPPS | LDISC_ACTS)) {
		if (ioctl(fd, I_PUSH, "clk") < 0) {
			msyslog(LOG_NOTICE,
				"refclock_ioctl: I_PUSH clk failed: %m");
		} else {
			char *str;

			if (flags & LDISC_PPS)
				str = "\377";
			else if (flags & LDISC_ACTS)
				str = "*";
			else
				 str = "\n";
			if (ioctl(fd, CLK_SETSTR, str) < 0)
				msyslog(LOG_ERR,
					"refclock_ioctl: CLK_SETSTR failed: %m");
		}
	}

	/*
	 * The ACTS line discipline requires additional line-ending
	 * character '*'.
	 */
	if (flags & LDISC_ACTS) {
		(void)tcgetattr(fd, ttyp);
		ttyp->c_cc[VEOL] = '*';
		(void)tcsetattr(fd, TCSANOW, ttyp);
	}
#endif /* TTYCLK */

#ifdef PPS
	/*
	 * The PPS option provides timestamping at the driver level.
	 * It uses a 1-pps signal and level converter (gadget box) and
	 * requires the ppsclock streams module and System V STREAMS
	 * support.
	 */
	if (flags & LDISC_PPS) {
		if (fdpps > 0) {
			msyslog(LOG_ERR,
				"refclock_ioctl: ppsclock already configured");
			return (0);
		}
#ifdef SYS_SOLARIS
		if ((ioctl(fd, TIOCSPPS, 1) < 0)) {
#else
		if ((ioctl(fd, I_PUSH, "ppsclock") < 0)) {
#endif /* SYS_SOLARIS */
			msyslog(LOG_NOTICE,
				"refclock_ioctl: I_PUSH ppsclock failed: %m");
		} else {
			fdpps = fd;
		}
	}
#else
	if (flags & LDISC_PPS)
		msyslog(LOG_NOTICE,
			"refclock_ioctl: ppsclock line discipline requested but unavailable");
#endif /* PPS */

#else /* not STREAM */

#ifdef HAVE_TERMIOS
#ifdef TTYCLK
	/*
	 * The TTYCLK option provides timestamping at the driver level.
	 * It requires the tty_clk line discipline and 4.3bsd or later.
	 * If not available, don't complain.
	 */
	if (flags & (LDISC_CLK | LDISC_CLKPPS | LDISC_ACTS)) {
		(void)tcgetattr(fd, ttyp);
		ttyp->c_lflag = 0;
		if (flags & LDISC_CLKPPS)
			ttyp->c_cc[VERASE] = ttyp->c_cc[VKILL] = '\377';
		else if (flags & LDISC_ACTS) {
			ttyp->c_cc[VERASE] = '*';
			ttyp->c_cc[VKILL] = '#';
		} else
			ttyp->c_cc[VERASE] = ttyp->c_cc[VKILL] = '\n';
		ttyp->c_line = CLKLDISC;
		(void)tcsetattr(fd, TCSANOW, ttyp);
		(void)tcflush(fd, TCIOFLUSH);
	}
#endif /* TTYCLK */
#ifdef PPS
	/*
	 * The PPS option provides timestamping at the driver level.
	 * It uses a 1-pps signal and level converter (gadget box) and
	 * requires ppsclock compiled into the kernel on non STREAMS
	 * systems.
	 */
	if (flags & LDISC_PPS) {
		if (fdpps > 0) {
			msyslog(LOG_ERR,
			    "refclock_ioctl: ppsclock already configured");
			return (0);
		}
		fdpps = fd;
	}
#endif /* PPS */
#endif /* HAVE_TERMIOS */

#ifdef HAVE_BSD_TTYS
#ifdef TTYCLK
	/*
	 * The TTYCLK option provides timestamping at the driver level.
	 * It requires the tty_clk line discipline and 4.3bsd or later.
	 * If not available, don't complain.
	 */
	if (flags & (LDISC_CLK | LDISC_CLKPPS | LDISC_ACTS)) {
		int ldisc = CLKLDISC;

		(void)ioctl(fd, TIOCGETP, (char *)ttyp);
		if (flags & LDISC_CLKPPS)
			ttyp->sg_erase = ttyp->sg_kill = '\377';
		else if (flags & LDISC_ACTS) {
			ttyp->sg_erase = '*';
			ttyp->sg_kill = '#';
		} else
			ttyp->sg_erase = ttyp->sg_kill = '\r';
		ttyp->sg_flags = RAW;
		(void)ioctl(fd, TIOCSETP, ttyp);
		ioctl(fd, TIOCSETD, (char *)&ldisc);
	}
#endif /* TTYCLK */
#endif /* HAVE_BSD_TTYS */

#endif /* STREAM */

#endif /* HAVE_TERMIOS || HAVE_SYSV_TTYS || HAVE_BSD_TTYS */
#endif /* SYS_VXWORKS */
	return (1);
}

/*
 * refclock_control - set and/or return clock values
 *
 * This routine is used mainly for debugging. It returns designated
 * values from the interface structure that can be displayed using
 * ntpdc and the clockstat command. It can also be used to initialize
 * configuration variables, such as fudgetimes, fudgevalues, reference
 * ID and stratum.
 */
void
refclock_control(
	struct sockaddr_in *srcadr,
	struct refclockstat *in,
	struct refclockstat *out
	)
{
	struct peer *peer;
	struct refclockproc *pp;
	u_char clktype;
	int unit;

	/*
	 * Check for valid address and running peer
	 */
	if (!ISREFCLOCKADR(srcadr))
		return;
	clktype = (u_char)REFCLOCKTYPE(srcadr);
	unit = REFCLOCKUNIT(srcadr);
	if (clktype >= num_refclock_conf || unit > MAXUNIT)
		return;
	if (!(peer = typeunit[clktype][unit]))
		return;
	pp = peer->procptr;

	/*
	 * Initialize requested data
	 */
	if (in != 0) {
		if (in->haveflags & CLK_HAVETIME1)
			pp->fudgetime1 = in->fudgetime1;
		if (in->haveflags & CLK_HAVETIME2)
			pp->fudgetime2 = in->fudgetime2;
		if (in->haveflags & CLK_HAVEVAL1)
			peer->stratum = (u_char) in->fudgeval1;
		if (in->haveflags & CLK_HAVEVAL2)
			pp->refid = in->fudgeval2;
		if (peer->stratum <= 1)
			peer->refid = pp->refid;
		else
			peer->refid = peer->srcadr.sin_addr.s_addr;
		if (in->haveflags & CLK_HAVEFLAG1) {
			pp->sloppyclockflag &= ~CLK_FLAG1;
			pp->sloppyclockflag |= in->flags & CLK_FLAG1;
		}
		if (in->haveflags & CLK_HAVEFLAG2) {
			pp->sloppyclockflag &= ~CLK_FLAG2;
			pp->sloppyclockflag |= in->flags & CLK_FLAG2;
		}
		if (in->haveflags & CLK_HAVEFLAG3) {
			pp->sloppyclockflag &= ~CLK_FLAG3;
			pp->sloppyclockflag |= in->flags & CLK_FLAG3;
		}
		if (in->haveflags & CLK_HAVEFLAG4) {
			pp->sloppyclockflag &= ~CLK_FLAG4;
			pp->sloppyclockflag |= in->flags & CLK_FLAG4;
		}
	}

	/*
	 * Readback requested data
	 */
	if (out != 0) {
		out->haveflags = CLK_HAVETIME1 | CLK_HAVEVAL1 |
			CLK_HAVEVAL2 | CLK_HAVEFLAG4;
		out->fudgetime1 = pp->fudgetime1;
		out->fudgetime2 = pp->fudgetime2;
		out->fudgeval1 = peer->stratum;
		out->fudgeval2 = pp->refid;
		out->flags = (u_char) pp->sloppyclockflag;

		out->timereset = current_time - pp->timestarted;
		out->polls = pp->polls;
		out->noresponse = pp->noreply;
		out->badformat = pp->badformat;
		out->baddata = pp->baddata;

		out->lastevent = pp->lastevent;
		out->currentstatus = pp->currentstatus;
		out->type = pp->type;
		out->clockdesc = pp->clockdesc;
		out->lencode = pp->lencode;
		out->p_lastcode = pp->a_lastcode;
	}

	/*
	 * Give the stuff to the clock
	 */
	if (refclock_conf[clktype]->clock_control != noentry)
		(refclock_conf[clktype]->clock_control)(unit, in, out, peer);
}


/*
 * refclock_buginfo - return debugging info
 *
 * This routine is used mainly for debugging. It returns designated
 * values from the interface structure that can be displayed using
 * ntpdc and the clkbug command.
 */
void
refclock_buginfo(
	struct sockaddr_in *srcadr, /* clock address */
	struct refclockbug *bug /* output structure */
	)
{
	struct peer *peer;
	struct refclockproc *pp;
	u_char clktype;
	int unit;
	int i;

	/*
	 * Check for valid address and peer structure
	 */
	if (!ISREFCLOCKADR(srcadr))
		return;
	clktype = (u_char) REFCLOCKTYPE(srcadr);
	unit = REFCLOCKUNIT(srcadr);
	if (clktype >= num_refclock_conf || unit > MAXUNIT)
		return;
	if (!(peer = typeunit[clktype][unit]))
		return;
	pp = peer->procptr;

	/*
	 * Copy structure values
	 */
	bug->nvalues = 8;
	bug->svalues = 0x0000003f;
	bug->values[0] = pp->year;
	bug->values[1] = pp->day;
	bug->values[2] = pp->hour;
	bug->values[3] = pp->minute;
	bug->values[4] = pp->second;
	bug->values[5] = pp->msec;
	bug->values[6] = pp->yearstart;
	bug->values[7] = pp->coderecv;

	bug->ntimes = pp->nstages + 3;
	if (bug->ntimes > NCLKBUGTIMES)
	    bug->ntimes = NCLKBUGTIMES;
	bug->stimes = 0xfffffffc;
	bug->times[0] = pp->lastref;
	bug->times[1] = pp->lastrec;
	for (i = 2; i < (int)bug->ntimes; i++)
		DTOLFP(pp->filter[i - 2], &bug->times[i]);

	/*
	 * Give the stuff to the clock
	 */
	if (refclock_conf[clktype]->clock_buginfo != noentry)
		(refclock_conf[clktype]->clock_buginfo)(unit, bug, peer);
}

#endif /* REFCLOCK */
