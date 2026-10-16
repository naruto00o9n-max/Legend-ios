import Foundation

/// Journaled directory swaps always recover the original after interruption.
/// The journal is removed only once the verified replacement is installed.
enum VaultFiles {
    struct Transfer:Codable{var owner:String;var revision:UUID}
    static func transfer(_ directory:URL)->URL{directory.appendingPathComponent("vault-transfer.json")}
    struct Swap:Codable{var id:UUID;var old:String;var staged:String}
    static func marker(_ directory:URL)->URL{directory.appendingPathComponent("vault.json")}
    static func receipt(_ directory:URL)throws->VaultReceipt? {
        let file=marker(directory);guard FileManager.default.fileExists(atPath:file.path) else{return nil};return try JSONDecoder().decode(VaultReceipt.self,from:Data(contentsOf:file))
    }
    static func write(_ value:VaultReceipt,directory:URL)throws{try JSONEncoder().encode(value).write(to:marker(directory),options:.atomic)}
    static func replace(_ staged:URL,id:UUID,root:URL)throws {
        let fm=FileManager.default,destination=root.appendingPathComponent(id.uuidString),old=root.appendingPathComponent(".vault-old-"+UUID().uuidString),journal=root.appendingPathComponent(".vault-swap-"+id.uuidString+".json")
        let swap=Swap(id:id,old:old.lastPathComponent,staged:staged.lastPathComponent)
        try JSONEncoder().encode(swap).write(to:journal,options:.atomic)
        do{if fm.fileExists(atPath:destination.path){try fm.moveItem(at:destination,to:old)};try fm.moveItem(at:staged,to:destination);try fm.removeItem(at:journal)}
        catch{if fm.fileExists(atPath:old.path){try? fm.removeItem(at:destination);do{try fm.moveItem(at:old,to:destination);try? fm.removeItem(at:journal)}catch{throw ImageFailure.message("توقفت عملية التخزين. احتُفظ بمجلد الاسترجاع، وسيعاد عند تشغيل التطبيق")}};throw error}
        try? fm.removeItem(at:old)
    }
    static func recover(root:URL)throws {
        let fm=FileManager.default
        for journal in (try? fm.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)) ?? [] where journal.lastPathComponent.hasPrefix(".vault-swap-") && journal.pathExtension=="json" {
            let v=try JSONDecoder().decode(Swap.self,from:Data(contentsOf:journal))
            guard v.old.hasPrefix(".vault-old-"),v.staged.hasPrefix(".vault-stage-"),[v.old,v.staged].allSatisfy({!$0.contains("/") && !$0.contains("..")}) else{throw ImageFailure.message("تعذر قراءة سجل استرجاع المشروع")}
            let destination=root.appendingPathComponent(v.id.uuidString),old=root.appendingPathComponent(v.old)
            // While a journal exists the old directory remains authoritative.
            if fm.fileExists(atPath:old.path){try? fm.removeItem(at:destination);try fm.moveItem(at:old,to:destination)}
            try? fm.removeItem(at:root.appendingPathComponent(v.staged));try fm.removeItem(at:journal)
        }
    }
    static func evict(_ page:EditorPage,project:VaultProject,directory:URL,root:URL)throws {
        let staging=root.appendingPathComponent(".vault-stage-"+UUID().uuidString);let fm=FileManager.default
        try fm.createDirectory(at:staging,withIntermediateDirectories:true);defer{try? fm.removeItem(at:staging)}
        try JSONEncoder().encode(page).write(to:staging.appendingPathComponent("page.json"),options:.atomic)
        let thumbnail=directory.appendingPathComponent("thumbnail.png");if fm.fileExists(atPath:thumbnail.path){try fm.copyItem(at:thumbnail,to:staging.appendingPathComponent("thumbnail.png"))}
        try write(VaultReceipt(project:project,resident:false),directory:staging)
        try replace(staging,id:page.id,root:root)
    }
}

@MainActor final class ProjectVaultStore:ObservableObject {
    weak var service:ReferenceService?
    private weak var owner:LibraryStore?
    private let root:URL
    var suspended=false
    @Published var listing:VaultListing?
    @Published var busy=false
    @Published var progress=0.0
    @Published var activity=""
    @Published var error:String?
    @Published var revision=0
    private var opened=Set<UUID>()
    private var closing:[UUID:Task<Void,Never>]=[:]
    init(library:LibraryStore){owner=library;root=library.root}
    var enabled:Bool{NetworkPolicy.enabled && UserDefaults.standard.bool(forKey:"storage-projects-server")}
    func receipt(_ id:UUID)->VaultReceipt?{try? VaultFiles.receipt(root.appendingPathComponent(id.uuidString))}
    private func client()async throws->(ProjectVaultClient,String){guard let service else{throw ImageFailure.message("اتصال الحساب غير جاهز")};let (token,user)=try await service.projectVaultCredentials();return(ProjectVaultClient(token:token),user)}
    private func checkAccount(_ user:String)throws{guard !suspended,!Task.isCancelled,service?.session?.user.id==user else{throw ImageFailure.message("تغير الحساب أثناء النقل. بقيت نسخة الجهاز محفوظة")}}
    func refresh()async {
        guard !busy,!suspended else{return};busy=true;activity="تحديث المشاريع";defer{busy=false}
        do{let(c,user)=try await client();_ = try await c.request("cleanup",method:"POST",bytes:Data("{}".utf8));let result=try await c.list();try checkAccount(user);listing=result;revision+=1}catch{self.error=error.localizedDescription}
    }
    /// Called before a canvas can read pixels. Opening waits for an earlier close
    /// of the same page, preventing a late upload from removing an active source.
    func open(_ id:UUID)async throws {
        guard !suspended,let library=owner else{throw CancellationError()}
        if let close=closing[id]{await close.value}
        opened.insert(id)
        do{if let receipt=try VaultFiles.receipt(library.directory(id)),!receipt.resident{try await download(receipt.project,installInLibrary:false)}}catch{opened.remove(id);throw error}
    }
    func close(_ id:UUID){
        opened.remove(id)
        guard !suspended,receipt(id)?.managed != false,(enabled || receipt(id) != nil) else{return}
        closing[id]=Task{[weak self] in guard let self else{return};while self.busy{try? await Task.sleep(nanoseconds:100_000_000);if Task.isCancelled{return}};await self.store(id,evict:true);self.closing[id]=nil}
    }
    func store(_ id:UUID,evict:Bool)async {
        guard !busy,!suspended,!opened.contains(id),let library=owner else{return};busy=true;activity="تجهيز المشروع";progress=0;defer{busy=false;revision+=1}
        do{
            let (c,user)=try await client();let remote=try await c.list();try checkAccount(user)
            let directory=library.directory(id),root=library.root
            var old=try VaultFiles.receipt(directory)
            if let data=try? Data(contentsOf:VaultFiles.transfer(directory)),let pending=try? JSONDecoder().decode(VaultFiles.Transfer.self,from:data),pending.owner==remote.owner,let committed=remote.projects.first(where:{$0.project_id==id && $0.revision_id==pending.revision}){
                old=VaultReceipt(project:committed,resident:true);try VaultFiles.write(old!,directory:directory);try? FileManager.default.removeItem(at:VaultFiles.transfer(directory))
            }
            if let old{guard old.project.owner_id==remote.owner else{throw ImageFailure.message("هذا المشروع مرتبط بحساب آخر. افتح الحساب الذي حفظه")};guard old.resident else{return}}
            let page=try library.load(id)
            let (archive,head)=try await BackgroundWork.run{try VaultArchive.create(page,directory:directory)}
            defer{try? FileManager.default.removeItem(at:archive)}
            try checkAccount(user);guard !opened.contains(id),try library.load(id)==page else{throw ImageFailure.message("فُتح المشروع أو تغير أثناء النقل؛ بقي على الجهاز")}
            let expected=old?.project.generation ?? 0,revisionID=UUID()
            let owner=try await c.reserve(id:id,revision:revisionID,expected:expected,head:head);guard owner==remote.owner else{throw ImageFailure.message("لم تتطابق ملكية المشروع")}
            try JSONEncoder().encode(VaultFiles.Transfer(owner:owner,revision:revisionID)).write(to:VaultFiles.transfer(directory),options:.atomic)
            activity="رفع المشروع";try await c.upload(archive,id:id,revision:revisionID,head:head){[weak self] in self?.progress=$0*0.5}
            let saved=try await c.commit(id:id,revision:revisionID)
            guard saved.project_id==id,saved.revision_id==revisionID,saved.generation==expected+1,saved.owner_id==owner,saved.head==head else{throw ImageFailure.message("لم يؤكد الخادم نسخة المشروع الصحيحة")}
            try checkAccount(user);try VaultFiles.write(VaultReceipt(project:saved,resident:true),directory:directory);try? FileManager.default.removeItem(at:VaultFiles.transfer(directory))
            activity="التحقق من النسخة المحفوظة";try await c.verify(saved){[weak self] in self?.progress=0.5+$0*0.5}
            try checkAccount(user)
            let confirmed=try await c.list();try checkAccount(user);guard confirmed.projects.contains(saved) else{throw ImageFailure.message("تغيرت نسخة الخادم بعد الرفع؛ احتُفظ بنسختك على الجهاز")}
            guard !opened.contains(id),try library.load(id)==page else{throw ImageFailure.message("تغير المشروع بعد الرفع؛ احتُفظ بالنسخة المحلية لتجنب فقد تعديلاتك")}
            try VaultFiles.write(VaultReceipt(project:saved,resident:true),directory:directory)
            if evict{ImagePipeline.clearMemoryCaches();try VaultFiles.evict(page,project:saved,directory:directory,root:root)}
            listing=confirmed;library.thumbnailRevision+=1
        }catch{self.error=error.localizedDescription}
    }
    func download(_ project:VaultProject,installInLibrary:Bool)async throws {
        guard !suspended,let library=owner else{throw CancellationError()}
        guard !busy else{throw ImageFailure.message("انتظر انتهاء نقل المشروع الحالي")}
        busy=true;activity="تنزيل المشروع";progress=0;defer{busy=false;revision+=1}
        let(c,user)=try await client(),remote=try await c.list();try checkAccount(user)
        guard remote.owner==project.owner_id,remote.projects.contains(project) else{throw ImageFailure.message("تغيرت نسخة المشروع؛ حدّث القائمة ثم أعد المحاولة")}
        let id=project.project_id,directory=library.directory(id),root=library.root
        if FileManager.default.fileExists(atPath:directory.path){guard let old=try VaultFiles.receipt(directory),!old.resident,old.project.owner_id==project.owner_id else{throw ImageFailure.message("توجد نسخة محلية؛ لم تُستبدل تلقائيًا")}}
        let archive=FileManager.default.temporaryDirectory.appendingPathComponent("vault-"+UUID().uuidString+".zip"),staging=root.appendingPathComponent(".vault-stage-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:archive);try? FileManager.default.removeItem(at:staging)}
        try await c.verify(project,output:archive){[weak self] in self?.progress=$0}
        let page=try await BackgroundWork.run{try VaultArchive.unpack(archive,head:project.head,id:id,staging:staging)}
        try checkAccount(user)
        let fontFolder=staging.appendingPathComponent("Fonts"),fonts=(try? FileManager.default.contentsOfDirectory(at:fontFolder,includingPropertiesForKeys:nil)) ?? []
        if !fonts.isEmpty{try FontPackage.importFiles(fonts)}
        try VaultFiles.write(VaultReceipt(project:project,resident:true),directory:staging)
        try VaultFiles.replace(staging,id:id,root:root)
        if installInLibrary,!library.items.contains(where:{$0.pages.contains(id)}){guard library.add(page,parent:nil) else{throw ImageFailure.message("تم التنزيل لكن تعذر تحديث المعرض؛ أعد المحاولة")}}
        library.thumbnailRevision+=1
    }
    func keepOnDevice(_ id:UUID)async {
        guard !suspended,let library=owner else{return}
        do{if let receipt=try VaultFiles.receipt(library.directory(id)),!receipt.resident{try await download(receipt.project,installInLibrary:false)};guard !busy,var receipt=try VaultFiles.receipt(library.directory(id)) else{return};receipt.managed=false;try VaultFiles.write(receipt,directory:library.directory(id));revision+=1}catch{self.error=error.localizedDescription}
    }
    func removeRemote(_ project:VaultProject)async {
        guard !busy,!suspended,!opened.contains(project.id),let library=owner else{return}
        do{
            let directory=library.directory(project.id)
            if !FileManager.default.fileExists(atPath:directory.path){try await download(project,installInLibrary:true)}
            else if let receipt=try VaultFiles.receipt(directory),!receipt.resident{try await download(project,installInLibrary:false)}
            busy=true;activity="حذف نسخة الخادم";defer{busy=false;revision+=1}
            let(c,user)=try await client(),remote=try await c.list();try checkAccount(user)
            guard remote.owner==project.owner_id,remote.projects.contains(project) else{throw ImageFailure.message("تغير المشروع؛ حدّث القائمة قبل الحذف")}
            try await c.remove(project);try checkAccount(user)
            var baseline=project;baseline.generation=0
            try VaultFiles.write(VaultReceipt(project:baseline,resident:true,managed:false),directory:directory)
            listing=try await c.list()
        }catch{self.error=error.localizedDescription}
    }

}
