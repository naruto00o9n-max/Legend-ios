import SwiftUI

struct LayerThumbnail: View {
    let layer:EditorLayer
    let directory:URL
    var previewSize:CGFloat=48
    var previewBackground="checker"
    @State private var image:UIImage?
    var body:some View { ZStack {
        Canvas{context,size in let cell:CGFloat=previewSize>48 ? 20:8;for y in 0..<Int(ceil(size.height/cell)){for x in 0..<Int(ceil(size.width/cell)){context.fill(Path(CGRect(x:CGFloat(x)*cell,y:CGFloat(y)*cell,width:cell,height:cell)),with:.color(Color(white:previewBackground=="dark" ? 0.05:previewBackground=="light" ? 0.96:(x+y)%2==0 ? 0.78:0.58)))}}}.allowsHitTesting(false)
        if let image{Image(uiImage:image).resizable().scaledToFit()}
    }.task(id:previewIdentity){
        do{
            try await Task.sleep(nanoseconds:70_000_000)
            let snapshot=previewLayer,directory=self.directory,previewSize=self.previewSize
            let rendered=try await BackgroundWork.run{try Task.checkCancellation();let bounds=snapshot.kind == .text ? TextVisualBounds.rect(snapshot):LayerRenderer.bounds(snapshot),format=UIGraphicsImageRendererFormat();format.scale=2;format.opaque=false;let scale=min((previewSize-4)/max(1,bounds.width),(previewSize-4)/max(1,bounds.height));return RenderBudget.screen{UIGraphicsImageRenderer(size:CGSize(width:previewSize,height:previewSize),format:format).image{output in output.cgContext.translateBy(x:(previewSize-bounds.width*scale)/2,y:(previewSize-bounds.height*scale)/2);output.cgContext.scaleBy(x:scale,y:scale);output.cgContext.translateBy(x:-bounds.minX,y:-bounds.minY);LayerRenderer.draw([snapshot],in:output.cgContext,directory:directory)}}}
            try Task.checkCancellation();image=rendered
        }catch{}
    }}
    private var previewLayer:EditorLayer{
        var item=layer;item.frame.x=0;item.frame.y=0;item.rotation=0;item.scaleX=1;item.scaleY=1;item.shearX=nil;item.opacity=1;item.isVisible=true;item.isLocked=false;item.name="";item.groupName=nil;item.groupID=nil;item.blend = .normal;return item
    }
    private var previewIdentity:LayerPreviewIdentity{LayerPreviewIdentity(layer:previewLayer,size:previewSize,directory:directory.path)}
}
private struct LayerPreviewIdentity:Hashable{let layer:EditorLayer;let size:CGFloat;let directory:String}
struct ShapeSheet:View {
    @ObservedObject var model:EditorModel;@Environment(\.dismiss) var dismiss
    var body:some View{VStack(alignment:.leading,spacing:20){Text("الأشكال وفقاعات الحوار").font(.system(size:18,weight:.semibold));ScrollView{LazyVGrid(columns:[GridItem(.adaptive(minimum:64))],spacing:12){ForEach(0..<20,id:\.self){i in Button{model.add(.shape,shape:i);model.tool = .move;dismiss()}label:{ShapePreview(index:i).frame(height:56).padding(10).glass(16)}.accessibilityLabel("شكل \(i+1)")}}}}.padding(22).foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.8)).glass(28)}
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
            if format=="JPEG"{StepSlider(value:$quality,in:0.5...1);Text("جودة JPEG: \(Int(quality*100))% · ضغط مع فقدان").font(.system(size:11)).foregroundStyle(Palette.quiet)}
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
struct BrushSheet:View {
    @ObservedObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @State private var importing=false
    var body:some View {VStack(spacing:0){
        HStack{Text("الفرشاة").font(.system(size:19,weight:.semibold));Spacer();IconButton(icon:"checkmark",title:"تم"){dismiss()}.accessibilityIdentifier("brush-close")}.padding(.horizontal,20).frame(height:54)
        ScrollView{VStack(alignment:.leading,spacing:16){
            Picker("نوع الفرشاة",selection:$model.brushStyle){Text("صلبة").tag("normal");Text("مائية").tag("water");Text("مضيئة").tag("neon");Text("ناعمة").tag("soft");Text("تحديد").tag("marker");Text("خامة").tag("texture")}.pickerStyle(.menu)
            if model.brushStyle=="texture"{textures;Button(model.brushTexture.isEmpty ? "استيراد خامة من الصور":"تغيير الخامة"){importing=true};if !model.brushTexture.isEmpty,let image=ImagePipeline.asset(model.directory.appendingPathComponent(model.brushTexture)){Image(uiImage:image).resizable().scaledToFit().frame(height:70)}}
            Picker("شكل الضربة",selection:$model.drawingShape){Text("حر").tag("free");Text("خط").tag("line");Text("مستطيل").tag("rectangle");Text("دائرة").tag("ellipse");Text("تعبئة").tag("fill");Text("طمس").tag("smudge")}.pickerStyle(.menu)
            if model.drawingShape=="smudge"{Text("قوة الطمس: \(Int(model.smudgeStrength*100))%").font(.system(size:12));StepSlider(value:$model.smudgeStrength,in:0...1)}
            if model.drawingShape=="fill"{Text("تسامح اللون: \(Int(model.fillTolerance))").font(.system(size:12));StepSlider(value:$model.fillTolerance,in:0...80)}
            Toggle("تعبئة الشكل",isOn:$model.drawingFilled).disabled(!["rectangle","ellipse"].contains(model.drawingShape))
            CookiesColorWell("لون الرسم",selection:Binding(get:{Color(uiColor:UIColor(hex:model.brushColor))},set:{model.brushColor=UIColor($0).hex}),supportsOpacity:false)
            Text("الحجم: \(Int(model.brushWidth)) بكسل").font(.system(size:12));StepSlider(value:$model.brushWidth,in:1...160,onEditingChanged:{model.brushSizePreview=$0});ZStack{Color.clear.frame(height:82);Circle().stroke(.white,lineWidth:1.5).frame(width:min(76,model.brushWidth),height:min(76,model.brushWidth));Text("\(Int(model.brushWidth)) px").font(.system(size:10,design:.monospaced)).offset(y:34)}
            Text("شفافية الضربة: \(Int(model.brushOpacity*100))%").font(.system(size:12));StepSlider(value:$model.brushOpacity,in:0...1)
            Button("مسح طبقة الرسم",role:.destructive){if model.active?.kind == .drawing{model.checkpoint();model.change{$0.strokes=[]}}}.disabled(model.active?.kind != .drawing)
        }.padding(20)}
    }.foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.85)).glass(28).sheet(isPresented:$importing){PhotoLibraryPicker{result in switch result{case .failure(let error):model.error=error.localizedDescription;case .success(let urls):if let url=urls.first{defer{try? FileManager.default.removeItem(at:url)};do{let name=UUID().uuidString+"."+url.pathExtension;try FileManager.default.copyItem(at:url,to:model.directory.appendingPathComponent(name));model.brushTexture=name}catch{model.error=error.localizedDescription}}}}}}
    private var textures:some View{ScrollView(.horizontal,showsIndicators:false){HStack(spacing:10){ForEach(["censor"],id:\.self){name in Button{do{guard let source=Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Brushes") ?? Bundle.main.url(forResource:name,withExtension:"png") else{throw ImageFailure.message("خامة الفرشاة غير متاحة")};let owned="brush-"+name+".png",target=model.directory.appendingPathComponent(owned);if !FileManager.default.fileExists(atPath:target.path){try FileManager.default.copyItem(at:source,to:target)};model.brushTexture=owned}catch{model.error=error.localizedDescription}}label:{if let url=Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Brushes") ?? Bundle.main.url(forResource:name,withExtension:"png"),let image=UIImage(contentsOfFile:url.path){Image(uiImage:image).renderingMode(.template).resizable().scaledToFit().foregroundStyle(Palette.pale).frame(width:44,height:44).padding(8).glass(12).overlay(RoundedRectangle(cornerRadius:12).stroke(model.brushTexture=="brush-"+name+".png" ? Palette.gold:.clear))}}.accessibilityIdentifier("brush-texture-"+name)}}}}

}

struct ReaderView:View {
    @ObservedObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    var body:some View {CanvasHost(model:model,readOnly:true).ignoresSafeArea(edges:.bottom).background(Palette.ink).safeAreaInset(edge:.top,spacing:0){HStack{Text(model.page.title).font(.system(size:13)).lineLimit(1);Spacer();IconButton(icon:"xmark",title:"إغلاق القراءة"){dismiss()}}.padding(.horizontal,14).foregroundStyle(Palette.pale).glass(0)}}
}

struct ExpandedLayerPreview:View {
    let layer:EditorLayer
    let directory:URL
    @Environment(\.dismiss) private var dismiss
    @State private var background="checker"
    var body:some View{NavigationStack{VStack(spacing:18){Picker("خلفية المعاينة",selection:$background){Text("شفافية").tag("checker");Text("فاتح").tag("light");Text("داكن").tag("dark")}.pickerStyle(.segmented);GeometryReader{geometry in LayerThumbnail(layer:layer,directory:directory,previewSize:min(768,max(48,min(geometry.size.width,geometry.size.height))),previewBackground:background).frame(maxWidth:.infinity,maxHeight:.infinity)};Text("الخلفية للمعاينة فقط؛ لا تتغير شفافية الطبقة أو ألوانها.").font(.footnote).foregroundStyle(Palette.quiet)}.padding(20).background(Palette.ink).navigationTitle("معاينة الطبقة").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}}}}.cookiesInterface()}
}
