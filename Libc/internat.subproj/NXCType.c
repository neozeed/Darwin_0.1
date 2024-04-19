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
#pragma CC_NO_MACH_TEXT_SECTIONS
/*
 * Copyright 1990, NeXT, Inc.
 */

/*
 * This file contains global data and the size of the global data can NOT
 * change or otherwise it would make the shared library incompatable.  This
 * file has NOT been padded to allow more data to be added to it because the
 * sizeof(char) is not expected to change.
 */
 
#include "NXCType.h"

unsigned int _NX_CTypeTable_[1 + 256] = {

/* One extra char in table: */	0,
/*    0	.notdef */	_C,
/*    1	.notdef */	_C,
/*    2	.notdef */	_C,
/*    3	.notdef */	_C,
/*    4	.notdef */	_C,
/*    5	.notdef */	_C,
/*    6	.notdef */	_C,
/*    7	.notdef */	_C,

/*    8	.notdef */	_C,
/*    9	.notdef */	_C|_S,
/*   10	.notdef */	_C|_S,
/*   11	.notdef */	_C|_S,
/*   12	.notdef */	_C|_S,
/*   13	.notdef */	_C|_S,
/*   14	.notdef */	_C,
/*   15	.notdef */	_C,

/*   16	.notdef */	_C,
/*   17	.notdef */	_C,
/*   18	.notdef */	_C,
/*   19	.notdef */	_C,
/*   20	.notdef */	_C,
/*   21	.notdef */	_C,
/*   22	.notdef */	_C,
/*   23	.notdef */	_C,

/*   24	.notdef */	_C,
/*   25	.notdef */	_C,
/*   26	.notdef */	_C,
/*   27	.notdef */	_C,
/*   28	.notdef */	_C,
/*   29	.notdef */	_C,
/*   30	.notdef */	_C,
/*   31	.notdef */	_C,

/*   32	space */	_S|_B,
/*   33	exclam */	_P,
/*   34	quotedbl */	_P,
/*   35	numbersign */	_P,
/*   36	dollar */	_P,
/*   37	percent */	_P,
/*   38	ampersand */	_P,
/*   39	quoteright */	_P,

/*   40	parenleft */	_P,
/*   41	parenright */	_P,
/*   42	asterisk */	_P,
/*   43	plus */		_P,
/*   44	comma */	_P,
/*   45	hyphen */	_P,
/*   46	period */	_P,
/*   47	slash */	_P,

/*   48	zero */		_D,
/*   49	one */		_D,
/*   50	two */		_D,
/*   51	three */	_D,
/*   52	four */		_D,
/*   53	five */		_D,
/*   54	six */		_D,
/*   55	seven */	_D,

/*   56	eight */	_D,
/*   57	nine */		_D,
/*   58	colon */	_P,
/*   59	semicolon */	_P,
/*   60	less */		_P,
/*   61	equal */	_P,
/*   62	greater */	_P,
/*   63	question */	_P,

/*   64	at */		_P,
/*   65	A */		_U|_X,
/*   66	B */		_U|_X,
/*   67	C */		_U|_X,
/*   68	D */		_U|_X,
/*   69	E */		_U|_X,
/*   70	F */		_U|_X,
/*   71	G */		_U,

/*   72	H */	_U,
/*   73	I */	_U,
/*   74	J */	_U,
/*   75	K */	_U,
/*   76	L */	_U,
/*   77	M */	_U,
/*   78	N */	_U,
/*   79	O */	_U,

/*   80	P */	_U,
/*   81	Q */	_U,
/*   82	R */	_U,
/*   83	S */	_U,
/*   84	T */	_U,
/*   85	U */	_U,
/*   86	V */	_U,
/*   87	W */	_U,

/*   88	X */	_U,
/*   89	Y */	_U,
/*   90	Z */	_U,
/*   91	bracketleft */	_P,
/*   92	backslash */	_P,
/*   93	bracketright */	_P,
/*   94	asciicircum */	_P,
/*   95	underscore */	_P,

/*   96	quoteleft */	_P,
/*   97	a */	_L|_X,
/*   98	b */	_L|_X,
/*   99	c */	_L|_X,
/*  100	d */	_L|_X,
/*  101	e */	_L|_X,
/*  102	f */	_L|_X,
/*  103	g */	_L,

/*  104	h */	_L,
/*  105	i */	_L,
/*  106	j */	_L,
/*  107	k */	_L,
/*  108	l */	_L,
/*  109	m */	_L,
/*  110	n */	_L,
/*  111	o */	_L,

/*  112	p */	_L,
/*  113	q */	_L,
/*  114	r */	_L,
/*  115	s */	_L,
/*  116	t */	_L,
/*  117	u */	_L,
/*  118	v */	_L,
/*  119	w */	_L,

/*  120	x */	_L,
/*  121	y */	_L,
/*  122	z */	_L,
/*  123	braceleft */	_P,
/*  124	bar */		_P,
/*  125	braceright */	_P,
/*  126	asciitilde */	_P,
/*  127	.notdef */	_C,

/*  128	.notdef */	_C,
/*  129	Agrave */	_U,
/*  130	Aacute */	_U,
/*  131	Acircumflex */	_U,
/*  132	Atilde */	_U,
/*  133	Adieresis */	_U,
/*  134	Aring */	_U,
/*  135	Ccedilla */	_U,

/*  136	Egrave */	_U,
/*  137	Eacute */	_U,
/*  138	Ecircumflex */	_U,
/*  139	Edieresis */	_U,
/*  140	Igrave */	_U,
/*  141	Iacute */	_U,
/*  142	Icircumflex */	_U,
/*  143	Idieresis */	_U,

/*  144	Eth */		_U,
/*  145	Ntilde */	_U,
/*  146	Ograve */	_U,
/*  147	Oacute */	_U,
/*  148	Ocircumflex */	_U,
/*  149	Otilde */	_U,
/*  150	Odieresis */	_U,
/*  151	Ugrave */	_U,

/*  152	Uacute */	_U,
/*  153	Ucircumflex */	_U,
/*  154	Udieresis */	_U,
/*  155	Yacute */	_U,
/*  156	Thorn */	_U,
/*  157	mu */		_P,
/*  158	multiply */	_P,
/*  159	divide */	_P,

/*  160	copyright */	_P,
/*  161	exclamdown */	_P,
/*  162	cent */		_P,
/*  163	sterling */	_P,
/*  164	fraction */	_P,
/*  165	yen */		_P,
/*  166	florin */	_P,
/*  167	section */	_P,

/*  168	currency */	_P,
/*  169	quotesingle */	_P,
/*  170	quotedblleft */	_P,
/*  171	guillemotleft */ _P,
/*  172	guilsinglleft */ _P,
/*  173	guilsinglright */ _P,
/*  174	fi */		_L,
/*  175	fl */		_L,

/*  176	registered */	_P,
/*  177	endash */	_P,
/*  178	dagger */	_P,
/*  179	daggerdbl */	_P,
/*  180	periodcentered */ _P,
/*  181	brokenbar */	_P,
/*  182	paragraph */	_P,
/*  183	bullet */	_P,

/*  184	quotesinglbase */ _P,
/*  185	quotedblbase */	_P,
/*  186	quotedblright */ _P,
/*  187	guillemotright */ _P,
/*  188	ellipsis */	_P,
/*  189	perthousand */	_P,
/*  190	logicalnot */	_P,
/*  191	questiondown */	_P,

/*  192	onesuperior */	_P,
/*  193	grave */	_P,
/*  194	acute */	_P,
/*  195	circumflex */	_P,
/*  196	tilde */	_P,
/*  197	macron */	_P,
/*  198	breve */	_P,
/*  199	dotaccent */	_P,

/*  200	dieresis */	_P,
/*  201	twosuperior */	_P,
/*  202	ring */		_P,
/*  203	cedilla */	_P,
/*  204	threesuperior */ _P,
/*  205	hungarumlaut */	_P,
/*  206	ogonek */	_P,
/*  207	caron */	_P,

/*  208	emdash */	_P,
/*  209	plusminus */	_P,
/*  210	onequarter */	_P,
/*  211	onehalf */	_P,
/*  212	threequarters */ _P,
/*  213	agrave */	_L,
/*  214	aacute */	_L,
/*  215	acircumflex */	_L,

/*  216	atilde */	_L,
/*  217	adieresis */	_L,
/*  218	aring */	_L,
/*  219	ccedilla */	_L,
/*  220	egrave */	_L,
/*  221	eacute */	_L,
/*  222	ecircumflex */	_L,
/*  223	edieresis */	_L,

/*  224	igrave */	_L,
/*  225	AE */		_U,
/*  226	iacute */	_L,
/*  227	ordfeminine */	_P,
/*  228	icircumflex */	_L,
/*  229	idieresis */	_L,
/*  230	eth */		_L,
/*  231	ntilde */	_L,

/*  232	Lslash */	_U,
/*  233	Oslash */	_U,
/*  234	OE */		_U,
/*  235	ordmasculine */	_P,
/*  236	ograve */	_L,
/*  237	oacute */	_L,
/*  238	ocircumflex */	_L,
/*  239	otilde */	_L,

/*  240	odieresis */	_L,
/*  241	ae */		_L,
/*  242	ugrave */	_L,
/*  243	uacute */	_L,
/*  244	ucircumflex */	_L,
/*  245	dotlessi */	_L,
/*  246	udieresis */	_L,
/*  247	yacute */	_L,

/*  248	lslash */	_L,
/*  249	oslash */	_L,
/*  250	oe */		_L,
/*  251	germandbls */	_L,
/*  252	thorn */	_L,
/*  253	ydieresis */	_L,
/*  254	.notdef */	_C,
/*  255	.notdef */	_C,
};

/*
 * Upper to lower and lower to upper table for NeXTStep encoding (256
 * characters).  An entry of zero means it's not an upper or lower case
 * thing (i.e., isn't alphabetic).  Otherwise, the value at a given
 * position is the opposite case equivalent.  E.g., the entry for the
 * "A" position is "a" and the entry for position "a" is "A".
 *
 * There are some pathological cases: ydieresis, germandbls, and the
 * fi & fl ligatures don't have "other case" equivalents; therefore
 * they're entered as themselves because they are in fact "lower case"
 * and the Type table lists them as _L.
 */
unsigned char _NX_ULTable_[256] = {
/*    0	.notdef */	0,
/*    1	.notdef */	0,
/*    2	.notdef */	0,
/*    3	.notdef */	0,
/*    4	.notdef */	0,
/*    5	.notdef */	0,
/*    6	.notdef */	0,
/*    7	.notdef */	0,
/*    8	.notdef */	0,
/*    9	.notdef */	0,
/*   10	.notdef */	0,
/*   11	.notdef */	0,
/*   12	.notdef */	0,
/*   13	.notdef */	0,
/*   14	.notdef */	0,
/*   15	.notdef */	0,
/*   16	.notdef */	0,
/*   17	.notdef */	0,
/*   18	.notdef */	0,
/*   19	.notdef */	0,
/*   20	.notdef */	0,
/*   21	.notdef */	0,
/*   22	.notdef */	0,
/*   23	.notdef */	0,
/*   24	.notdef */	0,
/*   25	.notdef */	0,
/*   26	.notdef */	0,
/*   27	.notdef */	0,
/*   28	.notdef */	0,
/*   29	.notdef */	0,
/*   30	.notdef */	0,
/*   31	.notdef */	0,
/*   32	space */	0,
/*   33	exclam */	0,
/*   34	quotedbl */	0,
/*   35	numbersign */	0,
/*   36	dollar */	0,
/*   37	percent */	0,
/*   38	ampersand */	0,
/*   39	quoteright */	0,
/*   40	parenleft */	0,
/*   41	parenright */	0,
/*   42	asterisk */	0,
/*   43	plus */		0,
/*   44	comma */	0,
/*   45	hyphen */	0,
/*   46	period */	0,
/*   47	slash */	0,
/*   48	zero */		0,
/*   49	one */		0,
/*   50	two */		0,
/*   51	three */	0,
/*   52	four */		0,
/*   53	five */		0,
/*   54	six */		0,
/*   55	seven */	0,
/*   56	eight */	0,
/*   57	nine */		0,
/*   58	colon */	0,
/*   59	semicolon */	0,
/*   60	less */		0,
/*   61	equal */	0,
/*   62	greater */	0,
/*   63	question */	0,
/*   64	at */		0,
/*   65	A */		97,
/*   66	B */		98,
/*   67	C */		99,
/*   68	D */		100,
/*   69	E */		101,
/*   70	F */		102,
/*   71	G */		103,
/*   72	H */		104,
/*   73	I */	105,
/*   74	J */	106,
/*   75	K */	107,
/*   76	L */	108,
/*   77	M */	109,
/*   78	N */	110,
/*   79	O */	111,
/*   80	P */	112,
/*   81	Q */	113,
/*   82	R */	114,
/*   83	S */	115,
/*   84	T */	116,
/*   85	U */	117,
/*   86	V */	118,
/*   87	W */	119,
/*   88	X */	120,
/*   89	Y */	121,
/*   90	Z */	122,
/*   91	bracketleft */	0,
/*   92	backslash */	0,
/*   93	bracketright */	0,
/*   94	asciicircum */	0,
/*   95	underscore */	0,
/*   96	quoteleft */	0,
/*   97	a */	65,
/*   98	b */	66,
/*   99	c */	67,
/*  100	d */	68,
/*  101	e */	69,
/*  102	f */	70,
/*  103	g */	71,
/*  104	h */	72,
/*  105	i */	73,
/*  106	j */	74,
/*  107	k */	75,
/*  108	l */	76,
/*  109	m */	77,
/*  110	n */	78,
/*  111	o */	79,
/*  112	p */	80,
/*  113	q */	81,
/*  114	r */	82,
/*  115	s */	83,
/*  116	t */	84,
/*  117	u */	85,
/*  118	v */	86,
/*  119	w */	87,
/*  120	x */	88,
/*  121	y */	89,
/*  122	z */	90,
/*  123	braceleft */	0,
/*  124	bar */		0,
/*  125	braceright */	0,
/*  126	asciitilde */	0,
/*  127	.notdef */	0,
/*  128	.notdef */	0,
/*  129	Agrave */	213,
/*  130	Aacute */	214,
/*  131	Acircumflex */	215,
/*  132	Atilde */	216,
/*  133	Adieresis */	217,
/*  134	Aring */	218,
/*  135	Ccedilla */	219,
/*  136	Egrave */	220,
/*  137	Eacute */	221,
/*  138	Ecircumflex */	222,
/*  139	Edieresis */	223,
/*  140	Igrave */	224,
/*  141	Iacute */	226,
/*  142	Icircumflex */	228,
/*  143	Idieresis */	229,
/*  144	Eth */		230,
/*  145	Ntilde */	231,
/*  146	Ograve */	236,
/*  147	Oacute */	237,
/*  148	Ocircumflex */	238,
/*  149	Otilde */	239,
/*  150	Odieresis */	240,
/*  151	Ugrave */	242,
/*  152	Uacute */	243,
/*  153	Ucircumflex */	244,
/*  154	Udieresis */	246,
/*  155	Yacute */	247,
/*  156	Thorn */	252,
/*  157	mu */		0,
/*  158	multiply */	0,
/*  159	divide */	0,
/*  160	copyright */	0,
/*  161	exclamdown */	0,
/*  162	cent */		0,
/*  163	sterling */	0,
/*  164	fraction */	0,
/*  165	yen */		0,
/*  166	florin */	0,
/*  167	section */	0,
/*  168	currency */	0,
/*  169	quotesingle */	0,
/*  170	quotedblleft */	0,
/*  171	guillemotleft */ 0,
/*  172	guilsinglleft */ 0,
/*  173	guilsinglright */ 0,
/*  174	fi */		174,	/* is self */
/*  175	fl */		175,	/* is self */
/*  176	registered */	0,
/*  177	endash */	0,
/*  178	dagger */	0,
/*  179	daggerdbl */	0,
/*  180	periodcentered */ 0,
/*  181	brokenbar */	0,
/*  182	paragraph */	0,
/*  183	bullet */	0,
/*  184	quotesinglbase */ 0,
/*  185	quotedblbase */	0,
/*  186	quotedblright */ 0,
/*  187	guillemotright */ 0,
/*  188	ellipsis */	0,
/*  189	perthousand */	0,
/*  190	logicalnot */	0,
/*  191	questiondown */	0,
/*  192	onesuperior */	0,
/*  193	grave */	0,
/*  194	acute */	0,
/*  195	circumflex */	0,
/*  196	tilde */	0,
/*  197	macron */	0,
/*  198	breve */	0,
/*  199	dotaccent */	0,
/*  200	dieresis */	0,
/*  201	twosuperior */	0,
/*  202	ring */		0,
/*  203	cedilla */	0,
/*  204	threesuperior */ 0,
/*  205	hungarumlaut */	0,
/*  206	ogonek */	0,
/*  207	caron */	0,
/*  208	emdash */	0,
/*  209	plusminus */	0,
/*  210	onequarter */	0,
/*  211	onehalf */	0,
/*  212	threequarters */ 0,
/*  213	agrave */	129,
/*  214	aacute */	130,
/*  215	acircumflex */	131,
/*  216	atilde */	132,
/*  217	adieresis */	133,
/*  218	aring */	134,
/*  219	ccedilla */	135,
/*  220	egrave */	136,
/*  221	eacute */	137,
/*  222	ecircumflex */	138,
/*  223	edieresis */	139,
/*  224	igrave */	140,
/*  225	AE */		241,
/*  226	iacute */	141,
/*  227	ordfeminine */	0,
/*  228	icircumflex */	142,
/*  229	idieresis */	143,
/*  230	eth */		144,
/*  231	ntilde */	145,
/*  232	Lslash */	248,
/*  233	Oslash */	249,
/*  234	OE */		250,
/*  235	ordmasculine */	0,
/*  236	ograve */	146,
/*  237	oacute */	147,
/*  238	ocircumflex */	148,
/*  239	otilde */	149,
/*  240	odieresis */	150,
/*  241	ae */		225,
/*  242	ugrave */	151,
/*  243	uacute */	152,
/*  244	ucircumflex */	153,
/*  245	dotlessi */	245,	/* is self */
/*  246	udieresis */	154,
/*  247	yacute */	155,
/*  248	lslash */	232,
/*  249	oslash */	233,
/*  250	oe */		234,
/*  251	germandbls */	251,	/* is self */
/*  252	thorn */	156,
/*  253	ydieresis */	253,	/* is self */
/*  254	.notdef */	0,
/*  255	.notdef */	0
};

