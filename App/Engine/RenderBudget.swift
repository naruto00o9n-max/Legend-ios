import UIKit

/// Screen previews have a bounded working set. Document export keeps its own
/// full-resolution path; this policy never changes a saved style or source image.
enum RenderBudget {
    private static let flag="cookies.screen-preview"
    static var isPreview:Bool{Thread.current.threadDictionary[flag] as? Bool ?? false}
    static var previewPixels:CGFloat{ProcessInfo.processInfo.physicalMemory<=4_294_967_296 ? 1_048_576:2_097_152}
    static var textCacheBytes:Int{ProcessInfo.processInfo.physicalMemory<=4_294_967_296 ? 16*1024*1024:32*1024*1024}
    static func screen<T>(_ body:()throws->T)rethrows->T {
        let old=Thread.current.threadDictionary[flag];Thread.current.threadDictionary[flag]=true
        defer{if let old{Thread.current.threadDictionary[flag]=old}else{Thread.current.threadDictionary.removeObject(forKey:flag)}}
        return try body()
    }
}

/// A structural key avoids repeatedly encoding whole layers into JSON while
/// drawing tiles and glitch bands. Geometry applied by the compositor is excluded.
final class TextRenderKey:NSObject {
    let layer:EditorLayer;let directory:String;let resolution:CGFloat;let width:CGFloat;let height:CGFloat
    private let value:Int
    init(_ source:EditorLayer,directory:URL,resolution:CGFloat,size:CGSize){
        var layer=source;layer.id=UUID(uuidString:"00000000-0000-0000-0000-000000000000")!;layer.name="";layer.frame.x=0;layer.frame.y=0;layer.rotation=0;layer.scaleX=1;layer.scaleY=1;layer.shearX=nil;layer.opacity=1;layer.isLocked=false;layer.isVisible=true;layer.gradientMapBaseline=nil;layer.groupID=nil;layer.groupName=nil;layer.textOrigin=nil
        self.layer=layer;self.directory=directory.path;self.resolution=resolution;width=size.width;height=size.height
        var h=Hasher();h.combine(layer);h.combine(directory.path);h.combine(resolution);h.combine(size.width);h.combine(size.height);value=h.finalize()
    }
    override var hash:Int{value}
    override func isEqual(_ object:Any?)->Bool{guard let other=object as? TextRenderKey else{return false};return resolution==other.resolution && width==other.width && height==other.height && directory==other.directory && layer==other.layer}
}
