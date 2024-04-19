# Microsoft Developer Studio Generated NMAKE File, Format Version 4.20
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Static Library" 0x0104

!IF "$(CFG)" == ""
CFG=libntp - Win32 Debug
!MESSAGE No configuration specified.  Defaulting to libntp - Win32 Debug.
!ENDIF 

!IF "$(CFG)" != "libntp - Win32 Release" && "$(CFG)" != "libntp - Win32 Debug"
!MESSAGE Invalid configuration "$(CFG)" specified.
!MESSAGE You can specify a configuration when running NMAKE on this makefile
!MESSAGE by defining the macro CFG on the command line.  For example:
!MESSAGE 
!MESSAGE NMAKE /f "libntp.mak" CFG="libntp - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "libntp - Win32 Release" (based on "Win32 (x86) Static Library")
!MESSAGE "libntp - Win32 Debug" (based on "Win32 (x86) Static Library")
!MESSAGE 
!ERROR An invalid configuration is specified.
!ENDIF 

!IF "$(OS)" == "Windows_NT"
NULL=
!ELSE 
NULL=nul
!ENDIF 
################################################################################
# Begin Project
# PROP Target_Last_Scanned "libntp - Win32 Debug"
CPP=cl.exe

!IF  "$(CFG)" == "libntp - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "WinRel"
# PROP BASE Intermediate_Dir "WinRel"
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "WinRel"
# PROP Intermediate_Dir "WinRel"
OUTDIR=.\WinRel
INTDIR=.\WinRel

ALL : "$(OUTDIR)\libntp.lib" "$(OUTDIR)\libntp.bsc"

CLEAN : 
	-@erase "$(INTDIR)\a_md512crypt.obj"
	-@erase "$(INTDIR)\a_md512crypt.sbr"
	-@erase "$(INTDIR)\a_md5decrypt.obj"
	-@erase "$(INTDIR)\a_md5decrypt.sbr"
	-@erase "$(INTDIR)\a_md5encrypt.obj"
	-@erase "$(INTDIR)\a_md5encrypt.sbr"
	-@erase "$(INTDIR)\atoint.obj"
	-@erase "$(INTDIR)\atoint.sbr"
	-@erase "$(INTDIR)\atolfp.obj"
	-@erase "$(INTDIR)\atolfp.sbr"
	-@erase "$(INTDIR)\atouint.obj"
	-@erase "$(INTDIR)\atouint.sbr"
	-@erase "$(INTDIR)\auth12crypt.obj"
	-@erase "$(INTDIR)\auth12crypt.sbr"
	-@erase "$(INTDIR)\authdecrypt.obj"
	-@erase "$(INTDIR)\authdecrypt.sbr"
	-@erase "$(INTDIR)\authdes.obj"
	-@erase "$(INTDIR)\authdes.sbr"
	-@erase "$(INTDIR)\authencrypt.obj"
	-@erase "$(INTDIR)\authencrypt.sbr"
	-@erase "$(INTDIR)\authkeys.obj"
	-@erase "$(INTDIR)\authkeys.sbr"
	-@erase "$(INTDIR)\authparity.obj"
	-@erase "$(INTDIR)\authparity.sbr"
	-@erase "$(INTDIR)\authreadkeys.obj"
	-@erase "$(INTDIR)\authreadkeys.sbr"
	-@erase "$(INTDIR)\authusekey.obj"
	-@erase "$(INTDIR)\authusekey.sbr"
	-@erase "$(INTDIR)\buftvtots.obj"
	-@erase "$(INTDIR)\buftvtots.sbr"
	-@erase "$(INTDIR)\caljulian.obj"
	-@erase "$(INTDIR)\caljulian.sbr"
	-@erase "$(INTDIR)\calleapwhen.obj"
	-@erase "$(INTDIR)\calleapwhen.sbr"
	-@erase "$(INTDIR)\caltontp.obj"
	-@erase "$(INTDIR)\caltontp.sbr"
	-@erase "$(INTDIR)\calyearstart.obj"
	-@erase "$(INTDIR)\calyearstart.sbr"
	-@erase "$(INTDIR)\clocktime.obj"
	-@erase "$(INTDIR)\clocktime.sbr"
	-@erase "$(INTDIR)\clocktypes.obj"
	-@erase "$(INTDIR)\clocktypes.sbr"
	-@erase "$(INTDIR)\decodenetnum.obj"
	-@erase "$(INTDIR)\decodenetnum.sbr"
	-@erase "$(INTDIR)\dofptoa.obj"
	-@erase "$(INTDIR)\dofptoa.sbr"
	-@erase "$(INTDIR)\dolfptoa.obj"
	-@erase "$(INTDIR)\dolfptoa.sbr"
	-@erase "$(INTDIR)\emalloc.obj"
	-@erase "$(INTDIR)\emalloc.sbr"
	-@erase "$(INTDIR)\findconfig.obj"
	-@erase "$(INTDIR)\findconfig.sbr"
	-@erase "$(INTDIR)\fptoa.obj"
	-@erase "$(INTDIR)\fptoa.sbr"
	-@erase "$(INTDIR)\fptoms.obj"
	-@erase "$(INTDIR)\fptoms.sbr"
	-@erase "$(INTDIR)\getopt.obj"
	-@erase "$(INTDIR)\getopt.sbr"
	-@erase "$(INTDIR)\hextoint.obj"
	-@erase "$(INTDIR)\hextoint.sbr"
	-@erase "$(INTDIR)\hextolfp.obj"
	-@erase "$(INTDIR)\hextolfp.sbr"
	-@erase "$(INTDIR)\humandate.obj"
	-@erase "$(INTDIR)\humandate.sbr"
	-@erase "$(INTDIR)\inttoa.obj"
	-@erase "$(INTDIR)\inttoa.sbr"
	-@erase "$(INTDIR)\lib_strbuf.obj"
	-@erase "$(INTDIR)\lib_strbuf.sbr"
	-@erase "$(INTDIR)\log.obj"
	-@erase "$(INTDIR)\log.sbr"
	-@erase "$(INTDIR)\machines.obj"
	-@erase "$(INTDIR)\machines.sbr"
	-@erase "$(INTDIR)\md5.obj"
	-@erase "$(INTDIR)\md5.sbr"
	-@erase "$(INTDIR)\mexit.obj"
	-@erase "$(INTDIR)\mexit.sbr"
	-@erase "$(INTDIR)\mfptoa.obj"
	-@erase "$(INTDIR)\mfptoa.sbr"
	-@erase "$(INTDIR)\mfptoms.obj"
	-@erase "$(INTDIR)\mfptoms.sbr"
	-@erase "$(INTDIR)\modetoa.obj"
	-@erase "$(INTDIR)\modetoa.sbr"
	-@erase "$(INTDIR)\mstolfp.obj"
	-@erase "$(INTDIR)\mstolfp.sbr"
	-@erase "$(INTDIR)\msutotsf.obj"
	-@erase "$(INTDIR)\msutotsf.sbr"
	-@erase "$(INTDIR)\msyslog.obj"
	-@erase "$(INTDIR)\msyslog.sbr"
	-@erase "$(INTDIR)\netof.obj"
	-@erase "$(INTDIR)\netof.sbr"
	-@erase "$(INTDIR)\numtoa.obj"
	-@erase "$(INTDIR)\numtoa.sbr"
	-@erase "$(INTDIR)\numtohost.obj"
	-@erase "$(INTDIR)\numtohost.sbr"
	-@erase "$(INTDIR)\octtoint.obj"
	-@erase "$(INTDIR)\octtoint.sbr"
	-@erase "$(INTDIR)\prettydate.obj"
	-@erase "$(INTDIR)\prettydate.sbr"
	-@erase "$(INTDIR)\ranny.obj"
	-@erase "$(INTDIR)\ranny.sbr"
	-@erase "$(INTDIR)\refnumtoa.obj"
	-@erase "$(INTDIR)\refnumtoa.sbr"
	-@erase "$(INTDIR)\statestr.obj"
	-@erase "$(INTDIR)\statestr.sbr"
	-@erase "$(INTDIR)\syssignal.obj"
	-@erase "$(INTDIR)\syssignal.sbr"
	-@erase "$(INTDIR)\systime.obj"
	-@erase "$(INTDIR)\systime.sbr"
	-@erase "$(INTDIR)\tsftomsu.obj"
	-@erase "$(INTDIR)\tsftomsu.sbr"
	-@erase "$(INTDIR)\tstotv.obj"
	-@erase "$(INTDIR)\tstotv.sbr"
	-@erase "$(INTDIR)\tvtoa.obj"
	-@erase "$(INTDIR)\tvtoa.sbr"
	-@erase "$(INTDIR)\tvtots.obj"
	-@erase "$(INTDIR)\tvtots.sbr"
	-@erase "$(INTDIR)\uglydate.obj"
	-@erase "$(INTDIR)\uglydate.sbr"
	-@erase "$(INTDIR)\uinttoa.obj"
	-@erase "$(INTDIR)\uinttoa.sbr"
	-@erase "$(INTDIR)\utvtoa.obj"
	-@erase "$(INTDIR)\utvtoa.sbr"
	-@erase "$(OUTDIR)\libntp.bsc"
	-@erase "$(OUTDIR)\libntp.lib"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_WINDOWS" /FR /YX /c
# ADD CPP /nologo /MT /W3 /GX /O2 /I "..\include" /I "..\include\winnt" /D "NDEBUG" /D "WIN32" /D "_WINDOWS" /D "SYS_WINNT" /D "__STDC__" /FR /YX /c
CPP_PROJ=/nologo /MT /W3 /GX /O2 /I "..\include" /I "..\include\winnt" /D\
 "NDEBUG" /D "WIN32" /D "_WINDOWS" /D "SYS_WINNT" /D "__STDC__" /FR"$(INTDIR)/"\
 /Fp"$(INTDIR)/libntp.pch" /YX /Fo"$(INTDIR)/" /c 
CPP_OBJS=.\WinRel/
CPP_SBRS=.\WinRel/
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
BSC32_FLAGS=/nologo /o"$(OUTDIR)/libntp.bsc" 
BSC32_SBRS= \
	"$(INTDIR)\a_md512crypt.sbr" \
	"$(INTDIR)\a_md5decrypt.sbr" \
	"$(INTDIR)\a_md5encrypt.sbr" \
	"$(INTDIR)\atoint.sbr" \
	"$(INTDIR)\atolfp.sbr" \
	"$(INTDIR)\atouint.sbr" \
	"$(INTDIR)\auth12crypt.sbr" \
	"$(INTDIR)\authdecrypt.sbr" \
	"$(INTDIR)\authdes.sbr" \
	"$(INTDIR)\authencrypt.sbr" \
	"$(INTDIR)\authkeys.sbr" \
	"$(INTDIR)\authparity.sbr" \
	"$(INTDIR)\authreadkeys.sbr" \
	"$(INTDIR)\authusekey.sbr" \
	"$(INTDIR)\buftvtots.sbr" \
	"$(INTDIR)\caljulian.sbr" \
	"$(INTDIR)\calleapwhen.sbr" \
	"$(INTDIR)\caltontp.sbr" \
	"$(INTDIR)\calyearstart.sbr" \
	"$(INTDIR)\clocktime.sbr" \
	"$(INTDIR)\clocktypes.sbr" \
	"$(INTDIR)\decodenetnum.sbr" \
	"$(INTDIR)\dofptoa.sbr" \
	"$(INTDIR)\dolfptoa.sbr" \
	"$(INTDIR)\emalloc.sbr" \
	"$(INTDIR)\findconfig.sbr" \
	"$(INTDIR)\fptoa.sbr" \
	"$(INTDIR)\fptoms.sbr" \
	"$(INTDIR)\getopt.sbr" \
	"$(INTDIR)\hextoint.sbr" \
	"$(INTDIR)\hextolfp.sbr" \
	"$(INTDIR)\humandate.sbr" \
	"$(INTDIR)\inttoa.sbr" \
	"$(INTDIR)\lib_strbuf.sbr" \
	"$(INTDIR)\log.sbr" \
	"$(INTDIR)\machines.sbr" \
	"$(INTDIR)\md5.sbr" \
	"$(INTDIR)\mexit.sbr" \
	"$(INTDIR)\mfptoa.sbr" \
	"$(INTDIR)\mfptoms.sbr" \
	"$(INTDIR)\modetoa.sbr" \
	"$(INTDIR)\mstolfp.sbr" \
	"$(INTDIR)\msutotsf.sbr" \
	"$(INTDIR)\msyslog.sbr" \
	"$(INTDIR)\netof.sbr" \
	"$(INTDIR)\numtoa.sbr" \
	"$(INTDIR)\numtohost.sbr" \
	"$(INTDIR)\octtoint.sbr" \
	"$(INTDIR)\prettydate.sbr" \
	"$(INTDIR)\ranny.sbr" \
	"$(INTDIR)\refnumtoa.sbr" \
	"$(INTDIR)\statestr.sbr" \
	"$(INTDIR)\syssignal.sbr" \
	"$(INTDIR)\systime.sbr" \
	"$(INTDIR)\tsftomsu.sbr" \
	"$(INTDIR)\tstotv.sbr" \
	"$(INTDIR)\tvtoa.sbr" \
	"$(INTDIR)\tvtots.sbr" \
	"$(INTDIR)\uglydate.sbr" \
	"$(INTDIR)\uinttoa.sbr" \
	"$(INTDIR)\utvtoa.sbr"

"$(OUTDIR)\libntp.bsc" : "$(OUTDIR)" $(BSC32_SBRS)
    $(BSC32) @<<
  $(BSC32_FLAGS) $(BSC32_SBRS)
<<

LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo
LIB32_FLAGS=/nologo /out:"$(OUTDIR)/libntp.lib" 
LIB32_OBJS= \
	"$(INTDIR)\a_md512crypt.obj" \
	"$(INTDIR)\a_md5decrypt.obj" \
	"$(INTDIR)\a_md5encrypt.obj" \
	"$(INTDIR)\atoint.obj" \
	"$(INTDIR)\atolfp.obj" \
	"$(INTDIR)\atouint.obj" \
	"$(INTDIR)\auth12crypt.obj" \
	"$(INTDIR)\authdecrypt.obj" \
	"$(INTDIR)\authdes.obj" \
	"$(INTDIR)\authencrypt.obj" \
	"$(INTDIR)\authkeys.obj" \
	"$(INTDIR)\authparity.obj" \
	"$(INTDIR)\authreadkeys.obj" \
	"$(INTDIR)\authusekey.obj" \
	"$(INTDIR)\buftvtots.obj" \
	"$(INTDIR)\caljulian.obj" \
	"$(INTDIR)\calleapwhen.obj" \
	"$(INTDIR)\caltontp.obj" \
	"$(INTDIR)\calyearstart.obj" \
	"$(INTDIR)\clocktime.obj" \
	"$(INTDIR)\clocktypes.obj" \
	"$(INTDIR)\decodenetnum.obj" \
	"$(INTDIR)\dofptoa.obj" \
	"$(INTDIR)\dolfptoa.obj" \
	"$(INTDIR)\emalloc.obj" \
	"$(INTDIR)\findconfig.obj" \
	"$(INTDIR)\fptoa.obj" \
	"$(INTDIR)\fptoms.obj" \
	"$(INTDIR)\getopt.obj" \
	"$(INTDIR)\hextoint.obj" \
	"$(INTDIR)\hextolfp.obj" \
	"$(INTDIR)\humandate.obj" \
	"$(INTDIR)\inttoa.obj" \
	"$(INTDIR)\lib_strbuf.obj" \
	"$(INTDIR)\log.obj" \
	"$(INTDIR)\machines.obj" \
	"$(INTDIR)\md5.obj" \
	"$(INTDIR)\mexit.obj" \
	"$(INTDIR)\mfptoa.obj" \
	"$(INTDIR)\mfptoms.obj" \
	"$(INTDIR)\modetoa.obj" \
	"$(INTDIR)\mstolfp.obj" \
	"$(INTDIR)\msutotsf.obj" \
	"$(INTDIR)\msyslog.obj" \
	"$(INTDIR)\netof.obj" \
	"$(INTDIR)\numtoa.obj" \
	"$(INTDIR)\numtohost.obj" \
	"$(INTDIR)\octtoint.obj" \
	"$(INTDIR)\prettydate.obj" \
	"$(INTDIR)\ranny.obj" \
	"$(INTDIR)\refnumtoa.obj" \
	"$(INTDIR)\statestr.obj" \
	"$(INTDIR)\syssignal.obj" \
	"$(INTDIR)\systime.obj" \
	"$(INTDIR)\tsftomsu.obj" \
	"$(INTDIR)\tstotv.obj" \
	"$(INTDIR)\tvtoa.obj" \
	"$(INTDIR)\tvtots.obj" \
	"$(INTDIR)\uglydate.obj" \
	"$(INTDIR)\uinttoa.obj" \
	"$(INTDIR)\utvtoa.obj"

"$(OUTDIR)\libntp.lib" : "$(OUTDIR)" $(DEF_FILE) $(LIB32_OBJS)
    $(LIB32) @<<
  $(LIB32_FLAGS) $(DEF_FLAGS) $(LIB32_OBJS)
<<

!ELSEIF  "$(CFG)" == "libntp - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "WinDebug"
# PROP BASE Intermediate_Dir "WinDebug"
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "WinDebug"
# PROP Intermediate_Dir "WinDebug"
OUTDIR=.\WinDebug
INTDIR=.\WinDebug

ALL : "$(OUTDIR)\libntp.lib" "$(OUTDIR)\libntp.bsc"

CLEAN : 
	-@erase "$(INTDIR)\a_md512crypt.obj"
	-@erase "$(INTDIR)\a_md512crypt.sbr"
	-@erase "$(INTDIR)\a_md5decrypt.obj"
	-@erase "$(INTDIR)\a_md5decrypt.sbr"
	-@erase "$(INTDIR)\a_md5encrypt.obj"
	-@erase "$(INTDIR)\a_md5encrypt.sbr"
	-@erase "$(INTDIR)\atoint.obj"
	-@erase "$(INTDIR)\atoint.sbr"
	-@erase "$(INTDIR)\atolfp.obj"
	-@erase "$(INTDIR)\atolfp.sbr"
	-@erase "$(INTDIR)\atouint.obj"
	-@erase "$(INTDIR)\atouint.sbr"
	-@erase "$(INTDIR)\auth12crypt.obj"
	-@erase "$(INTDIR)\auth12crypt.sbr"
	-@erase "$(INTDIR)\authdecrypt.obj"
	-@erase "$(INTDIR)\authdecrypt.sbr"
	-@erase "$(INTDIR)\authdes.obj"
	-@erase "$(INTDIR)\authdes.sbr"
	-@erase "$(INTDIR)\authencrypt.obj"
	-@erase "$(INTDIR)\authencrypt.sbr"
	-@erase "$(INTDIR)\authkeys.obj"
	-@erase "$(INTDIR)\authkeys.sbr"
	-@erase "$(INTDIR)\authparity.obj"
	-@erase "$(INTDIR)\authparity.sbr"
	-@erase "$(INTDIR)\authreadkeys.obj"
	-@erase "$(INTDIR)\authreadkeys.sbr"
	-@erase "$(INTDIR)\authusekey.obj"
	-@erase "$(INTDIR)\authusekey.sbr"
	-@erase "$(INTDIR)\buftvtots.obj"
	-@erase "$(INTDIR)\buftvtots.sbr"
	-@erase "$(INTDIR)\caljulian.obj"
	-@erase "$(INTDIR)\caljulian.sbr"
	-@erase "$(INTDIR)\calleapwhen.obj"
	-@erase "$(INTDIR)\calleapwhen.sbr"
	-@erase "$(INTDIR)\caltontp.obj"
	-@erase "$(INTDIR)\caltontp.sbr"
	-@erase "$(INTDIR)\calyearstart.obj"
	-@erase "$(INTDIR)\calyearstart.sbr"
	-@erase "$(INTDIR)\clocktime.obj"
	-@erase "$(INTDIR)\clocktime.sbr"
	-@erase "$(INTDIR)\clocktypes.obj"
	-@erase "$(INTDIR)\clocktypes.sbr"
	-@erase "$(INTDIR)\decodenetnum.obj"
	-@erase "$(INTDIR)\decodenetnum.sbr"
	-@erase "$(INTDIR)\dofptoa.obj"
	-@erase "$(INTDIR)\dofptoa.sbr"
	-@erase "$(INTDIR)\dolfptoa.obj"
	-@erase "$(INTDIR)\dolfptoa.sbr"
	-@erase "$(INTDIR)\emalloc.obj"
	-@erase "$(INTDIR)\emalloc.sbr"
	-@erase "$(INTDIR)\findconfig.obj"
	-@erase "$(INTDIR)\findconfig.sbr"
	-@erase "$(INTDIR)\fptoa.obj"
	-@erase "$(INTDIR)\fptoa.sbr"
	-@erase "$(INTDIR)\fptoms.obj"
	-@erase "$(INTDIR)\fptoms.sbr"
	-@erase "$(INTDIR)\getopt.obj"
	-@erase "$(INTDIR)\getopt.sbr"
	-@erase "$(INTDIR)\hextoint.obj"
	-@erase "$(INTDIR)\hextoint.sbr"
	-@erase "$(INTDIR)\hextolfp.obj"
	-@erase "$(INTDIR)\hextolfp.sbr"
	-@erase "$(INTDIR)\humandate.obj"
	-@erase "$(INTDIR)\humandate.sbr"
	-@erase "$(INTDIR)\inttoa.obj"
	-@erase "$(INTDIR)\inttoa.sbr"
	-@erase "$(INTDIR)\lib_strbuf.obj"
	-@erase "$(INTDIR)\lib_strbuf.sbr"
	-@erase "$(INTDIR)\log.obj"
	-@erase "$(INTDIR)\log.sbr"
	-@erase "$(INTDIR)\machines.obj"
	-@erase "$(INTDIR)\machines.sbr"
	-@erase "$(INTDIR)\md5.obj"
	-@erase "$(INTDIR)\md5.sbr"
	-@erase "$(INTDIR)\mexit.obj"
	-@erase "$(INTDIR)\mexit.sbr"
	-@erase "$(INTDIR)\mfptoa.obj"
	-@erase "$(INTDIR)\mfptoa.sbr"
	-@erase "$(INTDIR)\mfptoms.obj"
	-@erase "$(INTDIR)\mfptoms.sbr"
	-@erase "$(INTDIR)\modetoa.obj"
	-@erase "$(INTDIR)\modetoa.sbr"
	-@erase "$(INTDIR)\mstolfp.obj"
	-@erase "$(INTDIR)\mstolfp.sbr"
	-@erase "$(INTDIR)\msutotsf.obj"
	-@erase "$(INTDIR)\msutotsf.sbr"
	-@erase "$(INTDIR)\msyslog.obj"
	-@erase "$(INTDIR)\msyslog.sbr"
	-@erase "$(INTDIR)\netof.obj"
	-@erase "$(INTDIR)\netof.sbr"
	-@erase "$(INTDIR)\numtoa.obj"
	-@erase "$(INTDIR)\numtoa.sbr"
	-@erase "$(INTDIR)\numtohost.obj"
	-@erase "$(INTDIR)\numtohost.sbr"
	-@erase "$(INTDIR)\octtoint.obj"
	-@erase "$(INTDIR)\octtoint.sbr"
	-@erase "$(INTDIR)\prettydate.obj"
	-@erase "$(INTDIR)\prettydate.sbr"
	-@erase "$(INTDIR)\ranny.obj"
	-@erase "$(INTDIR)\ranny.sbr"
	-@erase "$(INTDIR)\refnumtoa.obj"
	-@erase "$(INTDIR)\refnumtoa.sbr"
	-@erase "$(INTDIR)\statestr.obj"
	-@erase "$(INTDIR)\statestr.sbr"
	-@erase "$(INTDIR)\syssignal.obj"
	-@erase "$(INTDIR)\syssignal.sbr"
	-@erase "$(INTDIR)\systime.obj"
	-@erase "$(INTDIR)\systime.sbr"
	-@erase "$(INTDIR)\tsftomsu.obj"
	-@erase "$(INTDIR)\tsftomsu.sbr"
	-@erase "$(INTDIR)\tstotv.obj"
	-@erase "$(INTDIR)\tstotv.sbr"
	-@erase "$(INTDIR)\tvtoa.obj"
	-@erase "$(INTDIR)\tvtoa.sbr"
	-@erase "$(INTDIR)\tvtots.obj"
	-@erase "$(INTDIR)\tvtots.sbr"
	-@erase "$(INTDIR)\uglydate.obj"
	-@erase "$(INTDIR)\uglydate.sbr"
	-@erase "$(INTDIR)\uinttoa.obj"
	-@erase "$(INTDIR)\uinttoa.sbr"
	-@erase "$(INTDIR)\utvtoa.obj"
	-@erase "$(INTDIR)\utvtoa.sbr"
	-@erase "$(INTDIR)\vc40.idb"
	-@erase "$(INTDIR)\vc40.pdb"
	-@erase "$(OUTDIR)\libntp.bsc"
	-@erase "$(OUTDIR)\libntp.lib"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

# ADD BASE CPP /nologo /ML /W3 /GX /Z7 /Od /D "WIN32" /D "_DEBUG" /D "_WINDOWS" /FR /YX /c
# ADD CPP /nologo /MTd /W3 /Gm /GX /Zi /Od /I "..\include" /I "..\include\winnt" /D "_DEBUG" /D "DEBUG" /D "WIN32" /D "_WINDOWS" /D "SYS_WINNT" /D "__STDC__" /FR /YX /c
CPP_PROJ=/nologo /MTd /W3 /Gm /GX /Zi /Od /I "..\include" /I "..\include\winnt"\
 /D "_DEBUG" /D "DEBUG" /D "WIN32" /D "_WINDOWS" /D "SYS_WINNT" /D "__STDC__"\
 /FR"$(INTDIR)/" /Fp"$(INTDIR)/libntp.pch" /YX /Fo"$(INTDIR)/" /Fd"$(INTDIR)/"\
 /c 
CPP_OBJS=.\WinDebug/
CPP_SBRS=.\WinDebug/
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
BSC32_FLAGS=/nologo /o"$(OUTDIR)/libntp.bsc" 
BSC32_SBRS= \
	"$(INTDIR)\a_md512crypt.sbr" \
	"$(INTDIR)\a_md5decrypt.sbr" \
	"$(INTDIR)\a_md5encrypt.sbr" \
	"$(INTDIR)\atoint.sbr" \
	"$(INTDIR)\atolfp.sbr" \
	"$(INTDIR)\atouint.sbr" \
	"$(INTDIR)\auth12crypt.sbr" \
	"$(INTDIR)\authdecrypt.sbr" \
	"$(INTDIR)\authdes.sbr" \
	"$(INTDIR)\authencrypt.sbr" \
	"$(INTDIR)\authkeys.sbr" \
	"$(INTDIR)\authparity.sbr" \
	"$(INTDIR)\authreadkeys.sbr" \
	"$(INTDIR)\authusekey.sbr" \
	"$(INTDIR)\buftvtots.sbr" \
	"$(INTDIR)\caljulian.sbr" \
	"$(INTDIR)\calleapwhen.sbr" \
	"$(INTDIR)\caltontp.sbr" \
	"$(INTDIR)\calyearstart.sbr" \
	"$(INTDIR)\clocktime.sbr" \
	"$(INTDIR)\clocktypes.sbr" \
	"$(INTDIR)\decodenetnum.sbr" \
	"$(INTDIR)\dofptoa.sbr" \
	"$(INTDIR)\dolfptoa.sbr" \
	"$(INTDIR)\emalloc.sbr" \
	"$(INTDIR)\findconfig.sbr" \
	"$(INTDIR)\fptoa.sbr" \
	"$(INTDIR)\fptoms.sbr" \
	"$(INTDIR)\getopt.sbr" \
	"$(INTDIR)\hextoint.sbr" \
	"$(INTDIR)\hextolfp.sbr" \
	"$(INTDIR)\humandate.sbr" \
	"$(INTDIR)\inttoa.sbr" \
	"$(INTDIR)\lib_strbuf.sbr" \
	"$(INTDIR)\log.sbr" \
	"$(INTDIR)\machines.sbr" \
	"$(INTDIR)\md5.sbr" \
	"$(INTDIR)\mexit.sbr" \
	"$(INTDIR)\mfptoa.sbr" \
	"$(INTDIR)\mfptoms.sbr" \
	"$(INTDIR)\modetoa.sbr" \
	"$(INTDIR)\mstolfp.sbr" \
	"$(INTDIR)\msutotsf.sbr" \
	"$(INTDIR)\msyslog.sbr" \
	"$(INTDIR)\netof.sbr" \
	"$(INTDIR)\numtoa.sbr" \
	"$(INTDIR)\numtohost.sbr" \
	"$(INTDIR)\octtoint.sbr" \
	"$(INTDIR)\prettydate.sbr" \
	"$(INTDIR)\ranny.sbr" \
	"$(INTDIR)\refnumtoa.sbr" \
	"$(INTDIR)\statestr.sbr" \
	"$(INTDIR)\syssignal.sbr" \
	"$(INTDIR)\systime.sbr" \
	"$(INTDIR)\tsftomsu.sbr" \
	"$(INTDIR)\tstotv.sbr" \
	"$(INTDIR)\tvtoa.sbr" \
	"$(INTDIR)\tvtots.sbr" \
	"$(INTDIR)\uglydate.sbr" \
	"$(INTDIR)\uinttoa.sbr" \
	"$(INTDIR)\utvtoa.sbr"

"$(OUTDIR)\libntp.bsc" : "$(OUTDIR)" $(BSC32_SBRS)
    $(BSC32) @<<
  $(BSC32_FLAGS) $(BSC32_SBRS)
<<

LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo
LIB32_FLAGS=/nologo /out:"$(OUTDIR)/libntp.lib" 
LIB32_OBJS= \
	"$(INTDIR)\a_md512crypt.obj" \
	"$(INTDIR)\a_md5decrypt.obj" \
	"$(INTDIR)\a_md5encrypt.obj" \
	"$(INTDIR)\atoint.obj" \
	"$(INTDIR)\atolfp.obj" \
	"$(INTDIR)\atouint.obj" \
	"$(INTDIR)\auth12crypt.obj" \
	"$(INTDIR)\authdecrypt.obj" \
	"$(INTDIR)\authdes.obj" \
	"$(INTDIR)\authencrypt.obj" \
	"$(INTDIR)\authkeys.obj" \
	"$(INTDIR)\authparity.obj" \
	"$(INTDIR)\authreadkeys.obj" \
	"$(INTDIR)\authusekey.obj" \
	"$(INTDIR)\buftvtots.obj" \
	"$(INTDIR)\caljulian.obj" \
	"$(INTDIR)\calleapwhen.obj" \
	"$(INTDIR)\caltontp.obj" \
	"$(INTDIR)\calyearstart.obj" \
	"$(INTDIR)\clocktime.obj" \
	"$(INTDIR)\clocktypes.obj" \
	"$(INTDIR)\decodenetnum.obj" \
	"$(INTDIR)\dofptoa.obj" \
	"$(INTDIR)\dolfptoa.obj" \
	"$(INTDIR)\emalloc.obj" \
	"$(INTDIR)\findconfig.obj" \
	"$(INTDIR)\fptoa.obj" \
	"$(INTDIR)\fptoms.obj" \
	"$(INTDIR)\getopt.obj" \
	"$(INTDIR)\hextoint.obj" \
	"$(INTDIR)\hextolfp.obj" \
	"$(INTDIR)\humandate.obj" \
	"$(INTDIR)\inttoa.obj" \
	"$(INTDIR)\lib_strbuf.obj" \
	"$(INTDIR)\log.obj" \
	"$(INTDIR)\machines.obj" \
	"$(INTDIR)\md5.obj" \
	"$(INTDIR)\mexit.obj" \
	"$(INTDIR)\mfptoa.obj" \
	"$(INTDIR)\mfptoms.obj" \
	"$(INTDIR)\modetoa.obj" \
	"$(INTDIR)\mstolfp.obj" \
	"$(INTDIR)\msutotsf.obj" \
	"$(INTDIR)\msyslog.obj" \
	"$(INTDIR)\netof.obj" \
	"$(INTDIR)\numtoa.obj" \
	"$(INTDIR)\numtohost.obj" \
	"$(INTDIR)\octtoint.obj" \
	"$(INTDIR)\prettydate.obj" \
	"$(INTDIR)\ranny.obj" \
	"$(INTDIR)\refnumtoa.obj" \
	"$(INTDIR)\statestr.obj" \
	"$(INTDIR)\syssignal.obj" \
	"$(INTDIR)\systime.obj" \
	"$(INTDIR)\tsftomsu.obj" \
	"$(INTDIR)\tstotv.obj" \
	"$(INTDIR)\tvtoa.obj" \
	"$(INTDIR)\tvtots.obj" \
	"$(INTDIR)\uglydate.obj" \
	"$(INTDIR)\uinttoa.obj" \
	"$(INTDIR)\utvtoa.obj"

"$(OUTDIR)\libntp.lib" : "$(OUTDIR)" $(DEF_FILE) $(LIB32_OBJS)
    $(LIB32) @<<
  $(LIB32_FLAGS) $(DEF_FLAGS) $(LIB32_OBJS)
<<

!ENDIF 

.c{$(CPP_OBJS)}.obj:
   $(CPP) $(CPP_PROJ) $<  

.cpp{$(CPP_OBJS)}.obj:
   $(CPP) $(CPP_PROJ) $<  

.cxx{$(CPP_OBJS)}.obj:
   $(CPP) $(CPP_PROJ) $<  

.c{$(CPP_SBRS)}.sbr:
   $(CPP) $(CPP_PROJ) $<  

.cpp{$(CPP_SBRS)}.sbr:
   $(CPP) $(CPP_PROJ) $<  

.cxx{$(CPP_SBRS)}.sbr:
   $(CPP) $(CPP_PROJ) $<  

################################################################################
# Begin Target

# Name "libntp - Win32 Release"
# Name "libntp - Win32 Debug"

!IF  "$(CFG)" == "libntp - Win32 Release"

!ELSEIF  "$(CFG)" == "libntp - Win32 Debug"

!ENDIF 

################################################################################
# Begin Source File

SOURCE=.\mfptoa.c
DEP_CPP_MFPTO=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\mfptoa.obj" : $(SOURCE) $(DEP_CPP_MFPTO) "$(INTDIR)"

"$(INTDIR)\mfptoa.sbr" : $(SOURCE) $(DEP_CPP_MFPTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\lib_strbuf.c
DEP_CPP_LIB_S=\
	"..\include\ntp_types.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\lib_strbuf.obj" : $(SOURCE) $(DEP_CPP_LIB_S) "$(INTDIR)"

"$(INTDIR)\lib_strbuf.sbr" : $(SOURCE) $(DEP_CPP_LIB_S) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\decodenetnum.c
DEP_CPP_DECOD=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\decodenetnum.obj" : $(SOURCE) $(DEP_CPP_DECOD) "$(INTDIR)"

"$(INTDIR)\decodenetnum.sbr" : $(SOURCE) $(DEP_CPP_DECOD) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\clocktime.c
DEP_CPP_CLOCK=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\clocktime.obj" : $(SOURCE) $(DEP_CPP_CLOCK) "$(INTDIR)"

"$(INTDIR)\clocktime.sbr" : $(SOURCE) $(DEP_CPP_CLOCK) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\uinttoa.c
DEP_CPP_UINTT=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\uinttoa.obj" : $(SOURCE) $(DEP_CPP_UINTT) "$(INTDIR)"

"$(INTDIR)\uinttoa.sbr" : $(SOURCE) $(DEP_CPP_UINTT) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\numtoa.c
DEP_CPP_NUMTO=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\numtoa.obj" : $(SOURCE) $(DEP_CPP_NUMTO) "$(INTDIR)"

"$(INTDIR)\numtoa.sbr" : $(SOURCE) $(DEP_CPP_NUMTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\octtoint.c
DEP_CPP_OCTTO=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\octtoint.obj" : $(SOURCE) $(DEP_CPP_OCTTO) "$(INTDIR)"

"$(INTDIR)\octtoint.sbr" : $(SOURCE) $(DEP_CPP_OCTTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\inttoa.c
DEP_CPP_INTTO=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\inttoa.obj" : $(SOURCE) $(DEP_CPP_INTTO) "$(INTDIR)"

"$(INTDIR)\inttoa.sbr" : $(SOURCE) $(DEP_CPP_INTTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\mstolfp.c
DEP_CPP_MSTOL=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\mstolfp.obj" : $(SOURCE) $(DEP_CPP_MSTOL) "$(INTDIR)"

"$(INTDIR)\mstolfp.sbr" : $(SOURCE) $(DEP_CPP_MSTOL) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\authdecrypt.c
DEP_CPP_AUTHD=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\authdecrypt.obj" : $(SOURCE) $(DEP_CPP_AUTHD) "$(INTDIR)"

"$(INTDIR)\authdecrypt.sbr" : $(SOURCE) $(DEP_CPP_AUTHD) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\tstotv.c
DEP_CPP_TSTOT=\
	"..\include\ntp_types.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\tstotv.obj" : $(SOURCE) $(DEP_CPP_TSTOT) "$(INTDIR)"

"$(INTDIR)\tstotv.sbr" : $(SOURCE) $(DEP_CPP_TSTOT) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\a_md512crypt.c
DEP_CPP_A_MD5=\
	"..\include\md5.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\a_md512crypt.obj" : $(SOURCE) $(DEP_CPP_A_MD5) "$(INTDIR)"

"$(INTDIR)\a_md512crypt.sbr" : $(SOURCE) $(DEP_CPP_A_MD5) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\modetoa.c
DEP_CPP_MODET=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\modetoa.obj" : $(SOURCE) $(DEP_CPP_MODET) "$(INTDIR)"

"$(INTDIR)\modetoa.sbr" : $(SOURCE) $(DEP_CPP_MODET) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\atouint.c
DEP_CPP_ATOUI=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\atouint.obj" : $(SOURCE) $(DEP_CPP_ATOUI) "$(INTDIR)"

"$(INTDIR)\atouint.sbr" : $(SOURCE) $(DEP_CPP_ATOUI) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\getopt.c
DEP_CPP_GETOP=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\getopt.obj" : $(SOURCE) $(DEP_CPP_GETOP) "$(INTDIR)"

"$(INTDIR)\getopt.sbr" : $(SOURCE) $(DEP_CPP_GETOP) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\uglydate.c
DEP_CPP_UGLYD=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\uglydate.obj" : $(SOURCE) $(DEP_CPP_UGLYD) "$(INTDIR)"

"$(INTDIR)\uglydate.sbr" : $(SOURCE) $(DEP_CPP_UGLYD) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\machines.c
DEP_CPP_MACHI=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_syslog.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\syslog.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	
NODEP_CPP_MACHI=\
	".\..\include\gizmo_syslog.h"\
	

"$(INTDIR)\machines.obj" : $(SOURCE) $(DEP_CPP_MACHI) "$(INTDIR)"

"$(INTDIR)\machines.sbr" : $(SOURCE) $(DEP_CPP_MACHI) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\dolfptoa.c
DEP_CPP_DOLFP=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\dolfptoa.obj" : $(SOURCE) $(DEP_CPP_DOLFP) "$(INTDIR)"

"$(INTDIR)\dolfptoa.sbr" : $(SOURCE) $(DEP_CPP_DOLFP) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\a_md5decrypt.c
DEP_CPP_A_MD5D=\
	"..\include\md5.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\a_md5decrypt.obj" : $(SOURCE) $(DEP_CPP_A_MD5D) "$(INTDIR)"

"$(INTDIR)\a_md5decrypt.sbr" : $(SOURCE) $(DEP_CPP_A_MD5D) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\mexit.c

"$(INTDIR)\mexit.obj" : $(SOURCE) "$(INTDIR)"

"$(INTDIR)\mexit.sbr" : $(SOURCE) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\msutotsf.c
DEP_CPP_MSUTO=\
	"..\include\ntp_types.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\msutotsf.obj" : $(SOURCE) $(DEP_CPP_MSUTO) "$(INTDIR)"

"$(INTDIR)\msutotsf.sbr" : $(SOURCE) $(DEP_CPP_MSUTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\atoint.c
DEP_CPP_ATOIN=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\atoint.obj" : $(SOURCE) $(DEP_CPP_ATOIN) "$(INTDIR)"

"$(INTDIR)\atoint.sbr" : $(SOURCE) $(DEP_CPP_ATOIN) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\auth12crypt.c
DEP_CPP_AUTH1=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\auth12crypt.obj" : $(SOURCE) $(DEP_CPP_AUTH1) "$(INTDIR)"

"$(INTDIR)\auth12crypt.sbr" : $(SOURCE) $(DEP_CPP_AUTH1) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\tsftomsu.c
DEP_CPP_TSFTO=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\tsftomsu.obj" : $(SOURCE) $(DEP_CPP_TSFTO) "$(INTDIR)"

"$(INTDIR)\tsftomsu.sbr" : $(SOURCE) $(DEP_CPP_TSFTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\systime.c
DEP_CPP_SYSTI=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_syslog.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/param.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	"..\include\winnt\syslog.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	
NODEP_CPP_SYSTI=\
	".\..\include\gizmo_syslog.h"\
	

"$(INTDIR)\systime.obj" : $(SOURCE) $(DEP_CPP_SYSTI) "$(INTDIR)"

"$(INTDIR)\systime.sbr" : $(SOURCE) $(DEP_CPP_SYSTI) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\tvtots.c
DEP_CPP_TVTOT=\
	"..\include\ntp_types.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\tvtots.obj" : $(SOURCE) $(DEP_CPP_TVTOT) "$(INTDIR)"

"$(INTDIR)\tvtots.sbr" : $(SOURCE) $(DEP_CPP_TVTOT) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\findconfig.c
DEP_CPP_FINDC=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\STAT.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\findconfig.obj" : $(SOURCE) $(DEP_CPP_FINDC) "$(INTDIR)"

"$(INTDIR)\findconfig.sbr" : $(SOURCE) $(DEP_CPP_FINDC) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\authkeys.c
DEP_CPP_AUTHK=\
	"..\include\ntp_malloc.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\authkeys.obj" : $(SOURCE) $(DEP_CPP_AUTHK) "$(INTDIR)"

"$(INTDIR)\authkeys.sbr" : $(SOURCE) $(DEP_CPP_AUTHK) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\a_md5encrypt.c
DEP_CPP_A_MD5E=\
	"..\include\md5.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\a_md5encrypt.obj" : $(SOURCE) $(DEP_CPP_A_MD5E) "$(INTDIR)"

"$(INTDIR)\a_md5encrypt.sbr" : $(SOURCE) $(DEP_CPP_A_MD5E) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\ranny.c
DEP_CPP_RANNY=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\ranny.obj" : $(SOURCE) $(DEP_CPP_RANNY) "$(INTDIR)"

"$(INTDIR)\ranny.sbr" : $(SOURCE) $(DEP_CPP_RANNY) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\tvtoa.c
DEP_CPP_TVTOA=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\tvtoa.obj" : $(SOURCE) $(DEP_CPP_TVTOA) "$(INTDIR)"

"$(INTDIR)\tvtoa.sbr" : $(SOURCE) $(DEP_CPP_TVTOA) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\refnumtoa.c
DEP_CPP_REFNU=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\refnumtoa.obj" : $(SOURCE) $(DEP_CPP_REFNU) "$(INTDIR)"

"$(INTDIR)\refnumtoa.sbr" : $(SOURCE) $(DEP_CPP_REFNU) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\netof.c
DEP_CPP_NETOF=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\netof.obj" : $(SOURCE) $(DEP_CPP_NETOF) "$(INTDIR)"

"$(INTDIR)\netof.sbr" : $(SOURCE) $(DEP_CPP_NETOF) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\hextoint.c
DEP_CPP_HEXTO=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\hextoint.obj" : $(SOURCE) $(DEP_CPP_HEXTO) "$(INTDIR)"

"$(INTDIR)\hextoint.sbr" : $(SOURCE) $(DEP_CPP_HEXTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\caltontp.c
DEP_CPP_CALTO=\
	"..\include\ntp_calendar.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\caltontp.obj" : $(SOURCE) $(DEP_CPP_CALTO) "$(INTDIR)"

"$(INTDIR)\caltontp.sbr" : $(SOURCE) $(DEP_CPP_CALTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\emalloc.c
DEP_CPP_EMALL=\
	"..\include\ntp_malloc.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_syslog.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\syslog.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	
NODEP_CPP_EMALL=\
	".\..\include\gizmo_syslog.h"\
	

"$(INTDIR)\emalloc.obj" : $(SOURCE) $(DEP_CPP_EMALL) "$(INTDIR)"

"$(INTDIR)\emalloc.sbr" : $(SOURCE) $(DEP_CPP_EMALL) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\calleapwhen.c
DEP_CPP_CALLE=\
	"..\include\ntp_calendar.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\calleapwhen.obj" : $(SOURCE) $(DEP_CPP_CALLE) "$(INTDIR)"

"$(INTDIR)\calleapwhen.sbr" : $(SOURCE) $(DEP_CPP_CALLE) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\md5.c
DEP_CPP_MD5_C=\
	"..\include\md5.h"\
	"..\include\ntp_types.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\md5.obj" : $(SOURCE) $(DEP_CPP_MD5_C) "$(INTDIR)"

"$(INTDIR)\md5.sbr" : $(SOURCE) $(DEP_CPP_MD5_C) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\fptoa.c
DEP_CPP_FPTOA=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\fptoa.obj" : $(SOURCE) $(DEP_CPP_FPTOA) "$(INTDIR)"

"$(INTDIR)\fptoa.sbr" : $(SOURCE) $(DEP_CPP_FPTOA) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\authdes.c
DEP_CPP_AUTHDE=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\authdes.obj" : $(SOURCE) $(DEP_CPP_AUTHDE) "$(INTDIR)"

"$(INTDIR)\authdes.sbr" : $(SOURCE) $(DEP_CPP_AUTHDE) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\authusekey.c
DEP_CPP_AUTHU=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\authusekey.obj" : $(SOURCE) $(DEP_CPP_AUTHU) "$(INTDIR)"

"$(INTDIR)\authusekey.sbr" : $(SOURCE) $(DEP_CPP_AUTHU) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\buftvtots.c
DEP_CPP_BUFTV=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\buftvtots.obj" : $(SOURCE) $(DEP_CPP_BUFTV) "$(INTDIR)"

"$(INTDIR)\buftvtots.sbr" : $(SOURCE) $(DEP_CPP_BUFTV) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\calyearstart.c
DEP_CPP_CALYE=\
	"..\include\ntp_calendar.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\calyearstart.obj" : $(SOURCE) $(DEP_CPP_CALYE) "$(INTDIR)"

"$(INTDIR)\calyearstart.sbr" : $(SOURCE) $(DEP_CPP_CALYE) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\utvtoa.c
DEP_CPP_UTVTO=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\utvtoa.obj" : $(SOURCE) $(DEP_CPP_UTVTO) "$(INTDIR)"

"$(INTDIR)\utvtoa.sbr" : $(SOURCE) $(DEP_CPP_UTVTO) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\atolfp.c
DEP_CPP_ATOLF=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\atolfp.obj" : $(SOURCE) $(DEP_CPP_ATOLF) "$(INTDIR)"

"$(INTDIR)\atolfp.sbr" : $(SOURCE) $(DEP_CPP_ATOLF) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\msyslog.c
DEP_CPP_MSYSL=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_syslog.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\syslog.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\log.h"\
	".\messages.h"\
	{$(INCLUDE)}"\sys\types.h"\
	
NODEP_CPP_MSYSL=\
	".\..\include\gizmo_syslog.h"\
	

"$(INTDIR)\msyslog.obj" : $(SOURCE) $(DEP_CPP_MSYSL) "$(INTDIR)"

"$(INTDIR)\msyslog.sbr" : $(SOURCE) $(DEP_CPP_MSYSL) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\clocktypes.c
DEP_CPP_CLOCKT=\
	"..\include\ntp.h"\
	"..\include\ntp_fp.h"\
	"..\include\ntp_refclock.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\clocktypes.obj" : $(SOURCE) $(DEP_CPP_CLOCKT) "$(INTDIR)"

"$(INTDIR)\clocktypes.sbr" : $(SOURCE) $(DEP_CPP_CLOCKT) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\caljulian.c
DEP_CPP_CALJU=\
	"..\include\ntp_calendar.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\caljulian.obj" : $(SOURCE) $(DEP_CPP_CALJU) "$(INTDIR)"

"$(INTDIR)\caljulian.sbr" : $(SOURCE) $(DEP_CPP_CALJU) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\authencrypt.c
DEP_CPP_AUTHE=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\authencrypt.obj" : $(SOURCE) $(DEP_CPP_AUTHE) "$(INTDIR)"

"$(INTDIR)\authencrypt.sbr" : $(SOURCE) $(DEP_CPP_AUTHE) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\prettydate.c
DEP_CPP_PRETT=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\prettydate.obj" : $(SOURCE) $(DEP_CPP_PRETT) "$(INTDIR)"

"$(INTDIR)\prettydate.sbr" : $(SOURCE) $(DEP_CPP_PRETT) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\hextolfp.c
DEP_CPP_HEXTOL=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\hextolfp.obj" : $(SOURCE) $(DEP_CPP_HEXTOL) "$(INTDIR)"

"$(INTDIR)\hextolfp.sbr" : $(SOURCE) $(DEP_CPP_HEXTOL) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\fptoms.c
DEP_CPP_FPTOM=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\fptoms.obj" : $(SOURCE) $(DEP_CPP_FPTOM) "$(INTDIR)"

"$(INTDIR)\fptoms.sbr" : $(SOURCE) $(DEP_CPP_FPTOM) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\numtohost.c
DEP_CPP_NUMTOH=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netdb.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\numtohost.obj" : $(SOURCE) $(DEP_CPP_NUMTOH) "$(INTDIR)"

"$(INTDIR)\numtohost.sbr" : $(SOURCE) $(DEP_CPP_NUMTOH) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\authparity.c
DEP_CPP_AUTHP=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\authparity.obj" : $(SOURCE) $(DEP_CPP_AUTHP) "$(INTDIR)"

"$(INTDIR)\authparity.sbr" : $(SOURCE) $(DEP_CPP_AUTHP) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\authreadkeys.c
DEP_CPP_AUTHR=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_syslog.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\syslog.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	
NODEP_CPP_AUTHR=\
	".\..\include\gizmo_syslog.h"\
	

"$(INTDIR)\authreadkeys.obj" : $(SOURCE) $(DEP_CPP_AUTHR) "$(INTDIR)"

"$(INTDIR)\authreadkeys.sbr" : $(SOURCE) $(DEP_CPP_AUTHR) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\dofptoa.c
DEP_CPP_DOFPT=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\dofptoa.obj" : $(SOURCE) $(DEP_CPP_DOFPT) "$(INTDIR)"

"$(INTDIR)\dofptoa.sbr" : $(SOURCE) $(DEP_CPP_DOFPT) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\mfptoms.c
DEP_CPP_MFPTOM=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\mfptoms.obj" : $(SOURCE) $(DEP_CPP_MFPTOM) "$(INTDIR)"

"$(INTDIR)\mfptoms.sbr" : $(SOURCE) $(DEP_CPP_MFPTOM) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\statestr.c
DEP_CPP_STATE=\
	"..\include\ntp.h"\
	"..\include\ntp_control.h"\
	"..\include\ntp_fp.h"\
	"..\include\ntp_refclock.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\statestr.obj" : $(SOURCE) $(DEP_CPP_STATE) "$(INTDIR)"

"$(INTDIR)\statestr.sbr" : $(SOURCE) $(DEP_CPP_STATE) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\humandate.c
DEP_CPP_HUMAN=\
	"..\include\ntp_fp.h"\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_types.h"\
	"..\include\ntp_unixtime.h"\
	"..\include\winnt\netinet/in.h"\
	"..\include\winnt\sys/socket.h"\
	"..\include\winnt\sys/time.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	".\lib_strbuf.h"\
	{$(INCLUDE)}"\sys\TIMEB.H"\
	{$(INCLUDE)}"\sys\types.h"\
	

"$(INTDIR)\humandate.obj" : $(SOURCE) $(DEP_CPP_HUMAN) "$(INTDIR)"

"$(INTDIR)\humandate.sbr" : $(SOURCE) $(DEP_CPP_HUMAN) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\messages.rc

!IF  "$(CFG)" == "libntp - Win32 Release"

!ELSEIF  "$(CFG)" == "libntp - Win32 Debug"

!ENDIF 

# End Source File
################################################################################
# Begin Source File

SOURCE=.\log.c
DEP_CPP_LOG_C=\
	".\log.h"\
	".\messages.h"\
	

"$(INTDIR)\log.obj" : $(SOURCE) $(DEP_CPP_LOG_C) "$(INTDIR)"

"$(INTDIR)\log.sbr" : $(SOURCE) $(DEP_CPP_LOG_C) "$(INTDIR)"


# End Source File
################################################################################
# Begin Source File

SOURCE=.\syssignal.c
DEP_CPP_SYSSI=\
	"..\include\ntp_stdlib.h"\
	"..\include\ntp_string.h"\
	"..\include\ntp_syslog.h"\
	"..\include\ntp_types.h"\
	"..\include\winnt\syslog.h"\
	".\..\include\l_stdlib.h"\
	".\..\include\ntp_machine.h"\
	{$(INCLUDE)}"\sys\types.h"\
	
NODEP_CPP_SYSSI=\
	".\..\include\gizmo_syslog.h"\
	

"$(INTDIR)\syssignal.obj" : $(SOURCE) $(DEP_CPP_SYSSI) "$(INTDIR)"

"$(INTDIR)\syssignal.sbr" : $(SOURCE) $(DEP_CPP_SYSSI) "$(INTDIR)"


# End Source File
# End Target
# End Project
################################################################################
