/* Heap management routines (including unexec) for GNU Emacs on Windows NT.
   Copyright (C) 1994 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.

   Geoff Voelker (voelker@cs.washington.edu)			     7-29-94
*/

#ifndef NTHEAP_H_
#define NTHEAP_H_

#include <windows.h>

/*
 * Heap related stuff.
 */
#define get_reserved_heap_size()	reserved_heap_size
#define get_committed_heap_size()	(get_data_end () - get_data_start ())
#define get_heap_start()		get_data_start ()
#define get_heap_end()			get_data_end ()
#define get_page_size()			sysinfo_cache.dwPageSize
#define get_allocation_unit()		sysinfo_cache.dwAllocationGranularity
#define get_processor_type()		sysinfo_cache.dwProcessorType
#define get_w32_major_version()  	w32_major_version
#define get_w32_minor_version()  	w32_minor_version

extern unsigned char *get_data_start();
extern unsigned char *get_data_end();
extern unsigned long  data_region_size;
extern unsigned long  reserved_heap_size;
extern SYSTEM_INFO    sysinfo_cache;
extern BOOL   	      need_to_recreate_heap;
extern int    	      w32_major_version;
extern int    	      w32_minor_version;

enum {
  OS_WIN95 = 1,
  OS_NT
};

extern int os_subtype;

/* Emulation of Unix sbrk().  */
extern void *sbrk (unsigned long size);

/* Recreate the heap created during dumping.  */
extern void recreate_heap (char *executable_path);

/* Round the heap to this size.  */
extern void round_heap (unsigned long size);

/* Load in the dumped .bss section.  */
extern void read_in_bss (char *name);

/* Map in the dumped heap.  */
extern void map_in_heap (char *name);

/* Cache system info, e.g., the NT page size.  */
extern void cache_system_info (void);

/* Round ADDRESS up to be aligned with ALIGN.  */
extern unsigned char *round_to_next (unsigned char *address, 
				     unsigned long align);

/* ----------------------------------------------------------------- */
/* Useful routines for manipulating memory-mapped files. */

typedef struct file_data {
    char          *name;
    unsigned long  size;
    HANDLE         file;
    HANDLE         file_mapping;
    unsigned char *file_base;
} file_data;

#define OFFSET_TO_RVA(var,section) \
	  (section->VirtualAddress + ((DWORD)(var) - section->PointerToRawData))

#define RVA_TO_OFFSET(var,section) \
	  (section->PointerToRawData + ((DWORD)(var) - section->VirtualAddress))

#define RVA_TO_PTR(var,section,filedata) \
	  ((void *)(RVA_TO_OFFSET(var,section) + (filedata).file_base))

int open_input_file (file_data *p_file, char *name);
int open_output_file (file_data *p_file, char *name, unsigned long size);
void close_file_data (file_data *p_file);

unsigned long get_section_size (PIMAGE_SECTION_HEADER p_section);

/* Return pointer to section header for named section. */
IMAGE_SECTION_HEADER * find_section (char * name, IMAGE_NT_HEADERS * nt_header);

/* Return pointer to section header for section containing the given
   relative virtual address. */
IMAGE_SECTION_HEADER * rva_to_section (DWORD rva, IMAGE_NT_HEADERS * nt_header);

#endif /* NTHEAP_H_ */
