import Foundation
import SwiftUI
import UIKit

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
    var draftSourceID:UUID?
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
    var drafts:[DialogueChapter]?
    var retiredTags:[DialogueTag]?
    var tagSets:[DialogueTagSet]?
    var activeTagSet:UUID?
    var deletedChapters:[DialogueChapter]?
    var quickFonts:[String]?
}
struct DialogueTagSet:Codable,Equatable,Identifiable{var id=UUID();var title:String;var tags:[DialogueTag]}
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
    private var storageReadable=true
    let directory: URL
    init(directory:URL?=nil) {
        self.directory=directory ?? FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Cookies/Typer",isDirectory:true)
        if ProcessInfo.processInfo.arguments.contains("-ui-tests"),directory==nil {try? FileManager.default.removeItem(at:self.directory)}
        do {try FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true)
            let url=self.directory.appendingPathComponent("chapters.json")
            if let saved=try RecoveryFile.read(TyperState.self,at:url){state=saved.value;if saved.recovered{self.error="استُعيدت آخر نسخة سليمة من بياناتك."}}
            if state.tagSets==nil{let group=DialogueTagSet(title:"افتراضي",tags:state.tags);var next=state;next.tagSets=[group];next.activeTagSet=group.id;try commit(next)}
        }catch{storageReadable=false;self.error="تعذر فتح فصول التايبر: "+error.localizedDescription}
    }
    var activeChapter:DialogueChapter? {state.chapters.first{$0.id==state.active}}
    func chapter(_ id:UUID)->DialogueChapter? {state.chapters.first{$0.id==id}}
    func tag(_ id:UUID?)->DialogueTag? {state.tags.first{$0.id==id} ?? state.tagSets?.flatMap(\.tags).first{$0.id==id} ?? state.retiredTags?.first{$0.id==id}}
    var tagSets:[DialogueTagSet]{state.tagSets ?? []}
    private func commit(_ state:TyperState)throws {guard storageReadable else{throw ImageFailure.message("تعذر قراءة بيانات التايبر؛ احتُفظ بالملف التالف للاستعادة ولم تُستبدل بياناتك")};var next=state;if let index=next.tagSets?.firstIndex(where:{$0.id==next.activeTagSet}){next.tagSets?[index].tags=next.tags};try RecoveryFile.write(next,at:directory.appendingPathComponent("chapters.json"));self.state=next}
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
    func remove(_ id:UUID)throws {var next=state;if let chapter=chapter(id){next.deletedChapters=(next.deletedChapters ?? [])+[chapter]};next.chapters.removeAll{$0.id==id};if next.active==id{next.active=next.chapters.first?.id};try commit(next)}
    func restore(_ id:UUID)throws{var next=state;guard let chapter=next.deletedChapters?.first(where:{$0.id==id}) else{return};next.chapters.append(chapter);next.deletedChapters?.removeAll{$0.id==id};next.active=id;try commit(next)}
    func deletePermanently(_ id:UUID)throws{var next=state;next.deletedChapters?.removeAll{$0.id==id};try commit(next)}
    func createTagSet(title:String,copyActive:Bool)throws{var next=state;let tags=(copyActive ? state.tags:DialogueTag.defaults).map{value in var tag=value;tag.id=UUID();return tag};let group=DialogueTagSet(title:title.isEmpty ? "مجموعة جديدة":title,tags:tags);next.tagSets=(next.tagSets ?? [])+[group];try commit(next);try activateTagSet(group.id)}
    func activateTagSet(_ id:UUID)throws{var next=state;guard let group=next.tagSets?.first(where:{$0.id==id}) else{return};next.tags=group.tags;next.activeTagSet=id;try commit(next)}
    func renameTagSet(_ id:UUID,title:String)throws{var next=state;guard let index=next.tagSets?.firstIndex(where:{$0.id==id}),!title.isEmpty else{return};next.tagSets?[index].title=title;try commit(next)}
    func removeTagSet(_ id:UUID)throws{guard tagSets.count>1 else{throw ImageFailure.message("احتفظ بمجموعة وسوم واحدة على الأقل")};var next=state;if let group=next.tagSets?.first(where:{$0.id==id}){next.retiredTags=(next.retiredTags ?? [])+group.tags};next.tagSets?.removeAll{$0.id==id};if next.activeTagSet==id{next.activeTagSet=next.tagSets?.first?.id;next.tags=next.tagSets?.first?.tags ?? DialogueTag.defaults};try commit(next)}
    func saveDraft(_ chapter:DialogueChapter)throws{var next=state;if let i=next.drafts?.firstIndex(where:{$0.id==chapter.id}){next.drafts?[i]=chapter}else{next.drafts=(next.drafts ?? [])+[chapter]};try commit(next)}
    func removeDraft(_ id:UUID)throws{var next=state;next.drafts?.removeAll{$0.id==id};try commit(next)}
    func setQuickFonts(_ fonts:[String])throws{var next=state;next.quickFonts=Array(Set(fonts)).sorted();try commit(next)}
    func setLinkPrefix(_ prefix:String)throws{var next=state;next.linkPrefix=prefix;try commit(next)}
    private func serialized(_ chapter:DialogueChapter)->String{chapter.bubbles.map{bubble in let prefix=tag(bubble.tagID)?.prefix ?? "";return prefix+(prefix.isEmpty ? "":" ")+bubble.text}.joined(separator:chapter.separation == .lines ? "\n":"\n\n")}
    func updateBubble(_ bubble:DialogueBubble,in chapter:UUID)throws{var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}) else{return};if let index=next.chapters[c].bubbles.firstIndex(where:{$0.id==bubble.id}){next.chapters[c].bubbles[index]=bubble}else{next.chapters[c].bubbles.append(bubble)};next.chapters[c].source=serialized(next.chapters[c]);next.chapters[c].modified=Date();try commit(next)}
    func reorderBubbles(_ ids:[UUID],in chapter:UUID)throws{var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}),Set(ids)==Set(next.chapters[c].bubbles.map(\.id)),ids.count==next.chapters[c].bubbles.count else{throw ImageFailure.message("ترتيب الفقاعات غير صالح")};let map=Dictionary(uniqueKeysWithValues:next.chapters[c].bubbles.map{($0.id,$0)});next.chapters[c].bubbles=ids.compactMap{map[$0]};next.chapters[c].source=serialized(next.chapters[c]);try commit(next)}
    func mark(_ bubble:UUID,in chapter:UUID,page:UUID?=nil,layer:UUID?=nil,used:Bool)throws {
        var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}),let b=next.chapters[c].bubbles.firstIndex(where:{$0.id==bubble}) else{return}
        next.chapters[c].bubbles[b].usedAt=used ? Date():nil;next.chapters[c].bubbles[b].usedOnPage=used ? page:nil;next.chapters[c].bubbles[b].usedLayer=used ? layer:nil
        next.chapters[c].modified=Date();try commit(next)
    }
    func reset(_ chapter:UUID)throws {var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}) else{return};for index in next.chapters[c].bubbles.indices{next.chapters[c].bubbles[index].usedAt=nil;next.chapters[c].bubbles[index].usedOnPage=nil;next.chapters[c].bubbles[index].usedLayer=nil};try commit(next)}
    func saveTag(_ tag:DialogueTag)throws {var next=state;if let i=next.tags.firstIndex(where:{$0.id==tag.id}){next.tags[i]=tag}else{next.tags.append(tag)};try commit(next)}
    func removeTag(_ id:UUID)throws {var next=state;if let tag=tag(id){next.retiredTags=(next.retiredTags ?? [])+[tag]};next.tags.removeAll{$0.id==id};try commit(next)}
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
    func place(_ bubbles:[DialogueBubble],chapter:UUID,model:EditorModel,targets:[SniperTarget]=[],overrideTag:UUID?=nil,font:String?=nil,format:String="",styleAssets:URL?=nil)throws {
        guard !bubbles.isEmpty else{return}
        let before=model.page
        let assets=styleAssets ?? directory.deletingLastPathComponent().appendingPathComponent("Styles")
        let values=try bubbles.map{bubble->(String,TextStyle?) in
            let previous=tag(bubble.tagID);var style=(tag(overrideTag) ?? state.tags.first{$0.prefix==previous?.prefix} ?? previous)?.style ?? TextStyle()
            if let font{style.fontPath=font}
            if !style.texturePath.isEmpty{let source=assets.appendingPathComponent(style.texturePath);guard FileManager.default.fileExists(atPath:source.path) else{throw ImageFailure.message("خامة وسم التايبر مفقودة")};let name=UUID().uuidString+"."+source.pathExtension;try FileManager.default.copyItem(at:source,to:model.directory.appendingPathComponent(name));style.texturePath=name}
            let formatter=Typesetter(measure:{Double((($0 as NSString).size(withAttributes:[.font:Fonts.font(style)])).width)})
            let text=format=="box" ? formatter.box(bubble.text,width:style.boxWidth,tatweel:true):format=="circle" ? formatter.circle(bubble.text,width:style.boxWidth,fontSize:style.fontSize):bubble.text
            return (text,style)
        }
        let layers=try model.insertDialogues(values,targets:targets)
        do {
            var next=state;guard let c=next.chapters.firstIndex(where:{$0.id==chapter}) else{throw ImageFailure.message("لم يعد الفصل موجودًا")}
            for (bubble,layer) in zip(bubbles,layers) {if let i=next.chapters[c].bubbles.firstIndex(where:{$0.id==bubble.id}){next.chapters[c].bubbles[i].usedAt=Date();next.chapters[c].bubbles[i].usedOnPage=model.page.id;next.chapters[c].bubbles[i].usedLayer=layer}}
            next.chapters[c].modified=Date();try commit(next)
        }catch {
            // Keep insertion and progress coherent if the second atomic file
            // cannot be written (for example, device storage is full).
            try model.library.persist(before);model.page=before;model.selected=nil;_ = model.undoStack.popLast();_ = model.undoDocuments.popLast();throw error
        }
    }
}
