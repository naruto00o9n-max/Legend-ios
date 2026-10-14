import Foundation
import CoreGraphics

extension EditorModel {
    func beginManualSniper(_ tool:ManualSniperTool,replacing:UUID?=nil,returnToWhitening:Bool=false){
        guard !busy else{return};manualSniperReplacement=replacing;returnToWhiteningAfterDrawing=returnToWhitening;manualSniperTool=tool;sniperWhiteningOpen=false;sniperMode=true;bubbleShape=nil;self.tool = .move;panel=nil
    }
    func cancelManualSniper(){manualSniperTool=nil;manualSniperReplacement=nil;if returnToWhiteningAfterDrawing{sniperWhiteningOpen=true};returnToWhiteningAfterDrawing=false}
    func finishManualSniper(_ points:[CGPoint]){
        guard let method=manualSniperTool else{return}
        defer{cancelManualSniper()}
        let points=points.map{CGPoint(x:max(0,min(CGFloat(page.width-1),$0.x)),y:max(0,min(CGFloat(page.height-1),$0.y)))}
        guard points.count>=3,points.allSatisfy({$0.x.isFinite && $0.y.isFinite}) else{return}
        let xs=points.map(\.x),ys=points.map(\.y),rect=CGRect(x:xs.min()!,y:ys.min()!,width:xs.max()!-xs.min()!,height:ys.max()!-ys.min()!)
        if method == .textRectangle{
            guard let id=manualSniperReplacement,let index=sniperTargets.firstIndex(where:{$0.id==id}),rect.width>=2,rect.height>=2 else{error="حدد منطقة النص داخل الفقاعة";return}
            let target=sniperTargets[index].bounds,clipped=rect.intersection(CGRect(x:target.x,y:target.y,width:target.width,height:target.height))
            guard !clipped.isNull,clipped.width>=2,clipped.height>=2 else{error="ارسم منطقة النص داخل الفقاعة المحددة";return}
            sniperTargets[index].manualTextRegions.append(Box(x:clipped.minX,y:clipped.minY,width:clipped.width,height:clipped.height));focusedSniperTarget=id;return
        }
        var twiceArea=CGFloat(0)
        for i in points.indices{let next=points[(i+1)%points.count];twiceArea+=points[i].x*next.y-next.x*points[i].y}
        guard rect.width>=24,rect.height>=24,abs(twiceArea)>=256 else{error="ارسم محيطًا واضحًا داخل الفقاعة؛ المساحة صغيرة أو متقاطعة";return}
        var target=SniperTarget(bounds:Box(x:rect.minX,y:rect.minY,width:rect.width,height:rect.height),outline:points.map{Point(x:$0.x,y:$0.y)},point:Point(x:rect.midX,y:rect.midY));target.manuallySelected=true
        if let id=manualSniperReplacement,let index=sniperTargets.firstIndex(where:{$0.id==id}){target.id=id;target.whiteningMethod=sniperTargets[index].whiteningMethod;target.manualTextRegions=sniperTargets[index].manualTextRegions;sniperTargets[index]=target}else{sniperTargets.append(target)}
        focusedSniperTarget=target.id
    }
    func cancelWhitening(){whiteningTask?.cancel()}
}
