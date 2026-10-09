import UIKit

enum BrushRenderer {
    static func path(_ s:Stroke)->UIBezierPath {
        let path=UIBezierPath();guard let first=s.points.first else{return path}
        if let shape=s.shape,shape != "free",let last=s.points.last{
            let rect=CGRect(x:min(first.x,last.x),y:min(first.y,last.y),width:abs(last.x-first.x),height:abs(last.y-first.y))
            if shape=="rectangle"{path.append(UIBezierPath(rect:rect))}else if shape=="ellipse"{path.append(UIBezierPath(ovalIn:rect))}else{path.move(to:first.cg);path.addLine(to:last.cg)}
        }else{path.move(to:first.cg);for point in s.points.dropFirst(){path.addLine(to:point.cg)}}
        path.lineWidth=CGFloat(s.width);path.lineCapStyle=s.brush=="marker" ? .square:.round;path.lineJoinStyle = .round
        return path
    }
    static func draw(_ s:Stroke,in ctx:CGContext,directory:URL){
        guard let first=s.points.first else{return};ctx.saveGState();defer{ctx.restoreGState()}
        let path=path(s),alpha=min(1,max(0,s.opacity ?? 1))*(s.brush=="water" ? 0.25:s.brush=="marker" ? 0.55:1)
        ctx.setAlpha(CGFloat(alpha));if s.erase{ctx.setBlendMode(.clear)}
        UIColor(hex:s.color).setStroke();UIColor(hex:s.color).setFill()
        if s.brush=="neon"{ctx.setShadow(offset:.zero,blur:CGFloat(s.width),color:UIColor(hex:s.color).cgColor)}
        if s.brush=="soft"{
            // Concentric alpha bands produce a feathered edge, including single taps.
            for band in stride(from:12,through:1,by:-1){ctx.saveGState();ctx.setAlpha(CGFloat(alpha)*0.065);let width=CGFloat(s.width)*CGFloat(band)/12;path.lineWidth=width;if s.points.count==1{ctx.fillEllipse(in:CGRect(x:first.x-Double(width)/2,y:first.y-Double(width)/2,width:Double(width),height:Double(width)))}else{path.stroke()};ctx.restoreGState()};return
        }
        if s.brush=="texture",let name=s.texturePath,let image=ImagePipeline.asset(directory.appendingPathComponent(name)){
            let cg=path.cgPath.copy(strokingWithWidth:CGFloat(s.width),lineCap:.round,lineJoin:.round,miterLimit:10);ctx.addPath(cg);ctx.clip();image.drawAsPattern(in:path.bounds.insetBy(dx:-CGFloat(s.width),dy:-CGFloat(s.width)));return
        }
        if s.filled==true,s.shape=="rectangle" || s.filled==true && s.shape=="ellipse"{path.fill()}
        else if s.points.count==1{ctx.fillEllipse(in:CGRect(x:first.x-s.width/2,y:first.y-s.width/2,width:s.width,height:s.width))}else{path.stroke()}
    }
}
