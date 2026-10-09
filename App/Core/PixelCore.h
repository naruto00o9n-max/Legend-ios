#ifndef LI_PIXEL_CORE_H
#define LI_PIXEL_CORE_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
/* PNG is decoded to an RGBA8 disk file, not a full-image allocation. */
int LIImportPNG(const char *source, const char *raw, int *width, int *height, char *error, size_t capacity);
uint8_t *LICopyPNGProfile(const char *source, size_t *length);
void LIFreeBuffer(void *buffer);
int LIReadTile(const char *raw, int width, int height, int x, int y, int w, int h, int sample, uint8_t *rgba);
/* Read a source region to ceil(w/sample) * ceil(h/sample) straight RGBA pixels. */
int LIReadRegion(const char *raw, int width, int height, int x, int y, int w, int h, int sample, uint8_t *rgba);
void LICompositeRGBA(uint8_t *base, const uint8_t *premultipliedOverlay, size_t pixels);
void LICompositeBlend(uint8_t *base, const uint8_t *premultipliedOverlay, size_t pixels, int mode);
typedef struct LIPngWriter LIPngWriter;
LIPngWriter *LIWriterOpen(const char *original, const char *destination, int width, int height, char *error, size_t capacity);
int LIWriterRows(LIPngWriter *writer, const uint8_t *rgba, int rows);
int LIWriterFinish(LIPngWriter *writer);
void LIWriterClose(LIPngWriter *writer);
#ifdef __cplusplus
}
#endif
#endif
