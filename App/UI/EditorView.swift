import SwiftUI

struct EditorView:View {
    @StateObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @State private var layers=false;@State private var shapes=false;@State private var assistant=false
    @State private var showExport=false;@State private var imagePicker=false
    var body:some View {
        ZStack{Palette.ink.ignoresSafeArea();CanvasHost(model:model).accessibilityIdentifier("editor-canvas")}
        .safeAreaInset(edge:.top,spacing:0){HStack(spacing:4){IconButton(icon:"chevron.right",title:"العودة"){model.save();dismiss()};VStack(alignment:.leading,spacing:2){Text(model.page.title).font(.system(size:12,weight:.medium)).lineLimit(1);Text("\(model.page.width) × \(model.page.height) · \(Int(model.zoom*100))%").font(.system(size:9,design:.monospaced)).foregroundStyle(Palette.quiet)};Spacer(minLength:4);IconButton(icon:"arrow.uturn.backward",title:"تراجع"){model.undo()}.disabled(model.undoStack.isEmpty).accessibilityIdentifier("undo");IconButton(icon:"arrow.uturn.forward",title:"إعادة"){model.redo()}.disabled(model.redoStack.isEmpty);IconButton(icon:"square.and.arrow.up",title:"تصدير"){showExport=true}.accessibilityIdentifier("export")}.padding(.horizontal,4).glass(0).frame(height:52)}
        .safeAreaInset(edge:.bottom,spacing:0){VStack(spacing:0){if model.selected != nil,model.active?.kind == .text {ScrollView(.horizontal,showsIndicators:false){HStack(spacing:4){ForEach(Panel.allCases){p in Button(p.title){model.panel=p}.font(.system(size:11,weight:.medium)).padding(.horizontal,12).frame(height:34).background(model.panel==p ? Palette.gold.opacity(0.14):.clear,in:Capsule()).accessibilityIdentifier("panel-\(p.rawValue)")}}.padding(.horizontal,8)}.frame(height:38)}
            ScrollView(.horizontal,showsIndicators:false){HStack(spacing:2){ForEach(Tool.allCases,id:\.self){t in Button{select(t)}label:{VStack(spacing:3){Image(systemName:t.icon).font(.system(size:18));Text(t.title).font(.system(size:9))}.frame(width:52,height:54).background(model.tool==t ? Palette.gold.opacity(0.15):.clear,in:RoundedRectangle(cornerRadius:12))}.accessibilityIdentifier("tool-\(t.rawValue)")};IconButton(icon:"photo.badge.plus",title:"طبقة صورة"){imagePicker=true};IconButton(icon:"text.bubble",title:"المساعد"){assistant=true}}.padding(.horizontal,8)}.frame(height:62)
        }.foregroundStyle(Palette.pale).glass(0)}
        .toolbar(.hidden,for:.navigationBar).foregroundStyle(Palette.pale)
        .sheet(item:$model.panel){panel in TextInspector(model:model,panel:panel).presentationDetents([.height(300),.large]).presentationDragIndicator(.visible).presentationBackground(.clear)}
        .sheet(isPresented:$layers){LayerSheet(model:model).presentationDetents([.medium,.large]).presentationBackground(.clear)}
        .sheet(isPresented:$shapes){ShapeSheet(model:model).presentationDetents([.medium,.large]).presentationBackground(.clear)}
        .sheet(isPresented:$assistant){AssistantView(insert:{text in model.add(.text);model.change{$0.textContent=text}}).presentationDetents([.medium,.large])}
        .sheet(isPresented:$showExport){ExportSheet(model:model).presentationDetents([.height(310)]).presentationBackground(.clear)}
        .fileImporter(isPresented:$imagePicker,allowedContentTypes:[.image]){result in if case let .success(url)=result {let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};do{let name=UUID().uuidString+"."+url.pathExtension;try FileManager.default.copyItem(at:url,to:model.directory.appendingPathComponent(name));model.add(.image);model.change{$0.imagePath=name}}catch{model.error=error.localizedDescription}}}
        .alert("تعذر إكمال العملية",isPresented:Binding(get:{model.error != nil},set:{if !$0{model.error=nil}})){Button("حسنًا"){model.error=nil}}message:{Text(model.error ?? "")}
        .onDisappear{model.save()}
    }
    func select(_ tool:Tool){model.tool=tool;switch tool{case .layers:layers=true;case .shapes:shapes=true;case .text:model.add(.text);case .brush,.eraser:if model.active?.kind != .drawing{model.add(.drawing)};default:break}}
}
