import Foundation
import SwiftUI

enum BubbleSeparation: String, Codable, CaseIterable {
    case lines, paragraphs
    var title: String { self == .lines ? "كل سطر فقاعة" : "كل فقرة فقاعة" }
}
struct DialogueTag: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var prefix: String
    var style = TextStyle()
    var noPaste = false
    static var defaults: [DialogueTag] {
        [("حوار عادي","","hayah.ttf"),("عنوان","##","hsn_sadiyah.ttf"),("صراخ",":","boahmed_alhour.ttf"),("تفكير","()","hacen_sahara.ttf"),("نظام","$","hsn_sadiyah.ttf"),("مؤثرات","**","afsaneh.ttf"),("مربع نص","[]","hacen_samra_lt.ttf"),("راوي","#","hacen_samra_lt.ttf")].map { title,prefix,font in
            var tag = DialogueTag(title:title,prefix:prefix);tag.style.fontPath=font;tag.noPaste=prefix=="##";return tag
        }
    }
}
struct DialogueBubble: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String
    var tagID: UUID?
    var noPaste = false
    var usedOnPage: UUID?
    var usedLayer: UUID?
    var usedAt: Date?
    var used: Bool { usedAt != nil }
}
struct DialogueChapter: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var source: String
    var separation = BubbleSeparation.lines
    var bubbles: [DialogueBubble] = []
    var folder: UUID?
    var modified = Date()
    var pasteable: [DialogueBubble] { bubbles.filter { !$0.noPaste } }
    var usedCount: Int { pasteable.filter(\.used).count }
}
struct TyperState: Codable {
    var chapters: [DialogueChapter] = []
    var active: UUID?
    var tags = DialogueTag.defaults
    var linkPrefix = "//"
}
enum TranscriptParser {
    static func decode(_ data: Data) throws -> String {
        guard data.count <= 8*1024*1024 else {throw ImageFailure.message("ملف النص كبير جدًا؛ الحد 8 ميغابايت")}
        let encoding: String.Encoding
        if data.starts(with:[0xFF,0xFE]) {encoding = .utf16LittleEndian}
        else if data.starts(with:[0xFE,0xFF]) {encoding = .utf16BigEndian}
        else {encoding = .utf8}
        guard let text=String(data:data,encoding:encoding) else {throw ImageFailure.message("احفظ ملف الفصل بصيغة UTF-8 أو UTF-16")}
        return text.replacingOccurrences(of:"\u{FEFF}",with:"").replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n")
    }
    // Reconcile by text/tag occurrence rather than line number. Adding a line
    // before existing text must never mark a different bubble as already used.
    static func parse(_ source:String,separation:BubbleSeparation,tags:[DialogueTag],link:String,previous:[DialogueBubble]=[]) -> [DialogueBubble] {
        let text=source.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n")
        let chunks=separation == .lines ? text.components(separatedBy:"\n") : text.components(separatedBy:try! NSRegularExpression(pattern:"\\n\\s*\\n"))
        let sorted=tags.filter{!$0.prefix.isEmpty}.sorted{$0.prefix.count>$1.prefix.count}
        let defaultTag=tags.first{$0.prefix.isEmpty} ?? tags.first
        var inherited=defaultTag
        var queues:[String:[DialogueBubble]]=[:]
        func key(_ bubble:DialogueBubble)->String {bubble.text+"\u{0}"+(bubble.tagID?.uuidString ?? "")+"\u{0}"+String(bubble.noPaste)}
        for bubble in previous {queues[key(bubble),default:[]].append(bubble)}
        return chunks.compactMap { raw in
            var value=raw.trimmingCharacters(in:.whitespacesAndNewlines)
            guard !value.isEmpty else{return nil}
            var tag=defaultTag
            if !link.isEmpty,value.hasPrefix(link) {value=String(value.dropFirst(link.count)).trimmingCharacters(in:.whitespaces);tag=inherited}
            else if let matched=sorted.first(where:{value.hasPrefix($0.prefix)}) {tag=matched;value=String(value.dropFirst(matched.prefix.count)).trimmingCharacters(in:.whitespaces)}
            while let first=value.first,["\"",":","“","”"].contains(String(first)) {value=String(value.dropFirst()).trimmingCharacters(in:.whitespaces)}
            guard !value.isEmpty else{return nil}
            let noPaste=tag?.noPaste == true || tag?.prefix == "##"
            if !noPaste,!["$","**","[]"].contains(tag?.prefix ?? "") {inherited=tag}
            var bubble=DialogueBubble(text:value,tagID:tag?.id,noPaste:noPaste)
            if var existing=queues[key(bubble)],!existing.isEmpty {bubble=existing.removeFirst();queues[key(bubble)]=existing}
            return bubble
        }
    }
}
private extension String {
    func components(separatedBy regex:NSRegularExpression)->[String] {
        let original=self as NSString;var start=0,result:[String]=[]
        for match in regex.matches(in:self,range:NSRange(location:0,length:original.length)) {result.append(original.substring(with:NSRange(location:start,length:match.range.location-start)));start=NSMaxRange(match.range)}
        result.append(original.substring(from:start));return result
    }
}
@MainActor final class TyperStore: ObservableObject {
    @Published private(set) var state=TyperState()
    @Published var error: String?
    let directory: URL
    init(directory:URL?=nil) {
        self.directory=directory ?? FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Cookies/Typer",isDirectory:true)
        if ProcessInfo.processInfo.arguments.contains("-ui-tests"),directory==nil {try? FileManager.default.removeItem(at:self.directory)}
        do {try FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true)
            let url=self.directory.appendingPathComponent("chapters.json")
            if FileManager.default.fileExists(atPath:url.path){state=try JSONDecoder().decode(TyperState.self,from:Data(contentsOf:url))}
        }catch{self.error="تعذر فتح فصول التايبر: "+error.localizedDescription}
    }
    var activeChapter:DialogueChapter? {state.chapters.first{$0.id==state.active}}
    func chapter(_ id:UUID)->DialogueChapter? {state.chapters.first{$0.id==id}}
    func tag(_ id:UUID?)->DialogueTag? {state.tags.first{$0.id==id}}
    private func commit(_ next:TyperState)throws {try JSONEncoder().encode(next).write(to:directory.appendingPathComponent("chapters.json"),options:.atomic);state=next}
    func activate(_ id:UUID)throws {var next=state;next.active=id;try commit(next)}
    @discardableResult func saveChapter(id:UUID?=nil,title:String,source:String,separation:BubbleSeparation,folder:UUID?=nil)throws->UUID {
        var next=state
        var chapter=id.flatMap{self.chapter($0)} ?? DialogueChapter(title:title,source:source)
        chapter.title=title.trimmingCharacters(in:.whitespacesAndNewlines);if chapter.title.isEmpty{chapter.title="فصل جديد"}
        chapter.source=source;chapter.separation=separation;chapter.folder=folder;chapter.modified=Date()
        chapter.bubbles=TranscriptParser.parse(source,separation:separation,tags:state.tags,link:state.linkPrefix,previous:chapter.bubbles)
        guard !chapter.bubbles.isEmpty else{throw ImageFailure.message("أضف نص الفصل أولًا")}
        if let index=next.chapters.firstIndex(where:{$0.id==chapter.id}){next.chapters[index]=chapter}else{next.chapters.insert(chapter,at:0)}
        next.active=chapter.id;try commit(next);return chapter.id
    }
    func remove(_ id:UUID)throws {var next=state;next.chapters.removeAll{$0.id==id};if next.active==id{next.active=next.chapters.first?.id};try commit(next)}
    func mark(_ bubble:UUID,in chapter:UUID,page:UUID?=nil,layer:UUID?=nil,used:Bool)throws {
        var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}),let b=next.chapters[c].bubbles.firstIndex(where:{$0.id==bubble}) else{return}
        next.chapters[c].bubbles[b].usedAt=used ? Date():nil;next.chapters[c].bubbles[b].usedOnPage=used ? page:nil;next.chapters[c].bubbles[b].usedLayer=used ? layer:nil
        next.chapters[c].modified=Date();try commit(next)
    }
    func reset(_ chapter:UUID)throws {var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}) else{return};for index in next.chapters[c].bubbles.indices{next.chapters[c].bubbles[index].usedAt=nil;next.chapters[c].bubbles[index].usedOnPage=nil;next.chapters[c].bubbles[index].usedLayer=nil};try commit(next)}
    func saveTag(_ tag:DialogueTag)throws {var next=state;if let i=next.tags.firstIndex(where:{$0.id==tag.id}){next.tags[i]=tag}else{next.tags.append(tag)};try commit(next)}
    func removeTag(_ id:UUID)throws {var next=state;next.tags.removeAll{$0.id==id};try commit(next)}
    func importFile(_ url:URL,folder:UUID?)throws {
        let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}}
        let bytes=try Data(contentsOf:url)
        if url.pathExtension.lowercased()=="json" {
            var chapter=try JSONDecoder().decode(DialogueChapter.self,from:bytes);chapter.id=UUID();chapter.folder=folder
            // Imported style IDs may belong to another library. Resolve ordinary
            // text to the local default rather than silently assigning wrong styles.
            for i in chapter.bubbles.indices where tag(chapter.bubbles[i].tagID)==nil {chapter.bubbles[i].tagID=state.tags.first?.id}
            var next=state;next.chapters.insert(chapter,at:0);next.active=chapter.id;try commit(next)
        }else {try saveChapter(title:url.deletingPathExtension().lastPathComponent,source:TranscriptParser.decode(bytes),separation:.lines,folder:folder)}
    }
    func export(_ chapter:DialogueChapter,plain:Bool)throws->URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Chapter-\(chapter.id.uuidString)."+(plain ? "txt":"json"))
        try (plain ? Data(chapter.source.utf8):JSONEncoder().encode(chapter)).write(to:url,options:.atomic);return url
    }
    func place(_ bubbles:[DialogueBubble],chapter:UUID,model:EditorModel,targets:[SniperTarget]=[])throws {
        guard !bubbles.isEmpty else{return}
        let before=model.page
        let layers=try model.insertDialogues(bubbles.map{($0.text,tag($0.tagID)?.style)},targets:targets)
        do {
            var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}) else{throw ImageFailure.message("لم يعد الفصل موجودًا")}
            for (bubble,layer) in zip(bubbles,layers) {if let i=next.chapters[c].bubbles.firstIndex(where:{$0.id==bubble.id}){next.chapters[c].bubbles[i].usedAt=Date();next.chapters[c].bubbles[i].usedOnPage=model.page.id;next.chapters[c].bubbles[i].usedLayer=layer}}
            next.chapters[c].modified=Date();try commit(next)
        }catch {
            // Keep insertion and progress coherent if the second atomic file
            // cannot be written (for example, device storage is full).
            try model.library.persist(before);model.page=before;model.selected=nil;_ = model.undoStack.popLast();throw error
        }
    }
}
