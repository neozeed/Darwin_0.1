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


	include	"dspsound.asm"

DMASIZE		equ	4096

main
	move	#>XRAMLO,r5		;
	move	r5,x:1			;
	move	#>XRAMLO+DMASIZE,r6	;use external RAM for double buffers
	move	r6,x:0			;
	move	#>DMASIZE-1,m5		;
	move	#>DMASIZE-1,m6		;
	move	#1,n6			;
	move	#1,n5			;
	move	#>$008000,y1		;scale factor for 16 bit output
	jsr	start			;
	movep	#$4100,x:SSI_CRA	; Set up serial port
	movep	#$2a00,x:SSI_CRB	; 	in network mode
	move	#>DMASIZE,a
	do	a,prime2		;prime the first buffer
prime					;
	jclr	#SSI_RDF,x:SSI_SR,prime ;
	movep	x:SSI_RX,x:(r5)+	;
prime2					;
					;
loop					;while (1) {
	move	x:1,r6			;
	move	x:0,r5			;
	move	r6,x:0			;    swap buffers
	move	r5,x:1			;
beginBuf				;
	jclr	#SSI_RDF,x:SSI_SR,_beg2	;
	movep	x:SSI_RX,x:(r5)+	;
_beg2					;
	jclr	#HTDE,x:HSR,beginBuf	;    start DMA
	movep	#DM_R_REQ,x:HTX		;
_ackBegin				;
	jclr	#SSI_RDF,x:SSI_SR,_ack2	;
	movep	x:SSI_RX,x:(r5)+	;
_ack2					;
	jclr	#HF1,x:HSR,_ackBegin	;
	
	move	#>DMASIZE,a		;
	do	a,senddone		;    send the output buffer
send					;
	jclr	#SSI_RDF,x:SSI_SR,_foo	;
	movep	x:SSI_RX,x:(r5)+	;
_foo					;
	jclr	#HTDE,x:HSR,send	;
	move	x:(r6)+,x1		;
	mpy	x1,y1,a			;
	move	a,x:HTX			;    
senddone				;
					;
_prodDMA				;    handshake the DMA
	btst	#DMA_DONE,x:x_sFlags	;
	jcs	endDMA			;
	jclr	#SSI_RDF,x:SSI_SR,_foo	;
	movep	x:SSI_RX,x:(r5)+	;
_foo					;
	jclr	#HTDE,x:HSR,_prodDMA	;
	movep	#0,x:HTX		;
	jmp	_prodDMA		;
endDMA					;
	bclr	#DMA_DONE,x:x_sFlags	;
_ackEnd					;
	jclr	#SSI_RDF,x:SSI_SR,_foo	;
	movep	x:SSI_RX,x:(r5)+	;
_foo					;
	jset	#HF1,x:HSR,_ackEnd	;
					;
finin					;    finish filling the input buffer
	move	x:1,b			;
	move	r5,a			;
	cmp	a,b			;
	jeq	loop_end		;
_foo					;
	jclr	#SSI_RDF,x:SSI_SR,_foo	;
	movep	x:SSI_RX,x:(r5)+	;
	jmp	finin			;}
loop_end				;
	jset	#HF0,x:HSR,stop		;
	jmp	loop			;


