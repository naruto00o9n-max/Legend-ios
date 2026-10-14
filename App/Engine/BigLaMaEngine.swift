import CoreML
import CoreVideo
import CoreGraphics
import Foundation

/// One serial session per requested batch. Never retained by the live canvas.
final class BigLaMaSession {
    private let model:MLModel
    private let extent=800
    init(compiled:URL,units:MLComputeUnits = .all)throws{
        let configuration=MLModelConfiguration();configuration.computeUnits=units;configuration.allowLowPrecisionAccumulationOnGPU=false
        model=try MLModel(contentsOf:compiled,configuration:configuration)
        for name in ["image","mask"]{guard let image=model.modelDescription.inputDescriptionsByName[name]?.imageConstraint,image.pixelsWide==800,image.pixelsHigh==800 else{throw LaMaFailure.message("لم تتطابق مداخل نموذج Big LaMa")}}
        guard model.modelDescription.outputDescriptionsByName["output"]?.imageConstraint != nil else{throw LaMaFailure.message("مخرج نموذج الترميم غير صالح")}
    }
    /// Native-resolution windows overlap; output is copied only under the text
    /// mask. The original outside that mask is never rescaled or regenerated.
    func repair(source:CGImage,mask:CGImage)throws->CGImage{
        let w=source.width,h=source.height
        guard w==mask.width,h==mask.height,w>0,h>0,w*h<=4_194_304 else{throw LaMaFailure.message("حدّد منطقة أصغر للترميم")}
        let input=try Self.rgba(source),maskRGBA=try Self.rgba(mask)
        var output=input,weights=[Float](repeating:0,count:w*h)
        let xs=Self.origins(length:w),ys=Self.origins(length:h)
        for originY in ys{for originX in xs{
            try Task.checkCancellation()
            let left=max(0,originX),top=max(0,originY),right=min(w,originX+extent),bottom=min(h,originY+extent)
            var marked=false
            for y in top..<bottom{for x in left..<right where maskRGBA[(y*w+x)*4]>0{marked=true;break};if marked{break}}
            if !marked{continue}
            try autoreleasepool{
                let color=try Self.buffer(width:extent,height:extent,format:kCVPixelFormatType_32BGRA),text=try Self.buffer(width:extent,height:extent,format:kCVPixelFormatType_OneComponent8)
                CVPixelBufferLockBaseAddress(color,[]);CVPixelBufferLockBaseAddress(text,[])
                guard let rgb=CVPixelBufferGetBaseAddress(color)?.assumingMemoryBound(to:UInt8.self),let ink=CVPixelBufferGetBaseAddress(text)?.assumingMemoryBound(to:UInt8.self) else{CVPixelBufferUnlockBaseAddress(color,[]);CVPixelBufferUnlockBaseAddress(text,[]);throw LaMaFailure.message("تعذر تجهيز ذاكرة الترميم")}
                let rgbStride=CVPixelBufferGetBytesPerRow(color),maskStride=CVPixelBufferGetBytesPerRow(text)
                for y in 0..<extent{for x in 0..<extent{
                    let sx=min(w-1,max(0,originX+x)),sy=min(h-1,max(0,originY+y)),index=(sy*w+sx)*4,pixel=y*rgbStride+x*4
                    rgb[pixel]=input[index+2];rgb[pixel+1]=input[index+1];rgb[pixel+2]=input[index];rgb[pixel+3]=255
                    ink[y*maskStride+x]=(originX+x>=0 && originX+x<w && originY+y>=0 && originY+y<h) ? maskRGBA[index]:0
                }}
                CVPixelBufferUnlockBaseAddress(color,[]);CVPixelBufferUnlockBaseAddress(text,[])
                let features=try MLDictionaryFeatureProvider(dictionary:["image":MLFeatureValue(pixelBuffer:color),"mask":MLFeatureValue(pixelBuffer:text)])
                let prediction=try model.prediction(from:features)
                guard let result=prediction.featureValue(for:"output")?.imageBufferValue,CVPixelBufferGetWidth(result)==extent,CVPixelBufferGetHeight(result)==extent,CVPixelBufferGetPixelFormatType(result)==kCVPixelFormatType_32BGRA else{throw LaMaFailure.message("تعذر قراءة نتيجة Big LaMa")}
                CVPixelBufferLockBaseAddress(result,.readOnly);defer{CVPixelBufferUnlockBaseAddress(result,.readOnly)}
                guard let pixels=CVPixelBufferGetBaseAddress(result)?.assumingMemoryBound(to:UInt8.self) else{throw LaMaFailure.message("نتيجة الترميم فارغة")}
                let stride=CVPixelBufferGetBytesPerRow(result)
                for y in top..<bottom{for x in left..<right{
                    let index=y*w+x,offset=index*4;guard maskRGBA[offset]>0 else{continue}
                    let tx=x-originX,ty=y-originY,edge=min(min(tx+1,extent-tx),min(ty+1,extent-ty)),weight=min(1,Float(edge)/80),old=weights[index],sum=old+weight,p=ty*stride+tx*4
                    for channel in 0..<3{let value=(Float(output[offset+channel])*old+Float(pixels[p+2-channel])*weight)/sum;output[offset+channel]=UInt8(max(0,min(255,value.rounded())))}
                    weights[index]=sum
                }}
            }
        }}
        // Transparent patch: pixels outside the mask cannot affect the canvas.
        for i in 0..<(w*h){let alpha=maskRGBA[i*4];for c in 0..<3{output[i*4+c]=UInt8((Int(output[i*4+c])*Int(alpha)+127)/255)};output[i*4+3]=alpha}
        guard let provider=CGDataProvider(data:Data(output) as CFData),let image=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent) else{throw LaMaFailure.message("تعذر حفظ رقعة الترميم")}
        return image
    }
    private static func origins(length:Int)->[Int]{
        if length<=800{return [-(800-length)/2]}
        var values=Array(stride(from:0,to:length-800,by:640));if values.last != length-800{values.append(length-800)};return values
    }
    static func rgba(_ image:CGImage)throws->[UInt8]{
        var data=[UInt8](repeating:0,count:image.width*image.height*4)
        let valid=data.withUnsafeMutableBytes{bytes->Bool in guard let context=CGContext(data:bytes.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false};context.setBlendMode(.copy);context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height));return true}
        guard valid else{throw LaMaFailure.message("تعذر قراءة صورة الترميم")};return data
    }
    private static func buffer(width:Int,height:Int,format:OSType)throws->CVPixelBuffer{
        var value:CVPixelBuffer?;guard CVPixelBufferCreate(kCFAllocatorDefault,width,height,format,[kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary,&value)==kCVReturnSuccess,let value else{throw LaMaFailure.message("لا تتوفر ذاكرة كافية للترميم")};return value
    }
}
