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
#import <objc/objc-runtime.h>
#import "LUGlobal.h"
#import "LUPrivate.h"
#import "Controller.h"
#import "LUDictionary.h"
#import "LUArray.h"
#import "LUServer.h"
#import "MemoryWatchdog.h"
#import <unistd.h>
#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <sgtty.h>
#import <setjmp.h>
#import <sys/signal.h>
#import <arpa/inet.h>
#import "stringops.h"

int oldflags;
struct ltchars termc;
struct sgttyb iobasic;
jmp_buf jmpenv;

#define forever for (;;)

extern struct ether_addr *ether_aton(char *);

@interface Controller (ControllerPrivate)
- (id)agentNamed:(char *)name;
@end

@interface LUServer (LUServerPrivate)
- (LUAgent *)agentForSystem:(id)systemClass;
@end

static id askMe = nil;

void oldterm(void)
{
	ioctl(fileno(stdin),TIOCGETP,&iobasic);
	iobasic.sg_flags = oldflags; 
	ioctl(fileno(stdin),TIOCSETP,&iobasic);

	ioctl(fileno(stdin),TIOCGLTC,&termc);
	termc.t_suspc = 26;
	termc.t_dsuspc = 25;
	ioctl(fileno(stdin),TIOCSLTC,&termc);
}

void newterm(void)
{
	ioctl(fileno(stdin),TIOCGETP,&iobasic);
	oldflags = iobasic.sg_flags; 
	iobasic.sg_flags |= CBREAK; 
	iobasic.sg_flags &= ~ECHO; 
	ioctl(fileno(stdin),TIOCSETN,&iobasic);

	ioctl(fileno(stdin),TIOCGLTC,&termc);
	termc.t_suspc = -1;
	termc.t_dsuspc = -1;
	ioctl(fileno(stdin),TIOCSLTC,&termc);
}

void printlist(FILE *out, int size, int items, char **list)
{
	int rows, cols, i, j, x, y, len, n;
	char blank[256];
	
	for (i = 0; i < 256; i++) blank[i] = ' ';

	size += 1;
		
	cols = 79 / size;
	rows = items / cols;
	if (items > (rows * cols)) rows++;
	cols = items / rows;
	if (items > (rows * cols)) cols++;

	n = rows * cols;
	y = -1;
	x = 0;

	for (i = 0; i < n; i++)
	{
		if (!(i % cols))
		{
			fprintf(out, "\n");
			y++;
			x = y;
		}
		if (x < items)
		{
			len = strlen(list[x]);
			j = (size - len) + 1;
			blank[j] = '\0';
			fprintf(out, "%s%s", list[x], blank);
			blank[j] = ' ';
		}
		x += rows;
	}
}

void helpcom(FILE *out, char **w, int f, int l)
{
	int max, i, len, n;

	max = 0;
	for (i = f; i <= l; i++)
	{
		len = strlen(w[i]);
		if (len > max) max = len;
	}

	n = (l - f) + 1;

	printlist(out, max, n, w+f);
}

int try_match(FILE *out, int *f, int *l, int *s, int *p, int *n, char **clist, char *cmd)
{
	int i, k, tf, tl;
	char *fent, *lent;

	if (*p == 0) return(0);
	tf = *f; 
	tl = *l;
	k = *p + 1;
	fent = clist[tf];
	lent = clist[tl];

	for (i = *s + 1; i < k; i++)
	{
		fent = clist[tf];
		while ((tf < tl) && (strncmp(cmd, fent, i) > 0)) fent = clist[++tf];
		lent = clist[tl];
		while ((tl > tf) && (strncmp(cmd, lent, i) < 0)) lent = clist[--tl];
	}

	if (tf == tl)
	{
		if (strncmp(cmd, fent, *p) == 0)
		{
			*f = tf; *l = tl; *s = *p; *n = tf;
			return(1);
		}
		else
		{
			i = *s;
			while ((i < *p) && (cmd[i] == fent[i])) i++;
			cmd[i] = '\0';
			k = i;
			for (; i < *p; i++) printf("\b \b");
			*p = k;
			return(0);
		}
	}
	else
	{
		i = *p;
		while (fent[i] == lent[i])
		{
			cmd[i] = fent[i];
			fprintf(out, "%c", cmd[i++]);
		}
		cmd[i] = '\0';
		*f = tf; *l = tl; *p = i; *s = *p;
		return(0);
	}
}

int getcom(FILE *in, FILE *out, char **clist, int ncmd, char *prompt)
{
	int cn, first, last, match, endpt, start, i, c;
	char *entry, cmd[256];

	match = endpt = start = first = 0;
	last = ncmd - 1;
	cmd[0] = '\0';
	
	fprintf(out, "%s", prompt); 
	while (!match)
	{
		c = getc(in);

		switch(c)
		{
			case '\04': /* ^D */
			case '?':
				match = try_match(out, &first, &last, &start, &endpt, &cn, clist, cmd);
				if (!match)
				{
					fprintf(out, "\b \b");
					helpcom(out, clist, first, last);
					fprintf(out, "\n%s%s", prompt, cmd); 
				}
				else {
					entry = clist[cn];
					for (i = endpt; entry[i] != '\0'; i++) 
						fprintf(out, "%c", entry[i]);
				}
				break;

			case '\03': /* ^C */
				return(-1);

			case '\033': /* ESC */
			case ' ': /* blank */
			case '\t':  /* tab */
			case '\r': /* return */
				match = try_match(out, &first, &last, &start, &endpt, &cn, clist, cmd);
				if (match) {
					entry = clist[cn];
					for (i = endpt; entry[i] != '\0'; i++) 
						fprintf(out, "%c", entry[i]);
				}
				else fprintf(out, "%c", 7);
				break;

			case '\n': /* newline */
				match = try_match(out, &first, &last, &start, &endpt, &cn, clist, cmd);
				if (streq(clist[first], cmd)) {
					cn = first;
					match = 1;
				}
				if (!match) fprintf(out, "%c", 7);
				break;

			case '\b': /* backspace */
			case 127:	/* DEL */
				if (endpt > 0) {
					fprintf(out, "\b \b");
					endpt--;
					cmd[endpt] = '\0';
				}
				start = first = 0;
				last = ncmd - 1;
				break;

			case '\025':  /* ^U */
				for (i = 0; i < endpt; i++) fprintf(out, "\b \b");
				match = endpt = start = first = 0;
				last = ncmd - 1;
				cmd[0] = '\0';
				break;

			default: /* anything else */
				fprintf(out, "%c", c);
				cmd[endpt++] = c;
				cmd[endpt] = '\0';
				break;
		}
	}
	return(cn);
}

void put_char(FILE *out, char c)
{
	if (c > 31)
	{
		if (c == 127) fprintf(out, "^?");
		else fprintf(out, "%c", c);
	}
	else fprintf(out, "^%c", c+64);
}

char *get_string(FILE *in, FILE *out, char *prompt)
{
	char c;
	static char str[256];
	int i;

	fprintf(out, "%s", prompt);

	i = 0;
	str[i] = '\0';
	
	while ('\n' != (c = getc(in)))
	{
		switch (c)
		{
			case '\b': /* backspace */
			case 127:	/* DEL */
			if (i > 0)
			{
				if (str[i-1] < 32 || str[i-1] == 127) fprintf(out, "\b \b");
				str[--i] = '\0';
				fprintf(out, "\b \b");
				fflush(out);
			}
			break;
			case '\025':  /* ^U */
			for (i--; i > 0; i--)
			{
				if (str[i-1] < 32 || str[i-1] == 127) fprintf(out, "\b \b");
				fprintf(out, "\b \b");
			}
			str[0] = '\0';
			fflush(out);
			break;
		default:
			put_char(out, c);
			str[i++] = c;
			break;
		}
	}
	str[i] = '\0';
	return(str);
}

void printDictionary(FILE *out, LUDictionary *d)
{
	if (d == nil) fprintf(out, "nil\n");
	else [d print:out];
}

void printArray(FILE *out, LUArray *a)
{
	if (a == nil) fprintf(out, "nil\n");
	else [a print:out];
}

void catchsig(int i)
{
	longjmp(jmpenv, 1);
}

void dohelp(FILE *in, FILE *out, int proc, char **commands)
{
	if (proc < 0) return;

	if (streq(commands[proc], "agent"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: agent name\n\n");
		fprintf(out, "Uses only the named lookup agent for subsequent lookups.\n");
		fprintf(out, "The normalLookupOrder command may be used to restore the\n");
		fprintf(out, "normal search order.\n");
	}

	else if (streq(commands[proc], "aliasWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: aliasWithName name\n\n");
		fprintf(out, "Looks up the named e-mail alias.\n");
	}
	
	else if (streq(commands[proc], "allAliases"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allAliases\n\n");
		fprintf(out, "Looks up all known e-mail aliases.\n");
	}
	
	else if (streq(commands[proc], "allBootparams"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allBootparams\n\n");
		fprintf(out, "Looks up all known bootparams entries.\n");
		fprintf(out, "Note that entries for hosts with no set bootparams\n");
		fprintf(out, "will also be printed, so this command will list all\n");
		fprintf(out, "known hosts.\n");
	}
	
	else if (streq(commands[proc], "allGroups"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allGroups\n\n");
		fprintf(out, "Looks up all known groups.\n");
	}
	
	else if (streq(commands[proc], "allGroupsWithUser"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allGroupsWithUser name\n\n");
		fprintf(out, "Looks up all groups having the named user as a member.\n");
	}

	else if (streq(commands[proc], "allHosts"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allHosts\n\n");
		fprintf(out, "Looks up all known hosts.\n");
	}
	
	else if (streq(commands[proc], "allMounts"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allMounts\n\n");
		fprintf(out, "Looks up all known NFS mounts.\n");
	}
	
	else if (streq(commands[proc], "allNetworks"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allNetworks\n\n");
		fprintf(out, "Looks up all known networks.\n");
	}
	
	else if (streq(commands[proc], "allPrinters"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allPrinters\n\n");
		fprintf(out, "Looks up all known printers and FAX modems.\n");
	}
	
	else if (streq(commands[proc], "allProtocols"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allProtocols\n\n");
		fprintf(out, "Looks up all known protocols.\n");
	}
	
	else if (streq(commands[proc], "allRpcs"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allRpcs\n\n");
		fprintf(out, "Looks up all known rpcs.\n");
	}
	
	else if (streq(commands[proc], "allServices"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allServices\n\n");
		fprintf(out, "Looks up all known TCP and UDP services.\n");
	}
	
	else if (streq(commands[proc], "allStatistics"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allStatistics\n\n");
		fprintf(out, "Prints statistics for all agents and servers.\n");
		fprintf(out, "Also prints memory statistics (see \"memory\").\n");
	}
	
	else if (streq(commands[proc], "allUsers"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: allUsers\n\n");
		fprintf(out, "Looks up all known users.\n");
	}

	else if (streq(commands[proc], "bootpWithEthernetAddress"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: bootpWithEthernetAddress en_address\n\n");
		fprintf(out, "Looks up bootp information for the host with the given\n");
		fprintf(out, "Ethernet address.  Addresses should be in the format:\n");
		fprintf(out, "    XX:XX:XX:XX:XX:XX\n");
		fprintf(out, "Leading zeros in a pair of hex digits may be omitted.\n");
	}
	
	else if (streq(commands[proc], "bootpWithInternetAddress"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: bootpWithInternetAddress ip_address\n\n");
		fprintf(out, "Looks up bootp information for the host with the given\n");
		fprintf(out, "Internet address.  Addresses should be specified in\n");
		fprintf(out, "dotted decimal notation.\n");

	}
	
	else if (streq(commands[proc], "bootparamsWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: bootparamsWithName name\n\n");
		fprintf(out, "Looks up bootparams information for the host with the \n");
		fprintf(out, "given name.\n");
	}
	
	else if (streq(commands[proc], "flushCache"))
	{
		fprintf(out, "\n");
		fprintf(out, "Removes all cached information from the internal cache.\n");
	}

	else if (streq(commands[proc], "groupWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: groupWithName name\n\n");
		fprintf(out, "Looks up the user group with the given name.\n");
	}
	
	else if (streq(commands[proc], "groupWithNumber"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: groupWithNumber gid\n\n");
		fprintf(out, "Looks up the user group with the given group ID number.\n");
	}	

	else if (streq(commands[proc], "help"))
	{
		fprintf(out, "\n");
		fprintf(out, "This is lookupd's interactive query and testing facility.\n");
		fprintf(out, "From the \">\" prompt, you may enter commands that invoke\n");
		fprintf(out, "all of lookupd's internal lookup routines, plus a few other\n");
		fprintf(out, "routines that are useful for testing your configuration.\n");
		fprintf(out, "\n");
		fprintf(out, "A brief help message is available for each command.  Enter\n");
		fprintf(out, "the command name at the \"help>\" prompt for information\n");
		fprintf(out, "about that command.\n");
		fprintf(out, "\n");
		fprintf(out, "Command completion is available.  Pressing ESC, space, tab,\n");
		fprintf(out, "or return will complete the command as you type.  Control-u\n");
		fprintf(out, "clears the command. Control-c aborts the command.  A \"?\"\n");
		fprintf(out, "will print all possible completions.\n");
		fprintf(out, "\n");
		fprintf(out, "Lookup results are printed to the terminal.  The listing\n");
		fprintf(out, "includes the data retrieved, statistics about the\n");
		fprintf(out, "information source, and internal cache statistics.\n");
	}

	else if (streq(commands[proc], "hostWithEthernetAddress"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: hostWithEthernetAddress en_address\n\n");
		fprintf(out, "Looks up the host with the given Ethernet address.\n");
		fprintf(out, "Addresses should be in the format:\n");
		fprintf(out, "    XX:XX:XX:XX:XX:XX\n");
		fprintf(out, "Leading zeros in a pair of hex digits may be omitted.\n");
	}
	
	else if (streq(commands[proc], "hostWithInternetAddress"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: hostWithInternetAddress ip_address\n\n");
		fprintf(out, "Looks up the host with the given Internet address.\n");
		fprintf(out, "Addresses should be specified in dotted decimal notation.\n");
	}
	
	else if (streq(commands[proc], "hostWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: hostWithName name\n\n");
		fprintf(out, "Looks up the host with the given name.\n");
	}
	
	else if (streq(commands[proc], "inNetgroup"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: inNetgroup group host user domain\n\n");
		fprintf(out, "Determines whether the given (host, user, domain)\n");
		fprintf(out, "is a member of the specified netgroup.  the value\n");
		fprintf(out, "for host, user, or domain may be \"-\" to signify\n");
		fprintf(out, "no value for that field.  Prints \"YES\" or \"NO\".\n");
	}

	else if (streq(commands[proc], "isNetwareEnabled"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: isNetwareEnabled\n\n");
		fprintf(out, "Determines whether netware is enabled.\n");
	}

	else if (streq(commands[proc], "isSecurityEnabledForOption"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: isSecurityEnabledForOption option\n\n");
		fprintf(out, "Determines whether the given security option is enabled.\n");
	}

	else if (streq(commands[proc], "memory"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: memory\n\n");
		fprintf(out, "Reports on memory usage.  Columns are\n");
		fprintf(out, "reference_number, retain count, \"*\" if cached, address, and description.\n");
		fprintf(out, "Description may be D-0x<addr> or A-0x<addr> for dictionaries and arrays.\n");
	}
	
	else if (streq(commands[proc], "mountWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: mountWithName name\n\n");
		fprintf(out, "Looks up the NFS mount with the given name.\n");
	}
	
	else if (streq(commands[proc], "netgroupWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: netgroupWithName name\n\n");
		fprintf(out, "Looks up the netgroup with the given name.\n");
	}
	
	else if (streq(commands[proc], "networkWithInternetAddress"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: networkWithInternetAddress address\n\n");
		fprintf(out, "Looks up the network with the given Internet address.\n");
		fprintf(out, "Addresses should be specified in dotted decimal notation.\n");
	}
	
	else if (streq(commands[proc], "networkWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: networkWithName name\n\n");
		fprintf(out, "Looks up the network with the given name.\n");
	}
	
	else if (streq(commands[proc], "normalLookupOrder"))
	{
		fprintf(out, "\n");
		fprintf(out, "Resets the interactive command interpretor to use lookupd's\n");
		fprintf(out, "normal lookup order - either the default order, or that\n");
		fprintf(out, "specified by lookupd's configuration information.  This\n");
		fprintf(out, "command resets the action of the \"agent\" command.\n");
	}

	else if (streq(commands[proc], "printerWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: printerWithName name\n\n");
		fprintf(out, "Looks up the printer or FAX modem with the given name.\n");
	}
	
	else if (streq(commands[proc], "protocolWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: protocolWithName name\n\n");
		fprintf(out, "Looks up the protocol with the given name.\n");
	}
	
	else if (streq(commands[proc], "protocolWithNumber"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: protocolWithNumber number\n\n");
		fprintf(out, "Looks up the protocol with the given number.\n");
	}	

	else if (streq(commands[proc], "restart"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: restart\n\n");
		fprintf(out, "Restarts lookupd.\n");
	}
	
	else if (streq(commands[proc], "rpcWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: rpcWithName name\n\n");
		fprintf(out, "Looks up the rpc with the given name.\n");
	}
	
	else if (streq(commands[proc], "rpcWithNumber"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: rpcWithNumber number\n\n");
		fprintf(out, "Looks up the rpc with the given number.\n");
	}	

	else if (streq(commands[proc], "serviceWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: serviceWithName name protocol\n\n");
		fprintf(out, "Looks up the service with the given name and protocol.\n");
		fprintf(out, "The value for protocol may be \"tcp\", \"udp\", or \"-\" to\n");
		fprintf(out, "signify no value (first match).\n");
	}
	
	else if (streq(commands[proc], "serviceWithNumber"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: serviceWithNumber number protocol\n\n");
		fprintf(out, "Looks up the service with the given number and protocol.\n");
		fprintf(out, "The value for protocol may be \"tcp\", \"udp\", or \"-\" to\n");
		fprintf(out, "signify no value (first match).\n");
	}	

	else if (streq(commands[proc], "showMemoryObject"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: showMemoryObject number\n\n");
		fprintf(out, "Prints the object with the given index (as given by the.\n");
		fprintf(out, "\"memory\" command).");
	}

	else if (streq(commands[proc], "statistics"))
	{
		fprintf(out, "\n");
		fprintf(out, "Prints statistics for the current lookup server, or for\n");
		fprintf(out, "the current agent if preceeded by the \"agent\" command.\n");
	}

	else if (streq(commands[proc], "statisticsForAgent"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: statisticsForAgent name\n\n");
		fprintf(out, "Prints statistics the named agent.\n");
	}

	else if (streq(commands[proc], "userWithName"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: userWithName name\n\n");
		fprintf(out, "Looks up the user with the given name.\n");
	}
	
	else if (streq(commands[proc], "userWithNumber"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: userWithNumber uid\n\n");
		fprintf(out, "Looks up the user with the given user ID number.\n");
	}	

#ifdef DNS_SRV
	else if (streq(commands[proc], "hostsWithService"))
	{
		fprintf(out, "\n");
		fprintf(out, "usage: hostsWithService name protocol\n\n");
		fprintf(out, "Looks up the hosts which serve the given name and protocol.\n");
		fprintf(out, "The value for protocol may be \"tcp\", \"udp\".\n");
	}	
#endif /* DNS_SRV */
 
	else
	{
		fprintf(out, "\n");
		fprintf(out, "Unknown command!\n");
	}
}

void help(FILE *in, FILE *out, char **commands)
{
	int n, len;

	len = listLength(commands);

	fprintf(out, "\n");
	fprintf(out, "Enter command name, \"help\" for general help, or \"quit\" to exit help\n");

	forever
	{
		n = getcom(stdin, stdout, commands, len, "help> ");
		if (n < 0)
		{
			fprintf(out, "\n");
			continue;
		}

		if (streq(commands[n], "quit")) break;
		dohelp(in, out, n, commands);
		fprintf(out, "\n");
	}

	fprintf(out, "\n");
}

void doproc(FILE *in, FILE *out, int proc, char **commands)
{
	LUDictionary *dict;
	LUArray *list;
	LUServer *server;
	int i;
	struct in_addr ip;
	struct ether_addr *ether;
	BOOL resultIsList;
	BOOL test;
	id agentClass;
	LUAgent *agent;
	id ask;
	char *name, *host, *user, *domain, *proto;

	if (proc < 0) return;
	if (streq(commands[proc], "help"))
	{
		help(in, out, commands);
		return;
	}

	server = [controller checkOutServer];
	if (server == nil)
	{
		fprintf(out, "Internal error: can't check out a server!\n");
		return;
	}

	list = nil;
	dict = nil;
	resultIsList = NO;

	ask = askMe;
	if (ask == nil) ask = server;

	if (streq(commands[proc], "agent"))
	{
		agentClass = [controller agentNamed:get_string(in, out, ": ")];
		fprintf(out, "\n");

		if (agentClass == nil) 
		{
			fprintf(out, "No such agent\n");
			[controller checkInServer:server];
			return;
		}

		agent = [server agentForSystem:agentClass];
		if (agent == nil)
		{
			fprintf(out, "No such agent\n");
			[controller checkInServer:server];
			return;
		}

		askMe = agent;
		[controller checkInServer:server];
		return;
	}

	else if (streq(commands[proc], "aliasWithName"))
	{
		dict = [ask aliasWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "allAliases"))
	{
		fprintf(out, "\n");
		list = [ask allAliases];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allBootparams"))
	{
		fprintf(out, "\n");
		list = [ask allBootparams];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allGroups"))
	{
		fprintf(out, "\n");
		list = [ask allGroups];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allGroupsWithUser"))
	{
		list = [ask allGroupsWithUser:get_string(in, out, ": ")];
		fprintf(out, "\n");
		resultIsList = YES;
	}

	else if (streq(commands[proc], "allHosts"))
	{
		fprintf(out, "\n");
		list = [ask allHosts];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allMounts"))
	{
		fprintf(out, "\n");
		list = [ask allMounts];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allNetworks"))
	{
		fprintf(out, "\n");
		list = [ask allNetworks];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allPrinters"))
	{
		fprintf(out, "\n");
		list = [ask allPrinters];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allProtocols"))
	{
		fprintf(out, "\n");
		list = [ask allProtocols];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allRpcs"))
	{
		fprintf(out, "\n");
		list = [ask allRpcs];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allServices"))
	{
		fprintf(out, "\n");
		list = [ask allServices];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allStatistics"))
	{
		fprintf(out, "\n");
		list = [controller allStatistics];
		resultIsList = YES;
	}
	
	else if (streq(commands[proc], "allUsers"))
	{
		fprintf(out, "\n");
		list = [ask allUsers];
		resultIsList = YES;
	}

	else if (streq(commands[proc], "bootpWithEthernetAddress"))
	{
		ether = ether_aton(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask bootpWithEthernetAddress:ether];
	}
	
	else if (streq(commands[proc], "bootpWithInternetAddress"))
	{
		ip.s_addr = inet_addr(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask bootpWithInternetAddress:&ip];
	}
	
	else if (streq(commands[proc], "bootparamsWithName"))
	{
		dict = [ask bootparamsWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "flushCache"))
	{
		fprintf(out, "\n");
		[controller flushCache];
		[controller checkInServer:server];
		return;
	}

	else if (streq(commands[proc], "groupWithName"))
	{
		dict = [ask groupWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "groupWithNumber"))
	{
		i = atoi(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask groupWithNumber:&i];
	}	

	else if (streq(commands[proc], "hostWithEthernetAddress"))
	{
		ether = ether_aton(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask hostWithEthernetAddress:ether];
	}
	
	else if (streq(commands[proc], "hostWithInternetAddress"))
	{
		ip.s_addr = inet_addr(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask hostWithInternetAddress:&ip];
	}
	
	else if (streq(commands[proc], "hostWithName"))
	{
		dict = [ask hostWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "inNetgroup"))
	{
		name = copyString(get_string(in, out, ": "));
		host = copyString(get_string(in, out, " host: "));
		user = copyString(get_string(in, out, " user: "));
		domain = copyString(get_string(in, out, " domain: "));
		fprintf(out, "\n");

		if (streq(host, "-"))
		{
			freeString(host);
			host = NULL;
		}
		if (streq(user, "-"))
		{
			freeString(user);
			user = NULL;
		}
		if (streq(domain, "-"))
		{
			freeString(domain);
			domain = NULL;
		}

		test = [ask inNetgroup:name host:host user:user domain:domain];
		freeString(name); name = NULL;
		freeString(host); host = NULL;
		freeString(user); user = NULL;
		freeString(domain); domain = NULL;
		fprintf(out, "%s\n", test ? "YES" : "NO");
		[controller checkInServer:server];
		return;
	}

	else if (streq(commands[proc], "isNetwareEnabled"))
	{
		fprintf(out, "\n");
		test = [controller isNetwareEnabled];
		fprintf(out, "%s\n", test ? "YES" : "NO");
		[controller checkInServer:server];
		return;
	}

	else if (streq(commands[proc], "isSecurityEnabledForOption"))
	{
		test = [controller isSecurityEnabledForOption:get_string(in, out, ": ")];
		fprintf(out, "\n");
		fprintf(out, "%s\n", test ? "YES" : "NO");
		[controller checkInServer:server];
		return;
	}

	else if (streq(commands[proc], "memory"))
	{
		fprintf(out, "\n");
		[rover checkObjects];
		[controller checkInServer:server];
		return;
	}
	
	else if (streq(commands[proc], "mountWithName"))
	{
		dict = [ask mountWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "netgroupWithName"))
	{
		/* XXX domain doesn't print */
		dict = [ask netgroupWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "networkWithInternetAddress"))
	{
		ip.s_addr = inet_network(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask networkWithInternetAddress:&ip];
	}
	
	else if (streq(commands[proc], "networkWithName"))
	{
		dict = [ask networkWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "normalLookupOrder"))
	{
		fprintf(out, "\n");
		askMe = nil;
		fprintf(out, "Using normal lookup order\n");
		[controller checkInServer:server];
		return;
	}

	else if (streq(commands[proc], "printerWithName"))
	{
		dict = [ask printerWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "protocolWithName"))
	{
		dict = [ask protocolWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "protocolWithNumber"))
	{
		i = atoi(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask protocolWithNumber:&i];
	}	

	else if (streq(commands[proc], "restart"))
	{
		fprintf(out, "\n... ");
		fflush(out);
		askMe = nil;
		[controller checkInServer:server];

		[controller release];
		controller = nil;
		[rover release];
		rover = nil;

		rover = [[MemoryWatchdog alloc] init];
		controller = [[Controller alloc] initWithName:portName];

		fprintf(out, "Restarted");
		return;
	}
	
	else if (streq(commands[proc], "rpcWithName"))
	{
		dict = [ask rpcWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "rpcWithNumber"))
	{
		i = atoi(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask rpcWithNumber:&i];
	}	

	else if (streq(commands[proc], "serviceWithName"))
	{
		name = copyString(get_string(in, out, ": "));
		proto = copyString(get_string(in, out, " protocol: "));
		fprintf(out, "\n");
		if (streq(proto, "-"))
		{
			freeString(proto);
			proto = NULL;
		}
		dict = [ask serviceWithName:name protocol:proto];
		fprintf(out, "\n");
		freeString(name);
		freeString(proto);
	}
	
	else if (streq(commands[proc], "showMemoryObject"))
	{
		i = atoi(get_string(in, out, ": "));
		fprintf(out, "\n");
		[rover printObject:i file:out];
		[controller checkInServer:server];
		return;
	}
	
	else if (streq(commands[proc], "serviceWithNumber"))
	{
		i = atoi(get_string(in, out, ": "));
		proto = copyString(get_string(in, out, " protocol: "));
		fprintf(out, "\n");
		if (streq(proto, "-"))
		{
			freeString(proto);
			proto = NULL;
		}
		dict = [ask serviceWithNumber:&i protocol:proto];
		freeString(proto);
	}	

	else if (streq(commands[proc], "statistics"))
	{
		fprintf(out, "\n");
		/* retain stats since we don't want to *really* free it */
		dict = [ask statistics];
		if (dict != nil) [dict retain];
	}

	else if (streq(commands[proc], "statisticsForAgent"))
	{
		agentClass = [controller agentNamed:get_string(in, out, ": ")];
		fprintf(out, "\n");
		if (agentClass != nil) 
		{
			agent = [server agentForSystem:agentClass];
			if (agent != nil)
			{
				dict = [agent statistics];
				if (dict != nil) [dict retain];
			}
		}
	}

	else if (streq(commands[proc], "userWithName"))
	{
		dict = [ask userWithName:get_string(in, out, ": ")];
		fprintf(out, "\n");
	}
	
	else if (streq(commands[proc], "userWithNumber"))
	{
		i = atoi(get_string(in, out, ": "));
		fprintf(out, "\n");
		dict = [ask userWithNumber:&i];
	}
	
#ifdef DNS_SRV	
	else if (streq(commands[proc], "hostsWithService"))
	{
		name = copyString(get_string(in, out, ": "));
		proto = copyString(get_string(in, out, " protocol: "));
		fprintf(out, "\n");
		dict = [ask hostsWithService:name protocol:proto];
		fprintf(out, "\n");
		freeString(name);
		freeString(proto);
	}
#endif /* DNS_SRV */

	else
	{
		fprintf(out, "\nUnknown command: %s\n", commands[proc]);
		[controller checkInServer:server];
		return;
	}

	[controller checkInServer:server];

	if (resultIsList)
	{
		printArray(out, list);
		[list release];
	}
	else
	{
		printDictionary(out, dict);
		[dict release];
	}
}

void interactive(FILE *in, FILE *out)
{
	char **commands = NULL;
	int n, len;

	commands = appendString("agent", commands);
	commands = appendString("aliasWithName", commands);
	commands = appendString("allAliases", commands);
	commands = appendString("allBootparams", commands);
	commands = appendString("allGroups", commands);
	commands = appendString("allGroupsWithUser", commands);
	commands = appendString("allHosts", commands);
	commands = appendString("allMounts", commands);
	commands = appendString("allNetworks", commands);
	commands = appendString("allPrinters", commands);
	commands = appendString("allProtocols", commands);
	commands = appendString("allRpcs", commands);
	commands = appendString("allServices", commands);
	commands = appendString("allStatistics", commands);
	commands = appendString("allUsers", commands);
	commands = appendString("bootpWithEthernetAddress", commands);
	commands = appendString("bootpWithInternetAddress", commands);
	commands = appendString("bootparamsWithName", commands);
	commands = appendString("flushCache", commands);
	commands = appendString("groupWithName", commands);
	commands = appendString("groupWithNumber", commands);
	commands = appendString("help", commands);
	commands = appendString("hostWithEthernetAddress", commands);
	commands = appendString("hostWithInternetAddress", commands);
	commands = appendString("hostWithName", commands);
	commands = appendString("hostsWithService", commands);
	commands = appendString("inNetgroup", commands);
	commands = appendString("isNetwareEnabled", commands);
	commands = appendString("isSecurityEnabledForOption", commands);
	commands = appendString("memory", commands);
	commands = appendString("mountWithName", commands);
	commands = appendString("netgroupWithName", commands);
	commands = appendString("networkWithInternetAddress", commands);
	commands = appendString("networkWithName", commands);
	commands = appendString("normalLookupOrder", commands);
	commands = appendString("printerWithName", commands);
	commands = appendString("protocolWithName", commands);
	commands = appendString("protocolWithNumber", commands);
	commands = appendString("quit", commands);
	commands = appendString("restart", commands);
	commands = appendString("rpcWithName", commands);
	commands = appendString("rpcWithNumber", commands);
	commands = appendString("serviceWithName", commands);
	commands = appendString("serviceWithNumber", commands);
	commands = appendString("showMemoryObject", commands);
	commands = appendString("statistics", commands);
	commands = appendString("statisticsForAgent", commands);
	commands = appendString("userWithName", commands);
	commands = appendString("userWithNumber", commands);

	len = listLength(commands);

	newterm();
	signal(SIGINT, catchsig);

	if (setjmp(jmpenv) != 0) fprintf(out, "\n");

	fprintf(out, "Enter command name, \"help\", or \"quit\" to exit\n");
	forever
	{
		n = getcom(stdin, stdout, commands, len, "> ");
		if (n < 0)
		{
			fprintf(out, "\n");
			continue;
		}

		if (streq(commands[n], "quit")) break;
		doproc(in, out, n, commands);
		fprintf(out, "\n");
	}

	fprintf(out, "\n");
	freeList(commands);
	oldterm();
}
