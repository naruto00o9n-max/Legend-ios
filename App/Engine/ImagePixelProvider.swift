import UIKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

/// Core Image requests only the tiles needed by its filter graph, including
/// distant mirror samples. Never upload a 15,000-pixel texture in one piece.
final class ImagePixelProvider:NSObject {
    let url:URL,width:Int,height:Int,colorSpace:CGColorSpace
    private let lock=NSLock()
    private var failure:String?
    private let tiles=NSCache<NSString,NSData>()
    private(set) var largestRequestPixels=0
    var error:String?{lock.lock();defer{lock.unlock()};return failure}
    init(url:URL,width:Int,height:Int,colorSpace:CGColorSpace){self.url=url;self.width=width;self.height=height;self.colorSpace=colorSpace}
    override func provideImageData(_ data:UnsafeMutableRawPointer,bytesPerRow:Int,origin x:Int,_ y:Int,size w:Int,_ h:Int,userInfo:Any?){
        data.initializeMemory(as:UInt8.self,repeating:0,count:bytesPerRow*h)
        guard w>0,h>0,x>=0,y>=0,x<width,y<height else{return}
        let rw=min(w,width-x),rh=min(h,height-y)
        let key="\(x):\(y):\(rw):\(rh)" as NSString
        if let cached=tiles.object(forKey:key){for row in 0..<rh{data.advanced(by:row*bytesPerRow).copyMemory(from:cached.bytes.advanced(by:row*rw*4),byteCount:rw*4)};return}
        var pixels=[UInt8](repeating:0,count:rw*rh*4)
        guard LIReadRegion(url.path,Int32(width),Int32(height),Int32(x),Int32(y),Int32(rw),Int32(rh),1,&pixels)==1 else{lock.lock();failure="تعذر قراءة جزء من الصورة؛ احتُفظ بالأصل";lock.unlock();return}
        lock.lock();largestRequestPixels=max(largestRequestPixels,w*h);lock.unlock()
        // Provider coordinates/rows are top-left, as specified by CIImageProvider.h.
        let count=pixels.count/4;LIPremultiplyRGBA(&pixels,count)
        let value=Data(pixels) as NSData;tiles.totalCostLimit=2*1024*1024;tiles.setObject(value,forKey:key,cost:value.length)
        for row in 0..<rh{data.advanced(by:row*bytesPerRow).copyMemory(from:value.bytes.advanced(by:row*rw*4),byteCount:rw*4)}
    }
    var image:CIImage{CIImage(imageProvider:self,size:width,height,format:.RGBA8,colorSpace:colorSpace,options:[.providerTileSize:256])}
}
enum ImageAssetPixels {
    private static let decodeLock=NSLock()
    private static let hashes=NSCache<NSString,NSString>()
    private static let providers=NSCache<NSString,ImagePixelProvider>()
    private static let inputs=NSCache<NSString,ImagePixelProvider>()
    static func clear(){providers.removeAllObjects();inputs.removeAllObjects();hashes.removeAllObjects()}
    private static func cachedProvider(_ raw:URL,width:Int,height:Int,profile:URL)->ImagePixelProvider {
        let key="\(raw.path)|\(width)|\(height)" as NSString
        if let hit=providers.object(forKey:key),hit.error==nil{return hit}
        let result=ImagePixelProvider(url:raw,width:width,height:height,colorSpace:ImagePipeline.colorSpace(profile))
        providers.countLimit=4;providers.setObject(result,forKey:key);return result
    }
    static func provider(_ layer:EditorLayer,directory:URL)throws->ImagePixelProvider {
        if let file=layer.imagePixelFile,AppStorageManager.safe(file),!file.contains("/"),let width=layer.imagePixelWidth,let height=layer.imagePixelHeight,width>0,height>0{
            let raw=directory.appendingPathComponent(file)
            if !FileManager.default.fileExists(atPath:raw.path),layer.isWorkingImage==true,
               let data=try? Data(contentsOf:directory.appendingPathComponent("page.json")),let page=try? JSONDecoder().decode(EditorPage.self,from:data),page.raw==file,page.source==layer.imagePath,page.width==width,page.height==height {
                try ImagePipeline.ensureDecoded(raw,width:width,height:height)
            }
            if (try? FileManager.default.attributesOfItem(atPath:raw.path)[.size] as? NSNumber)?.int64Value == Int64(width)*Int64(height)*4{return cachedProvider(raw,width:width,height:height,profile:directory.appendingPathComponent(layer.imagePath))}
        }
        let input=directory.appendingPathComponent(layer.imagePath)
        let attributes=try FileManager.default.attributesOfItem(atPath:input.path)
        let identity=input.path+"|\(attributes[.size] ?? 0)|\(attributes[.modificationDate] ?? Date.distantPast)"
        if let hit=inputs.object(forKey:identity as NSString),hit.error==nil,FileManager.default.fileExists(atPath:hit.url.path){return hit}
        guard let source=CGImageSourceCreateWithURL(input as CFURL,nil),let info=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],let width=info[kCGImagePropertyPixelWidth] as? Int,let height=info[kCGImagePropertyPixelHeight] as? Int,width>0,height>0 else{throw ImageFailure.message("تعذر فتح أصل طبقة الصورة")}
        let key:String
        if let cached=hashes.object(forKey:identity as NSString){key=cached as String}else{key=try AppStorageManager.hash(input);hashes.countLimit=256;hashes.setObject(key as NSString,forKey:identity as NSString)}
        let folder=AppStorageManager.caches.appendingPathComponent("CookiesImagePixels",isDirectory:true),raw=folder.appendingPathComponent(key+".rgba"),png=folder.appendingPathComponent(key+".png")
        decodeLock.lock();defer{decodeLock.unlock()}
        if !FileManager.default.fileExists(atPath:raw.path){
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let handle=try FileHandle(forReadingFrom:input);let signature=try handle.read(upToCount:8);try handle.close()
            var decodeInput=input
            if signature != Data([137,80,78,71,13,10,26,10]){
                guard let cg=CGImageSourceCreateImageAtIndex(source,0,nil),let destination=CGImageDestinationCreateWithURL(png as CFURL,UTType.png.identifier as CFString,1,nil) else{throw ImageFailure.message("تعذر تجهيز ذاكرة طبقة الصورة")}
                CGImageDestinationAddImage(destination,cg,nil);guard CGImageDestinationFinalize(destination) else{throw ImageFailure.message("تعذر تجهيز الصورة")};decodeInput=png
            }
            let temporary=raw.appendingPathExtension(UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:temporary)}
            var w:Int32=0,h:Int32=0,error=[CChar](repeating:0,count:512)
            guard LIImportPNG(decodeInput.path,temporary.path,&w,&h,&error,error.count)==1,Int(w)==width,Int(h)==height else{throw ImageFailure.message("تعذر قراءة أصل الصورة؛ لم يُغيّر")}
            try FileManager.default.moveItem(at:temporary,to:raw)
        }
        let result=cachedProvider(raw,width:width,height:height,profile:FileManager.default.fileExists(atPath:png.path) ? png:input)
        inputs.countLimit=8;inputs.setObject(result,forKey:identity as NSString);return result
    }
}
