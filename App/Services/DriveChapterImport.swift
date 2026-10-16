import Foundation
import ImageIO

struct DriveImage:Identifiable,Equatable {var id:String;var name:String;var resourceKey:String?}
/// Public links only. Private Drive documents stay behind Google's own Files
/// provider; no shared developer credentials or private OAuth client is used.
enum DriveChapterImport {
    enum Link:Equatable {case folder(String,String?),file(String,String?)}
    static func link(_ text:String)throws->Link{
        guard let url=URL(string:text.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="https",url.host?.lowercased()=="drive.google.com" else{throw ImageFailure.message("ألصق رابط Google Drive صالحًا يبدأ بـ https")}
        let parts=url.pathComponents,query=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems ?? [],key=query.first{$0.name=="resourcekey"}?.value
        func valid(_ id:String)->Bool{id.count>=10 && id.count<=200 && id.allSatisfy{$0.isASCII && ($0.isLetter || $0.isNumber || $0=="_" || $0=="-")}}
        if let i=parts.firstIndex(of:"folders"),parts.indices.contains(i+1),valid(parts[i+1]){return .folder(parts[i+1],key)}
        if let i=parts.firstIndex(of:"d"),parts.indices.contains(i+1),valid(parts[i+1]){return .file(parts[i+1],key)}
        if let id=query.first(where:{$0.name=="id"})?.value,valid(id){return .file(id,key)}
        throw ImageFailure.message("لم أجد ملفًا أو مجلدًا في هذا الرابط")
    }
    static func images(in html:String)throws->[DriveImage]{
        let pattern=#"window\['_DRIVE_ivd'\]\s*=\s*'((?:\\.|[^'\\])*)';"#
        let expression=try NSRegularExpression(pattern:pattern),range=NSRange(html.startIndex...,in:html)
        guard let match=expression.firstMatch(in:html,range:range),let capture=Range(match.range(at:1),in:html) else{throw ImageFailure.message("هذا المجلد غير متاح برابط عام. افتحه من Google Drive في «الملفات» أو فعّل مشاركة الرابط")}
        var literal=String(html[capture])
        let hex=try NSRegularExpression(pattern:#"\\x([0-9a-fA-F]{2})"#)
        for m in hex.matches(in:literal,range:NSRange(literal.startIndex...,in:literal)).reversed(){guard let full=Range(m.range,in:literal),let value=Range(m.range(at:1),in:literal) else{continue};let replacement="\\u00"+literal[value];literal.replaceSubrange(full,with:replacement)}
        literal=literal.replacingOccurrences(of:"\\'",with:"'")
        guard let decoded=try JSONSerialization.jsonObject(with:Data(("\""+literal+"\"").utf8),options:.fragmentsAllowed) as? String,let root=try JSONSerialization.jsonObject(with:Data(decoded.utf8)) as? [Any],let rows=root.first as? [[Any]] else{throw ImageFailure.message("تغيرت صيغة رابط Drive؛ استخدم الاستيراد من «الملفات»")}
        // Public HTML can truncate large directories. Never silently import an
        // incomplete chapter; the authenticated provider can select all files.
        guard rows.count<50 else{throw ImageFailure.message("المجلد كبير وقد يخفي Drive بعض صفحاته. اختر صوره كاملة من Google Drive في «الملفات»")}
        var seen=Set<String>()
        let result=rows.compactMap{row->DriveImage? in
            guard row.count>3,let id=row[0] as? String,let name=row[2] as? String,let mime=row[3] as? String,mime.hasPrefix("image/"),id.count<=200,id.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber || $0=="-" || $0=="_")}),seen.insert(id).inserted else{return nil}
            return DriveImage(id:id,name:name)
        }.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
        guard !result.isEmpty else{throw ImageFailure.message("المجلد لا يحتوي صورًا متاحة مباشرة. للمجلدات الخاصة استخدم Google Drive في «الملفات»")};return result
    }
    static func list(_ link:Link)async throws->[DriveImage]{
        switch link{
        case let .file(id,key):return [DriveImage(id:id,name:"",resourceKey:key)]
        case let .folder(id,key):
            var components=URLComponents(string:"https://drive.google.com/drive/folders/"+id)!
            if let key{components.queryItems=[URLQueryItem(name:"resourcekey",value:key)]}
            var request=URLRequest(url:components.url!);request.timeoutInterval=35
            let(stream,response)=try await URLSession.shared.bytes(for:request)
            guard let http=response as? HTTPURLResponse,http.statusCode==200 else{throw ImageFailure.message("تعذر فتح المجلد؛ تحقق من صلاحية مشاركة الرابط")}
            var data=Data();for try await byte in stream{if data.count>=4*1024*1024{throw ImageFailure.message("صفحة Drive أكبر من الحد الآمن؛ استخدم «الملفات»")};data.append(byte)}
            return try images(in:String(decoding:data,as:UTF8.self))
        }
    }
    static func download(_ image:DriveImage,into folder:URL)async throws->URL{
        var components=URLComponents(string:"https://drive.google.com/uc")!;components.queryItems=[URLQueryItem(name:"export",value:"download"),URLQueryItem(name:"id",value:image.id)]
        if let key=image.resourceKey{components.queryItems?.append(URLQueryItem(name:"resourcekey",value:key))}
        var request=URLRequest(url:components.url!);request.timeoutInterval=60
        let(file,response)=try await URLSession.shared.download(for:request);defer{try? FileManager.default.removeItem(at:file)}
        guard let http=response as? HTTPURLResponse,http.statusCode==200,let source=CGImageSourceCreateWithURL(file as CFURL,nil),CGImageSourceGetCount(source)>0 else{throw ImageFailure.message("تعذر تنزيل «"+(image.name.isEmpty ? "الصورة":image.name)+"». قد تتطلب تسجيل الدخول أو تجاوزت حصة Drive")}
        let size=try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size>0,size<=64*1024*1024 else{throw ImageFailure.message("الصورة أكبر من 64 ميغابايت")}
        let name=(image.name.isEmpty ? response.suggestedFilename ?? "صورة.jpg":image.name).replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"\\",with:"_")
        let directory=folder.appendingPathComponent(image.id);try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let target=directory.appendingPathComponent(name);try FileManager.default.moveItem(at:file,to:target);return target
    }
}
