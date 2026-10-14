import CoreGraphics
import Foundation

/// One serial session per requested batch. Never retained by the live canvas.
final class BigLaMaSession {
    private let context:UnsafeMutableRawPointer
    private let extent=512
    init(compiled:URL)throws{
        let available=CookiesLaMaAvailableMemory()
        guard available==0 || available>=900_000_000 else{throw LaMaFailure.message("الذاكرة المتاحة لا تكفي لترميم الخلفية بأمان. اختر «عبر الإنترنت»، أو أغلق التطبيقات الأخرى ثم أعد المحاولة")}
        let result=CookiesLaMaOpen(compiled.path)
        guard let value=(result["context"] as? NSValue)?.pointerValue else{
            NSLog("Cookies Big LaMa load: %@",result["error"] as? String ?? "unknown")
            throw LaMaFailure.message("تعذر تشغيل ملفات المعالجة. أعد تنزيلها أو اختر «عبر الإنترنت»")
        }
        context=value
    }
    deinit{CookiesLaMaClose(context)}
    /// Native-resolution windows overlap; output is copied only under the text
    /// mask. The original outside that mask is never rescaled or regenerated.
    func repair(source:CGImage,mask:CGImage)throws->CGImage{
        let w=source.width,h=source.height
        guard w==mask.width,h==mask.height,w>0,h>0,w*h<=4_194_304 else{throw LaMaFailure.message("حدّد منطقة أصغر للترميم")}
        let input=try Self.rgba(source),maskRGBA=try Self.rgba(mask)
        var output=input,weights=[Float](repeating:0,count:w*h)
        var minX=w,minY=h,maxX = -1,maxY = -1
        for y in 0..<h{for x in 0..<w where maskRGBA[(y*w+x)*4]>0{minX=min(minX,x);minY=min(minY,y);maxX=max(maxX,x);maxY=max(maxY,y)}}
        guard maxX>=minX,maxY>=minY else{throw LaMaFailure.message("حدد منطقة النص المراد ترميمها")}
        let xs=Self.origins(length:w,lower:minX,upper:maxX),ys=Self.origins(length:h,lower:minY,upper:maxY)
        for originY in ys{for originX in xs{
            try Task.checkCancellation()
            let left=max(0,originX),top=max(0,originY),right=min(w,originX+extent),bottom=min(h,originY+extent)
            var marked=false
            for y in top..<bottom{for x in left..<right where maskRGBA[(y*w+x)*4]>0{marked=true;break};if marked{break}}
            if !marked{continue}
            try autoreleasepool{
                let plane=extent*extent
                var color=[Float](repeating:0,count:plane*3),text=[Float](repeating:0,count:plane)
                for y in 0..<extent{for x in 0..<extent{
                    let sx=min(w-1,max(0,originX+x)),sy=min(h-1,max(0,originY+y)),index=(sy*w+sx)*4,pixel=y*extent+x
                    for channel in 0..<3{color[channel*plane+pixel]=Float(input[index+channel])/255}
                    text[pixel]=(originX+x>=0 && originX+x<w && originY+y>=0 && originY+y<h && maskRGBA[index]>0) ? 1:0
                }}
                let colorData=color.withUnsafeBufferPointer{Data(buffer:$0)},maskData=text.withUnsafeBufferPointer{Data(buffer:$0)}
                let prediction=CookiesLaMaPredict(context,colorData,maskData)
                try Task.checkCancellation()
                guard let bytes=prediction["output"] as? Data,bytes.count==plane*3*MemoryLayout<Float>.size else{
                    NSLog("Cookies Big LaMa inference: %@",prediction["error"] as? String ?? "invalid tensor")
                    throw LaMaFailure.message("تعذر إكمال الترميم على الجهاز. جرّب «عبر الإنترنت» أو منطقة نص أصغر")
                }
                var pixels=[Float](repeating:0,count:plane*3)
                _ = pixels.withUnsafeMutableBytes{bytes.copyBytes(to:$0)}
                guard pixels.allSatisfy(\.isFinite) else{throw LaMaFailure.message("نتيجة نموذج الترميم غير صالحة. لم تُغير الصورة؛ جرّب «عبر الإنترنت»")}
                for y in top..<bottom{for x in left..<right{
                    let index=y*w+x,offset=index*4;guard maskRGBA[offset]>0 else{continue}
                    let tx=x-originX,ty=y-originY,edge=min(min(tx+1,extent-tx),min(ty+1,extent-ty)),weight=min(1,Float(edge)/64),old=weights[index],sum=old+weight,p=ty*extent+tx
                    for channel in 0..<3{let value=(Float(output[offset+channel])*old+pixels[channel*plane+p]*weight)/sum;output[offset+channel]=UInt8(max(0,min(255,value.rounded())))}
                    weights[index]=sum
                }}
            }
        }}
        // Transparent patch: pixels outside the mask cannot affect the canvas.
        for i in 0..<(w*h){let alpha=maskRGBA[i*4];for c in 0..<3{output[i*4+c]=UInt8((Int(output[i*4+c])*Int(alpha)+127)/255)};output[i*4+3]=alpha}
        guard let provider=CGDataProvider(data:Data(output) as CFData),let image=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent) else{throw LaMaFailure.message("تعذر حفظ رقعة الترميم")}
        return image
    }
    private static func origins(length:Int,lower:Int,upper:Int)->[Int]{
        if length<=512{return [-(512-length)/2]}
        if upper-lower+1<=512{return [max(0,min(length-512,(lower+upper+1-512)/2))]}
        var values=Array(stride(from:0,to:length-512,by:448));if values.last != length-512{values.append(length-512)};return values
    }
    static func rgba(_ image:CGImage)throws->[UInt8]{
        var data=[UInt8](repeating:0,count:image.width*image.height*4)
        let valid=data.withUnsafeMutableBytes{bytes->Bool in guard let context=CGContext(data:bytes.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false};context.setBlendMode(.copy);context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height));return true}
        guard valid else{throw LaMaFailure.message("تعذر قراءة صورة الترميم")};return data
    }
}
