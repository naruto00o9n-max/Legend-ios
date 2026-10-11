import UIKit

/// Compose existing glyph rendering at document coordinates. Geometry remains
/// editable; sliders reuse the unchanged fill/outline raster and never flatten a layer.
enum TextArtRenderer {
    static func bandOffset(_ index:Int,seed:UInt32,strength:Double)->Double {
        var bits=UInt32(truncatingIfNeeded:index) &+ seed &* 0x9e3779b9
        bits=(bits ^ (bits >> 16)) &* 0x85ebca6b;bits=(bits ^ (bits >> 13)) &* 0xc2b2ae35;bits ^= bits >> 16
        return (Double(bits % 2001)/1000-1)*max(0,strength)
    }
    static func draw(_ layer:EditorLayer,rect:CGRect,in c:CGContext,directory:URL)->Bool {
        guard layer.style.effectType == .chromatic || layer.style.effectType == .glitch else{return false}
        let art=layer.style.art ?? TextArtSettings()
        var base=layer;base.style.effectType = .none;base.style.art=nil
        let area=TextVisualBounds.rect(base)
        let orders=[[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]],order=orders[max(0,min(5,art.order))]
        let colors=[UIColor.red,UIColor.green,UIColor.blue]
        func render(_ offset:CGPoint,_ color:UIColor?=nil){
            c.saveGState();c.translateBy(x:offset.x,y:offset.y)
            if let color{
                var copy=base;copy.style.backgroundAlpha=0;copy.style.shadowAlpha=0;copy.style.shadowRadius=0;copy.style.shadowGradient=[]
                c.beginTransparencyLayer(auxiliaryInfo:nil);LayerRenderer.drawText(copy,rect:rect,context:c,directory:directory)
                c.setBlendMode(.sourceIn);c.setFillColor(color.cgColor);c.fill(area);c.endTransparencyLayer()
            }else{LayerRenderer.drawText(base,rect:rect,context:c,directory:directory)}
            c.restoreGState()
        }
        func channels(distance:Double,angle:Double,shift:Double=0){let theta=angle*Double.pi/180
            for position in 0..<3{let d=Double(position-1)*max(0,distance);render(CGPoint(x:shift+cos(theta)*d,y:sin(theta)*d),colors[order[position]])}
            render(CGPoint(x:shift,y:0))
        }
        if layer.style.effectType == .chromatic{channels(distance:art.distance,angle:art.angle)}else{
            let height=max(2,min(420,art.bandHeight)),start=Int(floor(area.minY/height)),end=Int(ceil(area.maxY/height))
            // Process only visible bands, including displaced exterior pixels.
            let clip=c.boundingBoxOfClipPath
            for band in start..<end{let slice=CGRect(x:area.minX-CGFloat(art.strength+art.colorShift),y:Double(band)*height,width:area.width+CGFloat(2*(art.strength+art.colorShift)),height:height);guard slice.intersects(clip) else{continue};c.saveGState();c.clip(to:slice);channels(distance:art.colorShift,angle:0,shift:bandOffset(band,seed:art.seed,strength:art.strength));c.restoreGState()}
        }
        return true
    }
}
