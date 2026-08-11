#include "CWin32Compat.h"
#include <windows.h>
#include <commctrl.h>
#include <gdiplus.h>
#include <gdiplusflat.h>

using namespace Gdiplus;

extern "C" {
int32_t winRegGetValueW(void *key, const uint16_t *subKey, const uint16_t *value, uint32_t flags, uint32_t *type, void *data, uint32_t *size) {
    return RegGetValueW((HKEY)key, (LPCWSTR)subKey, (LPCWSTR)value, flags, (LPDWORD)type, data, (LPDWORD)size);
}
void *winCreateFontW(int32_t h, int32_t w, int32_t e, int32_t o, int32_t weight, uint32_t italic, uint32_t underline, uint32_t strike, uint32_t charset, uint32_t output, uint32_t clip, uint32_t quality, uint32_t pitch, const uint16_t *face) {
    return CreateFontW(h, w, e, o, weight, (DWORD)italic, (DWORD)underline, (DWORD)strike, charset, output, clip, quality, pitch, (LPCWSTR)face);
}
void *winCreateWindowExW(uint32_t ex, const uint16_t *className, const uint16_t *name, uint32_t style, int32_t x, int32_t y, int32_t width, int32_t height, void *parent, void *menu, void *instance, void *parameter) {
    return CreateWindowExW(ex, (LPCWSTR)className, (LPCWSTR)name, style, x, y, width, height, (HWND)parent, (HMENU)menu, (HINSTANCE)instance, parameter);
}
int32_t winImageListDraw(void *list, int32_t index, void *dc, int32_t x, int32_t y, uint32_t style) { return ImageList_Draw((HIMAGELIST)list, index, (HDC)dc, x, y, style); }
int32_t winTrackPopupMenu(void *menu, uint32_t flags, int32_t x, int32_t y, int32_t reserved, void *window, const void *rect) { return TrackPopupMenu((HMENU)menu, flags, x, y, reserved, (HWND)window, (const RECT *)rect); }
void *winLoadImageW(void *instance, const uint16_t *name, uint32_t type, int32_t width, int32_t height, uint32_t flags) { return LoadImageW((HINSTANCE)instance, (LPCWSTR)name, type, width, height, flags); }
int32_t winMoveWindow(void *window, int32_t x, int32_t y, int32_t width, int32_t height, int32_t repaint) { return MoveWindow((HWND)window, x, y, width, height, repaint); }
int32_t winSetWindowPos(void *window, void *after, int32_t x, int32_t y, int32_t width, int32_t height, uint32_t flags) { return SetWindowPos((HWND)window, (HWND)after, x, y, width, height, flags); }
int32_t winBitBlt(void *destination, int32_t x, int32_t y, int32_t width, int32_t height, void *source, int32_t sourceX, int32_t sourceY, uint32_t operation) { return BitBlt((HDC)destination, x, y, width, height, (HDC)source, sourceX, sourceY, operation); }
int32_t winStretchBlt(void *destination, int32_t x, int32_t y, int32_t width, int32_t height, void *source, int32_t sourceX, int32_t sourceY, int32_t sourceWidth, int32_t sourceHeight, uint32_t operation) { return StretchBlt((HDC)destination, x, y, width, height, (HDC)source, sourceX, sourceY, sourceWidth, sourceHeight, operation); }
int32_t winGdipCreateLineBrushFromRectWithAngle(const void *rect, uint32_t color1, uint32_t color2, float angle, int32_t scalable, int32_t wrap, void **brush) { return DllExports::GdipCreateLineBrushFromRectWithAngle((const GpRectF *)rect, color1, color2, angle, scalable, (GpWrapMode)wrap, (GpLineGradient **)brush); }
int32_t winGdipFillRectangle(void *graphics, void *brush, float x, float y, float width, float height) { return DllExports::GdipFillRectangle((GpGraphics *)graphics, (GpBrush *)brush, x, y, width, height); }
int32_t winGdipSetImageAttributesColorMatrix(void *attributes, int32_t type, int32_t enable, const float *matrix, const float *gray, int32_t flags) { return DllExports::GdipSetImageAttributesColorMatrix((GpImageAttributes *)attributes, (ColorAdjustType)type, enable, (const ColorMatrix *)matrix, (const ColorMatrix *)gray, (ColorMatrixFlags)flags); }
int32_t winGdipDrawImageRectRectI(void *graphics, void *image, int32_t dx, int32_t dy, int32_t dw, int32_t dh, int32_t sx, int32_t sy, int32_t sw, int32_t sh, int32_t unit, void *attributes, void *callback, void *data) { return DllExports::GdipDrawImageRectRectI((GpGraphics *)graphics, (GpImage *)image, dx, dy, dw, dh, sx, sy, sw, sh, (GpUnit)unit, (GpImageAttributes *)attributes, (DrawImageAbort)callback, data); }
int32_t winGdipCreateBitmapFromScan0(int32_t width, int32_t height, int32_t stride, int32_t format, void *scan, void **bitmap) { return DllExports::GdipCreateBitmapFromScan0(width, height, stride, format, (BYTE *)scan, (GpBitmap **)bitmap); }
}
