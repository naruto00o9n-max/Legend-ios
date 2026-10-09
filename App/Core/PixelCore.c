#include "PixelCore.h"
#include "Vendor/libpng/png.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <math.h>

typedef struct { char *message; size_t capacity; } LIError;
static void fail_message(LIError *ctx, const char *message) {
  if(ctx && ctx->message && ctx->capacity) snprintf(ctx->message,ctx->capacity,"%s",message);
}
static void png_failure(png_structp png, png_const_charp message) {
  fail_message((LIError *)png_get_error_ptr(png),message); png_longjmp(png,1);
}
static void png_warning_ignored(png_structp png, png_const_charp message) { (void)png; (void)message; }

int LIImportPNG(const char *source,const char *raw,int *width,int *height,char *error,size_t capacity) {
  LIError ctx={error,capacity}; FILE *input=fopen(source,"rb");
  if(!input){fail_message(&ctx,"Cannot read source image");return 0;}
  FILE *output=fopen(raw,"wb+");if(!output){fclose(input);fail_message(&ctx,"Cannot create image backing file");return 0;}
  png_structp png=png_create_read_struct(PNG_LIBPNG_VER_STRING,&ctx,png_failure,png_warning_ignored);
  png_infop info=png?png_create_info_struct(png):NULL;
  unsigned char * volatile row=NULL;
  int ok=0;
  if(!png || !info){fail_message(&ctx,"Cannot allocate PNG decoder");goto cleanup;}
  if(setjmp(png_jmpbuf(png)))goto cleanup;
  png_init_io(png,input);
  png_set_user_limits(png,32768,1000000);
  png_set_chunk_malloc_max(png,16*1024*1024);
  png_set_crc_action(png,PNG_CRC_ERROR_QUIT,PNG_CRC_ERROR_QUIT);
  png_read_info(png,info);
  png_uint_32 w=png_get_image_width(png,info),h=png_get_image_height(png,info);
  if(!w || !h || w>32768 || h>1000000)png_error(png,"Image dimensions exceed experimental limits");
  int depth=png_get_bit_depth(png,info),color=png_get_color_type(png,info);
  if(depth==16)png_error(png,"16-bit PNG is not supported; use an 8-bit copy");
  if(color==PNG_COLOR_TYPE_PALETTE)png_set_palette_to_rgb(png);
  if(color==PNG_COLOR_TYPE_GRAY && depth<8)png_set_expand_gray_1_2_4_to_8(png);
  if(png_get_valid(png,info,PNG_INFO_tRNS))png_set_tRNS_to_alpha(png);
  if(color==PNG_COLOR_TYPE_GRAY || color==PNG_COLOR_TYPE_GRAY_ALPHA)png_set_gray_to_rgb(png);
  if(!(color & PNG_COLOR_MASK_ALPHA) && !png_get_valid(png,info,PNG_INFO_tRNS))png_set_add_alpha(png,255,PNG_FILLER_AFTER);
  int passes=png_set_interlace_handling(png);png_read_update_info(png,info);
  size_t bytes=png_get_rowbytes(png,info);if(bytes!=(size_t)w*4)png_error(png,"Unsupported PNG layout");
  row=calloc(1,bytes);if(!row)png_error(png,"Cannot allocate PNG row");
  for(int pass=0;pass<passes;pass++)for(png_uint_32 y=0;y<h;y++) {
    off_t offset=(off_t)y*(off_t)bytes;
    if(pass>0){if(fseeko(output,offset,SEEK_SET)!=0 || fread((void *)row,1,bytes,output)!=bytes)png_error(png,"Cannot read interlaced backing row");}
    else memset((void *)row,0,bytes);
    png_read_row(png,(png_bytep)row,NULL);
    if(fseeko(output,offset,SEEK_SET)!=0 || fwrite((void *)row,1,bytes,output)!=bytes)png_error(png,"Not enough storage for image");
  }
  png_read_end(png,info);
  if(fflush(output)!=0)png_error(png,"Backing image flush failed");
  *width=(int)w;*height=(int)h;ok=1;
cleanup:
  free((void *)row);if(png)png_destroy_read_struct(&png,info?&info:NULL,NULL);
  fclose(input);if(fclose(output)!=0){ok=0;fail_message(&ctx,"Backing image close failed");}
  if(!ok)unlink(raw);
  return ok;
}

int LIReadTile(const char *raw,int width,int height,int x,int y,int w,int h,int sample,uint8_t *rgba) {
  if(width<1||height<1||sample<1||w<1||h<1||x<0||y<0||x>=width||y>=height)return 0;
  FILE *file=fopen(raw,"rb");if(!file)return 0;
  int span=width-x;int desired=(w-1)*sample+1;if(span>desired)span=desired;
  uint8_t *row=malloc((size_t)span*4);if(!row){fclose(file);return 0;}
  int ok=1;
  for(int j=0;j<h;j++) {
    int sourceY=y+j*sample;if(sourceY>=height)sourceY=height-1;
    if(fseeko(file,((off_t)sourceY*width+x)*4,SEEK_SET)!=0||fread(row,4,span,file)!=(size_t)span){ok=0;break;}
    for(int i=0;i<w;i++){
      int sourceX=i*sample;if(sourceX>=span)sourceX=span-1;
      uint8_t *pixel=row+sourceX*4,*dest=rgba+((size_t)j*w+i)*4;
      dest[0]=(pixel[0]*pixel[3]+127)/255;dest[1]=(pixel[1]*pixel[3]+127)/255;dest[2]=(pixel[2]*pixel[3]+127)/255;dest[3]=pixel[3];
    }
  }
  free(row);fclose(file);return ok;
}

int LIReadRegion(const char *raw,int width,int height,int x,int y,int w,int h,int sample,uint8_t *rgba) {
  if(!rgba||width<1||height<1||sample<1||w<1||h<1||x<0||y<0||x>=width||y>=height||w>width-x||h>height-y)return 0;
  FILE *file=fopen(raw,"rb");if(!file)return 0;
  unsigned char *row=malloc((size_t)w*4);if(!row){fclose(file);return 0;}
  int columns=(w+sample-1)/sample,rows=(h+sample-1)/sample,ok=1;
  for(int j=0;j<rows;j++) {
    if(fseeko(file,((off_t)(y+j*sample)*width+x)*4,SEEK_SET)!=0||fread(row,4,w,file)!=(size_t)w){ok=0;break;}
    for(int i=0;i<columns;i++)memcpy(rgba+((size_t)j*columns+i)*4,row+(size_t)i*sample*4,4);
  }
  free(row);fclose(file);return ok;
}

void LICompositeRGBA(uint8_t *base,const uint8_t *overlay,size_t pixels) {
  for(size_t i=0;i<pixels;i++){
    uint8_t *b=base+i*4;const uint8_t *o=overlay+i*4;
    unsigned oa=o[3],ba=b[3];if(!oa)continue; /* preserves even RGB hidden under alpha=0 */
    unsigned alpha=oa*255+ba*(255-oa);
    for(int c=0;c<3;c++){
      unsigned value=((unsigned)o[c]*65025+(unsigned)b[c]*ba*(255-oa)+alpha/2)/alpha;
      b[c]=(uint8_t)(value>255?255:value);
    }
    b[3]=(uint8_t)((alpha+127)/255);
  }
}

void LICompositeBlend(uint8_t *base,const uint8_t *overlay,size_t pixels,int mode) {
  if(mode==0){LICompositeRGBA(base,overlay,pixels);return;}
  for(size_t i=0;i<pixels;i++) {
    uint8_t *b=base+i*4;const uint8_t *s=overlay+i*4;
    if(!s[3])continue;
    /* Match Quartz plusLighter / Android PorterDuff ADD: add premultiplied
       channels and alpha, then convert back to the straight PNG layout. */
    if(mode==7) {
      unsigned alpha=s[3]+b[3];if(alpha>255)alpha=255;
      for(int c=0;c<3;c++) {
        unsigned premultiplied=s[c]+((unsigned)b[c]*b[3]+127)/255;
        if(premultiplied>255)premultiplied=255;
        unsigned value=(premultiplied*255+alpha/2)/alpha;
        b[c]=(uint8_t)(value>255?255:value);
      }
      b[3]=(uint8_t)alpha;continue;
    }
    double sa=s[3]/255.0,da=b[3]/255.0,alpha=sa+da*(1-sa);
    for(int c=0;c<3;c++) {
      double source=fmin(1,s[c]/(double)s[3]),dest=b[c]/255.0,blend=source;
      switch(mode){case 1:blend=source*dest;break;case 2:blend=source+dest-source*dest;break;case 3:blend=dest<=0.5?2*source*dest:1-2*(1-source)*(1-dest);break;case 4:blend=fmin(source,dest);break;case 5:blend=fmax(source,dest);break;case 6:blend=fabs(source-dest);break;case 7:blend=fmin(1,source+dest);break;}
      double color=((1-sa)*da*dest+(1-da)*sa*source+sa*da*blend)/alpha;
      b[c]=(uint8_t)fmin(255,fmax(0,lround(color*255)));
    }
    b[3]=(uint8_t)lround(alpha*255);
  }
}

struct LIPngWriter { FILE *file; png_structp png; png_infop info; int width,height,rows; LIError error; };
/* Read just the original PNG header to preserve its color interpretation. */
static void copy_color_metadata(LIPngWriter *writer,const char *source) {
  FILE *file=fopen(source,"rb");if(!file)return;
  unsigned char signature[8];if(fread(signature,1,8,file)!=8||png_sig_cmp(signature,0,8)){fclose(file);png_set_sRGB(writer->png,writer->info,PNG_sRGB_INTENT_PERCEPTUAL);return;}
  png_structp png=png_create_read_struct(PNG_LIBPNG_VER_STRING,NULL,png_failure,png_warning_ignored);
  png_infop info=png?png_create_info_struct(png):NULL;
  if(!png||!info)goto done;
  if(setjmp(png_jmpbuf(png)))goto done;
  png_init_io(png,file);png_set_sig_bytes(png,8);png_set_chunk_malloc_max(png,16*1024*1024);png_read_info(png,info);
  png_charp name;int compression;png_bytep profile;png_uint_32 length;int intent;
  if(png_get_iCCP(png,info,&name,&compression,&profile,&length))png_set_iCCP(writer->png,writer->info,name,compression,profile,length);
  else if(png_get_sRGB(png,info,&intent))png_set_sRGB(writer->png,writer->info,intent);
  double gamma;if(png_get_gAMA(png,info,&gamma))png_set_gAMA(writer->png,writer->info,gamma);
  double wx,wy,rx,ry,gx,gy,bx,by;
  if(png_get_cHRM(png,info,&wx,&wy,&rx,&ry,&gx,&gy,&bx,&by))png_set_cHRM(writer->png,writer->info,wx,wy,rx,ry,gx,gy,bx,by);
done:
  if(png)png_destroy_read_struct(&png,info?&info:NULL,NULL);
  fclose(file);
}
LIPngWriter *LIWriterOpen(const char *original,const char *destination,int width,int height,char *error,size_t capacity) {
  if(width<1||width>32768||height<1||height>1000000)return NULL;
  LIPngWriter * volatile w=calloc(1,sizeof(*w));if(!w)return NULL;
  w->error.message=error;w->error.capacity=capacity;w->width=width;w->height=height;
  w->file=fopen(destination,"wb");
  w->png=png_create_write_struct(PNG_LIBPNG_VER_STRING,&w->error,png_failure,png_warning_ignored);
  w->info=w->png?png_create_info_struct(w->png):NULL;
  if(!w->file||!w->png||!w->info){fail_message(&w->error,"Cannot create PNG output");LIWriterClose(w);return NULL;}
  if(setjmp(png_jmpbuf(w->png))){LIWriterClose(w);return NULL;}
  png_init_io(w->png,w->file);
  png_set_IHDR(w->png,w->info,width,height,8,PNG_COLOR_TYPE_RGBA,PNG_INTERLACE_NONE,PNG_COMPRESSION_TYPE_BASE,PNG_FILTER_TYPE_BASE);
  copy_color_metadata(w,original);
  png_set_filter(w->png,PNG_FILTER_TYPE_BASE,PNG_FILTER_NONE);
  png_write_info(w->png,w->info);return w;
}
int LIWriterRows(LIPngWriter *w,const uint8_t *rgba,int rows) {
  if(!w||rows<1||w->rows+rows>w->height)return 0;
  if(setjmp(png_jmpbuf(w->png)))return 0;
  for(int i=0;i<rows;i++){png_write_row(w->png,(png_const_bytep)(rgba+(size_t)i*w->width*4));w->rows++;}return 1;
}
int LIWriterFinish(LIPngWriter *w) {
  if(!w||w->rows!=w->height)return 0;
  if(setjmp(png_jmpbuf(w->png)))return 0;
  png_write_end(w->png,w->info);
  if(fflush(w->file)!=0){fail_message(&w->error,"PNG output flush failed");return 0;}return 1;
}
void LIWriterClose(LIPngWriter *w) {
  if(!w)return;
  if(w->png)png_destroy_write_struct(&w->png,w->info?&w->info:NULL);
  if(w->file)fclose(w->file);
  free(w);
}

uint8_t *LICopyPNGProfile(const char *source, size_t *length) {
  *length=0; FILE *file=fopen(source,"rb");if(!file)return NULL;
  unsigned char signature[8];
  if(fread(signature,1,8,file)!=8 || png_sig_cmp(signature,0,8)){fclose(file);return NULL;}
  png_structp png=png_create_read_struct(PNG_LIBPNG_VER_STRING,NULL,png_failure,png_warning_ignored);
  png_infop info=png?png_create_info_struct(png):NULL;
  uint8_t * volatile result=NULL;
  if(!png || !info)goto done;
  if(setjmp(png_jmpbuf(png)))goto done;
  png_init_io(png,file);png_set_sig_bytes(png,8);png_set_chunk_malloc_max(png,16*1024*1024);png_read_info(png,info);
  png_charp name; int compression; png_bytep profile; png_uint_32 count;
  if(png_get_iCCP(png,info,&name,&compression,&profile,&count)) {
    result=malloc(count);if(result){memcpy((void *)result,profile,count);*length=count;}
  }
done:
  if(png)png_destroy_read_struct(&png,info?&info:NULL,NULL);
  fclose(file);return (uint8_t *)result;
}
void LIFreeBuffer(void *buffer){free(buffer);}
