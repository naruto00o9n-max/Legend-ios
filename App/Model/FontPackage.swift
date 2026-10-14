import Foundation
import CoreText
import UIKit
import ZIPFoundation

enum FontPackage {
    static func importArchive(_ url:URL)throws->[String:[String]] {try importArchives([url])}
    /// Stage every provider file before modifying the library. Validation or a
    /// conflict in any selection leaves the existing library unchanged.
    static func importArchives(_ urls:[URL],directory:URL=Fonts.userDirectory)throws->[String:[String]] {
        guard !urls.isEmpty,urls.count<=200 else{throw ImageFailure.message("اختر من ملف واحد إلى 200 ملف")}
        let fm=FileManager.default,staging=fm.temporaryDirectory.appendingPathComponent("font-import-"+UUID().uuidString)
        try fm.createDirectory(at:staging,withIntermediateDirectories:true)
        defer{try? fm.removeItem(at:staging)}
        var candidates:[URL]=[],groups:[String:[String]]=[:]
        for url in urls{
            try Task.checkCancellation()
            let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
            let archive=url.pathExtension.lowercased()=="zip" ? try ChapterArchive.staging(url):nil
            defer{if let archive{try? fm.removeItem(at:archive)}}
            let files=archive.map{(fm.enumerator(at:$0,includingPropertiesForKeys:nil)?.allObjects as? [URL] ?? []).filter{["ttf","otf"].contains($0.pathExtension.lowercased())}} ?? [url]
            guard !files.isEmpty,files.count+candidates.count<=200 else{throw ImageFailure.message("حدد حتى 200 خط بصيغة TTF أو OTF، أو حزمة ZIP تحتوي خطوطًا")}
            for file in files{
                guard ["ttf","otf"].contains(file.pathExtension.lowercased()) else{throw ImageFailure.message("صيغة خط غير مدعومة: "+file.lastPathComponent)}
                let target=staging.appendingPathComponent(file.lastPathComponent)
                if fm.fileExists(atPath:target.path){guard try Data(contentsOf:target)==Data(contentsOf:file) else{throw ImageFailure.message("اسمان متعارضان في الملفات المحددة: "+file.lastPathComponent)};continue}
                let size=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0
                guard size>0,size<=16*1024*1024 else{throw ImageFailure.message("حجم خط غير صالح: "+file.lastPathComponent)}
                try fm.copyItem(at:file,to:target);candidates.append(target)
            }
            if let archive,let data=try? Data(contentsOf:archive.appendingPathComponent("collections.json")),let collections=try? JSONDecoder().decode([String:[String]].self,from:data){
                for (name,fonts) in collections{groups[name]=Array(Set((groups[name] ?? [])+fonts)).sorted()}
            }
        }
        try importFiles(candidates,directory:directory)
        return groups
    }
    static func importFiles(_ candidates:[URL],directory:URL=Fonts.userDirectory)throws {
        guard !candidates.isEmpty,candidates.count<=200 else{throw ImageFailure.message("الحزمة يجب أن تحتوي من خط واحد إلى 200 خط")}
        for file in candidates{let size=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0;guard size>0,size<=16*1024*1024,let provider=CGDataProvider(url:file as CFURL),CGFont(provider) != nil else{throw ImageFailure.message("خط غير صالح: "+file.lastPathComponent)}}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let bundled=(Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts") ?? [])+(Bundle.main.urls(forResourcesWithExtension:"otf",subdirectory:"Fonts") ?? [])
        var added:[URL]=[],registered:[URL]=[]
        do{for file in candidates{
            if let installed=bundled.first(where:{$0.lastPathComponent==file.lastPathComponent}){guard try Data(contentsOf:installed)==Data(contentsOf:file) else{throw ImageFailure.message("اسم الخط يتعارض مع خط مثبت: "+file.lastPathComponent)}}
            let target=directory.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath:target.path){guard try Data(contentsOf:target)==Data(contentsOf:file) else{throw ImageFailure.message("اسم الخط يتعارض مع خط مستورد: "+file.lastPathComponent)};continue}
            try FileManager.default.copyItem(at:file,to:target);added.append(target)
            var registrationError:Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(target as CFURL,.process,&registrationError){
                let error=registrationError?.takeRetainedValue()
                let code=error.map{CFErrorGetCode($0)}
                // A copied font may have a new filename but the same internal
                // PostScript name. Accept only a byte-identical installed alias;
                // a different font sharing that name must still be rejected.
                let identicalAlias=code==Int(CTFontManagerError.duplicatedName.rawValue) && (bundled+Fonts.userFiles).contains { known in
                    known.standardizedFileURL != target.standardizedFileURL && (try? Data(contentsOf:known)) == (try? Data(contentsOf:target))
                }
                guard code==Int(CTFontManagerError.alreadyRegistered.rawValue) || identicalAlias else{throw ImageFailure.message("تعذر تسجيل "+file.lastPathComponent)}
            }else{registered.append(target)}
        }}catch{for file in registered{CTFontManagerUnregisterFontsForURL(file as CFURL,.process,nil)};for file in added{try? FileManager.default.removeItem(at:file)};Fonts.register();throw error}
        Fonts.register()
    }
}
