import UIKit

extension EditorModel {
    func replaceBackground(_ url:URL) async {
        guard !busy else{return};busy=true;defer{busy=false};let before=page,root=library.root,directory=self.directory
        do{let imported=try await BackgroundWork.run{try ImagePipeline.importImage(url,root:root)};let folder=root.appendingPathComponent(imported.id.uuidString);defer{try? FileManager.default.removeItem(at:folder)}
            guard imported.width==before.width,imported.height==before.height else{throw ImageFailure.message("الصورة البديلة يجب أن تطابق مقاس اللوحة \(before.width) × \(before.height). غيّر مقاسها صراحة قبل الاستبدال")}
            guard page==before else{return};let id=UUID().uuidString,source=id+".png",raw=id+".rgba"
            try FileManager.default.copyItem(at:folder.appendingPathComponent(imported.source),to:directory.appendingPathComponent(source))
            do{try FileManager.default.copyItem(at:folder.appendingPathComponent(imported.raw),to:directory.appendingPathComponent(raw))}catch{try? FileManager.default.removeItem(at:directory.appendingPathComponent(source));throw error}
            checkpoint();page.source=source;page.raw=raw;page.baseHidden=false;save()
        }catch{self.error=error.localizedDescription}
    }
}
