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
#include "libsaio.h"
#include "localize.h"

char *Language = "English";
char *LanguageConfig;

int
loadLanguageFiles(void)
{
	char buf[128];
	int count, fd;
	
	sprintf(buf,
		"/usr/standalone/i386/%s.lproj/Localizable.strings",
		Language);
	if ((fd = open(buf,0)) >= 0) {
		LanguageConfig = malloc(file_size(fd));
		count = read(fd, LanguageConfig, file_size(fd));
		if (count <= 0) {
			free(LanguageConfig);
			LanguageConfig = 0;
		}
		close(fd);
	}
	return 0;
}

char *getLanguage(void)
{
	return Language;
}

char *setLanguage(char *new)
{
	return (Language = new);
}
