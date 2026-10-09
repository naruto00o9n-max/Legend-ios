import UIKit
import CoreImage

// Rasterize a text layer independently of the full image; keep source pixels on disk.
enum TextRaster {
    final class Raster {let image:UIImage;let frame:CGRect;init(_ image:UIImage,_ frame:CGRect){self.image=image;self.frame=frame}}
    static let cache=NSCache<NSString,Raster>()
    static let context=CIContext(options:[.cacheIntermediates:false])
    static func draw(_ layer:EditorLayer,rect:CGRect,in c:CGContext,directory:URL)->Bool {
        let s=layer.style
        let advanced = (s.fadeAmount ?? 0)>0 || !s.textGradient.isEmpty || !s.strokeGradient.isEmpty || !s.texturePath.isEmpty || !s.perspectivePoints.isEmpty || s.isMeshMode || s.rotationX != 0 || s.rotationY != 0 || s.effectType == .blur || s.effectType == .fade
        guard advanced,rect.width*rect.height<4_194_304 else{return false}
        var glyphLayer=layer;glyphLayer.frame.x=0;glyphLayer.frame.y=0;glyphLayer.rotation=0;glyphLayer.scaleX=1;glyphLayer.scaleY=1;glyphLayer.opacity=1;glyphLayer.isLocked=false;glyphLayer.isVisible=true;let key=(directory.path+String(data:(try? JSONEncoder().encode(glyphLayer)) ?? Data(),encoding:.utf8)!) as NSString
        let pad=max(8,CGFloat(s.strokeWidth+s.shadowRadius*3+s.effectValue*3))
        let size=CGSize(width:ceil(rect.width+pad*2),height:ceil(rect.height+pad*2))
        let raster:Raster
        if let cached=cache.object(forKey:key){raster=cached}else{
            var outputFrame=CGRect(x:-pad,y:-pad,width:size.width,height:size.height)
            let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=false
            let glyph=UIGraphicsImageRenderer(size:size,format:format).image{r in
                let a=NSMutableAttributedString(attributedString:LayerRenderer.attributed(layer,color:.white))
                a.draw(with:rect.offsetBy(dx:pad,dy:pad),options:[.usesLineFragmentOrigin,.usesFontLeading],context:nil)
            }
            var result=UIGraphicsImageRenderer(size:size,format:format).image{r in
                let ctx=r.cgContext
                GradientPaint.draw(colors:s.textGradient.isEmpty ? [s.color,s.color]:s.textGradient,stops:s.textGradientStops,angle:s.textGradientAngle,type:s.textGradientType,rect:CGRect(origin:.zero,size:size),in:ctx)
                if !s.texturePath.isEmpty,let texture=ImagePipeline.asset(directory.appendingPathComponent(s.texturePath)){
                    ctx.saveGState();ctx.translateBy(x:size.width/2+CGFloat(s.textureTranslationX),y:size.height/2+CGFloat(s.textureTranslationY));ctx.rotate(by:CGFloat(s.textureRotation)*CGFloat.pi/180);ctx.scaleBy(x:CGFloat(s.textureScaleX),y:CGFloat(s.textureScaleY));texture.drawAsPattern(in:CGRect(x:-size.width*10,y:-size.height*10,width:size.width*20,height:size.height*20));ctx.restoreGState()
                }
                // UIImage.draw(at:) uses normal blending by default and overrides
                // the CGContext blend mode. Pass the mask blend explicitly: a
                // gradient must retain glyph alpha, never the enclosing rectangle.
                glyph.draw(at:.zero,blendMode:.destinationIn,alpha:CGFloat(s.innerOpacity ?? 1))
                if let amount=s.fadeAmount,amount>0{
                    let alpha=min(1,max(0,amount)),cg=[UIColor.white.cgColor,UIColor.white.withAlphaComponent(CGFloat(1-alpha)).cgColor]
                    let fade=UIGraphicsImageRenderer(size:size,format:format).image{out in if let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:cg as CFArray,locations:[0,1]){let angle=(s.fadeAngle ?? 0)*Double.pi/180,dx=CGFloat(cos(angle))*size.width/2,dy=CGFloat(sin(angle))*size.height/2;out.cgContext.drawLinearGradient(gradient,start:CGPoint(x:size.width/2-dx,y:size.height/2-dy),end:CGPoint(x:size.width/2+dx,y:size.height/2+dy),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])}};fade.draw(at:.zero,blendMode:.destinationIn,alpha:1)
                }
                ctx.setBlendMode(.normal)
                if s.strokeWidth>0{
                    let outline=UIGraphicsImageRenderer(size:size,format:format).image{output in
                        let a=NSMutableAttributedString(attributedString:LayerRenderer.attributed(layer,color:.clear));a.addAttributes([.strokeColor:UIColor.white,.strokeWidth:s.strokeWidth/max(1,s.fontSize)*100],range:NSRange(location:0,length:a.length));a.draw(with:rect.offsetBy(dx:pad,dy:pad),options:[.usesLineFragmentOrigin,.usesFontLeading],context:nil)
                    }
                    let colored=UIGraphicsImageRenderer(size:size,format:format).image{output in
                        GradientPaint.draw(colors:s.strokeGradient.isEmpty ? [s.strokeColor,s.strokeColor]:s.strokeGradient,stops:s.strokeGradientStops,angle:s.strokeGradientAngle,type:s.strokeGradientType,rect:CGRect(origin:.zero,size:size),in:output.cgContext)
                        outline.draw(at:.zero,blendMode:.destinationIn,alpha:1)
                    };colored.draw(at:.zero)
                }
            }
            if let input=CIImage(image:result){
                var processed=input
                if s.effectType == .blur{processed=input.applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:max(0,s.effectValue)])}
                if s.effectType == .fade{processed=input.applyingFilter("CIFadeTransition",parameters:[kCIInputTargetImageKey:CIImage(color:.clear).cropped(to:input.extent),kCIInputTimeKey:min(1,max(0,s.effectValue/100))])}
                var corners=s.perspectivePoints
                if corners.count != 4 && (s.rotationX != 0 || s.rotationY != 0){let x=sin(s.rotationY*Double.pi/180)*0.25,y=sin(s.rotationX*Double.pi/180)*0.25;corners=[Point(x:max(0,x),y:max(0,y)),Point(x:min(1,1+x),y:max(0,-y)),Point(x:min(1,1-x),y:min(1,1+y)),Point(x:max(0,-x),y:min(1,1-y))]}
                if corners.count==4{func vector(_ p:Point)->CIVector{CIVector(x:pad+CGFloat(p.x)*rect.width,y:size.height-pad-CGFloat(p.y)*rect.height)};processed=processed.applyingFilter("CIPerspectiveTransformWithExtent",parameters:["inputExtent":CIVector(cgRect:CGRect(x:pad,y:pad,width:rect.width,height:rect.height)),"inputTopLeft":vector(corners[0]),"inputTopRight":vector(corners[1]),"inputBottomRight":vector(corners[2]),"inputBottomLeft":vector(corners[3])])}
                let extent=processed.extent.integral
                if !extent.isInfinite,!extent.isNull,extent.width*extent.height<16_777_216,let cg=context.createCGImage(processed,from:extent){result=UIImage(cgImage:cg);outputFrame=CGRect(x:extent.minX-pad,y:size.height-extent.maxY-pad,width:extent.width,height:extent.height)}
            }
            raster=Raster(result,outputFrame);cache.totalCostLimit=64*1024*1024;cache.setObject(raster,forKey:key,cost:Int(outputFrame.width*outputFrame.height)*4)
        }
        c.saveGState()
        if s.shadowRadius>0 || s.effectType == .neon || s.effectType == .shadow{c.setShadow(offset:CGSize(width:s.shadowDx,height:s.shadowDy),blur:CGFloat(s.effectType == .neon ? s.effectValue:s.shadowRadius),color:UIColor(hex:s.effectType == .neon ? s.effectColor:s.shadowColor,alpha:CGFloat(s.shadowAlpha)/255).cgColor)}
        if s.isMeshMode,s.meshPoints.count==(s.meshRows+1)*(s.meshCols+1){drawMesh(raster.image,rect:CGRect(x:-pad,y:-pad,width:size.width,height:size.height),style:s,in:c)}else{raster.image.draw(in:raster.frame)}
        c.restoreGState();return true
    }
    static func drawMesh(_ image:UIImage,rect:CGRect,style:TextStyle,in c:CGContext){
        let rows=max(1,style.meshRows),cols=max(1,style.meshCols)
        func original(_ col:Int,_ row:Int)->CGPoint{CGPoint(x:rect.minX+rect.width*CGFloat(col)/CGFloat(cols),y:rect.minY+rect.height*CGFloat(row)/CGFloat(rows))}
        func target(_ col:Int,_ row:Int)->CGPoint{let p=style.meshPoints[row*(cols+1)+col];return CGPoint(x:rect.minX+rect.width*CGFloat(p.x),y:rect.minY+rect.height*CGFloat(p.y))}
        for row in 0..<rows{for col in 0..<cols{for triangle in [[(col,row),(col+1,row),(col,row+1)],[(col+1,row+1),(col,row+1),(col+1,row)]]{
            let a=triangle.map{original($0.0,$0.1)},b=triangle.map{target($0.0,$0.1)}
            let source=CGAffineTransform(a:a[1].x-a[0].x,b:a[1].y-a[0].y,c:a[2].x-a[0].x,d:a[2].y-a[0].y,tx:a[0].x,ty:a[0].y)
            let dest=CGAffineTransform(a:b[1].x-b[0].x,b:b[1].y-b[0].y,c:b[2].x-b[0].x,d:b[2].y-b[0].y,tx:b[0].x,ty:b[0].y)
            c.saveGState();let path=UIBezierPath();path.move(to:b[0]);path.addLine(to:b[1]);path.addLine(to:b[2]);path.close();path.addClip();c.concatenate(source.inverted().concatenating(dest));image.draw(in:rect);c.restoreGState()
        }}}
    }
}
