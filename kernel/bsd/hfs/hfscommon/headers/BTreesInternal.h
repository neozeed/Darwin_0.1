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

/*
	File:		BTreesInternal.h

	Contains:	IPI to File Manager B-tree

	Version:	HFS Plus 1.0

	Copyright:	� 1996-1998 by Apple Computer, Inc., all rights reserved.

	File Ownership:

		DRI:				Don Brady

		Other Contact:		Mark Day

		Technology:			File Systems

	Writers:

		(msd)	Mark Day
		(DSH)	Deric Horn
		(djb)	Don Brady

	Change History (most recent first):
	
	  <RHAP>	 6/22/98	djb		Add ERR_BASE to btree error codes to make them negative (for Rhapsody only).

	   <CS7>	 7/28/97	msd		Add enum for fsBTTimeOutErr.
	   <CS6>	 7/25/97	DSH		Added heuristicHint as parameter to BTSearchRecord.
	   <CS5>	 7/24/97	djb		Add blockReadFromDisk flag to BlockDescriptor. Callbacks now use
									a file refNum instead of an FCB.
	   <CS4>	 7/16/97	DSH		FilesInternal.i renamed FileMgrInternal.i to avoid name
									collision
	   <CS3>	  6/2/97	DSH		Added SetEndOfForkProc() prototype, so Attributes.c can call it
									directly.
	   <CS2>	 5/19/97	djb		kMaxKeyLength is now 520.
	   <CS1>	 4/28/97	djb		first checked in

	  <HFS6>	 3/17/97	DSH		Remove Key Comparison prototype, already in FilesInternal.h.
	  <HFS5>	 2/19/97	djb		Add SetBlockSizeProcPtr. Add blockSize field to BlockDescriptor.
									Remove E_ type error enums.
	  <HFS4>	 1/27/97	djb		Include Types.h and FilesInternal.h.
	  <HFS3>	 1/13/97	djb		Added kBTreeCurrentRecord for BTIterateRecord.
	  <HFS2>	  1/3/97	djb		Added support for large keys.
	  <HFS1>	12/19/96	djb		first checked in

*/

#ifndef	__BTREESINTERNAL__
#define __BTREESINTERNAL__

#if TARGET_OS_MAC
#include <Types.h>
#else
#include "system/MacOSTypes.h"
#endif 	/* TARGET_OS_MAC */

#include "FileMgrInternal.h"

enum {
	fsBTInvalidHeaderErr			= btBadHdr,
	fsBTBadRotateErr				= dsBadRotate,
	fsBTInvalidNodeErr				= btBadNode,
	fsBTRecordTooLargeErr			= btNoFit,
	fsBTRecordNotFoundErr			= btNotFound,
	fsBTDuplicateRecordErr			= btExists,
	fsBTFullErr						= btNoSpaceAvail,

	fsBTInvalidFileErr				= ERR_BASE + 0x0302,	/* no BTreeCB has been allocated for fork*/
	fsBTrFileAlreadyOpenErr			= ERR_BASE + 0x0303,
	fsBTInvalidIteratorErr			= ERR_BASE + 0x0308,
	fsBTEmptyErr					= ERR_BASE + 0x030A,
	fsBTNoMoreMapNodesErr			= ERR_BASE + 0x030B,
	fsBTBadNodeSize					= ERR_BASE + 0x030C,
	fsBTBadNodeType					= ERR_BASE + 0x030D,
	fsBTInvalidKeyLengthErr			= ERR_BASE + 0x030E,
	fsBTInvalidKeyDescriptor		= ERR_BASE + 0x030F,
	fsBTStartOfIterationErr			= ERR_BASE + 0x0353,
	fsBTEndOfIterationErr			= ERR_BASE + 0x0354,
	fsBTUnknownVersionErr			= ERR_BASE + 0x0355,
	fsBTTreeTooDeepErr				= ERR_BASE + 0x0357,
	fsBTInvalidKeyDescriptorErr		= ERR_BASE + 0x0358,
	fsBTInvalidKeyFieldErr			= ERR_BASE + 0x035E,
	fsBTInvalidKeyAttributeErr		= ERR_BASE + 0x035F,
	fsIteratorExitedScopeErr		= ERR_BASE + 0x0A02,	/* iterator exited the scope*/
	fsIteratorScopeExceptionErr		= ERR_BASE + 0x0A03,	/* iterator is undefined due to error or movement of scope locality*/
	fsUnknownIteratorMovementErr	= ERR_BASE + 0x0A04,	/* iterator movement is not defined*/
	fsInvalidIterationMovmentErr	= ERR_BASE + 0x0A05,	/* iterator movement is invalid in current context*/
	fsClientIDMismatchErr			= ERR_BASE + 0x0A06,	/* wrong client process ID*/
	fsEndOfIterationErr				= ERR_BASE + 0x0A07,	/* there were no objects left to return on iteration*/
	fsBTTimeOutErr					= ERR_BASE + 0x0A08		/* BTree scan interrupted -- no time left for physical I/O */
};

struct BlockDescriptor{
	void		*buffer;
	void		*blockHeader;
	ByteCount	 blockSize;
	Boolean		 blockReadFromDisk;
	Byte		 reserved[3];
};
typedef struct BlockDescriptor BlockDescriptor;
typedef BlockDescriptor *BlockDescPtr;


struct FSBufferDescriptor {
	LogicalAddress 					bufferAddress;
	ByteCount 						itemSize;
	ItemCount 						itemCount;
};
typedef struct FSBufferDescriptor FSBufferDescriptor;

typedef FSBufferDescriptor *FSBufferDescriptorPtr;


/*
	Fork Level Access Method Block get options
*/
enum {
		kGetBlock			= 0x00000000,
		kForceReadBlock		= 0x00000002,	//�� how does this relate to Read/Verify? Do we need this?
		kGetEmptyBlock		= 0x00000008
};
typedef OptionBits	GetBlockOptions;

/*
	Fork Level Access Method Block release options
*/
enum {
		kReleaseBlock		= 0x00000000,
		kForceWriteBlock	= 0x00000001,
		kMarkBlockDirty		= 0x00000002,
		kTrashBlock			= 0x00000004
};
typedef OptionBits	ReleaseBlockOptions;

typedef	UInt32	FSSize;
typedef	UInt32	ForkBlockNumber;

/*============================================================================
	Fork Level Buffered I/O Access Method
============================================================================*/

typedef	OSStatus	(* GetBlockProcPtr)		(FileReference				 fileRefNum,
											 UInt32						 blockNum,
											 GetBlockOptions			 options,
											 BlockDescriptor			*block );
							 

typedef	OSStatus	(* ReleaseBlockProcPtr)	(FileReference				 fileRefNum,
											 BlockDescPtr				 blockPtr,
											 ReleaseBlockOptions		 options );

typedef	OSStatus	(* SetEndOfForkProcPtr)	(FileReference				 fileRefNum,
											 FSSize						 minEOF,
											 FSSize						 maxEOF );
								 
typedef	OSStatus	(* SetBlockSizeProcPtr)	(FileReference				 fileRefNum,
											 ByteCount					 blockSize,
											 ItemCount					 minBlockCount );

OSStatus		SetEndOfForkProc ( FileReference fileRefNum, FSSize minEOF, FSSize maxEOF );

/*
	BTreeObjID is used to indicate an access path using the
	BTree access method to a specific fork of a file. This value
	is session relative and not persistent between invocations of
	an application. It is in fact an object ID to which requests
	for the given path should be sent.
 */
typedef UInt32 BTreeObjID;

/*
	B*Tree Information Version
*/

enum BTreeInformationVersion{
	kBTreeInfoVersion	= 0
};

/*
	B*Tree Iteration Operation Constants
*/

enum BTreeIterationOperations{
	kBTreeFirstRecord,
	kBTreeNextRecord,
	kBTreePrevRecord,
	kBTreeLastRecord,
	kBTreeCurrentRecord
};
typedef UInt16 BTreeIterationOperation;

/*
	B*Tree Key Descriptor Limits
*/

enum BTreeKeyLimits{
	kMaxKeyDescriptorLength		= 23,
	kMaxKeyLength				= 520
};

/*
	B*Tree Key Descriptor Field Types
*/

enum {
	kBTreeSkip				=  0,
	kBTreeByte				=  1,
	kBTreeSignedByte		=  2,
	kBTreeWord				=  4,
	kBTreeSignedWord		=  5,
	kBTreeLong				=  6,
	kBTreeSignedLong		=  7,
	kBTreeString			=  3,		// Pascal string
	kBTreeFixLenString		=  8,		// Pascal string w/ fixed length buffer
	kBTreeReserved			=  9,		// reserved for Desktop Manager (?)
	kBTreeUseKeyCmpProc		= 10,
	//�� not implemented yet...
	kBTreeCString			= 11,
	kBTreeFixLenCString		= 12,
	kBTreeUniCodeString		= 13,
	kBTreeFixUniCodeString	= 14
};
typedef UInt8		BTreeKeyType;


/*
	B*Tree Key Descriptor String Field Attributes
*/

enum {
	kBTreeCaseSens			= 0x10,		// case sensitive
	kBTreeNotDiacSens		= 0x20		// not diacritical sensitive
};
typedef UInt8		BTreeStringAttributes;

/*
	Btree types: 0 is HFS CAT/EXT file, 1~127 are AppleShare B*Tree files, 128~254 unused
	hfsBtreeType	EQU		0			; control file
	validBTType		EQU		$80			; user btree type starts from 128
	userBT1Type		EQU		$FF			; 255 is our Btree type. Used by BTInit and BTPatch
*/

enum BTreeTypes{
	kHFSBTreeType			=   0,		// control file
	kUserBTreeType			= 128,		// user btree type starts from 128
	kReservedBTreeType		= 255		//
};

/*============================================================================
	B*Tree Key Structures
============================================================================*/

#if PRAGMA_STRUCT_ALIGN
	#pragma options align=mac68k
#elif PRAGMA_STRUCT_PACKPUSH
	#pragma pack(push, 2)
#elif PRAGMA_STRUCT_PACK
	#pragma pack(2)
#endif

/*
	BTreeKeyDescriptor is used to indicate how keys for a particular B*Tree
	are to be compared.
 */
typedef char BTreeKeyDescriptor[26];
typedef char *BTreeKeyDescriptorPtr;

/*
	BTreeInformation is used to describe the public information about a BTree
 */
struct BTreeInformation{
	UInt16						NodeSize;
	UInt16						MaxKeyLength;
	UInt16						Depth;
	UInt16						Reserved;
	ItemCount					NumRecords;
	ItemCount					NumNodes;
	ItemCount					NumFreeNodes;
	ByteCount					ClumpSize;
	BTreeKeyDescriptor			KeyDescriptor;
	};
typedef struct BTreeInformation BTreeInformation;
typedef BTreeInformation *BTreeInformationPtr;

union BTreeKey{
	UInt8			length8;
	UInt16			length16;
	UInt8			rawData [kMaxKeyLength+2];
};

typedef union BTreeKey BTreeKey;
typedef BTreeKey *BTreeKeyPtr;


struct KeyDescriptor{
	UInt8			length;
	UInt8			fieldDesc [kMaxKeyDescriptorLength];
};
typedef struct KeyDescriptor KeyDescriptor;
typedef KeyDescriptor *KeyDescriptorPtr;

struct NumberFieldDescriptor{
	UInt8			fieldType;
	UInt8			occurrence;					// number of consecutive fields of this type
};
typedef struct NumberFieldDescriptor NumberFieldDescriptor;

struct StringFieldDescriptor{
	UInt8			fieldType;					// kBTString
	UInt8			occurrence;					// number of consecutive fields of this type
	UInt8			stringAttribute;
	UInt8			filler;
};
typedef struct StringFieldDescriptor StringFieldDescriptor;

struct FixedLengthStringFieldDescriptor{
	UInt8			fieldType;					// kBTFixLenString
	UInt8			stringLength;
	UInt8			occurrence;
	UInt8			stringAttribute;
};
typedef struct FixedLengthStringFieldDescriptor FixedLengthStringFieldDescriptor;

#if PRAGMA_STRUCT_ALIGN
	#pragma options align=reset
#elif PRAGMA_STRUCT_PACKPUSH
	#pragma pack(pop)
#elif PRAGMA_STRUCT_PACK
	#pragma pack()
#endif

/*
	BTreeInfoRec Structure - for BTGetInformation
*/
struct BTreeInfoRec{
	UInt16				version;
	UInt16				nodeSize;
	UInt16				maxKeyLength;
	UInt16				treeDepth;
	ItemCount			numRecords;
	ItemCount			numNodes;
	ItemCount			numFreeNodes;
	KeyDescriptorPtr	keyDescriptor;
	ByteCount			keyDescLength;
	UInt32				reserved;
};
typedef struct BTreeInfoRec BTreeInfoRec;
typedef BTreeInfoRec *BTreeInfoPtr;

/*
	BTreeHint can never be exported to the outside. Use UInt32 BTreeHint[4],
	UInt8 BTreeHint[16], etc.
 */
struct BTreeHint{
	ItemCount				writeCount;
	UInt32					nodeNum;			// node the key was last seen in
	UInt16					index;				// index then key was last seen at
	UInt16					reserved1;
	UInt32					reserved2;
};
typedef struct BTreeHint BTreeHint;
typedef BTreeHint *BTreeHintPtr;

/*
	BTree Iterator
*/
struct BTreeIterator{
	BTreeHint				hint;
	UInt16					version;
	UInt16					reserved;
	BTreeKey				key;
};
typedef struct BTreeIterator BTreeIterator;
typedef BTreeIterator *BTreeIteratorPtr;


/*============================================================================
	B*Tree SPI
============================================================================*/

extern OSStatus	InitBTreeModule		(void);


extern OSStatus	BTInitialize		(FCB						*filePtrPtr,
									 UInt16						 maxKeyLength,
									 UInt16						 nodeSize,
									 UInt8						 btreeType,
									 KeyDescriptorPtr			 keyDescPtr );

/*
	Key Comparison Function ProcPtr Type - for BTOpenPath
*/
//typedef SInt32 				(* KeyCompareProcPtr)(BTreeKeyPtr a, BTreeKeyPtr b);

extern OSStatus	BTOpenPath			(FCB		 				*filePtr,
									 KeyCompareProcPtr			 keyCompareProc,
									 GetBlockProcPtr			 getBlockProc,
									 ReleaseBlockProcPtr		 releaseBlockProc,
									 SetEndOfForkProcPtr		 setEndOfForkProc,
									 SetBlockSizeProcPtr		 setBlockSizeProc );

extern OSStatus	BTClosePath			(FCB		 				*filePtr );


extern OSStatus	BTSearchRecord		(FCB		 				*filePtr,
									 BTreeIterator				*searchIterator,
									 UInt32						heuristicHint,
									 FSBufferDescriptor			*btRecord,
									 UInt16						*recordLen,
									 BTreeIterator				*resultIterator );

extern OSStatus	BTIterateRecord		(FCB		 				*filePtr,
									 BTreeIterationOperation	 operation,
									 BTreeIterator				*iterator,
									 FSBufferDescriptor			*btRecord,
									 UInt16						*recordLen );

extern OSStatus	BTInsertRecord		(FCB		 				*filePtr,
									 BTreeIterator				*iterator,
									 FSBufferDescriptor			*btrecord,
									 UInt16						 recordLen );

extern OSStatus	BTReplaceRecord		(FCB		 				*filePtr,
									 BTreeIterator				*iterator,
									 FSBufferDescriptor			*btRecord,
									 UInt16						 recordLen );

extern OSStatus	BTSetRecord			(FCB		 				*filePtr,
									 BTreeIterator				*iterator,
									 FSBufferDescriptor			*btRecord,
									 UInt16						 recordLen );

extern OSStatus	BTDeleteRecord		(FCB		 				*filePtr,
									 BTreeIterator				*iterator );

extern OSStatus	BTGetInformation	(FCB		 				*filePtr,
									 UInt16						 version,
									 BTreeInfoRec				*info );

extern OSStatus	BTFlushPath			(FCB		 				*filePtr );

extern OSStatus	BTInvalidateHint	(BTreeIterator				*iterator );

#endif // __BTREESINTERNAL__
