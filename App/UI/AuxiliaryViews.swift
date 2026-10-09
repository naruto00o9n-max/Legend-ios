import SwiftUI

struct LayerSheet:View {
    @ObservedObject var model:EditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var filter="all"
    @State private var multiple=false
    @State private var selection=Set<UUID>()
    @State private var preview:EditorLayer?
    @State private var grouping=false
    @State private var groupName=""
    @State private var flattening=false
    private var layers:[EditorLayer]{model.page.layers.reversed().filter{filter=="all" || $0.kind.rawValue==filter}}
    var body:some View {VStack(spacing:0){header;filters;if multiple{operations};layerList;opacity}
        .foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.85)).glass(24)
        .sheet(item:$preview){layer in LayerThumbnail(layer:layer,directory:model.directory,previewSize:512).frame(maxWidth:.infinity,maxHeight:.infinity).padding(24).background(Palette.ink)}
        .alert("مجموعة طبقات",isPresented:$grouping){TextField("اسم المجموعة",text:$groupName);Button("حفظ"){model.groupLayers(selection,name:groupName.isEmpty ? "مجموعة":groupName)};Button("إلغاء",role:.cancel){}}
        .alert("تسطيح العمل؟",isPresented:$flattening){Button("تسطيح"){Task{await model.flattenLayers()}};Button("إلغاء",role:.cancel){}}message:{Text("تتحول الصورة والطبقات إلى طبقة صورة واحدة. التراجع يعيد الطبقات القابلة للتعديل.")}
    }
    private var header:some View{HStack{Text("الطبقات").font(.system(size:18,weight:.semibold));Text("\(model.page.layers.count+1)").font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.quiet);Spacer();IconButton(icon:"plus",title:"طبقة رسم"){model.add(.drawing)};IconButton(icon:"checkmark",title:"تم"){dismiss()}}.padding(.horizontal,16).frame(height:56)}
    private var filters:some View{HStack{Picker("نوع الطبقة",selection:$filter){Text("الكل").tag("all");Text("نص").tag("text");Text("صور").tag("image");Text("رسم").tag("drawing");Text("أشكال").tag("shape")}.pickerStyle(.menu);Spacer();Toggle("تحديد متعدد",isOn:$multiple).toggleStyle(.button)}.font(.system(size:12)).padding(.horizontal,16)}
    private var operations:some View{ScrollView(.horizontal,showsIndicators:false){HStack(spacing:14){Button("الكل"){selection=Set(layers.map(\.id))};Button("دمج"){Task{await model.mergeLayers(selection)}}.disabled(selection.count<2 || model.busy);Button("تجميع"){grouping=true}.disabled(selection.isEmpty);Button("فك التجميع"){model.ungroupLayers(selection)}.disabled(selection.isEmpty);Button("تسطيح"){flattening=true}}.font(.system(size:12)).padding(12)}}
    private var layerList:some View{List{ForEach(layers){item in layerRow(item)}.onMove{source,destination in guard filter=="all" else{return};model.checkpoint();var ordered=Array(model.page.layers.reversed());ordered.move(fromOffsets:source,toOffset:destination);model.page.layers=Array(ordered.reversed());model.save()};backgroundRow}.environment(\.editMode,.constant(.active)).scrollContentBackground(.hidden).listStyle(.plain)}
    private func layerRow(_ item:EditorLayer)->some View{HStack(spacing:8){
        if multiple{Image(systemName:selection.contains(item.id) ? "checkmark.circle.fill":"circle")}
        LayerThumbnail(layer:item,directory:model.directory).frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:8))
        VStack(alignment:.leading,spacing:6){Text(item.kind == .text ? item.textContent:item.name).font(.system(size:13,weight:.medium)).lineLimit(1);Text("\(Int(item.opacity*100))% · \(item.blend.title)").font(.system(size:11)).foregroundStyle(Palette.quiet);if let group=item.groupName{Text(group).font(.system(size:10)).foregroundStyle(Palette.quiet)}}
        Spacer(minLength:0)
        if !multiple{IconButton(icon:item.isVisible ? "eye":"eye.slash",title:"إظهار الطبقة"){model.selected=item.id;model.checkpoint();if let i=model.page.layers.firstIndex(where:{$0.id==item.id}){model.page.layers[i].isVisible.toggle();model.save()}};IconButton(icon:item.isLocked ? "lock":"lock.open",title:"قفل الطبقة"){if let i=model.page.layers.firstIndex(where:{$0.id==item.id}){model.checkpoint();model.page.layers[i].isLocked.toggle();model.save()}}}
    }.contentShape(Rectangle()).onTapGesture{select(item)}.listRowBackground(model.selected==item.id ? Palette.gold.opacity(0.1):.clear)
        .contextMenu{Button("معاينة مكبرة"){preview=item};Button("نسخ"){model.selected=item.id;model.duplicate()};Button("حذف",role:.destructive){model.selected=item.id;model.delete()}}
    }
    private func select(_ item:EditorLayer){if multiple{let ids:Set<UUID>=item.groupID.map{group in Set(model.page.layers.filter{$0.groupID==group}.map(\.id))} ?? Set([item.id]);if selection.contains(item.id){selection.subtract(ids)}else{selection.formUnion(ids)}}else{model.selected=item.id;model.panel=nil;model.tool=item.kind == .text ? .text:.move}}
    private var backgroundRow:some View{HStack(spacing:12){if let image=UIImage(contentsOfFile:model.directory.appendingPathComponent("thumbnail.png").path){Image(uiImage:image).resizable().scaledToFill().frame(width:48,height:48).clipped().clipShape(RoundedRectangle(cornerRadius:8))};VStack(alignment:.leading,spacing:6){Text("الصورة الأصلية").font(.system(size:13));Text("\(model.page.width) × \(model.page.height)").font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.quiet)};Spacer();Button{model.checkpoint();model.page.baseHidden = !(model.page.baseHidden ?? false);model.save()}label:{Image(systemName:model.page.baseHidden==true ? "eye.slash":"eye")}}.listRowBackground(Color.clear)}
    @ViewBuilder private var opacity:some View{if model.active != nil{HStack{Text("الشفافية").font(.system(size:12));Slider(value:Binding(get:{model.active?.opacity ?? 1},set:{v in model.change{$0.opacity=v}}),in:0...1);Text("\(Int((model.active?.opacity ?? 1)*100))%").font(.system(size:11,design:.monospaced)).frame(width:40)}.padding(.horizontal,20).padding(.vertical,12).disabled(model.active?.isLocked==true)}}
}
struct LayerThumbnail: View {
    let layer:EditorLayer
    let directory:URL
    var previewSize:CGFloat=48
    @State private var image:UIImage?
    var body:some View { ZStack {
        Canvas{context,size in for y in 0..<6{for x in 0..<6{context.fill(Path(CGRect(x:CGFloat(x)*8,y:CGFloat(y)*8,width:8,height:8)),with:.color(.white.opacity((x+y)%2==0 ? 0.12:0.04)))}}}
        if let image{Image(uiImage:image).resizable().scaledToFit()}
    }.task(id:layer){var item=layer;item.frame.x=0;item.frame.y=0;item.rotation=0;item.scaleX=1;item.scaleY=1;item.opacity=1
        let snapshot=item,directory=self.directory,previewSize=self.previewSize
        image=await Task.detached(priority:.utility){let bounds=LayerRenderer.bounds(snapshot),format=UIGraphicsImageRendererFormat();format.scale=2;format.opaque=false;let scale=min((previewSize-4)/max(1,bounds.width),(previewSize-4)/max(1,bounds.height));return UIGraphicsImageRenderer(size:CGSize(width:previewSize,height:previewSize),format:format).image{output in output.cgContext.translateBy(x:(previewSize-bounds.width*scale)/2,y:(previewSize-bounds.height*scale)/2);output.cgContext.scaleBy(x:scale,y:scale);LayerRenderer.draw([snapshot],in:output.cgContext,directory:directory)}}.value
    }}
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
    @State private var savingPhotos=false
    @State private var photosSaved=false
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
            if let url=model.exported,["PNG","JPEG"].contains(format){Button(photosSaved ? "حُفظت في الصور":"حفظ في الاستوديو"){Task{savingPhotos=true;defer{savingPhotos=false};do{try await PhotoSave.save(url);photosSaved=true}catch{model.error=error.localizedDescription}}}.disabled(savingPhotos || photosSaved)}
            Button("إغلاق"){dismiss()}.font(.system(size:12)).foregroundStyle(Palette.quiet)
        }.padding(24).foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.85)).glass(28)
        .onAppear{model.exported=nil}.onChange(of:format){_,_ in model.exported=nil;photosSaved=false}
    }
}
struct SettingsView: View {
    @EnvironmentObject var service:ReferenceService
    @Environment(\.dismiss) private var dismiss
    @State private var account=false
    @State private var profile=false
    @State private var hub=false
    @State private var fonts=false
    @State private var typerSettings=false
    @State private var typerLibrary=false
    @State private var workspaceSettings=false
    var body:some View {
        NavigationStack { ZStack {Ambient();ScrollView {VStack(alignment:.leading,spacing:24) {
            Button{if service.session==nil{account=true}else{profile=true}}label:{HStack(spacing:16){Image(systemName:"person.crop.circle").font(.system(size:42,weight:.ultraLight));VStack(alignment:.leading,spacing:7){Text(service.session==nil ? "تسجيل الدخول":"الملف الشخصي").font(.system(size:17,weight:.semibold));Text(service.session?.user.email ?? "حسابك وأعمالك في مكان واحد").font(.system(size:12)).foregroundStyle(Palette.quiet).lineLimit(1)};Spacer();Image(systemName:"chevron.left").font(.system(size:12))}.padding(22).glass(22)}.buttonStyle(.plain)
            Text("مساحة العمل").font(.system(size:12,weight:.medium)).foregroundStyle(Palette.quiet)
            VStack(spacing:0){row("مساحة العمل والمقاسات","slider.horizontal.3"){workspaceSettings=true};Divider().padding(.horizontal,20);row("مكتبة الخطوط","textformat.alt"){fonts=true}.accessibilityIdentifier("settings-font-library");Divider().padding(.horizontal,20);row("المجتمع","person.2"){hub=true}.accessibilityIdentifier("settings-community");Divider().padding(.horizontal,20);row("فصول التايبر","text.bubble"){typerLibrary=true};Divider().padding(.horizontal,20);row("إعدادات التايبر والوسوم","tag"){typerSettings=true}.accessibilityIdentifier("settings-typer")}
                .glass(20)
            VStack(alignment:.leading,spacing:12){HStack{Image(systemName:"photo");Text("الصورة الأصلية").font(.system(size:15,weight:.medium))};Text("تُحفظ أبعاد صورك عند التصدير إلى PNG. احفظ ملف المشروع للاحتفاظ بالنصوص والطبقات القابلة للتعديل.").font(.system(size:12)).foregroundStyle(Palette.quiet).lineSpacing(6)}.padding(20).glass(20)
            HStack{Brand();Spacer();Text("iPhone · iPad").font(.system(size:11)).foregroundStyle(Palette.quiet)}.padding(.top,12)
        }.padding(24).frame(maxWidth:760).frame(maxWidth:.infinity)} }.foregroundStyle(Palette.pale).navigationTitle("الإعدادات").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"إغلاق"){dismiss()}.accessibilityIdentifier("settings-close")}}.tint(Palette.pale)
        .fullScreenCover(isPresented:$account){AccountView()}.fullScreenCover(isPresented:$profile){ProfileView()}.fullScreenCover(isPresented:$hub){ServiceHub()}.sheet(isPresented:$fonts){FontLibraryView()}.sheet(isPresented:$workspaceSettings){WorkspaceSettingsView()}.fullScreenCover(isPresented:$typerLibrary){TyperLibraryView()}.sheet(isPresented:$typerSettings){TyperSettingsView()}}.cookiesInterface()
    }
    private func row(_ title:String,_ icon:String,action:@escaping ()->Void)->some View{Button(action:action){HStack(spacing:14){Image(systemName:icon).font(.system(size:20)).frame(width:28);Text(title).font(.system(size:14));Spacer();Image(systemName:"chevron.left").font(.system(size:11)).foregroundStyle(Palette.quiet)}.padding(20).frame(maxWidth:.infinity,minHeight:62).contentShape(Rectangle())}.buttonStyle(.plain)}
}
struct BrushSheet:View {
    @ObservedObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @State private var importing=false
    var body:some View {VStack(spacing:0){
        HStack{Text("الفرشاة").font(.system(size:19,weight:.semibold));Spacer();IconButton(icon:"checkmark",title:"تم"){dismiss()}.accessibilityIdentifier("brush-close")}.padding(.horizontal,20).frame(height:54)
        ScrollView{VStack(alignment:.leading,spacing:16){
            Picker("نوع الفرشاة",selection:$model.brushStyle){Text("صلبة").tag("normal");Text("مائية").tag("water");Text("مضيئة").tag("neon");Text("ناعمة").tag("soft");Text("تحديد").tag("marker");Text("خامة").tag("texture")}.pickerStyle(.menu)
            if model.brushStyle=="texture"{Button(model.brushTexture.isEmpty ? "استيراد خامة من الصور":"تغيير الخامة"){importing=true};if !model.brushTexture.isEmpty,let image=ImagePipeline.asset(model.directory.appendingPathComponent(model.brushTexture)){Image(uiImage:image).resizable().scaledToFit().frame(height:70)}}
            Picker("شكل الضربة",selection:$model.drawingShape){Text("حر").tag("free");Text("خط").tag("line");Text("مستطيل").tag("rectangle");Text("دائرة").tag("ellipse");Text("تعبئة").tag("fill");Text("طمس").tag("smudge")}.pickerStyle(.menu)
            if model.drawingShape=="smudge"{Text("قوة الطمس: \(Int(model.smudgeStrength*100))%").font(.system(size:12));Slider(value:$model.smudgeStrength,in:0...1)}
            if model.drawingShape=="fill"{Text("تسامح اللون: \(Int(model.fillTolerance))").font(.system(size:12));Slider(value:$model.fillTolerance,in:0...80)}
            Toggle("تعبئة الشكل",isOn:$model.drawingFilled).disabled(!["rectangle","ellipse"].contains(model.drawingShape))
            ColorPicker("لون الرسم",selection:Binding(get:{Color(uiColor:UIColor(hex:model.brushColor))},set:{model.brushColor=UIColor($0).hex}),supportsOpacity:false)
            Text("الحجم: \(Int(model.brushWidth)) بكسل").font(.system(size:12));Slider(value:$model.brushWidth,in:1...160)
            Text("شفافية الضربة: \(Int(model.brushOpacity*100))%").font(.system(size:12));Slider(value:$model.brushOpacity,in:0...1)
            Button("مسح طبقة الرسم",role:.destructive){if model.active?.kind == .drawing{model.checkpoint();model.change{$0.strokes=[]}}}.disabled(model.active?.kind != .drawing)
        }.padding(20)}
    }.foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.85)).glass(28).sheet(isPresented:$importing){PhotoLibraryPicker{result in switch result{case .failure(let error):model.error=error.localizedDescription;case .success(let urls):if let url=urls.first{defer{try? FileManager.default.removeItem(at:url)};do{let name=UUID().uuidString+"."+url.pathExtension;try FileManager.default.copyItem(at:url,to:model.directory.appendingPathComponent(name));model.brushTexture=name}catch{model.error=error.localizedDescription}}}}}}
}

struct ReaderView:View {
    @ObservedObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    var body:some View {CanvasHost(model:model,readOnly:true).ignoresSafeArea(edges:.bottom).background(Palette.ink).safeAreaInset(edge:.top,spacing:0){HStack{Text(model.page.title).font(.system(size:13)).lineLimit(1);Spacer();IconButton(icon:"xmark",title:"إغلاق القراءة"){dismiss()}}.padding(.horizontal,14).foregroundStyle(Palette.pale).glass(0)}}
}
