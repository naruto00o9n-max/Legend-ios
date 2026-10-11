import SwiftUI

/// The real canvas and real text inspector, with an isolated disposable project.
/// Saving owns its assets before that preview project is removed.
@MainActor final class TagStyleSession:ObservableObject {
    @Published var model:EditorModel?
    @Published var error:String?
    let root=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Tag-Preview-"+UUID().uuidString)
    private var preparation:Task<Void,Never>?
    func prepare(_ tag:DialogueTag,styles:StyleStore){
        guard model==nil,preparation==nil else{return}
        let root=self.root
        let library=LibraryStore(root:root)
        preparation=Task{do{
            let page=try await BackgroundWork.run{try PageOperations.blank(title:"نمط · "+tag.title,width:800,height:900,color:"F5F3EE",transparent:false,root:root)}
            try Task.checkCancellation()
            let model=EditorModel(page:page,library:library)
            var layer=EditorLayer(kind:.text,name:"معاينة الوسم");layer.textOrigin = .tagPreview;layer.textContent="حوار يصنع الحكاية\nوهذا هو نمط الوسم"
            layer.style=try styles.resolved(tag.style,from:styles.directory,into:model.directory)
            tag.textTransform?.apply(to:&layer)
            let bounds=LayerRenderer.bounds(layer);layer.frame=Box(x:400-Double(bounds.width)/2,y:260-Double(bounds.height)/2,width:Double(bounds.width),height:Double(bounds.height))
            model.page.layers=[layer];model.selected=layer.id;model.stylePreviewLayer=layer.id;model.tool = .text;model.panel = .font;model.save();self.model=model
        }catch{if !Task.isCancelled{self.error=error.localizedDescription}}}
    }
    func finish(){
        preparation?.cancel();model?.cancelPendingSaves()
        // Inspector disappearance may flush a final preview edit first.
        let model=self.model,root=self.root
        Task{try? await Task.sleep(nanoseconds:300_000_000);model?.cancelPendingSaves();try? FileManager.default.removeItem(at:root)}
    }
}

struct TagStyleEditorView:View {
    let tag:DialogueTag
    let save:(EditorLayer,URL)throws->Void
    @EnvironmentObject private var styles:StyleStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session=TagStyleSession()
    @State private var confirmation=false
    var body:some View {
        ZStack{Palette.ink.ignoresSafeArea();if let model=session.model{canvas(model)}else if session.error==nil{ProgressView("جارٍ فتح محرر النمط…").tint(Palette.gold)}}
            .safeAreaInset(edge:.top,spacing:0){HStack(spacing:12){IconButton(icon:"xmark",title:"إلغاء"){dismiss()}.accessibilityIdentifier("tag-editor-cancel");VStack(alignment:.leading,spacing:3){Text("نمط · "+tag.title).font(.system(size:14,weight:.semibold));Text("أدوات النص كاملة · معاينة مباشرة").font(.system(size:10)).foregroundStyle(Palette.secondary)};Spacer(minLength:4);Button{confirmation=true}label:{Label("حفظ الوسم",systemImage:"checkmark")}.buttonStyle(CapsuleActionStyle(selected:true)).disabled(session.model?.active==nil).accessibilityIdentifier("tag-editor-save")}.padding(.horizontal,12).padding(.vertical,8).glass(0)}
            .confirmationDialog("حفظ هذا المظهر للوسم؟",isPresented:$confirmation,titleVisibility:.visible){Button("تأكيد وحفظ"){guard let model=session.model,let layer=model.active else{return};do{try save(layer,model.directory);dismiss()}catch{session.error=error.localizedDescription}}.accessibilityIdentifier("tag-editor-confirm");Button("إلغاء",role:.cancel){}}message:{Text("يُحفظ الخط واللون والحدود والتدرجات والتأثيرات وبقية إعدادات النص لهذا الوسم. يبقى نمط النص اليدوي مستقلًا.")}
            .alert("محرر نمط الوسم",isPresented:Binding(get:{session.error != nil},set:{if !$0{session.error=nil}})){Button("حسنًا"){session.error=nil}}message:{Text(session.error ?? "")}
            .onAppear{session.prepare(tag,styles:styles)}.onDisappear{session.finish()}.cookiesInterface()
    }
    private func canvas(_ model:EditorModel)->some View{TagStyleCanvas(model:model)}
}

private struct TagStyleCanvas:View {
    @ObservedObject var model:EditorModel
    var body:some View {
        ZStack(alignment:.bottom){CanvasHost(model:model);if let panel=model.panel{TextInspector(model:model,panel:panel,close:{model.panel=nil}).frame(maxWidth:560).frame(height:panel == .content ? 240:290).padding(.horizontal,12).padding(.bottom,8)}}
            .safeAreaInset(edge:.bottom,spacing:0){VStack(spacing:0){HStack(spacing:12){Text("جرّب أدوات النص، ثم احفظ الوسم من الأعلى").font(.system(size:10)).foregroundStyle(Palette.secondary);Spacer();IconButton(icon:"arrow.uturn.backward",title:"تراجع"){model.undo();model.selected=model.stylePreviewLayer}.disabled(model.undoStack.isEmpty);IconButton(icon:"arrow.uturn.forward",title:"إعادة"){model.redo();model.selected=model.stylePreviewLayer}.disabled(model.redoStack.isEmpty)}.padding(.horizontal,14);ScrollView(.horizontal,showsIndicators:false){HStack(spacing:4){ForEach(Panel.allCases.filter{$0 != .mask}){panel in Button{model.panel=model.panel==panel ? nil:panel}label:{VStack(spacing:6){Image(systemName:panel.icon).font(.system(size:20));Text(panel.title).font(.system(size:10)).lineLimit(1)}.frame(width:64,height:60).background(model.panel==panel ? Palette.gold.opacity(0.14):.clear,in:RoundedRectangle(cornerRadius:12))}.buttonStyle(.plain).accessibilityIdentifier("panel-"+panel.rawValue)}}.padding(.horizontal,8)}.frame(height:68).accessibilityIdentifier("panel-strip")}.foregroundStyle(Palette.pale).glass(0)}
            .onChange(of:model.selected){_,value in if value != model.stylePreviewLayer{model.selected=model.stylePreviewLayer}}
            .alert("تعذر تطبيق التعديل",isPresented:Binding(get:{model.error != nil},set:{if !$0{model.error=nil}})){Button("حسنًا"){model.error=nil}}message:{Text(model.error ?? "")}
    }
}
