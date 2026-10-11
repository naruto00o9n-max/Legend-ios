#pragma once
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <vector>
#include <algorithm>

// Closed-boundary detection does not assume a uniform interior color. Text and
// ornament contours can be nested inside the same exterior speech boundary.
static std::vector<cv::Point> CookiesOuterBoundary(const cv::Mat &gray,cv::Point seed) {
    cv::Mat smooth,edges;cv::medianBlur(gray,smooth,5);cv::Canny(smooth,edges,20,80);
    cv::morphologyEx(edges,edges,cv::MORPH_CLOSE,cv::getStructuringElement(cv::MORPH_ELLIPSE,cv::Size(5,5)));
    std::vector<std::vector<cv::Point>> contours;std::vector<cv::Vec4i> hierarchy;
    cv::findContours(edges,contours,hierarchy,cv::RETR_TREE,cv::CHAIN_APPROX_SIMPLE);
    std::vector<cv::Point> best;double bestArea=0;
    for(const auto &contour:contours){
        const double area=std::abs(cv::contourArea(contour));const cv::Rect box=cv::boundingRect(contour);
        if(area<1000||box.width<40||box.height<40||box.x<3||box.y<3||box.br().x>gray.cols-3||box.br().y>gray.rows-3)continue;
        if(area>gray.total()*0.72||area<box.area()*0.38||cv::pointPolygonTest(contour,seed,false)<0)continue;
        // A broken edge contour surrounds a narrow line, not a usable interior.
        const double perimeter=cv::arcLength(contour,true);
        if(perimeter<=0||area/perimeter<8)continue;
        if(area>bestArea){best=contour;bestArea=area;}
    }
    return best;
}
