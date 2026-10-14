import Foundation

extension LibraryStore {
    var trashRoots:[LibraryItem]{trashedItems.filter{($0.trashGroup ?? $0.id)==$0.id}.sorted{($0.deletedAt ?? .distantPast)>($1.deletedAt ?? .distantPast)}}
    func trashMembers(_ id:UUID)->[LibraryItem]{trashedItems.filter{($0.trashGroup ?? $0.id)==id}}
    func restoreTrash(_ groups:Set<UUID>)throws {
        guard !purgingTrash else{throw ImageFailure.message("انتظر اكتمال الحذف النهائي")}
        var restored=trashedItems.filter{groups.contains($0.trashGroup ?? $0.id)}
        guard !restored.isEmpty else{return}
        guard !restored.contains(where:{$0.purgePending==true}) else{throw ImageFailure.message("بدأ حذف هذه الملفات نهائيًا؛ لا يمكن استعادتها")}
        for id in Set(restored.flatMap(\.pages)){guard FileManager.default.fileExists(atPath:directory(id).appendingPathComponent("page.json").path) else{throw ImageFailure.message("ملف صفحة مفقود؛ لم تتغير السلة")}}
        let present=Set(items.map(\.id)).union(restored.map(\.id))
        for index in restored.indices{if let parent=restored[index].parent,!present.contains(parent){restored[index].parent=nil};restored[index].deletedAt=nil;restored[index].trashGroup=nil;restored[index].purgePending=nil}
        let next=items+restored,trash=trashedItems.filter{!groups.contains($0.trashGroup ?? $0.id)}
        try writeLibrary(active:next,trash:trash);items=next;trashedItems=trash
    }
    /// The irreversible intent is durable before any bytes are removed. If a
    /// deletion or the final index write fails, the row remains retryable and
    /// cannot be offered as a recoverable project with half its files missing.
    func purgeTrash(_ groups:Set<UUID>)async throws {
        guard !purgingTrash else{throw ImageFailure.message("الحذف النهائي جارٍ")}
        let removed=trashedItems.filter{groups.contains($0.trashGroup ?? $0.id)}
        guard !removed.isEmpty else{return}
        purgingTrash=true;defer{purgingTrash=false}
        let marked=trashedItems.map{value -> LibraryItem in var result=value;if groups.contains(value.trashGroup ?? value.id){result.purgePending=true};return result}
        try writeLibrary(active:items,trash:marked);trashedItems=marked
        let retained=Set((items+marked.filter{!groups.contains($0.trashGroup ?? $0.id)}).flatMap(\.pages))
        let targets=Set(removed.flatMap(\.pages)).subtracting(retained).map{directory($0)}
        try await BackgroundWork.run{for target in targets where FileManager.default.fileExists(atPath:target.path){try FileManager.default.removeItem(at:target)}}
        // Preserve projects created elsewhere while the asynchronous file work ran.
        let trash=trashedItems.filter{!groups.contains($0.trashGroup ?? $0.id)}
        try writeLibrary(active:items,trash:trash);trashedItems=trash
    }
    func resumeTrashPurge()async {
        let pending=Set(trashedItems.filter{$0.purgePending==true}.map{$0.trashGroup ?? $0.id})
        guard !pending.isEmpty else{return}
        do{try await purgeTrash(pending)}catch{self.error="لم يكتمل الحذف النهائي؛ يمكنك إعادة المحاولة من السلة. "+error.localizedDescription}
    }
}
