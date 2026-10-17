import SwiftUI
import ImageIO

struct EditorView:View {
    @StateObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var importAfterLayerDismiss=false
    @EnvironmentObject private var typer:TyperStore
    @EnvironmentObject private var styles:StyleStore
    @State private var layers=false;@State private var shapes=false;@State private var assistant=false
    @State private var reader=false
    @State private var gridSettingsOpen=false
    @AppStorage("editor-grid-data") private var gridData=Data()
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
        VStack(spacing:0){
            HStack(spacing:0){
                ZStack(alignment:textDock=="top" ? .top:.bottom){
                    Palette.ink.ignoresSafeArea()
                    CanvasHost(model:model,gridSettings:CanvasGridSettings.decode(gridData),onBubble:{rect,shape in placeBubble(rect,shape:shape)})
                    if let objectPanel,model.tool == .move,[LayerKind.image,.shape].contains(model.active?.kind ?? .text){TextInspector(model:model,panel:objectPanel,close:{self.objectPanel=nil}).frame(maxWidth:560).frame(height:290).padding(.horizontal,12).padding(.bottom,8)}
                    if model.tool == .text,let panel=model.panel,panel != .font,model.active?.kind == .text{TextInspector(model:model,panel:panel,close:{model.panel=nil}).frame(maxWidth:560).frame(height:panel == .content ? 240:290).padding(.horizontal,12).padding(.bottom,8)}
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                if horizontalSizeClass == .regular,!layers,model.panel == .font,model.tool == .text{fontDock.frame(width:340)}
                if horizontalSizeClass == .regular,layers{LayerSheet(model:model,onImport:{layers=false;imagePicker=true},onClose:{layers=false}).cookiesInterface().frame(width:370)}
            }
            if horizontalSizeClass != .regular,model.panel == .font,model.tool == .text{fontDock.frame(height:280)}
        }

        .overlay(alignment:.bottom){if model.imageEffectsOpen,model.active?.kind == .image{ImageEffectsPanel(model:model).frame(maxWidth:560).frame(height:420).padding(.horizontal,12).padding(.bottom,8)}}
        .safeAreaInset(edge:.top,spacing:0){HStack(spacing:4){IconButton(icon:"chevron.right",title:"العودة"){model.save();dismiss()};VStack(alignment:.leading,spacing:2){Text(model.page.title).font(.system(size:12,weight:.medium)).lineLimit(1);Text(model.currentLayerTitle).font(.system(size:10)).foregroundStyle(Palette.secondary).lineLimit(1).accessibilityIdentifier("active-layer-name");Text(verbatim:"\(model.page.width) × \(model.page.height) · \(Int(model.zoom*100))%").font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.quiet).accessibilityIdentifier("canvas-zoom")};Spacer(minLength:4);IconButton(icon:"arrow.uturn.backward",title:"تراجع"){model.undo()}.disabled(model.undoStack.isEmpty || model.busy).accessibilityIdentifier("undo");IconButton(icon:"arrow.uturn.forward",title:"إعادة"){model.redo()}.disabled(model.redoStack.isEmpty || model.busy).accessibilityIdentifier("redo");IconButton(icon:"plus.square.on.square",title:"طبقة جديدة"){model.createLayer()}.accessibilityIdentifier("create-layer");IconButton(icon:"square.3.layers.3d",title:"الطبقات"){model.panel=nil;layers=true}.accessibilityIdentifier("layers-header");IconButton(icon:"square.and.arrow.up",title:"تصدير"){showExport=true}.accessibilityIdentifier("export")}.padding(.horizontal,4).glass(0).frame(height:52)}
        .safeAreaInset(edge:.bottom,spacing:0){VStack(spacing:0){
            if [.brush,.eraser,.cleaner].contains(model.tool){HStack(spacing:12){Button{brushSettings=true}label:{Circle().fill(Color(uiColor:UIColor(hex:model.brushColor))).frame(width:24,height:24).overlay(Circle().stroke(Palette.gold.opacity(0.5),lineWidth:1))}.accessibilityLabel("إعدادات الفرشاة");StepSlider(value:$model.brushWidth,in:1...160,onEditingChanged:{model.brushSizePreview=$0}).tint(Palette.gold);Text("\(Int(model.brushWidth))").font(.system(size:10,design:.monospaced)).frame(width:30)}.padding(.horizontal,16).frame(height:38)}
            if model.tool == .text {
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton("chevron.right","رجوع",id:"text-back"){guard model.confirmTextSettings() else{return};model.finishObjectEditing()}
                    if model.active?.kind == .text{toolButton(Panel.styles.icon,Panel.styles.title,id:"panel-styles",selected:model.panel == .styles){model.panel=model.panel == .styles ? nil:.styles}}
                    toolButton("plus","إضافة نص",id:"text-add"){model.add(.text)}
                    gridControl
                    if model.active?.kind == .text{ForEach(Panel.allCases.filter{$0 != .styles}){panel in toolButton(panel.icon,panel.title,id:"panel-\(panel.rawValue)",selected:model.panel==panel){model.panel = model.panel==panel ? nil:panel}}}
                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("panel-strip")
            }else if [.brush,.eraser].contains(model.tool){
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton("chevron.right","رجوع",id:"brush-back"){model.finishObjectEditing()}
                    toolButton("paintbrush.pointed","فرشاة",id:"tool-brush",selected:model.tool == .brush){model.tool = .brush}
                    toolButton("eraser","ممحاة",id:"tool-eraser",selected:model.tool == .eraser){model.tool = .eraser}
                    toolButton("paintpalette","اللون والحجم",id:"brush-settings"){brushSettings=true}
                    gridControl
                    toolButton("square.3.layers.3d","الطبقات",id:"tool-layers"){model.panel=nil;layers=true}
                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("tool-strip")
            }else if model.tool == .move,model.objectControlsOpen,[LayerKind.image,.shape].contains(model.active?.kind ?? .text){
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton("chevron.right","رجوع",id:"object-back"){objectPanel=nil;model.finishObjectEditing()}
                    toolButton("move.3d","الموضع",id:"object-position",selected:objectPanel == .position){objectPanel=objectPanel == .position ? nil:.position}
                    toolButton("circle.lefthalf.filled","الشفافية",id:"object-opacity",selected:objectPanel == .opacity){objectPanel=objectPanel == .opacity ? nil:.opacity}
                    if model.active?.kind == .image{toolButton("sparkles","تأثيرات الصورة",id:"image-effects-open",selected:model.imageEffectsOpen){Task{await model.openImageEffects()}}}
                    if model.active?.kind == .shape{toolButton("paintpalette","اللون",id:"shape-color",selected:objectPanel == .color){objectPanel=objectPanel == .color ? nil:.color};toolButton("a.square","الحدود",id:"shape-stroke",selected:objectPanel == .stroke){objectPanel=objectPanel == .stroke ? nil:.stroke};toolButton("square.on.circle","شكل جديد",id:"shape-add"){shapes=true}}
                    toolButton("doc.on.doc","نسخ",id:"object-duplicate"){model.duplicate()}
                    toolButton("trash","حذف",id:"object-delete"){objectPanel=nil;model.delete()}
                    gridControl
                    toolButton("square.3.layers.3d","الطبقات",id:"object-layers"){model.panel=nil;layers=true}
                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("object-strip")
            }else{
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){
                    toolButton(Tool.text.icon,"نص",id:"tool-text"){select(.text)}
                    toolButton(Tool.brush.icon,"رسم",id:"tool-brush"){select(.brush)}
                    toolButton(Tool.eraser.icon,"ممحاة",id:"tool-eraser"){select(.eraser)}
                    toolButton("photo.badge.checkmark","تأثيرات الصورة",id:"tool-image-effects"){Task{await model.openImageEffects()}}
                    toolButton("photo.badge.plus","صورة",id:"tool-image"){imagePicker=true}
                    toolButton(Tool.shapes.icon,"أشكال",id:"tool-shapes"){select(.shapes)}
                    Menu{ForEach(BubbleShape.allCases){shape in Button(shape.title){model.panel=nil;model.sniperMode=false;model.bubbleShape=shape}}}label:{VStack(spacing:6){Image(systemName:"rectangle.and.pencil.and.ellipsis").font(.system(size:20));Text("تنسيق فقاعة").font(.system(size:10))}.frame(width:76,height:60)}.accessibilityIdentifier("tool-bubble-layout")
                    toolButton("text.bubble","التايبر",id:"tool-typer"){assistant.toggle();model.panel=nil}
                    toolButton("scope","القنص",id:"tool-sniper",selected:model.sniperMode){model.bubbleShape=nil;model.sniperMode.toggle();model.tool = .move;model.panel=nil}
                    toolButton(Tool.cleaner.icon,"تنظيف",id:"tool-cleaner"){select(.cleaner)}
                    toolButton(Tool.eyedropper.icon,"قطارة",id:"tool-eyedropper",selected:model.tool == .eyedropper){select(.eyedropper)}
                    toolButton("photo.on.rectangle","استبدال الأصل",id:"tool-replace-background"){replacingBackground=true}
                    gridControl
                    toolButton("book","القراءة",id:"tool-reader"){reader=true}

                }.padding(.horizontal,8)}.frame(height:68*min(1.15,max(0.85,toolbarScale))).accessibilityIdentifier("tool-strip")
            }

        }.foregroundStyle(Palette.pale).glass(0)}
        .toolbar(.hidden,for:.navigationBar).foregroundStyle(Palette.pale).animation(EditorPreferences.motion ? .easeInOut(duration:0.2):nil,value:model.panel).animation(EditorPreferences.motion ? .easeInOut(duration:0.2):nil,value:objectPanel).animation(EditorPreferences.motion ? .easeInOut(duration:0.2):nil,value:assistant)
        .overlay(alignment:.trailing){if !assistant{Button{assistant=true;model.panel=nil}label:{Image("CookiesLogo").resizable().scaledToFit().frame(width:38,height:38).clipShape(Circle()).padding(6).background(Palette.ink.opacity(0.85),in:Circle()).overlay(Circle().stroke(Palette.gold.opacity(0.4),lineWidth:0.8))}.padding(.trailing,12).accessibilityIdentifier("tool-assistant").accessibilityLabel("التايبر")}}
        .overlay(alignment:.trailing){if assistant{GeometryReader{g in TyperPanel(model:model,close:{assistant=false},compact:g.size.height<500).frame(width:min(CGFloat(typerWidth),g.size.width-24),height:min(CGFloat(typerHeight),max(160,g.size.height-24))).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.trailing).padding(.trailing,8)}.transition(.move(edge:.trailing).combined(with:.opacity))}}
        .overlay(alignment:.top){if let shape=model.bubbleShape{ToolModeCard(title:"تنسيق الفقاعة · "+shape.title,detail:"اسحب داخل الفقاعة؛ يُدرج الحوار التالي من التايبر بحجم وتوزيع مناسبين.",icon:"rectangle.and.pencil.and.ellipsis",close:{model.bubbleShape=nil}){Button{assistant=true}label:{Label("نصوص الفصل",systemImage:"text.bubble")};Menu{ForEach(BubbleShape.allCases){item in Button(item.title){model.bubbleShape=item}}}label:{Label("شكل المنطقة",systemImage:"square.on.circle")}}.padding(.top,58)}}
        .overlay(alignment:.top){if model.sniperMode && model.cleanCandidates.isEmpty{
            if let mode=model.manualSniperTool{ToolModeCard(title:mode == .textRectangle ? "تحديد النص للترميم":"محيط فقاعة يدوي",detail:mode == .freehand ? "ارسم داخل حد الفقاعة بإصبعك. حرّك الصورة وكبّرها بإصبعين.":"اسحب من زاوية إلى الزاوية المقابلة. حرّك الصورة وكبّرها بإصبعين.",icon:mode == .freehand ? "lasso":"rectangle.dashed",close:{model.cancelManualSniper()}){if mode != .textRectangle{Button("مستطيل"){model.manualSniperTool = .rectangle};Button("محيط حر"){model.manualSniperTool = .freehand}};Button("إلغاء"){model.cancelManualSniper()}}.padding(.top,58)}
            else{ToolModeCard(title:"القنص · \(model.sniperTargets.count) أهداف",detail:"المس داخل كل فقاعة بالترتيب، أو ارسم حدودها يدويًا.",icon:"scope",close:{model.sniperMode=false}){Button{_ = model.sniperTargets.popLast()}label:{Label("تراجع",systemImage:"arrow.uturn.backward")}.disabled(model.sniperTargets.isEmpty);Button{model.beginManualSniper(.rectangle)}label:{Label("تحديد يدوي",systemImage:"rectangle.dashed")}.accessibilityIdentifier("sniper-manual");Button{assistant=true}label:{Label("النصوص",systemImage:"text.bubble")};Button{model.sniperWhiteningOpen=true}label:{Label("التبييض",systemImage:"eraser.fill")}.disabled(model.sniperTargets.isEmpty || model.busy).accessibilityIdentifier("sniper-whiten")}.padding(.top,58)}
        }}
        .overlay(alignment:.top){if !model.cleanCandidates.isEmpty{ToolModeCard(title:"مراجعة التنظيف",detail:model.cleanCandidates.first?.detail ?? "قارن النتيجة بالأصل قبل اعتمادها.",icon:"sparkles",close:{model.discardCleaning()}){ForEach(model.cleanCandidates){candidate in Button(candidate.title){model.cleanPreviewID=candidate.id}.buttonStyle(CapsuleActionStyle(selected:model.cleanPreviewID==candidate.id))};Button{model.cleanPreviewID=nil}label:{Label("الأصل",systemImage:"photo")};Button{model.acceptCleaning()}label:{Label("اعتماد",systemImage:"checkmark")}.disabled(model.cleanPreviewID==nil).accessibilityIdentifier("cleaning-accept");Button{model.discardCleaning()}label:{Label("إلغاء",systemImage:"xmark")}.accessibilityIdentifier("cleaning-discard")}.padding(.top,58)}}

        .overlay{if model.busy && !showExport{ProgressView("جارٍ معالجة المنطقة…").tint(Palette.gold).padding(20).glass()}}
        .onChange(of:model.panel){_,panel in if panel == .font{layers=false}}
        .onChange(of:model.selected){_,_ in objectPanel=nil;if model.active?.kind != .image{model.imageEffectsOpen=false}}
        .onChange(of:model.requestTyper){_,open in if open{assistant=true;model.requestTyper=false}}
        .fullScreenCover(isPresented:$reader){ReaderView(model:model).cookiesInterface()}
        .sheet(isPresented:$model.sniperWhiteningOpen){SniperWhiteningPanel(model:model).presentationDetents([.large]).presentationContentInteraction(.scrolls).presentationDragIndicator(.visible).presentationBackground(.clear)}
        .sheet(isPresented:$gridSettingsOpen){CanvasGridSettingsView().presentationDetents([.medium,.large]).presentationBackground(.clear)}
        .sheet(isPresented:$brushSettings){BrushSheet(model:model).cookiesInterface().presentationDetents([.height(300)]).presentationBackground(.clear)}
        .sheet(isPresented:Binding(get:{layers && horizontalSizeClass != .regular},set:{layers=$0}),onDismiss:{if importAfterLayerDismiss{importAfterLayerDismiss=false;imagePicker=true}}){LayerSheet(model:model,onImport:{importAfterLayerDismiss=true;layers=false}).cookiesInterface().presentationDetents([.height(280),.medium,.large]).presentationBackgroundInteraction(.enabled(upThrough:.medium)).presentationBackground(.clear)}
        .sheet(isPresented:$shapes){ShapeSheet(model:model).cookiesInterface().presentationDetents([.medium,.large]).presentationBackground(.clear)}
        .sheet(isPresented:$showExport){ExportSheet(model:model).cookiesInterface().presentationDetents([.height(390)]).presentationBackground(.clear)}
        .sheet(isPresented:$replacingBackground){PhotoLibraryPicker{result in switch result{case .failure(let error):model.error=error.localizedDescription;case .success(let urls):if let url=urls.first{Task{defer{try? FileManager.default.removeItem(at:url)};await model.replaceBackground(url)}}}}}
        .sheet(isPresented:$imagePicker){PhotoLibraryPicker{result in
            switch result{case .failure(let error):model.error=error.localizedDescription
            case .success(let urls):if let url=urls.first{Task{defer{try? FileManager.default.removeItem(at:url)};await model.importImageLayer(url)}}}
        }}

        .cookiesConfirmationDialog("المسح من الطبقة كاملة؟",isPresented:Binding(get:{model.layerRasterizationRequested},set:{model.layerRasterizationRequested=$0;if !$0{model.tool = .move}})){
            Button("تحويل الطبقة والمسح"){Task{await model.rasterizeCurrentLayerForErasing()}}
            Button("إلغاء",role:.cancel){model.tool = .move}
        }message:{Text("تحتوي الطبقة نصوصًا أو أشكالًا قابلة للتحرير. لتحرير بكسلات الطبقة كاملة ستُحوّل محتوياتها إلى صورة بدقة المشروع الأصلية، دون إنشاء طبقة جديدة. يمكنك التراجع لاستعادة النصوص القابلة للتحرير.")}
        .cookiesAlert("تعذر إكمال العملية",isPresented:Binding(get:{model.error != nil},set:{if !$0{model.error=nil}})){Button("حسنًا"){model.error=nil}}message:{Text(model.error ?? "")}
        .onDisappear{model.cancelWhitening();model.commitTextMask();model.discardCleaning();model.save()}
    }
    private var fontDock:some View {
        FontLibraryView(onSelect:{name in model.change{$0.style.fontPath=name}},currentFont:model.active?.style.fontPath,embedded:true,onClose:{guard model.confirmTextSettings() else{return};model.panel=nil;model.save()}).cookiesInterface().background(Palette.ink).onAppear{model.checkpoint()}
    }
    func placeBubble(_ rect:CGRect,shape:BubbleShape){
        guard let chapter=typer.activeChapter else{model.error="افتح التايبر واختر فصلًا أولًا";assistant=true;return}
        let preferences=typer.panelPreferences
        guard var bubble=DialogueSequence.resume(chapter,cursor:preferences.cursor(in:chapter.id)) else{model.error="اكتمل وضع فقاعات هذا الفصل";return}
        guard !model.busy else{return};model.busy=true
        if preferences.uppercase{bubble.text=bubble.text.uppercased()}
        let input:EditorLayer
        do{input=try typer.dialogueLayer(bubble)}catch{model.error=error.localizedDescription;model.busy=false;return}
        let request=BubbleLayoutRequest(bounds:rect,shape:shape),pageID=model.page.id,chapterID=chapter.id
        Task{defer{model.busy=false};do{
            let prepared=try await BackgroundWork.run{try BubbleLayout.fit(input,request:request)}
            guard model.page.id==pageID,typer.activeChapter?.id==chapterID,typer.activeChapter?.bubbles.first(where:{$0.id==bubble.id})?.used==false else{return}
            try typer.place([bubble],chapter:chapterID,model:model,styleAssets:styles.directory,preparedLayout:prepared)
        }catch{model.error=error.localizedDescription}}

    }
    private var gridControl:some View{toolButton("grid","الشبكة",id:"tool-grid",selected:CanvasGridSettings.decode(gridData).enabled){var value=CanvasGridSettings.decode(gridData);value.enabled.toggle();gridData=value.data;if value.enabled{gridSettingsOpen=true}}.contextMenu{Button("إعدادات الشبكة"){gridSettingsOpen=true}}}
    func toolButton(_ icon:String,_ title:String,id:String,selected:Bool=false,action:@escaping ()->Void)->some View{Button(action:action){VStack(spacing:6){Image(systemName:icon).font(.system(size:20*min(1.2,max(0.8,iconScale)),weight:.regular));Text(title).font(.system(size:10*min(1.3,max(0.85,labelScale)))).lineLimit(1)}.frame(width:62,height:60*min(1.15,max(0.85,toolbarScale))).background(selected ? Palette.gold.opacity(0.16):.clear,in:RoundedRectangle(cornerRadius:12))}.disabled(model.busy).accessibilityIdentifier(id).accessibilityLabel(title)}
    func select(_ tool:Tool){model.sniperMode=false;model.bubbleShape=nil;model.gradientTarget=nil;model.tool=tool;switch tool{case .layers:layers=true;case .shapes:shapes=true;case .text:if model.selected==nil || model.active?.kind != .text{model.add(.text)}else{model.panel = .content};case .brush:_ = model.prepareBrushTarget();case .eraser:_ = model.prepareEraserTarget();default:break}}
}
