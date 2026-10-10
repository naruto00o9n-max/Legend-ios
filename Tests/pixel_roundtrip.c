#include "../App/Core/PixelCore.h"
#include "../App/Core/Vendor/libpng/png.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void fixture(const char *path) {
  FILE *file=fopen(path,"wb");assert(file);
  png_structp png=png_create_write_struct(PNG_LIBPNG_VER_STRING,NULL,NULL,NULL);
  png_infop info=png_create_info_struct(png);assert(!setjmp(png_jmpbuf(png)));
  png_init_io(png,file);png_set_IHDR(png,info,800,15000,8,PNG_COLOR_TYPE_RGBA,PNG_INTERLACE_NONE,PNG_COMPRESSION_TYPE_DEFAULT,PNG_FILTER_TYPE_DEFAULT);
  png_set_sRGB(png,info,PNG_sRGB_INTENT_PERCEPTUAL);png_write_info(png,info);
  unsigned char row[800*4];
  for(int y=0;y<15000;y++) {
    for(int x=0;x<800;x++) {row[x*4]=(x*17+y*3)&255;row[x*4+1]=(x*7+y*13)&255;row[x*4+2]=(x^y)&255;row[x*4+3]=(x+y)%19==0?0:((x+y)%11==0?127:255);}
    png_write_row(png,row);
  }
  png_write_end(png,info);png_destroy_write_struct(&png,&info);fclose(file);
}
int main(int argc,char **argv) {
  assert(argc==2);char src[1024],raw[1024],dst[1024],back[1024],error[512]={0};int w,h;
  snprintf(src,sizeof src,"%s/source.png",argv[1]);snprintf(raw,sizeof raw,"%s/source.rgba",argv[1]);snprintf(dst,sizeof dst,"%s/export.png",argv[1]);snprintf(back,sizeof back,"%s/export.rgba",argv[1]);
  fixture(src);assert(LIValidatePNG(src,800,15000)==1);assert(LIImportPNG(src,raw,&w,&h,error,sizeof error)==1);assert(w==800&&h==15000);
  FILE *input=fopen(raw,"rb");assert(input);LIPngWriter *writer=LIWriterOpen(src,dst,w,h,error,sizeof error);assert(writer);
  unsigned char row[800*4],overlay[800*4]={0};
  for(int y=0;y<h;y++){assert(LIReadRegion(raw,w,h,0,y,w,1,1,row)==1);LICompositeRGBA(row,overlay,w);assert(LIWriterRows(writer,row,1)==1);}
  assert(LIWriterFinish(writer)==1);LIWriterClose(writer);fclose(input);
  assert(LIImportPNG(dst,back,&w,&h,error,sizeof error)==1);assert(w==800&&h==15000);
  FILE *a=fopen(raw,"rb"),*b=fopen(back,"rb");assert(a&&b);unsigned char second[800*4];
  for(int y=0;y<h;y++){assert(fread(row,4,w,a)==(size_t)w);assert(fread(second,4,w,b)==(size_t)w);assert(!memcmp(row,second,w*4));}fclose(a);fclose(b);
  unsigned char tile[4*6];assert(LIReadTile(raw,w,h,794,14994,3,2,2,tile)==1);
  unsigned char region[4*9+16];memset(region,0xAD,sizeof region);
  assert(LIReadRegion(raw,w,h,790,14990,6,6,2,region)==1);
  for(int j=0;j<3;j++)for(int i=0;i<3;i++){int x=790+i*2,y=14990+j*2,k=(j*3+i)*4;assert(region[k]==((x*17+y*3)&255));assert(region[k+1]==((x*7+y*13)&255));assert(region[k+2]==((x^y)&255));assert(region[k+3]==((x+y)%19==0?0:((x+y)%11==0?127:255)));}
  for(int i=36;i<52;i++)assert(region[i]==0xAD);
  unsigned char base[]={12,23,34,0,100,120,140,255},upper[]={0,0,0,0,255,0,0,255};LICompositeRGBA(base,upper,2);
  assert(base[0]==12&&base[1]==23&&base[2]==34&&base[3]==0);assert(base[4]==255&&base[5]==0&&base[6]==0&&base[7]==255);
  unsigned char multiplyBase[]={200,100,50,255,12,23,34,0},multiplyOverlay[]={128,128,128,255,0,0,0,0};LICompositeBlend(multiplyBase,multiplyOverlay,2,1);assert(multiplyBase[0]==100&&multiplyBase[1]==50&&multiplyBase[2]==25);assert(multiplyBase[4]==12&&multiplyBase[5]==23&&multiplyBase[6]==34);
  unsigned char addBase[]={204,102,51,255,80,120,160,64},addOverlay[]={102,26,0,128,20,30,40,64};LICompositeBlend(addBase,addOverlay,2,7);assert(addBase[0]==255&&addBase[1]==128&&addBase[2]==51&&addBase[3]==255);assert(addBase[4]==80&&addBase[5]==120&&addBase[6]==159&&addBase[7]==128);
  puts("PASS: 800 x 15000, all 48,000,000 RGBA bytes unchanged after streaming import/export; edge tile and composite verified.");
  return 0;
}
