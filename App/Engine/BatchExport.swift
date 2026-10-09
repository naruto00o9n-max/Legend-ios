import Foundation
import Photos
import ZIPFoundation

enum PhotoSave {
    static func save(_ file:URL) async throws {
        let authorization=await PHPhotoLibrary.requestAuthorization(for:.addOnly)
        guard authorization == .authorized || authorization == .limited else{throw ImageFailure.message("اسمح بحفظ الصور من إعدادات الجهاز")}
        try await PHPhotoLibrary.shared().performChanges{PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL:file)}
    }
}
enum BatchExport {
    static func export(pages:[EditorPage],root:URL,format:String,quality:Double=0.95,prefix:String="صفحة",smartHeight:Int?=nil,progress:@escaping(Int,Int)->Void)throws->URL {
        guard !pages.isEmpty else{throw ImageFailure.message("اختر صفحات للتصدير")}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        var selected=pages,temporary:[EditorPage]=[]
        defer{for page in temporary{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString))}}
        if let smartHeight {
            guard smartHeight>0 else{throw ImageFailure.message("اكتب طول الجزء")}
            let merged=try PageOperations.merged(pages,root:root);temporary.append(merged)
            selected=try PageOperations.split(merged,maximumHeight:smartHeight,root:root);temporary+=selected
        }
        let name=prefix.replacingOccurrences(of:"/",with:"-").replacingOccurrences(of:"\\",with:"-").trimmingCharacters(in:.whitespaces)
        for (index,page) in selected.enumerated(){try Task.checkCancellation();let directory=root.appendingPathComponent(page.id.uuidString)
            let file:URL
            switch format {case "JPEG":file=try ImagePipeline.exportJPEG(page,directory:directory,quality:quality);case "PSD":file=try PSDWriter.export(page,directory:directory);case "مشروع":file=try ProjectArchive.export(page,directory:directory);default:file=try ImagePipeline.exportPNG(page,directory:directory)}
            defer{try? FileManager.default.removeItem(at:file)}
            let target=folder.appendingPathComponent(String(format:"%04d-",index+1)+name+"."+file.pathExtension)
            try FileManager.default.copyItem(at:file,to:target);progress(index+1,selected.count)
        }
        let output=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Export-\(UUID()).zip")
        try FileManager.default.zipItem(at:folder,to:output,shouldKeepParent:false);return output
    }
}
