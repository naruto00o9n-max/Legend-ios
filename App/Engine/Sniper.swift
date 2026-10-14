import UIKit

enum BubbleWhiteningMethod:String,CaseIterable,Identifiable {
    case classic,bigLaMa
    var id:String{rawValue}
    var title:String{self == .classic ? "التبييض المعتاد":"خدمة ذكاء اصطناعي"}
}
enum RestorationExecution:String,CaseIterable,Identifiable {
    case device,cloud
    var id:String{rawValue}
    var title:String{self == .device ? "دون إنترنت":"عبر الإنترنت"}
}
/// A saved preference is applied only when a target is created, never when
/// switching between existing bubbles with their independent choices.
enum WhiteningPreferences {
    static let methodKey="editor-whitening-method",executionKey="editor-whitening-execution"
    static func method(defaults:UserDefaults = .standard)->BubbleWhiteningMethod {
        BubbleWhiteningMethod(rawValue:defaults.string(forKey:methodKey) ?? "") ?? .classic
    }
    static func execution(available:Bool,defaults:UserDefaults = .standard)->RestorationExecution {
        available && defaults.string(forKey:executionKey)==RestorationExecution.device.rawValue ? .device:.cloud
    }
    static func remember(_ method:BubbleWhiteningMethod,defaults:UserDefaults = .standard){defaults.set(method.rawValue,forKey:methodKey)}
    static func remember(_ execution:RestorationExecution,available:Bool,defaults:UserDefaults = .standard){
        guard execution != .device || available else{return}
        defaults.set(execution.rawValue,forKey:executionKey)
    }
    static func apply(to target:inout SniperTarget,available:Bool,defaults:UserDefaults = .standard){
        target.whiteningMethod=method(defaults:defaults)
        target.restorationExecution=execution(available:available,defaults:defaults)
    }
}
enum ManualSniperTool:String {case rectangle,freehand,textRectangle}
struct SniperTarget: Identifiable, Equatable {
    var id=UUID()
    var bounds:Box
    var outline:[Point]=[]
    var pin=false
    var point:Point
    var whiteningMethod=BubbleWhiteningMethod.classic
    var restorationExecution=RestorationExecution.cloud
    var manualTextRegions:[Box]=[]
    var manuallySelected=false
}
enum SniperDetector {
    static func detect(page:EditorPage,directory:URL,point:CGPoint)throws->SniperTarget {
        let area=CGRect(x:point.x-500,y:point.y-500,width:1000,height:1000).intersection(CGRect(x:0,y:0,width:page.width,height:page.height)).integral
        let bytes=try ImagePipeline.tile(directory.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:area)
        guard let image=ImagePipeline.image(bytes,width:Int(area.width),height:Int(area.height)),let result=CookiesDetectBubble(UIImage(cgImage:image),CGPoint(x:point.x-area.minX,y:point.y-area.minY)) as? [String:Any] else{throw ImageFailure.message("تعذر تحليل الفقاعة")}
        func number(_ key:String)->Double {(result[key] as? NSNumber)?.doubleValue ?? 0}
        let pin=(result["pin"] as? Bool) ?? true
        let outline=((result["points"] as? [[NSNumber]]) ?? []).compactMap{pair -> Point? in guard pair.count==2 else{return nil};return Point(x:pair[0].doubleValue+area.minX,y:pair[1].doubleValue+area.minY)}
        return SniperTarget(bounds:Box(x:number("x")+area.minX,y:number("y")+area.minY,width:number("width"),height:number("height")),outline:outline,pin:pin,point:Point(x:point.x,y:point.y))
    }
    static func fitted(_ layer:EditorLayer,to target:SniperTarget)throws->EditorLayer {
        var result=layer
        if target.pin {let rect=LayerRenderer.bounds(result);result.frame.x=target.point.x-rect.width/2;result.frame.y=target.point.y-rect.height/2;return result}
        return try ContourTypesetter.fit(layer,to:target)
    }
}
