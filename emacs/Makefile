##
# Makefile for emacs
##

# Project info
Project        = emacs
UserType       = Developer
ToolType       = Commands
Extra_LD_Flags = -read_only_relocs warning

GnuAfterInstall = install_app

# It's a GNU Source project
include /System/Developer/Makefiles/CoreOS/ReleaseControl/GNUSource.make

# Override some defaults
# Emacs cannot be built fat; it requires a forked native build
RC_ARCHS = 

.PHONY: install_app

# Delete this line when the App is known to work. This puts the app in /Local instead of /System.
NSDEVELOPERAPPSDIR = $(NSLOCALDIR)$(NSDEVELOPERSUBDIR)$(NSAPPLICATIONSUBDIR)

install_app:
	$(MKDIR) $(DSTROOT)$(NSDEVELOPERAPPSDIR)/Emacs.app
	$(LN) -fs $(Install_Prefix)/bin/emacs $(DSTROOT)$(NSDEVELOPERAPPSDIR)/Emacs.app/Emacs
