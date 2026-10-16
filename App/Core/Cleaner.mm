#import "Cleaner.h"
#include "BubbleBoundary.hpp"
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
        auto exterior=CookiesOuterBoundary(gray,cv::Point((int)point.x,(int)point.y));
        const std::vector<cv::Point> *best=exterior.empty()?nullptr:&exterior;double bestArea=exterior.empty()?200:cv::contourArea(exterior);
        for(auto &contour:contours){double area=cv::contourArea(contour);cv::Rect box=cv::boundingRect(contour);if(exterior.empty()&&area>bestArea&&box.width<rgb.cols-5&&box.height<rgb.rows-5&&cv::pointPolygonTest(contour,cv::Point((int)point.x,(int)point.y),false)>=0){best=&contour;bestArea=area;}}
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
UIImage *CookiesMatchRestoration(UIImage *source,UIImage *candidate,UIImage *mask) {
    @try {try {
        if(!source.CGImage||!candidate.CGImage||!mask.CGImage)return nil;
        size_t width=CGImageGetWidth(source.CGImage),height=CGImageGetHeight(source.CGImage);
        if(width<4||height<4||width*height>4194304||CGImageGetWidth(candidate.CGImage)!=width||CGImageGetHeight(candidate.CGImage)!=height||CGImageGetWidth(mask.CGImage)!=width||CGImageGetHeight(mask.CGImage)!=height)return nil;
        cv::Mat original=pixels(source),generated=pixels(candidate),selection=pixels(mask),a,b,m,blended,patch;
        cv::cvtColor(original,a,cv::COLOR_RGBA2BGR);cv::cvtColor(generated,b,cv::COLOR_RGBA2BGR);
        // Preserve the application's exact positive-red mask convention.
        cv::extractChannel(selection,m,0);cv::threshold(m,m,0,255,cv::THRESH_BINARY);
        if(cv::countNonZero(m)<6)return nil;
        cv::Rect box=cv::boundingRect(m);
        if(box.x<1||box.y<1||box.br().x>m.cols-1||box.br().y>m.rows-1)return nil;
        // seamlessClone may mutate its mask. Keep m immutable for final alpha.
        cv::Mat working=m.clone();
        cv::seamlessClone(b,a,working,cv::Point(box.x+box.width/2,box.y+box.height/2),blended,cv::NORMAL_CLONE);
        cv::cvtColor(blended,patch,cv::COLOR_BGR2RGBA);
        for(int y=0;y<patch.rows;y++)for(int x=0;x<patch.cols;x++){if(m.at<unsigned char>(y,x))patch.at<cv::Vec4b>(y,x)[3]=255;else patch.at<cv::Vec4b>(y,x)=cv::Vec4b(0,0,0,0);}
        return patchImage(patch);
    }catch(const cv::Exception &){return nil;}}@catch(NSException *exception){return nil;}
}
NSDictionary<NSString *, id> *CookiesCreateBubbleTextMask(CGSize size,NSArray<NSValue *> *outline,NSArray<NSValue *> *textRects,double padding) {
    @try {try {
        if(!std::isfinite(size.width)||!std::isfinite(size.height)||size.width<24||size.height<24||size.width>4096||size.height>4096||size.width*size.height>4194304||outline.count<3||outline.count>2048||textRects.count==0)return nil;
        int width=(int)size.width,height=(int)size.height;std::vector<cv::Point> polygon;
        for(NSValue *v in outline){CGPoint p=v.CGPointValue;if(!std::isfinite(p.x)||!std::isfinite(p.y))return nil;polygon.emplace_back((int)std::round(std::clamp((double)p.x,0.0,(double)width-1)),(int)std::round(std::clamp((double)p.y,0.0,(double)height-1)));}
        cv::Mat inside=cv::Mat::zeros(height,width,CV_8UC1),mask=inside.clone();std::vector<std::vector<cv::Point>> paths{polygon};cv::fillPoly(inside,paths,cv::Scalar(255));
        cv::erode(inside,inside,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(7,7)));
        for(NSValue *v in textRects){CGRect r=v.CGRectValue;if(!std::isfinite(r.origin.x)||!std::isfinite(r.origin.y)||!std::isfinite(r.size.width)||!std::isfinite(r.size.height)||r.size.width<=0||r.size.height<=0)continue;
            double spread=std::clamp(padding,1.0,24.0);if(padding>=8)spread=std::max(spread,std::min(24.0,std::min((double)r.size.width,(double)r.size.height)*0.25));
            CGRect clipped=CGRectIntersection(CGRectInset(r,-spread,-spread),CGRectMake(0,0,width,height));if(CGRectIsNull(clipped)||CGRectIsEmpty(clipped))continue;
            int x=std::max(0,(int)std::floor(clipped.origin.x)),y=std::max(0,(int)std::floor(clipped.origin.y));int right=std::min(width,(int)std::ceil(CGRectGetMaxX(clipped))),bottom=std::min(height,(int)std::ceil(CGRectGetMaxY(clipped)));if(right>x&&bottom>y)mask(cv::Rect(x,y,right-x,bottom-y)).setTo(255);
        }
        cv::bitwise_and(mask,inside,mask);int count=cv::countNonZero(mask),interior=cv::countNonZero(inside);if(count<6||count>interior*0.90)return nil;
        cv::Mat rgba;cv::cvtColor(mask,rgba,cv::COLOR_GRAY2RGBA);return @{@"mask":patchImage(rgba),@"maskedPixels":@(count),@"interiorPixels":@(interior)};
    }catch(const cv::Exception &){return nil;}}@catch(NSException *exception){return nil;}
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
        // Protect a narrow contour band, rather than discarding five percent
        // of every bubble: small bubbles also need their edge-adjacent glyphs.
        int margin=std::max(3,std::min(12,(int)(std::min(box.width,box.height)*0.025)));
        cv::erode(inside,inside,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(2*margin+1,2*margin+1)));
        int innerCount=cv::countNonZero(inside);if(innerCount<200)return nil;
        std::vector<int> histogram(4096,0);int peak=0;
        for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++)if(inside.at<unsigned char>(y,x)){
            auto p=rgb.at<cv::Vec3b>(y,x);int bin=(p[0]>>4)*256+(p[1]>>4)*16+(p[2]>>4);if(++histogram[bin]>histogram[peak])peak=bin;
        }
        cv::Vec3d sum(0,0,0);int samples=0;
        for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++)if(inside.at<unsigned char>(y,x)){
            auto p=rgb.at<cv::Vec3b>(y,x);int bin=(p[0]>>4)*256+(p[1]>>4)*16+(p[2]>>4);if(bin==peak){sum+=cv::Vec3d(p[0],p[1],p[2]);samples++;}
        }
        if(!samples)return nil;
        cv::Vec3b background((unsigned char)std::round(sum[0]/samples),(unsigned char)std::round(sum[1]/samples),(unsigned char)std::round(sum[2]/samples));
        cv::Mat delta=cv::Mat::zeros(rgb.size(),CV_8UC1),ocr=cv::Mat::zeros(rgb.size(),CV_8UC1);int near=0;
        double smallestText=std::min(box.width,box.height);
        for(NSValue *value in textRects){CGRect r=value.CGRectValue;
            if(!std::isfinite(r.origin.x)||!std::isfinite(r.origin.y)||!std::isfinite(r.size.width)||!std::isfinite(r.size.height)||r.size.width<=0||r.size.height<=0)continue;
            smallestText=std::min(smallestText,(double)std::min(r.size.width,r.size.height));
            int pad=std::max(3,std::min(12,(int)(std::min(r.size.width,r.size.height)*0.12)));
            cv::Rect rect((int)std::floor(r.origin.x)-pad,(int)std::floor(r.origin.y)-pad,(int)std::ceil(r.size.width)+2*pad,(int)std::ceil(r.size.height)+2*pad);
            rect&=cv::Rect(0,0,rgb.cols,rgb.rows);if(rect.area()>0)ocr(rect).setTo(255);
        }
        bool localized=cv::countNonZero(ocr)>0;
        for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++){
            auto p=rgb.at<cv::Vec3b>(y,x);int d=std::max({abs(p[0]-background[0]),abs(p[1]-background[1]),abs(p[2]-background[2])});
            delta.at<unsigned char>(y,x)=(unsigned char)d;if(inside.at<unsigned char>(y,x)&&d<=12)near++;
        }
        int backgroundSamples=0,uniformSamples=0;
        if(localized){for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++)if(inside.at<unsigned char>(y,x)&&!ocr.at<unsigned char>(y,x)){
            backgroundSamples++;if(delta.at<unsigned char>(y,x)<=12)uniformSamples++;
        }}
        bool flat=localized ? backgroundSamples>=innerCount*0.20&&(double)uniformSamples/backgroundSamples>=0.97:(double)near/innerCount>=0.80;
        bool white=background[0]>=235&&background[1]>=235&&background[2]>=235;
        // Vision may detect only the top line. Ink in undetected lines must not
        // turn a genuinely white, uniform bubble into a textured-background case.
        if(white&&(double)near/innerCount>=0.70)flat=true;
        if(!localized&&(!flat||!white))return nil;
        std::vector<cv::Mat> contrasts;
        if(localized&&!flat){
            cv::Mat smooth,dark=cv::Mat::zeros(rgb.size(),CV_8UC1),light=dark.clone();cv::GaussianBlur(rgb,smooth,cv::Size(31,31),0);
            // Keep positive and negative contrast separate. Absolute contrast
            // joins dark letters to bright halos and rejects whole text lines.
            for(int y=0;y<rgb.rows;y++)for(int x=0;x<rgb.cols;x++){
                auto p=rgb.at<cv::Vec3b>(y,x),b=smooth.at<cv::Vec3b>(y,x);
                int negative=std::max({(int)b[0]-p[0],(int)b[1]-p[1],(int)b[2]-p[2]});
                int positive=std::max({(int)p[0]-b[0],(int)p[1]-b[1],(int)p[2]-b[2]});
                dark.at<unsigned char>(y,x)=negative>=20?255:0;light.at<unsigned char>(y,x)=positive>=20?255:0;
            }
            contrasts={dark,light};
        }else{cv::Mat ink;cv::compare(delta,24,ink,cv::CMP_GE);contrasts.push_back(ink);}
        cv::Mat mask=cv::Mat::zeros(rgb.size(),CV_8UC1);std::vector<int> heights;
        for(const cv::Mat &contrast:contrasts){
            cv::Mat labels,stats,centroids;int count=cv::connectedComponentsWithStats(contrast,labels,stats,centroids,8,CV_32S);
            std::vector<int> accepted;
            for(int i=1;i<count;i++){
                int area=stats.at<int>(i,cv::CC_STAT_AREA),w=stats.at<int>(i,cv::CC_STAT_WIDTH),h=stats.at<int>(i,cv::CC_STAT_HEIGHT);
                // Arabic words and outlined letters may be one connected shape.
                if(area<3||area>innerCount*(localized?0.30:0.20)||w>box.width*0.90||h>box.height*0.70)continue;
                cv::Rect r(stats.at<int>(i,cv::CC_STAT_LEFT),stats.at<int>(i,cv::CC_STAT_TOP),w,h);
                bool safe=true;int evidence=0;
                for(int y=r.y;y<r.y+r.height&&safe;y++)for(int x=r.x;x<r.x+r.width;x++)if(labels.at<int>(y,x)==i){if(!inside.at<unsigned char>(y,x)){safe=false;break;}if(ocr.at<unsigned char>(y,x))evidence++;}
                if(!safe||(localized&&!flat&&evidence<area*0.65))continue;accepted.push_back(i);
            }
            if(!localized&&accepted.size()>2048)return nil;
            for(int i:accepted){
                cv::Rect candidate(stats.at<int>(i,cv::CC_STAT_LEFT),stats.at<int>(i,cv::CC_STAT_TOP),stats.at<int>(i,cv::CC_STAT_WIDTH),stats.at<int>(i,cv::CC_STAT_HEIGHT));
                bool use=localized&&(!flat||cv::countNonZero(ocr(candidate))>0);
                if(!use){int neighbors=0;double cy=centroids.at<double>(i,1),cx=centroids.at<double>(i,0);int h=stats.at<int>(i,cv::CC_STAT_HEIGHT),w=stats.at<int>(i,cv::CC_STAT_WIDTH);
                    for(int j:accepted){int otherH=stats.at<int>(j,cv::CC_STAT_HEIGHT),otherW=stats.at<int>(j,cv::CC_STAT_WIDTH);double dy=abs(centroids.at<double>(j,1)-cy),dx=abs(centroids.at<double>(j,0)-cx);
                        if(otherH>=h*0.30&&otherH<=h*3.5&&((dy<=std::max(h,otherH)*0.8&&dx<=box.width*0.85)||(dx<=std::max(w,otherW)*0.8&&dy<=box.height*0.85))){neighbors++;if(neighbors>=2)break;}
                    }use=neighbors>=2;
                }
                if(use){heights.push_back(stats.at<int>(i,cv::CC_STAT_HEIGHT));cv::Rect r(stats.at<int>(i,cv::CC_STAT_LEFT),stats.at<int>(i,cv::CC_STAT_TOP),stats.at<int>(i,cv::CC_STAT_WIDTH),stats.at<int>(i,cv::CC_STAT_HEIGHT));for(int y=r.y;y<r.y+r.height;y++)for(int x=r.x;x<r.x+r.width;x++)if(labels.at<int>(y,x)==i)mask.at<unsigned char>(y,x)=255;}
            }
        }
        double glyphHeight=8;int spread=2;if(!heights.empty()){std::sort(heights.begin(),heights.end());double median=heights[heights.size()/2];if(heights.size()%2==0)median=(median+heights[heights.size()/2-1])/2;glyphHeight=median;spread=std::max(2,std::min(18,(int)std::round(median*0.45)));}
        if(flat){
            // Follow weak antialiasing, stroke and shadow pixels connected to
            // validated glyphs. Never grow weak contrast throughout the bubble.
            cv::Mat envelope,weak,labels,stats,centroids;
            cv::dilate(mask,envelope,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(2*spread+1,2*spread+1)));
            cv::compare(delta,3,weak,cv::CMP_GE);cv::bitwise_and(weak,envelope,weak);cv::bitwise_and(weak,inside,weak);
            int count=cv::connectedComponentsWithStats(weak,labels,stats,centroids,8,CV_32S);std::vector<bool> seeded(count,false);
            for(int y=0;y<mask.rows;y++)for(int x=0;x<mask.cols;x++)if(mask.at<unsigned char>(y,x))seeded[labels.at<int>(y,x)]=true;
            // Detached Arabic dots/diacritics in an OCR-missed line do not
            // connect to the body of the letter. Accept only small components
            // within the tight glyph envelope; distant decoration stays intact.
            for(int i=1;i<count;i++)if(!seeded[i]&&flat&&(white||localized)&&stats.at<int>(i,cv::CC_STAT_AREA)<=std::max(24.0,glyphHeight*glyphHeight*0.20))seeded[i]=true;
            for(int y=0;y<mask.rows;y++)for(int x=0;x<mask.cols;x++){int label=labels.at<int>(y,x);mask.at<unsigned char>(y,x)=label>0&&seeded[label]?255:0;}
        }
        if(flat&&localized){
            // On a verified uniform background, remove weak disconnected dots
            // and compression fringes inside detected text boxes as well.
            cv::Mat fringe;cv::compare(delta,3,fringe,cv::CMP_GE);cv::bitwise_and(fringe,ocr,fringe);cv::bitwise_and(fringe,inside,fringe);cv::bitwise_or(mask,fringe,mask);
        }
        int radius=flat?2:std::max(3,std::min(12,(int)std::round(smallestText*0.075)));
        cv::dilate(mask,mask,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(2*radius+1,2*radius+1)));cv::bitwise_and(mask,inside,mask);
        if(!flat){std::vector<std::vector<cv::Point>> contours;cv::findContours(mask.clone(),contours,cv::RETR_EXTERNAL,cv::CHAIN_APPROX_SIMPLE);cv::drawContours(mask,contours,-1,cv::Scalar(255),cv::FILLED);cv::bitwise_and(mask,inside,mask);}
        int removed=cv::countNonZero(mask);if(removed<6||removed>innerCount*0.55)return nil;
        cv::Mat cleaned,patch;
        if(flat){cleaned=rgb.clone();cleaned.setTo(cv::Scalar(background[0],background[1],background[2]),mask);}
        else{cv::inpaint(rgb,mask,cleaned,5,cv::INPAINT_TELEA);}
        cv::cvtColor(cleaned,patch,cv::COLOR_RGB2RGBA);
        for(int y=0;y<patch.rows;y++)for(int x=0;x<patch.cols;x++)patch.at<cv::Vec4b>(y,x)[3]=mask.at<unsigned char>(y,x);
        return @{@"patch":patchImage(patch),@"removedPixels":@(removed),@"flat":@(flat),@"localized":@(localized),@"reviewRequired":@(!flat||!localized||!white)};
    }catch(const cv::Exception &){return nil;}}@catch(NSException *exception){return nil;}
}
