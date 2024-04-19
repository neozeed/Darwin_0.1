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

extern int csum_length;

extern int verbose;
extern int am_server;

extern int remote_version;

typedef unsigned short tag;

#define TABLESIZE (1<<16)
#define NULL_TAG (-1)

static int false_alarms;
static int tag_hits;
static int matches;
static int64 data_transfer;

static int total_false_alarms;
static int total_tag_hits;
static int total_matches;

extern struct stats stats;

struct target {
  tag t;
  int i;
};

static struct target *targets;

static int *tag_table;

#define gettag2(s1,s2) (((s1) + (s2)) & 0xFFFF)
#define gettag(sum) gettag2((sum)&0xFFFF,(sum)>>16)

static int compare_targets(struct target *t1,struct target *t2)
{
  return((int)t1->t - (int)t2->t);
}


static void build_hash_table(struct sum_struct *s)
{
  int i;

  if (!tag_table)
    tag_table = (int *)malloc(sizeof(tag_table[0])*TABLESIZE);

  targets = (struct target *)malloc(sizeof(targets[0])*s->count);
  if (!tag_table || !targets) 
    out_of_memory("build_hash_table");

  for (i=0;i<s->count;i++) {
    targets[i].i = i;
    targets[i].t = gettag(s->sums[i].sum1);
  }

  qsort(targets,s->count,sizeof(targets[0]),(int (*)())compare_targets);

  for (i=0;i<TABLESIZE;i++)
    tag_table[i] = NULL_TAG;

  for (i=s->count-1;i>=0;i--) {    
    tag_table[targets[i].t] = i;
  }
}


static OFF_T last_match;


static void matched(int f,struct sum_struct *s,struct map_struct *buf,
		    OFF_T offset,int i)
{
	OFF_T n = offset - last_match;
	int j;

	if (verbose > 2 && i >= 0)
		rprintf(FINFO,"match at %d last_match=%d j=%d len=%d n=%d\n",
			(int)offset,(int)last_match,i,(int)s->sums[i].len,(int)n);

	send_token(f,i,buf,last_match,n,i<0?0:s->sums[i].len);
	data_transfer += n;

	if (i >= 0) {
		stats.matched_data += s->sums[i].len;
		n += s->sums[i].len;
	}
  
	for (j=0;j<n;j+=CHUNK_SIZE) {
		int n1 = MIN(CHUNK_SIZE,n-j);
		sum_update(map_ptr(buf,last_match+j,n1),n1);
	}


	if (i >= 0)
		last_match = offset + s->sums[i].len;
	else
		last_match = offset;

	if (buf)
		show_progress(last_match, buf->size);

	if (i == -1) end_progress();
}


static void hash_search(int f,struct sum_struct *s,
			struct map_struct *buf,OFF_T len)
{
	OFF_T offset;
	int j,k;
	int end;
	char sum2[SUM_LENGTH];
	uint32 s1, s2, sum; 
	schar *map;

	if (verbose > 2)
		rprintf(FINFO,"hash search b=%d len=%d\n",s->n,(int)len);

	k = MIN(len, s->n);
	
	map = (schar *)map_ptr(buf,0,k);
	
	sum = get_checksum1((char *)map, k);
	s1 = sum & 0xFFFF;
	s2 = sum >> 16;
	if (verbose > 3)
		rprintf(FINFO, "sum=%.8x k=%d\n", sum, k);
	
	offset = 0;
	
	end = len + 1 - s->sums[s->count-1].len;
	
	if (verbose > 3)
		rprintf(FINFO,"hash search s->n=%d len=%d count=%d\n",
			s->n,(int)len,s->count);
	
	do {
		tag t = gettag2(s1,s2);
		int done_csum2 = 0;
			
		j = tag_table[t];
		if (verbose > 4)
			rprintf(FINFO,"offset=%d sum=%08x\n",(int)offset,sum);
		
		if (j == NULL_TAG) {
			goto null_tag;
		}

		sum = (s1 & 0xffff) | (s2 << 16);
		tag_hits++;
		for (; j<s->count && targets[j].t == t; j++) {
			int i = targets[j].i;
			
			if (sum != s->sums[i].sum1) continue;
			
			if (verbose > 3)
				rprintf(FINFO,"potential match at %d target=%d %d sum=%08x\n",
					(int)offset,j,i,sum);
			
			if (!done_csum2) {
				int l = MIN(s->n,len-offset);
				map = (schar *)map_ptr(buf,offset,l);
				get_checksum2((char *)map,l,sum2);
				done_csum2 = 1;
			}
			
			if (memcmp(sum2,s->sums[i].sum2,csum_length) != 0) {
				false_alarms++;
				continue;
			}
			
			matched(f,s,buf,offset,i);
			offset += s->sums[i].len - 1;
			k = MIN((len-offset), s->n);
			map = (schar *)map_ptr(buf,offset,k);
			sum = get_checksum1((char *)map, k);
			s1 = sum & 0xFFFF;
			s2 = sum >> 16;
			matches++;
			break;
		}
		
	null_tag:
		/* Trim off the first byte from the checksum */
		map = (schar *)map_ptr(buf,offset,k+1);
		s1 -= map[0] + CHAR_OFFSET;
		s2 -= k * (map[0]+CHAR_OFFSET);
		
		/* Add on the next byte (if there is one) to the checksum */
		if (k < (len-offset)) {
			s1 += (map[k]+CHAR_OFFSET);
			s2 += s1;
		} else {
			--k;
		}

		/* By matching early we avoid re-reading the
		   data 3 times in the case where a token
		   match comes a long way after last
		   match. The 3 reads are caused by the
		   running match, the checksum update and the
		   literal send. */
		if (offset-last_match >= CHUNK_SIZE+s->n && 
		    (end-offset > CHUNK_SIZE)) {
			matched(f,s,buf,offset - s->n, -2);
		}
	} while (++offset < end);
	
	matched(f,s,buf,len,-1);
	map_ptr(buf,len-1,1);
}


void match_sums(int f,struct sum_struct *s,struct map_struct *buf,OFF_T len)
{
	char file_sum[MD4_SUM_LENGTH];

	last_match = 0;
	false_alarms = 0;
	tag_hits = 0;
	matches=0;
	data_transfer=0;

	sum_init();

	if (len > 0 && s->count>0) {
		build_hash_table(s);
		
		if (verbose > 2) 
			rprintf(FINFO,"built hash table\n");
		
		hash_search(f,s,buf,len);
		
		if (verbose > 2) 
			rprintf(FINFO,"done hash search\n");
	} else {
		OFF_T j;
		/* by doing this in pieces we avoid too many seeks */
		for (j=0;j<(len-CHUNK_SIZE);j+=CHUNK_SIZE) {
			int n1 = MIN(CHUNK_SIZE,(len-CHUNK_SIZE)-j);
			matched(f,s,buf,j+n1,-2);
		}
		matched(f,s,buf,len,-1);
	}

	sum_end(file_sum);

	if (remote_version >= 14) {
		if (verbose > 2)
			rprintf(FINFO,"sending file_sum\n");
		write_buf(f,file_sum,MD4_SUM_LENGTH);
	}

	if (targets) {
		free(targets);
		targets=NULL;
	}
	
	if (verbose > 2)
		rprintf(FINFO, "false_alarms=%d tag_hits=%d matches=%d\n",
			false_alarms, tag_hits, matches);
	
	total_tag_hits += tag_hits;
	total_false_alarms += false_alarms;
	total_matches += matches;
	stats.literal_data += data_transfer;
}

void match_report(void)
{
	if (verbose <= 1)
		return;

	rprintf(FINFO,
		"total: matches=%d  tag_hits=%d  false_alarms=%d data=%.0f\n",
		total_matches,total_tag_hits,
		total_false_alarms,
		(double)stats.literal_data);
}
