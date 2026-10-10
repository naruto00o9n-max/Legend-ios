#import "Cleaner.h"
#include <algorithm>
#include <cmath>
#include <vector>
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

UIImage *CookiesFillBucket(UIImage *source,CGPoint point,UIColor *color,double tolerance) {
    @try {try {
        cv::Mat rgba=pixels(source),rgb,mask;
        int x=(int)point.x,y=(int)point.y;
        if(x<0||y<0||x>=rgba.cols||y>=rgba.rows)return nil;
        cv::cvtColor(rgba,rgb,cv::COLOR_RGBA2RGB);
        mask=cv::Mat::zeros(rgb.rows+2,rgb.cols+2,CV_8UC1);
        double t=std::max(0.0,std::min(80.0,tolerance));
        cv::floodFill(rgb,mask,cv::Point(x,y),cv::Scalar(),nullptr,cv::Scalar(t,t,t),cv::Scalar(t,t,t),4|cv::FLOODFILL_MASK_ONLY|(255<<8));
        CGFloat r=0,g=0,b=0,a=1;[color getRed:&r green:&g blue:&b alpha:&a];
        cv::Mat patch(rgba.rows,rgba.cols,CV_8UC4,cv::Scalar(0,0,0,0));
        for(int row=0;row<patch.rows;row++)for(int col=0;col<patch.cols;col++)if(mask.at<unsigned char>(row+1,col+1)){patch.at<cv::Vec4b>(row,col)=cv::Vec4b((unsigned char)(r*255),(unsigned char)(g*255),(unsigned char)(b*255),(unsigned char)(a*255));}
        NSData *data=[NSData dataWithBytes:patch.data length:patch.total()*4];CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGImageRef cg=CGImageCreate(patch.cols,patch.rows,8,32,patch.cols*4,space,kCGImageAlphaLast,provider,NULL,false,kCGRenderingIntentDefault);UIImage *result=[UIImage imageWithCGImage:cg];CGImageRelease(cg);CGColorSpaceRelease(space);CGDataProviderRelease(provider);return result;
    }catch(const cv::Exception &){return nil;}}@catch(NSException *exception){return nil;}
}

static UIImage *patchImage(const cv::Mat &patch) {
    NSData *data=[NSData dataWithBytes:patch.data length:patch.total()*4];
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGImageRef cg=CGImageCreate(patch.cols,patch.rows,8,32,patch.cols*4,space,kCGImageAlphaLast,provider,NULL,false,kCGRenderingIntentDefault);
    UIImage *result=[UIImage imageWithCGImage:cg];CGImageRelease(cg);CGColorSpaceRelease(space);CGDataProviderRelease(provider);return result;
}
NSDictionary<NSString *, id> *CookiesWhitenBubble(UIImage *source,NSArray<NSValue *> *outline,NSArray<NSValue *> *textRects) {
    @try {try {
        if(!source.CGImage || outline.count<3)return nil;
        cv::Mat rgba=pixels(source),rgb;cv::cvtColor(rgba,rgb,cv::COLOR_RGBA2RGB);
        if(rgb.total()>4194304)return nil;
        std::vector<cv::Point> polygon;
        for(NSValue *value in outline){CGPoint p=value.CGPointValue;polygon.emplace_back((int)std::round(p.x),(int)std::round(p.y));}
        cv::Rect box=cv::boundingRect(polygon)&cv::Rect(0,0,rgb.cols,rgb.rows);
        if(box.width<24||box.height<24)return nil;
        cv::Mat inside=cv::Mat::zeros(rgb.size(),CV_8UC1);std::vector<std::vector<cv::Point>> polygons{polygon};cv::fillPoly(inside,polygons,cv::Scalar(255));
        int margin=std::max(3,std::min(20,(int)(std::min(box.width,box.height)*0.05)));
        cv::erode(inside,inside,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(2*margin+1,2*margin+1)));
        int innerCount=cv::countNonZero(inside);if(innerCount<200)return nil;
        // Dominant local background, computed inside the protected contour only.
        std::vector<int> histogram(4096,0);int peak=0;
        for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++)if(inside.at<unsigned char>(y,x)){
            auto p=rgb.at<cv::Vec3b>(y,x);int bin=(p[0]>>4)*256+(p[1]>>4)*16+(p[2]>>4);if(++histogram[bin]>histogram[peak])peak=bin;
        }
        cv::Vec3d sum(0,0,0);int samples=0;
        for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++)if(inside.at<unsigned char>(y,x)){
            auto p=rgb.at<cv::Vec3b>(y,x);int bin=(p[0]>>4)*256+(p[1]>>4)*16+(p[2]>>4);if(bin==peak){sum+=cv::Vec3d(p[0],p[1],p[2]);samples++;}
        }
        if(!samples)return nil;cv::Vec3b background((unsigned char)std::round(sum[0]/samples),(unsigned char)std::round(sum[1]/samples),(unsigned char)std::round(sum[2]/samples));
        cv::Mat contrast=cv::Mat::zeros(rgb.size(),CV_8UC1),ocr=cv::Mat::zeros(rgb.size(),CV_8UC1);int near=0;
        for(NSValue *value in textRects){CGRect r=value.CGRectValue;cv::Rect rect((int)std::floor(r.origin.x)-2,(int)std::floor(r.origin.y)-2,(int)std::ceil(r.size.width)+4,(int)std::ceil(r.size.height)+4);rect&=cv::Rect(0,0,rgb.cols,rgb.rows);if(rect.area()>0)ocr(rect).setTo(255);}
        bool localized=cv::countNonZero(ocr)>0;
        for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++){
            auto p=rgb.at<cv::Vec3b>(y,x);int delta=std::max({abs(p[0]-background[0]),abs(p[1]-background[1]),abs(p[2]-background[2])});
            if(inside.at<unsigned char>(y,x)&&delta<=12)near++;
            if(delta>=35)contrast.at<unsigned char>(y,x)=255;
        }
        double flatRatio=(double)near/innerCount;bool flat=flatRatio>=0.80;
        bool white=background[0]>=235&&background[1]>=235&&background[2]>=235;
        // Without text localization, colored/complex art is left untouched.
        if(!localized&&(!flat||!white))return nil;
        cv::Mat labels,stats,centroids;int count=cv::connectedComponentsWithStats(contrast,labels,stats,centroids,8,CV_32S);
        cv::Mat mask=cv::Mat::zeros(rgb.size(),CV_8UC1);std::vector<int> accepted;
        for(int i=1;i<count;i++){
            int area=stats.at<int>(i,cv::CC_STAT_AREA),w=stats.at<int>(i,cv::CC_STAT_WIDTH),h=stats.at<int>(i,cv::CC_STAT_HEIGHT);
            if(area<2||area>innerCount*0.06||w>box.width*0.70||h>box.height*0.40)continue;
            cv::Rect r(stats.at<int>(i,cv::CC_STAT_LEFT),stats.at<int>(i,cv::CC_STAT_TOP),w,h);
            bool safe=true;int evidence=0;
            for(int y=r.y;y<r.y+r.height&&safe;y++)for(int x=r.x;x<r.x+r.width;x++)if(labels.at<int>(y,x)==i){if(!inside.at<unsigned char>(y,x)){safe=false;break;}if(ocr.at<unsigned char>(y,x))evidence++;}
            if(!safe||(localized&&evidence<area*0.65))continue;
            accepted.push_back(i);
        }
        // Fallback requires a cluster of at least three similarly sized glyphs.
        for(int i:accepted){
            bool use=localized;
            if(!use){int neighbors=0;double cy=centroids.at<double>(i,1),cx=centroids.at<double>(i,0);int h=stats.at<int>(i,cv::CC_STAT_HEIGHT);
                for(int j:accepted){int otherH=stats.at<int>(j,cv::CC_STAT_HEIGHT);double dy=abs(centroids.at<double>(j,1)-cy),dx=abs(centroids.at<double>(j,0)-cx);
                    if(otherH>=h*0.45&&otherH<=h*2.2&&((dy<=std::max(h,otherH)*0.6&&dx<=box.width*0.75)||(dx<=std::max(h,otherH)*0.6&&dy<=box.height*0.75)))neighbors++;
                }use=neighbors>=3;
            }
            if(use){cv::Rect r(stats.at<int>(i,cv::CC_STAT_LEFT),stats.at<int>(i,cv::CC_STAT_TOP),stats.at<int>(i,cv::CC_STAT_WIDTH),stats.at<int>(i,cv::CC_STAT_HEIGHT));for(int y=r.y;y<r.y+r.height;y++)for(int x=r.x;x<r.x+r.width;x++)if(labels.at<int>(y,x)==i)mask.at<unsigned char>(y,x)=255;}
        }
        cv::dilate(mask,mask,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(3,3)));cv::bitwise_and(mask,inside,mask);
        int removed=cv::countNonZero(mask);if(removed<6||removed>innerCount*0.30)return nil;
        cv::Mat cleaned,patch;
        if(flat){cleaned=rgb.clone();cleaned.setTo(cv::Scalar(background[0],background[1],background[2]),mask);}
        else{cv::inpaint(rgb,mask,cleaned,3,cv::INPAINT_TELEA);}
        cv::cvtColor(cleaned,patch,cv::COLOR_RGB2RGBA);
        for(int y=0;y<patch.rows;y++)for(int x=0;x<patch.cols;x++)patch.at<cv::Vec4b>(y,x)[3]=mask.at<unsigned char>(y,x);
        return @{@"patch":patchImage(patch),@"removedPixels":@(removed),@"flat":@(flat),@"localized":@(localized),@"reviewRequired":@(!flat||!localized)};
    }catch(const cv::Exception &){return nil;}}@catch(NSException *exception){return nil;}
}
