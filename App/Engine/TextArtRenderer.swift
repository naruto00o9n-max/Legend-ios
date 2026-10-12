import UIKit

/// Shape/color text once, then compose cached channel images. A glitch with many
/// bands never rebuilds glyphs or creates a transparency layer for each band.
enum TextArtRenderer {
    final class Images {let original:UIImage;let channels:[UIImage];let frame:CGRect
        init(original:UIImage,channels:[UIImage],frame:CGRect){self.original=original;self.channels=channels;self.frame=frame}
    }
    static let cache=NSCache<TextRenderKey,Images>()
    static var cacheBuilds=0
    private static let countLock=NSLock()
    static func bandOffset(_ index:Int,seed:UInt32,strength:Double)->Double {
        var bits=UInt32(truncatingIfNeeded:index) &+ seed &* 0x9e3779b9
        bits=(bits ^ (bits >> 16)) &* 0x85ebca6b;bits=(bits ^ (bits >> 13)) &* 0xc2b2ae35;bits ^= bits >> 16
        return (Double(bits % 2001)/1000-1)*max(0,strength)
    }
    static func draw(_ layer:EditorLayer,rect:CGRect,in c:CGContext,directory:URL)->Bool {
        guard layer.style.effectType == .chromatic || layer.style.effectType == .glitch || layer.style.effectType == .error else{return false}
        let art=layer.style.art ?? TextArtSettings()
        var base=layer;base.style.effectType = .none;base.style.art=nil;base.style.styleEffect=nil;base.style.effectValue=0
        let area=TextVisualBounds.rect(base)
        guard area.width.isFinite,area.height.isFinite,area.width>0,area.height>0 else{return true}
        let requested=max(1,hypot(c.ctm.a,c.ctm.b),hypot(c.ctm.c,c.ctm.d))
        let pixels=RenderBudget.isPreview ? RenderBudget.previewPixels:8_388_608
        let resolution=max(0.125,min(8,pow(2,ceil(log2(requested))),sqrt(pixels/max(1,area.width*area.height))))
        var keyLayer=base;keyLayer.style.effectType=layer.style.effectType == .error ? .error:.chromatic
        let key=TextRenderKey(keyLayer,directory:directory,resolution:resolution,size:area.size)
        let images:Images
        if let cached=cache.object(forKey:key){images=cached}else{
            let format=UIGraphicsImageRendererFormat();format.scale=resolution;format.opaque=false;format.preferredRange = .standard
            func image(_ value:EditorLayer)->UIImage{var canonical=value;canonical.frame.x=0;canonical.frame.y=0;canonical.scaleX=1;canonical.scaleY=1;canonical.rotation=0;canonical.shearX=nil;canonical.opacity=1
                return UIGraphicsImageRenderer(size:area.size,format:format).image{out in out.cgContext.translateBy(x:-area.minX,y:-area.minY);LayerRenderer.drawText(canonical,rect:rect,context:out.cgContext,directory:directory)}
            }
            let original=image(base)
            var foreground=base;foreground.style.backgroundAlpha=0;foreground.style.shadowAlpha=0;foreground.style.shadowRadius=0;foreground.style.shadowGradient=[]
            let alpha=image(foreground)
            let colors=layer.style.effectType == .error ? [UIColor(hex:layer.style.effectColor),UIColor(hex:layer.style.strokeColor),UIColor.clear]:[UIColor.red,UIColor.green,UIColor.blue]
            let channels=colors.map{color in UIGraphicsImageRenderer(size:area.size,format:format).image{out in alpha.draw(at:.zero);out.cgContext.setBlendMode(.sourceIn);out.cgContext.setFillColor(color.cgColor);out.cgContext.fill(CGRect(origin:.zero,size:area.size))}}
            images=Images(original:original,channels:channels,frame:area)
            cache.totalCostLimit=RenderBudget.textCacheBytes;cache.setObject(images,forKey:key,cost:(original.cgImage.map{$0.bytesPerRow*$0.height} ?? 0)*4)
            countLock.lock();cacheBuilds+=1;countLock.unlock()
        }
        let orders=[[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]],order=orders[max(0,min(5,art.order))]
        func channels(distance:Double,angle:Double,shift:Double=0){let theta=angle*Double.pi/180
            for position in 0..<3{let d=Double(position-1)*max(0,distance);images.channels[order[position]].draw(in:images.frame.offsetBy(dx:shift+cos(theta)*d,dy:sin(theta)*d))}
            images.original.draw(in:images.frame.offsetBy(dx:shift,dy:0))
        }
        if layer.style.effectType == .error{images.channels[0].draw(in:images.frame.offsetBy(dx:layer.style.effectValue,dy:0));images.channels[1].draw(in:images.frame.offsetBy(dx:-layer.style.effectValue,dy:0));images.original.draw(in:images.frame)}else if layer.style.effectType == .chromatic{channels(distance:art.distance,angle:art.angle)}else{
            let height=max(2,min(420,art.bandHeight)),clip=c.boundingBoxOfClipPath
            let first=max(Int(floor(area.minY/height)),Int(floor(clip.minY/height))),last=min(Int(ceil(area.maxY/height)),Int(ceil(clip.maxY/height)))
            if first<last{for band in first..<last{let slice=CGRect(x:area.minX-CGFloat(art.strength+art.colorShift),y:Double(band)*height,width:area.width+CGFloat(2*(art.strength+art.colorShift)),height:height);guard slice.intersects(clip) else{continue};c.saveGState();c.clip(to:slice);channels(distance:art.colorShift,angle:0,shift:bandOffset(band,seed:art.seed,strength:art.strength));c.restoreGState()}}
        }
        return true
    }
}
