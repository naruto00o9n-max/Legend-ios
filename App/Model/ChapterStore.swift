import Foundation
import SwiftUI
import ZIPFoundation

struct ChapterHistory:Codable {var chapter:UUID;var pages:[UUID];var cover:UUID?;var date=Date()}
extension LibraryStore {
    @discardableResult func createChapter(_ title:String,parent:UUID?)throws->UUID {
        let name=title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else{throw ImageFailure.message("اكتب اسم الفصل")}
        let item=LibraryItem(parent:parent,title:name,folder:false,isChapter:true)
        var next=items;next.append(item);try commitItems(next);return item.id
    }
    func chapter(_ id:UUID)->LibraryItem?{items.first{$0.id==id && $0.isChapter==true}}
    func chapters(containing page:UUID)->[LibraryItem]{items.filter{$0.isChapter==true && $0.pages.contains(page)}}
    func commitItems(_ next:[LibraryItem])throws {try JSONEncoder().encode(next).write(to:root.appendingPathComponent("library.json"),options:.atomic);items=next}
    func setPages(_ ids:[UUID],chapter id:UUID,keepHistory:Bool=true)throws {
        guard Set(ids).count==ids.count else{throw ImageFailure.message("لا يمكن تكرار الصفحة داخل الفصل")}
        for page in ids{_ = try load(page)}
        var next=items;guard let index=next.firstIndex(where:{$0.id==id && $0.isChapter==true}) else{throw ImageFailure.message("لم يعد الفصل موجودًا")}
        if keepHistory {
            let folder=root.appendingPathComponent("ChapterHistory",isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            try JSONEncoder().encode(ChapterHistory(chapter:id,pages:next[index].pages,cover:next[index].cover)).write(to:folder.appendingPathComponent("\(id).json"),options:.atomic)
        }
        next[index].pages=ids;next[index].modified=Date();if let cover=next[index].cover,!ids.contains(cover){next[index].cover=ids.first};try commitItems(next)
    }
    func restoreChapter(_ id:UUID)throws {
        let file=root.appendingPathComponent("ChapterHistory/\(id).json"),history=try JSONDecoder().decode(ChapterHistory.self,from:Data(contentsOf:file))
        try setPages(history.pages,chapter:id,keepHistory:false);try setCover(history.cover,chapter:id);try FileManager.default.removeItem(at:file)
    }
    func setCover(_ page:UUID?,chapter id:UUID)throws {var next=items;guard let index=next.firstIndex(where:{$0.id==id}) else{return};guard page==nil || next[index].pages.contains(page!) else{throw ImageFailure.message("الغلاف خارج الفصل")};next[index].cover=page;try commitItems(next)}
    func renamePages(_ ids:Set<UUID>,prefix:String,chapter id:UUID)throws {
        guard let item=chapter(id) else{return}
        for (index,pageID) in item.pages.filter({ids.contains($0)}).enumerated(){var page=try load(pageID);page.title="\(prefix) \(index+1)";try persist(page)}
        objectWillChange.send()
    }
    func movePages(_ ids:Set<UUID>,from source:UUID,to destination:UUID)throws {
        guard let from=chapter(source),let to=chapter(destination),source != destination else{throw ImageFailure.message("اختر فصلًا آخر")}
        var next=items;let incoming=from.pages.filter{ids.contains($0)}
        for index in next.indices {if next[index].id==source{next[index].pages.removeAll{ids.contains($0)};if let cover=next[index].cover,ids.contains(cover){next[index].cover=next[index].pages.first}};if next[index].id==destination{next[index].pages=to.pages+incoming.filter{!to.pages.contains($0)}}}
        try commitItems(next)
    }
    func importPages(_ urls:[URL],chapter id:UUID) async throws {
        guard chapter(id) != nil else{throw ImageFailure.message("اختر الفصل")}
        let root=self.root;var imported:[EditorPage]=[]
        do {
            for url in urls{try Task.checkCancellation()
                let pages=try await BackgroundWork.run{()->[EditorPage] in
                    switch url.pathExtension.lowercased(){case "pdf":return try PageOperations.importPDF(url,root:root)
                    case "cookies":return [try ProjectArchive.importFile(url,root:root)]
                    case "cookieschapter":return try ChapterArchive.importFile(url,root:root)
                    case "zip":return try ChapterArchive.importImages(url,root:root)
                    default:return [try ImagePipeline.importImage(url,root:root)]}
                }
                imported+=pages
            }
            guard let item=chapter(id) else{throw ImageFailure.message("لم يعد الفصل موجودًا")}
            try setPages(item.pages+imported.map(\.id),chapter:id)
        }catch{for page in imported{try? FileManager.default.removeItem(at:directory(page.id))};throw error}
    }
}

enum ChapterArchive {
    static func export(_ item:LibraryItem,root:URL)throws->URL {
        let staging=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:staging,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:staging)}
        try JSONEncoder().encode(item).write(to:staging.appendingPathComponent("chapter.json"))
        let folder=staging.appendingPathComponent("Pages");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        for (index,id) in item.pages.enumerated(){try Task.checkCancellation();let dir=root.appendingPathComponent(id.uuidString),page=try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:dir.appendingPathComponent("page.json")));let file=try ProjectArchive.export(page,directory:dir);defer{try? FileManager.default.removeItem(at:file)};try FileManager.default.copyItem(at:file,to:folder.appendingPathComponent(String(format:"%04d.cookies",index+1)))}
        let output=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Chapter-\(UUID()).cookieschapter")
        try FileManager.default.zipItem(at:staging,to:output,shouldKeepParent:false);return output
    }
    static func staging(_ url:URL)throws->URL {
        let archive=try Archive(url:url,accessMode:.read);var size:UInt64=0
        for entry in archive {size+=entry.uncompressedSize;guard size<=1024*1024*1024,!entry.path.contains(".."),!entry.path.hasPrefix("/"),entry.type != .symlink else{throw ImageFailure.message("الأرشيف كبير جدًا أو يحتوي مسارات غير صالحة")}}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.unzipItem(at:url,to:folder);return folder
    }
    static func importFile(_ url:URL,root:URL)throws->[EditorPage] {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        let folder=try staging(url);defer{try? FileManager.default.removeItem(at:folder)}
        let files=try FileManager.default.contentsOfDirectory(at:folder.appendingPathComponent("Pages"),includingPropertiesForKeys:nil).filter{$0.pathExtension=="cookies"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        guard !files.isEmpty else{throw ImageFailure.message("الفصل لا يحتوي صفحات")}
        var result:[EditorPage]=[];do{for file in files{try Task.checkCancellation();result.append(try ProjectArchive.importFile(file,root:root))};return result}catch{for page in result{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString))};throw error}
    }
    static func importImages(_ url:URL,root:URL)throws->[EditorPage] {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        let folder=try staging(url);defer{try? FileManager.default.removeItem(at:folder)}
        let files=(FileManager.default.enumerator(at:folder,includingPropertiesForKeys:nil)?.allObjects as? [URL] ?? []).filter{["png","jpg","jpeg","heic","webp","cookies"].contains($0.pathExtension.lowercased())}.sorted{$0.path.localizedStandardCompare($1.path) == .orderedAscending}
        guard !files.isEmpty else{throw ImageFailure.message("الأرشيف لا يحتوي صورًا مدعومة")}
        var result:[EditorPage]=[];do{for file in files{try Task.checkCancellation();result.append(try file.pathExtension=="cookies" ? ProjectArchive.importFile(file,root:root):ImagePipeline.importImage(file,root:root))};return result}catch{for page in result{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString))};throw error}
    }
}
