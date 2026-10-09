#import "Cleaner.h"
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/photo.hpp>

static cv::Mat pixels(UIImage *image) {
    CGImageRef cg=image.CGImage;
    cv::Mat rgba((int)CGImageGetHeight(cg),(int)CGImageGetWidth(cg),CV_8UC4);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(rgba.data,rgba.cols,rgba.rows,8,rgba.step[0],space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
    CGContextDrawImage(context,CGRectMake(0,0,rgba.cols,rgba.rows),cg);CGContextRelease(context);CGColorSpaceRelease(space);return rgba;
}
UIImage *CookiesInpaint(UIImage *source,UIImage *mask,double radius) {
    @try {try {
        cv::Mat rgba=pixels(source),m=pixels(mask),rgb,gray,cleaned,patch;
        if(rgba.size()!=m.size())return nil;
        cv::cvtColor(rgba,rgb,cv::COLOR_RGBA2RGB);cv::cvtColor(m,gray,cv::COLOR_RGBA2GRAY);cv::threshold(gray,gray,127,255,cv::THRESH_BINARY);
        cv::inpaint(rgb,gray,cleaned,std::max(1.0,std::min(20.0,radius)),cv::INPAINT_TELEA);cv::cvtColor(cleaned,patch,cv::COLOR_RGB2RGBA);
        for(int y=0;y<patch.rows;y++)for(int x=0;x<patch.cols;x++)patch.at<cv::Vec4b>(y,x)[3]=gray.at<unsigned char>(y,x);
        NSData *data=[NSData dataWithBytes:patch.data length:patch.total()*4];CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
        CGImageRef cg=CGImageCreate(patch.cols,patch.rows,8,32,patch.cols*4,space,kCGImageAlphaLast,provider,NULL,false,kCGRenderingIntentDefault);
        UIImage *result=[UIImage imageWithCGImage:cg];CGImageRelease(cg);CGColorSpaceRelease(space);CGDataProviderRelease(provider);return result;
    }catch(const cv::Exception &){return nil;}}@catch(NSException *exception){return nil;}
}
