import UIKit

/// A bounded, mutable working region. Finger motion moves sampled paint; source
/// pixels stay untouched and only a masked result becomes a new editable layer.
final class SmudgeSession {
    let region:CGRect
    private let context:CGContext
    private let mask:CGContext
    private var previous:CGPoint
    private let width:CGFloat
    private let strength:CGFloat
    init(page:EditorPage,directory:URL,region:CGRect,point:CGPoint,width:Double,strength:Double)throws {
        self.region=region.integral.intersection(CGRect(x:0,y:0,width:page.width,height:page.height))
        let w=Int(self.region.width),h=Int(self.region.height)
        guard w>0,h>0,w*h<=2_097_152,let context=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:ImagePipeline.colorSpace(directory.appendingPathComponent(page.source)),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue),let mask=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:ImagePipeline.space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{throw ImageFailure.message("كبّر اللوحة لتعمل أداة الطمس ضمن مساحة أصغر")}
        self.context=context;self.mask=mask;self.width=CGFloat(width);self.strength=CGFloat(min(1,max(0,strength)));previous=CGPoint(x:point.x-self.region.minX,y:point.y-self.region.minY)
        context.translateBy(x:0,y:CGFloat(h));context.scaleBy(x:1,y:-1);mask.translateBy(x:0,y:CGFloat(h));mask.scaleBy(x:1,y:-1)
        let image=try ImagePipeline.compositeRegion(page,directory:directory,rect:self.region)
        UIGraphicsPushContext(context);UIImage(cgImage:image).draw(in:CGRect(x:0,y:0,width:w,height:h));UIGraphicsPopContext()
    }
    func move(to point:CGPoint){
        let destination=CGPoint(x:point.x-region.minX,y:point.y-region.minY),dx=destination.x-previous.x,dy=destination.y-previous.y,steps=max(1,min(128,Int(ceil(hypot(dx,dy)/max(1,width/5)))))
        for _ in 0..<steps{
            let next=CGPoint(x:previous.x+dx/CGFloat(steps),y:previous.y+dy/CGFloat(steps)),source=CGRect(x:previous.x-width/2,y:previous.y-width/2,width:width,height:width).integral.intersection(CGRect(origin:.zero,size:region.size))
            if let image=context.makeImage()?.cropping(to:source){let target=source.offsetBy(dx:next.x-previous.x,dy:next.y-previous.y)
                UIGraphicsPushContext(context);context.saveGState();context.addEllipse(in:CGRect(x:next.x-width/2,y:next.y-width/2,width:width,height:width));context.clip();UIImage(cgImage:image).draw(in:target,blendMode:.normal,alpha:strength);context.restoreGState();UIGraphicsPopContext()
                mask.setFillColor(UIColor.white.cgColor);mask.fillEllipse(in:CGRect(x:next.x-width/2,y:next.y-width/2,width:width,height:width))
            };previous=next
        }
    }
    func image(masked:Bool=false)->UIImage?{guard let cg=context.makeImage() else{return nil};let image=UIImage(cgImage:cg);guard masked else{return image};let format=UIGraphicsImageRendererFormat();format.scale=1;return UIGraphicsImageRenderer(size:region.size,format:format).image{out in image.draw(at:.zero);if let cg=mask.makeImage(){UIImage(cgImage:cg).draw(at:.zero,blendMode:.destinationIn,alpha:1)}}}
    @MainActor func commit(to model:EditorModel)throws{guard let data=image(masked:true)?.pngData() else{throw ImageFailure.message("تعذر حفظ ضربة الطمس")};let name=UUID().uuidString+".png";try data.write(to:model.directory.appendingPathComponent(name),options:.atomic);model.checkpoint();var layer=EditorLayer(kind:.image,name:"طمس");layer.imagePath=name;layer.frame=Box(x:region.minX,y:region.minY,width:region.width,height:region.height);model.page.layers.append(layer);model.selected=layer.id;model.save()}
}
