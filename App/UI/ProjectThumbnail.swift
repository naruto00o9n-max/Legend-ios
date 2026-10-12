import SwiftUI
import ImageIO

struct ProjectThumbnail:View {
    let url:URL
    let revision:Int
    let icon:String
    @State private var image:UIImage?
    var body:some View{Group{if let image{Image(uiImage:image).resizable().scaledToFill()}else{Image(systemName:icon)}}.task(id:"\(url.path)|\(revision)"){let next=await ThumbnailLoader.load(url);guard !Task.isCancelled else{return};image=next}}
}
private enum ThumbnailLoader {
    static let worker=DispatchQueue(label:"cookies.library.thumbnails",qos:.utility,autoreleaseFrequency:.workItem)
    static let cache=NSCache<NSString,UIImage>()
    static func load(_ url:URL)async->UIImage?{await withCheckedContinuation{continuation in worker.async{
        let modified=(try? url.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        let key="\(url.path)|\(modified)" as NSString
        if let image=cache.object(forKey:key){continuation.resume(returning:image);return}
        guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let cg=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:512,kCGImageSourceShouldCacheImmediately:true] as CFDictionary) else{continuation.resume(returning:nil);return}
        let image=UIImage(cgImage:cg);cache.totalCostLimit=4*1024*1024;cache.setObject(image,forKey:key,cost:cg.bytesPerRow*cg.height);continuation.resume(returning:image)
    }}}
}
