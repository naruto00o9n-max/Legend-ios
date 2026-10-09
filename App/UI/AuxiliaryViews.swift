import SwiftUI

struct LayerSheet:View {
    @ObservedObject var model:EditorModel;@Environment(\.dismiss) var dismiss
    var body:some View{VStack(spacing:14){HStack{Text("الطبقات").font(.system(size:18,weight:.semibold));Spacer();IconButton(icon:"plus",title:"طبقة رسم"){model.add(.drawing)};IconButton(icon:"checkmark",title:"تم"){dismiss()}}
        List{ForEach(model.page.layers.reversed()){l in HStack(spacing:12){IconButton(icon:l.isVisible ? "eye":"eye.slash",title:"إظهار الطبقة"){model.selected=l.id;model.checkpoint();model.change{$0.isVisible.toggle()}};VStack(alignment:.leading){Text(l.kind == .text ? l.textContent:l.name).font(.system(size:13)).lineLimit(1);Text("\(Int(l.opacity*100))% · \(l.blend.rawValue)").font(.system(size:10)).foregroundStyle(Palette.quiet)};Spacer();IconButton(icon:l.isLocked ? "lock":"lock.open",title:"قفل الطبقة"){if let i=model.page.layers.firstIndex(where:{$0.id==l.id}){model.checkpoint();model.page.layers[i].isLocked.toggle();model.save()}}}.contentShape(Rectangle()).onTapGesture{model.selected=l.id}.listRowBackground(model.selected==l.id ? Palette.gold.opacity(0.12):Color.clear).contextMenu{Button("نسخ"){model.selected=l.id;model.duplicate()};Button("حذف",role:.destructive){model.selected=l.id;model.delete()}}}.onMove{source,destination in model.checkpoint();var reversed=Array(model.page.layers.reversed());reversed.move(fromOffsets:source,toOffset:destination);model.page.layers=Array(reversed.reversed());model.save()}}.environment(\.editMode,.constant(.active)).scrollContentBackground(.hidden).listStyle(.plain)
    }.padding(16).foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.8)).glass(28)}
}
struct ShapeSheet:View {
    @ObservedObject var model:EditorModel;@Environment(\.dismiss) var dismiss
    var body:some View{VStack(alignment:.leading,spacing:20){Text("الأشكال وفقاعات الحوار").font(.system(size:18,weight:.semibold));ScrollView{LazyVGrid(columns:[GridItem(.adaptive(minimum:64))],spacing:12){ForEach(0..<20,id:\.self){i in Button{model.add(.shape,shape:i);dismiss()}label:{ShapePreview(index:i).frame(height:56).padding(10).glass(16)}.accessibilityLabel("شكل \(i+1)")}}}}.padding(22).foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.8)).glass(28)}
}
struct ShapePreview:Shape {var index:Int;func path(in rect:CGRect)->Path{Path(LayerRenderer.shapePath(index,rect:rect).cgPath)}}
struct ExportSheet:View {
    @ObservedObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @State private var format="PNG"
    @State private var quality=0.95
    var body:some View {
        VStack(alignment:.leading,spacing:16){
            HStack{Text("تصدير العمل").font(.system(size:20,weight:.semibold));Spacer();Image(systemName:"square.and.arrow.up")}
            Picker("الصيغة",selection:$format){ForEach(["PNG","JPEG","PSD","مشروع"],id:\.self){Text($0).tag($0)}}.pickerStyle(.segmented)
            Text("\(model.page.width) × \(model.page.height)").font(.system(size:13,design:.monospaced)).foregroundStyle(Palette.quiet)
            if format=="JPEG"{Slider(value:$quality,in:0.5...1);Text("جودة JPEG: \(Int(quality*100))% · ضغط مع فقدان").font(.system(size:11)).foregroundStyle(Palette.quiet)}
            else{Text(format=="مشروع" ? "يحفظ الصورة الأصلية والنصوص والطبقات القابلة للتعديل.":format=="PSD" ? "طبقات منفصلة في PSD؛ النصوص طبقات مرسومة. احتفظ بملف المشروع لتعديلها.":"PNG بلا فقدان وبالأبعاد الأصلية.").font(.system(size:12)).lineSpacing(4)}
            if model.busy{ProgressView("جارٍ التصدير…").tint(Palette.gold)}
            else if let url=model.exported{ShareLink(item:url){Label("حفظ أو مشاركة العمل",systemImage:"square.and.arrow.up")}.buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("share-png")}
            else{Button("تصدير \(format)"){Task{await model.export(format:format,quality:quality)}}.buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("export-png")}
            Button("إغلاق"){dismiss()}.font(.system(size:12)).foregroundStyle(Palette.quiet)
        }.padding(24).foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.85)).glass(28)
        .onAppear{model.exported=nil}.onChange(of:format){_,_ in model.exported=nil}
    }
}
struct AssistantView:View {
    var insert:((String)->Void)?
    @Environment(\.dismiss) var dismiss
    @State private var source="";@State private var lines:[String]=[];@State private var index=0
    var body:some View{ZStack{Ambient();VStack(alignment:.leading,spacing:16){HStack{Text("مساعد الحوارات").font(.system(size:21,weight:.semibold));Spacer();IconButton(icon:"xmark",title:"إغلاق"){dismiss()}}
        Text("كل فقرة فقاعة · نافذة داخل التطبيق").font(.system(size:12)).foregroundStyle(Palette.quiet)
        TextEditor(text:$source).scrollContentBackground(.hidden).font(.system(size:15)).padding(12).glass(18).frame(minHeight:140,maxHeight:240).accessibilityIdentifier("assistant-text")
        Button("تجهيز الحوارات"){lines=source.components(separatedBy:"\n\n").map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty};index=0}.buttonStyle(GoldButtonStyle(primary:true))
        if !lines.isEmpty{VStack(spacing:14){Text("\(index+1) / \(lines.count)").font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet);Text(lines[index]).font(.system(size:16)).multilineTextAlignment(.center).frame(maxWidth:.infinity);HStack{IconButton(icon:"chevron.right",title:"السابق"){index=max(0,index-1)};Button("نسخ"){UIPasteboard.general.string=lines[index]}.font(.system(size:13));Spacer();if let insert{Button("إضافة إلى الصورة"){insert(lines[index]);dismiss()}.font(.system(size:13))};IconButton(icon:"chevron.left",title:"التالي"){index=min(lines.count-1,index+1)}}}.padding(18).glass(20)};Spacer(minLength:0)
    }.padding(22)}.foregroundStyle(Palette.pale)}
}
struct SettingsView:View {
    @EnvironmentObject var service:ReferenceService;@Environment(\.dismiss) var dismiss
    @State private var account=false;@State private var hub=false;@State private var fonts=false
    var body:some View{ZStack{Ambient();VStack(alignment:.leading,spacing:20){HStack{Brand();Spacer();IconButton(icon:"xmark",title:"إغلاق"){dismiss()}};Text("مساحتك").font(.system(size:25,weight:.semibold))
        VStack(alignment:.leading,spacing:12){Text(NetworkPolicy.enabled ? "نسخة الخدمات":"نسخة محلية").font(.system(size:16,weight:.medium));Text(service.session?.user.email ?? "المشاريع محفوظة على هذا الجهاز").font(.system(size:12)).foregroundStyle(Palette.quiet)}.frame(maxWidth:.infinity,alignment:.leading).padding(20).glass()
        if NetworkPolicy.enabled{Button(service.session==nil ? "تسجيل الدخول إلى الحساب الأصلي":"حسابي والخدمات"){if service.session==nil{account=true}else{hub=true}}.buttonStyle(GoldButtonStyle(primary:true));Button("المجتمع"){hub=true}.buttonStyle(GoldButtonStyle());if service.session != nil{Button("تسجيل الخروج"){Task{await service.logout()}}.font(.system(size:13))}}else{Text("هذه النسخة لا ترسل طلبات إلى الخوادم.").font(.system(size:13)).foregroundStyle(Palette.quiet)}
        Button("مكتبة الخطوط"){fonts=true}.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("font-library")
        Text("Cookies Editor · iPhone\nالأسود والذهبي، ومساحة لصورتك.").font(.system(size:12)).foregroundStyle(Palette.quiet).lineSpacing(6);Spacer()
    }.padding(24)}.foregroundStyle(Palette.pale).sheet(isPresented:$account){AccountView()}.sheet(isPresented:$hub){ServiceHub()}.sheet(isPresented:$fonts){FontLibraryView()}}
}
struct ServiceHub:View {
    @EnvironmentObject var service:ReferenceService
    @Environment(\.dismiss) var dismiss
    @State private var section="community"
    var body:some View {
        ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:18){
            HStack{Text("مجتمع المترجمين").font(.system(size:23,weight:.semibold));Spacer();IconButton(icon:"xmark",title:"إغلاق"){dismiss()}}
            Picker("القسم",selection:$section){Text("المجتمع").tag("community");Text("حسابي").tag("profile")}.pickerStyle(.segmented)
            if service.busy{ProgressView().tint(Palette.gold)}
            if let message=service.message{Text(message).font(.system(size:13)).foregroundStyle(Palette.quiet)}
            ForEach(Array(service.rows.enumerated()),id:\.offset){_,row in
                VStack(alignment:.leading,spacing:12){
                    if let values=row["media_urls"] as? [String],let first=values.first,let url=URL(string:first){AsyncImage(url:url){phase in if let image=phase.image{image.resizable().scaledToFit().frame(maxHeight:230)}}}
                    Text((row["title"] ?? row["display_name"] ?? row["username"]) as? String ?? "حسابي").font(.system(size:17,weight:.semibold))
                    if let author=row["author_name"] as? String{Text(author).font(.system(size:11)).foregroundStyle(Palette.quiet)}
                    Text((row["description"] ?? row["bio"]) as? String ?? "").font(.system(size:13)).lineSpacing(5)
                    if let email=service.session?.user.email,section=="profile"{Text(email).font(.system(size:12)).foregroundStyle(Palette.quiet)}
                    if let points=row["points"] as? Int{Text("النقاط: \(points)").font(.system(size:12)).foregroundStyle(Palette.gold)}
                    if let tags=row["tags"] as? [String]{Text(tags.map{"#"+$0}.joined(separator:" ")).font(.system(size:11)).foregroundStyle(Palette.quiet)}
                }.frame(maxWidth:.infinity,alignment:.leading).padding(18).glass(20)
            }
        }.padding(22)}}.foregroundStyle(Palette.pale).task(id:section){await service.fetch(section)}
    }
}
struct BrushSheet:View {
    @ObservedObject var model:EditorModel
    var body:some View {VStack(alignment:.leading,spacing:22){Text("الفرشاة").font(.system(size:19,weight:.semibold));Picker("نوع الفرشاة",selection:$model.brushStyle){Text("صلبة").tag("normal");Text("مائية").tag("water");Text("مضيئة").tag("neon")}.pickerStyle(.segmented);ColorPicker("لون الرسم",selection:Binding(get:{Color(uiColor:UIColor(hex:model.brushColor))},set:{model.brushColor=UIColor($0).hex}),supportsOpacity:false);Text("الحجم: \(Int(model.brushWidth)) بكسل").font(.system(size:12));Slider(value:$model.brushWidth,in:1...160).tint(Palette.gold)}.padding(24).foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.85)).glass(28)}
}

struct ReaderView:View {
    @ObservedObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    var body:some View {CanvasHost(model:model,readOnly:true).ignoresSafeArea(edges:.bottom).background(Palette.ink).safeAreaInset(edge:.top,spacing:0){HStack{Text(model.page.title).font(.system(size:13)).lineLimit(1);Spacer();IconButton(icon:"xmark",title:"إغلاق القراءة"){dismiss()}}.padding(.horizontal,14).foregroundStyle(Palette.pale).glass(0)}}
}
