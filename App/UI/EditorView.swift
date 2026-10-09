import SwiftUI
import ImageIO

struct EditorView:View {
    @StateObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @State private var layers=false;@State private var shapes=false;@State private var assistant=false
    @State private var reader=false
    @State private var brushSettings=false
    @State private var replacingBackground=false
    @State private var objectPanel:Panel?
    @State private var showExport=false;@State private var imagePicker=false
    @AppStorage("text-inline-dock") private var textDock="bottom"
    @AppStorage("editor-icon-scale") private var iconScale=1.0
    @AppStorage("editor-toolbar-scale") private var toolbarScale=1.0
    @AppStorage("editor-label-scale") private var labelScale=1.0
    @AppStorage("typer-panel-width") private var typerWidth=320.0
    @AppStorage("typer-panel-height") private var typerHeight=490.0
    var body:some View {
        ZStack(alignment:textDock=="top" ? .top:.bottom){Palette.ink.ignoresSafeArea();CanvasHost(model:model);if let objectPanel,model.tool == .move,[LayerKind.image,.shape].contains(model.active?.kind ?? .text){TextInspector(model:model,panel:objectPanel,close:{self.objectPanel=nil}).frame(maxWidth:560).frame(height:290).padding(.horizontal,12).padding(.bottom,8)};if model.tool == .text{if let panel=model.panel,model.active?.kind == .text{TextInspector(model:model,panel:panel,close:{model.panel=nil}).frame(maxWidth:560).frame(height:panel == .content ? 240:290).padding(.horizontal,12).padding(.bottom,8).transition(.move(edge:.bottom).combined(with:.opacity))}}}
        .safeAreaInset(edge:.top,spacing:0){HStack(spacing:4){IconButton(icon:"chevron.right",title:"العودة"){model.save();dismiss()};VStack(alignment:.leading,spacing:2){Text(model.page.title).font(.system(size:12,weight:.medium)).lineLimit(1);Text(verbatim:"\(model.page.width) × \(model.page.height) · \(Int(model.zoom*100))%").font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.quiet).accessibilityIdentifier("canvas-zoom")};Spacer(minLength:4);IconButton(icon:"arrow.uturn.backward",title:"تراجع"){model.undo()}.disabled(model.undoStack.isEmpty).accessibilityIdentifier("undo");IconButton(icon:"arrow.uturn.forward",title:"إعادة"){model.redo()}.disabled(model.redoStack.isEmpty);IconButton(icon:"square.3.layers.3d",title:"الطبقات"){layers=true}.accessibilityIdentifier("layers-header");IconButton(icon:"square.and.arrow.up",title:"تصدير"){showExport=true}.accessibilityIdentifier("export")}.padding(.horizontal,4).glass(0).frame(height:52)}
        .safeAreaInset(edge:.bottom,spacing:0){VStack(spacing:0){
            if [.brush,.eraser,.cleaner].contains(model.tool){HStack(spacing:12){Button{brushSettings=true}label:{Circle().fill(Color(uiColor:UIColor(hex:model.brushColor))).frame(width:24,height:24).overlay(Circle().stroke(Palette.gold.opacity(0.5),lineWidth:1))}.accessibilityLabel("إعدادات الفرشاة");Slider(value:$model.brushWidth,in:1...160).tint(Palette.gold);Text("\(Int(model.brushWidth))").font(.system(size:10,design:.monospaced)).frame(width:30)}.padding(.horizontal,16).frame(height:38)}
            if model.tool == .text {
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton("chevron.right","رجوع",id:"text-back"){model.panel=nil;model.gradientTarget=nil;model.tool = .move}
                    toolButton("plus","إضافة نص",id:"text-add"){model.add(.text)}
                    if model.active?.kind == .text{ForEach(Panel.allCases){panel in toolButton(panel.icon,panel.title,id:"panel-\(panel.rawValue)",selected:model.panel==panel){model.panel = model.panel==panel ? nil:panel}}}
                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("panel-strip")
            }else if [.brush,.eraser].contains(model.tool){
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton("chevron.right","رجوع",id:"brush-back"){model.tool = .move}
                    toolButton("paintbrush.pointed","فرشاة",id:"tool-brush",selected:model.tool == .brush){model.tool = .brush}
                    toolButton("eraser","ممحاة",id:"tool-eraser",selected:model.tool == .eraser){model.tool = .eraser}
                    toolButton("paintpalette","اللون والحجم",id:"brush-settings"){brushSettings=true}
                    toolButton("square.3.layers.3d","الطبقات",id:"tool-layers"){layers=true}
                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("tool-strip")
            }else if model.tool == .move,[LayerKind.image,.shape].contains(model.active?.kind ?? .text){
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton("chevron.right","رجوع",id:"object-back"){objectPanel=nil;model.selected=nil}
                    toolButton("move.3d","الموضع",id:"object-position",selected:objectPanel == .position){objectPanel=objectPanel == .position ? nil:.position}
                    toolButton("circle.lefthalf.filled","الشفافية",id:"object-opacity",selected:objectPanel == .opacity){objectPanel=objectPanel == .opacity ? nil:.opacity}
                    if model.active?.kind == .shape{toolButton("paintpalette","اللون",id:"shape-color",selected:objectPanel == .color){objectPanel=objectPanel == .color ? nil:.color};toolButton("a.square","الحدود",id:"shape-stroke",selected:objectPanel == .stroke){objectPanel=objectPanel == .stroke ? nil:.stroke};toolButton("square.on.circle","شكل جديد",id:"shape-add"){shapes=true}}
                    toolButton("doc.on.doc","نسخ",id:"object-duplicate"){model.duplicate()}
                    toolButton("trash","حذف",id:"object-delete"){objectPanel=nil;model.delete()}
                    toolButton("square.3.layers.3d","الطبقات",id:"object-layers"){layers=true}
                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("object-strip")
            }else{
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton(Tool.text.icon,"نص",id:"tool-text"){select(.text)}
                    toolButton(Tool.brush.icon,"رسم",id:"tool-brush"){select(.brush)}
                    toolButton("photo.badge.plus","صورة",id:"tool-image"){imagePicker=true}
                    toolButton(Tool.shapes.icon,"أشكال",id:"tool-shapes"){select(.shapes)}
                    toolButton("text.bubble","التايبر",id:"tool-typer"){assistant.toggle();model.panel=nil}
                    Menu{
                        Button{select(.cleaner)}label:{Label("تنظيف",systemImage:"sparkles")}.accessibilityIdentifier("tool-cleaner")
                        Button{select(.eyedropper)}label:{Label("قطارة",systemImage:"eyedropper")}.accessibilityIdentifier("tool-eyedropper")
                        Button{replacingBackground=true}label:{Label("استبدال الصورة الأصلية",systemImage:"photo.on.rectangle")}
                        Button{reader=true}label:{Label("القراءة",systemImage:"book")}.accessibilityIdentifier("tool-reader")
                    }label:{VStack(spacing:6){Image(systemName:"ellipsis").font(.system(size:20));Text("المزيد").font(.system(size:10))}.frame(width:62,height:60)}.accessibilityIdentifier("tool-more")
                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("tool-strip")
            }

        }.foregroundStyle(Palette.pale).glass(0)}
        .toolbar(.hidden,for:.navigationBar).foregroundStyle(Palette.pale).animation(EditorPreferences.motion ? .easeInOut(duration:0.2):nil,value:model.panel)
        .overlay(alignment:.trailing){if !assistant{Button{assistant=true;model.panel=nil}label:{Image("CookiesLogo").resizable().scaledToFit().frame(width:38,height:38).clipShape(Circle()).padding(6).background(Palette.ink.opacity(0.85),in:Circle()).overlay(Circle().stroke(Palette.gold.opacity(0.4),lineWidth:0.8))}.padding(.trailing,12).accessibilityIdentifier("tool-assistant").accessibilityLabel("التايبر")}}
        .overlay(alignment:.trailing){if assistant{GeometryReader{g in TyperPanel(model:model,close:{assistant=false},compact:g.size.height<500).frame(width:min(CGFloat(typerWidth),g.size.width-24),height:min(CGFloat(typerHeight),max(160,g.size.height-136))).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.trailing).padding(.trailing,8)}.transition(.move(edge:.trailing).combined(with:.opacity))}}
        .overlay(alignment:.top){if model.sniperMode{HStack{Image(systemName:"scope");Text("حدد الفقاعات بالترتيب · \(model.sniperTargets.count)").font(.system(size:12));Button("تراجع"){_ = model.sniperTargets.popLast()}.disabled(model.sniperTargets.isEmpty);Button("الفقاعات"){assistant=true};Button("إنهاء"){model.sniperMode=false}}.padding(12).glass(14).padding(.horizontal,12).padding(.top,58)}}
        .overlay(alignment:.top){if !model.cleanCandidates.isEmpty{HStack(spacing:8){ForEach(model.cleanCandidates){candidate in Button(candidate.title){model.cleanPreviewID=candidate.id}.buttonStyle(.bordered).tint(model.cleanPreviewID==candidate.id ? Palette.gold:Palette.pale)};Button("اعتماد"){model.acceptCleaning()};Button("إلغاء"){model.discardCleaning()}}.font(.system(size:11)).padding(12).glass(14).padding(.horizontal,12).padding(.top,58)}}
        .overlay{if model.busy && !showExport{ProgressView("جارٍ معالجة المنطقة…").tint(Palette.gold).padding(20).glass()}}
        .onChange(of:model.selected){_,_ in objectPanel=nil}
        .onChange(of:model.requestTyper){_,open in if open{assistant=true;model.requestTyper=false}}
        .fullScreenCover(isPresented:$reader){ReaderView(model:model).cookiesInterface()}
        .sheet(isPresented:$brushSettings){BrushSheet(model:model).cookiesInterface().presentationDetents([.height(300)]).presentationBackground(.clear)}
        .sheet(isPresented:$layers){LayerSheet(model:model).cookiesInterface().presentationDetents([.medium,.large]).presentationBackground(.clear)}
        .sheet(isPresented:$shapes){ShapeSheet(model:model).cookiesInterface().presentationDetents([.medium,.large]).presentationBackground(.clear)}
        .sheet(isPresented:$showExport){ExportSheet(model:model).cookiesInterface().presentationDetents([.height(390)]).presentationBackground(.clear)}
        .sheet(isPresented:$replacingBackground){PhotoLibraryPicker{result in switch result{case .failure(let error):model.error=error.localizedDescription;case .success(let urls):if let url=urls.first{Task{defer{try? FileManager.default.removeItem(at:url)};await model.replaceBackground(url)}}}}}
        .sheet(isPresented:$imagePicker){PhotoLibraryPicker{result in
            switch result{case .failure(let error):model.error=error.localizedDescription
            case .success(let urls):if let url=urls.first{defer{try? FileManager.default.removeItem(at:url)};do{
                let name=UUID().uuidString+"."+url.pathExtension;let destination=model.directory.appendingPathComponent(name)
                try FileManager.default.copyItem(at:url,to:destination)
                guard let image=ImagePipeline.asset(destination),image.size.width>0 else{throw ImageFailure.message("تعذر قراءة الصورة المختارة")}
                model.add(.image);model.tool = .move;model.change{$0.imagePath=name;$0.frame.height=$0.frame.width*Double(image.size.height/image.size.width)}
            }catch{model.error=error.localizedDescription}}}
        }}

        .alert("تعذر إكمال العملية",isPresented:Binding(get:{model.error != nil},set:{if !$0{model.error=nil}})){Button("حسنًا"){model.error=nil}}message:{Text(model.error ?? "")}
        .onDisappear{model.discardCleaning();model.save()}
    }
    func toolButton(_ icon:String,_ title:String,id:String,selected:Bool=false,action:@escaping ()->Void)->some View{Button(action:action){VStack(spacing:6){Image(systemName:icon).font(.system(size:20*min(1.2,max(0.8,iconScale)),weight:.regular));Text(title).font(.system(size:10*min(1.3,max(0.85,labelScale)))).lineLimit(1)}.frame(width:62,height:60*min(1.15,max(0.85,toolbarScale))).background(selected ? Palette.gold.opacity(0.16):.clear,in:RoundedRectangle(cornerRadius:12))}.accessibilityIdentifier(id).accessibilityLabel(title)}
    func select(_ tool:Tool){model.gradientTarget=nil;model.tool=tool;switch tool{case .layers:layers=true;case .shapes:shapes=true;case .text:if model.active?.kind != .text{model.add(.text)}else{model.panel = .content};case .brush,.eraser:if model.active?.kind != .drawing{model.add(.drawing)};default:break}}
}
