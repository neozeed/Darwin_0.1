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
/***************************************************************
 *  ABSTRACT:
 *   Provides the routine used by parser.c to generate
 *   routine structures for each routine statement.
 *   The parser generates a threaded list of statements
 *   of which the most interesting are the various kinds
 *   routine statments. The routine structure is defined
 *   in routine.h which includes it name, kind of routine
 *   and other information,
 *   a pointer to an argument list which contains the name
 *   and type information for each argument, and a list
 *   of distinguished arguments, eg.  Request and Reply
 *   ports, waittime, retcode etc.
 *
 *	$Header: /CVSRoot/CoreOS/Commands/NeXT/bootstrap_cmds/migcom.tproj/routine.c,v 1.1.1.1.8.2 1999/03/16 16:12:00 wsanchez Exp $
 *
 * HISTORY
 *  4-Sep-91  Gregg Kellogg (gk) at NeXT
 *	Added SendTime to operate like WaitTime.
 *
 * 07-Apr-89  Richard Draves (rpd) at Carnegie-Mellon University
 *	Extensive revamping.  Added polymorphic arguments.
 *	Allow multiple variable-sized inline arguments in messages.
 *
 * 17-Oct-88  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Added to code to rtAugmentArgKind to reject any inline
 *	variable arguments that are both In and Out.
 *
 * 27-Feb-88  Richard Draves (rpd) at Carnegie-Mellon University
 *	Added warning messages.  CamelotRoutines should only be
 *	used in camelot subsystems, which should consist entirely
 *	of CamelotRoutines.
 *
 * 18-Feb-88  Richard Draves (rpd) at Carnegie-Mellon University
 *	Fix to rtCheckRoutineArgs, so we don't seg-fault on bad input.
 *	We want to do some checking for malformed args after an error,
 *	but nothing that has to use their type (which is NULL).
 *
 * 20-Dec-87  David Golub (dbg) at Carnegie-Mellon University
 *	Fill in pointers to last request and reply arguments.  Implement
 *	partial variable-length messages - only the last inline argument
 *	in a message can vary in size.  Added argMultiplier field for
 *	count arguments.
 *
 * 16-Nov-87  David Golub (dbg) at Carnegie-Mellon University
 *	Don't add akbVarNeeded attribute here - server.c can
 *	better determine whether it is needed.
 *
 * 25-Aug-87  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Changed CamelotPrefix from a UserPrefix to a ServerPrefix.
 *
 * 18-Aug-87  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Added code to add requestPort, Tid and WaitTime 
 *	arguments for CamelotRoutines.
 *
 * 10-Aug-87  Mary Thompson (mrt) at Carnegie-Mellon University
 *	Added code to handle MsgType arguments
 *
 * 15-Jun-87  David Black (dlb) at Carnegie-Mellon University
 *	Fixed rtAlloc and argAlloc to correctly initialize string
 *	pointers in allocated structures.
 *
 * 28-May-87  Richard Draves (rpd) at Carnegie-Mellon University
 *	Created.
 ******************************************************/

#include <mach/message.h>
#include "error.h"
#include "alloc.h"
#include "global.h"
#include "routine.h"

u_int rtNumber = 0;

routine_t *
rtAlloc()
{
    register routine_t *new;

    new = (routine_t *) calloc(1, sizeof *new);
    if (new == rtNULL)
	fatal("rtAlloc(): %s", unix_error_string(errno));
    new->rtNumber = rtNumber++;
    new->rtName = strNULL;
    new->rtErrorName = strNULL;
    new->rtUserName = strNULL;
    new->rtServerName = strNULL;

    return new;
}

void
rtSkip()
{
    rtNumber++;
}

argument_t *
argAlloc()
{
    static argument_t prototype =
    {
	strNULL,		/* identifier_t argName */
	argNULL,		/* argument_t *argNext */
	akNone,			/* arg_kind_t argKind */
	itNULL,			/* ipc_type_t *argType */
	strNULL,		/* string_t argVarName */
	strNULL,		/* string_t argMsgField */
	strNULL,		/* string_t argTTName */
	strNULL,		/* string_t argPadName */
	flNone,			/* ipc_flags_t argFlags */
	FALSE,			/* boolean_t argDeallocate */
	FALSE,			/* boolean_t argLongForm */
	rtNULL,			/* routine_t *argRoutine */
	argNULL,		/* argument_t *argCount */
	argNULL,		/* argument_t *argPoly */
	argNULL,		/* argument_t *argParent */
	1,			/* int argMultiplier */
	0,			/* int argRequestPos */
	0,			/* int argReplyPos */
	0			/* int argPuntNum */
    };
    register argument_t *new;

    new = (argument_t *) malloc(sizeof *new);
    if (new == argNULL)
	fatal("argAlloc(): %s", unix_error_string(errno));
    *new = prototype;
    return new;
}

routine_t *
rtMakeRoutine(name, args)
    identifier_t name;
    argument_t *args;
{
    register routine_t *rt = rtAlloc();

    rt->rtName = name;
    rt->rtKind = rkRoutine;
    rt->rtArgs = args;

    if (IsCamelot)
	warn("camelot subsystems should only contain CamelotRoutines");

    return rt;
}

routine_t *
rtMakeSimpleRoutine(name, args)
    identifier_t name;
    argument_t *args;
{
    register routine_t *rt = rtAlloc();

    rt->rtName = name;
    rt->rtKind = rkSimpleRoutine;
    rt->rtArgs = args;

    if (IsCamelot)
	warn("camelot subsystems should only contain CamelotRoutines");

    return rt;
}

routine_t *
rtMakeCamelotRoutine(name, args)
    identifier_t name;
    argument_t *args;
{
    register routine_t *rt = rtAlloc();

    rt->rtName = name;
    rt->rtKind = rkCamelotRoutine;
    rt->rtArgs = args;

    if (!IsCamelot)
    {
	warn("CamelotRoutine used; assuming camelot subsystem");
	IsCamelot = TRUE;
    }

    return rt;
}

routine_t *
rtMakeProcedure(name, args)
    identifier_t name;
    argument_t *args;
{
    register routine_t *rt = rtAlloc();

    rt->rtName = name;
    rt->rtKind = rkProcedure;
    rt->rtArgs = args;

    if (IsCamelot)
	warn("camelot subsystems should only contain CamelotRoutines");

    return rt;
}

routine_t *
rtMakeSimpleProcedure(name, args)
    identifier_t name;
    argument_t *args;
{
    register routine_t *rt = rtAlloc();

    rt->rtName = name;
    rt->rtKind = rkSimpleProcedure;
    rt->rtArgs = args;

    if (IsCamelot)
	warn("camelot subsystems should only contain CamelotRoutines");

    return rt;
}

routine_t *
rtMakeFunction(name, args, type)
    identifier_t name;
    argument_t *args;
    ipc_type_t *type;
{
    register routine_t *rt = rtAlloc();
    register argument_t *ret = argAlloc();

    ret->argName = name;
    ret->argKind = akReturn;
    ret->argType = type;
    ret->argNext = args;

    rt->rtName = name;
    rt->rtKind = rkFunction;
    rt->rtArgs = ret;

    if (IsCamelot)
	warn("camelot subsystems should only contain CamelotRoutines");

    return rt;
}

char *
rtRoutineKindToStr(rk)
    routine_kind_t rk;
{
    switch (rk)
    {
      case rkRoutine:
	return "Routine";
      case rkSimpleRoutine:
	return "SimpleRoutine";
      case rkCamelotRoutine:
	return "CamelotRoutine";
      case rkProcedure:
	return "Procedure";
      case rkSimpleProcedure:
	return "SimpleProcedure";
      case rkFunction:
	return "Function";
      default:
	fatal("rtRoutineKindToStr(%d): not a routine_kind_t", rk);
	/*NOTREACHED*/
    }
}

static void
rtPrintArg(arg)
    register argument_t *arg;
{
    register ipc_type_t *it = arg->argType;

    if (!akCheck(arg->argKind, akbUserArg|akbServerArg) ||
	(akIdent(arg->argKind) == akeCount) ||
	(akIdent(arg->argKind) == akePoly))
	return;

    printf("\n\t");

    switch (akIdent(arg->argKind))
    {
      case akeRequestPort:
	printf("RequestPort");
	break;
      case akeReplyPort:
	printf("ReplyPort");
	break;
      case akeWaitTime:
	printf("WaitTime");
	break;
#if	NeXT
      case akeSendTime:
	printf("SendTime");
	break;
#endif	NeXT
      case akeMsgType:
	printf("MsgType\t");
	break;
      default:
	if (akCheck(arg->argKind, akbRequest))
	    if (akCheck(arg->argKind, akbSend))
		printf("In");
	    else
		printf("(In)");
	if (akCheck(arg->argKind, akbReply))
	    if (akCheck(arg->argKind, akbReturn))
		printf("Out");
	    else
		printf("(Out)");
	printf("\t");
    }

    printf("\t%s: %s", arg->argName, it->itName);

    if (arg->argDeallocate != it->itDeallocate)
	if (arg->argDeallocate)
	    printf(", Dealloc");
	else
	    printf(", NotDealloc");
    if (arg->argLongForm != it->itLongForm)
	if (arg->argLongForm)
	    printf(", IsLong");
	else
	    printf(", IsNotLong");
}

void
rtPrintRoutine(rt)
    register routine_t *rt;
{
    register argument_t *arg;

    printf("%s (%d) %s(", rtRoutineKindToStr(rt->rtKind),
	   rt->rtNumber, rt->rtName);

    for (arg = rt->rtArgs; arg != argNULL; arg = arg->argNext)
	rtPrintArg(arg);

    if (rt->rtKind == rkFunction)
	printf("): %s\n", rt->rtReturn->argType->itName);
    else
	printf(")\n");

    printf("\n");
}

/*
 * Determines the value of msg_simple to be used when sending
 * a message.  Note that if there are polymorphic-in args,
 * then we conservatively assume the message isn't simple.
 * It isn't worth being fancier than this (like determining
 * the value of msg_simple at runtime) because in practice
 * polymorphic args are only used with ports.
 */

static boolean_t
rtCheckSimpleSend(args, mask)
    argument_t *args;
    u_int mask;
{
    register argument_t *arg;

    for (arg = args; arg != argNULL; arg = arg->argNext)
	if (akCheck(arg->argKind, mask))
	{
	    register ipc_type_t *it = arg->argType;

	    if ((it->itInName == MSG_TYPE_POLYMORPHIC) ||
		MSG_TYPE_PORT_ANY(it->itInName) ||
		!it->itInLine)
		return FALSE;
	}
    return TRUE;
}

/*
 * Determines the value of msg_simple we expect to see
 * in a received message.  If there are polymorphic-out args
 * but no port/pointer args, then we don't know what value
 * to expect.  If there are port/pointer args, it is very important
 * to check that the message isn't simple.  (If it is, we in fact
 * haven't received ports/memory, although the type-checking for
 * those arguments may still deceptively succeed.)  Therefore,
 * when type-checking a polymorphic-out arg in a message without a
 * definite msg-simple value, we need to check msg-simple after
 * looking at that arg's msg-type-name.
 */

static void
rtCheckSimpleReceive(args, mask, docheck, simple)
    argument_t *args;
    u_int mask;
    boolean_t *docheck, *simple;
{
    register argument_t *arg;
    boolean_t MayBeComplex = FALSE;
    boolean_t MustBeComplex = FALSE;

    for (arg = args; arg != argNULL; arg = arg->argNext)
	if (akCheck(arg->argKind, mask))
	{
	    register ipc_type_t *it = arg->argType;

	    if (it->itOutName == MSG_TYPE_POLYMORPHIC)
		MayBeComplex = TRUE;

	    if (MSG_TYPE_PORT_ANY(it->itOutName) ||
		!it->itInLine)
		MustBeComplex = TRUE;
	}

    if (*docheck = MustBeComplex || !MayBeComplex)
	*simple = !MustBeComplex;
}

static u_int
rtFindSize(args, mask)
    argument_t *args;
    u_int mask;
{
    register argument_t *arg;
    u_int size = sizeof(msg_header_t);

    for (arg = args; arg != argNULL; arg = arg->argNext)
	if (akCheck(arg->argKind, mask))
	{
	    register ipc_type_t *it = arg->argType;

	    if (arg->argLongForm)
		size += sizeof(msg_type_long_t);
	    else
		size += sizeof(msg_type_t);

	    size += it->itMinTypeSize;
	}

    return size;
}

#if	NeXT
static u_int
rtFindMaxSize(args, mask)
    argument_t *args;
    u_int mask;
{
    register argument_t *arg;
    u_int size = sizeof(msg_header_t);

    for (arg = args; arg != argNULL; arg = arg->argNext)
	if (akCheck(arg->argKind, mask))
	{
	    register ipc_type_t *it = arg->argType;

	    if (arg->argLongForm)
		size += sizeof(msg_type_long_t);
	    else
		size += sizeof(msg_type_t);

	    if (it->itVarArray) {
		if (it->itTypeSize == 0)
		    size = MSG_SIZE_MAX;
		else
		    size += (it->itTypeSize + it->itPadSize);
	    } else
		size += it->itMinTypeSize;
	}

    return size;
}
#endif	NeXT

boolean_t
rtCheckMask(args, mask)
    argument_t *args;
    u_int mask;
{
    register argument_t *arg;

    for (arg = args; arg != argNULL; arg = arg->argNext)
	if (akCheckAll(arg->argKind, mask))
	    return TRUE;
    return FALSE;
}

/* arg->argType may be NULL in this function */

static void
rtDefaultArgKind(rt, arg)
    routine_t *rt;
    argument_t *arg;
{
    if ((arg->argKind == akNone) &&
	(rt->rtRequestPort == argNULL))
	arg->argKind = akRequestPort;

    if (arg->argKind == akNone)
	arg->argKind = akIn;
}

/*
 * Initializes arg->argDeallocate and arg->argLongForm.
 */

static void
rtProcessArgFlags(arg)
    register argument_t *arg;
{
    register ipc_type_t *it = arg->argType;

    if ((arg->argFlags&(flLong|flNotLong)) == (flLong|flNotLong))
    {
	warn("%s: IsLong and IsNotLong cancel out", arg->argName);
	arg->argFlags &= ~(flLong|flNotLong);
    }

    if (arg->argFlags&flLong)
    {
	if (it->itLongForm)
	    warn("%s: IsLong on argument is redundant", arg->argName);
	arg->argLongForm = TRUE;
    }
    else if (arg->argFlags&flNotLong)
    {
	if (!it->itLongForm)
	    warn("%s: IsNotLong on argument is redundant", arg->argName);
	arg->argLongForm = FALSE;
    }
    else
	arg->argLongForm = it->itLongForm;


    if ((arg->argFlags&(flDealloc|flNotDealloc)) == (flDealloc|flNotDealloc))
    {
	warn("%s: Dealloc and NotDealloc cancel out", arg->argName);
	arg->argFlags &= ~(flDealloc|flNotDealloc);
    }

    if (arg->argFlags&flDealloc)
    {
	if (it->itDeallocate)
	    warn("%s: Dealloc on argument is redundant", arg->argName);
	arg->argDeallocate = TRUE;
    }
    else if (arg->argFlags&flNotDealloc)
    {
	if (!it->itDeallocate)
	    warn("%s: NotDealloc on argument is redundant", arg->argName);
	arg->argDeallocate = FALSE;
    }
    else
	arg->argDeallocate = it->itDeallocate;
}

static void
rtAugmentArgKind(arg)
    argument_t *arg;
{
    register ipc_type_t *it = arg->argType;

    /* akbVariable means variable-sized inline. */

    if (it->itVarArray && it->itInLine)
    {
	if (akCheckAll(arg->argKind, akbRequest|akbReply))
	    error("%s: Inline variable-sized arguments can't be InOut",
		  arg->argName);
	arg->argKind = akAddFeature(arg->argKind, akbVariable);
    }

    if (akCheck(arg->argKind, akbRequest|akbReply) &&
	!arg->argLongForm &&
	(it->itOutName != MSG_TYPE_POLYMORPHIC) &&
	!it->itVarArray)
	arg->argKind = akAddFeature(arg->argKind, akbQuickCheck);
	
    /*
     * Need to use a local variable in the following cases:
     *	1) There is a translate-out function & the argument is being
     *	   returned.  We need to translate it before it hits the message.
     *	2) There is a translate-in function & the argument is
     *	   sent and returned.  We need a local variable for its address.
     *	3) There is a destructor function, which will be used
     *	   (SendRcv and not ReturnSnd), and there is a translate-in
     *	   function whose value must be saved for the destructor.
     *	4) This is a count arg, getting returned.  The count can't get
     *	   stored directly into the msg-type, because the msg-type won't
     *	   get initialized until later, and that would trash the count.
     *	5) This is a poly arg, getting returned.  The name can't get
     *	   stored directly into the msg-type, because the msg-type won't
     *	   get initialized until later, and that would trash the name.
     */

    if (((it->itOutTrans != strNULL) &&
	 akCheck(arg->argKind, akbReturnSnd)) ||
	((it->itInTrans != strNULL) &&
	 akCheckAll(arg->argKind, akbSendRcv|akbReturnSnd)) ||
	((it->itDestructor != strNULL) &&
	 akCheck(arg->argKind, akbSendRcv) &&
	 !akCheck(arg->argKind, akbReturnSnd) &&
	 (it->itInTrans != strNULL)) ||
	((akIdent(arg->argKind) == akeCount) &&
	 akCheck(arg->argKind, akbReturnSnd)) ||
	((akIdent(arg->argKind) == akePoly) &&
	 akCheck(arg->argKind, akbReturnSnd)))
    {
	arg->argKind = akRemFeature(arg->argKind, akbReplyCopy);
	arg->argKind = akAddFeature(arg->argKind, akbVarNeeded);
    }
}

/* arg->argType may be NULL in this function */

static void
rtCheckRoutineArg(rt, arg)
    routine_t *rt;
    argument_t *arg;
{
    switch (akIdent(arg->argKind))
    {
      case akeRequestPort:
	if (rt->rtRequestPort != argNULL)
	    warn("multiple RequestPort args in %s; %s won't be used",
		 rt->rtName, rt->rtRequestPort->argName);
	rt->rtRequestPort = arg;
	break;

      case akeReplyPort:
	if (rt->rtReplyPort != argNULL)
	    warn("multiple ReplyPort args in %s; %s won't be used",
		 rt->rtName, rt->rtReplyPort->argName);
	rt->rtReplyPort = arg;
	break;

      case akeWaitTime:
	if (rt->rtWaitTime != argNULL)
	    warn("multiple WaitTime args in %s; %s won't be used",
		 rt->rtName, rt->rtWaitTime->argName);
	rt->rtWaitTime = arg;
	break;

#if	NeXT
      case akeSendTime:
	if (rt->rtSendTime != argNULL)
	    warn("multiple SendTime args in %s; %s won't be used",
		 rt->rtName, rt->rtSendTime->argName);
	rt->rtSendTime = arg;
	break;
#endif	NeXT

      case akeMsgType:
	if (rt->rtMsgType != argNULL)
	    warn("multiple MsgType args in %s; %s won't be used",
		 rt->rtName, rt->rtMsgType->argName);
	rt->rtMsgType = arg;
	break;

      case akeReturn:
	if (rt->rtReturn != argNULL)
	    warn("multiple Return args in %s; %s won't be used",
		 rt->rtName, rt->rtReturn->argName);
	rt->rtReturn = arg;
	break;

      default:
	break;
    }
}

/* arg->argType may be NULL in this function */

static void
rtSetArgDefaults(rt, arg)
    routine_t *rt;
    register argument_t *arg;
{
    arg->argRoutine = rt;
    if (arg->argVarName == strNULL)
	arg->argVarName = arg->argName;
    if (arg->argMsgField == strNULL)
	switch(akIdent(arg->argKind))
	{
	  case akeRequestPort:
	    arg->argMsgField = "Head.msg_request_port";
	    break;
	  case akeReplyPort:
	    arg->argMsgField = "Head.msg_reply_port";
	    break;
	  case akeMsgType:
	    arg->argMsgField = "Head.msg_type";
	    break;
	  default:
	    arg->argMsgField = arg->argName;
	    break;
	}
    if (arg->argTTName == strNULL)
	arg->argTTName = strconcat(arg->argName, "Type");
    if (arg->argPadName == strNULL)
	arg->argPadName = strconcat(arg->argName, "Pad");
}

static void
rtAddCountArg(arg)
    register argument_t *arg;
{
    register argument_t *count;

    count = argAlloc();
    count->argName = strconcat(arg->argName, "Cnt");
    count->argType = itMakeCountType();
    count->argParent = arg;
    count->argMultiplier = arg->argType->itElement->itNumber;
    count->argNext = arg->argNext;
    arg->argNext = count;
    arg->argCount = count;

    count->argKind = akAddFeature(akCount,
				  akCheck(arg->argKind, akbSendReturnBits));

    if (arg->argLongForm)
	count->argMsgField = strconcat(arg->argTTName,
				       ".msg_type_long_number");
    else
	count->argMsgField = strconcat(arg->argTTName, ".msg_type_number");
}

static void
rtAddPolyArg(arg)
    register argument_t *arg;
{
    register ipc_type_t *it = arg->argType;
    register argument_t *poly;
    arg_kind_t akbsend, akbreturn;

    poly = argAlloc();
    poly->argName = strconcat(arg->argName, "Poly");
    poly->argType = itMakePolyType();
    poly->argParent = arg;
    poly->argNext = arg->argNext;
    arg->argNext = poly;
    arg->argPoly = poly;

    akbsend = akbSend|akbSendBody;
    akbreturn = akbReturn|akbReturnBody;

    if (it->itInName == MSG_TYPE_POLYMORPHIC)
    {
	akbsend |= akbUserArg|akbSendSnd;
	akbreturn |= akbServerArg|akbReturnSnd;
    }
    if (it->itOutName == MSG_TYPE_POLYMORPHIC)
    {
	akbsend |= akbServerArg|akbSendRcv;
	akbreturn |= akbUserArg|akbReturnRcv;
    }

    poly->argKind = akPoly;
    if (akCheck(arg->argKind, akbSend))
	poly->argKind = akAddFeature(poly->argKind,
				     akCheck(arg->argKind, akbsend));
    if (akCheck(arg->argKind, akbReturn))
	poly->argKind = akAddFeature(poly->argKind,
				     akCheck(arg->argKind, akbreturn));

    if (arg->argLongForm)
	poly->argMsgField = strconcat(arg->argTTName,
				      ".msg_type_long_name");
    else
	poly->argMsgField = strconcat(arg->argTTName, ".msg_type_name");
}

static void
rtCheckRoutineArgs(rt)
    routine_t *rt;
{
    register argument_t *arg;

    for (arg = rt->rtArgs; arg != argNULL; arg = arg->argNext)
    {
	register ipc_type_t *it = arg->argType;

	rtDefaultArgKind(rt, arg);
	rtCheckRoutineArg(rt, arg);

	/* need to set argTTName before adding implicit args */
	rtSetArgDefaults(rt, arg);

	/* the arg may not have a type (if there was some error in parsing it),
	   in which case we don't want to do these steps. */

	if (it != itNULL)
	{
	    /* need to set argLongForm before adding implicit args */
	    rtProcessArgFlags(arg);
	    rtAugmentArgKind(arg);

	    /* args added here will get processed in later iterations */

	    if (it->itVarArray)
		rtAddCountArg(arg);
	    if ((it->itInName == MSG_TYPE_POLYMORPHIC) ||
		(it->itOutName == MSG_TYPE_POLYMORPHIC))
		rtAddPolyArg(arg);
	}
    }
}

static void
rtCheckArgTypes(rt)
    routine_t *rt;
{
    if (rt->rtRequestPort == argNULL)
	error("%s %s doesn't have a server port argument",
	      rtRoutineKindToStr(rt->rtKind), rt->rtName);

    if ((rt->rtKind == rkFunction) &&
	(rt->rtReturn == argNULL))
	error("Function %s doesn't have a return arg", rt->rtName);

    if ((rt->rtKind != rkFunction) &&
	(rt->rtReturn != argNULL))
	error("non-function %s has a return arg", rt->rtName);

    if ((rt->rtReturn == argNULL) && !rt->rtProcedure)
	rt->rtReturn = rt->rtRetCode;

    if (rt->rtKind == rkCamelotRoutine)
	rt->rtServerReturn = argNULL;
    else
	rt->rtServerReturn = rt->rtReturn;


    if ((rt->rtReturn != argNULL) &&
	(rt->rtReturn->argType != itNULL))
	itCheckReturnType(rt->rtReturn->argName,
			  rt->rtReturn->argType);

    if ((rt->rtRequestPort != argNULL) &&
	(rt->rtRequestPort->argType != itNULL))
	itCheckPortType(rt->rtRequestPort->argName,
			rt->rtRequestPort->argType);

    if ((rt->rtReplyPort != argNULL) &&
	(rt->rtReplyPort->argType != itNULL))
	itCheckPortType(rt->rtReplyPort->argName,
			rt->rtReplyPort->argType);

    if ((rt->rtWaitTime != argNULL) &&
	(rt->rtWaitTime->argType != itNULL))
	itCheckIntType(rt->rtWaitTime->argName,
		       rt->rtWaitTime->argType);

#if	NeXT
    if ((rt->rtSendTime != argNULL) &&
	(rt->rtSendTime->argType != itNULL))
	itCheckIntType(rt->rtSendTime->argName,
		       rt->rtSendTime->argType);
#endif	NeXT

    if ((rt->rtMsgType != argNULL) &&
	(rt->rtMsgType->argType != itNULL))
	itCheckIntType(rt->rtMsgType->argName,
		       rt->rtMsgType->argType);
}

/*
 * Check for arguments which are missing seemingly needed functions.
 * We make this check here instead of in itCheckDecl, because here
 * we can take into account what kind of argument the type is
 * being used with.
 *
 * These are warnings, not hard errors, because mig will generate
 * reasonable code in any case.  The generated code will work fine
 * if the ServerType and TransType are really the same, even though
 * they have different names.
 */

static void
rtCheckArgTrans(rt)
    routine_t *rt;
{
    register argument_t *arg;

    /* the arg may not have a type (if there was some error in parsing it) */

    for (arg = rt->rtArgs; arg != argNULL; arg = arg->argNext)
    {
	register ipc_type_t *it = arg->argType;

	if ((it != itNULL) &&
	    !streql(it->itServerType, it->itTransType))
	{
	    if (akCheck(arg->argKind, akbSendRcv) &&
		(it->itInTrans == strNULL))
		warn("%s: argument has no in-translation function",
		     arg->argName);

	    if (akCheck(arg->argKind, akbReturnSnd) &&
		(it->itOutTrans == strNULL))
		warn("%s: argument has no out-translation function",
		     arg->argName);
	}
    }
}

/*
 * Adds an implicit return-code argument.  It exists in the reply message,
 * where it is the first piece of data.  Even if there is no reply
 * message (rtOneWay is true), we generate the argument because
 * the server-side stub needs a dummy reply msg to return error codes
 * back to the server loop.
 */

static void
rtAddRetCode(rt)
    routine_t *rt;
{
    register argument_t *arg = argAlloc();

    arg->argName = "RetCode";
    arg->argType = itRetCodeType;
    arg->argKind = akRetCode;
    rt->rtRetCode = arg;

    /* add at beginning, so return-code is first in the reply message  */
    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;
}

/*
 *  Adds five implicit arguments to a CamelotRoutine.  In order,
 *	RequestPort	(not passed to server function)
 *	RetCode		(in request msg as well as reply)
 *	Dummy		(in msgs only, reserves space for ComMan)
 *	Tid		(in msgs, but not passed to server or back to user)
 *	WaitTime	(passed in by user, as normal)
 *
 *  So the user C args look like (RequestPort, Tid, WaitTime, Normal),
 *  the server C args look like (Normal),
 *  the request message looks like (RetCode, Dummy, Tid, Normal),
 *  and the reply message looks like (RetCode, Dummy, Tid, Normal).
 */

static void
rtAddCamelotArgs(rt)
    register routine_t *rt;
{
    register argument_t *arg;

    arg = argAlloc();
    arg->argName = "WaitTime";
    arg->argType = itWaitTimeType;
    arg->argKind = akWaitTime;
    /* rtCheckRoutineArg will set rt->rtWaitTime */

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    arg = argAlloc();
    arg->argName = "Tid";
    arg->argType = itTidType;
    arg->argKind = akTid;

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    arg = argAlloc();
    arg->argName = "Dummy";
    arg->argType = itDummyType;
    arg->argKind = akDummy;

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    arg = argAlloc();
    arg->argName = "RetCode";
    arg->argType = itRetCodeType;
    arg->argKind = akAddFeature(akRetCode, akbRequest);
    rt->rtRetCode = arg;

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    arg = argAlloc();
    arg->argName = "ServerPort";
    arg->argType = itPortType;
    arg->argKind = akRemFeature(akRequestPort, akbServerArg);
    /* rtCheckRoutineArg will set rt->rtRequestPort */

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;
}

/*
 *  Adds a dummy WaitTime argument to the function.
 *  This argument doesn't show up in any C argument lists;
 *  it implements the global WaitTime statement.
 */

static void
rtAddWaitTime(rt, name)
    routine_t *rt;
    identifier_t name;
{
    register argument_t *arg = argAlloc();

    arg->argName = "dummy WaitTime arg";
    arg->argVarName = name;
    arg->argType = itWaitTimeType;
    arg->argKind = akeWaitTime;
    rt->rtWaitTime = arg;

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    rtSetArgDefaults(rt, arg);
}

#if	NeXT
/*
 *  Adds a dummy SendTime argument to the function.
 *  This argument doesn't show up in any C argument lists;
 *  it implements the global SendTime statement.
 */

static void
rtAddSendTime(rt, name)
    routine_t *rt;
    identifier_t name;
{
    register argument_t *arg = argAlloc();

    arg->argName = "dummy SendTime arg";
    arg->argVarName = name;
    arg->argType = itWaitTimeType;
    arg->argKind = akeSendTime;
    rt->rtSendTime = arg;

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    rtSetArgDefaults(rt, arg);
}
#endif	NeXT

/*
 *  Adds a dummy MsgType argument to the function.
 *  This argument doesn't show up in any C argument lists;
 *  it implements the global MsgType statement.
 */

static void
rtAddMsgType(rt, name)
    routine_t *rt;
    identifier_t name;
{
    register argument_t *arg = argAlloc();

    arg->argName = "dummy MsgType arg";
    arg->argVarName = name;
    arg->argType = itMsgTypeType;
    arg->argKind = akeMsgType;
    rt->rtMsgType = arg;

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    rtSetArgDefaults(rt, arg);
}

/*
 *
 *  Adds a dummy reply port argument to the function.
 *  This argument doesn't show up in any C argument lists;
 *  it implements the default (Mig supplied) reply port.
 */

static void
rtAddReplyPort(rt, name)
    routine_t *rt;
    identifier_t name;
{
    register argument_t *arg = argAlloc();

    arg->argName = "dummy ReplyPort arg";
    arg->argVarName = name;
    arg->argType = itPortType;
    arg->argKind = akeReplyPort;
    rt->rtReplyPort = arg;

    arg->argNext = rt->rtArgs;
    rt->rtArgs = arg;

    rtSetArgDefaults(rt, arg);
}

/*
 * Initializes argRequestPos, argReplyPos, rtMaxRequestPos, rtMaxReplyPos,
 * rtNumRequestVar, rtNumReplyVar, and adds akbVarNeeded to those arguments
 * that need it because of variable-sized inline considerations.
 *
 * argRequestPos and argReplyPos get -1 if the value shouldn't be used.
 */
static void
rtCheckVariable(rt)
    register routine_t *rt;
{
    register argument_t *arg;
    int NumRequestVar = 0;
    int NumReplyVar = 0;
    int MaxRequestPos;
    int MaxReplyPos;

    for (arg = rt->rtArgs; arg != argNULL; arg = arg->argNext)
    {
	register argument_t *parent = arg->argParent;

	if (parent == argNULL)
	{
	    if (akCheck(arg->argKind, akbRequest|akbSend))
	    {
		arg->argRequestPos = NumRequestVar;
		MaxRequestPos = NumRequestVar;
		if (akCheck(arg->argKind, akbVariable))
		    NumRequestVar++;
	    }
	    else
		arg->argRequestPos = -1;

	    if (akCheck(arg->argKind, akbReply|akbReturn))
	    {
		arg->argReplyPos = NumReplyVar;
		MaxReplyPos = NumReplyVar;
		if (akCheck(arg->argKind, akbVariable))
		    NumReplyVar++;
	    }
	    else
		arg->argReplyPos = -1;
	}
	else
	{
	    arg->argRequestPos = parent->argRequestPos;
	    arg->argReplyPos = parent->argReplyPos;
	}

	/* Out variables that follow a variable-sized field
	   need VarNeeded or ReplyCopy; they can't be stored
	   directly into the reply message. */

	if (akCheck(arg->argKind, akbReturnSnd) &&
	    !akCheck(arg->argKind, akbReplyCopy|akbVarNeeded) &&
	    (arg->argReplyPos > 0))
	    arg->argKind = akAddFeature(arg->argKind, akbVarNeeded);
    }

    rt->rtNumRequestVar = NumRequestVar;
    rt->rtNumReplyVar = NumReplyVar;
    rt->rtMaxRequestPos = MaxRequestPos;
    rt->rtMaxReplyPos = MaxReplyPos;
}

/*
 * Initializes argPuntNum and adds akbDestroy where needed.
 */

static void
rtCheckDestroy(rt)
    register routine_t *rt;
{
    register argument_t *arg;
    int PuntNum = 0;

    for (arg = rt->rtArgs; arg != argNULL; arg = arg->argNext)
    {
	register ipc_type_t *it = arg->argType;

	arg->argPuntNum = PuntNum;

	if(akCheck(arg->argKind, akbSendRcv) &&
	   !akCheck(arg->argKind, akbReturnSnd) &&
	   (it->itDestructor != strNULL))
	{
	    arg->argKind = akAddFeature(arg->argKind, akbDestroy);
	    PuntNum++;
	}
    }
}

void
rtCheckRoutine(rt)
    register routine_t *rt;
{
#if	NeXT
#else	NeXT
    if ((rt->rtKind == rkSimpleProcedure) ||
	(rt->rtKind == rkProcedure) ||
	(rt->rtKind == rkFunction))
	warn("%s %s: obsolete routine kind",
	     rtRoutineKindToStr(rt->rtKind), rt->rtName);
#endif	NeXT

    /* Initialize random fields. */

    rt->rtErrorName = ErrorProc;
    rt->rtOneWay = ((rt->rtKind == rkSimpleProcedure) ||
		    (rt->rtKind == rkSimpleRoutine));
    rt->rtProcedure = ((rt->rtKind == rkProcedure) ||
		       (rt->rtKind == rkSimpleProcedure));
    rt->rtUseError = rt->rtProcedure || (rt->rtKind == rkFunction);
    if (rt->rtKind == rkCamelotRoutine)
	rt->rtServerName = strconcat(CamelotPrefix, rt->rtName);
    else
	rt->rtServerName = strconcat(ServerPrefix, rt->rtName);
    rt->rtUserName = strconcat(UserPrefix, rt->rtName);

    /* Add implicit arguments. */

    if (rt->rtKind == rkCamelotRoutine)
	rtAddCamelotArgs(rt);
    else
	rtAddRetCode(rt);

    /* Check out the arguments and their types.  Add count, poly
       implicit args.  Any arguments added after rtCheckRoutineArgs
       should have rtSetArgDefaults called on them. */

    rtCheckRoutineArgs(rt);

    /* Add dummy WaitTime, SendTime and MsgType arguments, if the routine
       doesn't have its own args and the user specified global values. */

    if ((rt->rtWaitTime == argNULL) &&
	(WaitTime != strNULL))
	rtAddWaitTime(rt, WaitTime);

#if	NeXT
    if ((rt->rtSendTime == argNULL) &&
	(SendTime != strNULL))
	rtAddSendTime(rt, SendTime);
#endif	NeXT

    if (rt->rtMsgType == argNULL)
	if (MsgType == strNULL)
	    rtAddMsgType(rt, "MSG_TYPE_NORMAL");
	else
	    rtAddMsgType(rt, MsgType);

    if (rt->rtReplyPort == argNULL)
	if (rt->rtOneWay)
	    rtAddReplyPort(rt, "PORT_NULL");
	else
	    rtAddReplyPort(rt, "mig_get_reply_port()");

    /* Now that all the arguments are in place, do more checking. */

    rtCheckArgTypes(rt);
    rtCheckArgTrans(rt);

    if (rt->rtOneWay && rtCheckMask(rt->rtArgs, akbReturn))
	error("%s %s has OUT argument",
	      rtRoutineKindToStr(rt->rtKind), rt->rtName);

    /* If there were any errors, don't bother calculating more info
       that is only used in code generation anyway.  Therefore,
       the following functions don't have to worry about null types. */

    if (errors > 0)
	return;

    rt->rtSimpleSendRequest = rtCheckSimpleSend(rt->rtArgs, akbRequest);
    rtCheckSimpleReceive(rt->rtArgs, akbRequest,
			 &rt->rtSimpleCheckRequest,
			 &rt->rtSimpleReceiveRequest);
    rt->rtRequestSize = rtFindSize(rt->rtArgs, akbRequest);
#if	NeXT
    rt->rtMaxRequestSize = rtFindMaxSize(rt->rtArgs, akbRequest);
#endif	NeXT

    rt->rtSimpleSendReply = rtCheckSimpleSend(rt->rtArgs, akbReply);
    rtCheckSimpleReceive(rt->rtArgs, akbReply,
			 &rt->rtSimpleCheckReply,
			 &rt->rtSimpleReceiveReply);
    rt->rtReplySize = rtFindSize(rt->rtArgs, akbReply);
#if	NeXT
    rt->rtMaxReplySize = rtFindMaxSize(rt->rtArgs, akbReply);
#endif	NeXT

    rtCheckVariable(rt);
    rtCheckDestroy(rt);

    /* Add RPC, CAMELOT bits to the msg_type field when appropriate. */

    if (!rt->rtOneWay)
	rt->rtMsgType->argVarName = strconcat(rt->rtMsgType->argVarName,
					      " | MSG_TYPE_RPC");
    if (rt->rtKind == rkCamelotRoutine)
	rt->rtMsgType->argVarName = strconcat(rt->rtMsgType->argVarName,
					      " | MSG_TYPE_CAMELOT");
}
