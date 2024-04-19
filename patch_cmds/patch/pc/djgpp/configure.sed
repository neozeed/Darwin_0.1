# Edit Makefile.in to produce Makefile for DJGPP v2
#	$Id: configure.sed,v 1.1.1.1 1997/08/20 20:57:59 wsanchez Exp $

1i\
# Makefile generated by "configure.bat" for DJGPP v2\

/@SET_MAKE@/d

s|@CC@|gcc|g
s|@ed_PROGRAM@|ed|g
s|@INSTALL@|${DJDIR}/bin/ginstall -c|g
s|@INSTALL_PROGRAM@|${INSTALL}|g
s|@INSTALL_DATA@|${INSTALL} -m 644|g
s|@program_transform_name@||g

s|@CFLAGS@|-g -O2|g
s|@CPPFLAGS@|-I$(srcdir)/pc/djgpp|g
s|@DEFS@|-DHAVE_CONFIG_H|g
s|@LDFLAGS@||g
s|@LIBOBJS@|getopt1.o getopt.o chdirsaf.o|g
s|@LIBS@||g
s|@PACKAGE@|patch|g
/@VERSION@/d

s|@prefix@|${DJDIR}|g
s|@exec_prefix@|${prefix}|g

/^CONFIG_STATUS *=/s|=.*|= $(srcdir)/pc/djgpp/configure.bat|
/^	\$(SHELL) \$(CONFIG_STATUS) *$/s//	$(CONFIG_STATUS) $(srcdir)/

$a\
config.h: config.hin pc/djgpp/config.sed; sed -f $(srcdir)/pc/djgpp/config.sed $(srcdir)/config.hin >$@\
chdirsaf.o: chdirsaf.c\
# Use sed instead of cp, since cp might not be installed.\
chdirsaf.c: pc/chdirsaf.c; sed -e '' $? > $@\
distclean::; rm -f chdirsaf.c
