NOT_DEBUG equ (1)  ; 0 enables simulator; 1 enables real-time use
;;;;
;; Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
;;
;; @APPLE_LICENSE_HEADER_START@
;; 
;; "Portions Copyright (c) 1999 Apple Computer, Inc.  All Rights
;; Reserved.  This file contains Original Code and/or Modifications of
;; Original Code as defined in and that are subject to the Apple Public
;; Source License Version 1.0 (the 'License').  You may not use this file
;; except in compliance with the License.  Please obtain a copy of the
;; License at http://www.apple.com/publicsource and read it before using
;; this file.
;; 
;; The Original Code and all software distributed under the License are
;; distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
;; EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
;; INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
;; License for the specific language governing rights and limitations
;; under the License."
;; 
;; @APPLE_LICENSE_HEADER_END@
;;;;
;;  Copyright 1989 by NeXT Inc.
;;  Author - Dana Massie 
;;      
;;  Modification history
;;  --------------------
;;      04/04/89/dcm - modified from mulawcodec.asm
;;  ------------------------------ DOCUMENTATION ---------------------------
;;  NAME
;;      mulawcodecsquelch - interpolation for muLaw codec data which has had
;;	silences run-length encoded
;;        -takes a buffer of 8 kHz codec muLaw data and produces 22kHz
;;	    stereo linear data for sound playback.
;;      
;;  DESCRIPTION ************************************************************
;;   This sample rate conversion algorithm relies heavily on the discussion in
;;   Crochiere and Rabiner, "Multirate Digital Signal Processing", 
;;   Prentice-Hall, 1984.  This is a standard polyphase filter implementation
;;   of a 11/4 sample rate convertor.  Input data are muLaw, output data are
;;   stereo 16 bit linear. 
;;	
;;   The run-length encoding of silences is formatted in up to 256 byte blocks,
;;   with the actual length stored in the second byte.
;    2 bytes are actually used to encode the run; the first (header) byte
;;   encodes whether the run contains sample data or zeros, the second
;;   contains the length (up to 255). The header byte is also a 
;;   synchronization word; if it is not one of two distinct
;;   values, then the dsp knows that the data stream is out of synch,
;;   and potentially invalid.
;;   
;;   The fundamental equation is
;;   y(m) = sum ( g(m) * x[ (int)(mM) - n ]
;;   where g(m) = h[nL + mM % L]
;;         h[ ] = lowpass filter 
;;         M == decimation ratio (4)
;;         L == Interpolation Ratio (11)
;;         n == 0 to number of multiplies (9)
;;	   % == modulo operation
;;	The quantity (int)(mM) is the integer input pointer advance.
;;	The (mM - n ) just runs through the input vector.
;;  MEMORY USE
;;      N = number of multiply-adds per output sample ( probably 9 )
;;      ???   program memory locations
;;      ((N * 11)+1) / 2 words x-memory space for the filter coefficients
;;      N + 3 words y-memory modulo storage for the filter state vector
;;      
;;  IPORTANT EXTENSIONS TO BE IMPLEMENTED
;;	Make this interpolator multichannel.
;;	Allow a simple upgrade to produce 44.1 kHz out, instead of 22 k
;;

	page 255,255,0,1,1
	include	"dspsound.asm"
;
; Equates here :
FALSE	equ 0
N_MULS equ (13)  ; number of multiplies per output sample (Q) (odd)
	; Q + 3 samples needed for complete 11 sample run
	; FILT_STATE_TABLE_LEN must be a multiple of 4.
	; It must also be more than number of multiplies.
FILT_STATE_TABLE_LEN equ (N_MULS+3)
INTERP_FACTOR	equ (11)
DEC_FACTOR	equ  (4)
FILT_TABLE_LEN equ (N_MULS*INTERP_FACTOR)

; move this equates into a global file (from ~/dsp/smsrc/memmap.asm)
XLI_MLT		equ  (256)	; mulaw table address in rom

; input state table or filter state table
; Initialize the input state vector to zero.
; Sleaze Alert!!!
; We really need to keep "Location Counters" for X and Y mem.


state		equ	(0)	; reserve mod space in Y memory.
ymemRunFlag	equ	(FILT_STATE_TABLE_LEN+1) ; reserve Y mem for runFlag
ymemRunLen	equ	(ymemRunFlag+1)
runbit		equ	(0)
ZeroRunFlag	equ	($55)	; arbitrary flag with lsb==1
SampleRunFlag	equ	($AA)	; arbitrary flag with lsb==0
InitFileFlag	equ	($A5)	; arbitrary flag to indicate sample len word

xInputInc	equ	(0) ; X mem Mod storage: len=FILT_STATE_TABLE_LEN
xmem_coeff	equ	(FILT_STATE_TABLE_LEN)	; use x memory

testpoint	equ	($80)  ; this should be a free location for testpoint

; Initialize pointer into the state table to store the output of the mulaw
; convertor.  The output of the mulaw must be 4 samples before the end
; of the state buffer, however long that might be.
OUT_POINTER_MULAW equ	(state+N_MULS-1)

; table of increments for input sample pointer
;	sub phase		: 0  1  2  3  4  5  6  7  8  9  10
;	input sample pointer	: 0  0  0  1  1  1  2  2  2  3  3
;	increment table		: 1  0  0  1  0  0  1  0  0  1  0

inctablen   equ (11)
inputInc    dc	1
	    dc	0
	    dc	0
	    dc	1
	    dc	0
	    dc	0
	    dc	1
	    dc	0
	    dc	0
	    dc	1
	    dc	0

; filter coeff table follows. This table generated by interpFilter.c
; in ~dana/src/dsp/interp/filt.
; Note ! Filter Coeff Table stored in scrambled order to make indexing trivial

coeff	dc	-0.004282584
	dc	 0.014319006
	dc	-0.035745670
	dc	 0.078044416
	dc	-0.170543097
	dc	 0.555492041
	dc	 0.670594562
	dc	-0.184561390
	dc	 0.083575947
	dc	-0.038520185
	dc	 0.015699667
	dc	-0.004873979
	dc	 0.000712003
	dc	-0.000682165
	dc	 0.002752407
	dc	-0.007456153
	dc	 0.016858635
	dc	-0.036080616
	dc	 0.091606308
	dc	 0.966887889
	dc	-0.074516770
	dc	 0.031336749
	dc	-0.014648880
	dc	 0.006329910
	dc	-0.002223295
	dc	 0.000484624
	dc	 0.000875975
	dc	-0.004750427
	dc	 0.014320325
	dc	-0.034053311
	dc	 0.073194980
	dc	-0.166493050
	dc	 0.860812276
	dc	 0.313276621
	dc	-0.111907211
	dc	 0.051942610
	dc	-0.023423484
	dc	 0.009031366
	dc	-0.002481025
	dc	-0.003438900
	dc	 0.011974525
	dc	-0.030450333
	dc	 0.066969021
	dc	-0.145154685
	dc	 0.434472982
	dc	 0.774114228
	dc	-0.184056148
	dc	 0.082251580
	dc	-0.038108637
	dc	 0.015785312
	dc	-0.005072164
	dc	 0.000841550
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.980690769
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000000000
	dc	 0.000841550
	dc	-0.005072164
	dc	 0.015785312
	dc	-0.038108637
	dc	 0.082251580
	dc	-0.184056148
	dc	 0.774114228
	dc	 0.434472982
	dc	-0.145154685
	dc	 0.066969021
	dc	-0.030450333
	dc	 0.011974525
	dc	-0.003438900
	dc	-0.002481025
	dc	 0.009031366
	dc	-0.023423484
	dc	 0.051942610
	dc	-0.111907211
	dc	 0.313276621
	dc	 0.860812276
	dc	-0.166493050
	dc	 0.073194980
	dc	-0.034053311
	dc	 0.014320325
	dc	-0.004750427
	dc	 0.000875975
	dc	 0.000484624
	dc	-0.002223295
	dc	 0.006329910
	dc	-0.014648880
	dc	 0.031336749
	dc	-0.074516770
	dc	 0.966887889
	dc	 0.091606308
	dc	-0.036080616
	dc	 0.016858635
	dc	-0.007456153
	dc	 0.002752407
	dc	-0.000682165
	dc	 0.000712003
	dc	-0.004873979
	dc	 0.015699667
	dc	-0.038520185
	dc	 0.083575947
	dc	-0.184561390
	dc	 0.670594562
	dc	 0.555492041
	dc	-0.170543097
	dc	 0.078044416
	dc	-0.035745670
	dc	 0.014319006
	dc	-0.004282584
	dc	-0.001530403
	dc	 0.005849778
	dc	-0.015494560
	dc	 0.034678585
	dc	-0.074402469
	dc	 0.197365637
	dc	 0.926211872
	dc	-0.130192090
	dc	 0.056100818
	dc	-0.026178693
	dc	 0.011164987
	dc	-0.003814969
	dc	 0.000769502
	dc	 0.000769502
	dc	-0.003814969
	dc	 0.011164987
	dc	-0.026178693
	dc	 0.056100818
	dc	-0.130192090
	dc	 0.926211872
	dc	 0.197365637
	dc	-0.074402469
	dc	 0.034678585
	dc	-0.015494560
	dc	 0.005849778
	dc	-0.001530403
;*****************************************************************************

; *************		Main Loop !!   		*****************************
main
;*********  Initialization *********
;
;	R0	filter coeff vector address, also temp pointer for init
;	R1	temp pointer for init; also used for runlen and runflag ptr
;	R2	Current Start Address of Filter State Vector
;	R3	(Output from Mulin) Filter State Vector Address for Input 
;	R4	Input Sample Pointer Increment address
;	R5	State vector address
;	R6	mulaw table lookup pointer
;	R7	unused
;
;	M2,3,4,5 Filter State Vector Size - 1
;	Y0	unused
;	Y1	MuLaw input
;	X0	shift constant for mulaw
;	X1	mu table base and offset
;	A	linear output
;	B	mulaw positive result
; *******************************************************************************
;
	; move filter coeffs into x memory! (Maybe later we
	; can have a different loader, which will directly load
	; the x and y memory spaces!)
        move	#coeff,r0	; filter coeff source vector address
	move	#xmem_coeff,r1		; destination x mem address
	do	#FILT_TABLE_LEN,move_coeff
	movem	p:(r0)+,x0
	move	x0,x:(r1)+
move_coeff
	
; zero out state table in Y memory
	clr	a
	move	#state,r0
	rep	#FILT_STATE_TABLE_LEN
	move	a,y:(r0)+
	
; Move table of increments into x memory
	move	#inputInc,r0
	move	#xInputInc,r1
	
	do	#inctablen,move_inc
	movem	p:(r0)+,x0
	move	x0,x:(r1)+
	nop
move_inc

; Zero out y mem locations for runFlag and runLen
	move	#ymemRunFlag,r1
	clr	a
	move	a,y:(r1)+
	move	a,y:(r1)
	
; Init for main loop.
	move	#OUT_POINTER_MULAW,r3	; initial value of mulaw output
;	Set up modulo addressing for filter state table addressing.
	move	#FILT_STATE_TABLE_LEN-1,m2
	move	#FILT_STATE_TABLE_LEN-1,m3
	move	#inctablen-1,m4 
	move	#FILT_STATE_TABLE_LEN-1,m5
        move	#state,r2	; filter state vector
	move	#>$8000,y0	; shift constant to move sample to lsb's
	move	(r2)-	; (need Mod reg) decrement for initial value only
	jsr	start
;	
	jsr	getFlag	; init for run-len decode
;
;********* End Initialization *********
;****************************************************************************

; 	|||||||
loop
; 	|||||||

; Perform the mu-law to linear conversion for 4 samples.
; Get input muLaw data, translate it, and store it into state table.
;
mushift	equ	$80

	do	#4,samp4loop
	move	#ymemRunFlag,r1	
	clr	a			; source of zero for zero runs
	jclr	#runbit,y:(r1),sampRun	; if (runBit ==0 ) goto sampRun
        move	a1,y:(r3)+		; save xlated data in state table
	jmp	pastmu
sampRun

	if NOT_DEBUG
	jsr	getHost			; leaves input data in A1
	jcs	stop	; we really should do an enddo for safety here
	else
	move	x:$f1,a
	endif

	; mask off relevant bits to be safe!
	move	#>$0ff,x0
	and	x0,a
	
	; translate mulaw to linear
	tfr	a,b	#>$7f,x0
	and	x0,a	#XLI_MLT,x1
	add	x1,a	b,x0
	move	a1,r6
	move	#>$8000,y1
	mpy	x0,y1,b
	move	b0,b1
	lsl	b	x:(r6),a
	neg	a	a,b
	tcs	b,a	
        move	a1,y:(r3)+		; save xlated data in state table

pastmu

	;  if ( --runLen == 0 ) getHeaderByte; getRunLen;
	move	#ymemRunLen,r1
	nop
	move	y:(r1),b
	move	#>1,a
	sub	a,b	; --runLen
	tst	b
	move	b,y:(r1)	; save decremented value	
	jsle	getFlag	; get preamble for sample run

			

samp4loop

; ****************************************************************************
;     Now set up a context to interpolate the linear data.
;     Put coefficient table in X memory, filter state table in Y memory
;
; ****************************************************************************
; *************   start an output sample calculation here!  ******************
	move	#xInputInc,r4	; input sample pointer increment table
        move	#xmem_coeff,r0	; filter coeff address
	move	x:(r4)+,n2	; load first input sample pointer increment
;	move	x:(r0)+,x0	; load first filter coeff for mult run
 ; *************   Polyphase filter loop         ***************************
	do	#11,polyloop	; compute 11 output samps
	move	(r2)+n2
	move	x:(r4)+,n2	; load next input sample pointer increment
	move	r2,r5		; update r5
	nop
	clr	a	x:(r0)+,x0	y:(r5)+,y1 ; load input sample & coeff
	rep	#N_MULS-1		; compute both wings
;	my main mac=>		filter coeff	next sample value
        mac	x0,y1,a		x:(r0)+,x0	y:(r5)+,y1
	macr	x0,y1,a
	move	a,x1
	mpy	x1,y0,a		; shift data to LSB's for extraction

	if NOT_DEBUG

	jsr	putHost
	jsr	putHost
	jcc	keepgoing
	enddo			; break out of this loop, we are done!
	jmp	stop
keepgoing

	else
	move	a,x:$f0		; write to this location for output file
	endif

	nop
polyloop
	jmp loop

; init subroutine for run-length decode
; uses regs a,b
;
getFlag
	move	#ymemRunFlag,r1	; address for run flag; setup for later
	if NOT_DEBUG
	jsr	getHost			; leaves input data in A1
	jcs	stop	; we really should do an enddo for safety here
	else
	move	x:$f1,a
	endif

	; mask off relevant bits to be safe!
	move	#>$0ff,x0
	and	x0,a

	move	a,y:(r1)+		; save run Flag

	move	#>ZeroRunFlag,b	
	cmp	a,b	; cmp header with zeroRunFlag
	jeq	glen	; zero run flag valid; continue

	move	#>SampleRunFlag,b	
	cmp	a,b
	jeq	glen	; samp run flag valid; continue
	
	move	#>InitFileFlag,b    ; only once per file; discard samplelen !
	cmp	a,b	
	jne	stop	; disaster deluxe: all flags false!
	
	if NOT_DEBUG
	jsr	getHost ; one byte zero pad after magic flag 
	jsr	getHost ; discard threshold byte 0 msb
	jsr	getHost ; discard threshold byte 1 lsb
	jsr	getHost	; discard sample length - 4 bytes : byte 0
	jsr	getHost ; byte 1
	jsr	getHost ; byte 2
	jsr	getHost ; byte 3 (last byte of length )

	jsr	getHost ; 8 bytes for future expansion : 0
	jsr	getHost ; 1
	jsr	getHost ; 2
	jsr	getHost ; 3
	jsr	getHost ; 4
	jsr	getHost ; 5
	jsr	getHost ; 6
	jsr	getHost ; 7
	else
	move	x:$f1,a ; one byte zero pad after magic flag 
	move	x:$f1,a ; discard threshold byte 0 msb
	move	x:$f1,a ; discard threshold byte 1 lsb
	move	x:$f1,a	; discard sample length - 4 bytes : byte 0
	move	x:$f1,a ; byte 1
	move	x:$f1,a ; byte 2
	move	x:$f1,a ; byte 3 (last byte of length )
	
	move	x:$f1,a ; 8 bytes for future expansion : 0
	move	x:$f1,a ; 1
	move	x:$f1,a ; 2
	move	x:$f1,a ; 3
	move	x:$f1,a ; 4
	move	x:$f1,a ; 5
	move	x:$f1,a ; 6
	move	x:$f1,a ; 7
	endif
	jmp	getFlag	; continue to get next flag
glen
	if NOT_DEBUG	; get length of run
	jsr	getHost			; leaves input data in A1
	jcs	stop	; we really should do an enddo for safety here
	else
	move	x:$f1,a
	endif

	; mask off relevant bits to be safe!
	move	#>$0ff,x0
	and	x0,a
	move	a,y:(r1)	; store runLen

	rts
