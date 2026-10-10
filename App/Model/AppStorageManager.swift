import Foundation
import CryptoKit
import ZIPFoundation
import CoreText
import UIKit

struct BackupUnit:Codable,Identifiable,Equatable {
    var id:String
    var title:String
    var group:String
    var paths:[String]
}
struct BackupFile:Codable {var path:String;var size:Int64;var sha256:String;var unit:String}
struct CookiesBackup:Codable {
    var version=1
    var created=Date()
    var units:[BackupUnit]
    var files:[BackupFile]
    var library:[LibraryItem]
}
struct StorageUsage {
    var documents:Int64=0,cache:Int64=0,temporary:Int64=0,rebuildable:Int64=0,available:Int64=0
    var total:Int64{documents+cache+temporary}
}
/// Archives contain durable local data, never Keychain credentials or decoded RGBA caches.
/// Selected folders are replaced transactionally; unrelated local data is preserved.
enum AppStorageManager {
    static let fm=FileManager.default
    static var documents:URL{fm.urls(for:.documentDirectory,in:.userDomainMask)[0]}
    static var root:URL{documents.appendingPathComponent("Cookies")}
    static var caches:URL{fm.urls(for:.cachesDirectory,in:.userDomainMask)[0]}
    static let changed=Notification.Name("CookiesLocalDataChanged")
    static let reset=Notification.Name("CookiesLocalDataReset")
    static func size(_ url:URL)->Int64 {
        if let values=try? url.resourceValues(forKeys:[.isRegularFileKey,.fileAllocatedSizeKey]),values.isRegularFile==true{return Int64(values.fileAllocatedSize ?? 0)}
        let files=fm.enumerator(at:url,includingPropertiesForKeys:[.isRegularFileKey,.fileAllocatedSizeKey,.isSymbolicLinkKey])
        return (files?.allObjects as? [URL] ?? []).reduce(0){total,file in guard let v=try? file.resourceValues(forKeys:[.isRegularFileKey,.fileAllocatedSizeKey,.isSymbolicLinkKey]),v.isRegularFile==true,v.isSymbolicLink != true else{return total};return total+Int64(v.fileAllocatedSize ?? 0)}
    }
    static func usage()->StorageUsage {
        var result=StorageUsage(documents:size(documents),cache:size(caches),temporary:size(fm.temporaryDirectory))
        for directory in (try? fm.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)) ?? []{
            if let page=try? JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:directory.appendingPathComponent("page.json"))),fm.fileExists(atPath:directory.appendingPathComponent(page.source).path){result.rebuildable+=size(directory.appendingPathComponent(page.raw))}
        }
        result.available=(try? documents.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
        return result
    }
    static func safe(_ path:String)->Bool{!path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator:"/").contains(where:{$0==".." || $0=="."})}
    static func hash(_ file:URL)throws->String {
        let handle=try FileHandle(forReadingFrom:file);defer{try? handle.close()};var hash=SHA256()
        while let bytes=try handle.read(upToCount:1024*1024),!bytes.isEmpty{hash.update(data:bytes)}
        return hash.finalize().map{String(format:"%02x",$0)}.joined()
    }
    static func library(at base:URL=root)throws->[LibraryItem]{guard fm.fileExists(atPath:base.appendingPathComponent("library.json").path) else{return []};return try JSONDecoder().decode([LibraryItem].self,from:Data(contentsOf:base.appendingPathComponent("library.json")))}
    static func units(at base:URL=root)throws->[BackupUnit] {
        let items=try library(at:base);var output:[BackupUnit]=[]
        for directory in (try? fm.contentsOfDirectory(at:base,includingPropertiesForKeys:nil)) ?? []{
            let name=directory.lastPathComponent
            if let id=UUID(uuidString:name),let page=try? JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:directory.appendingPathComponent("page.json"))){output.append(BackupUnit(id:name,title:items.first{$0.id==id}?.title ?? page.title,group:"المشاريع",paths:[name]))}
            else if name=="Fonts"{for font in (try? fm.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? []{output.append(BackupUnit(id:"font:"+font.lastPathComponent,title:font.lastPathComponent,group:"الخطوط",paths:["Fonts/"+font.lastPathComponent]))}}
            else if (try? directory.resourceValues(forKeys:[.isDirectoryKey]).isDirectory)==true{output.append(BackupUnit(id:name,title:name=="Styles" ? "الأنماط وخاماتها":name=="Typer" ? "فصول التايبر والوسوم":name=="ChapterHistory" ? "تاريخ الفصول":name,group:"بيانات أخرى",paths:[name]))}
        }
        output.append(BackupUnit(id:"settings",title:"الإعدادات والمفضلة وآخر استخدام",group:"الإعدادات",paths:[]))
        return output.sorted{($0.group,$0.title)<($1.group,$1.title)}
    }
    static func settingsData(_ defaults:UserDefaults = .standard)throws->Data {
        let keys=defaults.dictionaryRepresentation().filter{key,_ in key.hasPrefix("editor-") || key.hasPrefix("typer-") || key.hasPrefix("font") || key.hasPrefix("reader-") || key.hasPrefix("text-") || key.hasPrefix("default-")}
        return try PropertyListSerialization.data(fromPropertyList:keys,format:.binary,options:0)
    }
    static func createBackup(selected:Set<String>,at base:URL=root,settings:Data?=nil)throws->URL {
        let choices=try units(at:base).filter{selected.contains($0.id)};guard !choices.isEmpty else{throw ImageFailure.message("حدد بيانات النسخة الاحتياطية")}
        let output=fm.temporaryDirectory.appendingPathComponent("Cookies-Backup-\(UUID()).cookiesbackup")
        let archive=try Archive(url:output,accessMode:.create);var files:[BackupFile]=[]
        do {
            for unit in choices {for path in unit.paths {
                let input=base.appendingPathComponent(path),directory=(try input.resourceValues(forKeys:[.isDirectoryKey])).isDirectory==true
                let candidates=directory ? (fm.enumerator(at:input,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey])?.allObjects as? [URL] ?? []):[input]
                var raw:String?
                if let page=try? JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:input.appendingPathComponent("page.json"))){raw=page.raw}
                for file in candidates {let v=try file.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey]);guard v.isRegularFile==true,v.isSymbolicLink != true else{continue};if file.lastPathComponent==raw{continue}
                    let relative=String(file.path.dropFirst(base.path.count+1));guard safe(relative) else{throw ImageFailure.message("مسار غير صالح")}
                    let bytes=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0
                    files.append(BackupFile(path:relative,size:Int64(bytes),sha256:try hash(file),unit:unit.id))
                    try archive.addEntry(with:relative,fileURL:file,compressionMethod:.deflate)
                }
            }}
            if choices.contains(where:{$0.id=="settings"}){
                let bytes=try settings ?? settingsData();try add(bytes,path:"settings.plist",archive:archive)
                files.append(BackupFile(path:"settings.plist",size:Int64(bytes.count),sha256:SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined(),unit:"settings"))
            }
            let manifest=CookiesBackup(units:choices,files:files,library:try library(at:base));try add(try JSONEncoder().encode(manifest),path:"manifest.json",archive:archive)
            return output
        }catch{try? fm.removeItem(at:output);throw error}
    }
    private static func add(_ bytes:Data,path:String,archive:Archive)throws{try archive.addEntry(with:path,type:.file,uncompressedSize:Int64(bytes.count),compressionMethod:.deflate){position,size in bytes.subdata(in:Int(position)..<min(bytes.count,Int(position)+size))}}
    static func inspect(_ file:URL)throws->CookiesBackup {
        let archive=try Archive(url:file,accessMode:.read);guard let entry=archive["manifest.json"],entry.uncompressedSize<=8*1024*1024 else{throw ImageFailure.message("ليست نسخة Cookies سليمة")};var data=Data();_ = try archive.extract(entry){data.append($0)}
        let manifest=try JSONDecoder().decode(CookiesBackup.self,from:data)
        guard manifest.version==1,manifest.files.count<=100000,manifest.files.reduce(Int64(0),{$0+max(0,min($1.size,20*1024*1024*1024))})<=20*1024*1024*1024,Set(manifest.units.map(\.id)).count==manifest.units.count,Set(manifest.files.map(\.path)).count==manifest.files.count else{throw ImageFailure.message("إصدار النسخة أو فهرسها غير صالح")}
        for file in manifest.files{guard safe(file.path),file.size>=0,manifest.units.contains(where:{$0.id==file.unit}),let entry=archive[file.path],entry.type == .file,entry.uncompressedSize==file.size else{throw ImageFailure.message("ملفات النسخة ناقصة أو غير صالحة")}}
        for unit in manifest.units{guard (UUID(uuidString:unit.id) != nil ? unit.paths==[unit.id]:unit.id.hasPrefix("font:") ? unit.paths==["Fonts/"+String(unit.id.dropFirst(5))]:unit.id=="settings" ? unit.paths.isEmpty:unit.paths==[unit.id]), unit.paths.allSatisfy(safe),unit.paths.allSatisfy({$0 != "library.json" && !$0.hasPrefix(".")}) else{throw ImageFailure.message("وجهة الاستعادة غير صالحة")};for file in manifest.files where file.unit==unit.id{guard unit.id=="settings" ? file.path=="settings.plist":unit.paths.contains(where:{file.path==$0 || file.path.hasPrefix($0+"/")}) else{throw ImageFailure.message("تعارض في فهرس الاستعادة")}}}
        return manifest
    }
    static func restore(_ file:URL,selected:Set<String>,at base:URL=root)throws->[String:Any]? {
        let manifest=try inspect(file),choices=manifest.units.filter{selected.contains($0.id)};guard !choices.isEmpty else{throw ImageFailure.message("حدد ما تريد استعادته")}
        let chosen=Set(choices.map(\.id)),files=manifest.files.filter{chosen.contains($0.unit)},archive=try Archive(url:file,accessMode:.read)
        let parent=base.deletingLastPathComponent(),staging=parent.appendingPathComponent(".cookies-restore-\(UUID())"),rollback=parent.appendingPathComponent(".cookies-rollback-\(UUID())")
        var keepRollback=false
        try fm.createDirectory(at:staging,withIntermediateDirectories:true);defer{try? fm.removeItem(at:staging);if !keepRollback{try? fm.removeItem(at:rollback)}}
        for info in files {let destination=staging.appendingPathComponent(info.path);try fm.createDirectory(at:destination.deletingLastPathComponent(),withIntermediateDirectories:true);_ = try archive.extract(archive[info.path]!,to:destination);guard try hash(destination)==info.sha256 else{throw ImageFailure.message("فشل فحص سلامة النسخة؛ لم تتغير بياناتك")}}
        for unit in choices where UUID(uuidString:unit.id) != nil {let directory=staging.appendingPathComponent(unit.id);let page=try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:directory.appendingPathComponent("page.json")));guard page.id.uuidString==unit.id,safe(page.source),!page.source.contains("/"),safe(page.raw),!page.raw.contains("/"),fm.fileExists(atPath:directory.appendingPathComponent(page.source).path) else{throw ImageFailure.message("مشروع ناقص في النسخة")}}
        for unit in choices {
            if unit.id=="Styles"{_ = try JSONDecoder().decode([SavedTextStyle].self,from:Data(contentsOf:staging.appendingPathComponent("Styles/styles.json")))}
            if unit.id=="Typer"{_ = try JSONDecoder().decode(TyperState.self,from:Data(contentsOf:staging.appendingPathComponent("Typer/chapters.json")))}
            if unit.id.hasPrefix("font:"),let path=unit.paths.first{guard let provider=CGDataProvider(url:staging.appendingPathComponent(path) as CFURL),CGFont(provider) != nil else{throw ImageFailure.message("خط غير صالح في النسخة")}}
        }
        let settings: [String:Any]? = chosen.contains("settings") ? try PropertyListSerialization.propertyList(from:Data(contentsOf:staging.appendingPathComponent("settings.plist")),format:nil) as? [String:Any]:nil
        let restoredPages=Set(choices.compactMap{UUID(uuidString:$0.id)});var next=try library(at:base)
        let wanted=manifest.library.filter{$0.folder || !$0.pages.allSatisfy{!restoredPages.contains($0)}}
        for var item in wanted {if !item.folder{item.pages=item.pages.filter{restoredPages.contains($0)}};if let index=next.firstIndex(where:{$0.id==item.id}){if item.isChapter==true{next[index].pages=Array(NSOrderedSet(array:next[index].pages+item.pages)) as? [UUID] ?? item.pages}else{next[index]=item}}else{next.append(item)}}
        try JSONEncoder().encode(next).write(to:staging.appendingPathComponent("library.json"),options:.atomic)
        let paths=choices.flatMap(\.paths)+["library.json"];guard Set(paths).count==paths.count else{throw ImageFailure.message("وجهات الاستعادة متكررة")}
        try fm.createDirectory(at:base,withIntermediateDirectories:true);try fm.createDirectory(at:rollback,withIntermediateDirectories:true)
        var moved:[String]=[],installed:[String]=[]
        do{for path in paths{let target=base.appendingPathComponent(path),old=rollback.appendingPathComponent(path),new=staging.appendingPathComponent(path);if fm.fileExists(atPath:target.path){try fm.createDirectory(at:old.deletingLastPathComponent(),withIntermediateDirectories:true);try fm.moveItem(at:target,to:old);moved.append(path)};if fm.fileExists(atPath:new.path){try fm.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true);try fm.moveItem(at:new,to:target);installed.append(path)}}}
        catch{for path in installed.reversed(){try? fm.removeItem(at:base.appendingPathComponent(path))};for path in moved.reversed(){do{try fm.moveItem(at:rollback.appendingPathComponent(path),to:base.appendingPathComponent(path))}catch{keepRollback=true}};throw error}
        return settings
    }
    static func cleanDecodedCaches(at base:URL=root)throws {
        for directory in (try? fm.contentsOfDirectory(at:base,includingPropertiesForKeys:nil)) ?? [] {
            guard let page=try? JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:directory.appendingPathComponent("page.json"))),safe(page.raw),!page.raw.contains("/"),fm.fileExists(atPath:directory.appendingPathComponent(page.source).path) else{continue}
            guard LIValidatePNG(directory.appendingPathComponent(page.source).path,Int32(page.width),Int32(page.height))==1 else{throw ImageFailure.message("تعذر التحقق من الأصل؛ احتُفظ بنسخة البكسلات لحماية المشروع")};let raw=directory.appendingPathComponent(page.raw);if fm.fileExists(atPath:raw.path){try fm.removeItem(at:raw)}
        }
    }
    static func cleanCaches(at base:URL=root)throws {
        try cleanDecodedCaches(at:base)
        URLCache.shared.removeAllCachedResponses()
        for folder in [caches,fm.temporaryDirectory]{for file in (try? fm.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)) ?? []{try fm.removeItem(at:file)}}
    }
    static func resetLocalData()throws {
        // Called from Settings, after explicit destructive confirmation; no editor is open.
        for font in Fonts.userFiles{CTFontManagerUnregisterFontsForURL(font as CFURL,.process,nil)}
        for directory in [documents,caches,fm.temporaryDirectory,fm.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]]{for file in try fm.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil){try fm.removeItem(at:file)}}
        if let name=Bundle.main.bundleIdentifier{UserDefaults.standard.removePersistentDomain(forName:name)}
        Keychain.remove("session");URLCache.shared.removeAllCachedResponses();Fonts.register()
    }
}
