import UIKit
import ImageIO
import UniformTypeIdentifiers

enum ImageFailure: LocalizedError {
    case message(String)
    var errorDescription:String?{if case let .message(s)=self{return s};return nil}
}
enum ImagePipeline {
    static let space=CGColorSpaceCreateDeviceRGB()
    private static let assets=NSCache<NSString,UIImage>()
    private static let assetLock=NSLock()
    static func asset(_ url:URL)->UIImage? {assetLock.lock();defer{assetLock.unlock()};if let image=assets.object(forKey:url.path as NSString){return image};guard let image=UIImage(contentsOfFile:url.path) else{return nil};assets.totalCostLimit=64*1024*1024;assets.setObject(image,forKey:url.path as NSString,cost:Int(image.size.width*image.size.height)*4);return image}
    static let spaces=NSCache<NSString,CGColorSpace>()
    static func colorSpace(_ source:URL)->CGColorSpace {if let cached=spaces.object(forKey:source.path as NSString){return cached};var count=0;guard let pointer=LICopyPNGProfile(source.path,&count) else{return CGColorSpace(name:CGColorSpace.sRGB) ?? space};defer{LIFreeBuffer(pointer)};let result=CGColorSpace(iccData:Data(bytes:pointer,count:count) as CFData) ?? space;spaces.setObject(result,forKey:source.path as NSString);return result}
    static func image(_ rgba:[UInt8],width:Int,height:Int,colorSpace:CGColorSpace=space)->CGImage? {
        guard width>0,height>0,let provider=CGDataProvider(data:Data(rgba) as CFData) else{return nil}
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:colorSpace,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
    }
    static func tile(_ url:URL,width:Int,height:Int,rect:CGRect,sample:Int=1)throws->[UInt8] {
        let x=max(0,Int(rect.minX)),y=max(0,Int(rect.minY)),w=min(width-x,max(1,Int(ceil(rect.width)))),h=min(height-y,max(1,Int(ceil(rect.height))))
        guard w>0,h>0 else{return []};var bytes=[UInt8](repeating:0,count:((w+sample-1)/sample)*((h+sample-1)/sample)*4)
        guard LIReadRegion(url.path,Int32(width),Int32(height),Int32(x),Int32(y),Int32(w),Int32(h),Int32(sample),&bytes)==1 else{throw ImageFailure.message("تعذر قراءة جزء من الصورة")};return bytes
    }
    static func importImage(_ input:URL,root:URL)throws->EditorPage {
        let scoped=input.startAccessingSecurityScopedResource();defer{if scoped{input.stopAccessingSecurityScopedResource()}}
        var page=EditorPage(title:input.deletingPathExtension().lastPathComponent,width:0,height:0)
        let directory=root.appendingPathComponent(page.id.uuidString,isDirectory:true);try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        do {
            let source=directory.appendingPathComponent(page.source)
            if let signature=try? FileHandle(forReadingFrom:input).read(upToCount:8),signature==Data([137,80,78,71,13,10,26,10]) {try FileManager.default.copyItem(at:input,to:source)}
            else {
                guard let src=CGImageSourceCreateWithURL(input as CFURL,nil),let cg=CGImageSourceCreateImageAtIndex(src,0,[kCGImageSourceShouldCache:false] as CFDictionary),let destination=CGImageDestinationCreateWithURL(source as CFURL,UTType.png.identifier as CFString,1,nil) else{throw ImageFailure.message("تعذر فتح صيغة الصورة")}
                let properties=CGImageSourceCopyPropertiesAtIndex(src,0,nil) as? [String:Any],orientation=properties?[kCGImagePropertyOrientation as String] as? Int ?? 1
                var normalized=cg
                if orientation != 1 {
                    let orientations:[UIImage.Orientation]=[.up,.up,.upMirrored,.down,.downMirrored,.leftMirrored,.right,.rightMirrored,.left]
                    let image=UIImage(cgImage:cg,scale:1,orientation:orientations[min(8,max(1,orientation))]),rotated=(5...8).contains(orientation)
                    let size=CGSize(width:rotated ? cg.height:cg.width,height:rotated ? cg.width:cg.height),format=UIGraphicsImageRendererFormat();format.scale=1;format.preferredRange = .standard
                    normalized=UIGraphicsImageRenderer(size:size,format:format).image{_ in image.draw(in:CGRect(origin:.zero,size:size))}.cgImage ?? cg
                }
                CGImageDestinationAddImage(destination,normalized,nil);guard CGImageDestinationFinalize(destination) else{throw ImageFailure.message("تعذر تجهيز الصورة")}
            }
            var w:Int32=0,h:Int32=0,error=[CChar](repeating:0,count:512)
            guard LIImportPNG(source.path,directory.appendingPathComponent(page.raw).path,&w,&h,&error,error.count)==1 else{throw ImageFailure.message(String(cString:error).contains("16-bit") ? "صور PNG ذات 16 بت تحتاج نسخة 8 بت؛ لم تُخفض دقتها تلقائيًا.":"تعذر قراءة الصورة: \(String(cString:error))")}
            page.width=Int(w);page.height=Int(h);try JSONEncoder().encode(page).write(to:directory.appendingPathComponent("page.json"),options:.atomic)
            try? projectThumbnail(page,directory:directory);return page
        }catch{try? FileManager.default.removeItem(at:directory);throw error}
    }
    static func projectThumbnail(_ page:EditorPage,directory:URL)throws {
        let visibleHeight=min(page.height,max(page.width,Int(Double(page.width)*1.25))),sample=max(1,page.width/320)
        let pixels=try tile(directory.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:CGRect(x:0,y:0,width:page.width,height:visibleHeight),sample:sample)
        guard let cg=image(pixels,width:(page.width+sample-1)/sample,height:(visibleHeight+sample-1)/sample,colorSpace:colorSpace(directory.appendingPathComponent(page.source))) else{return}
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let preview=UIGraphicsImageRenderer(size:CGSize(width:cg.width,height:cg.height),format:format).image{renderer in
            UIImage(cgImage:cg).draw(in:CGRect(x:0,y:0,width:cg.width,height:cg.height));renderer.cgContext.scaleBy(x:1/CGFloat(sample),y:1/CGFloat(sample));LayerRenderer.draw(page.layers,in:renderer.cgContext,directory:directory)
        }
        try preview.pngData()?.write(to:directory.appendingPathComponent("thumbnail.png"),options:.atomic)
    }
    static func thumbnail(_ source:URL,to output:URL) {
        guard let s=CGImageSourceCreateWithURL(source as CFURL,nil),let c=CGImageSourceCreateThumbnailAtIndex(s,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:480,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else{return}
        try? UIImage(cgImage:c).pngData()?.write(to:output)
    }
    static func exportPNG(_ page:EditorPage,directory:URL)throws->URL {
        let output=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-\(page.id.uuidString)-\(UUID().uuidString).png")
        let original=directory.appendingPathComponent(page.source)
        if page.layers.allSatisfy({!$0.isVisible}){try FileManager.default.copyItem(at:original,to:output);return output}
        var error=[CChar](repeating:0,count:512)
        guard let writer=LIWriterOpen(original.path,output.path,Int32(page.width),Int32(page.height),&error,error.count) else{throw ImageFailure.message("تعذر بدء التصدير")}
        defer{LIWriterClose(writer)}
        for y in stride(from:0,to:page.height,by:256) {
            try Task.checkCancellation()
            let rows=min(256,page.height-y);var base=try tile(directory.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:CGRect(x:0,y:y,width:page.width,height:rows))
            for layer in page.layers where layer.isVisible {
                var overlay=[UInt8](repeating:0,count:base.count)
                var isolated=layer;isolated.blend = .normal
                let rendered=overlay.withUnsafeMutableBytes{bytes->Bool in
                    guard let ctx=CGContext(data:bytes.baseAddress,width:page.width,height:rows,bitsPerComponent:8,bytesPerRow:page.width*4,space:colorSpace(original),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false}
                    ctx.translateBy(x:0,y:CGFloat(rows));ctx.scaleBy(x:1,y:-1);ctx.translateBy(x:0,y:-CGFloat(y))
                    LayerRenderer.draw([isolated],in:ctx,directory:directory);return true
                }
                guard rendered else{throw ImageFailure.message("تعذر رسم الطبقات")}
                let mode=Int32(Blend.allCases.firstIndex(of:layer.blend) ?? 0)
                LICompositeBlend(&base,&overlay,base.count/4,mode)
            }
            guard LIWriterRows(writer,&base,Int32(rows))==1 else{throw ImageFailure.message("تعذر كتابة الصورة؛ تحقق من مساحة التخزين")}
        }
        guard LIWriterFinish(writer)==1 else{throw ImageFailure.message("لم يكتمل التصدير")};return output
    }
    static func exportJPEG(_ page:EditorPage,directory:URL,quality:Double)throws->URL {
        let png=try exportPNG(page,directory:directory);defer{try? FileManager.default.removeItem(at:png)}
        let output=png.deletingPathExtension().appendingPathExtension("jpg")
        guard let source=CGImageSourceCreateWithURL(png as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil),let context=CGContext(data:nil,width:page.width,height:page.height,bitsPerComponent:8,bytesPerRow:page.width*4,space:image.colorSpace ?? space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue) else{throw ImageFailure.message("تعذر إعداد JPEG")}
        context.setFillColor(UIColor.white.cgColor);context.fill(CGRect(x:0,y:0,width:page.width,height:page.height));context.draw(image,in:CGRect(x:0,y:0,width:page.width,height:page.height))
        guard let flattened=context.makeImage(),let destination=CGImageDestinationCreateWithURL(output as CFURL,UTType.jpeg.identifier as CFString,1,nil) else{throw ImageFailure.message("تعذر التصدير")}
        CGImageDestinationAddImage(destination,flattened,[kCGImageDestinationLossyCompressionQuality:min(1,max(0.1,quality))] as CFDictionary);guard CGImageDestinationFinalize(destination) else{throw ImageFailure.message("لم يكتمل تصدير JPEG")};return output
    }
    static func fixture(root:URL)throws->EditorPage {
        let input=root.appendingPathComponent("الفصل التجريبي.png");var error=[CChar](repeating:0,count:512)
        guard let writer=LIWriterOpen(nil,input.path,800,15000,&error,error.count) else{throw ImageFailure.message("صورة الاختبار")};defer{LIWriterClose(writer)}
        var band=[UInt8](repeating:255,count:800*750*4)
        for y in 0..<750 {for x in 0..<800 {let inside=x>24&&x<776&&y>24&&y<610,c:UInt8=inside ? 24:248,offset=(y*800+x)*4;band[offset]=c;band[offset+1]=c;band[offset+2]=inside ? 26:c;if inside && x>110&&x<690&&y>90&&y<400{band[offset]=164;band[offset+1]=135;band[offset+2]=70}}}
        for _ in 0..<20{guard LIWriterRows(writer,&band,750)==1 else{throw ImageFailure.message("صورة الاختبار")}}
        guard LIWriterFinish(writer)==1 else{throw ImageFailure.message("صورة الاختبار")};return try importImage(input,root:root)
    }
}
