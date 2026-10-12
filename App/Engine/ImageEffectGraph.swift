import CoreImage
import UIKit

/// All coordinates are source-image coordinates, so gradients, bands and noise
/// remain identical between viewport tiles, preview scale and exported PNG bands.
enum ImageEffectGraph {
    private static let vignette=CIColorKernel(source:"""
    kernel vec4 imageVignette(__sample s,vec2 center,float radius,float start,float strength){float t=clamp((distance(destCoord(),center)/max(radius,1.0)-start)/max(0.001,1.0-start),0.0,1.0);return vec4(s.rgb*(1.0-t*strength),s.a);}
    """)
    private static let grain=CIColorKernel(source:"""
    kernel vec4 imageGrain(__sample s,float cell,float strength,float seed){vec2 p=floor(destCoord()/max(1.0,cell));float n=fract(sin(dot(p,vec2(12.9898,78.233))+seed)*43758.5453);vec3 a=s.rgb/max(s.a,0.00001);vec3 low=2.0*a*n;vec3 high=1.0-2.0*(1.0-a)*(1.0-n);vec3 mixed=mix(low,high,step(vec3(0.5),a));return vec4(mix(a,mixed,strength)*s.a,s.a);}
    """)
    private static let fade=CIColorKernel(source:"""
    kernel vec4 imageFade(__sample s,vec2 center,vec2 direction,float radius,float cutoff,float particles,float seed){float t=(dot(destCoord()-center,direction)+radius)/(2.0*max(1.0,radius));float opacity=1.0-smoothstep(clamp(cutoff-0.1,0.0,1.0),clamp(cutoff+0.1,0.0,1.0)+0.0001,t);vec4 result=s*opacity;vec2 cell=floor(destCoord()/4.0);float n=fract(sin(dot(cell,vec2(12.9898,78.233))+seed)*43758.5453);float spark=step(1.0-particles*0.008,n)*step(cutoff-0.1,t)*0.7;if(particles>0.0){result=vec4(mix(result.rgb,vec3(spark),spark),max(result.a,spark*s.a));}return result;}
    """)
    private static let duotone=CIColorKernel(source:"""
    kernel vec4 imageDuotone(__sample s,__color dark,__color light){vec3 p=s.rgb/max(s.a,0.00001);float l=dot(p,vec3(0.213,0.715,0.072));return vec4(mix(dark.rgb,light.rgb,l)*s.a,s.a);}
    """)
    private static let halftone=CIKernel(source:"""
    kernel vec4 imageHalftone(sampler source,float radius,float angle){vec2 p=destCoord();float c=cos(angle),s=sin(angle);vec2 q=vec2(c*p.x-s*p.y,s*p.x+c*p.y);float cell=radius*1.5;float row=floor(q.y/cell);float stagger=mod(row,2.0)*cell*0.5;vec2 center=vec2(floor((q.x-stagger)/cell)*cell+stagger,row*cell);vec2 samplePoint=vec2(c*center.x+s*center.y,-s*center.x+c*center.y);vec4 original=sample(source,samplerTransform(source,p));vec4 color=sample(source,samplerTransform(source,samplePoint));float lum=dot(color.rgb/max(color.a,0.00001),vec3(0.299,0.587,0.114));float dotRadius=lum*radius*0.9;float inside=1.0-smoothstep(max(0.0,dotRadius-0.6),dotRadius+0.6,distance(q,center));return mix(original,color,inside*step(0.5,dotRadius));}
    """)
    private static let pixelate=CIKernel(source:"""
    kernel vec4 imagePixelate(sampler source,float cell){vec2 q=floor(destCoord()/max(1.0,cell))*max(1.0,cell)+vec2(max(1.0,cell)*0.5);return sample(source,samplerTransform(source,q));}
    """)
    private static func pixelated(_ image:CIImage,cell:Double,extent:CGRect)->CIImage {
        pixelate?.apply(extent:extent,roiCallback:{_,r in r.insetBy(dx:-CGFloat(cell*2),dy:-CGFloat(cell*2))},arguments:[image.clampedToExtent(),cell]) ?? image
    }
    static var kernelsAvailable:Bool{vignette != nil && grain != nil && fade != nil && duotone != nil && halftone != nil && pixelate != nil}
    static func apply(_ input:CIImage,effects:[ImageEffect],size:CGSize)->CIImage {
        let extent=CGRect(origin:.zero,size:size),center=CIVector(x:size.width/2,y:size.height/2)
        var result=input
        for raw in effects where raw.enabled && raw.opacity>0 {
            let effect=raw.sanitized,before=result,i=effect.intensity,angle=effect.angle*Double.pi/180
            switch effect.kind {
            case .blur:
                switch Int(effect.parameter1){
                case 1:result=pixelated(result,cell:1/max(0.04,1-i/105),extent:extent)
                case 2:result=result.clampedToExtent().applyingFilter("CIZoomBlur",parameters:[kCIInputAmountKey:i,kCIInputCenterKey:center])
                case 3:
                    var spun=result;let count=RenderBudget.isInteractive ? 4:14
                    for n in 1...count{for sign in [-1.0,1.0]{let theta=sign*Double(n)/Double(count)*min(35,i*0.35)*Double.pi/180;let transform=CGAffineTransform(translationX:size.width/2,y:size.height/2).rotated(by:theta).translatedBy(x:-size.width/2,y:-size.height/2);let sample=opacity(result.transformed(by:transform),1/Double(count*2+1));spun=sample.composited(over:spun)}};result=spun
                case 4:result=result.clampedToExtent().applyingFilter("CIMotionBlur",parameters:[kCIInputRadiusKey:i*0.3,kCIInputAngleKey:angle])
                default:result=result.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:i*0.12])
                }
            case .chromatic:result=chromatic(result,dx:i*cos(angle),dy:-i*sin(angle))
            case .glitch:
                let shift=max(1.5,i*0.4)
                let first=tint(result,color:effect.color,amount:0.5).transformed(by:CGAffineTransform(translationX:shift,y:0))
                let second=tint(result,color:effect.color2,amount:0.5).transformed(by:CGAffineTransform(translationX:-shift,y:0))
                let colored=first.applyingFilter("CIAdditionCompositing",parameters:[kCIInputBackgroundImageKey:second]).composited(over:result)
                var generator=SeededImageRandom(seed:UInt64(i*1000)+UInt64(effect.seed)),top=0.0
                var slices=CIImage.empty()
                while top<Double(size.height){let length=generator.next()*Double(size.height)/20+4,offset=generator.next()>0.4 ? (generator.next()-0.5)*shift*2.5:0;let bottom=max(0,Double(size.height)-top-length),h=min(length,Double(size.height)-top);let rect=CGRect(x:0,y:bottom,width:Double(size.width),height:h);slices=colored.transformed(by:CGAffineTransform(translationX:offset,y:0)).cropped(to:rect).composited(over:slices);top+=length};result=slices
            case .vignette:if let value=vignette?.apply(extent:extent,arguments:[result,center,hypot(size.width/2,size.height/2),1-min(100,effect.parameter1)/100*0.6,i/200]){result=value}
            case .grain:if let value=grain?.apply(extent:extent,arguments:[result,max(1,effect.parameter1),min(0.9,i/200*0.9),Double(effect.seed)]){result=value}
            case .glow:
                let blurred=result.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:max(0.1,i*0.12)])
                let tinted=tint(blurred,color:effect.color,amount:min(1,i/100))
                result=tinted.applyingFilter("CIAdditionCompositing",parameters:[kCIInputBackgroundImageKey:result])
            case .pixelate:result=pixelated(result,cell:max(2,i),extent:extent)
            case .halftone:
                let radius=max(2,i/5)
                if let value=halftone?.apply(extent:extent,roiCallback:{_,r in r.insetBy(dx:-CGFloat(radius*3),dy:-CGFloat(radius*3))},arguments:[result,radius,angle]){result=value}
            case .slice:
                let dx=CGFloat(cos(angle+Double.pi/2)*i),dy=CGFloat(-sin(angle+Double.pi/2)*i),height=size.height/3
                var sliced=CIImage.empty()
                for n in 0..<3{let offset=CGFloat(n-1);let rect=CGRect(x:0,y:size.height-CGFloat(n+1)*height,width:size.width,height:height);sliced=result.transformed(by:CGAffineTransform(translationX:dx*offset,y:dy*offset)).cropped(to:rect).composited(over:sliced)};result=sliced
            case .fade:if let value=fade?.apply(extent:extent,arguments:[result,center,CIVector(x:cos(angle),y:-sin(angle)),hypot(size.width,size.height)/2,1-i/200,effect.parameter2,Double(effect.seed)]){result=value}
            case .duotone:if let value=duotone?.apply(extent:extent,arguments:[result,CIColor(color:UIColor(hex:effect.color)),CIColor(color:UIColor(hex:effect.color2))]){result=value}
            case .mirror:
                let transform=Int(effect.parameter1)==1 ? CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:size.height):CGAffineTransform(a:-1,b:0,c:0,d:1,tx:size.width,ty:0)
                result=opacity(result.transformed(by:transform),min(200,i)/255).applyingFilter("CIScreenBlendMode",parameters:[kCIInputBackgroundImageKey:result])
            case .outline:
                let blurred=result.applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:max(1,i)])
                let outer=tint(blurred,color:effect.color,amount:1).applyingFilter("CISourceOutCompositing",parameters:[kCIInputBackgroundImageKey:result])
                result=result.composited(over:outer)
            }
            result=result.cropped(to:extent)
            if effect.opacity<1{result=result.applyingFilter("CIDissolveTransition",parameters:[kCIInputTargetImageKey:before,kCIInputTimeKey:1-effect.opacity])}
        }
        return result.cropped(to:extent)
    }
    private static func chromatic(_ image:CIImage,dx:Double,dy:Double)->CIImage {
        let red=image.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:1,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:0,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:0,w:0)]).transformed(by:CGAffineTransform(translationX:dx,y:dy))
        let cyan=image.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:0,y:0,z:0,w:0)]).transformed(by:CGAffineTransform(translationX:-dx,y:-dy))
        return red.applyingFilter("CIScreenBlendMode",parameters:[kCIInputBackgroundImageKey:cyan])
    }
    private static func opacity(_ image:CIImage,_ amount:Double)->CIImage{image.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:amount,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:amount,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:amount,w:0),"inputAVector":CIVector(x:0,y:0,z:0,w:amount)])}
    private static func tint(_ image:CIImage,color:String,amount:Double)->CIImage{let c=CIColor(color:UIColor(hex:color));return image.applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:0,y:0,z:0,w:c.red*CGFloat(amount)),"inputGVector":CIVector(x:0,y:0,z:0,w:c.green*CGFloat(amount)),"inputBVector":CIVector(x:0,y:0,z:0,w:c.blue*CGFloat(amount))])}
}
struct SeededImageRandom {
    private var state:UInt64
    init(seed:UInt64){state=(seed^0x5DEECE66D)&((1<<48)-1)}
    mutating func next()->Double{state=(state &* 0x5DEECE66D &+ 11)&((1<<48)-1);return Double(state>>24)/Double(1<<24)}
}
