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

NSDictionary<NSString *, id> *CookiesDetectBubble(UIImage *source,CGPoint point) {
    @try {try {
        cv::Mat rgba=pixels(source),rgb,gray,edges;
        // CGContextDrawImage into this bitmap preserves CGImage row order,
        // as verified by the existing asymmetric inpaint orientation fixture.
        cv::cvtColor(rgba,rgb,cv::COLOR_RGBA2RGB);
        if(point.x<0||point.y<0||point.x>=rgb.cols||point.y>=rgb.rows)return nil;
        cv::cvtColor(rgb,gray,cv::COLOR_RGB2GRAY);cv::medianBlur(gray,gray,7);
        cv::Canny(gray,edges,20,80);cv::dilate(edges,edges,cv::getStructuringElement(cv::MORPH_RECT,cv::Size(3,3)));
        cv::Mat mask=cv::Mat::zeros(rgb.rows+2,rgb.cols+2,CV_8UC1),inner=mask(cv::Rect(1,1,rgb.cols,rgb.rows));edges.copyTo(inner);
        cv::floodFill(rgb,mask,cv::Point((int)point.x,(int)point.y),cv::Scalar(255),nullptr,cv::Scalar(15,15,15),cv::Scalar(15,15,15),261892);
        cv::subtract(inner,edges,inner);cv::morphologyEx(inner,inner,cv::MORPH_CLOSE,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(15,15)));
        std::vector<std::vector<cv::Point>> contours;cv::findContours(inner,contours,cv::RETR_EXTERNAL,cv::CHAIN_APPROX_SIMPLE);
        const std::vector<cv::Point> *best=nullptr;double bestArea=200;
        for(auto &contour:contours){double area=cv::contourArea(contour);cv::Rect box=cv::boundingRect(contour);if(area>bestArea&&box.width<rgb.cols-5&&box.height<rgb.rows-5){best=&contour;bestArea=area;}}
        if(!best)return @{ @"pin":@YES, @"x":@(point.x), @"y":@(point.y), @"width":@0, @"height":@0, @"points":@[] };
        std::vector<cv::Point> simplified;cv::approxPolyDP(*best,simplified,2,true);NSMutableArray *points=[NSMutableArray array];for(auto &p:simplified)[points addObject:@[@(p.x),@(p.y)]];
        cv::Rect box=cv::boundingRect(*best);
        return @{ @"pin":@NO, @"x":@(box.x+box.width*0.1), @"y":@(box.y+box.height*0.1), @"width":@(box.width*0.8), @"height":@(box.height*0.8), @"points":points };
    }catch(const cv::Exception &){return nil;}}@catch(NSException *exception){return nil;}
}
