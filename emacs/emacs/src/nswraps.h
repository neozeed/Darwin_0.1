/* nswraps.h generated from nswraps.pswm
   by unix pswrap V1.009  Wed Apr 19 17:50:24 PDT 1989
 */

#ifndef NSWRAPS_H
#define NSWRAPS_H

extern void nswrap_transtable(const char *EncodingIn, const char *EncodingOut, float Array[]);

extern void nswrap_moveline(float x, float y, float l);

extern void nswrap_moveshow(float x, float y, const char txt[], int n);

extern void nswrap_rect(float x, float y, float w, float h);

extern void nswrap_rect_rev(float x, float y, float w, float h);

#endif NSWRAPS_H
