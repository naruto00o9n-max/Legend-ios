import UIKit

enum TextVisualBounds {
    static func padding(_ style:TextStyle,minimum:Double=16)->Double {
        let extraWidth:Double=(style.extraStrokes ?? []).map(\.width).max() ?? 0
        let outline:Double=max(style.strokeWidth,extraWidth)
        let offset:Double=max(abs(style.shadowDx),abs(style.shadowDy))
        let shadow:Double=style.shadowRadius*3+offset
        let effect:Double=style.effectValue*3+Double(style.threeDDepth)
        let background:Double=max(style.backgroundPaddingX,style.backgroundPaddingY)
        return max(minimum,outline+shadow+effect+background)
    }
    static func rect(_ layer:EditorLayer)->CGRect {
        let style=layer.style,base=LayerRenderer.bounds(layer)
        let pad:Double=padding(style),width:Double=Double(base.width),height:Double=Double(base.height)
        var result: CGRect=base.insetBy(dx:-CGFloat(pad),dy:-CGFloat(pad))
        guard width>0,height>0 else{return result.integral}
        if style.isMeshMode,MeshGeometry.valid(style) {
            let xs:[Double]=[-pad/width,1+pad/width]
            let ys:[Double]=[-pad/height,1+pad/height]
            for x in xs{for y in ys{
                let p=MeshGeometry.target(x:x,y:y,style:style)
                if p.x.isFinite,p.y.isFinite{result=result.union(CGRect(x:p.x*width,y:p.y*height,width:1,height:1))}
            }}
            for p in style.meshPoints where p.x.isFinite && p.y.isFinite{
                result=result.union(CGRect(x:p.x*width-pad,y:p.y*height-pad,width:pad*2,height:pad*2))
            }
        }else if let points=PerspectiveGeometry.extended(PerspectiveGeometry.corners(style),width:width,height:height,padding:pad){
            for p in points where p.x.isFinite && p.y.isFinite{result=result.union(CGRect(x:p.x*width,y:p.y*height,width:1,height:1))}
        }
        return result.integral
    }
}
