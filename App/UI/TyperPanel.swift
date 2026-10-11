import SwiftUI

/// A nonblocking chapter navigator; editing the canvas remains possible beside it.
struct TyperPanel:View {
    @EnvironmentObject private var typer:TyperStore
    @EnvironmentObject private var styles:StyleStore
    @ObservedObject var model:EditorModel
    var close:()->Void
    var compact=false
    @State private var preferences=TyperPanelPreferences()
    @State private var loaded=false
    @State private var library=false
    @State private var settings=false
    @State private var reset=false
    @State private var editing:DialogueBubble?
    @State private var scrollRequest=UUID()
    private var chapter:DialogueChapter?{typer.activeChapter}
    private var scrollKey:String{(chapter?.id.uuidString ?? "")+preferences.filter.rawValue+preferences.query+scrollRequest.uuidString}
    private var cursor:UUID?{chapter.flatMap{preferences.cursor(in:$0.id)}}
    var body:some View {
        VStack(spacing:0){
            header
            if let chapter{
                chapterHeader(chapter)
                filters
                if preferences.expanded && !compact{insertionOptions}
                bubbleList(chapter)
                footer(chapter)
            }else{VStack(spacing:16){SurfaceSymbol(icon:"text.bubble",size:54);Text("كل حوار في مكانه").font(.system(size:17,weight:.semibold));Text("أضف نص الفصل أو استورد ملفه، ثم ضع الفقاعات في الصورة وتابع تقدّمك.").font(.system(size:12)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center);Button{library=true}label:{Label("إضافة نص الفصل",systemImage:"doc.badge.plus")}.buttonStyle(GoldButtonStyle(primary:true))}.padding(20).frame(maxHeight:.infinity)}
        }.foregroundStyle(Palette.pale).floatingGlass(26)
        .fullScreenCover(isPresented:$library){TyperLibraryView()}
        .sheet(isPresented:$settings){TyperSettingsView()}
        .sheet(item:$editing){bubble in if let chapter{BubbleEditor(bubble:bubble,chapter:chapter.id).cookiesInterface()}}
        .alert("إعادة تعيين التقدّم؟",isPresented:$reset){Button("إعادة تعيين",role:.destructive){if let chapter{do{try typer.reset(chapter.id);scrollRequest=UUID()}catch{typer.error=error.localizedDescription}}};Button("إلغاء",role:.cancel){}}message:{Text("تصبح الفقاعات متاحة مجددًا. تبقى طبقات النص الموجودة في الصور.")}
        .typerErrors(typer)
        .onAppear{preferences=typer.panelPreferences;model.typerOverrideTag=preferences.overrideTag;model.typerQuickFont=preferences.quickFont;loaded=true;scrollRequest=UUID()}
        .onChange(of:preferences){old,new in
            guard loaded else{return}
            model.typerOverrideTag=new.overrideTag;model.typerQuickFont=new.quickFont
            if old.query==new.query{persist()}
        }
        .task(id:preferences.query){guard loaded else{return};do{try await Task.sleep(nanoseconds:300_000_000);try Task.checkCancellation();persist()}catch{}}
        .onDisappear{if loaded{persist()}}
        .onChange(of:typer.state.active){_,_ in scrollRequest=UUID()}
        .onChange(of:typer.panelPreferences){_,value in if loaded,value != preferences{preferences=value;scrollRequest=UUID()}}
        .onChange(of:typer.state.activeTagSet){_,_ in if let id=preferences.overrideTag,!typer.state.tags.contains(where:{$0.id==id}){preferences.overrideTag=nil}}
    }
    private var header:some View{HStack(spacing:10){SurfaceSymbol(icon:"text.bubble",size:32);VStack(alignment:.leading,spacing:2){Text("التايبر").font(.system(size:14,weight:.semibold));if !compact{Text("نصوص الفصل · تقدّم محفوظ").font(.system(size:9)).foregroundStyle(Palette.quiet)}};Spacer(minLength:4);Menu{Button{library=true}label:{Label("إدارة الفصول",systemImage:"doc.text")};Button{settings=true}label:{Label("الوسوم والألوان",systemImage:"tag")};Button{preferences.expanded.toggle()}label:{Label(preferences.expanded ? "إخفاء خيارات الإدراج":"خيارات الإدراج",systemImage:"slider.horizontal.3")};Button{editing=DialogueBubble(text:"",tagID:typer.state.tags.first?.id)}label:{Label("فقاعة جديدة",systemImage:"plus.bubble")};Button{reset=true}label:{Label("إعادة تعيين التقدّم",systemImage:"arrow.counterclockwise")}}label:{Image(systemName:"slider.horizontal.3").frame(width:34,height:40)}.accessibilityLabel("خيارات التايبر");IconButton(icon:"xmark",title:"إغلاق لوحة التايبر"){persist();close()}.accessibilityIdentifier("typer-panel-close")}.padding(.leading,14).padding(.trailing,4).frame(height:54)}
    private func chapterHeader(_ chapter:DialogueChapter)->some View{VStack(spacing:9){HStack(spacing:6){Menu{ForEach(typer.state.chapters){item in Button(item.title){do{try typer.activate(item.id)}catch{typer.error=error.localizedDescription}}};Divider();Button("إدارة الفصول"){library=true}}label:{HStack(spacing:7){Text(chapter.title).lineLimit(1);Image(systemName:"chevron.down").font(.system(size:9))}.font(.system(size:12,weight:.semibold))}.accessibilityIdentifier("typer-chapters");Spacer(minLength:4);Text("\(chapter.usedCount) / \(chapter.pasteable.count)").font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.secondary).accessibilityIdentifier("typer-progress")};if !compact{ProgressView(value:Double(chapter.usedCount),total:Double(max(1,chapter.pasteable.count))).tint(Palette.gold).scaleEffect(x:1,y:0.7);HStack{Text("\(chapter.pasteable.count-chapter.usedCount) فقاعة متبقية").font(.system(size:10)).foregroundStyle(Palette.quiet);Spacer();Button{scrollRequest=UUID()}label:{Label("موضعي",systemImage:"location")}.font(.system(size:10,weight:.medium)).accessibilityIdentifier("typer-resume")}}}.padding(.horizontal,16).padding(.bottom,12)}
    private var filters:some View{VStack(spacing:8){HStack(spacing:4){ForEach(TyperBubbleFilter.allCases){filter in Button{preferences.filter=filter}label:{Text(filter.title).font(.system(size:11,weight:preferences.filter==filter ? .semibold:.regular)).frame(maxWidth:.infinity,minHeight:32).background(preferences.filter==filter ? .white.opacity(0.1):.clear,in:RoundedRectangle(cornerRadius:10)).overlay(alignment:.bottom){if preferences.filter==filter{Capsule().fill(Palette.gold).frame(width:18,height:2).padding(.bottom,3)}}}.buttonStyle(.plain).accessibilityIdentifier("typer-filter-"+filter.rawValue).accessibilityValue(preferences.filter==filter ? "مختار":"غير مختار")}}.padding(3).background(.black.opacity(0.2),in:RoundedRectangle(cornerRadius:13));if !compact{HStack(spacing:8){Image(systemName:"magnifyingglass").foregroundStyle(Palette.quiet);TextField("بحث في الفقاعات",text:$preferences.query).font(.system(size:11)).autocorrectionDisabled().accessibilityIdentifier("typer-search");if !preferences.query.isEmpty{Button{preferences.query=""}label:{Image(systemName:"xmark.circle.fill")}.accessibilityLabel("مسح البحث")}}.padding(9).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:10))}}.padding(.horizontal,12).padding(.bottom,6)}
    private var insertionOptions:some View{VStack(alignment:.leading,spacing:10){
        HStack(spacing:8){Image(systemName:"tag").foregroundStyle(Palette.gold);Text("الخط واللون والتأثيرات من وسم كل فقاعة").font(.system(size:10)).foregroundStyle(Palette.secondary)}
        HStack{Picker("تنسيق الإدراج",selection:$preferences.textFormat){Text("كما هو").tag("");Text("مربع").tag("box");Text("دائرة").tag("circle")}.pickerStyle(.menu);Spacer();Button{preferences.uppercase.toggle()}label:{Image(systemName:"textformat.abc")}.buttonStyle(CapsuleActionStyle(selected:preferences.uppercase)).accessibilityLabel("تحويل إلى أحرف كبيرة")}.font(.system(size:11))
        Button{settings=true}label:{Label("تحرير أنماط الوسوم",systemImage:"slider.horizontal.3")}.buttonStyle(CapsuleActionStyle())
    }.padding(.horizontal,12).padding(.bottom,8)}
    private func bubbleList(_ chapter:DialogueChapter)->some View{ScrollViewReader{proxy in ScrollView{LazyVStack(spacing:8){let visible=chapter.bubbles.enumerated().filter{preferences.matches($0.element)};if visible.isEmpty{VStack(spacing:10){Image(systemName:"text.magnifyingglass");Text("لا توجد فقاعات بهذا العرض");if !preferences.query.isEmpty{Button("مسح البحث"){preferences.query=""}}}.font(.system(size:12)).foregroundStyle(Palette.quiet).frame(maxWidth:.infinity).padding(.vertical,24)};ForEach(Array(visible),id:\.element.id){index,bubble in bubbleRow(bubble,index:index,chapter:chapter).id(bubble.id)}}.padding(12)}.accessibilityIdentifier("typer-bubbles").task(id:scrollKey){do{try await Task.sleep(nanoseconds:120_000_000);try Task.checkCancellation();if let destination=DialogueSequence.scrollDestination(chapter,preferences:preferences){proxy.scrollTo(destination,anchor:.center)}}catch{}}}.layoutPriority(1)}
    private func bubbleRow(_ bubble:DialogueBubble,index:Int,chapter:DialogueChapter)->some View{
        let tag=typer.tag(bubble.tagID),accent=Color(uiColor:UIColor(hex:tag?.resolvedDisplayColor ?? "D4AF37")),current=DialogueSequence.resume(chapter,cursor:cursor)?.id==bubble.id
        return Button{insert([bubble],chapter:chapter.id)}label:{HStack(alignment:.top,spacing:10){RoundedRectangle(cornerRadius:2).fill(bubble.used ? .white.opacity(0.16):accent).frame(width:3);VStack(alignment:.leading,spacing:8){HStack(spacing:6){Circle().fill(bubble.used ? Palette.quiet:accent).frame(width:5,height:5);Text(tag?.title ?? "حوار").font(.system(size:10,weight:.medium)).foregroundStyle(bubble.used ? Palette.quiet:accent);Spacer(minLength:2);if current{Text("التالية").font(.system(size:9,weight:.medium)).foregroundStyle(Palette.gold)};Text(String(index+1)).font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.quiet);if bubble.used{Image(systemName:"checkmark.circle.fill").font(.system(size:11)).foregroundStyle(Palette.quiet)}};Text(bubble.text).font(.system(size:13,weight:.medium)).lineLimit(compact ? 2:5).multilineTextAlignment(.leading).foregroundStyle(bubble.used ? Color(white:0.51):Palette.pale)}}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(bubble.used ? Color(white:0.11).opacity(0.9):.white.opacity(current ? 0.055:0.025),in:RoundedRectangle(cornerRadius:15)).overlay(RoundedRectangle(cornerRadius:15).stroke(current ? Palette.gold.opacity(0.4):.white.opacity(0.055),lineWidth:0.75))}.buttonStyle(.plain).disabled(bubble.noPaste || model.busy).accessibilityIdentifier("typer-bubble-\(index)").accessibilityValue(bubble.noPaste ? "عنوان":bubble.used ? "مستخدمة":"متاحة").contextMenu{Button("ابدأ التوزيع من هذه الفقاعة"){preferences.cursors[chapter.id.uuidString]=bubble.id;scrollRequest=UUID()};Button("تعديل الفقاعة"){editing=bubble};Button("تقديم الفقاعة"){move(bubble.id,by:-1,in:chapter)}.disabled(index==0);Button("تأخير الفقاعة"){move(bubble.id,by:1,in:chapter)}.disabled(index==chapter.bubbles.count-1);Button("نسخ النص"){UIPasteboard.general.string=bubble.text};Button(bubble.used ? "إعادتها إلى المتبقية":"تحديد كمستخدمة"){do{try typer.mark(bubble.id,in:chapter.id,used:!bubble.used);scrollRequest=UUID()}catch{typer.error=error.localizedDescription}}}
    }
    private func footer(_ chapter:DialogueChapter)->some View{VStack(spacing:8){if let cursor,let bubble=chapter.bubbles.first(where:{$0.id==cursor}){HStack{Image(systemName:"flag");Text("بدء التوزيع: "+bubble.text).lineLimit(1);Spacer();Button{preferences.cursors.removeValue(forKey:chapter.id.uuidString);scrollRequest=UUID()}label:{Image(systemName:"xmark.circle")}}.font(.system(size:10)).foregroundStyle(Palette.quiet)};HStack(spacing:8){Button{model.bubbleShape=nil;model.sniperMode.toggle();model.tool = .move;model.panel=nil;persist();close()}label:{Image(systemName:"scope").font(.system(size:18)).frame(width:44,height:46).glass(14)}.accessibilityLabel("القنص").accessibilityIdentifier("typer-sniper");Button{let count=max(1,model.sniperTargets.count),start=cursor ?? DialogueSequence.resume(chapter)?.id;insert(DialogueSequence.next(chapter,from:start,count:count),chapter:chapter.id)}label:{Label(model.sniperTargets.isEmpty ? "الفقاعة التالية":"إدراج \(model.sniperTargets.count) أهداف",systemImage:"text.badge.plus").font(.system(size:12,weight:.semibold))}.buttonStyle(GoldButtonStyle(primary:true)).disabled(chapter.pasteable.allSatisfy(\.used) || model.busy).accessibilityIdentifier("typer-next")}}.padding(.horizontal,12).padding(.top,10).padding(.bottom,12).background(.black.opacity(0.14))}
    private func persist(){do{try typer.savePanelPreferences(preferences)}catch{typer.error=error.localizedDescription}}
    private func insert(_ bubbles:[DialogueBubble],chapter:UUID){
        guard !model.busy else{return}
        let remaining=Array(bubbles.filter{!$0.noPaste}.prefix(model.sniperTargets.isEmpty ? bubbles.count:model.sniperTargets.count))
        guard !remaining.isEmpty else{return}
        var values=remaining;if preferences.uppercase{for i in values.indices{values[i].text=values[i].text.uppercased()}}
        let targets=model.sniperTargets,before=model.page,format=preferences.textFormat
        var inputs:[EditorLayer]=[]
        do{inputs=try values.map{try typer.dialogueLayer($0)}}catch{typer.error=error.localizedDescription;return}
        model.busy=true
        Task{defer{model.busy=false};do{let prepared=try await BackgroundWork.run{try inputs.enumerated().map{index,layer in targets.indices.contains(index) ? try SniperDetector.fitted(layer,to:targets[index]):layer}};guard model.page==before,model.sniperTargets==targets,typer.activeChapter?.id==chapter else{throw ImageFailure.message("تغيرت الصفحة أو أهداف القنص؛ أعد المحاولة")};try typer.place(values,chapter:chapter,model:model,targets:targets,format:targets.isEmpty ? format:"",styleAssets:styles.directory,preparedLayouts:targets.isEmpty ? []:prepared);model.sniperTargets=[];model.sniperMode=false;if let active=typer.chapter(chapter){preferences.cursors[chapter.uuidString]=DialogueSequence.resume(active)?.id};persist();scrollRequest=UUID()}catch{typer.error=error.localizedDescription}}
    }
    private func move(_ id:UUID,by delta:Int,in chapter:DialogueChapter){var ids=chapter.bubbles.map(\.id);guard let index=ids.firstIndex(of:id),ids.indices.contains(index+delta) else{return};ids.swapAt(index,index+delta);do{try typer.reorderBubbles(ids,in:chapter.id)}catch{typer.error=error.localizedDescription}}
}
