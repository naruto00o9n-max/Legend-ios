import SwiftUI

struct TyperSettingsView:View {
    @EnvironmentObject var typer:TyperStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("typer-default-separation") private var separation="lines"
    @AppStorage("default-text-size") private var size=48.0
    @State private var editing:DialogueTag?
    @State private var groupPrompt=false
    @State private var groupName=""
    @State private var groupID:UUID?
    @State private var quickFonts=false
    @State private var link="//"
    @AppStorage("typer-panel-width") private var panelWidth=320.0
    @AppStorage("typer-panel-height") private var panelHeight=490.0
    var body:some View {NavigationStack{ZStack{Ambient();List{
        Section("مجموعات الوسوم"){
            Picker("المجموعة النشطة",selection:Binding(get:{typer.state.activeTagSet ?? typer.tagSets.first?.id ?? UUID()},set:{id in do{try typer.activateTagSet(id)}catch{typer.error=error.localizedDescription}})){ForEach(typer.tagSets){group in Text(group.title).tag(group.id)}}
            ForEach(typer.tagSets){group in HStack{Text(group.title);Spacer();Button{groupID=group.id;groupName=group.title;groupPrompt=true}label:{Image(systemName:"pencil")};Button(role:.destructive){do{try typer.removeTagSet(group.id)}catch{typer.error=error.localizedDescription}}label:{Image(systemName:"trash")}.disabled(typer.tagSets.count==1)}}
            Button("نسخ المجموعة إلى مجموعة جديدة"){groupID=nil;groupName="";groupPrompt=true}
        }
        Section("إضافة النص"){Picker("فصل الفقاعات",selection:$separation){Text("كل سطر فقاعة").tag("lines");Text("كل فقرة فقاعة").tag("paragraphs")};HStack{Text("حجم النص الافتراضي");Spacer();Text("\(Int(size)) px").font(.system(size:12,design:.monospaced))};Slider(value:$size,in:8...160,step:1).tint(Palette.gold)}
        Section("اللوحة والخطوط السريعة"){Text("عرض اللوحة: \(Int(panelWidth))");Slider(value:$panelWidth,in:240...600,step:10);Text("ارتفاع اللوحة: \(Int(panelHeight))");Slider(value:$panelHeight,in:280...760,step:10);Button("اختيار الخطوط السريعة"){quickFonts=true};TextField("بادئة استمرار الوسم",text:$link);Button("حفظ البادئة"){do{try typer.setLinkPrefix(link)}catch{typer.error=error.localizedDescription}}}
        Section{ForEach(typer.state.tags){tag in Button{editing=tag}label:{HStack{VStack(alignment:.leading,spacing:5){Text(tag.title);Text(tag.prefix.isEmpty ? "الوسم الافتراضي":tag.prefix).font(.system(size:12,design:.monospaced)).foregroundStyle(Palette.quiet)};Spacer();Text(tag.noPaste ? "لا يُدرج":"نص").font(.system(size:11)).foregroundStyle(Palette.quiet);Image(systemName:"chevron.left")}}};Button{editing=DialogueTag(title:"وسم جديد",prefix:"")}label:{Label("إضافة وسم",systemImage:"plus")}}header:{Text("وسوم الفصل وخطوطها")}footer:{Text("تبدأ الفقاعة بالوسم، ثم يُحذف الوسم عند إدراج النص. // يحتفظ بنمط الحوار السابق. الرمادي يعني فقاعة مستخدمة، ويظل محفوظًا عند إغلاق التطبيق.")}
    }.scrollContentBackground(.hidden).listRowSeparatorTint(.white.opacity(0.08))}.navigationTitle("إعدادات التايبر").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.accessibilityIdentifier("typer-settings-close")}}.sheet(item:$editing){tag in DialogueTagView(tag:tag)}.sheet(isPresented:$quickFonts){QuickFontsView()}.onAppear{link=typer.state.linkPrefix}.alert(groupID==nil ? "مجموعة جديدة":"اسم المجموعة",isPresented:$groupPrompt){TextField("الاسم",text:$groupName);Button("حفظ"){do{if let groupID{try typer.renameTagSet(groupID,title:groupName)}else{try typer.createTagSet(title:groupName,copyActive:true)}}catch{typer.error=error.localizedDescription}};Button("إلغاء",role:.cancel){}}}.alert("تعذر تحديث إعدادات التايبر",isPresented:Binding(get:{typer.error != nil},set:{if !$0{typer.error=nil}})){Button("حسنًا"){typer.error=nil}}message:{Text(typer.error ?? "")}.cookiesInterface()}
}
struct DialogueTagView:View {
    @EnvironmentObject var typer:TyperStore
    @EnvironmentObject var styles:StyleStore
    @Environment(\.dismiss) private var dismiss
    @State var tag:DialogueTag
    @State private var error:String?
    var body:some View {NavigationStack{Form{
        Section("الوسم"){TextField("الاسم",text:$tag.title);TextField("بادئة الوسم",text:$tag.prefix).autocorrectionDisabled();Toggle("عنوان أو ملاحظة لا تُدرج",isOn:$tag.noPaste)}
        Section("نمط النص"){Picker("الخط",selection:$tag.style.fontPath){ForEach((Fonts.files+Fonts.otf).sorted{$0.lastPathComponent<$1.lastPathComponent},id:\.self){url in Text(url.deletingPathExtension().lastPathComponent).tag(url.lastPathComponent)}};HStack{Text("الحجم");Spacer();Text("\(Int(tag.style.fontSize)) px")};Slider(value:$tag.style.fontSize,in:8...160,step:1);ColorPicker("لون النص",selection:Binding(get:{Color(uiColor:UIColor(hex:tag.style.color))},set:{tag.style.color=UIColor($0).hex}),supportsOpacity:false);Toggle("غامق",isOn:$tag.style.isBold);Toggle("مائل",isOn:$tag.style.isItalic);HStack{Text("سمك الحد");Spacer();Text("\(Int(tag.style.strokeWidth)) px")};Slider(value:$tag.style.strokeWidth,in:0...12,step:1);ColorPicker("لون الحد",selection:Binding(get:{Color(uiColor:UIColor(hex:tag.style.strokeColor))},set:{tag.style.strokeColor=UIColor($0).hex}),supportsOpacity:false)}
        if !styles.styles.isEmpty{Section("نمط محفوظ"){ForEach(styles.styles){item in Button(item.title){tag.style=item.style}}}}
        Section{Text("معاينة الحوار العربي").font(Font(Fonts.font(tag.style))).foregroundStyle(Color(uiColor:UIColor(hex:tag.style.color))).frame(maxWidth:.infinity,minHeight:90).background(.black)}
    }.navigationTitle(tag.title).navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("إلغاء"){dismiss()}};ToolbarItem(placement:.topBarTrailing){Button("حفظ"){do{try typer.saveTag(tag);dismiss()}catch{self.error=error.localizedDescription}}.disabled(tag.title.trimmingCharacters(in:.whitespaces).isEmpty)}}.alert("تعذر حفظ الوسم",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}}.cookiesInterface()}
}
struct QuickFontsView:View {
    @EnvironmentObject var typer:TyperStore
    @Environment(\.dismiss) var dismiss
    var body:some View{NavigationStack{List{ForEach(Fonts.files+Fonts.otf,id:\.self){font in Toggle(font.deletingPathExtension().lastPathComponent,isOn:Binding(get:{typer.state.quickFonts?.contains(font.lastPathComponent)==true},set:{enabled in var fonts=Set(typer.state.quickFonts ?? []);if enabled{fonts.insert(font.lastPathComponent)}else{fonts.remove(font.lastPathComponent)};do{try typer.setQuickFonts(Array(fonts))}catch{typer.error=error.localizedDescription}}))}}.navigationTitle("الخطوط السريعة").toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}}}}.cookiesInterface()}
}
