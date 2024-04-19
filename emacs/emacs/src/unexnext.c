/* Dump Emacs in macho format.
   Copyright (C) 1990, 1993 Free Software Foundation, Inc.
   Written by Bradley Taylor (btaylor@next.com).

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
Boston, MA 02111-1307, USA.  */

#include "config.h"
#include <stdio.h>
#include <libc.h>
#include <nlist.h>
#include <mach/mach.h>
#ifdef RHAPSODY
#include <mach/vm_param.h>
#endif
#include <mach-o/ldsyms.h>
#include <mach-o/loader.h>
#include <mach-o/reloc.h>

extern int malloc_freezedry (void);

int malloc_cookie;

#define VERBOSE

#ifdef VERBOSE
#define SHOW_MCOPY_WRITES
#endif

typedef struct region_t
{
    struct region_t *next;
    vm_address_t address;
    vm_size_t size;
    vm_prot_t protection;
    vm_prot_t max_protection;

    // And some info about where it was written to disk.
    unsigned long file_offset;
    unsigned long file_size;
} region_t;

typedef struct section_list_t
{
    struct section_list_t *next;
    struct section section;
} section_list_t;

static void fatal_unexec (char *format, ...)
{
    va_list ap;
   
    va_start (ap, format);
    fprintf (stderr, "unexec: ");
    vfprintf (stderr, format, ap);
    fprintf (stderr, "\n");
    va_end (ap);
    exit (1);
}

static void print_region (struct region_t *region)
{
    printf ("0x%8lx - 0x%8lx, length: 0x%8lx, protection: %c%c%c, max_protection: %c%c%c\n",
            region->address, region->address + region->size, region->size,
            (region->protection & VM_PROT_READ) ? 'r' : '-',
            (region->protection & VM_PROT_WRITE) ? 'w' : '-',
            (region->protection & VM_PROT_EXECUTE) ? 'x' : '-',
            (region->max_protection & VM_PROT_READ) ? 'r' : '-',
            (region->max_protection & VM_PROT_WRITE) ? 'w' : '-',
            (region->max_protection & VM_PROT_EXECUTE) ? 'x' : '-');
}

static void print_regions (struct region_t *regions)
{
    while (regions != NULL)
    {
        print_region (regions);
        regions = regions->next;
    }
}

static void print_section (struct section *section)
{
    printf ("0x%8lx - 0x%8lx, length: 0x%8lx, offset: 0x%8lx\n",
            section->addr, section->addr + section->size, section->size, section->offset);
}

static void print_sections (section_list_t *sections)
{
    while (sections != NULL)
    {
        print_section (&(sections->section));
        sections = sections->next;
    }
}

/*
 * Copy len bytes from ffd@fpos to tfd@tpos.
 * If both file descriptors are -1, copy in memory (handles overlapping copies).
 * If either ffd or tfd are -1, either read or write len bytes.
 */

static void mcopy (int ffd, int tfd,
                   unsigned long fpos, unsigned long tpos, unsigned long len)
{
    if ((ffd == -1) && (tfd == -1))
    {
        char *f, *t, *e;
        if (fpos > tpos)
        {
            f = (char *)fpos;
            t = (char *)tpos;
            e = (char *)(fpos + len);
            while (f < e) *t++ = *f++;
        }
        else if (tpos > fpos)
        {
            f = (char *)(fpos + len);
            t = (char *)(tpos + len);
            e = (char *)fpos;
            while (f > e) *--t = *--f;         
        }   
    }
    else if (ffd == -1)
    {
        if (lseek (tfd, tpos, L_SET) < 0)
            fatal_unexec ("cannot seek target");
        if (write (tfd, (void *)fpos, len) != len)
            fatal_unexec ("cannot write target");
#ifdef SHOW_MCOPY_WRITES
        printf ("write: %10lu - %10lu, length: %10lu\n", tpos, tpos+len, len);
#endif
    }
    else if (tfd == -1)
    {
        if (lseek (ffd, fpos, L_SET) < 0)
            fatal_unexec ("cannot seek source");
        if (read (ffd, (void *)tpos, len) != len)
            fatal_unexec ("cannot read source");
    }
    else
    {
        int bread;
        char *buf = alloca (1 << 16);
      
#ifdef SHOW_MCOPY_WRITES
        printf ("write: %10lu - %10lu, length: %10lu\n", tpos, tpos+len, len);
#endif

        if (lseek (ffd, fpos, L_SET) < 0)
            fatal_unexec ("cannot seek source");
      
        if (lseek (tfd, tpos, L_SET) < 0)
            fatal_unexec ("cannot seek target");
      
        while((len > 0) && (bread = read (ffd, buf, MIN(1 << 16, len))) > 0)
        {
            if (bread < 0)
                fatal_unexec ("cannot read source");
            if (write (tfd, buf, bread) != bread)
                fatal_unexec ("cannot write target");
            len -= bread;
        }
    }
}

/*
 * The process of dumping (or unexecing) is the opposite of exec().
 * It takes the original executable and parts of memory that have been
 * loaded with data, and creates a new executable.  This allows
 * standard lisp files to be loaded "instantly", because they are part
 * of the executable.
 *
 * This involves using vm_region() to build a list of allocated memory
 * regions, combining adjacent "similar" regions to reduce their
 * number, skipping read-only regions and parts of regions covered by
 * non-data segment load commands, and finally replacing the (usually
 * one) data segment with a new segment for each region.
 *
 * File offsets in load commands that follow the data segment must be
 * adjusted by the change in size of the data segment.  The size of
 * the load commands can increase without affecting file offsets --
 * see the note below.
 *
 * Data associated with the LC_SYMTAB and LC_DYSYMTAB is found in the
 * __LINKEDIT segment -- there is no extra data to be written for
 * these load commands.
 *
 * Relocatable symbols from the data segment, which we took from
 * memory, need to be unrelocated.  The relocatable address is found
 * in the new mach-o file and then zeroed out.  Failure to do this
 * typically results in a segmentation fault, with the offending
 * address being double what it is at the same point in temacs, since
 * it has been relocated twice.
 *
 * Be sure to study the loader.h file if you want to understand this.
 * otool -lv shows the load commands of the file, and is very useful
 * when debugging this code.
 *
 * Note: This is not obvious, but the __TEXT section usually has a
 *       file offset of 0, and so when it is written it will overwrite
 *       any mach headers or load commands that have already been
 *       written...  How much room is there before critial parts are
 *       overwritten when we add load commands?
 *
 *    -- Steve Nygard
 */

static void unexec_doit(int infd,int outfd)
{
    int i, j, l, header_position, output_position;
    region_t *regions = NULL, *cregion, **pregions;
    struct mach_header mach_header;
    struct load_command *load_command, *original_load_commands;
    struct segment_command *segment_pointer;
    struct symtab_command *symtab_pointer;
    struct section *section_pointer;

    unsigned long delta = 0;
#ifdef NS_TARGET
    struct dysymtab_command *dysymtab;
    unsigned long extreloff = 0;
    unsigned long nextrel = 0;
    unsigned long locreloff = 0;
    unsigned long nlocrel = 0;
    struct relocation_info reloc_info;
    unsigned long fixed_reloc_count = 0;

#endif

    struct segment_command new_data_segment;
    section_list_t *original_sections, *new_sections, **sect_ptr, *section_item;
    int found_la_symbol_ptr = 0, found_nl_symbol_ptr = 0, found_dyld = 0;

    malloc_cookie = malloc_freezedry();
#ifdef VERBOSE
    printf ("malloc_cookie: %lx\n", malloc_cookie);
#endif
   
    {
        vm_task_t task = task_self();
        vm_address_t address;
        vm_size_t size;
        vm_prot_t protection, max_protection;
        vm_inherit_t inheritance;
        boolean_t shared;
        port_t name;
        vm_offset_t offset;
      
        for (address = VM_MIN_ADDRESS, pregions = &regions;
             vm_region (task, &address, &size, &protection, &max_protection,
                        &inheritance, &shared, &name, &offset) == KERN_SUCCESS;
             address += size)
        {
            (*pregions) = alloca (sizeof(region_t));
            (*pregions)->address = address;
            (*pregions)->size = size;
            (*pregions)->protection = protection;
            (*pregions)->max_protection = max_protection;
            (*pregions)->file_offset = 0;
            (*pregions)->file_size = 0;
            (*pregions)->next = 0;
            pregions = &((*pregions)->next);
        }
    }
   
    /*
     * Concatenate regions that are adjacent in memory and share the same
     * protection attributes.
     */

    for (cregion = regions; cregion; cregion = cregion->next)
    {
        while ((cregion->next) &&
               (cregion->next->address == cregion->address + cregion->size) &&
               (cregion->next->protection == cregion->protection) &&
               (cregion->next->max_protection == cregion->max_protection))
        {
            cregion->size += cregion->next->size;
            cregion->next = cregion->next->next;
        }
    }
#ifdef VERBOSE   
    printf ("Concatenated regions.\n");
    print_regions (regions);
    printf ("----------------------------------------------------------------------\n");
#endif

    /*
     * Remove read-only regions, and regions above a fixed limit.
     * Could have been done before allocating, but this way we can show
     * the regions before and after while debugging.
     */
    
    for (pregions = &regions; *pregions != NULL;)
    {
        if ( !((*pregions)->protection & VM_PROT_WRITE)
             || ((*pregions)->address >= 0x3000000))
        {
            *pregions = (*pregions)->next;
        }
        else
        {
            pregions = &((*pregions)->next);
        }
    }
#ifdef VERBOSE
    printf ("Skipped regions.\n");
    print_regions (regions);
    printf ("----------------------------------------------------------------------\n");
#endif
    /*
     * Read original mach header and load commands.
     */

    mcopy (infd, -1, 0, (unsigned long) &mach_header, sizeof(mach_header));
    original_load_commands = alloca (mach_header.sizeofcmds);
    mcopy (infd, -1, sizeof(mach_header), (unsigned long) original_load_commands, mach_header.sizeofcmds);

    /*
     * Skip (or adjust) regions that intersect memory represented by non-data
     * segments from the original load commands.
     */

    for (pregions = &regions; *pregions;)
    {
        for (load_command = original_load_commands, i = 0;
            i < mach_header.ncmds;
            i++, load_command = (struct load_command *)(((void *)load_command) + load_command->cmdsize))
        {
            unsigned long ob, oe;
            segment_pointer = (struct segment_command *)load_command;
            if (segment_pointer->cmd != LC_SEGMENT || (strcmp (segment_pointer->segname, SEG_DATA) == 0)) continue;
            ob = MAX((*pregions)->address, segment_pointer->vmaddr);
            oe = MIN((*pregions)->address + (*pregions)->size, segment_pointer->vmaddr + segment_pointer->vmsize);
            if (ob >= oe) continue;
            if (ob == (*pregions)->address)
            {
                if (oe == (*pregions)->address + (*pregions)->size)
                {
                    goto skip_region;
                }
                else
                {
                    (*pregions)->address = oe;
                    (*pregions)->size -= (oe - ob);
                }
            }
            else
            {
                if (oe == (*pregions)->address + (*pregions)->size)
                {
                    (*pregions)->size -= (oe - ob);
                }
                else
                {
                    cregion = alloca (sizeof(*cregion));
                    cregion->address = oe;
                    cregion->size = ((*pregions)->address + (*pregions)->size) - oe;
                    cregion->protection = (*pregions)->protection;
                    cregion->max_protection = (*pregions)->max_protection;
                    cregion->file_offset = 0;
                    cregion->file_size = 0;
                    cregion->next = (*pregions)->next;
                    (*pregions)->size = ob - (*pregions)->address;
                    (*pregions)->next = cregion;
                }
            }
        }

        pregions = &((*pregions)->next);
        continue;

      skip_region:
        *pregions = (*pregions)->next;
    }
#ifdef VERBOSE
    printf ("Munged regions (1).\n");
    print_regions (regions);
    printf ("----------------------------------------------------------------------\n");
#endif

    for (load_command = original_load_commands, i = mach_header.ncmds, header_position = sizeof(mach_header), output_position = 0;
         i > 0;
         i--, load_command = (struct load_command *)(((void *)load_command) + load_command->cmdsize))
    {
        switch (load_command->cmd)
        {
          case LC_SEGMENT:
              segment_pointer = (struct segment_command *)load_command;

              if (strcmp (segment_pointer->segname, SEG_DATA) == 0)
              {
#if 1
                  unsigned long current_address;

                  original_sections = NULL;
                  new_sections = NULL;
                  sect_ptr = &original_sections;

                  section_pointer = (struct section *)(segment_pointer + 1);
                  for (l = 0; l < segment_pointer->nsects; l++)
                  {
                      if (!strncmp (section_pointer->sectname, "__la_symbol_ptr", 16))
                      {
                          found_la_symbol_ptr = 1;
                          section_item = alloca (sizeof (section_list_t));
                          section_item->next = *sect_ptr;
                          section_item->section = *section_pointer;
                          *sect_ptr = section_item;
                          sect_ptr = &(section_item->next);
                      }
                      else if (!strncmp (section_pointer->sectname, "__nl_symbol_ptr", 16))
                      {
                          found_nl_symbol_ptr = 1;
                          section_item = alloca (sizeof (section_list_t));
                          section_item->next = *sect_ptr;
                          section_item->section = *section_pointer;
                          *sect_ptr = section_item;
                          sect_ptr = &(section_item->next);
                      }
                      else if (!strncmp (section_pointer->sectname, "__dyld", 16))
                      {
                          found_dyld = 1;
                          section_item = alloca (sizeof (section_list_t));
                          section_item->next = *sect_ptr;
                          section_item->section = *section_pointer;
                          *sect_ptr = section_item;
                          sect_ptr = &(section_item->next);
                      }

                      section_pointer++;
                  }
#ifdef VERBOSE
                  printf ("la: %d, nl: %d, dyld: %d\n", found_la_symbol_ptr, found_nl_symbol_ptr, found_dyld);
#endif
                  //
                  // Assumption - the special sections we want to handle are in the first segment.
                  // Special sections:
                  //   - __DATA:__data - leave at beginning, take from memory
                  //   - __DATA:__la_symbol_ptr - keep S_LAZY_SYMBOL_POINTERS flag and reserved1, take from original file
                  //   - __DATA:__nl_symbol_ptr - keep S_NON_LAZY_SYMBOL_POINTERS flag and reserved1, take from original file
                  //   - __DATA:__dyld - take from original file
                  //   - remaining - take from memory, throw in __DATA:__data2 section?
                  //
                  // - Get range of first region
                  // - get original __la_symbol_ptr, __symbol_ptr and __dyld sections
                  // - make sure they are within the first region
                  //
                  // - Create new __DATA segment, size=0, nsects=0
                  // - create section for data up to __la_symbol_ptr
                  // - create section for data up to __nl_symbol_ptr
                  // - create section for data up to __dyld
                  // - create section for remaining data
                  //
#if 0
                  cregion = regions;
                  if (cregion != NULL)
                  {
                      unsigned long start, end;

                      start = cregion->address;
                      end = start + cregion->size;
        
                      if (found_la_symbol_ptr == 1)
                      {
                          if (la_symbol_ptr_section.addr < start && la_symbol_ptr_section.addr + la_symbol_ptr_section.size >= end)
                              fatal_unexec ("la_symbol_ptr section lies outside of segment.");
                      }
                      else
                          fatal_unexec ("Couldn't find la_symbol_ptr section.");
        
                      if (found_nl_symbol_ptr == 1)
                      {
                          if (nl_symbol_ptr_section.addr < start && nl_symbol_ptr_section.addr + nl_symbol_ptr_section.size >= end)
                              fatal_unexec ("nl_symbol_ptr section lies outside of segment.");
                      }
                      else
                          fatal_unexec ("Couldn't find nl_symbol_ptr section.");
        
                      if (found_dyld == 1)
                      {
                          if (dyld_section.addr < start && dyld_section.addr + dyld_section.size >= end)
                              fatal_unexec ("dyld section lies outside of segment.");
                      }
                      else
                          fatal_unexec ("Couldn't find dyld section.");
                  }
                  else
                  {
                      fatal_unexec ("No data regions.");
                  }
#endif
                  cregion = regions;
                  // new_data_segment
                  new_data_segment.cmd = LC_SEGMENT;
                  strncpy (new_data_segment.segname, SEG_DATA, 16);
                  new_data_segment.vmaddr = cregion->address;
                  new_data_segment.vmsize = 0;
                  new_data_segment.fileoff = 0;
                  new_data_segment.filesize = 0;
                  new_data_segment.maxprot = cregion->max_protection;
                  new_data_segment.initprot = cregion->protection;
                  new_data_segment.flags = segment_pointer->flags;
                  new_data_segment.nsects = 0;
                  new_data_segment.cmdsize = sizeof (struct segment_command);
#ifdef VERBOSE
                  printf ("Original sections:\n");
                  print_sections (original_sections);
                  printf ("----------------------------------------------------------------------\n");
#endif
                  // Create list of new segments
                  sect_ptr = &new_sections;
                  current_address = new_data_segment.vmaddr;
                  while (original_sections != NULL)
                  {
                      if (current_address < original_sections->section.addr)
                      {
                          // Create new section for this.
                          section_item = alloca (sizeof (section_list_t));
                          section_item->next = *sect_ptr;

                          section_pointer = &(section_item->section);
                          strncpy (section_pointer->sectname, "__data", 16);
                          strncpy (section_pointer->segname, SEG_DATA, 16);
                          section_pointer->addr = current_address;
                          section_pointer->size = original_sections->section.addr - current_address;
                          section_pointer->offset = 0;
                          section_pointer->align = 2; // Yuck.
                          section_pointer->reloff = 0;
                          section_pointer->nreloc = 0;
                          section_pointer->flags = 0; // S_REGULAR?
                          section_pointer->reserved1 = 0;
                          section_pointer->reserved2 = 0;

                          *sect_ptr = section_item;
                          sect_ptr = &(section_item->next);
                          current_address = original_sections->section.addr;
                      }

                      // Put/copy this section into new list
                      section_item = original_sections;
                      original_sections = original_sections->next;
                      section_item->next = *sect_ptr; // Should be NULL...
                      *sect_ptr = section_item;
                      sect_ptr = &(section_item->next);

                      // increase current address
                      current_address += section_item->section.size;
                  }
                  // if current address < end of region, add final section.
                  if (current_address < cregion->address + cregion->size)
                  {
                      // Create new section for this.
                      section_item = alloca (sizeof (section_list_t));
                      section_item->next = *sect_ptr;

                      section_pointer = &(section_item->section);
                      strncpy (section_pointer->sectname, "__data", 16);
                      strncpy (section_pointer->segname, SEG_DATA, 16);
                      section_pointer->addr = current_address;
                      section_pointer->size = cregion->address + cregion->size - current_address;
                      section_pointer->offset = 0;
                      section_pointer->align = 2; // Yuck.
                      section_pointer->reloff = 0;
                      section_pointer->nreloc = 0;
                      section_pointer->flags = 0; // S_REGULAR?
                      section_pointer->reserved1 = 0;
                      section_pointer->reserved2 = 0;

                      *sect_ptr = section_item;
                      sect_ptr = &(section_item->next);
                      current_address = original_sections->section.addr;
                  }
#ifdef VERBOSE
                  printf ("New sections:\n");
                  print_sections (new_sections);
                  printf ("----------------------------------------------------------------------\n");
#endif
                  // Go through new list of sections
                  //   - write section to disk, either from memory or original file
                  //     - say, if offset == 0, take from memory, otherwise from original file at that offset
                  //   - set offset of section
                  //   - set fileoff of segment to be that of the first section
                  //   - increase output position

                  sect_ptr = &new_sections;
                  while (*sect_ptr != NULL)
                  {
                      section_pointer = &((*sect_ptr)->section);
                      if (new_data_segment.fileoff == 0)
                          new_data_segment.fileoff = output_position;
                      new_data_segment.vmsize += section_pointer->size;
                      new_data_segment.filesize += section_pointer->size;
                      new_data_segment.nsects++;
                      new_data_segment.cmdsize += sizeof (struct section);
                      if (section_pointer->offset == 0)
                      {
                          mcopy (-1, outfd, (unsigned long) section_pointer->addr, output_position, section_pointer->size);
                      }
                      else
                      {
                          mcopy (infd, outfd, (unsigned long) section_pointer->offset, output_position, section_pointer->size);
                      }
                      section_pointer->offset = output_position;
                      output_position += section_pointer->size;

                      sect_ptr = &((*sect_ptr)->next);
                  }

                  // Write data segment and sections, increasing the header position
                  mcopy (-1, outfd, (unsigned long) &new_data_segment, header_position, sizeof (struct segment_command));
                  header_position += sizeof (struct segment_command);
                  while (new_sections != NULL)
                  {
                      mcopy (-1, outfd, (unsigned long) &(new_sections->section), header_position, sizeof (struct section));
                      header_position += sizeof (struct section);
                      new_sections = new_sections->next;
                  }
                  mach_header.ncmds++;

                  // Finally, skip first data segment.
                  regions = regions->next;
#endif

#if 1
                  // Write remainder of regions as data segments
                  mach_header.ncmds--;
                  j = segment_pointer->cmdsize; // Save original command size for loop.
                  for (cregion = regions; cregion != NULL; cregion = cregion->next)
                  {
                      mcopy (-1, outfd, cregion->address, output_position, cregion->size);
                      segment_pointer->cmd = LC_SEGMENT;
                      segment_pointer->cmdsize = sizeof(*segment_pointer);
                      strncpy (segment_pointer->segname, SEG_DATA, sizeof(segment_pointer->segname));
                      segment_pointer->vmaddr = cregion->address;
                      segment_pointer->vmsize = cregion->size;
                      segment_pointer->filesize = cregion->size;
                      segment_pointer->maxprot = cregion->max_protection;
                      segment_pointer->initprot = cregion->protection;
                      segment_pointer->nsects = 0;
                      segment_pointer->flags = 0;
                      segment_pointer->fileoff = output_position;
                      output_position += segment_pointer->filesize;
                      mcopy (-1, outfd, (unsigned long)segment_pointer, header_position, segment_pointer->cmdsize);
                      header_position += segment_pointer->cmdsize;
                      mach_header.ncmds++;

                      cregion->file_offset = segment_pointer->fileoff;
                      cregion->file_size = segment_pointer->filesize;
                  }
                  segment_pointer->cmdsize = j;

#endif
              }
              else
              {
                  mcopy (infd, outfd, segment_pointer->fileoff, output_position, segment_pointer->filesize);
                  section_pointer = (struct section *) (((void *)segment_pointer)+sizeof(*segment_pointer));
                  for(j = 0; j < segment_pointer->nsects; j++)
                  {
                      if (section_pointer[j].offset != 0)
                          section_pointer[j].offset = (section_pointer[j].offset - segment_pointer->fileoff) + output_position;
                      if (section_pointer[j].reloff != 0)
                          section_pointer[j].reloff = (section_pointer[j].reloff - segment_pointer->fileoff) + output_position;
                  }

                  if (strcmp (segment_pointer->segname, SEG_LINKEDIT) == 0)
                  {
                      delta = output_position - segment_pointer->fileoff;
                  }

                  segment_pointer->fileoff = output_position;
                  output_position += segment_pointer->filesize;

                  mcopy (-1, outfd, (unsigned long)load_command, header_position, load_command->cmdsize);
                  header_position += load_command->cmdsize;
              }
              break;

          case LC_SYMTAB:
              symtab_pointer = (struct symtab_command *)load_command;

              symtab_pointer->symoff += delta;
              symtab_pointer->stroff += delta;
              mcopy (-1, outfd, (unsigned long)load_command, header_position, load_command->cmdsize);
              header_position += load_command->cmdsize;

              break;
#ifdef NS_TARGET
          case LC_DYSYMTAB:
              dysymtab = (struct dysymtab_command *)load_command;
              extreloff = dysymtab->extreloff;
              nextrel = dysymtab->nextrel;

              locreloff = dysymtab->locreloff;
              nlocrel = dysymtab->nlocrel;

              if (dysymtab->nindirectsyms > 0) {
                  dysymtab->indirectsymoff += delta;
              }
              if (nextrel > 0) {
                  dysymtab->extreloff += delta;
              }

              if (nlocrel > 0) {
                  dysymtab->locreloff += delta;
              }
              mcopy (-1, outfd, (unsigned long)load_command, header_position, load_command->cmdsize);
              header_position += load_command->cmdsize;

              break;
#endif
          default:
              mcopy (-1, outfd, (unsigned long)load_command, header_position, load_command->cmdsize);
              header_position += load_command->cmdsize;
        }
    }

    mach_header.sizeofcmds = header_position - sizeof(mach_header);
    mcopy (-1, outfd, (unsigned long) &mach_header, 0, sizeof(mach_header));

#ifdef NS_TARGET
    if (mach_header.flags & MH_PREBOUND) {
	/* Don't mess with prebound executables */
	return;
    }

     /*
     * Fix up relocation entries in the data segment(s).
     */
    if (lseek (infd, locreloff, L_SET) < 0)
        fatal_unexec ("cannot seek input file");

    fixed_reloc_count = 0;
    for (i = 0; i < nlocrel; i++)
    {
        long zeroval = 0;
	struct scattered_relocation_info *si;

        if (read (infd, &reloc_info, sizeof(reloc_info)) != sizeof(reloc_info))
            fatal_unexec ("cannot read input file");

#if 1
#ifdef VERBOSE
        printf ("%2d: reloc: %lx, start: %lx, end: %lx\n", i, reloc_info.r_address,
                new_data_segment.vmaddr, new_data_segment.vmaddr + new_data_segment.filesize);
#endif
        if (reloc_info.r_address >= new_data_segment.vmaddr
            && reloc_info.r_address < new_data_segment.vmaddr + new_data_segment.filesize)
        {
            fixed_reloc_count++;
            mcopy (-1, outfd, (unsigned long) &zeroval,
                   new_data_segment.fileoff + reloc_info.r_address - new_data_segment.vmaddr,
                   1 << reloc_info.r_length);
        }
#endif
#if 0
        for (cregion = regions; cregion != NULL; cregion = cregion->next)
        {
            if (reloc_info.r_address >= cregion->address
                && reloc_info.r_address < cregion->address + cregion->file_size)
            {
                fixed_reloc_count++;
                mcopy (-1, outfd, (unsigned long) &zeroval,
                       cregion->file_offset + reloc_info.r_address - cregion->address,
                       1 << reloc_info.r_length);
                break;
            }
        }
#endif
    }
    printf ("Fixed %lu/%lu local relocation entries in data segment(s).\n", fixed_reloc_count, nlocrel);

    if (lseek (infd, extreloff, L_SET) < 0)
        fatal_unexec ("cannot seek input file");

    for (i = 0; i < nextrel; i++)
    {
        long zeroval = 0;

        if (read (infd, &reloc_info, sizeof(reloc_info)) != sizeof(reloc_info))
            fatal_unexec ("cannot read input file");

#if 1
#ifdef VERBOSE
        printf ("%2d: reloc: %lx, start: %lx, end: %lx\n", i, reloc_info.r_address,
                new_data_segment.vmaddr, new_data_segment.vmaddr + new_data_segment.filesize);
#endif
        if (reloc_info.r_address >= new_data_segment.vmaddr
            && reloc_info.r_address < new_data_segment.vmaddr + new_data_segment.filesize)
        {
            fixed_reloc_count++;
            mcopy (-1, outfd, (unsigned long) &zeroval,
                   new_data_segment.fileoff + reloc_info.r_address - new_data_segment.vmaddr,
                   1 << reloc_info.r_length);
        }
#endif
#if 0
        for (cregion = regions; cregion != NULL; cregion = cregion->next)
        {
            if (reloc_info.r_address >= cregion->address
                && reloc_info.r_address < cregion->address + cregion->file_size)
            {
                fixed_reloc_count++;
                mcopy (-1, outfd, (unsigned long) &zeroval,
                       cregion->file_offset + reloc_info.r_address - cregion->address,
                       1 << reloc_info.r_length);
                break;
            }
        }
#endif
    }

    printf ("Fixed %lu/%lu external relocation entries in data segment(s).\n", fixed_reloc_count, nextrel);

#endif
}

void unexec (char *outfile, char *infile)
{
    char tmpfile[MAXPATHLEN + 1];
    int infd, outfd;
   
    if ((infd = open (infile, O_RDONLY, 0)) < 0)
        fatal_unexec ("cannot open input file `%s'", infile);

    strcpy (tmpfile, outfile);
    strcat (tmpfile, "-temp");
   
    if ((outfd = open (tmpfile, O_RDWR|O_TRUNC|O_CREAT, 0755)) < 0)
        fatal_unexec ("cannot open temporary output file `%s'", tmpfile);

    unexec_doit (infd, outfd);

    close (infd);
    close (outfd);
    if (rename (tmpfile, outfile) < 0)
    {
        unlink (tmpfile);
        fatal_unexec ("cannot rename `%s' to `%s'", tmpfile, outfile);
    }  
}
