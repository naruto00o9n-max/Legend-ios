import Foundation
import Combine
import CryptoKit

enum LaMaFailure:LocalizedError {
    case message(String)
    var errorDescription:String?{if case .message(let value)=self{return value};return nil}
}
struct BigLaMaSpecification:Codable {
    struct Asset:Codable{let path:String;let size:Int64;let sha256:String}
    let revision:String,repository:String,upstream:String,license:String
    let width:Int,height:Int
    let files:[Asset]
    static func bundled()throws->Self{
        guard let url=Bundle.main.url(forResource:"big-lama-model",withExtension:"json") else{throw LaMaFailure.message("تعذر العثور على بيانات نموذج الترميم")}
        let value=try JSONDecoder().decode(Self.self,from:Data(contentsOf:url))
        guard value.width==512,value.height==512,value.files.count==1,value.files.allSatisfy({!$0.path.hasPrefix("/") && !$0.path.split(separator:"/").contains("..") && $0.size>0 && $0.sha256.count==64}) else{throw LaMaFailure.message("بيانات نموذج الترميم غير صالحة")}
        return value
    }
    var downloadSize:Int64{files.reduce(0){$0+$1.size}}
    func url(_ file:Asset)->URL{URL(string:"https://huggingface.co/\(repository)/resolve/\(revision)/\(file.path)")!}
}
private final class LaMaTransferProgress:NSObject,URLSessionDownloadDelegate,@unchecked Sendable {
    let changed:@Sendable(Double)->Void
    private let lock=NSLock()
    private var last = -1
    init(changed:@escaping @Sendable(Double)->Void){self.changed=changed}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL){}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64){
        guard totalBytesExpectedToWrite>0 else{return};let fraction=min(1,Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)),percent=Int(fraction*100)
        lock.lock();let publish=percent != last;last=percent;lock.unlock();if publish{changed(fraction)}
    }
}
@MainActor final class BigLaMaAssets:ObservableObject {
    static let shared=BigLaMaAssets()
    let root:URL
    @Published private(set) var ready=false
    @Published private(set) var installing=false
    @Published private(set) var progress=0.0
    @Published private(set) var phase=""
    @Published private(set) var activeUses=0
    @Published private(set) var removing=false
    @Published private(set) var failure:String?
    private var installation:Task<Void,Never>?
    private var generation=UUID()
    init(root:URL?=nil){self.root=root ?? FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("CookiesModels/BigLaMa");refresh()}
    var compiled:URL{root.appendingPathComponent("big-lama.onnx")}
    private var receipt:URL{root.appendingPathComponent("verified-revision.txt")}
    func refresh(){guard let spec=try? BigLaMaSpecification.bundled() else{ready=false;return};ready=(try? String(contentsOf:receipt,encoding:.utf8))==spec.revision && FileManager.default.fileExists(atPath:compiled.path)}
    func acquire()throws->URL{refresh();guard ready,!installing,!removing else{throw LaMaFailure.message("نزّل نموذج Big LaMa أولًا من إعدادات التبييض")};activeUses+=1;return compiled}
    func release(){activeUses=max(0,activeUses-1)}
    func startInstallation(){guard installation==nil,!installing,!removing else{return};failure=nil;installation=Task{defer{installation=nil};do{_ = try await install()}catch is CancellationError{}catch{if !Task.isCancelled{failure=error.localizedDescription}}}}
    func cancelInstallation(){installation?.cancel()}
    @discardableResult func install()async throws->URL{
        refresh();if ready{return compiled}
        guard !installing,!removing else{throw LaMaFailure.message("انتظر اكتمال إدارة ملفات النموذج")}
        let spec=try BigLaMaSpecification.bundled(),fm=FileManager.default,folder=root.appendingPathComponent("prepare-\(UUID())"),package=folder.appendingPathComponent("Payload")
        let token=UUID();generation=token;installing=true;progress=0;phase="تنزيل النموذج"
        defer{installing=false;try? fm.removeItem(at:folder)}
        try fm.createDirectory(at:package,withIntermediateDirectories:true)
        let stale=(try fm.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)).filter{$0.lastPathComponent.hasPrefix("prepare-") && $0 != folder}
        try await BackgroundWork.run{for item in stale{try fm.removeItem(at:item)}}
        try Task.checkCancellation()
        if let available=try? root.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,available<spec.downloadSize*2{throw LaMaFailure.message("لا تتوفر مساحة كافية لتنزيل النموذج وتهيئته. أفرغ نحو 420 ميغابايت ثم حاول مجددًا")}
        var completed:Int64=0
        for asset in spec.files{
            try Task.checkCancellation();let start=completed,total=spec.downloadSize
            let delegate=LaMaTransferProgress{[weak self] value in Task{@MainActor in guard let self,self.generation==token,self.installing else{return};self.progress=max(self.progress,(Double(start)+value*Double(asset.size))/Double(total))}}
            var request=URLRequest(url:spec.url(asset));request.timeoutInterval=180
            let (temporary,response)=try await URLSession.shared.download(for:request,delegate:delegate)
            guard (response as? HTTPURLResponse)?.statusCode==200 else{try? fm.removeItem(at:temporary);throw LaMaFailure.message("تعذر تنزيل ملف النموذج؛ حاول مجددًا")}
            let destination=package.appendingPathComponent(asset.path);try fm.createDirectory(at:destination.deletingLastPathComponent(),withIntermediateDirectories:true);try fm.moveItem(at:temporary,to:destination)
            phase="التحقق من سلامة النموذج"
            try await BackgroundWork.run{guard try Self.check(destination,asset:asset) else{throw LaMaFailure.message("لم يتطابق ملف النموذج مع النسخة المعتمدة")}}
            completed+=asset.size;progress=Double(completed)/Double(total);phase="تنزيل النموذج"
        }
        try Task.checkCancellation();phase="تهيئة النموذج للجهاز"
        let result=package.appendingPathComponent(spec.files[0].path)
        defer{try? fm.removeItem(at:result)}
        try Task.checkCancellation()
        if fm.fileExists(atPath:compiled.path){try fm.removeItem(at:compiled)}
        try fm.moveItem(at:result,to:compiled);try spec.revision.write(to:receipt,atomically:true,encoding:.utf8)
        let obsolete=root.appendingPathComponent("LaMa.mlmodelc");try? await BackgroundWork.run{if fm.fileExists(atPath:obsolete.path){try fm.removeItem(at:obsolete)}}
        progress=1;phase="النموذج جاهز";refresh();return compiled
    }
    func remove()async throws{
        guard !installing,!removing,activeUses==0 else{throw LaMaFailure.message("انتظر انتهاء معالجة النموذج")}
        removing=true;defer{removing=false};let directory=root;try await BackgroundWork.run{if FileManager.default.fileExists(atPath:directory.path){try FileManager.default.removeItem(at:directory)}};ready=false;progress=0;phase=""
    }
    /// Cache cleanup must await cancellation before deleting model downloads.
    /// Otherwise an in-flight compilation could recreate files after full reset.
    func beginCacheCleanup()async throws{
        guard !removing,activeUses==0 else{throw LaMaFailure.message("انتظر انتهاء ترميم الفقاعات قبل تنظيف ملفات النموذج")}
        removing=true
        installation?.cancel()
        if let installation{await installation.value}
        guard !installing else{removing=false;throw LaMaFailure.message("انتظر انتهاء تهيئة النموذج")}
    }
    func endCacheCleanup(){removing=false;failure=nil;progress=0;phase="";refresh()}
    nonisolated private static func check(_ url:URL,asset:BigLaMaSpecification.Asset)throws->Bool{
        guard (try url.resourceValues(forKeys:[.fileSizeKey])).fileSize==Int(asset.size) else{return false}
        let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()};var hash=SHA256()
        while let bytes=try handle.read(upToCount:1_048_576),!bytes.isEmpty{try Task.checkCancellation();hash.update(data:bytes)}
        return hash.finalize().map{String(format:"%02x",$0)}.joined()==asset.sha256
    }
}
