/* 
   Copyright (C) Andrew Tridgell 1996
   Copyright (C) Paul Mackerras 1996
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "rsync.h"

/* handling the cleanup when a transfer is interrupted is tricky when
   --partial is selected. We need to ensure that the partial file is
   kept if any real data has been transferred */
int cleanup_got_literal=0;

static char *cleanup_fname;
static char *cleanup_new_fname;
static struct file_struct *cleanup_file;
static int cleanup_fd1, cleanup_fd2;
static struct map_struct *cleanup_buf;

void exit_cleanup(int code)
{
	extern int keep_partial;

	signal(SIGUSR1, SIG_IGN);

	if (cleanup_got_literal && cleanup_fname && keep_partial) {
		char *fname = cleanup_fname;
		cleanup_fname = NULL;
		if (cleanup_buf) unmap_file(cleanup_buf);
		if (cleanup_fd1 != -1) close(cleanup_fd1);
		if (cleanup_fd2 != -1) close(cleanup_fd2);
		finish_transfer(cleanup_new_fname, fname, cleanup_file);
	}
	io_flush();
	if (cleanup_fname)
		do_unlink(cleanup_fname);
	if (code) {
		kill_all(SIGUSR1);
	}
	exit(code);
}

void cleanup_disable(void)
{
	cleanup_fname = NULL;
	cleanup_got_literal = 0;
}


void cleanup_set(char *fnametmp, char *fname, struct file_struct *file,
		 struct map_struct *buf, int fd1, int fd2)
{
	cleanup_fname = fnametmp;
	cleanup_new_fname = fname;
	cleanup_file = file;
	cleanup_buf = buf;
	cleanup_fd1 = fd1;
	cleanup_fd2 = fd2;
}
