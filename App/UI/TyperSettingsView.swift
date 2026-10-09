import SwiftUI

struct TyperSettingsView:View {
    @EnvironmentObject var typer:TyperStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("typer-default-separation") private var separation="lines"
    @AppStorage("default-text-size") private var size=48.0
    @State private var editing:DialogueTag?
    var body:some View {NavigationStack{ZStack{Ambient();List{
        Section("إضافة النص"){Picker("فصل الفقاعات",selection:$separation){Text("كل سطر فقاعة").tag("lines");Text("كل فقرة فقاعة").tag("paragraphs")};HStack{Text("حجم النص الافتراضي");Spacer();Text("\(Int(size)) px").font(.system(size:12,design:.monospaced))};Slider(value:$size,in:8...160,step:1).tint(Palette.gold)}
        Section{ForEach(typer.state.tags){tag in Button{editing=tag}label:{HStack{VStack(alignment:.leading,spacing:5){Text(tag.title);Text(tag.prefix.isEmpty ? "الوسم الافتراضي":tag.prefix).font(.system(size:12,design:.monospaced)).foregroundStyle(Palette.quiet)};Spacer();Text(tag.noPaste ? "لا يُدرج":"نص").font(.system(size:11)).foregroundStyle(Palette.quiet);Image(systemName:"chevron.left")}}};Button{editing=DialogueTag(title:"وسم جديد",prefix:"")}label:{Label("إضافة وسم",systemImage:"plus")}}header:{Text("وسوم الفصل وخطوطها")}footer:{Text("تبدأ الفقاعة بالوسم، ثم يُحذف الوسم عند إدراج النص. // يحتفظ بنمط الحوار السابق. الرمادي يعني فقاعة مستخدمة، ويظل محفوظًا عند إغلاق التطبيق.")}
    }.scrollContentBackground(.hidden).listRowSeparatorTint(.white.opacity(0.08))}.navigationTitle("إعدادات التايبر").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.accessibilityIdentifier("typer-settings-close")}}.sheet(item:$editing){tag in DialogueTagView(tag:tag)}}.cookiesInterface()}
}
struct DialogueTagView:View {
    @EnvironmentObject var typer:TyperStore
    @Environment(\.dismiss) private var dismiss
    @State var tag:DialogueTag
    @State private var error:String?
    var body:some View {NavigationStack{Form{
        Section("الوسم"){TextField("الاسم",text:$tag.title);TextField("بادئة الوسم",text:$tag.prefix).autocorrectionDisabled();Toggle("عنوان أو ملاحظة لا تُدرج",isOn:$tag.noPaste)}
        Section("نمط النص"){Picker("الخط",selection:$tag.style.fontPath){ForEach((Fonts.files+Fonts.otf).sorted{$0.lastPathComponent<$1.lastPathComponent},id:\.self){url in Text(url.deletingPathExtension().lastPathComponent).tag(url.lastPathComponent)}};HStack{Text("الحجم");Spacer();Text("\(Int(tag.style.fontSize)) px")};Slider(value:$tag.style.fontSize,in:8...160,step:1);ColorPicker("لون النص",selection:Binding(get:{Color(uiColor:UIColor(hex:tag.style.color))},set:{tag.style.color=UIColor($0).hex}),supportsOpacity:false);Toggle("غامق",isOn:$tag.style.isBold);Toggle("مائل",isOn:$tag.style.isItalic);HStack{Text("سمك الحد");Spacer();Text("\(Int(tag.style.strokeWidth)) px")};Slider(value:$tag.style.strokeWidth,in:0...12,step:1);ColorPicker("لون الحد",selection:Binding(get:{Color(uiColor:UIColor(hex:tag.style.strokeColor))},set:{tag.style.strokeColor=UIColor($0).hex}),supportsOpacity:false)}
        Section{Text("معاينة الحوار العربي").font(Font(Fonts.font(tag.style))).foregroundStyle(Color(uiColor:UIColor(hex:tag.style.color))).frame(maxWidth:.infinity,minHeight:90).background(.black)}
    }.navigationTitle(tag.title).navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("إلغاء"){dismiss()}};ToolbarItem(placement:.topBarTrailing){Button("حفظ"){do{try typer.saveTag(tag);dismiss()}catch{self.error=error.localizedDescription}}.disabled(tag.title.trimmingCharacters(in:.whitespaces).isEmpty)}}.alert("تعذر حفظ الوسم",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}}.cookiesInterface()}
}
