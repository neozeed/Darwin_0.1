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
 *	performsound.h - recording and playback of sound.
 *	Copyright 1988-89 NeXT, Inc.
 *
 */

#import "soundstruct.h"
#import "sounderror.h"

typedef int (*SNDNotificationFun)(SNDSoundStruct *s, int tag, int err);
#define SND_NULL_FUN ((SNDNotificationFun)0)
/*
 * Notification functions are called when some event occurs in the sound 
 * library, and are always explicitly given to the sound library (i.e. as
 * arguments in SNDStartPlaying).
 * They always take three arguments: the sound structure, the tag, and
 * an error code.
 * The integer returned is ignored.
 */

int SNDStartPlaying(SNDSoundStruct *s, int tag, int priority, int preempt,
		    SNDNotificationFun beginFun, SNDNotificationFun endFun);
/*
 * Initiates the playing of the sound "s". This function returns
 * immediately, and playing continues in the background until the
 * the entire sound has been played.
 * The tag is used for identification of the sound for the SNDStop, 
 * SNDWait, and SNDSamplesProcessed routines. It must be unique.
 * The priority is used to help resolve conflict if the sound cannot
 * be immediately played. Higher priorities can cause interruption
 * of lower priority sounds. Zero is defined to be lowest priority,
 * and larger numbers are of higher priority. Negative priorities are
 * reserved. When a sound is interrupted, it may not be resumed (i.e. an
 * interruption is equivalent to an abort).
 * The preempt flag, when non-zero, allows the sound to interrupt other
 * sounds of equal or inferior priority. If preempt is zero, then the sound is
 * enqueued for playback on a first-come-first-served basis (the priority is
 * not used to determine when to play the sound, but rather only to determine
 * what can interrupt it while it is playing).
 * Both the beginFun and endFun are optional: when non-null, they call
 * the given function with the soundstruct, tag, and an error code as
 * arguments, when playback of the  sound begins and ends, respectively.
 * These functions are called in the context of a background thread. 
 * This routine returns an error if the sound cannot be played.
 */

int SNDWait(int tag);
/*
 * Return only when playback or recording of the sound matching the given tag 
 * has completed. If several requests have the same tag, the last one is
 * waited for.
 * An error code is returned.
 */

int SNDStop(int tag);
/*
 * Terminates the playback or recording of sound with the given tag.
 * An error code is returned.
 */

int SNDStartRecording(SNDSoundStruct *s, int tag, int priority, int preempt,
		     SNDNotificationFun beginFun, SNDNotificationFun endFun);
/*
 * Begins recording into the specified sound structure.
 * The codec type, dsp_data types, and compressed types are supported.
 */

int SNDStartRecordingFile(char *fileName, SNDSoundStruct *s,
			  int tag, int priority, int preempt,
			  SNDNotificationFun beginFun, SNDNotificationFun endFun);
/*
 * Same as SNDStartRecording() but writes directly to file fileName.  The sound data
 * is NOT returned in "s".
 */

int SNDSamplesProcessed(int tag);
/*
 * Return a count of the number of samples played or recorded in the sound 
 * matching the given tag.
 * A negative return value indicates an error.
 */

int SNDModifyPriority(int tag, int new_priority);
/*
 * Modifies the priority of the sound matching the given tag.
 * This could cause the sound to either be interrupted or played
 * immediately.
 * An error code is returned.
 */

int SNDSetVolume(int left, int right);
int SNDGetVolume(int *left, int *right);
/*
 * Get/set the volume of the sound for left and right channels.
 * The line out jacks on the back of the monitor are not affected;
 * only the speaker (if it is not muted) and the headphone levels
 * are affected.
 * An error code is returned.
 *  
 */

int SNDSetMute(int speakerOn);
int SNDGetMute(int *speakerOn);
/*
 * Set/get the state of the monitor's built-in speaker. Zero indicates
 * that the speaker is silent. This does not affect the line out jacks
 * on the back of the monitor -- they are always enabled.
 * An error code is returned.
 */

int SNDSetCompressionOptions(SNDSoundStruct *s, int bitFaithful, int dropBits);
int SNDGetCompressionOptions(SNDSoundStruct *s, int *bitFaithful, int *dropBits);
/*
 * Set/get the compression options for the sound "s."  SNDStartRecording() uses
 * these options when recording into the sound.  If bitFaithful is non-zero,
 * the recorded sound can be decompressed exactly back to its original samples.
 * Otherwise the decompressed sound will have some degradation.  The dropBits
 * parameter specifys the number of bits to right shift off of each sample
 * before compressing.  It ranges from 4 to 8 bits, with higher numbers
 * giving more compression but less fidelity.  In bit faithful mode, dropBits
 * may affect the amount of compression, but decompression will still be
 * exact.
 * If this function is not called before recording, bitFaithful defaults to
 * true and dropBits defaults to 4.
 * An error code is returned.
 */

int SNDSetFilter(int filterOn);
int SNDGetFilter(int *filterOn);
/*
 * Set/get the state of the low-pass filter. Zero indicates
 * that the filter is off. The low-pass filter is used for
 * playing back emphasized sounds.
 * An error code is returned.
 */

int SNDVerifyPlayable(SNDSoundStruct *s);
/*
 * Returns SND_ERR_NONE (0) if sound is in a playable format, or
 * SND_ERR_CANNOT_PLAY if it requires format conversion in advance
 * of playing (or if it is inherently unplayable such as format
 * SND_FORMAT_DSP_CORE).
 */
