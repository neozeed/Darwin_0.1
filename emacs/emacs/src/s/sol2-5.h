/* Handle Solaris 2.5.  */

#include "sol2-4.h"

/* If this is not defined, Emacs crashes (perhaps just in batch mode).
   Reported by drew@staff.prodigy.com.  */
#define SYSTEM_MALLOC

/* -lgen is needed for the regex and regcmp functions
   which are used by Motif.  In the future we can try changing
   regex.c to provide them in Emacs, but this is safer for now.  */
#define LIB_MOTIF -lXm -lgen

#if 0 /* A recent patch in unexelf.c should eliminate the need for this.  */
/* Don't use the shared libraries for -lXt and -lXaw,
   to work around a linker bug in Solaris 2.5.
   (This also affects the other libraries used specifically for
   the X toolkit, which may not be necessary.)  */
#define LIBXT_STATIC

#ifdef __GNUC__
#define STATIC_OPTION -Xlinker -Bstatic
#define DYNAMIC_OPTION -Xlinker -Bdynamic
#else
#define STATIC_OPTION -Bstatic
#define DYNAMIC_OPTION -Bdynamic
#endif

#endif /* 0 */
