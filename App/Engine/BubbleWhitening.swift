import UIKit
import Vision

struct BubbleWhiteningResult {
    var layer:EditorLayer
    var reviewRequired:Bool
}
enum BubbleWhitening {
    static func prepare(page:EditorPage,directory:URL,target:SniperTarget)throws->BubbleWhiteningResult {
        guard !target.pin,target.outline.count>=3 else{throw ImageFailure.message("تحتاج هذه الفقاعة إلى محيط مغلق لحماية حدودها")}
        let xs=target.outline.map(\.x),ys=target.outline.map(\.y)
        let region=CGRect(x:xs.min()!,y:ys.min()!,width:xs.max()!-xs.min()!+1,height:ys.max()!-ys.min()!+1).insetBy(dx:-3,dy:-3).integral.intersection(CGRect(x:0,y:0,width:page.width,height:page.height))
        guard region.width*region.height<=4_194_304,region.width>=24,region.height>=24 else{throw ImageFailure.message("حدّد فقاعة أصغر للمعالجة")}
        let source=try ImagePipeline.tile(directory.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:region)
        guard let image=ImagePipeline.image(source,width:Int(region.width),height:Int(region.height),colorSpace:ImagePipeline.colorSpace(directory.appendingPathComponent(page.source))) else{throw ImageFailure.message("تعذر قراءة الفقاعة")}
        let outline=target.outline.map{NSValue(cgPoint:CGPoint(x:$0.x-region.minX,y:$0.y-region.minY))}
        // Text localization runs locally on the bounded source region. No account
        // or OCR upload is used; unfamiliar scripts retain a conservative fallback.
        let request=VNDetectTextRectanglesRequest();request.reportCharacterBoxes=true
        try? VNImageRequestHandler(cgImage:image,orientation:.up,options:[:]).perform([request])
        let rectangles=(request.results ?? []).map{observation -> NSValue in
            let b=observation.boundingBox
            return NSValue(cgRect:CGRect(x:b.minX*region.width,y:(1-b.maxY)*region.height,width:b.width*region.width,height:b.height*region.height))
        }
        let bitmap=UIImage(cgImage:image)
        var analyzed=CookiesWhitenBubble(bitmap,outline,rectangles) as? [String:Any]
        if analyzed==nil,!rectangles.isEmpty{
            // Vision may detect only part of a glyph or an unrelated shape.
            // The native fallback independently requires a flat white interior
            // and a coherent glyph cluster; colored artwork still fails closed.
            analyzed=CookiesWhitenBubble(bitmap,outline,[]) as? [String:Any]
        }
        guard let result=analyzed,let patch=result["patch"] as? UIImage,let data=patch.pngData() else{throw ImageFailure.message("لم يمكن فصل النص بأمان عن الرسم؛ استخدم التنظيف اليدوي لهذه الفقاعة")}
        let name="bubble-clean-\(UUID().uuidString).png";try data.write(to:directory.appendingPathComponent(name),options:.atomic)
        var layer=EditorLayer(kind:.image,name:"تبييض النص الأصلي");layer.imagePath=name;layer.frame=Box(x:region.minX,y:region.minY,width:region.width,height:region.height)
        return BubbleWhiteningResult(layer:layer,reviewRequired:(result["reviewRequired"] as? Bool) ?? true)
    }
}
