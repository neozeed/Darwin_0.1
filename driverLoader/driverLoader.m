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
/* 	Copyright (c) 1993 NeXT Computer, Inc.  All rights reserved. 
 * 
 * driverLoader.m
 *
 * HISTORY
 * 03-Feb-93    Doug Mitchell at NeXT
 *      Created. 
 */

/*
 * This program runs early in the boot sequence. It scans the system config 
 * table, performing the following:
 * 
 * -- For each Boot Device, _IOProbeDriver() is invoked for each config
 *    table file for instance > 0. (Instance 0 for Boot Devices is handled
 *    by the booter (or possibly hard-coded kernel tables).
 * -- For each Active Device, if a *_reloc binary exists for the driver,
 *    the *_reloc is kern-loaded into the kernel. If successful, 
 *    _IOProbeDriver() is invoked for each config table file instance.
 * -- For all drivers, the Pre-Load and Post-Load binaries are executed
 *    as appropriate. 
 *
 * In addition to normal boot-time use, this program can also be used 
 * interactively to load and/or config drivers. See the usage strings.
 */
 
#import <mach/mach.h>
#import <strings.h>
#import <driverkit/IOConfigTable.h>
#import <driverkit/IODeviceMaster.h>
#import <driverkit/configTablePrivate.h>
#import <driverkit/generalFuncs.h>
#import <driverkit/driverServer.h>
#import <driverkit/IODevice.h>
#import <objc/List.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <libc.h>
#import <errno.h>
#import <sys/dir.h>

/*
 * IOConfigTable keys used only here.
 */
#define IO_BOOT_DRIVERS		"Boot Drivers"
#define IO_ACTIVE_DRIVERS	"Active Drivers"
#define IO_PRE_LOAD		"Pre-Load"
#define IO_POST_LOAD		"Post-Load"
#define IO_SERVER_NAME		"Server Name"
#define IO_DISPLAY_NAME		"Display0"
#define IO_VGADISPLAY_NAME	"VGADisplay0"
#define IO_SVGADISPLAY_NAME	"SVGADisplay0"

#import "kl_com.h"

#define vprintf(x)  {		\
	if(verbose) {		\
		printf x;	\
	}			\
}

#define DL_DEBUG	0

#define dprintf(x,a,b,c,d,e)  {			\
	if(DL_DEBUG) {				\
		fprintf(stderr, x,a,b,c,d,e);	\
	}					\
}

/*
 * Return codes for configDriver().
 */
typedef enum {
	CR_Success,
	CR_NoInstance,		// instance not present
	CR_Error,		// error 
	CR_Abort,		// abort entire driver (security violation)
} configReturn;

typedef enum {PRELOAD, POSTLOAD} prePost;

/*
 * Static functions.
 */
static void usage(char **argv);
static BOOL inquire(const char *op);
static int processDriverList(const char *driverList, BOOL bootDrivers,
	BOOL load);
static int processDriver(const char *driverName, BOOL bootDriver, BOOL load);
static int loadDriver(const char *driverName);
static int unloadDriver(const char *driverName);
static configReturn getInstanceFile(const char *driverName, char *fileName,
	int unitNum, struct stat *statBuf);
static configReturn configDriver(const char *driverName, int unitNum,
	BOOL doProbe, BOOL doPreExec);
static BOOL securityCheck(const char *driverName);
static BOOL securityCheckDir(const char *path);
static configReturn prePostExec(const char *driverName, int unit, prePost pre);

/*
 * Globals.
 */
int verbose = 0;
int interactive = 0;
char *progName;

int main(int argc, char **argv)
{
	int 		arg;
	IOConfigTable 	*configTable;
	const char 	*driverList;
	const char 	*driverName = NULL;
	BOOL		load = YES;
	
	if(argc < 2) {
		usage(argv);
	}
	progName = argv[0];
	for(arg=1; arg<argc; arg++) {
		switch(argv[arg][0]) {
		    case 'a':			// default mode
			break;
		    case 'i':
			interactive = 1;
			break;
		    case 'd':
		    case 'D':
#if NOTYET
		    case 'u':
#endif NOTYET
			driverName = argv[arg] + 2;
			interactive = (argv[arg][0] == 'd') ? YES : NO;
			load = (argv[arg][0] == 'u') ? NO : YES;
			break;
		    case 'v':
		    	verbose = 1;
			break;
		    default:
			usage(argv);
		}
	}
	if(driverName) {
		/*
		 * Just do one device. We set bootDevice false since
		 * we're in interactive mode; the user can decide about
		 * loading and Instance0.
		 */
		return processDriver(driverName, NO, load);
	}
	
	/*
	 * Configure all devices listed in system config table.
	 */
	configTable = [IOConfigTable newFromSystemConfig];
	if(configTable == nil) {
		fprintf(stderr, "%s: can\'t get system config table\n", 
			argv[0]);
		exit(1);
	}
	if(inquire("Configure Boot Drivers")) {
		driverList = [configTable valueForStringKey:IO_BOOT_DRIVERS];
		if(driverList == NULL) {
			fprintf(stderr, "%s: can\'t get Boot Driver list\n",
				 argv[0]);
			exit(1);
		}
		processDriverList(driverList, YES, YES);
	}
	if(inquire("Configure Active Drivers")) {
		driverList = [configTable valueForStringKey:IO_ACTIVE_DRIVERS];
		if(driverList == NULL) {
			fprintf(stderr, "%s: can\'t get Active Driver list\n",
				argv[0]);
			exit(1);
		}
		processDriverList(driverList, NO, YES);
	}
	if (!interactive) {
	    IODeviceMaster *devMaster = [IODeviceMaster new];
	    IOObjectNumber objNum;
	    IOString kind;
	    BOOL displayFound;
	    
	    displayFound =
	    (([devMaster lookUpByDeviceName:IO_DISPLAY_NAME objectNumber:&objNum deviceKind:&kind] == IO_R_SUCCESS) ||
	     ([devMaster lookUpByDeviceName:IO_VGADISPLAY_NAME objectNumber:&objNum deviceKind:&kind] == IO_R_SUCCESS) ||
	     ([devMaster lookUpByDeviceName:IO_SVGADISPLAY_NAME objectNumber:&objNum deviceKind:&kind] == IO_R_SUCCESS));
	    if (!displayFound) {
		fprintf(stderr, "%s: No display driver added, trying VGA\n", argv[0]);
		return (processDriver("VGA", NO, YES));
	    }
	}
	return 0;
}

static void usage(char **argv)
{
	printf("Usage: %s <operation> [v(verbose)]\n", argv[0]);
	printf("Operations:\n");
	printf("\ta               Configure All Devices\n");
	printf("\ti               Interactive mode\n");
	printf("\td=deviceName    Configure one device (implies "
		"interactive)\n");
	printf("\tD=deviceName    Configure one device (non-interactive)\n");
#if NOTYET
	printf("\tu=deviceName    Unload one device (implies interactive)\n");
#endif NOTYET
	exit(1);
}

/*
 * Returns YES if operation should proceed, NO if not.
 */
static instruction = NO;

static BOOL inquire(const char *op)
{
	char instr[80];
	
	if(!interactive) {
		return YES;
	}
	if(!instruction) {
		printf("Answer queries with 'y' for 'yes', anything else "
			"is 'no'.\n");
		instruction = YES;
	}
	printf("%s? ", op);
	gets(instr);
	return ((instr[0] == 'y') ? YES : NO);
}

/*
 * Process a list of drivers. If bootDrivers is YES, we 
 * just look for a post-load executable to run.
 */
static int processDriverList(const char *driverList, BOOL bootDrivers,
	    BOOL load)
{
	char 		driverName[100];
	const char	*stringP;		// --> activeDrivers
	char 		*nameP;			// --> driverName
	BOOL		gotName;
	
	vprintf(("Configuring %s Drivers\n", 
		(bootDrivers ? "Boot" : "Active")));
	nameP = driverName;	
	gotName = NO;
	stringP = driverList;
	while(1) {
		if((*stringP != ' ') && (*stringP != '\0')) {
			gotName = YES;
			*nameP++ = *stringP;
		}
		else {
			if(!gotName) {
			   	/*
				 * Skip spaces (we haven't gotten a name yet).
				 */
			   	if(*stringP == '\0') {
					break;	// trailing spaces; done
			    	} 
			    	goto nextChar;
			}
			*nameP = '\0';		// null-terminate driverName
			processDriver(driverName, bootDrivers, load);
			
			/*
			 * Reset...
			 */
			nameP = driverName;
			gotName = NO;
			
		}  /* terminator */
nextChar:
		if(*stringP) {
		    	stringP++;
		}
		else {
		    	break;
		}
	}
	return 0;
}

/*
 * Process one driver. This consists of loading the *_reloc if present and 
 * doing an _IOProbeDriver() for each instance table.
 * Returns non-zero on error.
 */
static int processDriver(const char *driverName, BOOL bootDriver, BOOL load)
{
	int		rtn;
	int 		unit;
	configReturn	crtn;
#ifdef	ppc
//
//	driverLoader does not appear to return meaningful return codes with respect
//	to whether a driver was actually loaded and probed successfully. Change return 
//      code for ppc version to return 0 only if at least one driver instance was probed OK. 
// 
        int		crtnOKCount = 0;		// # of instances probed OK
#endif
	
	if (load == FALSE) {
	    return unloadDriver(driverName);
	}
	
	//if(securityCheck(driverName)) {
		//fprintf(stderr, "Aborting configuration of driver %s\n", 
			//driverName);
		//return 1;
	//}

	/*
	 * First, execute the Pre-Load binary for instance 0.
	 */
	switch(prePostExec(driverName, 0, PRELOAD)) {
	    case CR_Success:	// OK or no file specified
		break;
	    case CR_Error:	// exited with non-zero status
	    	fprintf(stderr, "driverLoader: driver %s Pre-Load file "
			"returned non-zero status; aborting\n", driverName);
	    case CR_Abort:    	// security violation detected
	    default:
		return 1;	// either case - forget it!
	}
		
	if(!bootDriver) {
		if(rtn = loadDriver(driverName)) {
			return rtn;
		}
	}
	
	/*
	 * Config each appropriate instance of the driver.
	 */
	crtn = CR_Success;
	for(unit = 0; crtn != CR_NoInstance; unit++) {
		crtn = configDriver(driverName, 
			unit,
			!bootDriver,
			(unit > 0) ? YES : NO);
		switch(crtn) {
		    case CR_Success:
#ifdef	ppc
			crtnOKCount++;
#endif
			continue;	// next instance
		    case CR_NoInstance:
			break;		// done with this driver
		    case CR_Error:
			continue;	// this instance failed, but
					//   keep going
		    case CR_Abort:	// security violation
		    	return 1;
		}
	}
#ifdef	ppc
        return (((crtn == CR_NoInstance) && (crtnOKCount > 0)) ? 0 : 1);
#else
	return ((crtn == CR_NoInstance) ? 0 : 1);
#endif
}

/*
 * Load a driver's *_reloc into the kernel if present. driverName is as it
 * appears in either "Boot Drivers" or "Active Drivers". If a driver has no
 * _reloc binary, this is not considered an error; we assume that this 
 * means that the driver is already linked into the kernel.
 *
 * Returns nonzero on error.
 */
static int loadDriver(const char *driverName)
{
	char fileName[MAXPATHLEN];
	struct stat statBuf;
	char query[100];
	IOConfigTable *configTable;
	const char *serverName;
	
	sprintf(fileName, "%s%s%s/%s%s", 
		IO_CONFIG_DIR, driverName, IO_BUNDLE_EXTENSION,
		driverName, IO_BINARY_EXTENSION);
	if(stat(fileName, &statBuf)) {
		vprintf(("No Relocatable for %s\n", driverName));
		return 0;
	}

	sprintf(query, "Load driver %s", driverName);
	if(!inquire(query)) {
		return 0;
	}

	vprintf(("Loading %s for driver %s\n", fileName, driverName));
	if(kl_com_add(fileName, driverName)) {
		fprintf(stderr, "%s: kl_com_add() failed on %s\n", 
			progName, fileName);
		return 1;
	}

	/*
	 * Get server name from config table.
	 */	
	configTable = [IOConfigTable newForDriver:driverName unit:0];
	if(configTable == nil) {
		/*
		 * Try default table.
		 */
		configTable = [IOConfigTable 
			newDefaultTableForDriver:driverName];
		if(configTable == nil) {
			fprintf(stderr, "%s: Can\'t get config table for %s\n", 
				progName, driverName);
			return 1;
		}
	}
	serverName = [configTable valueForStringKey:IO_SERVER_NAME];
	if(serverName == NULL) {
		fprintf(stderr, "%s: No Server Name for %s\n", 
			progName, driverName);
		return 1;
	}
	if(kl_com_load(serverName)) {
		fprintf(stderr, "%s: kl_com_load() failed on %s\n", 
			progName, fileName);
		[configTable free];
		return 1;
	}
	[configTable free];
	return 0;
}

static int
unloadDriver( const char *driverName )
{
    int			cc, fd;
    char 		fileName[MAXPATHLEN], query[100];
    struct stat 	statBuf;
    vm_offset_t 	vm;
    
    vprintf(("Unloading driver %s\n", driverName));
    
    if (getInstanceFile(driverName, fileName, 0, &statBuf) != CR_Success) {
	fprintf(stderr, "%s: couldn't get instance file for driver %s\n",
	    progName, driverName);
    	return 1;
    }

    sprintf(query, "Unload driver %s", driverName);
    if(!inquire(query)) {
	    return 0;
    }	

    fd = open(fileName, O_RDONLY);
    if(fd < 0) {
	vprintf(("Can\'t open Instance file for %s instance %d "
		"(errno %d)\n",
		driverName, 0, errno));
	return CR_NoInstance;
    }
    if(map_fd(fd, 
		0,		// file offset
		&vm,
		TRUE,		// find_space
		statBuf.st_size)) {
	vprintf(("Can\'t read Instance file for %s instance %d "
		"(errno %d)\n",
		driverName, 0, errno));
	close(fd);
	return 1;
    }
	
    cc = _IOUnloadDriver(device_master_self(),
		(unsigned char *)vm,
		statBuf.st_size);

    vm_deallocate(task_self(), vm, statBuf.st_size);
    close(fd);

    if (cc != IO_R_SUCCESS) {
	fprintf(stderr, "%s: IOUnloadDriver() failed with code %d on %s\n",
	    progName, cc, driverName);
	return 1;
    }
    
    if ((cc = kl_com_unload(driverName)) != 0) {
	fprintf(stderr, "%s: kl_com_unload() failed with code %d on %s\n",
	    progName, cc, driverName);
	return 1;
    }
    if ((cc = kl_com_delete(driverName)) != 0) {
	fprintf(stderr, "%s: kl_com_delete() failed with code %d on %s\n",
	    progName, cc, driverName);
	return 1;
    }
    return 0;
}

/*
 * Gets the file name of the instance file for the driver,
 * and does a stat() of that file for you.
 * Returns CR_Success if everything went OK.
 */
static configReturn getInstanceFile(const char *driverName,
	char *fileName,
	int unitNum,
	struct stat *statBuf)
{
	sprintf(fileName, "%s%s%s/Instance%d%s", 
		IO_CONFIG_DIR, driverName, IO_BUNDLE_EXTENSION,
		unitNum, IO_TABLE_EXTENSION);
	if(stat(fileName, statBuf)) {
		vprintf(("No Instance file for %s instance %d\n",
			driverName, unitNum));
			
		/*
		 * Try using the default table if appropriate.
		 */
		if(unitNum == 0) {
			sprintf(fileName, "%s%s%s/%s", 
				IO_CONFIG_DIR, driverName, IO_BUNDLE_EXTENSION,
				IO_DEFAULT_TABLE_FILENAME);
			if(stat(fileName, statBuf)) {
				vprintf(("No Default table for %s\n", 
					driverName));
				return CR_NoInstance;
			}
			fprintf(stderr, "Using Default table for %s\n",
				driverName);
		}
		else {
			return CR_NoInstance;
		}
	}
	return CR_Success;
}
	
/*
 * Given driverName and unitNum, cause the kernel to probe the driver class
 * with the appropriate IOConfigTable info. Assumes that the driver has 
 * already been loaded into the kernel's address space.
 *
 * Returns:
 *    	CR_NoInstance if no instance file found
 *	CR_Error if error occurred on _IOProbeDevice()
 *	CR_Abort if security violation in pre or post exec. 
 *	CR_Success if OK.
 */
static configReturn configDriver(const char *driverName, 
	int unitNum,
	BOOL doProbe,
	BOOL doPreExec)
{
	char 		fileName[MAXPATHLEN];
	struct stat 	statBuf;
	int 		fd;
	vm_offset_t 	vm;
	IOReturn 	rtn;
	char 		query[100];
	configReturn 	crtn = CR_Success;
	
	if ((crtn = getInstanceFile(driverName, fileName, unitNum, &statBuf))
		    != CR_Success) {
		return crtn;
	}
	
	sprintf(query, "Configure driver %s unit %d", driverName, unitNum);
	if(!inquire(query)) {
		return CR_Success;
	}	

	if(doPreExec) {
		switch(prePostExec(driverName, unitNum, PRELOAD)) {
		    case CR_Success:	// OK or no file specified
		    	break;
		    case CR_Error:	// exited with non-zero status
		    default:
		    	return CR_NoInstance;
		    case CR_Abort:    	// security violation detected
		    	return CR_Abort;
		}
	}
	
	fd = open(fileName, O_RDONLY);
	if(fd < 0) {
		vprintf(("Can\'t open Instance file for %s instance %d "
			"(errno %d)\n",
			driverName, unitNum, errno));
		return CR_NoInstance;
	}
	if (doProbe) {
	    if(map_fd(fd, 
			    0,		// file offset
			    &vm,
			    TRUE,		// find_space
			    statBuf.st_size)) {
		    vprintf(("Can\'t read Instance file for %s instance %d "
			    "(errno %d)\n",
			    driverName, unitNum, errno));
		    return CR_Error;
	    }
	    rtn = _IOProbeDriver(device_master_self(),
		    (unsigned char *)vm, 
		    statBuf.st_size);
	    if(rtn) {
		    fprintf(stderr, "_IOProbeDriver: %s, device %s unit %d\n", 
			    [IODevice stringFromReturn:rtn], driverName,
			    unitNum);
		    crtn = CR_Error;
	    }
	    vm_deallocate(task_self(), vm, statBuf.st_size);
	}
	close(fd);

	/*
	 * Do post-exec.
	 */
	if(crtn == CR_Success) {
		switch(prePostExec(driverName, unitNum, POSTLOAD)) {
		    case CR_Success:	// OK or no file specified
		    case CR_Error:	// exited with non-zero status - so 
		    			//    what?
		    default:
			break;
		    case CR_Abort:    	// security violation detected
			crtn = CR_Abort;
		}
	}
	return crtn;
}

/*
 * Verify protections in this driver's bundle to make sure nothing is 
 * writable by anyone other than root.
 */
static BOOL securityCheck(const char *driverName)
{
	char path[MAXPATHLEN];
	
	sprintf(path, "%s%s%s", 
		IO_CONFIG_DIR, driverName, IO_BUNDLE_EXTENSION);
	return securityCheckDir(path);
}

/*
 * Check security of fully-specified path. Cwd will be the same on exit 
 * as on entry. Returns YES if security violation found.
 */
 
/*
 * Why aren't these defined in stat.h for non-posix builds!?
 */
#ifndef	S_IWGRP
#define S_IWGRP	0000020
#define S_IWOTH	0000002
#endif	S_IWGRP

static BOOL securityCheckDir(const char *path)
{
	char 		newdir[MAXPATHLEN];
  	struct direct 	**namelist = NULL;
	int 		i;
	int 		numEntries;
	char 		cwd[MAXPATHLEN];
	BOOL 		brtn;
	struct stat 	statb;
	int 		rtn;
	char		*node;
	
	/*
	 * Cwd to desired directory to optimize the stats we have to do...
	 */
	if(getwd(cwd) == 0) {
		fprintf(stderr, cwd);
		fprintf(stderr, "driverLoader: getwd() failed\n");
		return YES;
	}	
	chdir(path);
	numEntries = scandir(path, &namelist, NULL, NULL);
	if(numEntries < 0) {
		fprintf(stderr, "driverLoader: scandir(%s) error\n", path);
		brtn = YES;
		goto out;
	}
	
	/*
	 * Stat everything in the directory except "..". Follow symlinks.
	 */
	for(i=0; namelist[i]; i++) {
		node = namelist[i]->d_name;
		node[namelist[i]->d_namlen] = '\0';
		if(strcmp(node, "..") == 0) {
			continue;
		}
		rtn = stat(node, &statb);
		if(rtn) {
			fprintf(stderr, "Could not access %s/%s\n", 
				path, node);
			brtn = YES;
			goto out;
		}
		if(statb.st_uid != 0) {
			fprintf(stderr, "driverLoader: file %s/%s is not"
				" owned by root; aborting\n", 
				path, namelist[i]->d_name);
			brtn = YES;
			goto out;
		}
		if(statb.st_mode & (S_IWGRP | S_IWOTH)) {
			fprintf(stderr, "driverLoader: file %s/%s is writable;"
				" aborting\n", path, namelist[i]->d_name);
			brtn = YES;
			goto out;
		}	
		if((strcmp(node, ".") != 0) && 
		   (statb.st_mode & S_IFMT) == S_IFDIR) {
			/*
			 * Descend, rescursively...
			 */
			sprintf(newdir, "%s/%s", path, node);
			if(securityCheckDir(newdir)) {
				brtn = YES;
				goto out;
			}
		}
	}
	brtn = NO;
out:
	chdir(cwd);
	if(namelist) {
		for(i=0; i<numEntries; i++) {
			free(namelist[i]);
		}
		free(namelist);
	}
	return brtn;
}

/*
 * Exec Pre- or Post-Load binary for specified driver and unit.
 * Returns:
 *	CR_Success  if no file specified
 *	CR_Success  if executable exited with zero status
 *	CR_Success  if inquire() said "don't do it"
 *	CR_Error    if executable exited with non-zero status
 *	CR_Abort    if security violation detected
 */
static configReturn prePostExec(const char *driverName, int unit, prePost pre)
{
	IOConfigTable 	*configTable;
	const char	*key;
	const char 	*value;
	char 		driverPath[MAXPATHLEN];
	char		execString[2*MAXPATHLEN];
	configReturn	crtn;
	char		query[100];
	
	configTable = [IOConfigTable newForDriver:driverName unit:unit];
	if(configTable == nil) {
		if(unit == 0) {
			/*
			 * Try default table.
			 */
			configTable = [IOConfigTable 
				newDefaultTableForDriver:driverName];
			if(configTable == nil) {
				return CR_Success;
			}
		}
		else {
			return CR_Success;
		}
	}
	if(pre == PRELOAD) {
		key = IO_PRE_LOAD;
	}
	else {
		key = IO_POST_LOAD;
	}
	value = [configTable valueForStringKey:key];
	if(value == NULL) {
		return CR_Success;
	}
	
	/*
	 * Possible security violations are:
	 *	-- leading '/'
	 *	-- a ".." anywhere in the path 
	 */
	if(value[0] == '/') {
		crtn = CR_Abort;
		goto out;
	}
	if(strstr(value, "..")) {
		crtn = CR_Abort;
		goto out;
	}
	
	sprintf(query, "Execute %s file (%s)", 
		((pre == PRELOAD) ? "Pre-Load" : "Post-Load"), value);
	if(!inquire(query)) {
		return CR_Success;
	}	
		
	/*
	 * Looks good; let's do it. Cwd to driver's bundle, cons up a 
	 * system() string and let fly. Don't assume that "." is in current 
	 * shell's path...
	 */
	sprintf(driverPath, "%s%s%s", 
		IO_CONFIG_DIR, driverName, IO_BUNDLE_EXTENSION);
	chdir(driverPath);
	sprintf(execString, "%s/%s Instance=%d", 
		driverPath, value, unit);
	if(system(execString)) {
		dprintf("prePostExec: execString %s\n", execString, 2,3,4,5);
		dprintf("   cwd %s\n", driverPath, 2,3,4,5);
		crtn = CR_Error;
	}
	else {
		crtn = CR_Success;
	}
out:
	[configTable free];
	return crtn;
}

/* end of driverLoader.m */
