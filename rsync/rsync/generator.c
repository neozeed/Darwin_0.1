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

extern int verbose;
extern int dry_run;
extern int relative_paths;
extern int preserve_links;
extern int am_root;
extern int preserve_devices;
extern int preserve_hard_links;
extern int update_only;
extern int whole_file;
extern int block_size;
extern int csum_length;
extern int ignore_times;
extern int io_timeout;
extern int remote_version;
extern int always_checksum;


/* choose whether to skip a particular file */
static int skip_file(char *fname,
		     struct file_struct *file, STRUCT_STAT *st)
{
	if (st->st_size != file->length) {
		return 0;
	}
	
	/* if always checksum is set then we use the checksum instead 
	   of the file time to determine whether to sync */
	if (always_checksum && S_ISREG(st->st_mode)) {
		char sum[MD4_SUM_LENGTH];
		file_checksum(fname,sum,st->st_size);
		return (memcmp(sum,file->sum,csum_length) == 0);
	}

	if (ignore_times) {
		return 0;
	}

	return (st->st_mtime == file->modtime);
}


/* use a larger block size for really big files */
static int adapt_block_size(struct file_struct *file, int bsize)
{
	int ret;

	if (bsize != BLOCK_SIZE) return bsize;

	ret = file->length / (10000); /* rough heuristic */
	ret = ret & ~15; /* multiple of 16 */
	if (ret < bsize) ret = bsize;
	if (ret > CHUNK_SIZE/2) ret = CHUNK_SIZE/2;
	return ret;
}


/*
  send a sums struct down a fd
  */
static void send_sums(struct sum_struct *s,int f_out)
{
	int i;

  /* tell the other guy how many we are going to be doing and how many
     bytes there are in the last chunk */
	write_int(f_out,s?s->count:0);
	write_int(f_out,s?s->n:block_size);
	write_int(f_out,s?s->remainder:0);
	if (s)
		for (i=0;i<s->count;i++) {
			write_int(f_out,s->sums[i].sum1);
			write_buf(f_out,s->sums[i].sum2,csum_length);
		}
}


/*
  generate a stream of signatures/checksums that describe a buffer

  generate approximately one checksum every n bytes
  */
static struct sum_struct *generate_sums(struct map_struct *buf,OFF_T len,int n)
{
	int i;
	struct sum_struct *s;
	int count;
	int block_len = n;
	int remainder = (len%block_len);
	OFF_T offset = 0;

	count = (len+(block_len-1))/block_len;

	s = (struct sum_struct *)malloc(sizeof(*s));
	if (!s) out_of_memory("generate_sums");

	s->count = count;
	s->remainder = remainder;
	s->n = n;
	s->flength = len;

	if (count==0) {
		s->sums = NULL;
		return s;
	}

	if (verbose > 3)
		rprintf(FINFO,"count=%d rem=%d n=%d flength=%d\n",
			s->count,s->remainder,s->n,(int)s->flength);

	s->sums = (struct sum_buf *)malloc(sizeof(s->sums[0])*s->count);
	if (!s->sums) out_of_memory("generate_sums");
  
	for (i=0;i<count;i++) {
		int n1 = MIN(len,n);
		char *map = map_ptr(buf,offset,n1);

		s->sums[i].sum1 = get_checksum1(map,n1);
		get_checksum2(map,n1,s->sums[i].sum2);

		s->sums[i].offset = offset;
		s->sums[i].len = n1;
		s->sums[i].i = i;

		if (verbose > 3)
			rprintf(FINFO,"chunk[%d] offset=%d len=%d sum1=%08x\n",
				i,(int)s->sums[i].offset,s->sums[i].len,s->sums[i].sum1);

		len -= n1;
		offset += n1;
	}

	return s;
}


void recv_generator(char *fname,struct file_list *flist,int i,int f_out)
{  
	int fd;
	STRUCT_STAT st;
	struct map_struct *buf;
	struct sum_struct *s;
	int statret;
	struct file_struct *file = flist->files[i];

	if (verbose > 2)
		rprintf(FINFO,"recv_generator(%s,%d)\n",fname,i);

	statret = link_stat(fname,&st);

	if (S_ISDIR(file->mode)) {
		if (dry_run) return;
		if (statret == 0 && !S_ISDIR(st.st_mode)) {
			if (do_unlink(fname) != 0) {
				rprintf(FERROR,"unlink %s : %s\n",fname,strerror(errno));
				return;
			}
			statret = -1;
		}
		if (statret != 0 && do_mkdir(fname,file->mode) != 0 && errno != EEXIST) {
			if (!(relative_paths && errno==ENOENT && 
			      create_directory_path(fname)==0 && 
			      do_mkdir(fname,file->mode)==0)) {
				rprintf(FERROR,"mkdir %s : %s (2)\n",
					fname,strerror(errno));
			}
		}
		if (set_perms(fname,file,NULL,0) && verbose) 
			rprintf(FINFO,"%s/\n",fname);
		return;
	}

	if (preserve_links && S_ISLNK(file->mode)) {
#if SUPPORT_LINKS
		char lnk[MAXPATHLEN];
		int l;
		extern int safe_symlinks;

		if (safe_symlinks && unsafe_symlink(file->link, fname)) {
			if (verbose) {
				rprintf(FINFO,"ignoring unsafe symlink %s -> %s\n",
					fname,file->link);
			}
			return;
		}
		if (statret == 0) {
			l = readlink(fname,lnk,MAXPATHLEN-1);
			if (l > 0) {
				lnk[l] = 0;
				if (strcmp(lnk,file->link) == 0) {
					set_perms(fname,file,&st,1);
					return;
				}
			}
		}
		delete_file(fname);
		if (do_symlink(file->link,fname) != 0) {
			rprintf(FERROR,"link %s -> %s : %s\n",
				fname,file->link,strerror(errno));
		} else {
			set_perms(fname,file,NULL,0);
			if (verbose) {
				rprintf(FINFO,"%s -> %s\n",
					fname,file->link);
			}
		}
#endif
		return;
	}

#ifdef HAVE_MKNOD
	if (am_root && preserve_devices && IS_DEVICE(file->mode)) {
		if (statret != 0 || 
		    st.st_mode != file->mode ||
		    st.st_rdev != file->rdev) {	
			delete_file(fname);
			if (verbose > 2)
				rprintf(FINFO,"mknod(%s,0%o,0x%x)\n",
					fname,(int)file->mode,(int)file->rdev);
			if (do_mknod(fname,file->mode,file->rdev) != 0) {
				rprintf(FERROR,"mknod %s : %s\n",fname,strerror(errno));
			} else {
				set_perms(fname,file,NULL,0);
				if (verbose)
					rprintf(FINFO,"%s\n",fname);
			}
		} else {
			set_perms(fname,file,&st,1);
		}
		return;
	}
#endif

	if (preserve_hard_links && check_hard_link(file)) {
		if (verbose > 1)
			rprintf(FINFO,"%s is a hard link\n",f_name(file));
		return;
	}

	if (!S_ISREG(file->mode)) {
		rprintf(FINFO,"skipping non-regular file %s\n",fname);
		return;
	}

	if (statret == -1) {
		if (errno == ENOENT) {
			write_int(f_out,i);
			if (!dry_run) send_sums(NULL,f_out);
		} else {
			if (verbose > 1)
				rprintf(FERROR,"recv_generator failed to open %s\n",fname);
		}
		return;
	}

	if (!S_ISREG(st.st_mode)) {
		if (delete_file(fname) != 0) {
			return;
		}

		/* now pretend the file didn't exist */
		write_int(f_out,i);
		if (!dry_run) send_sums(NULL,f_out);    
		return;
	}

	if (update_only && st.st_mtime > file->modtime) {
		if (verbose > 1)
			rprintf(FINFO,"%s is newer\n",fname);
		return;
	}

	if (skip_file(fname, file, &st)) {
		set_perms(fname,file,&st,1);
		return;
	}

	if (dry_run) {
		write_int(f_out,i);
		return;
	}

	if (whole_file) {
		write_int(f_out,i);
		send_sums(NULL,f_out);    
		return;
	}

	/* open the file */  
	fd = open(fname,O_RDONLY);

	if (fd == -1) {
		rprintf(FERROR,"failed to open %s : %s\n",fname,strerror(errno));
		rprintf(FERROR,"skipping %s\n",fname);
		return;
	}

	if (st.st_size > 0) {
		buf = map_file(fd,st.st_size);
	} else {
		buf = NULL;
	}

	if (verbose > 3)
		rprintf(FINFO,"gen mapped %s of size %d\n",fname,(int)st.st_size);

	s = generate_sums(buf,st.st_size,adapt_block_size(file, block_size));

	if (verbose > 2)
		rprintf(FINFO,"sending sums for %d\n",i);

	write_int(f_out,i);
	send_sums(s,f_out);

	close(fd);
	if (buf) unmap_file(buf);

	free_sums(s);
}



void generate_files(int f,struct file_list *flist,char *local_name,int f_recv)
{
	int i;
	int phase=0;

	if (verbose > 2)
		rprintf(FINFO,"generator starting pid=%d count=%d\n",
			(int)getpid(),flist->count);

	for (i = 0; i < flist->count; i++) {
		struct file_struct *file = flist->files[i];
		mode_t saved_mode = file->mode;
		if (!file->basename) continue;

		/* we need to ensure that any directories we create have writeable
		   permissions initially so that we can create the files within
		   them. This is then fixed after the files are transferred */
		if (!am_root && S_ISDIR(file->mode)) {
			file->mode |= S_IWUSR; /* user write */
		}

		recv_generator(local_name?local_name:f_name(file),
			       flist,i,f);

		file->mode = saved_mode;
	}

	phase++;
	csum_length = SUM_LENGTH;
	ignore_times=1;

	if (verbose > 2)
		rprintf(FINFO,"generate_files phase=%d\n",phase);

	write_int(f,-1);

	/* we expect to just sit around now, so don't exit on a
	   timeout. If we really get a timeout then the other process should
	   exit */
	io_timeout = 0;

	if (remote_version >= 13) {
		/* in newer versions of the protocol the files can cycle through
		   the system more than once to catch initial checksum errors */
		for (i=read_int(f_recv); i != -1; i=read_int(f_recv)) {
			struct file_struct *file = flist->files[i];
			recv_generator(local_name?local_name:f_name(file),
				       flist,i,f);    
		}

		phase++;
		if (verbose > 2)
			rprintf(FINFO,"generate_files phase=%d\n",phase);

		write_int(f,-1);
	}
}
