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

/*
 * Find out about remote users
 */

#ifndef RPC_HDR
%#ifndef lint
%/*static char sccsid[] = "from: @(#)rnusers.x 1.2 87/09/20 Copyr 1987 Sun Micro";*/
%/*static char sccsid[] = "from: @(#)rnusers.x	2.1 88/08/01 4.0 RPCSRC";*/
%static char rcsid[] = "$Id: rnusers.x,v 1.2.2.3 1999/03/16 15:52:15 wsanchez Exp $";
%#endif /* not lint */
#endif


#ifdef RPC_HDR
%/*
% * The following structures are used by version 2 of the rusersd protocol.
% * They were not developed with rpcgen, so they do not appear as RPCL.
% */
%
%#define 	RUSERSVERS_ORIG 1	/* original version */
%#define	RUSERSVERS_IDLE 2
%#define	MAXUSERS 100
%
%/*
% * This is the structure used in version 2 of the rusersd RPC service.
% * It corresponds to the utmp structure for BSD sytems.
% */
%struct ru_utmp {
%	char	ut_line[8];		/* tty name */
%	char	ut_name[8];		/* user id */
%	char	ut_host[16];		/* host name, if remote */
%	long	ut_time;		/* time on */
%};
%typedef struct ru_utmp rutmp;
%
%struct utmparr {
%	struct utmp **uta_arr;
%	int uta_cnt;
%};
%typedef struct utmparr utmparr;
%int xdr_utmparr();
%
%struct utmpidle {
%	struct ru_utmp ui_utmp;
%	unsigned ui_idle;
%};
%
%struct utmpidlearr {
%	struct utmpidle **uia_arr;
%	int uia_cnt;
%};
%typedef struct utmpidlearr utmpidlearr;
%int xdr_utmpidlearr();
%
%#define RUSERSVERS_1 ((u_long)1)
%#define RUSERSVERS_2 ((u_long)2)
%#ifndef RUSERSPROG
%#define RUSERSPROG ((u_long)100002)
%#endif
%#ifndef RUSERSPROC_NUM
%#define RUSERSPROC_NUM ((u_long)1)
%#endif
%#ifndef RUSERSPROC_NAMES
%#define RUSERSPROC_NAMES ((u_long)2)
%#endif
%#ifndef RUSERSPROC_ALLNAMES
%#define RUSERSPROC_ALLNAMES ((u_long)3)
%#endif
%
#endif	/* RPC_HDR */

#ifdef	RPC_XDR
%bool_t
%xdr_utmp(xdrs, objp)
%	XDR *xdrs;
%	struct ru_utmp *objp;
%{
%	char *ptr;
%	int size;
%
%	ptr  = objp->ut_line;
%	size = sizeof(objp->ut_line);
%	if (!xdr_bytes(xdrs, &ptr, &size, size)) {
%		return (FALSE);
%	}
%	ptr  = objp->ut_name;
%	size = sizeof(objp->ut_line);
%	if (!xdr_bytes(xdrs, &ptr, &size, size)) {
%		return (FALSE);
%	}
%	ptr  = objp->ut_host;
%	size = sizeof(objp->ut_host);
%	if (!xdr_bytes(xdrs, &ptr, &size, size)) {
%		return (FALSE);
%	}
%	if (!xdr_long(xdrs, &objp->ut_time)) {
%		return (FALSE);
%	}
%	return (TRUE);
%}
%
%bool_t
%xdr_utmpptr(xdrs, objpp)
%	XDR *xdrs;
%	struct utmp **objpp;
%{
%	if (!xdr_reference(xdrs, (char **) objpp, sizeof (struct ru_utmp), 
%			   xdr_utmp)) {
%		return (FALSE);
%	}
%	return (TRUE);
%}
%
%bool_t
%xdr_utmparr(xdrs, objp)
%	XDR *xdrs;
%	struct utmparr *objp;
%{
%	if (!xdr_array(xdrs, (char **)&objp->uta_arr, (u_int *)&objp->uta_cnt,
%		       MAXUSERS, sizeof(struct utmp *), xdr_utmpptr)) {
%		return (FALSE);
%	}
%	return (TRUE);
%}
%
%bool_t
%xdr_utmpidle(xdrs, objp)
%	XDR *xdrs;
%	struct utmpidle *objp;
%{
%	if (!xdr_utmp(xdrs, &objp->ui_utmp)) {
%		return (FALSE);
%	}
%	if (!xdr_u_int(xdrs, &objp->ui_idle)) {
%		return (FALSE);
%	}
%	return (TRUE);
%}
%
%bool_t
%xdr_utmpidleptr(xdrs, objpp)
%	XDR *xdrs;
%	struct utmpidle **objpp;
%{
%	if (!xdr_reference(xdrs, (char **) objpp, sizeof (struct utmpidle), 
%			   xdr_utmpidle)) {
%		return (FALSE);
%	}
%	return (TRUE);
%}
%
%bool_t
%xdr_utmpidlearr(xdrs, objp)
%	XDR *xdrs;
%	struct utmpidlearr *objp;
%{
%	if (!xdr_array(xdrs, (char **)&objp->uia_arr, (u_int *)&objp->uia_cnt,
%		       MAXUSERS, sizeof(struct utmpidle *), xdr_utmpidleptr)) {
%		return (FALSE);
%	}
%	return (TRUE);
%}
#endif
