#	$NetBSD: bsd.inc.mk,v 1.11 1998/09/29 11:47:51 christos Exp $

.PHONY:		incinstall
includes:	${INCS} incinstall

.if defined(INCS)
.for I in ${INCS}
incinstall:: ${DESTDIR}${INCSDIR}/$I

.PRECIOUS: ${DESTDIR}${INCSDIR}/$I
.if !defined(UPDATE)
.PHONY: ${DESTDIR}${INCSDIR}/$I
.endif
${DESTDIR}${INCSDIR}/$I: $I
	@cmp -s ${.ALLSRC} ${.TARGET} > /dev/null 2>&1 || \
	    (echo "${INSTALL} ${PRESERVE} -c -o ${BINOWN} -g ${BINGRP} \
		-m ${NONBINMODE} ${.ALLSRC} ${.TARGET}" && \
	     ${INSTALL} ${PRESERVE} -c -o ${BINOWN} -g ${BINGRP} \
		-m ${NONBINMODE} ${.ALLSRC} ${.TARGET})
.endfor
.endif

.if !target(incinstall)
incinstall::
.endif
