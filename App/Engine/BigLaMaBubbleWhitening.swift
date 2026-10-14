import UIKit
import Vision

extension BubbleWhitening {
    static func prepareBigLaMa(page:EditorPage,directory:URL,target:SniperTarget,session:()throws->BigLaMaSession)throws->BubbleWhiteningResult {
        guard !target.pin,target.outline.count>=3 else{throw ImageFailure.message("حدد محيط الفقاعة تلقائيًا أو ارسمه يدويًا أولًا")}
        let xs=target.outline.map(\.x),ys=target.outline.map(\.y),box=CGRect(x:xs.min()!,y:ys.min()!,width:xs.max()!-xs.min()!+1,height:ys.max()!-ys.min()!+1)
        let width=min(CGFloat(page.width),max(800,box.width+96)),height=min(CGFloat(page.height),max(800,box.height+96))
        let region=CGRect(x:max(0,min(CGFloat(page.width)-width,box.midX-width/2)),y:max(0,min(CGFloat(page.height)-height,box.midY-height/2)),width:width,height:height).integral
        guard region.width<=4096,region.height<=4096,region.width*region.height<=4_194_304 else{throw ImageFailure.message("حدد فقاعة أصغر للترميم، بدل تحديد مساحة الفصل كله")}
        let bytes=try ImagePipeline.tile(directory.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:region)
        guard let source=ImagePipeline.image(bytes,width:Int(region.width),height:Int(region.height),colorSpace:ImagePipeline.colorSpace(directory.appendingPathComponent(page.source))) else{throw ImageFailure.message("تعذر قراءة منطقة الترميم")}
        let rectangles:[CGRect]
        if !target.manualTextRegions.isEmpty{rectangles=target.manualTextRegions.map{CGRect(x:$0.x-region.minX,y:$0.y-region.minY,width:$0.width,height:$0.height)}}
        else{
            let request=VNDetectTextRectanglesRequest();request.reportCharacterBoxes=true
            try VNImageRequestHandler(cgImage:source,orientation:.up,options:[:]).perform([request])
            rectangles=(request.results ?? []).map{let b=$0.boundingBox;return CGRect(x:b.minX*region.width,y:(1-b.maxY)*region.height,width:b.width*region.width,height:b.height*region.height)}
        }
        let outline=target.outline.map{NSValue(cgPoint:CGPoint(x:$0.x-region.minX,y:$0.y-region.minY))}
        let pad=target.manualTextRegions.isEmpty ? 8.0:3.0
        guard let result=CookiesCreateBubbleTextMask(region.size,outline,rectangles.map{NSValue(cgRect:$0)},pad) as? [String:Any],let mask=(result["mask"] as? UIImage)?.cgImage else{throw ImageFailure.message("لم يتحدد النص بأمان. اختر الفقاعة ثم «تحديد منطقة النص» وارسم حول حروفها")}
        try Task.checkCancellation()
        let patch=try session().repair(source:source,mask:mask)
        try Task.checkCancellation()
        guard let data=UIImage(cgImage:patch).pngData() else{throw ImageFailure.message("تعذر حفظ نتيجة الترميم")}
        let name="bubble-lama-\(UUID()).png";try data.write(to:directory.appendingPathComponent(name),options:.atomic)
        var layer=EditorLayer(kind:.image,name:"ترميم النص الأصلي");layer.imagePath=name;layer.frame=Box(x:region.minX,y:region.minY,width:region.width,height:region.height)
        return BubbleWhiteningResult(layer:layer,reviewRequired:true)
    }
}
