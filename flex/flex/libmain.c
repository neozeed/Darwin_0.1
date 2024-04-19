/* libmain - flex run-time support library "main" function */

/* $Header: /CVSRoot/CoreOS/Commands/GNU/flex/flex/libmain.c,v 1.1.1.1 1997/08/14 18:29:22 wsanchez Exp $ */

extern int yylex();

int main( argc, argv )
int argc;
char *argv[];
	{
	while ( yylex() != 0 )
		;

	return 0;
	}
