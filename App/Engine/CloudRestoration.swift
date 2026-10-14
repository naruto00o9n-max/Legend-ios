import Foundation
import UIKit
import CryptoKit
import ImageIO

private final class RestorationRedirectPolicy:NSObject,URLSessionTaskDelegate,@unchecked Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){
        completionHandler(request.url?.scheme=="https" && request.url?.host==task.originalRequest?.url?.host ? request:nil)
    }
}
enum CloudRestoration {
    struct Configuration:Decodable{let endpoint:String}
    static let endpoint:URL?={
        guard let file=Bundle.main.url(forResource:"RestorationService",withExtension:"json"),let data=try? Data(contentsOf:file),let config=try? JSONDecoder().decode(Configuration.self,from:data),let url=URL(string:config.endpoint),url.scheme=="https",url.host != nil else{return nil}
        return url
    }()
    static var configured:Bool{endpoint != nil}
    /// Called only for an explicitly selected cloud target. No whole chapter,
    /// user filename, account credential, or model download is sent.
    static func repair(source:CGImage,mask:CGImage,endpoint override:URL?=nil,session supplied:URLSession?=nil)async throws->CGImage{
        guard let endpoint=override ?? Self.endpoint else{throw LaMaFailure.message("خدمة الترميم السحابي غير مهيأة في هذه النسخة")}
        guard source.width==mask.width,source.height==mask.height,source.width*source.height<=4_194_304,let image=UIImage(cgImage:source).pngData(),let selection=UIImage(cgImage:mask).pngData() else{throw LaMaFailure.message("تعذر تجهيز منطقة النص للترميم")}
        let digest=SHA256.hash(data:image).map{String(format:"%02x",$0)}.joined(),boundary="Cookies-\(UUID().uuidString)"
        var body=Data()
        for (name,bytes) in [("image",image),("mask",selection)]{
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(name).png\"\r\nContent-Type: image/png\r\n\r\n".utf8));body.append(bytes);body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))
        guard body.count<=20_000_000 else{throw LaMaFailure.message("منطقة الفقاعة كبيرة للإرسال؛ حدد مساحة أصغر حول النص")}
        var request=URLRequest(url:endpoint.appendingPathComponent("v1/restore"));request.httpMethod="POST";request.httpBody=body;request.timeoutInterval=180
        request.setValue("multipart/form-data; boundary=\(boundary)",forHTTPHeaderField:"Content-Type");request.setValue("no-store",forHTTPHeaderField:"Cache-Control");request.setValue("CookiesEditor/1.1",forHTTPHeaderField:"User-Agent")
        let session=supplied ?? URLSession(configuration:.ephemeral,delegate:RestorationRedirectPolicy(),delegateQueue:nil)
        defer{if supplied==nil{session.finishTasksAndInvalidate()}}
        let data:Data,response:URLResponse
        do{(data,response)=try await session.data(for:request)}catch is CancellationError{throw CancellationError()}catch{
            if Task.isCancelled{throw CancellationError()}
            throw LaMaFailure.message("تعذر الاتصال بخدمة الترميم. تحقق من الإنترنت، أو اختر التنفيذ على الجهاز")
        }
        try Task.checkCancellation()
        guard let http=response as? HTTPURLResponse,http.statusCode==200 else{
            let code=(response as? HTTPURLResponse)?.statusCode
            let reason=(try? JSONSerialization.jsonObject(with:data) as? [String:String])?["error"]
            if code==429{throw LaMaFailure.message(reason=="daily_capacity_reached" ? "بلغت الخدمة سعتها المؤقتة لليوم. يمكنك استخدام الترميم المحلي أو المحاولة لاحقًا":"الخدمة تعالج فقاعة أخرى حاليًا. انتظر بضع ثوانٍ ثم أعد المحاولة")}
            throw LaMaFailure.message("تعذر إكمال الترميم السحابي الآن. لم تتغير الصورة الأصلية")
        }
        guard data.count<=20_000_000,http.value(forHTTPHeaderField:"X-Cookies-Source-SHA256")==digest,let container=CGImageSourceCreateWithData(data as CFData,nil),CGImageSourceGetCount(container)==1,let info=CGImageSourceCopyPropertiesAtIndex(container,0,nil) as? [CFString:Any],(info[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue==source.width,(info[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue==source.height,let result=CGImageSourceCreateImageAtIndex(container,0,nil) else{throw LaMaFailure.message("لم تتطابق نتيجة الترميم مع منطقة الصورة المرسلة؛ رُفضت لحماية عملك")}
        return try clipped(result,mask:mask)
    }
    /// Re-apply the trusted local mask even if a remote response has an opaque
    /// background. Outside-mask source pixels cannot be replaced by the server.
    static func clipped(_ result:CGImage,mask:CGImage)throws->CGImage{
        guard result.width==mask.width,result.height==mask.height else{throw LaMaFailure.message("أبعاد رقعة الترميم غير صالحة")}
        var bytes=try BigLaMaSession.rgba(result);let ink=try BigLaMaSession.rgba(mask)
        for i in 0..<(result.width*result.height){let p=i*4;if ink[p]==0{for c in 0..<4{bytes[p+c]=0}}else{bytes[p+3]=255}}
        guard let provider=CGDataProvider(data:Data(bytes) as CFData),let patch=CGImage(width:result.width,height:result.height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:result.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent) else{throw LaMaFailure.message("تعذر قراءة رقعة الترميم")}
        return patch
    }
}
