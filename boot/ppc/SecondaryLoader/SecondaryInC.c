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
 /* -*- mode:C++; tab-width: 4 -*- */

/*
  This is the Tesla/Maxwell/Copland/MacOS8/Rhapsody secondary loader.
  It's loaded by Open Firmware.  It either loads a kernel or another
  stage of booting, as required by Powers that Don't Be (pardon the pun
  and the Ebonics).

  Copyright (c) 1996-97, Apple Computer Inc.  All rights reserved.
*/

/*
  Note: HFS booting has not been tested since the Secondary Loader
  sources were split into multiple .c files.  There might be a few wrinkles...
*/

/*
	One thing about Open Firmware.  If you get to this Secondary
	Loader, you had better find something useful to boot.  There's no
	way to exit from an Open Firmware client program (like this one)
	to continue the Open Firmware code that started you where it left
	off with a LOAD/GO or BOOT command.  (Of course I know about CHAIN
	and stuff like that.  But that doesn't CONTINUE Open Firmware's
	execution, it just starts something new.)  Therefore, all search
	path logic to provide the nice Macintosh style user experience to
	"find something to boot from" must be handled HERE.  But it must
	ALSO be done in the thing that finds and loads the Secondary
	Loader.
	
	Some days it just doesn't pay to get out of bed.
*/

/*
	TO DO:

	* Merge kernBootStruct structure with KernelParams.h structure
	* Add restart and poweroff buttons to DeathScreen somehow

*/

#ifndef HFS_SUPPORT
#define HFS_SUPPORT	0
#endif

//#undef OF_DEBUGGING
#ifndef OF_DEBUGGING
#define OF_DEBUGGING	0
#endif

#include <Types.h>
#include <BootBlocksPriv.h>
// #include "/usr/include/setjmp.h"
#include <stdio.h>
#include <string.h>
#include <saio_types.h>
#include <memory.h>

#include <KernelParams.h>
#include "kernBootStruct.h"

#include "SecondaryLoaderOptions.h"
#include "SecondaryLoader.h"
#include "Display.h"
#include "HFSSupport.h"

#include "images.h"

// Make nonzero for trendy serialport style progress bar...
#ifndef kShowProgress
#define kShowProgress 0
#endif

// Define nonzero to ignore all secondary loader extensions
#ifndef defeatExtensions
#define defeatExtensions 0
#endif

unsigned int slDebugFlag;

enum {
	kMaxLoadSize = 4 * 1024 * 1024,			// Maximum size of a kernel load image

	// Largest 2ldr image we will ever build (hopefully)
	kMaximumSecondaryLoaderImageSize = 256 * 1024,
	kCacheLineSize = 32					/* PowerPC's favorite cache line size */
};

ClientInterfacePtr gCIPointer;
int gBootPartition, gPartitions;
char *gKernelBSSAppendixP;				// Add to this to alloc more BSS appendix data
boot_args *gKernelParamsP;				// BSS appendix struct we pass to kernel main
UInt32 gKernelEntryP;

int gSymbolTableLen, gSymbolTableAddr = 0x1200000;
int gStringTableLen, gStringTableAddr = 0x1280000;
int gSymTabLen = 0, gSymTabAddr = -1;

// loadmacho sets this to byte after highest used for kernel data
extern UInt32 gTopOfData;

static char loadFileName[256] = "mach_kernel"; 	// Can be overridden by boot-file value
static char loadedFlagString[ 128 ];		// Kernel flags from System.config
static int partitionNumber;
static UInt32 tVector[2];			// MrC thinks this is not a live var unless it's static!?
static UInt32 lowestExtensionBase;		// Base of area to allocate extension memory
static UInt32 extensionBase;			// Alloc pointer (grows upward) for extensions
static UInt32 cachePartitionOffset;		// Offset last part # in ReadPartitionBlocks
static int cachePartitionNumber;		// Part# of cache for ReadPartitionBlocks
static CICell bootIH;					// Last AccessDevice device (0 if none)


// Struct we use to keep track of extensions' memory span so we can
// free them on DeaccessDevice calls
typedef struct ExtensionDescriptor {
	UInt32 base;						// Virtual (and physical) base of region
	UInt32 size;						// Size of region in bytes
} ExtensionDescriptor;

enum {
	kMaximumExtensions = 10				// Largest # extensions on a single disk device
};
static ExtensionDescriptor extensions[kMaximumExtensions];

void SecondaryLoaderMain (void *junk1, void *junk2, ClientInterfacePtr ciPointer);

extern void GetDeviceTree ();

static void InstallDebuggerAndDisassembler ();

// PowerMac ABI style Transition Vector to enter our main entry point
const UInt32 SecondaryLoaderMainTVector [2] = {(UInt32) SecondaryLoaderMain, 0};

void Interpret (char *forth);
CICell InterpretReturn1 (char *forth);

void FindDrivers( void * saRef );

void FindNetDrivers( void * saRef );
static int getNetDrivers(int op);
static void getOFDeviceAddr(char *pathname);
static int openftp(char *name);
static int open2(char *path, int perm); 
static char *readNetDrivers();
static void convert(char *buf,char ch1,char ch2);
static char *readBootInfo(char *pathname, int (**loaderF) (char *bootFileP));
static int networkLoadKernel (char *bootFileP);
#define ReadFile(a,b) diskReadFile(a,b) 
char * diskReadFile( char * path, int * len); 
static char *FindStringKey( const char * config, const char * key, char * buf );
static int fileLoadKernel (char *bootFileP);

// Declare the routines for the patch vectors as extern
#define DO_VECTOR(F,R,P)	extern R f##F P;
SECONDARY_LOADER_VECTORS
#undef DO_VECTOR

static SecondaryLoaderVector patchVectors = {
	kSecondaryLoaderVectorVersion,

#define DO_VECTOR(F,R,P)	1+
	SECONDARY_LOADER_VECTORS	0, 		// Count of the entries in the vector
#undef DO_VECTOR

#define DO_VECTOR(F,R,P)	f##F,
	SECONDARY_LOADER_VECTORS			// The actual vector function pointers
#undef DO_VECTOR

	0									// List terminator
};

SecondaryLoaderVector *gSecondaryLoaderVectors = &patchVectors;


static LoaderJumpBuffer failureJumpBuffer;


#ifdef __GNUC__
int CallCI (CIArgs *argsP)
{
    int ret;
    volatile unsigned long *ptr;

    ret = (*gCIPointer) (argsP);
    ptr = (unsigned long *)0xff80801c;
    *ptr = (unsigned long)0;
    return ret;
}


void fDataToCode (void *base, UInt32 length)
{
    UInt32 newBase = (UInt32) base & -kCacheLineSize;
    UInt32 newLength = (((UInt32) base + length + kCacheLineSize - 1)
						& -kCacheLineSize) - newBase;
    UInt32 newEnd = newBase + newLength;
    register UInt32 a;// asm ("7");		// R7 is my lucky register

    for (a = newBase; a < newEnd; a += kCacheLineSize) {
		asm ("dcbf 0,%0" : /* no outputs */ : "g" (a));
		asm ("icbi 0,%0" : /* no outputs */ : "g" (a));
	}
}


void bcopy (const void *srcP, void *dstP, /*UInt32*/size_t length)
{
	memcpy (dstP, srcP, length);
}


void bzero (void *dstP, UInt32 length)
{
	memset (dstP, 0, length);
}

void fMoveBytes (void *dstP, void *srcP, UInt32 length)
{
	memcpy (dstP, srcP, (size_t)length);
}
#endif


int fLoaderSetjmp (jmp_buf env)
{
	setjmp (env);
}


void fLoaderLongjmp (jmp_buf env, int value)
{
	printf ("LoaderLongJmp (... %d)\n", value);
	longjmp (env, value);
}


void fBailToOpenFirmware ()
{
	CIArgs ciArgs;

	ciArgs.service = "exit";
	ciArgs.nArgs = 0;
	ciArgs.nReturns = 0;
	CallCI (&ciArgs);				// Never to return from this call
}


void fStartSystem7 ()
{
	CIArgs ciArgs;

	ciArgs.service = "boot";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 0;
	ciArgs.args.boot.bootspec = "/AAPL,ROM";
	CallCI (&ciArgs);				// Never to return from this call
}


void fShowMessage (char *message)
{
	CIArgs ciArgs;

	ciArgs.service = "interpret";
	ciArgs.nArgs = 2;
	ciArgs.nReturns = 1;
	// Display a NUL terminated string followed by a CRLF
	ciArgs.args.interpret_1_0.forth = "9999 decode-string type cr 2drop";
	ciArgs.args.interpret_1_0.arg1 = (CICell) message;
	CallCI (&ciArgs);
}


// This gets us out past the most recent setjmp on failureJumpBuffer.
// Presently, the only setjmp call is at the top of TryPartition, so
// only in calls nested within that routine can FatalError be used to
// longjmp out.
void fFatalError (char *message)
{
	VCALL(ShowMessage) (message);
	VCALL(LoaderLongjmp) (failureJumpBuffer, 1);
}


void Interpret (char *forth)
{
	CIArgs ciArgs;

	ciArgs.service = "interpret";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_0_0.forth = forth;
	CallCI (&ciArgs);
}


CICell InterpretReturn1 (char *forth)
{
	CIArgs ciArgs;

	ciArgs.service = "interpret";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_0_1.forth = forth;
	CallCI (&ciArgs);
	return ciArgs.args.interpret_0_1.return1;
}


void fSpinActivity ()
{
}


static char toUpper (const char c)
{
	if (c >= 'a' && c <= 'z')
		return c - ('a' - 'A');
	else
		return c;
}


// Compare two NUL-terminated C strings for equality in a case-insensitive manner.
// Returns true if the strings ARE equal, false otherwise.
int fStringsAreEqualCaseInsensitive (char *string1, char *string2)
{
	// Testing just string1 for NUL is OK since != test below effectively does string2
	while (*string1) {
		if (toUpper (*string1++) != toUpper (*string2++)) return false;
	}

	return (*string2 == 0);			// We can only get here if *string1 is 0
}


// Return the log base 2 of k.  Deliberately defined such that log2(0) = 0.
static unsigned long log2 (unsigned long k)
{
	unsigned long log2;

	if (k == 0) return 0;			// Useful special case.
	for (log2 = 0; k; ++log2, k >>= 1) ;
	return log2 - 1;
}


static int isPowerSurgeOF ()
{
	CIArgs ciArgs;
	
	ciArgs.service = "interpret";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_0_1.forth =
		"\" /openprom\" find-package if "
			"\" model\" rot GPP$ if "
				"drop \" Open Firmware, 1.0.5\"(00)\" comp 0= "
			"else "
				"0 "
			"then "
		"else "
			"0 "
		"then";
	CallCI (&ciArgs);
	return ciArgs.args.interpret_0_1.catchResult == 0
		&& ciArgs.args.interpret_0_1.return1;
}


UInt32 fClaimMemory (CICell virtual, CICell size, CICell alignment)
{
	CIArgs ciArgs;

	// Correct for bug in ROM based O/F on PowerSurge machines (version <= 1.0.5)
	if (alignment != 0 && isPowerSurgeOF ()) alignment = log2 (alignment);

	// All this to get around a completely dysfunctional "claim" client interface
	// callback in 1.0.5!  Allocations virtual space according to the rules of
	// MMU's "claim" method and its parameters.  Then maps logical == physical
	// with mode=10 on the resulting address range.
	ciArgs.service = "interpret";
	ciArgs.nArgs = 4;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_3_1.arg1 = alignment;
	ciArgs.args.interpret_3_1.arg2 = size;
	ciArgs.args.interpret_3_1.arg3 = virtual;
	ciArgs.args.interpret_3_1.forth =	// ( virt size align -- allocated-virt )
#if kDebugLotsDef
		".\" ClaimMem:\" .s cr "
#endif
		"$clm"
		;

	if (CallCI (&ciArgs) != 0 || ciArgs.args.interpret_3_1.catchResult != 0) return 0;
	return ciArgs.args.interpret_3_1.return1;
}


void fReleaseMemory (CICell virtual, CICell size)
{
	CIArgs ciArgs;

	// Release physically contiguous RAM of size bytes claimed and mapped earlier
	ciArgs.service = "interpret";
	ciArgs.nArgs = 3;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_2_0.arg1 = size;
	ciArgs.args.interpret_2_0.arg2 = virtual;
	ciArgs.args.interpret_2_0.forth =				// ( virtual size -- )
#if kDebugLotsDef
		".\" RelMem:\" 2dup . . cr "
#endif
		"over \" translate\" ^mmu "		// Find out physical base
		"^on0 "							// Bail if translation failed
		"drop "							// Leaving phys on top of stack
		"2dup \" unmap\" ^mmu "			// Unmap the space first
		"2dup \" release\" ^mmu "		// Then free the virtual pages
		"\" release\" ^mem "			// Then free the physical pages
		;
	CallCI (&ciArgs);
}


void fTryPartition (int tryPartitionNumber)
{
}


void fReadPartitionBlocks (UInt32 partitionNumber, void *buffer,
						  UInt32 blockNumber, UInt32 nBlocks)
{
	CIArgs ciArgs;

#if 0
	printf ("ReadPartitionBlocks (%d, 0x%08X, %d, %d)\n",
			partitionNumber, buffer, blockNumber, nBlocks);
#endif

	if (partitionNumber != kReadRawDisk) {

		if (partitionNumber != cachePartitionNumber) {
			Partition part;

#ifdef DEBUG
                        if( slDebugFlag & kDebugLots) VCALL(ShowMessage) ("pmoff");
#endif
			VCALL(ReadPartitionBlocks) (kReadRawDisk, &part, partitionNumber, 1);
			cachePartitionNumber = partitionNumber;
			cachePartitionOffset = part.pmPyPartStart;
		}

		blockNumber += cachePartitionOffset;
	}
	
	VCALL(SpinActivity) ();

	// Note that this relies on the previous FORTH definition of word "slReadBlocks"
	// sticking around so we can use it.
	ciArgs.service = "interpret";
	ciArgs.nArgs = 4;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_3_0.forth =
		"2ldr-spin"				// Show user we're still working on it...
		" slReadBlocks";			// ( buffer block# #blocks -- )
	ciArgs.args.interpret_3_0.arg1 = nBlocks;
	ciArgs.args.interpret_3_0.arg2 = blockNumber;
	ciArgs.args.interpret_3_0.arg3 = (CICell) buffer;
	CallCI (&ciArgs);
}


#if OF_DEBUGGING
static void InstallDebuggerAndDisassembler ()
{
	extern char *DebuggerSource[];
	int k;

	printf ("\nInstalling the PowerPC Open Firmware client program "
			"Debugger and Disassembler: 0x%08X\n", DebuggerSource);
	for (k = 0; DebuggerSource[k]; ++k) Interpret (DebuggerSource[k]);
}
#endif


static void patchStupidOF105 ()
{
	/*****************************************************************************
		Since I figured out all this stuff, I thought I would save it:
		
		In the CONTROL.of driver (vci0/control) in 1.0.5 Open Firmware in ROM:
			HEADERLESS name:	Is at EXTERNAL name HEX offset:
			' PING-CONTROL		' COLOR@ 430 -
			' MY-CLOSE			' COLOR@ 40 -
			' REGS				' COLOR@ C90 -

		In the VIA-CUDA.of driver (/bandit/gc/via-cuda) in 1.0.5 Open Firmware in ROM:
			HEADERLESS name:	Is at EXTERNAL name HEX offset:
			' setByteACK		' WRITE 548 -
			' setTIP			' WRITE 4D8 -

	*****************************************************************************/

#if USE_LAME_BUILTIN_ROM_CONTROL_DRIVER
	Interpret ("dev /bandit/gc/via-cuda");

	Interpret (
		"hex "
		
		// Fix VIA-CUDA's WRITE method to add delay before setting
		// input mode and to clear byteAck flag at end of WRITE.
		"' write value &W "
		": -&We &W swap - execute ; "
		": P1 4D8 -&We false 548 -&We ; "
		
		// Add false setByteAck at end
		"&W FC + ' P1 BLpatch "
		
		// Add 2ms delay before setting input mode
		": P2 0c 2 ms ; "
		"&W E0 + ' P2 BLpatch "
		// device-end
	);
		
		// Fix CONTROL's FILL-RECTANGLE not to pop too many things from the stack
	Interpret ("dev vci0/control");
	Interpret (
		"60000000 ' fill-rectangle AC + code! "		// This is a PowerPC nop instruction
		
		// Since we must fix three methods the same way, define a new
		// function to fix the Xs and Ys which are swapped in
		// DRAW-RECTANGLE, FILL-RECTANGLE and READ-RECTANGLE.  Then
		// fix 'em.
		": z1 10 + dup @ 4+ over code! 10 + dup @ 4- swap code! ; "
		"' draw-rectangle z1 "
		"' read-rectangle z1 "
		"' fill-rectangle z1 "
	);

	Interpret ("device-end");
#else
	{
		extern char *Control2Source[];
		int k;

		printf ("\nInstalling bugfix replacement device drivers: 0x%08X\n",
				Control2Source);

		for (k = 0; Control2Source[k]; ++k) {
			Interpret (Control2Source[k]);
		}
	}
#endif
	
	// Install our sick O/F client program debugger and PowerPC disassembler
#if OF_DEBUGGING
	InstallDebuggerAndDisassembler ();
#endif
}

static unsigned char gKeyMap[ 16 ];

void InitializeHotkeys(void)
{
	CIArgs ciArgs;

    // Define word for key map
    ciArgs.service = "interpret";
    ciArgs.nArgs = 2;
    ciArgs.nReturns = 1;
    ciArgs.args.interpret_1_0.forth = "value gKeyMap";
    ciArgs.args.interpret_1_0.arg1 = (CICell) gKeyMap;
    CallCI (&ciArgs);

    Interpret (
        ": update-key-map"
        " \" get-key-map\" \" kbd\" open-dev $call-method drop"
        " gKeyMap"                 // or into current state
        " 4 0 do swap"             // ( gKeyMap current-map )
        " dup @ >r 4+ swap"        // ( current-map++ gKeyMap )
        " dup dup @ r> or swap !"  // ( current-map++ gKeyMap )
        " 4+ loop ;"

        // Update global keymap first time
        " update-key-map"
#if 1
		// Check for 'v' - kill O/F stdout if not down
		" gKeyMap 1+ c@ not h# 40 and if"
            " 0 stdout !"
		" then"
#endif
    );
}

void DefineSpinIndicator ()
{
	CIArgs ciArgs;

	// Create a time-based spin indicator for TFTP downloads
	Interpret ("0 value last-spin 0 value spin-stage");

	// Define a word for our background pixel value since it's only
	// known to the C world at this point
	ciArgs.service = "interpret";
	ciArgs.nArgs = 2;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_1_0.forth = "value spin-bg";
	ciArgs.args.interpret_1_0.arg1 = (CICell) 0; //kBackgroundPixel;
	CallCI (&ciArgs);

	// Define a word for our icon address value since it's only
	// known to the C world at this point
	ciArgs.service = "interpret";
	ciArgs.nArgs = 2;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_1_0.forth = "value spin-icon";
	ciArgs.args.interpret_1_0.arg1 = (CICell) waitCursors;
	CallCI (&ciArgs);

	// Define words for our icon's dimensions
	ciArgs.service = "interpret";
	ciArgs.nArgs = 2;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_1_0.forth = "value spinW";
	ciArgs.args.interpret_1_0.arg1 = (CICell) SPIN_WIDTH;
	CallCI (&ciArgs);

	Interpret (
		": stage>R"			// ( icon stage# -- x y width height )
		" 100 * +"          // ( icon )
		" Dwidth 10 - 2/ "
		" Dheight d# 480 - 2/ d# 260 +"
		" spinW dup"
		" ;"
	);

	// Define our spin routine
	Interpret (
		": 2ldr-spin"
		" get-msecs dup last-spin - d# 111 >= if"	// Do nothing if < 111ms has passed
                    " to last-spin"
                    // Calculate new step #
                    " spin-stage 1+ dup to spin-stage"

                    // Update global keymap each 9 spins (spin-stage)
                    // " dup 9 mod 0= if ( update-key-map ) then"

                    // Draw new step (spin-stage)
                    " 3 mod spin-icon swap stage>R ^drect"
		" else"
                    " drop"
		" then"
		" ;"
	);

    Interpret (
            ": drawImage { image dy width height }"
            " image"
            " Dwidth width - 2/ "
            " Dheight height - 2/ dy +"
            " width height"
            " ^drect"
            " ;"
    );

    ciArgs.service = "interpret";
    ciArgs.nArgs = 5;
    ciArgs.nReturns = 1;
    ciArgs.args.interpret_4_0.arg1 = BIG_HEIGHT;
    ciArgs.args.interpret_4_0.arg2 = BIG_WIDTH;
    ciArgs.args.interpret_4_0.arg3 = BIG_DY;
    ciArgs.args.interpret_4_0.arg4 = (CICell) bigImage;
    ciArgs.args.interpret_4_0.forth = "drawImage";
    CallCI (&ciArgs);

	Interpret ("dev /packages/obp-tftp");

	// Surround patch the LOAD method to set OUR spin routine exec
	// token since the LOAD *command* rudely always sets its lame
	// one...
	Interpret (
		": load"
                    " ['] 2ldr-spin to spin"
                    " load"
		" ;"
	);
	Interpret ("device-end");
}


void fTryAllPartitionsOnDisk (int nPartitions, int partitionNumberToSkip)
{
	Partition part;
	UInt32 requiredStatus;
	int pass;

	// If we get back after trying the default we need to do the
	// laborious partition map enumeration looking for bootable
	// partitions.  We do so carefully avoiding any attempt to retry
	// the partitionNumberToSkip partition.  The first pass gives
	// preference for partitions marked with pmPartStatus with the
	// high order bit (boot priority bit) set.
	for (requiredStatus = 0x80000037, pass = 0;
		 pass < 2;
		 requiredStatus = 0x37, ++pass)
	{
		int n;

		for (n = 1; n <= nPartitions; ++n) {

			// Avoid retry of default partition
			if (n == partitionNumberToSkip) continue;
			
#ifdef DEBUG
                        if( slDebugFlag & kDebugLots) VCALL(ShowMessage) ("get pmE");
#endif
			VCALL(ReadPartitionBlocks) (kReadRawDisk, &part, n, 1);

			// Skip partitions that aren't Rhapsody FFS
			if (!VCALL(StringsAreEqualCaseInsensitive) (part.pmParType,
														"Apple_Rhapsody_FFS"))
				continue;

			// Skip parts that aren't mountable or aren't marked as containing valid data
			if ((part.pmPartStatus & requiredStatus) != requiredStatus) continue;

			// This looks like a live one -- try it!		
			VCALL(TryPartition) (n);
		}
	}
	
	// If we return, we can assume that we have, sadly, failed.
}


int fAccessDevice (CICell devIH, SecondaryLoaderVector *secondaryLoaderVectorsP)
{
	CIArgs ciArgs;
	Partition part;
	int n;
	int nPartitions;
	
	if (bootIH != 0) return gPartitions;

	cachePartitionNumber = 0;		// Destroy existing cache of partition information

	// Tell Open Firmware world about our nifty new device ihandle
	ciArgs.service = "interpret";
	ciArgs.nArgs = 2;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_1_0.arg1 = devIH;
	ciArgs.args.interpret_1_0.forth = "to bIH";
	CallCI (&ciArgs);
	
	if (bootIH != 0) VCALL(DeaccessDevice) (bootIH, secondaryLoaderVectorsP);

#ifdef DEBUG
        if( slDebugFlag & kDebugLots) VCALL(ShowMessage) ("Access");
#endif
	bootIH = devIH;

	// Determine the lowest address we can use for extension memory.
	// This done a bit wastefully and pretty cheesily: we use the
	// address of a static variable plus our maximum possible size
	// rounded up to the nearest page boundary to find a chunk of
	// memory just beyond our own image.  A static variable is OK
	// since our data is part of our image.
	lowestExtensionBase = ((UInt32) &lowestExtensionBase
						   + kMaximumSecondaryLoaderImageSize
						   + kPageSize - 1)
		& -kPageSize;

	// Reset our memory allocation pointer
	extensionBase = lowestExtensionBase;

	// Read first partition map block so we can tell how many
	// partitions there are on the disk
	VCALL(ReadPartitionBlocks) (kReadRawDisk, &part, 1, 1);
	gPartitions = nPartitions = part.pmMapBlkCnt;

	// Now install all Secondary Loader Extensions found among this disk's partitions.
	for (n = 1; n <= nPartitions; ++n) {
		VCALL(ReadPartitionBlocks) (kReadRawDisk, &part, n, 1);
		
		// If partition type is right, load the extension and call its entry point
		if (!defeatExtensions
			&& VCALL(StringsAreEqualCaseInsensitive) (part.pmParType,
										  kSecondaryLoaderExtensionPartitionType))
		{
			int k;

			// Look for an empty extensions descriptor array slot to store
			// this extension in			
			for (k = 0; k < kMaximumExtensions; ++k) {

				if (extensions[k].size == 0) {
					UInt32 nBytes = (part.pmPartBlkCnt * kBlockSize + kPageSize - 1)
						& -kPageSize;

					extensions[k].base = VCALL(ClaimMemory) (extensionBase, nBytes, 0);
					if (extensions[k].base == nil) {

						if (kShowProgress) {
							VCALL(ShowMessage) ("?ext mem");
//							CIbreakpoint ();
						}
						break;
					}

					// Read the extension into memory and make SURE i-cache entries
					// for that range are flushed
					VCALL(ReadPartitionBlocks) (n, (void *) extensionBase, 0,
												part.pmPartBlkCnt);
					VCALL(DataToCode) ((void *) extensionBase, nBytes);
					
					// Successful load.  We get here when we get a valid extension
					// loaded.  Call the code we just loaded, passing every useful
					// parameter we can think of.  Extensions return ZERO if they
					// are successful, or nonzero to indicate we should ignore them.
					tVector[0] = extensionBase;	// PC to start next stage
					tVector[1] = 0;				// Start with NIL rtoc value

					if (kShowProgress) VCALL(ShowMessage) ("Ext");
					if (((ExtensionEntryPointer) tVector) (devIH,
														   gSecondaryLoaderVectors,
														   gCIPointer)
						== 0)
					{
						// Extension is happy, so remember it
						extensions[k].size = nBytes;	// This marks slot as used too
						extensionBase += nBytes;		// Keep track of allocated memory
						if (kShowProgress) VCALL(ShowMessage) ("OK");
					} else {
						// Extension says no soap, so just free its memory and get
						// on with life
						VCALL(ReleaseMemory) (extensionBase, nBytes);
						if (kShowProgress) VCALL(ShowMessage) ("~OK");
					}
					
					break;
				}
			}

			// If we fall out to here we either DID install the extension or we failed
			// to do so -- either way, we continue to try to boot from the device.
		}
	}

	return nPartitions;	
}


void fDeaccessDevice (CICell devIH, SecondaryLoaderVector *secondaryLoaderVectorsP)
{
#pragma unused (devIH, secondaryLoaderVectorsP)
	int k;

#ifdef DEBUG
        if( slDebugFlag & kDebugLots) VCALL(ShowMessage) ("Deaccess");
#endif

	// Free the extensions' space
	for (k = 0; k < kMaximumExtensions; ++k) {
		if (extensions[k].size == 0) continue;			// Skip empty slots
		VCALL(ReleaseMemory) (extensions[k].base, extensions[k].size);
		extensions[k].size = 0;							// Mark slot as empty
	}
	
	// We COULD NIL out the FORTH value "bIH" here, but that takes space
	// and isn't really necessary.  Just zeroing bootIH is enough.
	bootIH = 0;			// Remember there's no device accessible right now
}


// Retrieve a pointer to the NUL-terminated C string property value of the specified
// property on the specified device tree node.
char *fGetPackagePropertyString (CICell phandle, char *propertyName)
{
	CIArgs ciArgs;
	
	ciArgs.service = "interpret";
	ciArgs.nArgs = 4;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_3_1.arg1 = phandle;
	ciArgs.args.interpret_3_1.arg2 = strlen (propertyName);
	ciArgs.args.interpret_3_1.arg3 = (CICell) propertyName;
	ciArgs.args.interpret_3_1.forth =	// ( propname propnamelen phandle -- propptr|0 )
		"GPP$ if drop else 0 then";

	if (CallCI (&ciArgs) != 0 || ciArgs.args.interpret_3_1.catchResult != 0) return 0;

	return (char *) ciArgs.args.interpret_3_1.return1;
}


CICell fGetParentPHandle (CICell phandle)
{
	CIArgs ciArgs;
	ciArgs.service = "parent";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 1;
	ciArgs.args.parent.childPhandle = phandle;
	if (CallCI (&ciArgs) != 0) return 0;
	return ciArgs.args.parent.parentPhandle;
}


CICell fGetPeerPHandle (CICell phandle)
{
	CIArgs ciArgs;
	ciArgs.service = "peer";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 1;
	ciArgs.args.peer.phandle = phandle;
	if (CallCI (&ciArgs) != 0) return 0;
	return ciArgs.args.peer.peerPhandle;
}


CICell fGetChildPHandle (CICell phandle)
{
	CIArgs ciArgs;
	ciArgs.service = "child";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 1;
	ciArgs.args.child.phandle = phandle;
	if (CallCI (&ciArgs) != 0) return 0;
	return ciArgs.args.child.childPhandle;
}


CICell fGetNextProperty (CICell phandle, char *prevP, char *thisP)
{
	CIArgs ciArgs;

	ciArgs.service = "nextprop";
	ciArgs.nArgs = 3;
	ciArgs.nReturns = 1;
	ciArgs.args.nextprop.phandle = phandle;
	ciArgs.args.nextprop.previous = prevP;
	ciArgs.args.nextprop.buf = thisP;
	if (CallCI (&ciArgs) != 0) return -1;
	return ciArgs.args.nextprop.flag;
}


CICell fGetProperty (CICell phandle, char *name, void *bufP, CICell buflen)
{
	CIArgs ciArgs;

	ciArgs.service = "getprop";
	ciArgs.nArgs = 4;
	ciArgs.nReturns = 1;
	ciArgs.args.getprop.phandle = phandle;
	ciArgs.args.getprop.name = name;
	ciArgs.args.getprop.buf = bufP;
	ciArgs.args.getprop.buflen = buflen;
	if (CallCI (&ciArgs) != 0) return -1;
	return ciArgs.args.getprop.size;
}


// NOTE that this evalutes "C" a bunch of times -- don't use side-effect parameters
#define isHexChar(C)	((C) >= '0' && (C) <= '9' \
						 || (C) >= 'A' && (C) <= 'F' \
						 || (C) >= 'a' && (C) <= 'f')


// Format value as unsigned hex at "p" returning updated "p" pointing after last
// character written into the buffer.
static char *formatHex (char *p, UInt32 value)
{
	static const char hexDigits[] = "0123456789ABCDEF";
	int n;
	int nDigits;
	UInt32 temp;

	// First count the number of digits we'll store by walking through
	// value til it's zero
	for (nDigits = 0, temp = value; temp != 0; temp >>= 4) ++nDigits;
	if (nDigits == 0) nDigits = 1;		// Always store at least one zero

	// Now format the digits into the buffer
	for (temp = value, n = nDigits - 1; n >= 0; --n) {
		p[n] = hexDigits[temp & 15];
		temp >>= 4;
	}

	return p + nDigits;
}


// Starting at "p" decode a hex number.  Store the resulting value
// through *valueP and return the updated "p" to point to the
// character that terminated the scan.
static char *eatHex (char *p, UInt32 *valueP)
{
	UInt32 value = 0;
	
	while (isHexChar (*p)) {
		int ch = *p++;
		value <<= 4;
		value |=	ch >= 'a' ? ch - 'a' + 10 :
					ch >= 'A' ? ch - 'A' + 10 :
					ch - '0';
	}
	
	*valueP = value;
	return p;
}


void fTryThisUnit (CICell phandle, UInt32 unit)
{
	char path[400];
	CIArgs ciArgs;
	int k;
	char *p;
	int nPartitions;
	
	ciArgs.service = "package-to-path";
	ciArgs.nArgs = 3;
	ciArgs.nReturns = 1;
	ciArgs.args.packageToPath.phandle = phandle;
	ciArgs.args.packageToPath.buf = path;
	ciArgs.args.packageToPath.buflen = sizeof (path);
	
	if (CallCI (&ciArgs) != 0 || ciArgs.args.packageToPath.length < 0) return;
	
	// Find the right-most '@' before any '/' so we can put in our own unit #
	for (k = ciArgs.args.packageToPath.length - 1; k > 0; --k) {
		if (path[k] == '@' || path[k] == '/') break;
	}
	
	if (k == 0 || path[k] != '@') {		// No trailing '@' means we have to append one?
		k = ciArgs.args.packageToPath.length - 1;
		path[k++] = '@';
	} else {
		++k;							// Point past the last '@'
	}

	p = formatHex (path + k, unit);		// Replace any existing unit # with OURS
	*p = 0;								// NUL terminate the string
	
#ifdef DEBUG
        if( slDebugFlag & kDebugLots) {
		VCALL(ShowMessage) ("Unit");
		VCALL(ShowMessage) (path);
	}
#endif

	// Now open the resulting device specifier and give it a whirl
	ciArgs.service = "open";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 1;
	ciArgs.args.open.deviceSpecifier = path;
	if (CallCI (&ciArgs) != 0 || ciArgs.args.open.ihandle == 0) return;
	
	// Open happened OK, so try booting from it!
	nPartitions = VCALL(AccessDevice) (ciArgs.args.open.ihandle, gSecondaryLoaderVectors);
	VCALL(TryAllPartitionsOnDisk) (nPartitions, 0);

	// We do matching DeaccessDevice call lazily on next AccessDevice call (if any)
}


// Device tree looks like: (... (scsi-int:scsi (sd:block))) or
// (... (ata-int:ata (ad:block))) where the sd node has units 0..7 for
// a standard SCSI bus and 0..1 for a standard ATA "bus".  If there's
// a "name goes here" property on the "block" node, the unit# range or
// enumeration to try comes from that.  This permits things like
// FireWire which has a very LARGE possible set of unit numbers to
// describe for us those that are detected by the bus.

// If the parent node is not "scsi" or "ata" and no AAPL,units
// property exists, we assume the device is something wiggy like a PC
// Card that has only one unit (#0).

// AAPL,units property values must be a comma separated sequence in the following syntax:
//		startUnit [ '-' endingUnit ]
//	where
//		brackets enclose part of the specification that are optional
//				(brackets are metasyntax).
//		startUnit and endingUnit are hex numbers (only 0-9 and A-F or a-f allowed)
//			specifying the first unit to try and the last unit to try.  If startUnit
//			is less than lastUnit, the sequence is ascending.  Otherwise descending.
//			startUnit may equal endUnit, but it's a waste of string space since leaving
//			the "'-' endUnit" off the specification is equivalent.
//
//	Example:
//		0-F,42,100-F0		means do 0, 1, 2, .. 0E, 0F
//							then do 42,
//							then do from 100 down to 0F0.

void fTryThisDevice (CICell phandle)
{
	char *unitsP;
	char *deviceTypeP;
	
	// Ignore devices that aren't of type "block"
	deviceTypeP = VCALL(GetPackagePropertyString) (phandle, "device_type");

#ifdef DEBUG
        if( (slDebugFlag & kDebugLots) && deviceTypeP != nil) {
		VCALL(ShowMessage) ("TryDev");
		VCALL(ShowMessage) (deviceTypeP);
	}
#endif

	if (deviceTypeP == nil || !VCALL(StringsAreEqualCaseInsensitive) (deviceTypeP,
																	  "block"))
		return;

	// Get the "AAPL,units" property if any on the node to find the unit #s to try.
	unitsP = VCALL(GetPackagePropertyString) (phandle, "AAPL,units");
	
	// No AAPL,units means we do the default for the parent device_type
	if (unitsP == 0) {
		char *parentDeviceTypeP;
		CICell parentPH = VCALL(GetParentPHandle) (phandle);

		if (parentPH != 0) {
	
			parentDeviceTypeP = VCALL(GetPackagePropertyString) (parentPH,
																 "device_type");
	
			if (parentDeviceTypeP != nil) {
	
				if (VCALL(StringsAreEqualCaseInsensitive) (parentDeviceTypeP,
														   "scsi"))
					unitsP = "7-0";
				else if (VCALL(StringsAreEqualCaseInsensitive) (parentDeviceTypeP,
																"ata"))
					unitsP = "0-1";
			}
		}		
	}

	// If all else fails, we just use unit #0 on the device and hope for the best.
	if (unitsP == nil) unitsP = "0";
	
	while (*unitsP != 0) {
		UInt32 unit;
		UInt32 startUnit, endUnit;
		int delta;
		
#ifdef DEBUG
                if( slDebugFlag & kDebugLots) {
			VCALL(ShowMessage) ("unitsP");
			VCALL(ShowMessage) (unitsP);
		}
#endif
		unitsP = eatHex (unitsP, &startUnit);
		
		if (*unitsP == '-') {
			unitsP = eatHex (unitsP, &endUnit);
		} else {
			endUnit = startUnit;
		}

		if (startUnit <= endUnit)
			delta = 1;
		else
			delta = -1;

		for (unit = startUnit; ; unit += delta) {
			VCALL(TryThisUnit) (phandle, unit);
			if (unit == endUnit) break;
		}
		
		if (*unitsP == ',')
			++unitsP;		// Skip delimiting comma
		else
			break;			// ANY other character means we're done
	}
}


// Called to search the device tree (possibly recursively) starting at
// root (a phandle).  Doesn't return if a bootable device is found (it
// boots instead of returning).  For each device, calls TryThisDevice,
// which never returns if the device successfully boots.
void fSearchDeviceTree (CICell root)
{
	CICell node;

	if (root == 0) return;

#ifdef DEBUG
        if( slDebugFlag & kDebugLots) {
		CIArgs ciArgs;

		ciArgs.service = "interpret";
		ciArgs.nArgs = 2;
		ciArgs.nReturns = 1;
		ciArgs.args.interpret_1_0.arg1 = root;
		ciArgs.args.interpret_1_0.forth = ".\" Srch:\" . cr";
		CallCI (&ciArgs);
	}
#endif
	VCALL(TryThisDevice) (root);

	// Now traverse the first child of this node and its peers, recursing on each one.
	// If we succeed, we don't come back.
	for (node = VCALL(GetChildPHandle) (root);
		 node != 0;
		 node = VCALL(GetPeerPHandle) (node))
	{
		VCALL(SearchDeviceTree) (node);
	}
}


/* STUBS FOR NeXT BOOTER */
void time18 () {}
void readKeyboardStatus () {}


int __environ[4];
static KERNBOOTSTRUCT bogusBootStruct;		// This is bogus but used as a placeholder
KERNBOOTSTRUCT *kernBootStruct = &bogusBootStruct;
/**/


void halt ()
{
	CIArgs ciArgs;

	printf ("SecondaryLoader halt()\n");
	ciArgs.service = "exit";
	ciArgs.nArgs = 0;
	ciArgs.nReturns = 0;
	CallCI (&ciArgs);
}


#if 0
void printf_putchar (int ch)
{
	CIArgs ciArgs;

	ciArgs.service = "interpret";
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_1_0.arg1 = ch;

	if (ch == 0x0A) {
		ciArgs.nArgs = 1;
		ciArgs.args.interpret_1_0.forth = "cr";
	} else {
		ciArgs.nArgs = 2;
		ciArgs.args.interpret_1_0.forth = "emit";
	}

	CallCI (&ciArgs);
}
#endif


void sleep (int n)
{
	CIArgs ciArgs;

	ciArgs.service = "interpret";
	ciArgs.nArgs = 2;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_1_0.arg1 = n * 1000;
	ciArgs.args.interpret_1_0.forth = "ms";
	CallCI (&ciArgs);
}


void *fAppendBSSData (void *dataP, UInt32 size)
{
	void *baseOfNewDataP = gKernelBSSAppendixP;

	if ((UInt32) gKernelBSSAppendixP + size < KERNEL_LEN) {

		if (dataP != nil) {
			memcpy (gKernelBSSAppendixP, dataP, size);
		} else {				// NIL dataP means just reserve the space
			memset (gKernelBSSAppendixP, 0, size);
		}

		gKernelBSSAppendixP += size;
	} else {
		VCALL (FatalError) ("Device Tree too big!");
	}

	return baseOfNewDataP;
}

// begin net booting

// static for net booting
static char OFAddr[30];
static char bootInfoKernel[128];
static char bootInfoLinker[128];
static char bootInfoDrivers[128];

static void convert(char *buf,char ch1,char ch2)
{
    char *p;

    p = buf;
    while (*p != 0)
    {
        if (*p == ch1) *p = ch2;
        p++;
    }
}
    
// returns the kernel pathname from boot-info
static char *readBootInfo(char *pathname, int (**loaderF) (char *bootFileP)) 
{
    char *table, propBuf[256], *prop, *filename;
    int len,fd;
    unsigned int magic, *pmagic;

    bootInfoLinker[0] = '\0';
    bootInfoKernel[0] = '\0';
    bootInfoDrivers[0] = '\0';
    filename = pathname;

    // check if booting from disk
    if (strncmp(pathname,"enet",4) != 0) {

        // disk pathname does have the device address
        strcpy(propBuf,pathname);
        while (*filename != 0 && *filename != ',') filename++;
        filename++;

        // initialize disk 
        fd = fileLoadKernel(propBuf);
        read(fd,&magic,4);
        close(fd);

        // check magic number
        if (magic == 0xcafebabe || magic == 0xfeedface) {
            strcpy(bootInfoLinker,"/usr/standalone/ppc/sarld");
            return pathname;
        }
    }

    if ((table = ReadFile(filename,&len)) == nil) return;

    // check magic number
    pmagic = (unsigned int *)table;
    if (*pmagic == 0xcafebabe || *pmagic == 0xfeedface) return pathname;

    // drivers property
    if ((prop = FindStringKey( table, "\"drivers\"", propBuf)) != 0)
    {
        if (strncmp(prop,"enet",4) == 0) {
            convert(prop,'/','\\');
            sprintf(bootInfoDrivers,"%s",prop);
        } else {
            if (strncmp(pathname,"enet",4) == 0) {
                convert(prop,'/','\\');
                sprintf(bootInfoDrivers,"%s,%s",OFAddr,prop);
            } else {
                convert(prop,'\\','/');
                sprintf(bootInfoDrivers,"%s",prop);
            }
        }
    }

    // kernel property
    if ((prop = FindStringKey( table, "\"kernel\"", propBuf)) != 0)
    {
        if (strncmp(prop,"enet",4) == 0) {
            convert(prop,'/','\\');
            sprintf(bootInfoKernel,"%s",prop);
            *loaderF = networkLoadKernel;
        } else {
            if (strncmp(pathname,"enet",4) == 0) {
                convert(prop,'/','\\');
                sprintf(bootInfoKernel,"%s,%s",OFAddr,prop);
            } else {
                convert(prop,'/','\\');
                sprintf(bootInfoKernel,"%s,%s",OFAddr,prop);
            }
        }
    }

    // linker property
    if ((prop = FindStringKey( table, "\"linker\"", propBuf)) != 0)
    {
        if (strncmp(prop,"enet",4) == 0) {
            convert(prop,'/','\\');
            sprintf(bootInfoLinker,"%s",prop);
        } else {
            if (strncmp(pathname,"enet",4) == 0) {
                convert(prop,'/','\\');
                sprintf(bootInfoLinker,"%s,%s",OFAddr,prop);
            } else {
                convert(prop,'\\','/');
                sprintf(bootInfoLinker,"%s",prop);
            }
        }
    }

    free(table);

    return (char *)bootInfoKernel;
}

//  get the device address from the OF boot-file
static void getOFDeviceAddr(char *pathname)
{
    int i;
    char *addr;

    addr = OFAddr;
    for (i = 0 ; i < sizeof(OFAddr) - 1 ; i++)
    {
        if (*pathname == ',') break; 
        *addr++ = *pathname++;
    }
    *addr = '\0';
} 

// load twice to get the correct file size
static int openftp(char *name)
{ 
    UInt32 load_base,len1,len2,len;
    char load_cmd[80];
    unsigned char *p;
    int i;

    // get loadBase and load cmd
    load_base = InterpretReturn1 ("load-base");
    if (strlen(name) > 4 && strncmp(name,"enet",4) == 0)
        sprintf(load_cmd,"LOAD %s",name);   
    else
        sprintf(load_cmd,"LOAD %s,%s",OFAddr,name);   

    // zero from loadBase
    p = (unsigned char *)load_base;
    for (i = 0 ; i < 0x100000 ; i++) *p++ = 0xab;

    // load boot-drivers into load-base
    Interpret(load_cmd); 

    // calculate filesize
    p = (unsigned char *)(load_base + 0x100000 - 1);
    while (p >= (unsigned char *)load_base && *p == 0xab) p--;
    len1 = (int)p - load_base + 1;
    printf(" %d\n",len1);

    // check if too big to be a driver
    if (len1 >= 0x100000) return openmem (load_base, len1); 

    // zero from loadBase
    p = (unsigned char *)load_base;
    for (i = 0 ; i < 0x100000 ; i++) *p++ = 0x00;

    // load boot-drivers into load-base
    Interpret(load_cmd); 

    // calculate filesize
    p = (unsigned char *)(load_base + 0x100000 - 1);
    while (p >= (unsigned char *)load_base && *p == 0x00) p--;
    len2 = (int)p - load_base + 1;
    printf(" %d\n",len2);

    len = (len1 > len2) ? len1: len2;
    return openmem (load_base, len); 
}       

static int getNetDrivers(int op)
{
    int fd;
    static char *buf;
    static int next, len;

    // check if initialize
    if (op == 1)
    {
        if ((fd = open2(bootInfoDrivers,0)) == -1)
        {
            len = next = 0;
            return 1;
        }
        len = file_size(fd);
        buf = (char *) malloc(len);
        read(fd,buf,len);
        close(fd);
        next = 0;
        return 1;
    } 

    // check if eof
    if (next == len)
    {
        if (buf != (char *)0)
        {
            free(buf);
            buf = (char *)0;
        }
        return -1;
    }

    // otherwise return data
    return buf[next++];
}

static char *readNetDrivers()
{
    static char buf[256];
    char c;
    int ch,i;

    // skip leading white space
    for (;;)
    {
        if ((ch = getNetDrivers(2)) == -1) return (char *)0;
        c = (char) ch;
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == 0) continue;
        buf[0] = (char) c;
        break;
    }

    // copy and null terminate
    for (i = 1 ; i < sizeof(buf) - 1 ; i++)
    {
        if ((ch = getNetDrivers(2)) == -1) break;
        c = (char) ch;
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == 0) break;
        buf[i] = (char) c;
    }
    buf[i] = 0;

    // return string
    return (char *) buf;
}

// generic open for disk or tftp
static int open2(char *path, int perm)
{
    // check if path is defined
    if (strlen(path) == 0) return -1;

    // check if net boot
    if (strncmp(OFAddr,"enet",4) == 0 || strncmp(path,"enet",4) == 0) {
        convert(path,'/','\\');
        return openftp(path);
    }

    // otherwise open disk file
    convert(path,'\\','/');
    return open(path,perm);
}

// end net booting

// Returns -1 error
static int networkLoadKernel (char *bootFileP)
{
	char loadCmd[256];
	UInt32 loadBase, *p;
	int retry;

	// kernel image was just loaded.
	loadBase = InterpretReturn1 ("load-base");
        p = loadBase;

	// Generate a LOAD command to evaluate by concatenating "LOAD "
	// with boot-file's value This loads the actual kernel file into
	// memory at load-base.
	strcpy (loadCmd, "LOAD ");
	strcat (loadCmd, bootFileP);
	
	printf ("Loading Rhapsody Kernel: [%s]\n", loadCmd);

	// multiple retries loading kernel from the net
	for (retry = 0 ; retry < 32 ; retry++)
	{
	    Interpret (loadCmd);		// Do the actual LOAD command

	    // check for macho magic
	    if (*p != 0xFEEDFACE && *p != 0xCAFEBABE)
	    {
		Interpret("500 ms");
		continue;
	    }
	    break;
	}

#if OF_DEBUGGING
	Interpret ("state-valid on");	// For debugging early crashes (LOAD clears this)
#endif
	
	// Determine the value of "load-base" in Open Firmware which is where the
	return openmem (loadBase, kMaxLoadSize);
}


// Parse boot-file value of the form
//		device-specification:partition-number,kernel-file-name
//	where partition-number and its preceding ':' may be omitted, in which
//	case the entire device is treated as the boot volume;
//	kernel-file-name has '\' substituted for every '/' since Open Firmware
//	uses '/' for something else.
//
// Returns -1 error
static int fileLoadKernel (char *bootFileP)
{
	int defaultPartNo = 0;
	int nPartitions = 1;
	CICell devIH;
	CIArgs ciArgs;
	char *p;
	char *kernelFileP;
	int err, retry;

	// Scan backwards from end of boot-file value looking for the ',' that delimits
	// between the kernel file name and the device specification.
	p = bootFileP + strlen (bootFileP) - 1;

	while (p > bootFileP && *p != ',') {
		if (*p == '\\') *p = '/';			// Substitute correct slashes along the way
		--p;
	}

	kernelFileP = p + 1;
	*p = 0;									// NUL terminate the dev spec (replacing ',')

	// Scan backwards from the ',' looking for the ':' that delimits between
	// the boot device and the partition number.  If there is none, use 0.

	while (p > bootFileP && *p != ':') --p;

	if (*p == ':') {
		eatHex (p + 1, (UInt32 *) &defaultPartNo);
		*p = 0;								// NUL terminate the dev spec
	}

	// Now bootFileP points to the boot device spec, defaultPartNo has the
	// partition number on that device (zero if entire disk), and kernelFileP
	// points to the kernel file name to load.

	if (bootIH != 0) return open (kernelFileP, 0);
#ifdef DEBUG
        if( slDebugFlag & kDebugLots)
            printf ("Dev=\"%s\", part#=%d, kernel=\"%s\"\n",
			bootFileP, defaultPartNo, kernelFileP);
#endif

	// Remember partition number we're trying this time
	gBootPartition = defaultPartNo;

	// multiple retries loading the kernel from disk
	for (retry = 0 ; retry < 32 ; retry++)
	{
	    // Open the boot device
	    ciArgs.service = "interpret";
	    ciArgs.nArgs = 3;
	    ciArgs.nReturns = 2;
	    ciArgs.args.interpret_2_1.arg1 = strlen (bootFileP);
	    ciArgs.args.interpret_2_1.arg2 = (CICell) bootFileP;
	    ciArgs.args.interpret_2_1.forth = "open-dev";

	    if ((err = CallCI (&ciArgs))
	    ||	ciArgs.args.interpret_2_1.catchResult != 0
	    ||	ciArgs.args.interpret_2_1.return1 == 0)
	    {
		Interpret("500 ms");
		continue;
	    }
	    break;
	}
	if (err
	|| ciArgs.args.interpret_2_1.catchResult != 0
	||	ciArgs.args.interpret_2_1.return1 == 0)
	{
	    return -1;
	}

	// Remember the resulting instance handle
	devIH = ciArgs.args.interpret_2_1.return1;

	nPartitions = VCALL(AccessDevice) (devIH, gSecondaryLoaderVectors);

	if (nPartitions < 0) return -1;

	return open (kernelFileP, 0);
}

static void setupKernelParams (char *alternateArgs)
{
	char *bootArgsP;
    char c, *s;
    int graphicsBoot = 1;
	char tmpStr[256];

	gKernelParamsP = VCALL(AppendBSSData) (nil, sizeof (boot_args));

	gKernelParamsP->Version = kBootArgsVersion;
	gKernelParamsP->Revision = kBootArgsRevision;
	gKernelParamsP->machineType = 0;		// This is bogus
	SetupKernelVideoParams (&gKernelParamsP->Video);

    gKernelParamsP->PhysicalDRAM[0].base = 0;
    gKernelParamsP->PhysicalDRAM[0].size = InterpretReturn1 (
        "\" reg\" mem# ihandle>phandle GPP$ if drop 4+ @ else 0 then "
    );

    // This is a hack to get around a bug in Open Firmware 1.0.5 which
    // doesn't pass through the remainder of the 'boot' command
    // properly (at all).
    // Grab the kernel command parameters from /chosen's "machargs" property.
    bootArgsP = (char *) InterpretReturn1 (
            " \" /chosen\" find-package if "
                    "\" machargs\" rot GPP$ if "
                            "drop "
                    "else "
                            "0 "
                    "then "
            "else "
                    "0 "
            "then"
    );

    if (bootArgsP == 0) bootArgsP = alternateArgs;

    // Add Kernel Flags from System bundle
    strcpy( gKernelParamsP->CommandLine, loadedFlagString);
    // Copy result so we can NUL terminate it (!)
    strcat( gKernelParamsP->CommandLine, bootArgsP);

	// Add in the address for the Symbol Table
	if (gSymTabAddr != -1) {
	  sprintf(tmpStr, " symtab=%d ", gSymTabAddr);
	  strcat( gKernelParamsP->CommandLine, tmpStr);
	}


    Interpret(
        " update-key-map"
        "  \" /\" find-device gKeyMap h# 10 encode-bytes \" AAPL,adb-keymap\" property"
    );

    s = gKernelParamsP->CommandLine;
    if( (gKeyMap[0] & 0x40) )          /* s */
	    strcat( s, " -s");
    if( (gKeyMap[1] & 0x40) )          /* v */
		graphicsBoot = 0;

    // Look for -s to force text mode,
    //   strip any -v.
    while( c = *s++) {
	  if( c == '-') {
		if( *s == 's')
		  graphicsBoot = 0;
		if( *s == 'v') {
          *s = ' ';
          *(s-1) = ' ';
		  graphicsBoot = 0;
		}
	  }
	}
    gKernelParamsP->Video.v_display = graphicsBoot;

printf("boot args = '%s'\n", gKernelParamsP->CommandLine);
	GetDeviceTree ();
	
	// Remember how high we got in our BSS appending
	gKernelParamsP->topOfKernelData = (unsigned long) gKernelBSSAppendixP;
}

struct SAVars {
	unsigned char *	nextObject;
	int		objRemain;
	unsigned char *	workmem;
	int		workSize;
	unsigned char *	kernelAddr;
	char 	*	kernelName;
	UInt32		ld_entry;
	UInt32		ld_size;
	UInt32		ld_addr;
};

// MT: load boot drivers
static void * 
InitializeSARLD(char *kernelName, UInt32 kernelAddr, int kernelSize,
		unsigned char * objects, int objSize)
{
	int i,fd,st,cc,ret,len;
	unsigned char *workmem, *drivers, buf[ 120 ];
	struct mach_header header;
	UInt32 ld_addr=0, ld_entry=0, ld_size=0;
        struct SAVars * saVars;

	// print kernel name
	sprintf(buf,"loader: kernel: %s",kernelName);
	VCALL(ShowMessage) (buf);

	// open sarld
	if ((fd = open2(bootInfoLinker,0)) == -1)
	{
		VCALL(ShowMessage) ("loader: open sarld: could not open");
		return( nil);
	}

	// load sarld
	st = loadprog(DEV_SD,fd,&header,&ld_entry,&ld_addr,&ld_size);
	close(fd);

	drivers = (unsigned char *) gKernelBSSAppendixP;
	workmem = (unsigned char *)0xa00000;
	VCALL(ClaimMemory) ((UInt32) workmem, 0x70000, 0); // workmem - 384K

        for (kernelAddr = 0x10000 ; kernelAddr > 0 ; kernelAddr -= 0x1000) // FIXME LATER
        {
            unsigned int *tmpptr;
            tmpptr = (unsigned int *) kernelAddr;
            if (*tmpptr == 0xfeedface) break;
        }
        if (kernelAddr == 0)
            return( nil);

	// need to zero for drivers' bss
	bzero( objects, objSize);

	saVars = (struct SAVars *) malloc( sizeof( struct SAVars));
	if( saVars) {
            saVars->nextObject	= (unsigned char *) gKernelBSSAppendixP;
	    saVars->objRemain	= objSize;
            saVars->workmem	= workmem;
            saVars->workSize	= 0x70000; 		// on intel 0x100000
            saVars->kernelName	= kernelName;		// !!! reference
            saVars->kernelAddr	= (unsigned char *) kernelAddr;
            saVars->ld_entry	= ld_entry;
            saVars->ld_size	= ld_size;
            saVars->ld_addr	= ld_addr;
	}
	return( saVars);
}

static void *
FinalizeSARLD( void * saRef)
{
    struct SAVars *	saVars = saRef;

    gKernelBSSAppendixP = saVars->nextObject;
    free( saVars);
}

static int
LinkObject( void * saRef, char * name, unsigned char * object, int objSize,
		unsigned char ** linkedObj, int * linkedSize)
{
    struct SAVars *	saVars = saRef;
    char		ebuf[ 1024 ];
    int			len, ret;

        // setup sarld call
        ebuf[0] = 0;
        len = saVars->objRemain;

        // call sarld
#ifdef DEBUG
        if( slDebugFlag & kDebugSARLD)
            VCALL(ShowMessage) ("loader: sarld: calling");
#endif

        ret = (*(int (*) ()) saVars->ld_entry) (
		saVars->kernelName,
		saVars->kernelAddr,
                name, object, objSize,
                saVars->nextObject, &len,
                ebuf, sizeof( ebuf),
                saVars->workmem, saVars->workSize,
                gSymbolTableAddr, gSymbolTableLen,
                gStringTableAddr, gStringTableLen
        );

        // return from sarld
#ifdef DEBUG
        if( slDebugFlag & kDebugSARLD)
            VCALL(ShowMessage) ("loader: sarld: returned");
#endif

        if (ebuf[0] != 0)
        {
            int i;

            // convert to spaces
            for ( i = 0 ; i < sizeof(ebuf) ; i++)
                if (ebuf[i] == 10) ebuf[i] = 32;
            VCALL(ShowMessage) (ebuf);
        }
#ifdef DEBUG
        if( slDebugFlag & kDebugSARLD) {
            sprintf(ebuf,"loader: sarld: ret=%ld addr=0x%x len=0x%x",
                    ret,saVars->nextObject,len);
            VCALL(ShowMessage) (ebuf);
	}
#endif

        if (ret == 1)
        {
	    *linkedObj = saVars->nextObject;
	    *linkedSize = len;

	    // align nextObject on page boundary
	    if (len % 0x1000) len += 0x1000 - len % 0x1000;

            // update pointer for next driver
            saVars->nextObject += len;
            saVars->objRemain -= len;
        }
	return( ret != 1);
}

static void loadAndCallKernel (char *bootFileP, int (*loaderF) (char *bootFileP), char *bootArgs)
{
	int st;
	int fd;
	int kernelSize = 0;
	UInt32 load_base, kernelAddr = 0;
	struct mach_header header;
	CIArgs ciArgs;
	char *p;
	long msr;

	// read boot-info
        getOFDeviceAddr(bootFileP);
        load_base = InterpretReturn1 ("load-base");
        VCALL(ClaimMemory) ((UInt32) load_base,0x100000, 0);
        bootFileP = readBootInfo(bootFileP,&loaderF);
        if (*bootFileP == '\0') return;

	// MT: get kernel name
	for (p = bootFileP ; *p != ',' && *p != '\0' ; p++);
	p++;

	// Actually load the kernel using the specified loader function
	fd = (*loaderF) (bootFileP);
	if (fd < 0) return;

	printf ("Loading kernel and preparing it...\n");
	st = loadprog (DEV_SD, fd, &header, &gKernelEntryP, &kernelAddr, &kernelSize);

	printf ("   fd=%d, st=%d, entry=%X, base=%X, size=%X, dataTop=%X\n",
			fd, st, gKernelEntryP, kernelAddr, kernelSize, gTopOfData);

	// Don't leave our icon partially rotated -- make it pretty
   	VCALL(ShowWelcomeIcon) ();

	// Align our BSS appendix pointer to a new page boundary
	gTopOfData= (gTopOfData + kPageSize - 1) & -kPageSize;
	// Claim remaining space in kernel plat for our BSS appendix area
	gKernelBSSAppendixP = (char *) gTopOfData;
#ifdef DEBUG
        if( slDebugFlag & kDebugLots)
            printf ("Claiming 0x%08X length 0x%08X for BSS appendix area\n",
			gKernelBSSAppendixP, KERNEL_LEN - gTopOfData);
#endif
	VCALL(ClaimMemory) ((UInt32) gKernelBSSAppendixP, KERNEL_LEN - gTopOfData, 0);

        if( 0 == (slDebugFlag & kDisableDrivers)) {
            void *	saRef;
                saRef = InitializeSARLD( p, kernelAddr, kernelSize,
                                        gKernelBSSAppendixP, KERNEL_LEN - gTopOfData);
                if( saRef) {
                    if (strncmp(bootInfoDrivers,"enet",4) == 0) getOFDeviceAddr(bootInfoDrivers);
                    if (strncmp(OFAddr,"enet",4) == 0 || strlen(bootInfoDrivers) > 0)
                        FindNetDrivers( saRef);
                    else
                        FindDrivers( saRef);
                    FinalizeSARLD( saRef);
                }
        }

	setupKernelParams (bootArgs);
//while(1) {}
	// Call it
	if (st == 0) {
		if (kShowProgress) VCALL(ShowMessage) ("Call kernel!");
		// asm (".long 0x0FE01234"); // EV 1997.02.24 Commented out for test

		// Turn all translations off before calling the kernel.
		msr = 0x00001000;
		__asm__ volatile("mtmsr %0" : : "r" (msr));
		__asm__ volatile("isync");
		
		(*(void (*) ()) gKernelEntryP) (gKernelParamsP);
	} else {
		if (kShowProgress) VCALL(ShowMessage) ("Kernel load failed.");
	}
}


void SecondaryLoaderMain (void *junk1, void *junk2, ClientInterfacePtr ciPointer)
{
	CIArgs ciArgs;
	UInt32 mallocArenaVirt;
	char bootFile[256];
	char bootCommand[256];
	char newBootCommand[256];
	char *newArgs;
	int (*loaderFunctionP) (char *bootFileP);
	char *bootArgs;
	char *s;

	bootIH = 0;
	gCIPointer = ciPointer;

    InitializeHotkeys();

   // Initialize our Open Firmware assumptions
	Interpret (
#if DEBUG
		" ' u. to . "				// Temporary for debugging
		"cr .\" Rhapsody Kernel Loader <" BUILD_DATETIME "> \" cr "
#endif
		// MUCH OF THE FORTH IN THIS LOADER DEPENDS ON THIS SETTING
		"hex "

		": D2NIP decode-int nip nip ;\r" 	 // A useful function to save space
		": GPP$ get-package-property 0= ;\r" // Another useful function to save space
		": ^on0 0= if -1 throw then ;\r"	 // Bail if result zero
		": $CM $call-method ;\r"
		
		"0 value bIH\r"					// ihandle for dev we're booting from now
	);

	Interpret (
		": slReadBlocks "				// ( buffer block# #blocks -- )
#if kDebugLotsDef
			" .( RPB: ) .s 2 pick >r "
#endif
			"2 pick 200 erase "			// Clear buf so failures result in "safe junk"
			"200 * "				// Convert blk-count to a byte count
			"swap 200 um* "				// ( buf byte-count seek.lo seek.hi )
			"\" seek\" bIH $CM drop"       		// Seek to specified 512-byte block
#if 0
			"\" read\" ^bIH"			// This can't fail.  Right.
			" 10 ms"				// Wait fixes CD read failures on some 9500s
#else
			" a begin"				// #retries
                            " -rot 2dup \" read\" bIH $CM"	// ( bytesRead )
                            " 0= >r"				// read_error
			    " rot 1- dup 0<>"			// 	&& retries--
			    " r> and while"			// => loop
			    " 10 ms"				// delay after error
			" repeat 2drop"
#endif

#if kDebugLotsDef
			" .( RPB blk:) r> 200 dumpl cr cr "
#endif
			" ;\r"

		" \" /chosen\" find-package if "
			"dup \" memory\" rot GPP$ if "
				"D2NIP swap "				 // ( MEMORY-ihandle "/chosen"-phandle )
				"\" mmu\" rot GPP$ if "
					"D2NIP "				 // ( MEMORY-ihandle MMU-ihandle )
				"else "
					"0 "					 // ( MEMORY-ihandle 0 )
				"then "
			"else "
				"0 0 "						 // ( 0 0 )
			"then "
		"else "
			"0 0 "							 // ( 0 0 )
		"then\r"
		"value mmu# "
		"value mem# "
	);

	Interpret (
		": ^mem mem# $CM ; "
		": ^mmu mmu# $CM ; "
	);

	Interpret (
		// A "claim" client interface call replacement ( virt size align -- virt )
		": $clm { _v _s _a ; _av _p } "
#if 0
			".\" $clm: \" _v . _s . _a . cr "
#endif
			"_v _s _a \" claim\" ^mmu -> _av "	// Ask MMU for address space first
#if 0
			"_av ^on0 "							// Check for failure
#endif
			"_a 0= if _av then "				// If align==0 we want logical==physical
			"_s _a \" claim\" ^mem -> _p "		// Alloc physical memory next
#if 0
			"_p ^on0 "							// Check for failure
#endif
			"_p _av _s 10 \" map\" ^mmu "		// Map phys mem to _av (mode=10)
			"_av ; "							// Return allocated virtual base
	);

	ciArgs.service = "interpret";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_0_1.forth = "sl-debug";
	if (CallCI (&ciArgs) == 0 && ciArgs.args.interpret_0_1.catchResult == 0)
		slDebugFlag = ciArgs.args.interpret_0_1.return1;
	else
		slDebugFlag = 0;
	printf("Debug Flag = %08x\n", slDebugFlag);

	// Apply patches for PowerSurge ROMs to fix CONTROL
	// onboard video frame buffer driver.
	if (isPowerSurgeOF ()) patchStupidOF105 ();

	// Claim our malloc arena and initialize the zalloc malloc package
	mallocArenaVirt = VCALL(ClaimMemory) (ZALLOC_ADDR, ZALLOC_LEN, 0);
	malloc_init ((char *) mallocArenaVirt, ZALLOC_LEN, 512);

	// Open the display and draw the gray screen
	(void) VCALL(FindAndOpenDisplay) (nil, nil);

	// Grab the boot-command environment variable.
	ciArgs.service = "interpret";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 3;
	ciArgs.args.interpret_0_2.forth = "boot-command";
	CallCI (&ciArgs);

	// Copy result so we can NUL terminate it (!)
	memcpy (bootCommand,
			(void *) ciArgs.args.interpret_0_2.return2,
			ciArgs.args.interpret_0_2.return1);
	bootCommand[ciArgs.args.interpret_0_2.return1] = 0; // NUL terminate it

	// Replace boot-command if the prefix is wrong!
	if (strncmp ("0 bootr", bootCommand, 7) != 0) {
		// save the args if it was the Mac version
		if (strncmp ("40 bootr", bootCommand, 8) == 0) {
			newArgs = &bootCommand[8];
		} else {
			newArgs = "";
		}
		strcpy(newBootCommand, "setenv boot-command 0 bootr");
		strcat(newBootCommand, newArgs);
		Interpret(newBootCommand);

		bootArgs = "";
		for (s = bootCommand; *s; s++) {
		    if (strncmp(" bootr", s, 6) == 0) {
			bootArgs = s + 6;
			break;
		    }
		}
	} else {
		bootArgs = &bootCommand[7];
	}
	
	for (s = bootArgs; *s; s++) {
	  if (strncmp(s, "-y", 2) == 0)
		gSymTabAddr = 0;
	}

	DefineSpinIndicator ();

	// Grab the kernel file path from the boot-file environment variable.
	ciArgs.service = "interpret";
	ciArgs.nArgs = 1;
	ciArgs.nReturns = 3;
	ciArgs.args.interpret_0_2.forth = "boot-file";
	CallCI (&ciArgs);

	// Copy result so we can NUL terminate it (!)
	memcpy (bootFile,
			(void *) ciArgs.args.interpret_0_2.return2,
			ciArgs.args.interpret_0_2.return1);
	bootFile[ciArgs.args.interpret_0_2.return1] = 0; // NUL terminate it

	// Determine if it's a network load or a filesystem based one
	if (strncmp ("enet", bootFile, 4) == 0) {
		loaderFunctionP = networkLoadKernel;
	} else {
		loaderFunctionP = fileLoadKernel;
	}

	// Load the sucker and call it!
	loadAndCallKernel (bootFile, loaderFunctionP, bootArgs);
	// RETURNING means we didn't succeed...

	// Search the entire device tree looking desperately for something to boot...
	// printf ("Searching exhaustively for boot device...\n");
	// VCALL(SearchDeviceTree) (VCALL(GetPeerPHandle) (0));

	// Nothing we have tried worked, so just give up and tell the user
	// "At warp 9.5 she's a-goin' nowhere mighty fast"...
	VCALL(DeathScreen) ("?no dev");		// This never returns
}


// lame decl to match bsd/string.h
char * strchr( const char * str, int c)
{
    for( ; *str; str++ )
	if( *str == c)
	    return( str);
    return( nil);
}

static BOOL CompareName( const char * keys, const char * nameList)
{
    BOOL		matched;
    UInt32		keyLen, nameLen;
    const char *	nextKey;
    const char *	names;
    const char *	nextName;
    BOOL		wild;

    do {
	// for each key

	nextKey = strchr( keys, ' ');
	if( nextKey)
	    keyLen = nextKey - keys;
	else
	    keyLen = strlen( keys);
	wild = (keys[ keyLen - 1 ] == '*');

	names = nameList;
	do {
	    // for each name

	    nextName = strchr( names, ' ');
	    if( nextName)
		nameLen = nextName - names;
	    else
		nameLen = strlen( names);

	    if( wild)
		matched = (0 == strncmp( keys, names, keyLen - 1 ));
	    else
		matched =  ((nameLen == keyLen) 
			&& (0 == strncmp( keys, names, keyLen )));

	    names = nextName + 1;

	} while( nextName && (NO == matched));

	keys = nextKey + 1;

    } while( nextKey && (NO == matched));

    return( matched);
}

static CICell DeviceMatches( CICell device, const char * keys )
{
    char		compat[ 256 ];
    const char *	nodeName;
    const char *	devType;
    const char *	model;
    UInt32		len, i;
    const char *	next;
    Boolean		matched;

    nodeName = VCALL(GetPackagePropertyString) (device, "name");
    devType = VCALL(GetPackagePropertyString) (device, "device_type");
    model = VCALL(GetPackagePropertyString) (device, "model");

    len = VCALL(GetProperty) (device, "compatible", compat, sizeof( compat));
    if( len == -1)
	len = 0;
    else
	// convert separators from null to blanks. Blech.
        for( i = 0; i < len - 1; i++)
            if( compat[ i ] == 0)
                compat[ i ] = ' ';

    matched =  (model && CompareName( keys, model))
	    || (len && CompareName( keys, compat))
	    || (nodeName && CompareName( keys, nodeName))
	    || (devType && CompareName( keys, devType));

    if( matched)
	return( device);
    else
	return( 0);
}

// A third tree walker for the Secondary Loader...

static CICell SearchForDevice (CICell root, const char * matchName )
{
    CICell node;
    CICell found = 0;

    if (root == 0) return 0;

    found = DeviceMatches (root, matchName );
    
    // Now traverse the first child of this node and its peers, recursing on each one.
    for (node = VCALL(GetChildPHandle) (root);
	node != 0 && found == 0;
	node = VCALL(GetPeerPHandle) (node))
    {
	found = SearchForDevice (node, matchName );
    }

    return( found);
}

CICell SetProperty( CICell phandle, char *name, void *bufP, CICell buflen)
{
	CIArgs ciArgs;

	ciArgs.service = "interpret";
	ciArgs.nArgs = 5;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_4_0.arg1 = buflen;
	ciArgs.args.interpret_4_0.arg2 = (CICell) bufP;
	ciArgs.args.interpret_4_0.arg3 = strlen (name);
	ciArgs.args.interpret_4_0.arg4 = (CICell) name;
	ciArgs.args.interpret_4_0.forth =	// ( name namelen buf bufLen -- phandle )
		"encode-bytes 2swap property";

	if (CallCI (&ciArgs) != 0 || ciArgs.args.interpret_4_0.catchResult != 0) return 0;

#ifdef DEBUG
        if( slDebugFlag & kDebugLoadables)
            printf("Prop %s = %x, %x\n", name, *((unsigned int *)bufP), buflen);
#endif

	return buflen;
}

// Note: sets active-package, my-self
static CICell FindDeviceNode( char *path)
{
	CIArgs ciArgs;

	ciArgs.service = "interpret";
	ciArgs.nArgs = 3;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_2_1.arg1 = strlen (path);
	ciArgs.args.interpret_2_1.arg2 = (CICell) path;
	ciArgs.args.interpret_2_1.forth =	// ( name namelen -- phandle )
		"0 to my-self find-device active-package";

	if (CallCI (&ciArgs) != 0 || ciArgs.args.interpret_2_1.catchResult != 0) return 0;

	return ciArgs.args.interpret_2_1.return1;
}

// Note: sets active-package
static CICell MakeDeviceNode( char *name)
{
	CIArgs ciArgs;
	
	ciArgs.service = "interpret";
	ciArgs.nArgs = 3;
	ciArgs.nReturns = 2;
	ciArgs.args.interpret_2_1.arg1 = strlen (name);
	ciArgs.args.interpret_2_1.arg2 = (CICell) name;
	ciArgs.args.interpret_2_1.forth =	// ( name namelen -- phandle )
		"new-device 2dup device-name finish-device find-device active-package";

	if (CallCI (&ciArgs) != 0 || ciArgs.args.interpret_2_1.catchResult != 0) return 0;

	return ciArgs.args.interpret_2_1.return1;
}



/*	The Driver Description */
enum {
    kInitialDriverDescriptor	= 0,
    kVersionOneDriverDescriptor	= 1,
    kTheDescriptionSignature	= 'mtej',
    kDriverDescriptionSignature	= 'pdes'						
};

struct DriverType {
    Str31		nameInfoStr;				/* Driver Name/Info String*/
    UInt32		version;				/* Driver Version Number - really NumVersion */
};
typedef struct DriverType		DriverType;

typedef UInt32 DriverDescVersion;

struct DriverDescription {
    OSType			driverDescSignature;		/* Signature field of this structure*/
    DriverDescVersion		driverDescVersion;		/* Version of this data structure*/
    DriverType			driverType;			/* Type of Driver*/
    char			otherStuff[ 512 ];
};
typedef struct DriverDescription	DriverDescription;

// Note: sets active-package, my-self
static void
ProcessNDRV( char * pef, unsigned int pefLen )
{
    
    char			descripName[] = " TheDriverDescription";
    OSStatus			err;
    DriverDescription		descrip;
    DriverDescription		curDesc;
    char *			currentPef;
    char	 		matchName[ 40 ];
    UInt32			newVersion;
    UInt32			curVersion;
    CICell			node;

    do {
	descripName[0] = strlen( descripName + 1);
	err = GetSymbolFromPEF( descripName, pef, &descrip, sizeof( descrip));
	if( err) {
            printf("\nGetSymbolFromPEF returns %d\n",err);
	    continue;
	}
	if( (descrip.driverDescSignature != kTheDescriptionSignature)
	||  (descrip.driverDescVersion != kInitialDriverDescriptor))
	    continue;

	strncpy( matchName, descrip.driverType.nameInfoStr + 1, descrip.driverType.nameInfoStr[0] );
	newVersion = descrip.driverType.version;

#ifdef DEBUG
        if( slDebugFlag & kDebugLoadables)
            printf(" New %x ", newVersion);
#endif

	if( (newVersion & 0xffff) == 0x8000)		// final stage, release rev
	    newVersion |= 0xff;

#ifdef DEBUG
        if( slDebugFlag & kDebugLoadables)
            printf( "Looking for %s...", matchName );
#endif

	node = SearchForDevice(VCALL(GetPeerPHandle) (0), matchName);

	if( node) {

	    CIArgs ciArgs;

#ifdef DEBUG
            if( slDebugFlag & kDebugLoadables)
                printf("Located");
#endif

	    do {
		// A little caching might be nice - but only if there is often 
		// multiple files for a node.
		// Use GetPackagePropertyString so we don't copy property

		currentPef = VCALL(GetPackagePropertyString) (node, "driver,AAPL,MacOS,PowerPC");
		if( currentPef == nil)
		    continue;
		if( GetSymbolFromPEF( descripName, currentPef, &curDesc, sizeof( curDesc)))
    		    continue;
		if( (curDesc.driverDescSignature != kTheDescriptionSignature)
		||  (curDesc.driverDescVersion != kInitialDriverDescriptor))
		    continue;

		curVersion = curDesc.driverType.version;

#ifdef DEBUG
                if( slDebugFlag & kDebugLoadables)
                    printf("Current %x ", curVersion);
#endif

		if( (curVersion & 0xffff) == 0x8000)		// final stage, release rev
		    curVersion |= 0xff;

		if( newVersion <= curVersion)
		    pefLen = 0;

	    } while( false);

	    if( pefLen == 0)
		continue;

	    ciArgs.service = "interpret";
	    ciArgs.nArgs = 4;
	    ciArgs.nReturns = 1;
	    ciArgs.args.interpret_3_0.arg1 = node;
	    ciArgs.args.interpret_3_0.arg2 = pefLen;
	    ciArgs.args.interpret_3_0.arg3 = (CICell) pef;
	    ciArgs.args.interpret_3_0.forth =	// ( data len phandle -- )
		"unselect-dev to active-package "
		"encode-bytes \" driver,AAPL,MacOS,PowerPC\" property ";

    	    if (CallCI (&ciArgs) != 0 || ciArgs.args.interpret_3_0.catchResult != 0)
		continue;
#ifdef DEBUG
            if( slDebugFlag & kDebugLoadables)
                printf("patched!\n");
#endif

	}
    } while( false);
}

static char *
FindStringKey( const char * config, const char * key, char * buf )
{
    char  	* match;
    char 	* prop;
    char 	* end;
    char 	* eol;
    int		  keyLen;

    keyLen = strlen( key);
    for( match = config;
	(match = strchr( match, '\"'));
	 match++) {
      
            if( 0 == strncmp( match, key, keyLen)) {
                eol = strchr( match + keyLen, ';');
                prop = strchr( match + keyLen, '\"');
                if( (prop == NULL) || (eol < prop))
                    break;
		prop++;
		end = strchr( prop, '\"');
		strncpy( buf, prop, end - prop);

#ifdef DEBUG
                if( slDebugFlag & kDebugLoadables)
                    printf("%s = %s\n", key, buf);
#endif
                return( buf);
            }
    }
    return( nil);
}




char *
diskReadFile( char * path, int * len)
{
    int			fd, binSize, count;
    char	*	bin = nil;

    do {

#ifdef DEBUG
        if( slDebugFlag & kDebugLoadables)
            printf("Opening %s\n", path);
#endif
        fd = open2( path, 0);
        if( fd < 0) {
#ifdef DEBUG
            if( slDebugFlag & kDebugLoadables)
                printf("Open failed\n");
#endif
            continue;
        }
        binSize = file_size( fd);
	*len = binSize;
        bin = (char *) malloc( binSize);
        if( bin) {
            count = read( fd, bin, binSize);
            if( count != binSize) {
                printf("Read failed for %s\n", path);
                free( bin);
		bin = nil;
	    }
        }
        close( fd);

    } while( false);

    return( bin);
}

extern long int strtol(const char *nptr, char **endptr, int base);

static int
ProcessDriverBundle( void * saRef, char * path, int pathLen, Boolean doReloc,
			char * bundleName, char * tableName )
{
    struct direct *	driverFile;
    int			len, err;
    int			loadPri = 0;
    Boolean    		doLoad = (doReloc == false);
    unsigned char    *	obj = nil;
    char		*table, *reloc, *prop, *nextTable;
    int			objSize, tableLen;
    char		propBuf[ 256 ];
    int 		size = 0;
    CICell		dtDir;
    int			fd, count;

    strcpy( path + pathLen, tableName );

#ifdef DEBUG
    if( slDebugFlag & kDebugLoadables)
        printf("Opening %s\n", path);
#endif
    fd = open2( path, 0);
    if( fd < 0) {
        if( slDebugFlag & kDebugLoadables)
            printf("Open failed\n");

	return( -1);
    }
    tableLen = file_size( fd);
    table = (char *) malloc( tableLen + 1);			// needs null terminate
    if( table) {
        count = read( fd, table, tableLen);
        if( count != tableLen) {
            printf("Read failed for %s\n", path);
            free( table);
            table = nil;
        }
    }
    close( fd);

    if( table == nil)
        return( -1);

    table[ tableLen ] = 0;

    // Check for Kernel flags as the System bundle goes by
    if( (0 == strcmp("System", bundleName))
    &&  (prop = FindStringKey( table, "\"Kernel Flags\"", propBuf)) ) {

	// overwrite if first table or non-Default
	if( ((loadedFlagString[ 0 ] == 0) && (0 == strcmp("Default.table", tableName)))
	||  (0 == strcmp("Instance0.table", tableName))) {
	    strcpy( loadedFlagString, prop);
	    strcat( loadedFlagString, " ");
	}
    }

    if( doReloc) {
        prop = FindStringKey( table, "\"Boot Driver\"", propBuf);
#if DEBUG
        if( prop && (
                        (prop[ 0 ] == 'Y')
                     || ((slDebugFlag & kForceDrivers) && prop[ 0 ])
		    )) {
#else
        if( prop && (prop[ 0 ] == 'Y')) {
#endif

	    // look at multiple tables in one file, null separated
	    for(    nextTable = table;
                    (doLoad == false) && ((nextTable - table) < tableLen);
                    nextTable = nextTable + strlen( nextTable) + 1) {

                prop = FindStringKey( nextTable, "\"Matching\"", propBuf);
                doLoad = ((!prop) || SearchForDevice(VCALL(GetPeerPHandle) (0), prop));
	    }

	    if( doLoad) {
                strcpy( path + pathLen, bundleName );
                strcat( path + pathLen, "_reloc");
                reloc = ReadFile( path, &objSize);
                if( reloc) {
                    err = LinkObject( saRef, path + pathLen, reloc, objSize, &obj, &objSize);
                    doLoad = (err == 0);
                    free( reloc);
                }
	    }
        }
    }

    err = -1;
    if( doLoad) {
        dtDir = FindDeviceNode("/AAPL,loadables");
        if( dtDir) {
            dtDir = FindDeviceNode( bundleName);
            if( 0 == dtDir)
                dtDir = MakeDeviceNode( bundleName);
        }
        if( dtDir) {
            size = SetProperty( dtDir, tableName, table, tableLen);
	    if( doReloc) {
                size = SetProperty( dtDir, "_reloc", &obj, sizeof( obj));
                size = SetProperty( dtDir, "_reloc_size", &objSize, sizeof( objSize));
	    }
	    err = 0;
	}
    }
    free( table);
    return( err);
}


void
FindDrivers( void * saRef )
{
    void	*	dirp;
    void	*	bundleDir;
    struct direct *	driverEntry;
    struct direct *	driverFile;
    char		path[ 256 ];
    char		bundleName[ 32 ];
    int			len;
    int			pathLen;
    CICell		dtDir;
    Boolean		addedBundle, systemBundle;

    static const char * rootPath = "/private/Drivers/ppc";
    static const int	rootPathLen = 20;
    static const char * bundleTrailer = ".config";
    static const int	bundleTrailerLen = 7;
    static const char * ndrvDriverTrailer = "_ndrv";
    static const int	ndrvDriverTrailerLen = 5;
    static const char * tableTrailer = ".table";
    static const int	tableTrailerLen = 6;

    if( FindDeviceNode("/"))
    	MakeDeviceNode("AAPL,loadables");

    strcpy( path, rootPath);
    dirp = (void *) opendir( path);
    if (dirp) {
	while( (driverEntry = (struct direct *) readdir(dirp)) ) {

	    len = strlen( driverEntry->d_name);
	    if( (len > bundleTrailerLen) && 
		(0 == strcmp( driverEntry->d_name + len - bundleTrailerLen, bundleTrailer)) ) {

		path[ rootPathLen ] = '/';
		strcpy( path + rootPathLen + 1, driverEntry->d_name );	// rootPath/XXX.config
		bundleDir = (void *) opendir( path);

		if( bundleDir) {

                    pathLen = rootPathLen + len + 1;			// place to put file name
		    path[ pathLen++ ] = '/';

                    strncpy( bundleName, driverEntry->d_name, len - bundleTrailerLen);
		    systemBundle = (0 == strcmp( "System", bundleName));

		    if( systemBundle == false)
                        addedBundle = (0 == ProcessDriverBundle( saRef, path, pathLen, true, bundleName, "Default.table" ));

		    while( (driverFile = (struct direct *) readdir( bundleDir)) ) {

			len = strlen( driverFile->d_name);

			if( (len > tableTrailerLen)
				 && ( 0 == strcmp( driverFile->d_name + len - tableTrailerLen, tableTrailer)) ) {

			    // Add instance tables
			    // Everything in System, but only loaded drivers
			    if( systemBundle
			    || (addedBundle && strcmp( "Default.table", driverFile->d_name)) )
                                ProcessDriverBundle( saRef, path, pathLen, false, bundleName, driverFile->d_name );

			} else if( (0 == (slDebugFlag & kDisableNDRVs))
				 && (len > ndrvDriverTrailerLen)
				 && ( 0 == strcmp( driverFile->d_name + len - ndrvDriverTrailerLen, ndrvDriverTrailer)) ) {

			    int 	binSize;
			    char *	bin;

			    strcpy( path + pathLen, driverFile->d_name );	// rootPath/XXX.config/XXX_ndrv
			    bin = ReadFile( path, &binSize);
			    if( bin) {
                                ProcessNDRV( bin, binSize );
				free( bin);
			    }
			}
		    }
                    closedir( bundleDir);
		}
	    }
	}
	closedir( dirp);
    }
}


void
FindNetDrivers( void * saRef )
{
    char driver[256], *path, *bin;
    int i,binSize;

    if( FindDeviceNode("/"))
        MakeDeviceNode("AAPL,loadables");

    getNetDrivers(1);
    while ((path = readNetDrivers()) != (char *)0)
    {
        for (i = strlen(path) - 1 ; i > 0 ; i--)
            if (path[i] == '\\' || path[i] == '/') break;

        strcpy(driver, &path[i+1]);

        // check if driver name ends with _ndrv
        if (strlen(driver) > 5 && strncmp(driver + strlen(driver) - 5, "_ndrv", 5) == 0)
        {
            // process ndrv
            bin = ReadFile(path, &binSize);
            if (bin)
            {
                ProcessNDRV(bin, binSize);
                free(bin);
            }
        } else {
            // process driver
            strcat(path, ".config/");
            ProcessDriverBundle(saRef, path, strlen(path), true, driver, "Default.table");
        }
    }
}

