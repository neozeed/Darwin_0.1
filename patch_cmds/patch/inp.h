/* inputting files to be patched */

/* $Id: inp.h,v 1.1.1.1 1997/08/20 20:57:57 wsanchez Exp $ */

XTERN LINENUM input_lines;		/* how long is input file in lines */

char const *ifetch PARAMS ((LINENUM, int, size_t *));
void get_input_file PARAMS ((char const *, char const *));
void re_input PARAMS ((void));
void scan_input PARAMS ((char *));
