/*
 * refclock_atom - clock driver for 1-pps signals
 */
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#if defined(REFCLOCK) && defined(CLOCK_ATOM)

#include <stdio.h>
#include <ctype.h>
#include <sys/time.h>

#include "ntpd.h"
#include "ntp_io.h"
#include "ntp_unixtime.h"
#include "ntp_refclock.h"
#include "ntp_stdlib.h"

#ifdef PPS
# include <sys/ppsclock.h>
#endif /* PPS */

/*
 * This driver furnishes an interface for pulse-per-second (PPS) signals
 * produced by a cesium clock, timing receiver or related  equipment. It
 * can be used to remove accumulated jitter and retime a secondary
 * server when synchronized to a primary server over a congested, wide-
 * area network and before redistributing the time to local clients.
 *
 * In order for this driver to work, the local clock must be set to
 * within +-500 ms by another means, such as a radio clock or NTP
 * itself. The 1-pps signal is connected via a serial port and gadget
 * box consisting of a one-shot and RS232 level converter. When operated
 * at 38.4 kbps with a SPARCstation IPC, this arrangement has a worst-
 * case jitter less than 26 us.
 *
 * There are three ways in which this driver can be used. The first way
 * uses the LDISC_PPS line discipline and works only for the baseboard
 * serial ports of the Sun SPARCstation. The PPS signal is connected via
 * a gadget box to the carrier detect (CD) line of a serial port and
 * flag3 of the driver configured for that port is set. This causes the
 * ppsclock streams module to be configured for that port and capture a
 * timestamp at the on-time transition of the PPS signal. This driver
 * then reads the timestamp directly by a designated ioctl() system
 * call. This provides the most accurate time and least jitter of any
 * other scheme. There is no need to configure a dedicated device for
 * this purpose, which ordinarily is the device used for the associated
 * radio clock.
 *
 * The second way uses the LDISC_CLKPPS line discipline and works for
 * any architecture supporting a serial port. If after a few seconds
 * this driver finds no ppsclock module configured, it attempts to open
 * a serial port device /dev/pps%d, where %d is the unit number, and
 * assign the LDISC_CLKPPS line discipline to it. If the line discipline
 * fails, no harm is done except the accuracy is reduced somewhat. The
 * pulse generator in the gadget box is adjusted to produce a start bit
 * of length 26 usec at 38400 bps. Used with the LDISC_CLKPPS line
 * discipline, this produces an ASCII DEL character ('\377') followed by
 * a timestamp at each seconds epoch. 
 *
 * The third way involves an auxiliary radio clock driver which calls
 * the PPS driver with a timestamp captured by that driver. This use is
 * documented in the source code for the driver(s) involved.  Note that
 * some drivers collect the sample information themselves before calling
 * our pps_sample(), and others call us knowing only that they are running
 * shortly after an on-time tick and they expect us to retrieve the PPS
 * offset, fudge their result, and insert it into the timestream.
 *
 * Fudge Factors
 *
 * There are no special fudge factors other than the generic and those
 * explicitly defined above. The fudge time1 parameter can be used to
 * compensate for miscellaneous UART and OS delays. Allow about 247 us
 * for uart delays at 38400 bps and about 1 ms for SunOS streams
 * nonsense.
 */

/*
 * Interface definitions
 */
#ifdef TTYCLK
#define	DEVICE		"/dev/pps%d" /* device name and unit */
#ifdef B38400
#define	SPEED232	B38400	/* uart speed (38400 baud) */
#else
#define SPEED232	EXTB	/* as above */
#endif
#endif /* TTYCLK */
#define	PRECISION	(-20)	/* precision assumed (about 1 usec) */
#define	REFID		"PPS\0"	/* reference ID */
#define	DESCRIPTION	"PPS Clock Discipline" /* WRU */

#define FLAG_TTY	0x01	/* tty_clk heard from */
#define FLAG_PPS	0x02	/* ppsclock heard from */
#define FLAG_AUX	0x04	/* auxiliary PPS source */

/*
 * Imported from ntp_timer module
 */
extern u_long current_time;	/* current time (s) */

/*
 * Imported from ntpd module
 */
extern int debug;		/* global debug flag */

/*
 * Imported from ntp_loopfilter module
 */
#ifdef PPS
extern int fdpps;		/* pps file descriptor */
#endif /* PPS */

#ifdef PPS_SAMPLE
static struct peer *pps_peer;	/* atom driver for auxiliary PPS sources */
#endif

extern int pps_update;		/* prefer peer valid update */

#ifdef TTYCLK
static	void	atom_receive	P((struct recvbuf *));
#endif /* TTYCLK */

/*
 * Unit control structure
 */
struct atomunit {
#ifdef PPS
	struct	ppsclockev ev;	/* ppsclock control */
#endif /* PPS */
	int	flags;		/* flags that wave */
	int	pollcnt;	/* poll message counter */
};

/*
 * Function prototypes
 */
static	int	atom_start	P((int, struct peer *));
static	void	atom_shutdown	P((int, struct peer *));
static	void	atom_poll	P((int, struct peer *));
#ifdef PPS
static	int	atom_pps	P((struct peer *));
#endif /* PPS */

/*
 * Transfer vector
 */
struct	refclock refclock_atom = {
	atom_start,		/* start up driver */
	atom_shutdown,		/* shut down driver */
	atom_poll,		/* transmit poll message */
	noentry,		/* not used (old atom_control) */
	noentry,		/* initialize driver */
	noentry,		/* not used (old atom_buginfo) */
	NOFLAGS			/* not used */
};


/*
 * atom_start - initialize data for processing
 */
static int
atom_start(
	int unit,
	struct peer *peer
	)
{
	register struct atomunit *up;
	struct refclockproc *pp;
	int flags;
#ifdef TTYCLK
	int fd;
	char device[20];
#endif /* TTYCLK */

	flags = 0;
#ifndef PPS
#ifdef TTYCLK
	/*
	 * Open serial port. Use LDISC_CLKPPS line discipline only
	 * if the LDISC_PPS line discipline is not availble,
	 */
	(void)sprintf(device, DEVICE, unit);
	if ((fd = refclock_open(device, SPEED232, LDISC_CLKPPS)) == 0)
		return (0);
	flags |= FLAG_TTY;
#endif /* TTYCLK */
#endif /* PPS */

	/*
	 * Allocate and initialize unit structure
	 */
	if (!(up = (struct atomunit *)emalloc(sizeof(struct atomunit)))) {
#ifdef TTYCLK
		if (flags & FLAG_TTY)
			(void) close(fd);
#endif /* TTYCLK */
		return (0);
	}
	memset((char *)up, 0, sizeof(struct atomunit));
	pp = peer->procptr;
	pp->unitptr = (caddr_t)up;
#ifdef TTYCLK
	if (flags & FLAG_TTY) {
		pp->io.clock_recv = atom_receive;
		pp->io.srcclock = (caddr_t)peer;
		pp->io.datalen = 0;
		pp->io.fd = fd;
		if (!io_addclock(&pp->io)) {
			(void) close(fd);
			free(up);
			return (0);
		}
	}
#endif /* TTYCLK */
#ifdef PPS_SAMPLE
	if (pps_peer == 0)
		pps_peer = peer;
#endif /* PPS_SAMPLE */
	/*
	 * Initialize miscellaneous variables
	 */
	peer->precision = PRECISION;
	pp->clockdesc = DESCRIPTION;
	memcpy((char *)&pp->refid, REFID, 4);
	up->pollcnt = 2;
	up->flags = flags;
	pp->nstages = MAXSTAGE;
	pp->nskeep = MAXSTAGE * 3 / 5;
	return (1);
}


/*
 * atom_shutdown - shut down the clock
 */
static void
atom_shutdown(
	int unit,
	struct peer *peer
	)
{
	register struct atomunit *up;
	struct refclockproc *pp;

	pp = peer->procptr;
	up = (struct atomunit *)pp->unitptr;
#ifdef TTYCLK
	if (up->flags & FLAG_TTY)
		io_closeclock(&pp->io);
#endif /* TTYCLK */
#ifdef PPS_SAMPLE
	if (pps_peer == peer)
		pps_peer = 0;
#endif /* PPS_SAMPLE */
	free(up);
}


#ifdef PPS
/*
 * atom_pps - receive data from the LDISC_PPS discipline
 */
static int
atom_pps(
	struct peer *peer
	)
{
	register struct atomunit *up;
	struct refclockproc *pp;

	l_fp lftmp;
	double doffset;
	int i;

	/*
	 * This routine is called once per second when the LDISC_PPS
	 * discipline is present. It snatches the pps timestamp from the
	 * kernel and saves the sign-extended fraction in a circular
	 * buffer for processing at the next poll event.
	 */
	pp = peer->procptr;
	up = (struct atomunit *)pp->unitptr;

	/*
	 * Convert the timeval to l_fp and save for billboards. Sign-
	 * extend the fraction and stash in the buffer. No harm is done
	 * if previous data are overwritten. If the discipline comes bum
	 * or the data grow stale, just forget it.
	 */ 
	i = up->ev.serial;
	if (fdpps <= 0)
		return (1);
	if (ioctl(fdpps, CIOGETEV, (caddr_t)&up->ev) < 0)
		return (1);
	if (i == up->ev.serial)
		return (2);
	up->flags |= FLAG_PPS;
	pp->lastrec.l_ui = up->ev.tv.tv_sec + JAN_1970;
	TVUTOTSF(up->ev.tv.tv_usec, pp->lastrec.l_uf);
	L_CLR(&lftmp);
	L_ADDF(&lftmp, pp->lastrec.l_f);
	LFPTOD(&lftmp, doffset);
	pp->filter[pp->coderecv++ % pp->nstages] = -doffset + pp->fudgetime1;
	up->pollcnt = 2 * 60;
	return (0);
}
#endif /* PPS */

#ifdef TTYCLK
/*
 * atom_receive - receive data from the LDISC_CLK discipline
 */
static void
atom_receive(
	struct recvbuf *rbufp
	)
{
	register struct atomunit *up;
	struct refclockproc *pp;
	struct peer *peer;
	l_fp lftmp;
	double doffset;

	/*
	 * This routine is called once per second when the serial
	 * interface is in use. It snatches the timestamp from the
	 * buffer and saves the sign-extended fraction in a circular
	 * buffer for processing at the next poll event.
	 */
	peer = (struct peer *)rbufp->recv_srcclock;
	pp = peer->procptr;
	up = (struct atomunit *)pp->unitptr;
	pp->lencode = refclock_gtlin(rbufp, pp->a_lastcode, BMAX,
	    &pp->lastrec);

	/*
	 * Save the timestamp for billboards. Sign-extend the fraction
	 * and stash in the buffer. No harm is done if previous data are
	 * overwritten. Do this only if the ppsclock gizmo is not working.
	 */
	if (up->flags & FLAG_PPS)
		return;
	L_CLR(&lftmp);
	L_ADDF(&lftmp, pp->lastrec.l_f);
	LFPTOD(&lftmp, doffset);
	pp->filter[pp->coderecv++ % pp->nstages] = -doffset + pp->fudgetime1;
	up->pollcnt = 2;
}
#endif /* TTYCLK */

#ifdef PPS_SAMPLE
/*
 * pps_sample - receive PPS data from the some clock driver
 */
int
pps_sample(
	   l_fp *offset
	   )
{
	register struct peer *peer;
	register struct atomunit *up;
	struct refclockproc *pp;

	l_fp lftmp;
	double doffset;

	/*
	 * This routine is called once per second when the external clock driver
	 * processes PPS information. It processes the pps timestamp
	 * and saves the sign-extended fraction in a circular
	 * buffer for processing at the next poll event.
	 */
	peer = pps_peer;

	if (peer == 0)		/* nobody home */
		return 1;
	
	pp = peer->procptr;
	up = (struct atomunit *)pp->unitptr;

	/*
	 * Convert the timeval to l_fp and save for billboards. Sign-
	 * extend the fraction and stash in the buffer. No harm is done
	 * if previous data are overwritten. If the discipline comes bum
	 * or the data grow stale, just forget it.
	 */ 
	up->flags |= FLAG_AUX;
	pp->lastrec = *offset;
	L_CLR(&lftmp);
	L_ADDF(&lftmp, pp->lastrec.l_f);
	LFPTOD(&lftmp, doffset);
	pp->filter[pp->coderecv++ % pp->nstages] = -doffset + pp->fudgetime1;
	up->pollcnt = 2 * 60;
	return (0);
}
#endif /* PPS_SAMPLE */

/*
 * atom_poll - called by the transmit procedure
 */
static void
atom_poll(
	int unit,
	struct peer *peer
	)
{
	register struct atomunit *up;
	struct refclockproc *pp;

	/*
	 * Accumulate samples in the median filter. At the end of each
	 * poll interval, do a little bookeeping and process the samples.
	 */
	pp = peer->procptr;
	up = (struct atomunit *)pp->unitptr;
#ifdef PPS
	if (atom_pps(peer))
		return;
	if (peer->burst > 0)
		return;
#endif /* PPS */
	pp->polls++;
	if (up->pollcnt == 0) {
		refclock_report(peer, CEVNT_FAULT);
		return;
	}
	up->pollcnt--;

	/*
	 * Valid time (leap bits zero) is returned only if the prefer
	 * peer has survived the intersection algorithm and within
	 * CLOCK_MAX of local time and not too long ago.  This ensures
	 * the pps time is within +-0.5 s of the local time and the
	 * seconds numbering is unambiguous.
	 */
	if (pps_update)
		pp->leap = LEAP_NOWARNING;
	else {
		pp->leap = LEAP_NOTINSYNC;
		return;
	}
	pp->dispersion = pp->skew = 0;
	refclock_receive(peer);
#ifdef PPS
	peer->burst = pp->nstages;
	peer->nextdate = current_time + BURST_INTERVAL;
#endif /* PPS */
}

#else
int refclock_atom_bs;
#endif /* REFCLOCK */
