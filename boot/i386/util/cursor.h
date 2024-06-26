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
static const unsigned char waitAlpha2[] =
{
    0x00,0x3f,0xfc,0x00,
    0x03,0xff,0xff,0xc0,
    0x0f,0xff,0xff,0xf0,
    0x3f,0xff,0xff,0xfc,
    0x3f,0xff,0xff,0xfc,
    0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,
    0xff,0xff,0xff,0xff,
    0x3f,0xff,0xff,0xfc,
    0x3f,0xff,0xff,0xfc,
    0x0f,0xff,0xff,0xf0,
    0x03,0xff,0xff,0xc0,
    0x00,0x3f,0xfc,0x00
};

static unsigned char waitData2W1[] =
{
    0x00,0x3F,0xFC,0x00,
    0x03,0xE9,0x42,0x80,
    0x0F,0xA9,0x41,0x60,
    0x3F,0xE9,0x05,0x54,
    0x3B,0xF9,0x15,0xA4,
    0xEA,0xB9,0x16,0xBC,
    0xD6,0x6D,0x1B,0xFC,
    0xD5,0x55,0x6E,0xA8,
    0xD1,0x01,0x55,0x98,
    0xC0,0x16,0x50,0x54,
    0xC1,0x5B,0x94,0x04,
    0x25,0x6B,0xA5,0x00,
    0x25,0xAB,0xE5,0x40,
    0x09,0xAF,0xA5,0x40,
    0x01,0x7F,0xE4,0x00,
    0x00,0x00,0x00,0x00
};

static unsigned char waitData2W2[] =
{
    0x00,0x3F,0xFC,0x00,
    0x03,0xEF,0xEA,0x80,
    0x0E,0xAF,0xA9,0x60,
    0x35,0xAB,0xA5,0x04,
    0x31,0x6B,0x94,0x04,
    0xC0,0x5B,0x90,0x54,
    0xD0,0x06,0x81,0x58,
    0xD5,0x41,0x16,0xA8,
    0xD9,0x94,0x1F,0xF8,
    0xEA,0xAD,0x1A,0xFC,
    0xEB,0xF9,0x06,0xA4,
    0x2F,0xE9,0x05,0xA0,
    0x2F,0xA9,0x05,0x60,
    0x0B,0xA5,0x41,0x40,
    0x02,0x95,0x40,0x00,
    0x00,0x00,0x00,0x00
};

static unsigned char waitData2W3[] =
{
    0x00,0x3F,0xFC,0x00,
    0x03,0xC5,0x6B,0xC0,
    0x0D,0x05,0x6B,0xF0,
    0x39,0x41,0xAF,0xF4,
    0x39,0x41,0xAF,0xA4,
    0xEA,0x51,0xAA,0x94,
    0xFE,0x94,0x95,0x54,
    0xFF,0xF9,0x00,0x00,
    0xFB,0xA4,0x55,0x00,
    0xEA,0x94,0xA9,0x54,
    0xE9,0x51,0xBA,0x54,
    0x25,0x41,0xBA,0x90,
    0x25,0x01,0xAE,0x80,
    0x09,0x05,0xAF,0x40,
    0x01,0x55,0x64,0x00,
    0x00,0x00,0x00,0x00
};
