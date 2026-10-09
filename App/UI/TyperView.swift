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
            Text("التايبر").font(.system(size:28,weight:.semibold))
            Text("نص الفصل، فقاعاته، وتقدّمك في التحرير.").font(.system(size:13)).foregroundStyle(Palette.quiet)
            HStack{Button{newChapter=true}label:{Label("فصل جديد",systemImage:"plus")}.accessibilityIdentifier("typer-new");Spacer();Button{importing=true}label:{Label("استيراد نص",systemImage:"doc.badge.plus")}.accessibilityIdentifier("typer-import")}.font(.system(size:14,weight:.medium)).padding(16).glass(16)
            if let drafts=typer.state.drafts,!drafts.isEmpty{DisclosureGroup("المسودات (\(drafts.count))"){ForEach(drafts){item in HStack{Button(item.title.isEmpty ? "مسودة نص":item.title){draft=item};Spacer();Button(role:.destructive){do{try typer.removeDraft(item.id)}catch{typer.error=error.localizedDescription}}label:{Image(systemName:"trash")}}.font(.system(size:12)).padding(10)}}}
            if let deleted=typer.state.deletedChapters,!deleted.isEmpty{DisclosureGroup("المهملات (\(deleted.count))"){ForEach(deleted){chapter in HStack{Text(chapter.title);Spacer();Button("استرجاع"){do{try typer.restore(chapter.id)}catch{typer.error=error.localizedDescription}};Button(role:.destructive){do{try typer.deletePermanently(chapter.id)}catch{typer.error=error.localizedDescription}}label:{Image(systemName:"trash")}}.font(.system(size:12)).padding(10)}}}
            if typer.state.chapters.isEmpty{ContentUnavailableView("أضف نص الفصل",systemImage:"text.bubble",description:Text("اكتب الحوارات أو استورد ملف TXT. كل سطر يصبح فقاعة مستقلة، وتُحفظ الفقاعات المستخدمة لتتبع تقدّمك."))}
            else{TextField("بحث في الفصول",text:$query).padding(14).glass(12)
                ForEach(typer.state.chapters.filter{query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)}){chapter in
                    Button{do{try typer.activate(chapter.id);editing=chapter}catch{typer.error=error.localizedDescription}}label:{VStack(alignment:.leading,spacing:12){HStack{Image(systemName:"text.bubble");Text(chapter.title).font(.system(size:16,weight:.semibold));Spacer();if typer.state.active==chapter.id{Image(systemName:"checkmark.circle")}};ProgressView(value:Double(chapter.usedCount),total:Double(max(1,chapter.pasteable.count))).tint(Palette.gold);Text("\(chapter.usedCount) من \(chapter.pasteable.count) فقاعة مستخدمة").font(.system(size:12)).foregroundStyle(Palette.quiet)}.padding(18).glass(18)}.buttonStyle(.plain).accessibilityIdentifier("typer-chapter-\(chapter.id)").contextMenu{Button("حذف الفصل",role:.destructive){deletion=chapter}}
                }
            }
        }.padding(24).frame(maxWidth:760).frame(maxWidth:.infinity)}}.toolbar(.hidden,for:.navigationBar)
        .fullScreenCover(isPresented:$newChapter){ChapterSourceView(folder:folder)}
        .fullScreenCover(item:$editing){chapter in ChapterSourceView(chapter:chapter,folder:chapter.folder)}
        .fullScreenCover(item:$draft){chapter in ChapterSourceView(chapter:chapter,folder:chapter.folder,isDraft:true)}
        .fileImporter(isPresented:$importing,allowedContentTypes:[.plainText,.json],allowsMultipleSelection:false){result in do{try typer.importFile(result.get()[0],folder:folder)}catch{typer.error=error.localizedDescription}}
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
            Text("## عنوان · () تفكير · ** مؤثرات · // استمرار الوسم السابق").font(.system(size:11)).foregroundStyle(Palette.quiet)
            if let exporting{ShareLink(item:exporting){Label("مشاركة الملف",systemImage:"square.and.arrow.up")}}
        }.padding(.horizontal,20).padding(.bottom,20).frame(maxWidth:820).frame(maxWidth:.infinity)}.toolbar(.hidden,for:.navigationBar)}.foregroundStyle(Palette.pale).cookiesInterface().typerErrors(typer)
        .task(id:title+source+separation.rawValue){guard !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!saved else{return};do{try await Task.sleep(nanoseconds:400_000_000);try Task.checkCancellation();try persistDraft()}catch is CancellationError{}catch{typer.error=error.localizedDescription}}
        .onAppear{if let chapter{if isDraft{draftID=chapter.id};title=chapter.title;source=chapter.source;separation=chapter.separation}else{separation=BubbleSeparation(rawValue:UserDefaults.standard.string(forKey:"typer-default-separation") ?? "lines") ?? .lines}}
    }
    private func persistDraft()throws{guard !source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!saved else{return};var draft=DialogueChapter(title:title,source:source);draft.id=draftID;draft.folder=folder;draft.separation=separation;draft.draftSourceID=isDraft ? chapter?.draftSourceID:chapter?.id;try typer.saveDraft(draft)}
    private func export(plain:Bool){do{guard let chapter else{return};exporting=try typer.export(chapter,plain:plain)}catch{typer.error=error.localizedDescription}}
}

/// An editor overlay, not a blocking sheet: the canvas and selected text remain
/// available while the user chooses and tracks chapter bubbles.
struct TyperPanel:View {
    @EnvironmentObject var typer:TyperStore
    @EnvironmentObject var styles:StyleStore
    @ObservedObject var model:EditorModel
    var close:()->Void
    var compact=false
    @State private var query=""
    @State private var filter="all"
    @State private var library=false
    @State private var reset=false
    @State private var uppercase=false
    @State private var overrideTag:UUID?
    @State private var quickFont:String?
    @State private var textFormat=""
    @State private var editing:DialogueBubble?
    var body:some View {
        VStack(spacing:0){
            HStack(spacing:8){Image(systemName:"text.bubble");Text("التايبر").font(.system(size:14,weight:.semibold));Spacer();IconButton(icon:"xmark",title:"إغلاق لوحة التايبر",action:close).accessibilityIdentifier("typer-panel-close")}.padding(.leading,14).frame(height:48)
            HStack{Menu{ForEach(typer.state.chapters){chapter in Button(chapter.title){do{try typer.activate(chapter.id)}catch{typer.error=error.localizedDescription}}};Divider();Button("إدارة الفصول"){library=true}}label:{HStack{Text(typer.activeChapter?.title ?? "اختر نص الفصل").lineLimit(1);Image(systemName:"chevron.down")}.font(.system(size:12,weight:.medium))}.accessibilityIdentifier("typer-chapters");Spacer();Text("\(typer.activeChapter?.usedCount ?? 0) / \(typer.activeChapter?.pasteable.count ?? 0)").font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.quiet).accessibilityIdentifier("typer-progress")}.padding(.horizontal,14).padding(.bottom,10)
            if let chapter=typer.activeChapter {
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){Menu{ForEach(typer.tagSets){group in Button(group.title){do{try typer.activateTagSet(group.id);overrideTag=nil}catch{typer.error=error.localizedDescription}}}}label:{Label("الوسوم",systemImage:"tag")};ForEach(typer.state.tags.filter{!$0.noPaste}){tag in Button(tag.title){overrideTag=overrideTag==tag.id ? nil:tag.id}.padding(7).background(overrideTag==tag.id ? Palette.gold.opacity(0.15):.white.opacity(0.04),in:RoundedRectangle(cornerRadius:8))}}.font(.system(size:10)).padding(.horizontal,12)}.frame(height:36)
                if let fonts=typer.state.quickFonts,!fonts.isEmpty{ScrollView(.horizontal,showsIndicators:false){HStack{ForEach(fonts,id:\.self){font in Button(URL(fileURLWithPath:font).deletingPathExtension().lastPathComponent){quickFont=quickFont==font ? nil:font}.padding(6).background(quickFont==font ? Palette.gold.opacity(0.15):.clear,in:RoundedRectangle(cornerRadius:8))}}.font(.system(size:10)).padding(.horizontal,12)}.frame(height:30)}
                if !compact{HStack(spacing:6){Image(systemName:"magnifyingglass").foregroundStyle(Palette.quiet);TextField("بحث في الفقاعات",text:$query).font(.system(size:12));Menu{Button("الكل"){filter="all"};Button("المتبقية"){filter="unused"};Button("المستخدمة"){filter="used"}}label:{Image(systemName:"line.3.horizontal.decrease.circle")}}.padding(10).background(.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius:10)).padding(.horizontal,12)}
                ScrollView{LazyVStack(spacing:7){ForEach(Array(chapter.bubbles.enumerated()),id:\.element.id){index,bubble in
                    if (query.isEmpty || bubble.text.localizedCaseInsensitiveContains(query)) && (filter=="all" || (filter=="used" ? bubble.used:!bubble.used)) {
                        Button{insert([bubble],chapter:chapter.id)}label:{HStack(alignment:.top,spacing:9){Text("\(index+1)").font(.system(size:10,design:.monospaced)).frame(width:22);VStack(alignment:.leading,spacing:5){HStack{Text(typer.tag(bubble.tagID)?.title ?? "حوار").font(.system(size:9));Spacer();if bubble.used{Image(systemName:"checkmark.circle.fill")}}.foregroundStyle(Palette.quiet);Text(bubble.text).font(.system(size:13)).lineLimit(4).multilineTextAlignment(.leading)}}.padding(11).frame(maxWidth:.infinity,alignment:.leading).background(bubble.used ? Color(white:0.18):Palette.gold.opacity(bubble.noPaste ? 0.025:0.08),in:RoundedRectangle(cornerRadius:11)).foregroundStyle(bubble.used ? Color(white:0.54):Palette.pale)}.buttonStyle(.plain).disabled(bubble.noPaste || model.busy).accessibilityIdentifier("typer-bubble-\(index)").accessibilityValue(bubble.noPaste ? "عنوان":bubble.used ? "مستخدمة":"متاحة").contextMenu{Button("تعديل الفقاعة"){editing=bubble};Button("تقديم الفقاعة"){move(bubble.id,by:-1,in:chapter)}.disabled(index==0);Button("تأخير الفقاعة"){move(bubble.id,by:1,in:chapter)}.disabled(index==chapter.bubbles.count-1);Button("نسخ النص"){UIPasteboard.general.string=bubble.text};Button(bubble.used ? "إعادتها إلى المتبقية":"تحديد كمستخدمة"){do{try typer.mark(bubble.id,in:chapter.id,used:!bubble.used)}catch{typer.error=error.localizedDescription}}}
                    }
                }}}.padding(12).accessibilityIdentifier("typer-bubbles")
                if !compact{HStack{Button{library=true}label:{Image(systemName:"doc.badge.plus")}.accessibilityLabel("تحرير أو استيراد الفصل");Spacer();Button{uppercase.toggle()}label:{Image(systemName:"textformat.abc")}.accessibilityLabel("تحويل إلى أحرف كبيرة");Spacer();Button{reset=true}label:{Image(systemName:"arrow.counterclockwise")}.accessibilityLabel("إعادة تعيين الفقاعات المستخدمة")}.font(.system(size:17)).padding(.horizontal,22).frame(height:40)}
                HStack{Button{editing=DialogueBubble(text:"",tagID:typer.state.tags.first?.id)}label:{Image(systemName:"plus.bubble")};Spacer();Picker("تنسيق الإدراج",selection:$textFormat){Text("كما هو").tag("");Text("مربع").tag("box");Text("دائرة").tag("circle")}.pickerStyle(.menu)}.font(.system(size:11)).padding(.horizontal,14)
                HStack(spacing:8){Button{model.sniperMode.toggle();model.tool = .move;model.panel=nil;close()}label:{Label("القنص",systemImage:"scope")}.font(.system(size:12)).padding(.horizontal,12).frame(height:42).glass(12).accessibilityIdentifier("typer-sniper")
                    Button{let count=max(1,model.sniperTargets.count);let next=Array(chapter.bubbles.filter{!$0.noPaste && !$0.used}.prefix(count));insert(next,chapter:chapter.id)}label:{Label(model.sniperTargets.isEmpty ? "الفقاعة التالية":"إدراج \(model.sniperTargets.count) أهداف",systemImage:"text.badge.plus")}.buttonStyle(GoldButtonStyle(primary:true)).disabled(chapter.pasteable.allSatisfy(\.used)).accessibilityIdentifier("typer-next")
                }.padding(12)
            }else{VStack(spacing:16){Image(systemName:"doc.text").font(.system(size:30,weight:.light));Text("أضف ملف الفصل أو اكتب النص، ثم اختر أي فقاعة لإدراجها في الصورة.").font(.system(size:12)).multilineTextAlignment(.center).foregroundStyle(Palette.quiet);Button("إضافة نص الفصل"){library=true}.buttonStyle(GoldButtonStyle(primary:true))}.padding(20).frame(maxHeight:.infinity)}
        }.foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.9)).glass(20)
        .fullScreenCover(isPresented:$library){TyperLibraryView()}
        .sheet(item:$editing){bubble in if let chapter=typer.activeChapter{BubbleEditor(bubble:bubble,chapter:chapter.id).cookiesInterface()}}
        .alert("إعادة تعيين التقدّم؟",isPresented:$reset){Button("إعادة تعيين",role:.destructive){if let chapter=typer.activeChapter{do{try typer.reset(chapter.id)}catch{typer.error=error.localizedDescription}}};Button("إلغاء",role:.cancel){}}message:{Text("تصبح كل الفقاعات متاحة مجددًا. لن تُحذف طبقات النص من الصور.")}
        .typerErrors(typer)
    }
    private func insert(_ bubbles:[DialogueBubble],chapter:UUID){
        do {let remaining=Array(bubbles.filter{!$0.noPaste}.prefix(model.sniperTargets.isEmpty ? bubbles.count:model.sniperTargets.count))
            var values=remaining;if uppercase{for i in values.indices{values[i].text=values[i].text.uppercased()}}
            try typer.place(values,chapter:chapter,model:model,targets:model.sniperTargets,overrideTag:overrideTag,font:quickFont,format:textFormat,styleAssets:styles.directory);model.sniperTargets=[];model.sniperMode=false
        }catch{typer.error=error.localizedDescription}
    }
    private func move(_ id:UUID,by delta:Int,in chapter:DialogueChapter){var ids=chapter.bubbles.map(\.id);guard let index=ids.firstIndex(of:id),ids.indices.contains(index+delta) else{return};ids.swapAt(index,index+delta);do{try typer.reorderBubbles(ids,in:chapter.id)}catch{typer.error=error.localizedDescription}}
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
private extension View {func typerErrors(_ store:TyperStore)->some View{modifier(TyperError(store:store))}}
