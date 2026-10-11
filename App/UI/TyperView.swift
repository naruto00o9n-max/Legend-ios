import SwiftUI
import UniformTypeIdentifiers

struct TyperLibraryView:View {
    @EnvironmentObject var typer:TyperStore
    @Environment(\.dismiss) private var dismiss
    var folder:UUID?=nil
    @State private var editing:DialogueChapter?
    @State private var newChapter=false
    @State private var importing=false
    @State private var query=""
    @State private var deletion:DialogueChapter?
    @State private var draft:DialogueChapter?
    var body:some View {
        NavigationStack {ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:18){
            HStack{Brand();Spacer();IconButton(icon:"xmark",title:"إغلاق التايبر"){dismiss()}.accessibilityIdentifier("typer-close")}
            SurfaceHeader(title:"استوديو الحوارات",subtitle:"الفصل من نصه الأول إلى آخر فقاعة",icon:"text.bubble")
            HStack(spacing:12){Button{newChapter=true}label:{Label("فصل جديد",systemImage:"plus")}.buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("typer-new");Button{importing=true}label:{Label("استيراد نص",systemImage:"doc.badge.plus")}.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("typer-import")}
            if let drafts=typer.state.drafts,!drafts.isEmpty{DisclosureGroup("المسودات (\(drafts.count))"){ForEach(drafts){item in HStack{Button(item.title.isEmpty ? "مسودة نص":item.title){draft=item};Spacer();Button(role:.destructive){do{try typer.removeDraft(item.id)}catch{typer.error=error.localizedDescription}}label:{Image(systemName:"trash")}}.font(.system(size:12)).padding(10)}}}
            if let deleted=typer.state.deletedChapters,!deleted.isEmpty{DisclosureGroup("المهملات (\(deleted.count))"){ForEach(deleted){chapter in HStack{Text(chapter.title);Spacer();Button("استرجاع"){do{try typer.restore(chapter.id)}catch{typer.error=error.localizedDescription}};Button(role:.destructive){do{try typer.deletePermanently(chapter.id)}catch{typer.error=error.localizedDescription}}label:{Image(systemName:"trash")}}.font(.system(size:12)).padding(10)}}}
            if typer.state.chapters.isEmpty{WorkspaceEmpty(title:"أضف أول فصل",detail:"اكتب الحوارات أو استورد TXT. تُحفظ الفقاعات المستخدمة لتعرف دائمًا أين وصلت.",icon:"text.bubble")}
            else{SearchBar(placeholder:"بحث في الفصول",text:$query)
                ForEach(typer.state.chapters.filter{query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)}){chapter in
                    Button{do{try typer.activate(chapter.id);editing=chapter}catch{typer.error=error.localizedDescription}}label:{VStack(alignment:.leading,spacing:12){HStack{Image(systemName:"text.bubble");Text(chapter.title).font(.system(size:16,weight:.semibold));Spacer();if typer.state.active==chapter.id{Image(systemName:"checkmark.circle")}};ProgressView(value:Double(chapter.usedCount),total:Double(max(1,chapter.pasteable.count))).tint(Palette.gold);Text("\(chapter.usedCount) من \(chapter.pasteable.count) فقاعة مستخدمة").font(.system(size:12)).foregroundStyle(Palette.quiet)}.padding(18).glass(18)}.buttonStyle(.plain).accessibilityIdentifier("typer-chapter-\(chapter.id)").contextMenu{Button("حذف الفصل",role:.destructive){deletion=chapter}}
                }
            }
        }.padding(24).frame(maxWidth:760).frame(maxWidth:.infinity)}}.toolbar(.hidden,for:.navigationBar)
        .fullScreenCover(isPresented:$newChapter){ChapterSourceView(folder:folder)}
        .fullScreenCover(item:$editing){chapter in ChapterSourceView(chapter:chapter,folder:chapter.folder)}
        .fullScreenCover(item:$draft){chapter in ChapterSourceView(chapter:chapter,folder:chapter.folder,isDraft:true)}
        .cookiesFileImporter(isPresented:$importing,allowedContentTypes:[.plainText,.json],allowsMultipleSelection:false){result in do{try typer.importFile(result.get()[0],folder:folder)}catch{typer.error=error.localizedDescription}}
        .alert("حذف الفصل؟",isPresented:Binding(get:{deletion != nil},set:{if !$0{deletion=nil}})){Button("حذف",role:.destructive){if let chapter=deletion{do{try typer.remove(chapter.id)}catch{typer.error=error.localizedDescription}};deletion=nil};Button("إلغاء",role:.cancel){deletion=nil}}message:{Text("سيُحذف النص وتقدّمه من التايبر. تبقى طبقات النص الموجودة في الصور.")}
        }.foregroundStyle(Palette.pale).cookiesInterface().typerErrors(typer)
    }
}
struct ChapterSourceView:View {
    @EnvironmentObject var typer:TyperStore
    @Environment(\.dismiss) private var dismiss
    var chapter:DialogueChapter?
    var folder:UUID?
    var isDraft=false
    @State private var draftID=UUID()
    @State private var saved=false
    @State private var title=""
    @State private var source=""
    @State private var separation=BubbleSeparation.lines
    @State private var exporting:URL?
    @FocusState private var focused:Bool
    var count:Int {TranscriptParser.parse(source,separation:separation,tags:typer.state.tags,link:typer.state.linkPrefix).filter{!$0.noPaste}.count}
    var body:some View {
        NavigationStack{ZStack{Ambient();VStack(spacing:14){
            HStack{IconButton(icon:"xmark",title:"إلغاء"){do{try persistDraft();dismiss()}catch{typer.error=error.localizedDescription}};Spacer();Text(chapter==nil ? "نص فصل جديد":"تحرير نص الفصل").font(.system(size:17,weight:.semibold));Spacer();Button("حفظ"){do{try typer.saveChapter(id:isDraft ? chapter?.draftSourceID:chapter?.id,title:title,source:source,separation:separation,folder:folder);saved=true;try typer.removeDraft(draftID);dismiss()}catch{typer.error=error.localizedDescription}}.disabled(count==0).accessibilityIdentifier("typer-save")}.padding(.horizontal,12)
            TextField("اسم الفصل",text:$title).font(.system(size:17,weight:.medium)).padding(16).glass(14).accessibilityIdentifier("typer-title")
            Picker("فصل الفقاعات",selection:$separation){ForEach(BubbleSeparation.allCases,id:\.self){mode in Text(mode.title).tag(mode)}}.pickerStyle(.segmented).accessibilityIdentifier("typer-separation")
            ArabicTextEditor(text:$source).padding(12).glass(18).accessibilityIdentifier("typer-source").focused($focused)
            HStack{Text("\(count) فقاعة قابلة للإدراج").font(.system(size:12)).foregroundStyle(Palette.quiet);Spacer();Button{source=UIPasteboard.general.string ?? source}label:{Label("لصق",systemImage:"doc.on.clipboard")}.accessibilityIdentifier("typer-clipboard")
                if chapter != nil{Menu{Button("تصدير TXT"){export(plain:true)};Button("تصدير الفصل مع تقدّمه"){export(plain:false)}}label:{Image(systemName:"square.and.arrow.up")}}
            }.font(.system(size:14)).padding(.vertical,8)
            HStack(spacing:8){Image(systemName:"tag");Text("## عنوان · () تفكير · ** مؤثرات · // استمرار الوسم السابق").fixedSize(horizontal:false,vertical:true)}.font(.system(size:11)).foregroundStyle(Palette.secondary).padding(12).glass(14)
            if let exporting{ShareLink(item:exporting){Label("مشاركة الملف",systemImage:"square.and.arrow.up")}}
        }.padding(.horizontal,20).padding(.bottom,20).frame(maxWidth:820).frame(maxWidth:.infinity)}.toolbar(.hidden,for:.navigationBar)}.foregroundStyle(Palette.pale).cookiesInterface().typerErrors(typer)
        .task(id:title+source+separation.rawValue){guard !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!saved else{return};do{try await Task.sleep(nanoseconds:400_000_000);try Task.checkCancellation();try persistDraft()}catch is CancellationError{}catch{typer.error=error.localizedDescription}}
        .onAppear{if let chapter{if isDraft{draftID=chapter.id};title=chapter.title;source=chapter.source;separation=chapter.separation}else{separation=BubbleSeparation(rawValue:UserDefaults.standard.string(forKey:"typer-default-separation") ?? "lines") ?? .lines}}
    }
    private func persistDraft()throws{guard !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!saved else{return};var draft=DialogueChapter(title:title,source:source);draft.id=draftID;draft.folder=folder;draft.separation=separation;draft.draftSourceID=isDraft ? chapter?.draftSourceID:chapter?.id;try typer.saveDraft(draft)}
    private func export(plain:Bool){do{guard let chapter else{return};exporting=try typer.export(chapter,plain:plain)}catch{typer.error=error.localizedDescription}}
}

struct BubbleEditor:View {
    @EnvironmentObject var typer:TyperStore
    @Environment(\.dismiss) var dismiss
    @State var bubble:DialogueBubble
    let chapter:UUID
    var body:some View{NavigationStack{Form{ArabicTextEditor(text:$bubble.text).frame(height:160);Picker("الوسم",selection:Binding(get:{bubble.tagID ?? typer.state.tags.first?.id ?? UUID()},set:{bubble.tagID=$0;bubble.noPaste=typer.tag($0)?.noPaste ?? false})){ForEach(typer.state.tags){tag in Text(tag.title).tag(tag.id)}};Toggle("عنوان لا يُدرج",isOn:$bubble.noPaste);Text("تحرير النص لا يمحو حالة الاستخدام.").font(.system(size:12))}.navigationTitle("تحرير الفقاعة").toolbar{ToolbarItem(placement:.topBarLeading){Button("إلغاء"){dismiss()}};ToolbarItem(placement:.topBarTrailing){Button("حفظ"){do{try typer.updateBubble(bubble,in:chapter);dismiss()}catch{typer.error=error.localizedDescription}}.disabled(bubble.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}}}
}
private struct TyperError:ViewModifier {
    @ObservedObject var store:TyperStore
    func body(content:Content)->some View{content.alert("تعذر حفظ التايبر",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("حسنًا"){store.error=nil}}message:{Text(store.error ?? "")}}
}
extension View {func typerErrors(_ store:TyperStore)->some View{modifier(TyperError(store:store))}}
