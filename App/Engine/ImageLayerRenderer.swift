import UIKit
import CoreImage

enum ImageLayerRenderer {
    private static let contexts=NSCache<ImageContextKey,CIContext>()
    private static func context(_ space:CGColorSpace)->CIContext {
        let key=ImageContextKey(space)
        if let hit=contexts.object(forKey:key){return hit}
        let value=CIContext(options:[.cacheIntermediates:false,.workingColorSpace:space,.outputColorSpace:space])
        contexts.countLimit=3;contexts.setObject(value,forKey:key);return value
    }
    private static let cache=NSCache<ImageRasterKey,CGImage>()
    private static let errorKey="cookies.image.render-error"
    static func clear(){cache.removeAllObjects();contexts.removeAllObjects();ImageAssetPixels.clear()}
    static func takeError()->String?{let value=Thread.current.threadDictionary[errorKey] as? String;Thread.current.threadDictionary.removeObject(forKey:errorKey);return value}
    static func draw(_ layer:EditorLayer,rect:CGRect,in c:CGContext,directory:URL){
        guard rect.width>0,rect.height>0 else{return}
        if layer.isWorkingImage != true && (layer.imageEffects ?? []).isEmpty{ImagePipeline.asset(directory.appendingPathComponent(layer.imagePath))?.draw(in:rect);return}
        do {
            let provider=try ImageAssetPixels.provider(layer,directory:directory)
            let local=c.boundingBoxOfClipPath.intersection(rect)
            guard !local.isNull,!local.isEmpty else{return}
            let sx=CGFloat(provider.width)/rect.width,sy=CGFloat(provider.height)/rect.height
            let sourceRect=CGRect(x:(local.minX-rect.minX)*sx,y:CGFloat(provider.height)-(local.maxY-rect.minY)*sy,width:local.width*sx,height:local.height*sy).integral.intersection(CGRect(x:0,y:0,width:provider.width,height:provider.height))
            let transform=c.ctm,requested=min(1,max(hypot(transform.a,transform.b)/sx,hypot(transform.c,transform.d)/sy))
            let budget:CGFloat=RenderBudget.isPreview ? RenderBudget.previewPixels:4_194_304
            let scale=max(0.002,min(requested,sqrt(budget/max(1,sourceRect.width*sourceRect.height))))
            let key=ImageRasterKey(layer,directory:directory,sourceRect:sourceRect,scale:scale)
            let image:CGImage
            if let hit=cache.object(forKey:key){image=hit}else{
                guard ImageEffectGraph.kernelsAvailable else{throw ImageFailure.message("تعذر تشغيل محرك تأثيرات الصورة")}
                let graph=ImageEffectGraph.apply(provider.image,effects:layer.effectiveImageEffects,size:CGSize(width:provider.width,height:provider.height))
                let reduction=CGAffineTransform(scaleX:scale,y:scale)
                guard let rendered=context(provider.colorSpace).createCGImage(graph.transformed(by:reduction),from:sourceRect.applying(reduction),format:.RGBA8,colorSpace:provider.colorSpace),provider.error==nil else{throw ImageFailure.message(provider.error ?? "تعذر تجهيز تأثير الصورة")}
                image=rendered;cache.totalCostLimit=RenderBudget.textCacheBytes/2;cache.setObject(image,forKey:key,cost:image.width*image.height*4)
            }
            let destination=CGRect(x:rect.minX+sourceRect.minX/sx,y:rect.minY+(CGFloat(provider.height)-sourceRect.maxY)/sy,width:sourceRect.width/sx,height:sourceRect.height/sy)
            c.saveGState();c.interpolationQuality = .high;UIImage(cgImage:image).draw(in:destination);c.restoreGState()
        }catch{Thread.current.threadDictionary[errorKey]=error.localizedDescription}
    }
}
private final class ImageRasterKey:NSObject {
    let layer:EditorLayer,source:String,area:CGRect,scale:CGFloat,tier:Int
    private let value:Int
    init(_ original:EditorLayer,directory:URL,sourceRect:CGRect,scale:CGFloat){
        var canonical=original;canonical.id=UUID(uuidString:"00000000-0000-0000-0000-000000000000")!;canonical.name="";canonical.frame.x=0;canonical.frame.y=0;canonical.rotation=0;canonical.scaleX=1;canonical.scaleY=1;canonical.opacity=1;canonical.isVisible=true;canonical.isLocked=false;canonical.blend = .normal
        layer=canonical;source=directory.path;area=sourceRect;self.scale=scale;tier=RenderBudget.isPreview ? (RenderBudget.isInteractive ? 2:1):0
        var h=Hasher();h.combine(canonical);h.combine(directory.path);h.combine(sourceRect.minX);h.combine(sourceRect.minY);h.combine(sourceRect.width);h.combine(sourceRect.height);h.combine(scale);h.combine(tier);value=h.finalize()
    }
    override var hash:Int{value}
    override func isEqual(_ object:Any?)->Bool{guard let other=object as? ImageRasterKey else{return false};return layer==other.layer && source==other.source && area==other.area && scale==other.scale && tier==other.tier}
}

private final class ImageContextKey:NSObject {
    let space:CGColorSpace
    init(_ space:CGColorSpace){self.space=space}
    override var hash:Int{Int(bitPattern:CFHash(space))}
    override func isEqual(_ object:Any?)->Bool{guard let other=object as? ImageContextKey else{return false};return CFEqual(space,other.space)}
}
