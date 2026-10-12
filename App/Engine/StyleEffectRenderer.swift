import UIKit
import CoreImage

/// Glyph-local, nondestructive style filters. Inputs and intermediate extents
/// stay bounded to the text raster; source images are never modified.
enum StyleEffectRenderer {
    // Nine neighbouring Voronoi sites, unrolled once when the kernel is built.
    // No per-cell UIKit loop or chapter-sized procedural texture is allocated.
    private static let glassKernel:CIColorKernel? = {
        var source="kernel vec4 cookiesGlass(vec2 origin, float cell, float border, float seed, float saturation, vec4 edgeColor) { vec2 p=(destCoord()-origin)/cell; vec2 tile=floor(p); vec2 f=fract(p); float nearest=100.0; float second=100.0; vec2 winner=tile;"
        for y in -1...1{for x in -1...1{source+="{ vec2 n=tile+vec2(\(x).0,\(y).0); vec2 h=fract(sin(vec2(dot(n,vec2(127.1,311.7)),dot(n,vec2(269.5,183.3)))+seed)*43758.5453); float d=length(vec2(\(x).0,\(y).0)+vec2(0.15)+h*0.7-f); if(d<nearest){second=nearest;nearest=d;winner=n;}else if(d<second){second=d;} }"}}
        source+="float hue=fract(sin(dot(winner,vec2(127.1,311.7))+seed)*43758.5453); vec3 q=abs(fract(vec3(hue)+vec3(0.0,0.6666667,0.3333333))*6.0-3.0); vec3 rgb=0.9*mix(vec3(1.0),clamp(q-1.0,0.0,1.0),saturation); return (second-nearest)*cell<border ? edgeColor:vec4(rgb,1.0); }"
        return CIColorKernel(source:source)
    }()

    static var glassKernelAvailable:Bool{glassKernel != nil}
    static func apply(_ input:CIImage,mask:CIImage,effect:TextEffect,settings:StyleEffectSettings,scale:CGFloat)->CIImage {
        guard settings.opacity>0 else{return input}
        let extent=input.extent
        let radius=max(0,min(80,settings.radius))*Double(scale),softness=max(0,min(60,settings.softness))*Double(scale)
        let opacity=max(0,min(1,settings.opacity)),theta=settings.angle*Double.pi/180
        let depth=max(0,min(80,settings.depth))*Double(scale),dx=cos(theta)*depth,dy=sin(theta)*depth
        func bounded(_ image:CIImage)->CIImage{image.cropped(to:extent)}
        func tint(_ image:CIImage,_ hex:String,_ alpha:Double=1)->CIImage {
            let color=UIColor(hex:hex);var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0;color.getRed(&r,green:&g,blue:&b,alpha:&a)
            return bounded(image.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:0,y:0,z:0,w:r),"inputGVector":CIVector(x:0,y:0,z:0,w:g),"inputBVector":CIVector(x:0,y:0,z:0,w:b),"inputAVector":CIVector(x:0,y:0,z:0,w:CGFloat(alpha)),"inputBiasVector":CIVector(x:0,y:0,z:0,w:0)]))
        }
        func blur(_ image:CIImage,_ amount:Double)->CIImage{bounded(image.applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:amount]))}
        func expand(_ image:CIImage,_ amount:Double)->CIImage{bounded(image.applyingFilter("CIMorphologyMaximum",parameters:[kCIInputRadiusKey:amount]))}
        func erode(_ image:CIImage,_ amount:Double)->CIImage{bounded(image.applyingFilter("CIMorphologyMinimum",parameters:[kCIInputRadiusKey:amount]))}
        func inside(_ image:CIImage)->CIImage{bounded(image.applyingFilter("CISourceInCompositing",parameters:[kCIInputBackgroundImageKey:mask]))}
        func subtract(_ a:CIImage,_ b:CIImage)->CIImage{bounded(a.applyingFilter("CISourceOutCompositing",parameters:[kCIInputBackgroundImageKey:b]))}
        func over(_ a:CIImage,_ b:CIImage)->CIImage{bounded(a.composited(over:b))}
        func move(_ a:CIImage,_ x:Double,_ y:Double)->CIImage{bounded(a.transformed(by:CGAffineTransform(translationX:x,y:y)))}
        let colored=tint(mask,settings.color,opacity)
        switch effect {
        case .strokeOuter:
            return over(input,subtract(tint(expand(mask,radius),settings.color,opacity),mask))
        case .strokeBoth:
            return over(tint(subtract(mask,erode(mask,radius)),settings.color,opacity),over(input,tint(expand(mask,radius),settings.color,opacity)))
        case .wetEdge:
            let edge=subtract(mask,erode(mask,max(0.5,radius)));return over(tint(blur(edge,softness),settings.color,opacity),input)
        case .innerGlow:
            let edge=subtract(mask,erode(mask,radius));return over(inside(tint(blur(edge,softness),settings.color,opacity)),input)
        case .outerGlow:
            return over(input,subtract(blur(tint(expand(mask,radius),settings.color,opacity),softness),mask))
        case .dropShadow:
            return over(input,move(blur(colored,softness),dx,dy))
        case .satin:
            let left=blur(move(mask,dx,dy),softness),right=blur(move(mask,-dx,-dy),softness)
            let difference=left.applyingFilter("CIDifferenceBlendMode",parameters:[kCIInputBackgroundImageKey:right]);return over(inside(tint(difference,settings.color,opacity)),input)
        case .bevelInner,.bevelOuter,.emboss,.relief,.waterdrop:
            let a=max(0.5,radius),normal=erode(mask,a),expanded=expand(mask,a)
            let field=effect == .bevelOuter ? subtract(expanded,mask):effect == .relief ? expanded:mask
            let highlight=tint(subtract(field,move(field,cos(theta)*a,sin(theta)*a)),settings.highlightColor,opacity)
            let shade=tint(subtract(field,move(field,-cos(theta)*a,-sin(theta)*a)),settings.color,opacity)
            var shading=over(blur(highlight,softness),blur(shade,softness))
            if effect == .bevelInner{shading=inside(shading)}
            if effect == .bevelOuter{return over(input,shading)}
            if effect == .emboss{let flat=tint(mask,settings.baseColor);return over(inside(shading),flat)}
            if effect == .relief{return over(shading,over(input,tint(subtract(expanded,normal),settings.baseColor,opacity)))}
            if effect == .waterdrop{
                let wide=blur(subtract(mask,erode(mask,a*2)),max(0.5,softness+a*0.3));shading=over(inside(tint(wide,settings.highlightColor,opacity*0.7)),inside(shading))
                return over(shading,over(input,move(blur(tint(mask,settings.color,opacity*0.5),softness),dx,dy)))
            }
            return over(shading,input)
        case .extrude:
            var result=CIImage(color:.clear).cropped(to:extent)
            let count=min(64,max(1,Int(ceil(depth))))
            for i in stride(from:count,through:1,by:-1){let f=Double(i)/Double(count);result=over(move(colored,dx*f,dy*f),result)}
            return over(input,result)
        case .godRays:
            var rays=CIImage(color:.clear).cropped(to:extent)
            let count=max(4,min(48,settings.density))
            for i in 1...count{let fraction=Double(i)/Double(count);let ray=tint(move(mask,dx*fraction,dy*fraction),settings.color,opacity*(1-fraction)/Double(count)*3);rays=over(ray,rays)}
            return over(input,blur(rays,softness))
        case .stainedGlass:
            let cell=max(4,min(160,settings.cellSize))*Double(scale)
            let color=CIColor(color:UIColor(hex:settings.color)),edge=CIVector(x:color.red,y:color.green,z:color.blue,w:1)
            if let cells=glassKernel?.apply(extent:extent,arguments:[CIVector(x:extent.midX,y:extent.midY),cell,radius,Double(settings.seed),max(0,min(1,settings.saturation)),edge]){return over(inside(cells.applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:opacity)])),input)}
            // Preserve the source if the runtime cannot compile the kernel.
            // The native release gate separately requires successful compilation.
            return input

        default:return input
        }
    }
}
