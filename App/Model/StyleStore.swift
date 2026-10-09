import Foundation
import SwiftUI
import ZIPFoundation

struct SavedTextStyle:Codable,Equatable,Identifiable {
    var id=UUID()
    var title:String
    var group:String
    var style:TextStyle
    var modified=Date()
}
struct StylePackage:Codable {
    var version=1
    var styles:[SavedTextStyle]
    var tags:[DialogueTag]
}

/// Saved styles own their textures. Removing a project cannot invalidate a style.
@MainActor final class StyleStore:ObservableObject {
    @Published private(set) var styles:[SavedTextStyle]=[]
    @Published var error:String?
    private(set) var copiedStyle:TextStyle?
    private var copiedDirectory:URL?
    let directory:URL
    init(directory:URL?=nil) {
        self.directory=directory ?? FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Cookies/Styles",isDirectory:true)
        do {
            if directory==nil,ProcessInfo.processInfo.arguments.contains("-ui-tests"){try? FileManager.default.removeItem(at:self.directory)}
            try FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true)
            let file=self.directory.appendingPathComponent("styles.json")
            if FileManager.default.fileExists(atPath:file.path){styles=try JSONDecoder().decode([SavedTextStyle].self,from:Data(contentsOf:file))}
        }catch{self.error=error.localizedDescription}
    }
    var groups:[String]{Array(Set(styles.map(\.group))).sorted()}
    private func commit(_ next:[SavedTextStyle])throws {
        try JSONEncoder().encode(next).write(to:directory.appendingPathComponent("styles.json"),options:.atomic)
        styles=next
    }
    @discardableResult func save(title:String,group:String,layer:EditorLayer,from assets:URL,replacing:UUID?=nil)throws->UUID {
        guard layer.kind == .text else{throw ImageFailure.message("حدد طبقة نص لحفظ نمطها")}
        let name=title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else{throw ImageFailure.message("اكتب اسم النمط")}
        var style=layer.style
        // Spans are tied to a particular string, not the reusable style.
        style.spans=[]
        style.texturePath=try ownTexture(style.texturePath,from:assets)
        var item=SavedTextStyle(title:name,group:group.isEmpty ? "أنماطي":group,style:style)
        if let replacing{item.id=replacing}
        var next=styles
        if let index=next.firstIndex(where:{$0.id==item.id}){next[index]=item}else{next.insert(item,at:0)}
        try commit(next);return item.id
    }
    private func ownTexture(_ filename:String,from assets:URL)throws->String {
        guard !filename.isEmpty else{return ""}
        guard !filename.hasPrefix("/"),!filename.split(separator:"/").contains(".."),!filename.contains("\\") else{throw ImageFailure.message("مسار الخامة غير صالح")}
        let source=assets.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath:source.path) else{throw ImageFailure.message("خامة النمط مفقودة")}
        let name=UUID().uuidString+"."+source.pathExtension
        try FileManager.default.copyItem(at:source,to:directory.appendingPathComponent(name));return name
    }
    func rename(_ id:UUID,title:String,group:String)throws {
        guard !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw ImageFailure.message("اكتب اسم النمط")}
        var next=styles;guard let index=next.firstIndex(where:{$0.id==id}) else{return}
        next[index].title=title;next[index].group=group.isEmpty ? "أنماطي":group;next[index].modified=Date();try commit(next)
    }
    func duplicate(_ id:UUID)throws {
        guard var value=styles.first(where:{$0.id==id}) else{return};value.id=UUID();value.title+=" — نسخة";value.modified=Date();try commit([value]+styles)
    }
    func remove(_ id:UUID)throws {try commit(styles.filter{$0.id != id})}
    func resolved(_ style:TextStyle,from source:URL,into destination:URL)throws->TextStyle {
        var next=style
        if !style.texturePath.isEmpty {
            let input=source.appendingPathComponent(style.texturePath)
            guard FileManager.default.fileExists(atPath:input.path) else{throw ImageFailure.message("خامة النمط مفقودة؛ استورد حزمة النمط كاملة")}
            let name=UUID().uuidString+"."+input.pathExtension
            try FileManager.default.copyItem(at:input,to:destination.appendingPathComponent(name));next.texturePath=name
        }
        guard (Fonts.files+Fonts.otf).contains(where:{$0.lastPathComponent==style.fontPath}) else{throw ImageFailure.message("خط النمط مفقود: "+style.fontPath)}
        return next
    }
    func apply(_ item:SavedTextStyle,to model:EditorModel,includeLayout:Bool=false)throws {
        guard model.active?.kind == .text,model.active?.isLocked==false else{throw ImageFailure.message("حدد نصًا غير مقفل")}
        var next=try resolved(item.style,from:directory,into:model.directory)
        if !includeLayout,let current=model.active?.style {
            next.boxWidth=current.boxWidth;next.perspectivePoints=current.perspectivePoints
            next.isMeshMode=current.isMeshMode;next.meshPoints=current.meshPoints
            next.meshRows=current.meshRows;next.meshCols=current.meshCols
            next.rotationX=current.rotationX;next.rotationY=current.rotationY
        }
        model.checkpoint();model.change{$0.style=next}
    }
    func copy(_ layer:EditorLayer,from assets:URL) {copiedStyle=layer.style;copiedDirectory=assets}
    func paste(to model:EditorModel)throws {
        guard let style=copiedStyle,let source=copiedDirectory,model.active?.kind == .text else{throw ImageFailure.message("انسخ نمط نص أولًا")}
        var next=try resolved(style,from:source,into:model.directory);next.spans=[]
        next.boxWidth=model.active?.style.boxWidth ?? next.boxWidth
        model.checkpoint();model.change{$0.style=next}
    }
    func export(ids:Set<UUID>=[],tags:[DialogueTag]=[])throws->URL {
        let selected=ids.isEmpty ? styles:styles.filter{ids.contains($0.id)}
        guard !selected.isEmpty || !tags.isEmpty else{throw ImageFailure.message("لا توجد أنماط لتصديرها")}
        let staging=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:staging,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:staging)}
        let allStyles=selected.map(\.style)+tags.map(\.style)
        for name in Set(allStyles.map(\.texturePath)).filter({!$0.isEmpty}) {
            let source=directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath:source.path) else{throw ImageFailure.message("خامة مفقودة في الحزمة")}
            try FileManager.default.copyItem(at:source,to:staging.appendingPathComponent(name))
        }
        let fonts=Set(allStyles.map(\.fontPath))
        for font in Fonts.userFiles where fonts.contains(font.lastPathComponent){let folder=staging.appendingPathComponent("Fonts");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);try FileManager.default.copyItem(at:font,to:folder.appendingPathComponent(font.lastPathComponent))}
        try JSONEncoder().encode(StylePackage(styles:selected,tags:tags)).write(to:staging.appendingPathComponent("styles.json"))
        let output=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Styles-\(UUID()).cookiesstyles")
        try FileManager.default.zipItem(at:staging,to:output,shouldKeepParent:false);return output
    }
    @discardableResult func importPackage(_ url:URL)throws->[DialogueTag] {
        let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}}
        let archive=try Archive(url:url,accessMode:.read);var total:UInt64=0
        for entry in archive {total+=entry.uncompressedSize;guard total<=128*1024*1024,entry.type != .symlink,!entry.path.contains(".."),!entry.path.hasPrefix("/") else{throw ImageFailure.message("حزمة الأنماط غير صالحة أو كبيرة جدًا")}}
        let staging=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer{try? FileManager.default.removeItem(at:staging)}
        try FileManager.default.unzipItem(at:url,to:staging)
        let bytes=try Data(contentsOf:staging.appendingPathComponent("styles.json"))
        var package:StylePackage
        if let own=try? JSONDecoder().decode(StylePackage.self,from:bytes){package=own}else{package=StylePackage(styles:try ReferenceStyleImport.decode(bytes),tags:[])}
        guard package.version==1 else{throw ImageFailure.message("إصدار حزمة الأنماط غير مدعوم")}
        for index in package.styles.indices {package.styles[index].id=UUID();package.styles[index].style.texturePath=try ownTexture(package.styles[index].style.texturePath,from:staging)}
        for index in package.tags.indices {package.tags[index].id=UUID();package.tags[index].style.texturePath=try ownTexture(package.tags[index].style.texturePath,from:staging)}
        for font in (FileManager.default.enumerator(at:staging,includingPropertiesForKeys:nil)?.allObjects as? [URL]) ?? [] where ["ttf","otf"].contains(font.pathExtension.lowercased()) {
            try FileManager.default.createDirectory(at:Fonts.userDirectory,withIntermediateDirectories:true)
            let target=Fonts.userDirectory.appendingPathComponent(font.lastPathComponent)
            if !FileManager.default.fileExists(atPath:target.path){try FileManager.default.copyItem(at:font,to:target)}
        }
        Fonts.register();try commit(package.styles+styles);return package.tags
    }
}
