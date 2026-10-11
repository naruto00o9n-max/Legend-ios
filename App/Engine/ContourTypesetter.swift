import UIKit

/// Intersect every horizontal band with the real closed outline, not its box.
/// The common interval across all polygon vertices in a band keeps glyphs away
/// from concavities, tails and narrow tips between sampled scanlines.
struct BubbleInterior {
    let target:SniperTarget
    var outline:[Point]{target.outline}
    var body:CGRect{target.bounds.cg}
    func width(at y:Double,height:Double,margin:Double)->Double {
        let top=y-margin,bottom=y+height+margin,cx=Double(body.midX)
        var levels=[top,bottom,(top+bottom)/2]
        for point in outline where point.y>top && point.y<bottom{levels += [point.y-0.001,point.y+0.001]}
        var left = -Double.infinity,right=Double.infinity
        for level in levels {
            var hits:[Double]=[]
            for i in outline.indices{
                let a=outline[i],b=outline[(i+1)%outline.count]
                if (a.y<=level && b.y>level)||(b.y<=level && a.y>level){hits.append(a.x+(level-a.y)*(b.x-a.x)/(b.y-a.y))}
            }
            hits.sort();var interval:(Double,Double)?
            for i in stride(from:0,to:max(0,hits.count-1),by:2){if hits[i]<=cx && hits[i+1]>=cx{interval=(hits[i],hits[i+1]);break}}
            guard let interval else{return 0}
            left=max(left,interval.0+margin);right=min(right,interval.1-margin)
        }
        return max(0,2*min(cx-left,right-cx))
    }
}
enum ContourTypesetter {
    /// A long narrow speech tail should not pull the text toward the bottom
    /// of the bounding box. Use the area centroid when it lies in the contour.
    static func centeredTarget(_ target:SniperTarget)->SniperTarget {
        var twiceArea=0.0,x=0.0,y=0.0
        let points=target.outline
        guard points.count>=3 else{return target}
        let path=UIBezierPath();path.move(to:CGPoint(x:points[0].x,y:points[0].y))
        for i in points.indices {
            let a=points[i],b=points[(i+1)%points.count],cross=a.x*b.y-b.x*a.y
            twiceArea+=cross;x+=(a.x+b.x)*cross;y+=(a.y+b.y)*cross
            path.addLine(to:CGPoint(x:b.x,y:b.y))
        };path.close()
        guard abs(twiceArea)>1 else{return target}
        let center=CGPoint(x:x/(3*twiceArea),y:y/(3*twiceArea))
        guard center.x.isFinite,center.y.isFinite,path.contains(center) else{return target}
        var result=target;result.bounds.x=center.x-target.bounds.width/2;result.bounds.y=center.y-target.bounds.height/2
        return result
    }
    static func fit(_ input:EditorLayer,to target:SniperTarget)throws->EditorLayer {
        guard !target.pin,target.outline.count>=3 else{throw ImageFailure.message("لم يُكتشف محيط مغلق؛ أعد تحديد الفقاعة أو استخدم التنسيق اليدوي")}
        let interior=BubbleInterior(target:centeredTarget(target)),body=interior.body
        let words=input.textContent.split(whereSeparator:{$0.isWhitespace})
        guard !words.isEmpty,words.count<=256,body.width>=24,body.height>=24 else{throw ImageFailure.message("الفقاعة صغيرة أو النص أطول من مساحة التنسيق")}
        // Detector already reserves 10% on all sides. Protect outlines/shadows too.
        let outline=max(input.style.strokeWidth,input.style.fakeBoldWidth,(input.style.extraStrokes ?? []).map(\.width).max() ?? 0)
        let shadow=input.style.shadowAlpha>0 ? max(abs(input.style.shadowDx),abs(input.style.shadowDy))+input.style.shadowRadius*2:0
        let margin=max(4,min(body.width,body.height)*0.055)+CGFloat(outline+shadow)
        let centerWidth=interior.width(at:Double(body.midY)-1,height:2,margin:0)
        let edgeWidth=min(interior.width(at:Double(body.minY)+1,height:2,margin:0),interior.width(at:Double(body.maxY)-3,height:2,margin:0))
        let curved=centerWidth>edgeWidth*1.15
        func capacities(y:Double,step:Double,count:Int)->[Double] {
            (0..<count).map { row in
                let safe=min(maxWidth,interior.width(at:y+Double(row)*step,height:step,margin:Double(margin)))
                let distance=abs(Double(row)-Double(count-1)/2)/max(1,Double(count-1)/2)
                return curved ? min(safe,maxWidth*(1-0.24*distance*distance)):safe
            }
        }
        let maxWidth=max(20,Double(body.width)-2*Double(margin))
        var best:EditorLayer?,bestSize=0.0
        for count in 1...min(16,words.count){
            var low=6.0,high=min(192,max(input.style.fontSize,Double(body.height)))
            var candidate:EditorLayer?
            for _ in 0..<10{
                let size=(low+high)/2
                var layer=input;layer.rotation=0;layer.scaleX=1;layer.scaleY=1;layer.shearX=nil
                layer.style.fontSize=size;layer.style.boxWidth=maxWidth;layer.style.alignment=1
                let font=Fonts.font(layer.style)
                // Measure line fragments using the same native paragraph settings.
                layer.textContent=Array(repeating:"آHg",count:count).joined(separator:"\n")
                let height=Double(LayerRenderer.bounds(layer).height),step=height/Double(count),y=Double(body.midY)-height/2
                if height>Double(body.height)-2*Double(margin){high=size;continue}
                let widths=capacities(y:y,step:step,count:count)
                let measure:(String)->Double={Double(($0 as NSString).size(withAttributes:[.font:font,.kern:layer.style.letterSpacing]).width)}
                guard let lines=BubbleLayout.lines(input.textContent,widths:widths,measure:measure) else{high=size;continue}
                layer.textContent=lines.joined(separator:"\n")
                let actual=Double(LayerRenderer.bounds(layer).height)
                // Font fallback and Arabic diacritics can change measured height.
                let actualY=Double(body.midY)-actual/2,actualStep=actual/Double(count)
                let valid=actual<=Double(body.height)-2*Double(margin) && lines.enumerated().allSatisfy{row,text in
                    measure(text)<=capacities(y:actualY,step:actualStep,count:count)[row]
                }
                if valid{layer.frame=Box(x:body.midX-maxWidth/2,y:actualY,width:maxWidth,height:actual);candidate=layer;low=size}else{high=size}
            }
            if let candidate,candidate.style.fontSize>bestSize{best=candidate;bestSize=candidate.style.fontSize}
        }
        guard let best else{throw ImageFailure.message("لا يتسع النص بأمان داخل هذا المحيط؛ وسّع التحديد أو قسّم النص")}
        return best
    }
}
