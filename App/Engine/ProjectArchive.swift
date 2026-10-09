import Foundation
import ZIPFoundation

// An editable document archive contains source pixels, layer metadata and assets.
enum ProjectArchive {
    static func export(_ page:EditorPage,directory:URL)throws->URL {
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:temporary,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:temporary)}
        for url in try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil) where url.lastPathComponent != page.raw && url.lastPathComponent != "page.json" {try FileManager.default.copyItem(at:url,to:temporary.appendingPathComponent(url.lastPathComponent))}
        try JSONEncoder().encode(page).write(to:temporary.appendingPathComponent("page.json"))
        let output=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-\(page.id).cookies")
        try? FileManager.default.removeItem(at:output);try FileManager.default.zipItem(at:temporary,to:output,shouldKeepParent:false)
        return output
    }
    static func importFile(_ input:URL,root:URL)throws->EditorPage {
        let access=input.startAccessingSecurityScopedResource();defer{if access{input.stopAccessingSecurityScopedResource()}}
        let archive=try Archive(url:input,accessMode:.read)
        var total:UInt64=0
        for entry in archive{total+=entry.uncompressedSize;guard total<=512*1024*1024,!entry.path.contains(".."),!entry.path.hasPrefix("/"),entry.type != .symlink else{throw ImageFailure.message("ملف المشروع أكبر من الحد المدعوم أو يحتوي مسارات غير صالحة")}}
        let destination=root.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
        do {
            try FileManager.default.unzipItem(at:input,to:destination)
            var page=try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:destination.appendingPathComponent("page.json")))
            guard page.source=="source.png",page.raw=="pixels.rgba",page.layers.allSatisfy({l in [l.imagePath,l.style.texturePath].allSatisfy{$0.isEmpty || (!$0.contains("/") && !$0.contains(".."))}}) else{throw ImageFailure.message("مسارات أصول المشروع غير صالحة")}
            page.id=UUID(uuidString:destination.lastPathComponent)!
            var width:Int32=0,height:Int32=0,error=[CChar](repeating:0,count:512)
            guard LIImportPNG(destination.appendingPathComponent(page.source).path,destination.appendingPathComponent(page.raw).path,&width,&height,&error,error.count)==1,Int(width)==page.width,Int(height)==page.height else{throw ImageFailure.message("أبعاد الصورة لا تطابق المشروع")}
            try JSONEncoder().encode(page).write(to:destination.appendingPathComponent("page.json"),options:.atomic);return page
        }catch{try? FileManager.default.removeItem(at:destination);throw error}
    }
}
