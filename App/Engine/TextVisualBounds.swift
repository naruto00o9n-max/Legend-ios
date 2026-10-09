import UIKit

enum TextVisualBounds {
    static func rect(_ layer:EditorLayer)->CGRect {
        let style=layer.style,base=LayerRenderer.bounds(layer)
        let pad=max(16,max(style.strokeWidth,(style.extraStrokes ?? []).map(\.width).max() ?? 0)+style.shadowRadius*3+max(abs(style.shadowDx),abs(style.shadowDy))+style.effectValue*3+Double(style.threeDDepth)+max(style.backgroundPaddingX,style.backgroundPaddingY))
        var result=base.insetBy(dx:-pad,dy:-pad)
        if style.isMeshMode {
            for x in [-pad/Double(base.width),1+pad/Double(base.width)]{for y in [-pad/Double(base.height),1+pad/Double(base.height)]{let p=MeshGeometry.target(x:x,y:y,style:style);if p.x.isFinite,p.y.isFinite{result=result.union(CGRect(x:p.x*Double(base.width),y:p.y*Double(base.height),width:1,height:1))}}}
            for p in style.meshPoints{result=result.union(CGRect(x:p.x*Double(base.width)-pad,y:p.y*Double(base.height)-pad,width:pad*2,height:pad*2))}
        }else if let points=PerspectiveGeometry.extended(PerspectiveGeometry.corners(style),width:Double(base.width),height:Double(base.height),padding:pad){
            for p in points where p.x.isFinite && p.y.isFinite{result=result.union(CGRect(x:p.x*Double(base.width),y:p.y*Double(base.height),width:1,height:1))}
        }
        return result.integral
    }
}
