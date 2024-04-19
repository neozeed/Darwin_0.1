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
/**************************************************
 *  ABSTRACT:
 *	exports most of the global variables.
 * 	init_global sets input file name before yyparse
 *		is called.
 *	more_global is called after yyparse and before
 *		any code generation to initialize names
 *		that are derived from the subsystem name.
 *
 *
 * HISTORY
 *  4-Sep-91  Gregg Kellogg (gk) at NeXT
 *	Added SendTime to operate like WaitTime.
 *
 * 07-Apr-89  Richard Draves (rpd) at Carnegie-Mellon University
 *	Extensive revamping.  Added polymorphic arguments.
 *	Allow multiple variable-sized inline arguments in messages.
 *
 * 03-Jan-89  Trey Matteson (trey@next.com)
 *	Removed init_<sysname> function
 *
 *  8-Feb-89  David Golub (dbg) at Carnegie-Mellon University
 *	Use default values for output file names only if they have not
 *	yet been set.
 *
 * 17-Sep-87  Bennet Yee (bsy) at Carnegie-Mellon University
 *	Added GenSymTab
 *
 * 25-Aug-87  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Changed CamelotPrefix to op_
 *
 * 12-Aug-87  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Initialized CamelotPrefix
 *
 * 10-Aug-87  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Changed UseRPC to TRUE
 *
 *  3-Aug-87  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Removed reference to UseThreads.
 *
 * 16-Jul-87  Robert Sansom (rds) at Carnegie Mellon University
 *	Added MsgType.
 *
 * 28-May-87  Richard Draves (rpd) at Carnegie-Mellon University
 *	Created.
 **************************************************/

#include "string.h"
#include "global.h"

boolean_t BeQuiet = FALSE;
boolean_t BeVerbose = FALSE;
boolean_t UseMsgRPC = TRUE;
boolean_t GenSymTab = FALSE;

boolean_t IsKernel = FALSE;
boolean_t IsCamelot = FALSE;

string_t RCSId = strNULL;

string_t SubsystemName = strNULL;
u_int SubsystemBase = 0;

string_t MsgType = strNULL;
string_t WaitTime = strNULL;
#if	NeXT
string_t SendTime = strNULL;
#endif	NeXT
string_t ErrorProc = "MsgError";
string_t ServerPrefix = strNULL;
string_t UserPrefix = strNULL;
char CamelotPrefix[4] = "op_";

string_t yyinname;

char NewCDecl[] = "(defined(__STDC__) || defined(c_plusplus))";
char LintLib[] = "defined(LINTLIBRARY)";

void
init_global()
{
    yyinname = strmake("<no name yet>");
}

string_t HeaderFileName = strNULL;
string_t UserFileName   = strNULL;
string_t ServerFileName = strNULL;
#if	NeXT
string_t ServerHeaderFileName = strNULL;
#endif	NeXT

identifier_t SetMsgTypeName;
identifier_t ReplyPortName;
identifier_t ReplyPortIsOursName;
identifier_t MsgTypeVarName;
identifier_t DeallocPortRoutineName;
identifier_t AllocPortRoutineName;
identifier_t ServerProcName;

void
more_global()
{
    if (SubsystemName == strNULL)
	fatal("no SubSystem declaration");

    if (HeaderFileName == strNULL)
	HeaderFileName = strconcat(SubsystemName, ".h");
    else if (streql(HeaderFileName, "/dev/null"))
	HeaderFileName = strNULL;

    if (UserFileName == strNULL)
	UserFileName = strconcat(SubsystemName, "User.c");
    else if (streql(UserFileName, "/dev/null"))
	UserFileName = strNULL;

    if (ServerFileName == strNULL)
	ServerFileName = strconcat(SubsystemName, "Server.c");
    else if (streql(ServerFileName, "/dev/null"))
	ServerFileName = strNULL;

    SetMsgTypeName = strconcat("set_msg_type_", SubsystemName);
    MsgTypeVarName = strconcat("msg_type_var_", SubsystemName);
    ReplyPortName = strconcat(SubsystemName, "_reply_port");
    ReplyPortIsOursName = strconcat(ReplyPortName, "_is_ours");
    DeallocPortRoutineName = strconcat(ReplyPortName, "_dealloc");
    AllocPortRoutineName = strconcat(ReplyPortName, "_alloc");

#if	NeXT
    if (GenHandler) {
	ServerProcName = strconcat(SubsystemName, "_handler");
	if (ServerHeaderFileName == strNULL)
	    ServerHeaderFileName = strconcat(SubsystemName, "_handler.h");
	else if (streql(ServerHeaderFileName, "/dev/null"))
	    ServerHeaderFileName = strNULL;
    } else
#endif	NeXT
    ServerProcName = strconcat(SubsystemName, "_server");
}
