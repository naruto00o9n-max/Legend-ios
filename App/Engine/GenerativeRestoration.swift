import UIKit
import CryptoKit
import ImageIO

/// A second, explicitly chosen hosted engine. Fixed geometry keeps uploads and
/// inference bounded; original-resolution clipping is always performed here.
enum GenerativeRestoration {
    struct Input {let image:Data;let marked:Data;let content:CGRect}
    static func render(_ size:CGSize,_ draw:(CGContext)->Void)->CGImage {
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true;format.preferredRange = .standard
        return UIGraphicsImageRenderer(size:size,format:format).image{draw($0.cgContext)}.cgImage!
    }
    static func prepare(source:CGImage,mask:CGImage)throws->Input {
        guard source.width==mask.width,source.height==mask.height,source.width*source.height<=4_194_304 else{throw LaMaFailure.message("أبعاد منطقة الترميم غير صالحة")}
        let scale=min(480.0/Double(source.width),480.0/Double(source.height)),w=(Double(source.width)*scale).rounded(),h=(Double(source.height)*scale).rounded()
        let rect=CGRect(x:floor((480-w)/2),y:floor((480-h)/2),width:w,height:h)
        guard rect.width>=1,rect.height>=1 else{throw LaMaFailure.message("حدد منطقة أقرب إلى النص")}
        let original=render(CGSize(width:480,height:480)){context in
            UIColor(white:10.0/255,alpha:1).setFill();context.fill(CGRect(x:0,y:0,width:480,height:480));context.interpolationQuality = .high;UIImage(cgImage:source).draw(in:rect)
        }
        let selection=render(CGSize(width:480,height:480)){context in UIColor.black.setFill();context.fill(CGRect(x:0,y:0,width:480,height:480));context.interpolationQuality = .none;UIImage(cgImage:mask).draw(in:rect)}
        var bytes=try BigLaMaSession.rgba(original);let ink=try BigLaMaSession.rgba(selection)
        for i in 0..<(480*480) where ink[i*4]>0{bytes[i*4]=255;bytes[i*4+1]=0;bytes[i*4+2]=255;bytes[i*4+3]=255}
        guard let marked=ImagePipeline.image(bytes,width:480,height:480),let a=UIImage(cgImage:original).pngData(),let b=UIImage(cgImage:marked).pngData() else{throw LaMaFailure.message("تعذر تجهيز صورة الفقاعة")}
        return Input(image:a,marked:b,content:rect)
    }
    static func finish(_ generated:CGImage,input:Input,source:CGImage,mask:CGImage)throws->CGImage {
        guard generated.width==512,generated.height==512 else{throw LaMaFailure.message("لم تتطابق أبعاد نتيجة الترميم")}
        let small=render(CGSize(width:480,height:480)){context in context.interpolationQuality = .high;UIImage(cgImage:generated).draw(in:CGRect(x:0,y:0,width:480,height:480))}
        guard let crop=small.cropping(to:input.content) else{throw LaMaFailure.message("تعذر محاذاة نتيجة الترميم")}
        let candidate=render(CGSize(width:source.width,height:source.height)){context in context.interpolationQuality = .high;UIImage(cgImage:crop).draw(in:CGRect(x:0,y:0,width:source.width,height:source.height))}
        try Task.checkCancellation()
        guard let patch=CookiesMatchRestoration(UIImage(cgImage:source),UIImage(cgImage:candidate),UIImage(cgImage:mask))?.cgImage else{throw LaMaFailure.message("تعذر دمج الخلفية بأمان؛ حدد منطقة نص داخل الفقاعة وبعيدة عن الحواف")}
        return try CloudRestoration.clipped(patch,mask:mask)
    }
    static func repair(source:CGImage,mask:CGImage,endpoint override:URL?=nil,session supplied:URLSession?=nil)async throws->CGImage {
        guard let endpoint=override ?? CloudRestoration.endpoint else{throw LaMaFailure.message("خدمة الذكاء الاصطناعي غير مهيأة")}
        try Task.checkCancellation();let input=try prepare(source:source,mask:mask),boundary="Cookies-"+UUID().uuidString
        var body=Data()
        for (name,bytes) in [("image",input.image),("marked",input.marked)]{guard bytes.count<=700_000 else{throw LaMaFailure.message("المنطقة معقدة للإرسال؛ حدد مساحة أقرب للنص")};body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"region.png\"\r\nContent-Type: image/png\r\n\r\n".utf8));body.append(bytes);body.append(Data("\r\n".utf8))}
        body.append(Data("--\(boundary)--\r\n".utf8))
        var request=URLRequest(url:endpoint.appendingPathComponent("v1/reconstruct"));request.httpMethod="POST";request.httpBody=body;request.timeoutInterval=180
        request.setValue("multipart/form-data; boundary=\(boundary)",forHTTPHeaderField:"Content-Type");request.setValue("no-store",forHTTPHeaderField:"Cache-Control");request.setValue("CookiesEditor/1.1",forHTTPHeaderField:"User-Agent")
        let session=supplied ?? URLSession(configuration:.ephemeral,delegate:RestorationRedirectPolicy(),delegateQueue:nil);defer{if supplied==nil{session.finishTasksAndInvalidate()}}
        let data:Data,response:URLResponse
        do{(data,response)=try await session.data(for:request)}catch{if Task.isCancelled{throw CancellationError()};throw LaMaFailure.message("تعذر الاتصال بخدمة إعادة البناء. تحقق من الإنترنت")}
        try Task.checkCancellation()
        guard let http=response as? HTTPURLResponse else{throw LaMaFailure.message("تعذر قراءة نتيجة الترميم")}
        let reason=(try? JSONSerialization.jsonObject(with:data) as? [String:String])?["error"]
        if reason=="provider_account_capacity_reached"{throw LaMaFailure.message("توقفت استضافة هذا الأسلوب عند حد حساب الخدمة، وليس حد استخدامك الشخصي. اختر «ترميم بديل مجاني» أو «ترميم متوازن»")}
        if http.statusCode==429{
            let message:String
            switch reason{case "client_daily_capacity_reached":message="بلغ هذا الاتصال حد الاستخدام اليومي لهذا الأسلوب؛ يمكنك اختيار الترميم البديل المجاني أو المتوازن";case "service_monthly_capacity_reached":message="بلغت الخدمة ميزانية الاستضافة الشهرية؛ يمكنك اختيار الترميم البديل المجاني أو المتوازن";case "service_daily_capacity_reached","daily_capacity_reached":message="بلغت الخدمة سعتها المشتركة اليوم؛ يمكنك اختيار الترميم البديل المجاني أو المتوازن";default:message="الخدمة مشغولة بفقاعة أخرى؛ أعد المحاولة بعد قليل"}
            throw LaMaFailure.message(message)
        }
        guard http.statusCode==200 else{throw LaMaFailure.message("تعذر إكمال إعادة البناء الآن. جرّب الترميم المتوازن؛ لم تتغير الصورة الأصلية")}
        let digest=SHA256.hash(data:input.image).map{String(format:"%02x",$0)}.joined()
        guard data.count<=8_000_000,http.value(forHTTPHeaderField:"X-Cookies-Source-SHA256")==digest,let container=CGImageSourceCreateWithData(data as CFData,nil),CGImageSourceGetCount(container)==1,let info=CGImageSourceCopyPropertiesAtIndex(container,0,nil) as? [CFString:Any],(info[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue==512,(info[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue==512,let generated=CGImageSourceCreateImageAtIndex(container,0,nil) else{throw LaMaFailure.message("لم تتطابق نتيجة الترميم؛ رُفضت لحماية الصورة")}
        return try finish(generated,input:input,source:source,mask:mask)
    }
}
