#ifndef CWIN32COMPAT_H
#define CWIN32COMPAT_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int32_t winRegGetValueW(void *, const uint16_t *, const uint16_t *, uint32_t, uint32_t *, void *, uint32_t *);
void *winCreateFontW(int32_t, int32_t, int32_t, int32_t, int32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, const uint16_t *);
void *winCreateWindowExW(uint32_t, const uint16_t *, const uint16_t *, uint32_t, int32_t, int32_t, int32_t, int32_t, void *, void *, void *, void *);
int32_t winImageListDraw(void *, int32_t, void *, int32_t, int32_t, uint32_t);
int32_t winTrackPopupMenu(void *, uint32_t, int32_t, int32_t, int32_t, void *, const void *);
void *winLoadImageW(void *, const uint16_t *, uint32_t, int32_t, int32_t, uint32_t);
int32_t winMoveWindow(void *, int32_t, int32_t, int32_t, int32_t, int32_t);
int32_t winSetWindowPos(void *, void *, int32_t, int32_t, int32_t, int32_t, uint32_t);
int32_t winBitBlt(void *, int32_t, int32_t, int32_t, int32_t, void *, int32_t, int32_t, uint32_t);
int32_t winStretchBlt(void *, int32_t, int32_t, int32_t, int32_t, void *, int32_t, int32_t, int32_t, int32_t, uint32_t);
int32_t winGdipCreateLineBrushFromRectWithAngle(const void *, uint32_t, uint32_t, float, int32_t, int32_t, void **);
int32_t winGdipFillRectangle(void *, void *, float, float, float, float);
int32_t winGdipSetImageAttributesColorMatrix(void *, int32_t, int32_t, const float *, const float *, int32_t);
int32_t winGdipDrawImageRectRectI(void *, void *, int32_t, int32_t, int32_t, int32_t, int32_t, int32_t, int32_t, int32_t, int32_t, void *, void *, void *);
int32_t winGdipCreateBitmapFromScan0(int32_t, int32_t, int32_t, int32_t, void *, void **);

#ifdef __cplusplus
}
#endif
#endif
