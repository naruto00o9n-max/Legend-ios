import Foundation
import CryptoKit

struct VaultProject:Codable,Equatable,Identifiable {
    var owner_id:String;var project_id:UUID;var revision_id:UUID;var generation:Int;var head:VaultHead
    var id:UUID{project_id}
}
struct VaultListing:Decodable {var owner:String;var projects:[VaultProject];var used:Int64;var limit:Int64}
struct VaultReceipt:Codable,Equatable {
    var project:VaultProject
    var resident:Bool
    var managed:Bool?
}
struct ProjectVaultClient {
    static let serviceURL=URL(string:"https://ilagswvocznnrrreiswq.supabase.co/functions/v1/project-vault/")!
    var token:String
    var transport=URLSession.shared
    var endpoint=ProjectVaultClient.serviceURL
    func request(_ path:String,method:String="GET",bytes:Data?=nil)async throws->Data {
        try Task.checkCancellation()
        var r=URLRequest(url:endpoint.appendingPathComponent(path));r.httpMethod=method;r.timeoutInterval=90;r.cachePolicy = .reloadIgnoringLocalCacheData;r.setValue("Bearer "+token,forHTTPHeaderField:"Authorization");r.setValue(path.hasPrefix("chunk/") ? "application/octet-stream":"application/json",forHTTPHeaderField:"Content-Type");r.httpBody=bytes
        let (data,response)=try await transport.data(for:r)
        guard let http=response as? HTTPURLResponse else{throw ImageFailure.message("تعذر قراءة استجابة حفظ المشاريع")}
        guard (200..<300).contains(http.statusCode) else{
            switch http.statusCode {
            case 401,403:throw ImageFailure.message("انتهت جلسة الحساب؛ سجّل الدخول مجددًا. لم تُحذف ملفات جهازك")
            case 409:throw ImageFailure.message("تغيّرت نسخة المشروع في الخادم؛ حدّث القائمة قبل المتابعة. بقيت نسختك على جهازك")
            case 413,507:throw ImageFailure.message("بلغت مساحة الحفظ أو حجم المشروع الحد المتاح. بقي المشروع على جهازك")
            default:throw ImageFailure.message("تعذر إتمام حفظ المشروع أو تنزيله (\(http.statusCode)). احتُفظ بملفات جهازك")
            }
        }
        return data
    }
    func list()async throws->VaultListing{try JSONDecoder().decode(VaultListing.self,from:await request("list"))}
    func reserve(id:UUID,revision:UUID,expected:Int,head:VaultHead)async throws->String {
        let bytes=try JSONSerialization.data(withJSONObject:["project":id.uuidString.lowercased(),"revision":revision.uuidString.lowercased(),"expected":expected,"head":JSONSerialization.jsonObject(with:JSONEncoder().encode(head))])
        let data=try await request("reserve",method:"POST",bytes:bytes)
        guard let object=try JSONSerialization.jsonObject(with:data) as? [String:String],let owner=object["owner"],UUID(uuidString:owner) != nil else{throw ImageFailure.message("لم يؤكد الخادم ملكية المشروع")};return owner
    }
    func commit(id:UUID,revision:UUID)async throws->VaultProject {
        let body=try JSONSerialization.data(withJSONObject:["project":id.uuidString.lowercased(),"revision":revision.uuidString.lowercased()])
        return try JSONDecoder().decode(VaultProject.self,from:await request("commit",method:"POST",bytes:body))
    }
    func remove(_ project:VaultProject)async throws {
        let body=try JSONSerialization.data(withJSONObject:["project":project.project_id.uuidString.lowercased(),"expected":project.generation])
        _ = try await request("delete",method:"POST",bytes:body)
    }
    func upload(_ archive:URL,id:UUID,revision:UUID,head:VaultHead,progress:@escaping @MainActor (Double)->Void)async throws {
        let handle=try FileHandle(forReadingFrom:archive);defer{try? handle.close()}
        for (index,chunk) in head.chunks.enumerated(){try Task.checkCancellation();guard let data=try handle.read(upToCount:chunk.bytes),data.count==chunk.bytes,Self.hash(data)==chunk.sha256 else{throw ImageFailure.message("تغير ملف النقل؛ احتُفظ بالمشروع على الجهاز")}
            _ = try await request("chunk/\(id.uuidString.lowercased())/\(revision.uuidString.lowercased())/\(index)",method:"PUT",bytes:data);await progress(Double(index+1)/Double(head.chunks.count))
        }
    }
    /// Reads every saved byte back from private storage before permitting eviction.
    /// Verification is streamed, so it needs no second archive or full-size bitmap.
    func verify(_ project:VaultProject,output:URL?=nil,progress:@escaping @MainActor (Double)->Void={_ in})async throws {
        try project.head.validate();var hash=SHA256()
        var handle:FileHandle?
        if let output{FileManager.default.createFile(atPath:output.path,contents:nil);handle=try FileHandle(forWritingTo:output)}
        defer{try? handle?.close()}
        for (i,chunk) in project.head.chunks.enumerated(){let data=try await request("chunk/\(project.project_id.uuidString.lowercased())/\(project.revision_id.uuidString.lowercased())/\(i)");guard data.count==chunk.bytes,Self.hash(data)==chunk.sha256 else{throw ImageFailure.message("فشل التحقق من أحد أجزاء المشروع؛ بقي الأصل على الجهاز")};hash.update(data:data);try handle?.write(contentsOf:data);await progress(Double(i+1)/Double(project.head.chunks.count))}
        guard hash.finalize().map({String(format:"%02x",$0)}).joined()==project.head.sha256 else{throw ImageFailure.message("فشل التحقق من سلامة المشروع")}
    }
    static func hash(_ bytes:Data)->String{SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined()}
}
extension ReferenceService {
    func projectVaultCredentials()async throws->(String,String) {
        guard NetworkPolicy.enabled,session != nil else{throw ImageFailure.message("سجّل الدخول إلى حسابك لاستخدام حفظ المشاريع")}
        let data=try await request("/auth/v1/user",authenticated:true)
        let user=try JSONDecoder().decode(ServiceUser.self,from:data)
        guard let session,session.user.id==user.id else{throw ImageFailure.message("تغير الحساب أثناء الاتصال؛ أعد المحاولة")};return(session.access_token,user.id)
    }
}
