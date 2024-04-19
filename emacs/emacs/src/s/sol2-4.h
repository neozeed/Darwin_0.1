/* Handle Solaris 2.4.  */

#include "sol2-3.h"

#define SOLARIS2_4

/* Get rid of -traditional and let const really do its thing.  */

#ifdef __GNUC__
#undef C_SWITCH_SYSTEM
#undef const
#endif /* __GNUC__ */

#undef LD_SWITCH_SYSTEM

#ifndef __GNUC__
#define LD_SWITCH_SYSTEM_TEMACS -L/usr/ccs/lib LD_SWITCH_X_SITE_AUX -R/usr/dt/lib -L/usr/dt/lib
#else /* GCC */
/* We use ./prefix-args because we don't know whether LD_SWITCH_X_SITE_AUX
   has anything in it.  It can be empty.
   This works ok in temacs.  */
#define LD_SWITCH_SYSTEM_TEMACS -L/usr/ccs/lib \
 `./prefix-args -Xlinker LD_SWITCH_X_SITE_AUX` -R/usr/dt/lib -L/usr/dt/lib
#endif /* GCC */

/* Gregory Neil Shapiro <gshapiro@hhmi.org> reports the Motif header files
   are in this directory on Solaris 2.4.  */
#define C_SWITCH_X_SYSTEM -I/usr/dt/include

