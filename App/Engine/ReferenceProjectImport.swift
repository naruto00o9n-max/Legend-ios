import Foundation
import UIKit

/// Migrates the Android project_meta.json + pages/*.json + assets export.
/// Reject unknown layer data rather than silently dropping edits.
enum ReferenceProjectImport {
    static func importFolder(_ folder:URL,root:URL)throws->[EditorPage]? {
        let files=FileManager.default.enumerator(at:folder,includingPropertiesForKeys:nil)?.allObjects as? [URL] ?? []
        guard let meta=files.first(where:{$0.lastPathComponent=="project_meta.json"}) else{return nil}
        guard let project=try JSONSerialization.jsonObject(with:Data(contentsOf:meta)) as? [String:Any],let pages=project["pages"] as? [[String:Any]],!pages.isEmpty else{throw ImageFailure.message("بيانات مشروع تايبر غير صالحة")}
        let projectFolder=meta.deletingLastPathComponent()
        func asset(_ path:String)throws->URL {
            let name=(path as NSString).lastPathComponent
            let exact=projectFolder.appendingPathComponent("assets").appendingPathComponent(name)
            if FileManager.default.fileExists(atPath:exact.path){return exact}
            let found=files.filter{$0.lastPathComponent==name};guard found.count==1,let file=found.first else{throw ImageFailure.message("أصل مفقود أو ملتبس في المشروع: "+name)};return file
        }
        var imported:[EditorPage]=[],fonts=Set<URL>()
        do{for (index,pageMeta) in pages.sorted(by:{($0["orderIndex"] as? Int ?? 0)<($1["orderIndex"] as? Int ?? 0)}).enumerated(){
            try Task.checkCancellation();guard let originalID=pageMeta["id"] as? String,!originalID.contains("/"),!originalID.contains("..") else{throw ImageFailure.message("معرف الصفحة مفقود")}
            let state=projectFolder.appendingPathComponent("pages").appendingPathComponent(originalID+".json")
            guard let object=try JSONSerialization.jsonObject(with:Data(contentsOf:state)) as? [String:Any],let canvas=object["canvasConfig"] as? [String:Any],let width=canvas["width"] as? Int,let height=canvas["height"] as? Int else{throw ImageFailure.message("مقاسات صفحة تايبر مفقودة")}
            let title=pageMeta["originalName"] as? String ?? "صفحة \(index+1)"
            var page:EditorPage
            if let path=canvas["backgroundImagePath"] as? String,!path.isEmpty{page=try ImagePipeline.importImage(asset(path),root:root);guard page.width==width,page.height==height else{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString));throw ImageFailure.message("مقاس خلفية المشروع يختلف عن اللوحة؛ لم تُغيّر الصورة تلقائيًا")}}
            else{let color=(canvas["backgroundColor"] as? NSNumber)?.int64Value ?? -1;page=try PageOperations.blank(title:title,width:width,height:height,color:String(format:"%06X",UInt32(truncatingIfNeeded:color)&0xFFFFFF),transparent:((UInt32(truncatingIfNeeded:color)>>24)==0),root:root)}
            imported.append(page);page.title=title;let target=root.appendingPathComponent(page.id.uuidString)
            func copy(_ path:String)throws->String{let input=try asset(path),name=UUID().uuidString+"."+input.pathExtension;try FileManager.default.copyItem(at:input,to:target.appendingPathComponent(name));return name}
            for row in (object["layers"] as? [[String:Any]] ?? []).sorted(by:{($0["zIndex"] as? Int ?? 0)<($1["zIndex"] as? Int ?? 0)}){
                let kind=(row["layerType"] as? String ?? "").lowercased(),name=row["name"] as? String ?? "طبقة مستوردة"
                var layer:EditorLayer
                if kind.contains("text"){layer=EditorLayer(kind:.text,name:name);layer.textContent=row["textContent"] as? String ?? "";layer.style=try ReferenceStyleImport.decode(JSONSerialization.data(withJSONObject:[row]))[0].style
                    if (row["boxWidth"] as? Double ?? -1)<=0{layer.style.boxWidth=max(layer.style.boxWidth,ceil(LayerRenderer.attributed(layer).size().width)+1)}
                    if let font=row["fontPath"] as? String,!font.isEmpty{if let input=try? asset(font){fonts.insert(input)}else if !(Fonts.files+Fonts.otf).contains(where:{$0.lastPathComponent==(font as NSString).lastPathComponent}){throw ImageFailure.message("خط المشروع مفقود: "+(font as NSString).lastPathComponent)}}
                    if let texture=row["texturePath"] as? String,!texture.isEmpty{layer.style.texturePath=try copy(texture)}
                }else if kind.contains("image") || kind.contains("drawing") || kind.contains("shape"),let path=row["imagePath"] as? String,!path.isEmpty{layer=EditorLayer(kind:.image,name:name);layer.imagePath=try copy(path)}
                else{throw ImageFailure.message("الطبقة \(name) لا تملك بيانات يمكن ترحيلها بأمان؛ بقي الأرشيف الأصلي دون تغيير")}
                layer.frame=Box(x:0,y:0,width:row["baseWidth"] as? Double ?? layer.style.boxWidth,height:row["baseHeight"] as? Double ?? 100)
                let bounds=LayerRenderer.bounds(layer)
                // Android layer x/y locate its center; Cookies stores the unscaled top-left.
                layer.frame.x=(row["x"] as? Double ?? 0)-Double(bounds.width)/2
                layer.frame.y=(row["y"] as? Double ?? 0)-Double(bounds.height)/2
                layer.rotation=row["rotation"] as? Double ?? 0;layer.scaleX=row["scaleX"] as? Double ?? 1;layer.scaleY=row["scaleY"] as? Double ?? 1;layer.opacity=(row["opacity"] as? Double ?? 255)/255;layer.isLocked=row["isLocked"] as? Bool ?? false;layer.isVisible=row["isVisible"] as? Bool ?? true
                if let mode=row["layerBlendMode"] as? String{guard let blend=Blend(rawValue:mode.lowercased()) else{throw ImageFailure.message("وضع مزج غير مدعوم: "+mode)};layer.blend=blend}
                layer.isMaskEnabled=row["isMaskEnabled"] as? Bool ?? false;layer.maskX=row["maskX"] as? Double ?? 0;layer.maskY=row["maskY"] as? Double ?? 0;layer.maskRadius=row["maskRadius"] as? Double ?? 80
                if let mask=row["eraserMaskPath"] as? String,!mask.isEmpty{throw ImageFailure.message("المشروع يحتوي قناع مسح أصلي؛ ترحيل صيغته لم يكتمل بعد")}
                page.layers.append(layer)
            }
            try PageOperations.persist(page,root:root);imported[imported.count-1]=page
        };if !fonts.isEmpty{try FontPackage.importFiles(Array(fonts))};return imported}catch{for page in imported{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString))};throw error}
    }
}
