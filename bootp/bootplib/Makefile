#
# Generated by the NeXT Project Builder.
#
# NOTE: Do NOT change this file -- Project Builder maintains it.
#
# Put all of your customizations in files called Makefile.preamble
# and Makefile.postamble (both optional), and Makefile will include them.
#

NAME = bootplib

PROJECTVERSION = 2.8
PROJECT_TYPE = Library

CLASSES = clientTypes.m dhcpOptions.m macNCOptions.m NIDomain.m\
          NIHosts.m subnetDescr.m

HFILES = afp.h clientTypes.h dhcp.h dhcpOptions.h dhcpOptionsPrivate.h\
         gen_dhcp_parse_table.h gen_dhcp_tags.h gen_dhcp_types.h\
         hostlist.h host_identifier.h inetroute.h interfaces.h\
         macNCOptions.h netinfo.h NIDomain.h NIHosts.h rfc_options.h\
         subnetDescr.h util.h arp.h hfsvols.h sharepoints.h

CFILES = arp.c hfsvols.c hostlist.c host_identifier.c inetroute.c\
         interfaces.c netinfo.c sharepoints.c

OTHERSRCS = Makefile.preamble Makefile Makefile.postamble\
            genoptionfiles.c


MAKEFILEDIR = $(MAKEFILEPATH)/pb_makefiles
CURRENTLY_ACTIVE_VERSION = YES
DEPLOY_WITH_VERSION_NAME = A
CODE_GEN_STYLE = DYNAMIC
MAKEFILE = library.make
NEXTSTEP_INSTALLDIR = /usr/libexec
WINDOWS_INSTALLDIR = $(HOMEDRIVE)$(LOCAL_DEVELOPER_DIR)/Libraries
PDO_UNIX_INSTALLDIR = /usr/local/lib
LIBS = 
DEBUG_LIBS = $(LIBS)
PROF_LIBS = $(LIBS)


FRAMEWORK_PATHS = -F$(NEXT_ROOT)/System/Library/PrivateFrameworks
NEXTSTEP_PB_CFLAGS = -Wno-four-char-constants
FRAMEWORKS = -framework oamshim -framework ServerControl


WINDOWS_PUBLIC_HEADERS_DIR = $(HOMEDRIVE)$(LOCAL_DEVELOPER_DIR)/Headers/$(NAME)

PDO_UNIX_PUBLIC_HEADERS_DIR = $(LOCAL_DEVELOPER_DIR)/Headers/$(NAME)

NEXTSTEP_OBJCPLUS_COMPILER = /usr/bin/cc
WINDOWS_OBJCPLUS_COMPILER = $(DEVDIR)/gcc
PDO_UNIX_OBJCPLUS_COMPILER = $(NEXTDEV_BIN)/gcc
NEXTSTEP_JAVA_COMPILER = /usr/bin/javac
WINDOWS_JAVA_COMPILER = $(JDKBINDIR)/javac.exe
PDO_UNIX_JAVA_COMPILER = $(NEXTDEV_BIN)/javac

include $(MAKEFILEDIR)/platform.make

-include Makefile.preamble

include $(MAKEFILEDIR)/$(MAKEFILE)

-include Makefile.postamble

-include Makefile.dependencies
