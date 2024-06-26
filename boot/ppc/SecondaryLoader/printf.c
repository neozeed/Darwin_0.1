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
#include <Types.h>
// #include "/usr/include/setjmp.h"
/* #include "/usr/include/pure_mach/stdarg.h" */
#include "StdCFns.h"
#include <SecondaryLoader.h>

#define MULTIPLY_IS_FAST	1
#define ALIGN_FOUR	1
#define ALIGN_MASK	3

#define TLVAL(T,s)		(*((T *)&(s)))
#define CHARSTARLVAL(s)		TLVAL(char *,(s))
#define CONSTCHARSTARLVAL(s)	TLVAL(const char *,(s))
#define UCHARSTARLVAL(s)	TLVAL(unsigned char *,(s))
#define CONSTUCHARSTARLVAL(s)	TLVAL(const unsigned char *,(s))
#define LONGSTARLVAL(s)		TLVAL(long *,(s))


int min (int a, int b)
{
	return a < b ? a : b;
}


int max (int a, int b)
{
	return a > b ? a : b;
}


int abs (int a)
{
	return a < 0 ? -a : a;
}


/********************************************************************************/
/* 							IntToStr								*/
/*																*/
/* Description.													*/
/*	Convert an integer to an ASCII string representation of the integer.		*/
/*																*/
/* Input Parameters.												*/
/*	i		:  integer to convert.									*/
/*	base		:  numeric base of the representation (-10 is signed decimal).	*/
/*	padC		:  character to use when padding the representation (to the		*/
/*			   left) to fit the field.								*/
/*	fieldSize	:  size of the field holding the representation.				*/
/*	upCase	:  TRUE if the hexadecimal representation uses capital letters	*/
/*			   for digits greater than nine.							*/
/*	str		:  pointer to buffer for string representation.				*/
/*																*/
/* Output Parameters.												*/
/*			:  the function returns a pointer to the end of the string.		*/
/*			   (points at the null string-terminator character)			*/
/*																*/
/* Notes.															*/
/*	Originally written by Dan Chernikoff, procedure name aside.				*/
/*	Heavily revised by Bill Kincaid, mostly for efficiency.				*/
/*																*/
/********************************************************************************/

static char *IntToStr (int i, int base, char padC, int fieldSize, int precision, Boolean upCase, char *str)
{
	char			buffer[32];			/* local buffer for string */
	char			*p;
	unsigned int	value, mask, remainder, quotient;
	const int		*pwrs;
	short		shiftCount;
	Boolean		minus = false;
	int			j;
	static const char	digits[] = "0123456789abcdef";
	static const char	upcaseDigits[] = "0123456789ABCDEF";
	static const int	powersOfTen[] = {
		1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1
	};

	if (precision != 0) {
		fieldSize = precision;
		padC = '0';
	}
	
	p = &buffer[31];
	*p-- = '\0';

	if (base == -10) {
		if (i < 0) {
			if (i == 0x80000000) {
				/* special case -2147483648 (can't negate most negative number) */
				strcpy(str, "-2147483648");
				return (str + 11);	/* return pointing at null */
			}
			minus = true;
			i = -i;
		}
		base = 10;
	}

	/* Value to convert is non-negative at this point */
	value = i;

	if (value == 0) {
		/* 1st special case */
		*p-- = '0';
		--fieldSize;
	} else if ((base == 16) || (base == 8) || (base == 2)) {
		/* easy and common special cases, worth optimizing for */
		shiftCount = 4;
		mask = 0xF;
		if (base != 16) {
			shiftCount = (base == 8) ? 3 : 1;
			mask = (base == 8) ? 0x7 : 0x1;
		}
		while (value != 0) {
			if (upCase)
				*p-- = upcaseDigits[value & mask];
			else
				*p-- = digits[value & mask];
			--fieldSize;
			value >>= shiftCount;
		}
	} else if (base == 10) {
		/* the other common special case */
		pwrs = &powersOfTen[0];
		p = &buffer[21];	/* fill last 10 characters, not counting null */
		for (j = 0; j < 10; ++j) {
			*p = '0';
			while (value >= *pwrs) {
				++(*p);
				value -= *pwrs;
			}
			++pwrs;
			++p;
		}
		/* find leftmost nonzero digit */
		p = &buffer[21];
		while (*p == '0')
			++p;
		fieldSize -= &buffer[31] - p;
		--p;		/* p now points to rightmost leading zero */
	} else {
		/* general case- very slow but very general (works for any base) */
		while (value != 0) {
			remainder = value;
			quotient = 0;
			while (remainder >= base) {
				remainder -= base;
				++quotient;
			}
			if (upCase)
				*p-- = upcaseDigits[remainder];
			else
				*p-- = digits[remainder];
			--fieldSize;
			value = quotient;
		}
	}

	/* Add the padding characters to the string */
	if (fieldSize > 0 && padC != '\0') {
		while (fieldSize--) {
			*p-- = padC;
		}
	}

	if (minus)
		*p = '-';
	else
		++p;
		
	while ((*str++ = *p++) != 0)
	{
	}
	
	--str;		/* return pointing at null */
	
	return str;
}


/********************************************************************************/
/* 							StrToInt								*/
/*																*/
/* Description. 													*/
/*	Return a long integer containing the value represented by a given 		*/
/*	character string.												*/
/*																*/
/* Input Parameters.												*/
/*	string	:  string containing the integer representation.				*/
/*	ptr		:  pointer to character terminating the conversion scan.		*/
/*	base		:  numeric base of the integer.							*/ 
/*																*/
/* Notes.															*/
/*	Implements the strtol function of the standard C library, with the		*/
/*	following restrictions:											*/
/*			- only handles decimal and hexadecimal representations			*/
/*			- will not determine the base from the format of the string		*/
/*																*/
/********************************************************************************/

long StrToInt (char *string, char **ptr, int base)
{
	char		c;			/* next character in buffer */
	char		*p;			/* pointer to character string */
	Boolean	negate;		/* TRUE if the decimal number should be negated */
	long		decValue;		/* decimal value represented by the string */

	negate = false;
	decValue = 0;
	p = string;

	/* Init the ptr argument */
	if (ptr != NULL)
		*ptr = string;

	/* Check the base argument */
	if (base != 10 && base != 16)
		return 0;

	/* Consume leading whitespace */
	while (*p == ' ' || *p == '\t' || *p == '\n')
		++p;

	/* Look for unary minus operator */
	if ((c = *p++) == '-') {
		negate = true;	/* flag programming */
		c = *p++;
	}

	/* Convert the string */
	while (1) {
		if (c >= '0' && c <= '9') {
			if (base == 16)
				decValue = decValue << 4;
			else {	// base == 10
				decValue = (decValue << 3) + (decValue << 1);
			}
			decValue += (unsigned int) c - (unsigned int) '0';
		}
		else if (base == 16 && c >= 'a' && c <= 'f') {
			decValue = decValue << 4;
			decValue += 10 + ((unsigned int) c - (unsigned int) 'a');
		}
		else if (base == 16 && c >= 'A' && c <= 'F') {
			decValue = decValue << 4;
			decValue += 10 + ((unsigned int) c - (unsigned int) 'A');
		}
		else
			break;
		c = *p++;
	}

	/* Apply unary minus operator */
	if (negate)
		decValue = -decValue;

	/* Return the adjusted pointer into the buffer */
	if (ptr != NULL)
		*ptr = --p;

	return decValue;
}


/********************************************************************************/
/* 							ExpandFormat							*/
/*																*/
/* Description. 													*/
/*	Expand a printf format string, substituting arguments, to yield the final	*/
/*	string that will be written to the output device.						*/
/*																*/
/* Input Parameters.												*/
/*	string	:  buffer for the final string.							*/
/*	format	:  printf format string.									*/
/*	args		:  pointer to the argument list.							*/ 
/*																*/
/* Notes.															*/
/*	Called by printf.												*/
/*	This is a minimal implementation.  It barely handles precision specifiers	*/
/*	and probably other formatting options as well.  Caveat emptor.			*/
/*																*/
/********************************************************************************/

static void ExpandFormat (char *string, char *format, va_list args)
{
	char			*str, *t, *fmt;
	char			c, padC;
	int			i, len, fieldSize, precision;
	Boolean		leftJustify;

	padC = '\0';			/* no padding is the default */
	fieldSize = 0;			/* no field width is the default */
	leftJustify = false;	/* right justify is the default */
	
	/* Parse the format string */
	for (str = string, fmt = format; ((*str = *fmt++) != 0); ++str) {
		if (*str == '%') {
			padC = '\0';
			fieldSize = 0;
			precision = 0;
			leftJustify = false;
Hell:		switch (*fmt) {
			  case '%':
			  	++fmt;
			  	continue;
			  case 'c':	/* character substitution */
			  	c = (char) va_arg( args, int );
			  	if ((fieldSize > 0) && !leftJustify) {
					for (i = 0; i < (fieldSize - 1); ++i)
						*str++ = ' ';
				}
				*str++ = c;
				*str = 0;	/* point to the terminating null */
			  	if ((fieldSize > 0) && leftJustify) {
					for (i = 0; i < (fieldSize - 1); ++i)
						*str++ = ' ';
					*str = 0;
				}
			  	break;
			  case 's':	/* string substitution, 's' for C strings and 'P' for Pascal strings */
			  case 'P':
			  	t = va_arg( args, char* );
				if (*fmt == 'P')
				{
					len = *(unsigned char*)t;
					t++;
				}
				else
					len = strlen(t);
				if ((precision > 0) && (precision < len))
					len = precision;
			  	if ((fieldSize > 0) && !leftJustify)
					for (i = 0; i < (fieldSize - len); ++i)
						*str++ = ' ';
				for (i = len; i > 0; --i)
					*str++ = *t++;
				*str = 0;		/* point to the terminating null */
			  	if ((fieldSize > 0) && leftJustify) {
					for (i = 0; i < (fieldSize - len); ++i)
						*str++ = ' ';
					*str = 0;
				}
			  	break;
			  case '-':	/* left justify */
			  	leftJustify = true;
				++fmt;
				goto Hell;	/* how juvenile is this? very! */
			  case 'l':	/* integer size specifier (int == long!) */
			  case 'L':
				++fmt;
				goto Hell;
			  case 'd':	/* integer substitution (signed decimal) */
			  case 'D':
			     str = IntToStr(va_arg( args, int ), -10, padC, fieldSize, precision, false, str);
				break;
			  case 'u':	/* integer substitution (unsigned decimal) */
			  case 'U':
			     str = IntToStr(va_arg( args, int ), 10, padC, fieldSize, precision, false, str);
				break;
			  case 'o':	/* integer substitution (octal) */
			  case 'O':
			     str = IntToStr(va_arg( args, int), 8, padC, fieldSize, precision, false, str);
				break;
			  case 'x':	/* integer substitution (hex) */
			     str = IntToStr(va_arg( args, int), 16, padC, fieldSize, precision, false, str);
				break;
			  case 'X':	/* integer substitution (hex) */
			     str = IntToStr(va_arg( args, int), 16, padC, fieldSize, precision, true, str);
				break;
			  case '.':	/* precision */
			  	++fmt;
				if (*fmt == '*') {
					++fmt;
					precision = va_arg( args, int);
				} else
					precision = (int) StrToInt(fmt, &fmt, 10);
				goto Hell;
				break;
			  default:
			  	/* Look for flags */
			  	if (*fmt == '0') {
					/* Change the padding character */
					padC = '0';
					fieldSize = 0;	/* just in case */
					++fmt;
				}
				if (*fmt >= '0' && *fmt <= '9') {
					/* Change the pad character if it's not already set */
					if (padC == '\0')
						padC = ' ';
					/* Get the field width */
					fieldSize = (int) StrToInt(fmt, &fmt, 10);
					/* Now process the format specifier */
					goto Hell;
				}
				break;
			}
			++fmt; --str;
		}
	}
}


/********************************************************************************/
/* 							printf								*/
/*																*/
/* Description. 													*/
/*	printf procedure that writes to screen.								*/
/*																*/
/* Input Parameters.												*/
/*	fmt	:  the format string.										*/
/*	...	:  variable number of arguments.								*/
/*																*/
/* Function Result.													*/
/*	int	:  length of str.											*/
/*																*/
/********************************************************************************/

int printf (char const *fmt, ...)
{
	va_list args;
	char str[512];
	CIArgs ciArgs;
	
	va_start( args, fmt );

	/* Expand the format string */
	ExpandFormat(str, (char*)fmt, args);

	ciArgs.service = "interpret";
	ciArgs.nArgs = 2;
	ciArgs.args.interpret_1_0.arg1 = (CICell) str;
	ciArgs.nReturns = 1;
	ciArgs.args.interpret_1_0.forth =
		"200 bounds do "
			"i c@ ?dup 0= if leave then "
			"dup "
			"0A = if "
				"drop cr "
			"else "
				"emit "
			"then "
		"loop";
	CallCI (&ciArgs);

	return strlen( str );
}


/********************************************************************************/
/* 							sprintf								*/
/*																*/
/* Description. 													*/
/*	printf procedure that writes to a string instead of an output device.		*/
/*																*/
/* Input Parameters.												*/
/*	str	:  string buffer where the output is placed.						*/
/*	fmt	:  a printf-style format string (see printf).					*/
/*	...	:  variable number of arguments.								*/
/*																*/
/* Function Result.													*/
/*	int	:  length of str.											*/
/*																*/
/********************************************************************************/

int sprintf (char *str, char const *fmt, ...)
{
	va_list args;
	
	va_start( args, fmt );

	/* Expand the format string */
	ExpandFormat(str, (char*)fmt, args);
	
	return strlen( str );
}

int vsprintf(char *str, char const *fmt, va_list args)
{
	ExpandFormat( str, (char*)fmt, args );
	return strlen( str );
}

#if 0
/********************************************************************************/
/* 							strlen								*/
/*																*/
/* Description. 													*/
/*	Return the length of a string.									*/
/*																*/
/* Input Parameters.												*/
/*	str	:  string to measure.										*/
/*																*/
/********************************************************************************/

size_t strlen (const char *str)
{
	int		length;		/* length of the string */

	for (length = 0; *str++ != '\0'; ++length) ;

	return length;
}


/********************************************************************************/
/* 							strcat								*/
/*																*/
/* Description. 													*/
/*	Concatenate two strings.											*/
/*																*/
/* Input Parameters.												*/
/*	str1	:  first string and destination string.							*/
/*	str2	:  string appended to end of str1.								*/
/*																*/
/********************************************************************************/

char *strcat (char *str1, const char *str2)
{
	char		*saveStr1 = str1;

	/* Find end of str1 */
	while (*str1) ++str1;

	/* Copy str2 to end of str1 */
	while ((*str1++ = *str2++) != 0)
	{
	}

	return saveStr1;
}


/********************************************************************************/
/* 							strncat								*/
/*																*/
/* Description. 													*/
/*	Concatenate two strings, but with a limit on the length of the source.	*/
/*																*/
/* Input Parameters.												*/
/*	str1		:  first string and destination string.						*/
/*	str2		:  string appended to end of str1.							*/
/*	count	:  at most these many characters from str2 will be appended.	*/
/*																*/
/********************************************************************************/

char *strncat (char *str1, const char *str2, size_t count)
{
	char		*s1 = str1, *s2 = (char*)str2;

	/* Find end of str1 */
	while (*s1) ++s1;

	/* Copy str2 to end of str1 */
	while ( (count-- > 0) && ((*s1++ = *s2++) != 0) ) ;
	
	if (count == 0)
		*s1++ = 0;

	return str1;
}


/********************************************************************************/
/* 							strcpy								*/
/*																*/
/* Description. 													*/
/*	Copy a string.													*/
/*																*/
/* Input Parameters.												*/
/*	destStr	:  destination string.									*/
/*	srcStr	:  source string.										*/
/*																*/
/********************************************************************************/

char *strcpy (char *destStr, const char *srcStr)
{
	char		*saveDest = destStr;

	/* Copy source to destination */
	while ((*destStr++ = *srcStr++) != 0) ;

	return saveDest;
}


/********************************************************************************/
/* 							strncpy								*/
/*																*/
/* Description. 													*/
/*	Copy a string of a given length.									*/
/*																*/
/* Input Parameters.												*/
/*	destStr	:  destination string.									*/
/*	srcStr	:  source string.										*/
/*	length	:  length of the resultant string.							*/
/*																*/
/********************************************************************************/

char *strncpy (char *destStr, const char *srcStr, size_t length)
{
	char		c;
	char		*saveDest = destStr;
	int		i;

	*destStr = '\0';

	if (length > 0) {
		/* Copy source to destination */
		i = 0;
		do {
			c = *destStr++ = *srcStr++;
			++i;		/* count characters copied */
		} while (i < length && c != '\0') ;

		/* Pad the destination string to the right if necessary */
		while (i < length) {
			*destStr++ = '\0';
			++i;
		}
	}

	return saveDest;
}


/********************************************************************************/
/* 							strchr								*/
/*																*/
/* Description 													*/
/*	Find the first occurrence of a specified character within a string.		*/
/*																*/
/* Input Parameters													*/
/*	str		:  pointer to string to be searched.						*/
/*	chr		:  character to search for.								*/
/*																*/
/* Output Parameters												*/
/*			:  pointer to the first occurrence of chr in str,				*/
/*				or NULL if chr does not occur.						*/
/*																*/
/********************************************************************************/

char *strchr (const char *str, int chr)
{
	for (; *str && (*str != chr); ++str)
		if ((*str == '\0') && (chr != '\0'))
			return NULL;		/* didn't find it */

	/* found it */
	return (char*)str;
}


/* memcmp is builtin in GNUC */
/********************************************************************************/
/* 							memcmp								*/
/*																*/
/* Description 													*/
/*	Compare two raw memory areas.										*/
/*																*/
/* Input Parameters													*/
/*	str1		:  pointer to first bytestring.							*/
/*	str2		:  pointer to second bytestring.							*/
/*	count	:  size of memory areas to compare.						*/
/*																*/
/* Output Parameters												*/
/*			:  the function return is < 0 if str1 < str2					*/
/*								 > 0 if str1 > str2					*/
/*								   0 if str1 == str2				*/
/*																*/
/********************************************************************************/

int memcmp (const void *s1, const void *s2, size_t n)
{
	unsigned char *p1 = (unsigned char*)s1, *p2 = (unsigned char*)s2;
	int delta;

	while (n-- > 0) if ((delta = *p1++ - *p2++) != 0) return delta;
	return 0;
}


/* memcpy is builtin in GNUC */
#ifndef __GNUC__
/********************************************************************************/
/* 							memcpy								*/
/*																*/
/* Description 													*/
/*	Copy from source to destination.									*/
/*																*/
/* Input Parameters													*/
/*	str1		:  pointer to first bytestring.							*/
/*	str2		:  pointer to second bytestring.							*/
/*	count	:  size of memory areas to copy.							*/
/*																*/
/* Output Parameters												*/
/*			:  The original destination pointer						*/
/*																*/
/********************************************************************************/

void *memcpy (void *s1, const void *s2, size_t n)
{
	int rem;
	char *s = (char *)s1;
	if((n < 32)
#ifdef ALIGN_MASK
			||((int)s1 & ALIGN_MASK) != ((int)s2 & ALIGN_MASK)
#endif
			)
	{
		++n;
		while (--n)  *s++ = *(CHARSTARLVAL(s2))++;
	} else {
		/* bring s2 to the long align; 
		   with some luck 's' will also be long aligned  
		   if not we are loosing in %50 (and only in case of ALIGN_MASK ==1 )
			but we are always saving on checking*/
		while ((int)s2 & 0x3) {
			*s++ = *(CHARSTARLVAL(s2))++;
			--n;
		}
		rem = (n & 3)+1;
		n >>= 2;
		++n;
		while(--n) {
			*(LONGSTARLVAL(s))++ = *(LONGSTARLVAL(s2))++;
		}
		while (--rem) {
			*s++ = *(CHARSTARLVAL(s2))++;
		}
	}
	return (s1);
}
#endif


/********************************************************************************/
/* 							memset								*/
/*																*/
/* Description 													*/
/*	Set a range of bytes to a pattern.									*/
/*																*/
/* Input Parameters													*/
/*	str		:  pointer to destination bytestring.						*/
/*	c		:  character pattern to fill bytestring with.				*/
/*	count	:  size of memory area to fill.							*/
/*																*/
/* Output Parameters												*/
/*			:  The original destination pointer						*/
/*																*/
/********************************************************************************/

void *memset (void *s, int c, size_t n)
{
	void * s1=s;
	if(n < 16){
		while(n--){ 
			*(UCHARSTARLVAL(s))++ = (unsigned char)c;
		}
	}else{
		register int rem; register long c4;
		
		while((int)s & 0x3){ 	--n;
			*(UCHARSTARLVAL(s))++ = (unsigned char)c;
		}
		
#if MULTIPLY_IS_FAST
		c4 = 0x01010101 * (unsigned long) (unsigned char) c;
#else
		c4 = (unsigned char)c;
		c4 = (c4 << 8) + c4;
		c4 = (c4 << 16) + c4;
#endif
		rem = (n & 3) +1;
		
		for(n >>= 2, n++; --n;){ 
			*(LONGSTARLVAL(s))++ = c4;
		}
		while(--rem){
			*(UCHARSTARLVAL(s))++ = (unsigned char)c;
		}
	}
	return(s1);
}


/********************************************************************************/
/* 							strcmp								*/
/*																*/
/* Description 													*/
/*	Compare two strings.											*/
/*																*/
/* Input Parameters													*/
/*	str1		:  pointer to first string.								*/
/*	str2		:  pointer to second string.								*/
/*																*/
/* Output Parameters												*/
/*			:  the function return is < 0 if str1 < str2					*/
/*								 > 0 if str1 > str2					*/
/*								   0 if str1 == str2				*/
/*																*/
/********************************************************************************/

int strcmp (const char *str1, const char *str2)
{
	for (; *str1 == *str2; ++str1, ++str2)
		if (*str1 == '\0')
			return 0;		/* strings are equal */

	/* Exited loop because characters do not match */
	return *str1 - *str2;
}


static int tolower (const char c)
{
	return c >= 'A' || c <= 'Z' ? (int) c + 'a' - 'A' : c;
}


int strcmpCaseInsensitive (const char *s1, const char *s2)
{
	for (; tolower (*s1) == tolower (*s2); ++s1, ++s2)
		if (*s1 == '\0')
			return 0;		/* strings are equal */

	/* Exited loop because characters do not match */
	return tolower (*s1) - tolower (*s2);
}


/********************************************************************************/
/* 							strncmp								*/
/*																*/
/* Description 													*/
/*	Compare two strings up to a specified length.						*/
/*																*/
/* Input Parameters													*/
/*	str1		:  pointer to first string.								*/
/*	str2		:  pointer to second string.								*/
/*	length	:  number of character to compare.							*/
/*																*/
/* Output Parameters												*/
/*			:  the function return is < 0 if str1 < str2					*/
/*								 > 0 if str1 > str2					*/
/*								   0 if str1 == str2				*/
/*																*/
/********************************************************************************/

int strncmp (const char *str1, const char *str2, size_t length)
{
	int i;
	
	if (length == 0)
		return 0;

	for (i = 1; *str1 == *str2; ++str1, ++str2, ++i)
		if (*str1 == '\0' || i == length)
			return 0;		/* strings are equal */

	/* Exited loop because characters do not match */
	return *str1 - *str2;
}


void exit (int code)
{
	printf ("exit (%d)\n", code);
	CIexit ();
}

#endif
