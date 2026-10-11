import SwiftUI

struct TyperSettingsView:View {
    @EnvironmentObject private var typer:TyperStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("typer-default-separation") private var separation="lines"
    @AppStorage("default-text-size") private var size=48.0
    @AppStorage("typer-panel-width") private var panelWidth=320.0
    @AppStorage("typer-panel-height") private var panelHeight=490.0
    @State private var editing:DialogueTag?
    @State private var groupPrompt=false
    @State private var groupName=""
    @State private var groupID:UUID?
    @State private var quickFonts=false
    @State private var link="//"
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:20){
        SurfaceHeader(title:"هوية كل حوار",subtitle:"وسوم مميزة، وأنماط وخيارات إدراج تخصك",icon:"tag")
        GlassSection("وسوم الفصل وألوانها",icon:"tag",subtitle:"لون البطاقة مستقل عن لون النص المدرج"){
            ForEach(typer.state.tags){tag in Button{editing=tag}label:{HStack(spacing:12){Circle().fill(Color(uiColor:UIColor(hex:tag.resolvedDisplayColor))).frame(width:10,height:10).overlay(Circle().stroke(.white.opacity(0.16),lineWidth:1));VStack(alignment:.leading,spacing:5){Text(tag.title).font(.system(size:14,weight:.medium));Text(tag.prefix.isEmpty ? "الحوار الافتراضي":tag.prefix).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet)};Spacer();if tag.noPaste{QuietBadge(text:"عنوان")};Image(systemName:"slider.horizontal.3").font(.system(size:13)).foregroundStyle(Palette.quiet)}.frame(minHeight:44).contentShape(Rectangle())}.buttonStyle(.plain).accessibilityIdentifier("typer-tag-"+tag.id.uuidString)}
            Button{editing=DialogueTag(title:"وسم جديد",prefix:"")}label:{Label("إضافة وسم",systemImage:"plus")}.buttonStyle(CapsuleActionStyle())
        }
        GlassSection("مجموعات الوسوم",icon:"square.stack",subtitle:"مجموعة لكل طريقة عمل أو فصل"){
            Picker("المجموعة النشطة",selection:Binding(get:{typer.state.activeTagSet ?? typer.tagSets.first?.id ?? UUID()},set:{id in perform{try typer.activateTagSet(id)}})){ForEach(typer.tagSets){group in Text(group.title).tag(group.id)}}.pickerStyle(.menu)
            ForEach(typer.tagSets){group in HStack{Text(group.title).font(.system(size:13));Spacer();IconButton(icon:"pencil",title:"اسم المجموعة"){groupID=group.id;groupName=group.title;groupPrompt=true};IconButton(icon:"trash",title:"حذف المجموعة"){perform{try typer.removeTagSet(group.id)}}.disabled(typer.tagSets.count==1)}}
            Button{groupID=nil;groupName="";groupPrompt=true}label:{Label("نسخ إلى مجموعة جديدة",systemImage:"doc.on.doc")}.buttonStyle(CapsuleActionStyle())
        }
        GlassSection("إعدادات الإدراج",icon:"text.badge.plus"){
            Picker("فصل الفقاعات",selection:$separation){Text("كل سطر فقاعة").tag("lines");Text("كل فقرة فقاعة").tag("paragraphs")}.pickerStyle(.menu)
            HStack{Text("حجم النص اليدوي الافتراضي");Spacer();Text("\(Int(size)) px").font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.secondary)};StepSlider(value:$size,in:8...160,step:1)
            NavigationRow(title:"الخطوط السريعة",subtitle:"تظهر داخل خيارات لوحة التايبر",icon:"textformat.alt"){quickFonts=true}
            HStack{TextField("بادئة استمرار الوسم",text:$link).autocorrectionDisabled().glassField();Button{perform{try typer.setLinkPrefix(link)}}label:{Image(systemName:"checkmark").frame(width:42,height:44).glass(14)}.accessibilityLabel("حفظ البادئة")}
            Text("// يحتفظ بوسم الحوار السابق. ## عنوان لا يُدرج. تُحفظ ألوان الوسوم ونصوصها مع نسختك الاحتياطية.").font(.system(size:11)).foregroundStyle(Palette.quiet).lineSpacing(4)
        }
        GlassSection("اللوحة العائمة",icon:"rectangle.on.rectangle",subtitle:"يُقيّد المقاس تلقائيًا بمساحة الشاشة"){
            value("العرض",Int(panelWidth));StepSlider(value:$panelWidth,in:240...600,step:10)
            value("الارتفاع",Int(panelHeight));StepSlider(value:$panelHeight,in:280...760,step:10)
            Text("يُحفظ الفلتر والبحث وخيارات الإدراج عند إغلاق اللوحة. عند فتحها تنتقل إلى الفقاعة التالية بعد آخر استخدام.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)
            Button{perform{try typer.savePanelPreferences(TyperPanelPreferences())}}label:{Label("إعادة خيارات اللوحة فقط",systemImage:"arrow.counterclockwise")}.buttonStyle(CapsuleActionStyle())
        }
    }.padding(20).frame(maxWidth:740).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("إعدادات التايبر").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.accessibilityIdentifier("typer-settings-close")}}.sheet(item:$editing){tag in DialogueTagView(tag:tag)}.sheet(isPresented:$quickFonts){QuickFontsView()}.onAppear{link=typer.state.linkPrefix}.alert(groupID==nil ? "مجموعة جديدة":"اسم المجموعة",isPresented:$groupPrompt){TextField("الاسم",text:$groupName);Button("حفظ"){perform{if let groupID{try typer.renameTagSet(groupID,title:groupName)}else{try typer.createTagSet(title:groupName,copyActive:true)}}};Button("إلغاء",role:.cancel){}}}.cookiesInterface().typerErrors(typer)}
    private func value(_ title:String,_ number:Int)->some View{HStack{Text(title);Spacer();Text(String(number)).font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.secondary)}}
    private func perform(_ action:()throws->Void){do{try action()}catch{typer.error=error.localizedDescription}}
}
struct DialogueTagView:View {
    @EnvironmentObject private var typer:TyperStore
    @EnvironmentObject private var styles:StyleStore
    @Environment(\.dismiss) private var dismiss
    @State var tag:DialogueTag
    @State private var error:String?
    @State private var visualEditor=false
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:18){
        SurfaceHeader(title:tag.title,subtitle:"هوية البطاقة ونمط الحوار عند الإدراج",icon:"tag")
        GlassSection("الاسم والبادئة",icon:"tag"){
            TextField("اسم الوسم",text:$tag.title).glassField();TextField("بادئة الوسم",text:$tag.prefix).autocorrectionDisabled().glassField();SettingToggle(title:"عنوان أو ملاحظة لا تُدرج",value:$tag.noPaste)
            CookiesColorWell("لون الوسم في التايبر",selection:Binding(get:{Color(uiColor:UIColor(hex:tag.resolvedDisplayColor))},set:{tag.displayColor=UIColor($0).hex}),supportsOpacity:false).accessibilityIdentifier("tag-display-color")
            HStack(spacing:10){Circle().fill(Color(uiColor:UIColor(hex:tag.resolvedDisplayColor))).frame(width:8,height:8);Text(tag.title).font(.system(size:12,weight:.medium));Spacer();Text("معاينة البطاقة").font(.system(size:10)).foregroundStyle(Palette.quiet)}.padding(14).glass(14)
        }
        GlassSection("نمط النص",icon:"textformat",subtitle:"هذا النمط يطبّق على الحروف داخل الصورة"){
            NavigationRow(title:"تصميم النمط داخل المحرر",subtitle:"كل أدوات النص، ومعاينة مباشرة، وحفظ للوسم",icon:"rectangle.and.pencil.and.ellipsis"){visualEditor=true}.accessibilityIdentifier("tag-open-editor")
            Picker("الخط",selection:$tag.style.fontPath){ForEach((Fonts.files+Fonts.otf).sorted{$0.lastPathComponent<$1.lastPathComponent},id:\.self){url in Text(url.deletingPathExtension().lastPathComponent).tag(url.lastPathComponent)}}.pickerStyle(.menu)
            value("الحجم",tag.style.fontSize);StepSlider(value:$tag.style.fontSize,in:8...160,step:1)
            CookiesColorWell("لون النص",selection:Binding(get:{Color(uiColor:UIColor(hex:tag.style.color))},set:{tag.style.color=UIColor($0).hex}),supportsOpacity:false)
            SettingToggle(title:"غامق",value:$tag.style.isBold);SettingToggle(title:"مائل",value:$tag.style.isItalic)
            value("سمك الحد",tag.style.strokeWidth);StepSlider(value:$tag.style.strokeWidth,in:0...12,step:1)
            CookiesColorWell("لون الحد",selection:Binding(get:{Color(uiColor:UIColor(hex:tag.style.strokeColor))},set:{tag.style.strokeColor=UIColor($0).hex}),supportsOpacity:false)
        }
        if !styles.styles.isEmpty{GlassSection("نمط محفوظ",icon:"square.grid.2x2"){ForEach(styles.styles){item in Button{tag.style=item.style}label:{HStack{Text(item.title);Spacer();Image(systemName:"arrow.down.to.line").font(.system(size:12))}.padding(.vertical,6)}.buttonStyle(.plain)}}}
        GlassSection("معاينة الحروف",icon:"eye"){LayerThumbnail(layer:preview,directory:styles.directory,previewSize:240).frame(height:160).clipShape(RoundedRectangle(cornerRadius:16))}
        if typer.state.tags.contains(where:{$0.id==tag.id}){Button("حذف الوسم",role:.destructive){do{try typer.removeTag(tag.id);dismiss()}catch{self.error=error.localizedDescription}}.font(.system(size:13)).padding(.vertical,10)}
    }.padding(20).frame(maxWidth:700).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("تحرير الوسم").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("إلغاء"){dismiss()}};ToolbarItem(placement:.topBarTrailing){Button("حفظ"){do{try typer.saveTag(tag);dismiss()}catch{self.error=error.localizedDescription}}.disabled(tag.title.trimmingCharacters(in:.whitespaces).isEmpty).accessibilityIdentifier("tag-save")}}.fullScreenCover(isPresented:$visualEditor){TagStyleEditorView(tag:tag){layer,assets in var value=tag;value.style=try styles.ownedReusableStyle(layer.style,from:assets);value.textTransform=TextLayerTransform(layer);try typer.saveTag(value);tag=value}}.alert("تعذر حفظ الوسم",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}}.cookiesInterface()}
    private var preview:EditorLayer{var layer=EditorLayer(kind:.text);layer.textContent="حوار يصنع الحكاية";layer.style=tag.style;tag.textTransform?.apply(to:&layer);return layer}
    private func value(_ name:String,_ amount:Double)->some View{HStack{Text(name);Spacer();Text("\(Int(amount)) px").font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.secondary)}}
}
struct QuickFontsView:View {
    @EnvironmentObject private var typer:TyperStore
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    var body:some View{NavigationStack{ZStack{Ambient();VStack(spacing:14){SearchBar(placeholder:"ابحث عن اسم الخط",text:$query).padding(.horizontal,20);List{ForEach((Fonts.files+Fonts.otf).filter{query.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(query)},id:\.self){font in Toggle(font.deletingPathExtension().lastPathComponent,isOn:Binding(get:{typer.state.quickFonts?.contains(font.lastPathComponent)==true},set:{enabled in var fonts=Set(typer.state.quickFonts ?? []);if enabled{fonts.insert(font.lastPathComponent)}else{fonts.remove(font.lastPathComponent)};do{try typer.setQuickFonts(Array(fonts))}catch{typer.error=error.localizedDescription}})).font(.system(size:13)).tint(Palette.gold).padding(.vertical,7).listRowBackground(Color.clear)}}.listStyle(.plain).scrollContentBackground(.hidden)}}.foregroundStyle(Palette.pale).navigationTitle("الخطوط السريعة").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}}}}.cookiesInterface().typerErrors(typer)}
}
