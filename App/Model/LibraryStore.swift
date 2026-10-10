import Foundation
import SwiftUI

@MainActor final class LibraryStore: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var error: String?
    let root: URL
    init(root: URL? = nil) {
        self.root=root ?? FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Cookies",isDirectory:true)
        if ProcessInfo.processInfo.arguments.contains("-ui-tests"){try? FileManager.default.removeItem(at:self.root)}
        try? FileManager.default.createDirectory(at:self.root,withIntermediateDirectories:true)
        do {
            if let saved=try RecoveryFile.read([LibraryItem].self,at:self.root.appendingPathComponent("library.json")){items=saved.value;if saved.recovered{error="استُعيد المعرض من آخر نسخة سليمة بعد تعذر قراءة الفهرس."}}
        }catch{self.error="تعذر قراءة فهرس المعرض. احتُفظ بالملف المتضرر: \(error.localizedDescription)";items=Self.recoverPages(root:self.root)}
    }
    func save() { do {try writeItems(items)}catch{self.error=error.localizedDescription} }
    func writeItems(_ next:[LibraryItem])throws{try RecoveryFile.write(next,at:root.appendingPathComponent("library.json"))}
    private static func recoverPages(root:URL)->[LibraryItem]{
        let folders=(try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)) ?? []
        return folders.compactMap{folder in guard UUID(uuidString:folder.lastPathComponent) != nil,let data=try? Data(contentsOf:folder.appendingPathComponent("page.json")),let page=try? JSONDecoder().decode(EditorPage.self,from:data) else{return nil};return LibraryItem(id:page.id,title:page.title,folder:false,pages:[page.id])}.sorted{$0.title.localizedStandardCompare($1.title) == .orderedAscending}
    }
    func directory(_ page: UUID)->URL {root.appendingPathComponent(page.uuidString,isDirectory:true)}
    func createFolder(_ name:String,parent:UUID?){var next=items;next.append(LibraryItem(parent:parent,title:name,folder:true));do{try commitItems(next)}catch{self.error=error.localizedDescription}}
    @discardableResult func add(_ page:EditorPage,parent:UUID?)->Bool {
        var next=items
        if let index=next.firstIndex(where:{$0.id==parent && $0.isChapter==true}){next[index].pages.append(page.id);next[index].modified=Date()}else{next.append(LibraryItem(id:page.id,parent:parent,title:page.title,folder:false,pages:[page.id]))}
        do{try commitItems(next);return true}catch{self.error=error.localizedDescription;return false}
    }
    func load(_ id:UUID)throws->EditorPage {
        guard let saved=try RecoveryFile.read(EditorPage.self,at:directory(id).appendingPathComponent("page.json")) else{throw ImageFailure.message("ملف الصفحة مفقود")}
        if saved.recovered{error="استُعيدت الصفحة من آخر حفظ سليم. راجع آخر تعديل قبل المتابعة."};return saved.value
    }
    func persist(_ page:EditorPage)throws {try RecoveryFile.write(page,at:directory(page.id).appendingPathComponent("page.json"))}
    func remove(_ item:LibraryItem){
        var ids:Set<UUID>=[item.id],changed=true
        while changed{changed=false;for child in items where child.parent.map(ids.contains)==true{if ids.insert(child.id).inserted{changed=true}}}
        let removed=items.filter{ids.contains($0.id)},next=items.filter{!ids.contains($0.id)}
        do{try commitItems(next)}catch{self.error=error.localizedDescription;return}
        let retained=Set(next.flatMap(\.pages))
        for id in Set(removed.flatMap(\.pages)) where !retained.contains(id){try? FileManager.default.removeItem(at:directory(id))}
    }
    func move(_ item:LibraryItem,parent:UUID?){
        var parentID=parent,visited=Set<UUID>();while let id=parentID{guard id != item.id,visited.insert(id).inserted else{error="لا يمكن نقل مجلد داخل نفسه";return};parentID=items.first{$0.id==id}?.parent}
        var next=items;if let index=next.firstIndex(where:{$0.id==item.id}){next[index].parent=parent;do{try commitItems(next)}catch{self.error=error.localizedDescription}}
    }
    func rename(_ item:LibraryItem,to name:String){
        var next=items;guard let index=next.firstIndex(where:{$0.id==item.id}) else{return};var previousPage:EditorPage?
        do{if !item.folder,item.isChapter != true{var page=try load(item.id);previousPage=page;page.title=name;try persist(page)};next[index].title=name;try commitItems(next)}catch{if let previousPage{try? persist(previousPage)};self.error=error.localizedDescription}
    }
    func importImage(_ url:URL,parent:UUID?) async {
        if ["pdf","zip","cookieschapter"].contains(url.pathExtension.lowercased()) {var created:UUID?;do{let id=try createChapter(url.deletingPathExtension().lastPathComponent,parent:parent);created=id;try await importPages([url],chapter:id)}catch{if let created,let item=items.first(where:{$0.id==created}),item.pages.isEmpty{remove(item)};self.error=error.localizedDescription};return}
        do {let root=self.root;let page=try await Task.detached(priority:.userInitiated){try url.pathExtension.lowercased()=="cookies" ? ProjectArchive.importFile(url,root:root):ImagePipeline.importImage(url,root:root)}.value;if !add(page,parent:parent){try? FileManager.default.removeItem(at:directory(page.id))}}catch{self.error=error.localizedDescription}
    }
}

@MainActor final class EditorModel:ObservableObject {
    @Published var page:EditorPage
    @Published var selected:UUID?
    @Published var tool:Tool = .move
    @Published var panel:Panel?
    @Published var brushWidth = 12.0
    @Published var brushColor = "D4AF37"
    @Published var brushStyle = "normal"
    @Published var brushOpacity=1.0
    @Published var brushTexture=""
    @Published var brushSizePreview=false
    @Published var drawingShape="free"
    @Published var drawingFilled=false
    @Published var cleanCandidates:[CleaningCandidate]=[]
    var cleaningGeneration=UUID()
    var textSelection=NSRange(location:0,length:0)
    var textSelectionLayer:UUID?
    @Published var gradientTarget:String?
    @Published var cleanPreviewID:UUID?
    @Published var fillTolerance=12.0
    @Published var smudgeStrength=0.4
    var textMaskDraft:TextMaskDraft?
    @Published var textMaskMode=false
    @Published var textMaskRestore=false
    @Published var zoom = 1.0
    @Published var error:String?
    @Published var busy = false
    @Published var exported:URL?
    @Published var undoStack:[[EditorLayer]]=[]
    @Published var redoStack:[[EditorLayer]]=[]
    var undoDocuments:[EditorPage]=[]
    var redoDocuments:[EditorPage]=[]
    @Published var sniperTargets:[SniperTarget]=[]
    @Published var sniperMode=false
    @Published var bubbleShape:BubbleShape?
    @Published var requestTyper=false
    let library:LibraryStore; var visibleCenter=CGPoint.zero
    private var previewTask:Task<Void,Never>?
    init(page:EditorPage,library:LibraryStore){self.page=page;self.library=library}
    var directory:URL {library.directory(page.id)}
    var active:EditorLayer? {page.layers.first{$0.id==selected}}
    @discardableResult func insertDialogues(_ values:[(String,TextStyle?)],targets:[SniperTarget]=[],bubbleLayout:BubbleLayoutRequest?=nil,preparedLayout:EditorLayer?=nil)throws->[UUID] {
        let previous=page.layers;var next=page
        let center = !EditorPreferences.smartPosition || visibleCenter == .zero ? CGPoint(x:Double(page.width)/2,y:200):visibleCenter
        for (index,value) in values.enumerated() {
            var item=EditorLayer(kind:.text,name:value.0);item.textContent=value.0
            if let style=value.1{item.style=style}
            item.style.fontSize*=EditorPreferences.typerScale;item.style.boxWidth=min(item.style.boxWidth*EditorPreferences.typerScale,Double(page.width));let bounds=LayerRenderer.bounds(item);item.frame=Box(x:max(0,center.x-bounds.width/2),y:max(0,center.y-bounds.height/2),width:bounds.width,height:bounds.height)
            if let preparedLayout{item.textContent=preparedLayout.textContent;item.style.fontSize=preparedLayout.style.fontSize;item.style.boxWidth=preparedLayout.style.boxWidth;item.style.alignment=1;item.frame=preparedLayout.frame}
            else if let bubbleLayout{item=try BubbleLayout.fit(item,request:bubbleLayout)}
            if index<targets.count{item=SniperDetector.fitted(item,to:targets[index])}
            next.layers.append(item)
        }
        next.modified=Date();try library.persist(next)
        checkpoint();page=next;selected=next.layers.last?.id;tool = .text;panel=nil;save()
        return Array(next.layers.dropFirst(previous.count)).map(\.id)
    }
    func detectSniper(at point:CGPoint) async {
        guard !busy,point.x>=0,point.y>=0,point.x<Double(page.width),point.y<Double(page.height) else{return}
        busy=true;defer{busy=false};let page=self.page,directory=self.directory
        do{let target=try await Task.detached(priority:.userInitiated){try SniperDetector.detect(page:page,directory:directory,point:point)}.value
            guard sniperMode,self.page.id==page.id else{return}
            if !sniperTargets.contains(where:{hypot($0.point.x-point.x,$0.point.y-point.y)<12}){sniperTargets.append(target)}
        }catch{self.error=error.localizedDescription}
    }
    func checkpoint() {undoStack.append(page.layers);undoDocuments.append(page);if undoStack.count>60{undoStack.removeFirst();undoDocuments.removeFirst()};redoStack=[];redoDocuments=[]}
    func change(persist:Bool=true,_ body:(inout EditorLayer)->Void) {guard let i=page.layers.firstIndex(where:{$0.id==selected}),!page.layers[i].isLocked else{return};body(&page.layers[i]);page.modified=Date();if persist{save()}}
    func add(_ kind:LayerKind,shape:Int=0) {
        checkpoint();let center = !EditorPreferences.smartPosition || visibleCenter == .zero ? CGPoint(x:Double(page.width)/2,y:200):visibleCenter
        var l=EditorLayer(kind:kind,name:kind == .text ? "نص جديد":"طبقة \(page.layers.count+1)");l.frame=Box(x:max(0,Double(center.x)-160),y:max(0,Double(center.y)-65),width:min(320,Double(page.width)),height:130);l.style.boxWidth=l.frame.width;l.style.fontSize=UserDefaults.standard.object(forKey:"default-text-size") as? Double ?? 48;l.shape=shape
        if kind == .drawing{l.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))}
        page.layers.append(l);selected=l.id;save();if kind == .text{panel = .content}
    }
    func delete() {guard let selected,active?.isLocked==false else{return};checkpoint();page.layers.removeAll{$0.id==selected};self.selected=nil;save()}
    func duplicate() {guard var l=active else{return};checkpoint();l.id=UUID();l.frame.x+=20;l.frame.y+=20;page.layers.append(l);selected=l.id;save()}
    func undo(){guard let previous=undoStack.popLast() else{return};redoStack.append(page.layers);redoDocuments.append(page);if let document=undoDocuments.popLast(){page=document}else{page.layers=previous};if textMaskDraft==nil{selected=nil};save()}
    func redo(){guard let next=redoStack.popLast() else{return};undoStack.append(page.layers);undoDocuments.append(page);if let document=redoDocuments.popLast(){page=document}else{page.layers=next};if textMaskDraft==nil{selected=nil};save()}
    func save(){guard textMaskDraft==nil else{return};do{try library.persist(page)}catch{self.error=error.localizedDescription}
        previewTask?.cancel();let snapshot=page,directory=self.directory
        let library=self.library
        previewTask=Task {try? await Task.sleep(nanoseconds:500_000_000);guard !Task.isCancelled else{return};do{try await Task.detached(priority:.utility){try ImagePipeline.projectThumbnail(snapshot,directory:directory)}.value;guard !Task.isCancelled else{return};library.objectWillChange.send()}catch{}}
    }
    func exportPNG() async {await export(format:"PNG")}
    func export(format:String,quality:Double=0.95) async {
        busy=true;defer{busy=false};let page=self.page,directory=self.directory
        do{exported=try await Task.detached(priority:.userInitiated){()->URL in
            switch format {case "JPEG":return try ImagePipeline.exportJPEG(page,directory:directory,quality:quality);case "PSD":return try PSDWriter.export(page,directory:directory);case "مشروع":return try ProjectArchive.export(page,directory:directory);default:return try ImagePipeline.exportPNG(page,directory:directory)}
        }.value}catch{self.error=error.localizedDescription}
    }
    func clean(_ stroke:Stroke) async {
        guard !busy,!stroke.points.isEmpty else{return};busy=true;defer{busy=false}
        let xs=stroke.points.map(\.x),ys=stroke.points.map(\.y),padding=stroke.width+20
        let region=CGRect(x:max(0,(xs.min() ?? 0)-padding),y:max(0,(ys.min() ?? 0)-padding),width:(xs.max() ?? 0)-(xs.min() ?? 0)+padding*2,height:(ys.max() ?? 0)-(ys.min() ?? 0)+padding*2).intersection(CGRect(x:0,y:0,width:page.width,height:page.height)).integral
        guard region.width*region.height<=4_194_304 else{error="اختر مساحة تنظيف أصغر";return}
        let page=self.page,directory=self.directory,radius=EditorPreferences.cleanRadius
        discardCleaning();let generation=cleaningGeneration
        do{let candidates=try await BackgroundWork.run{()->[CleaningCandidate] in
            let cg=try ImagePipeline.compositeRegion(page,directory:directory,rect:region)
            let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
            let mask=UIGraphicsImageRenderer(size:region.size,format:format).image{ctx in UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:region.size));UIColor.white.setStroke();let path=UIBezierPath();path.lineWidth=CGFloat(stroke.width);path.lineCapStyle = .round;path.move(to:CGPoint(x:stroke.points[0].x-Double(region.minX),y:stroke.points[0].y-Double(region.minY)));for p in stroke.points.dropFirst(){path.addLine(to:CGPoint(x:p.x-Double(region.minX),y:p.y-Double(region.minY)))};if stroke.points.count==1{UIColor.white.setFill();let point=stroke.points[0];UIBezierPath(ovalIn:CGRect(x:point.x-Double(region.minX)-stroke.width/2,y:point.y-Double(region.minY)-stroke.width/2,width:stroke.width,height:stroke.width)).fill()}else{path.stroke()}}
            var results:[CleaningCandidate]=[]
            do{for (index,value) in [max(1,radius/2),radius,min(20,radius*2)].enumerated(){try Task.checkCancellation();guard let patch=CookiesInpaint(UIImage(cgImage:cg),mask,value),let data=patch.pngData() else{throw ImageFailure.message("تعذر تنظيف المنطقة")};let name=UUID().uuidString+".png";try data.write(to:directory.appendingPathComponent(name));var layer=EditorLayer(kind:.image,name:"تنظيف ذكي");layer.frame=Box(x:region.minX,y:region.minY,width:region.width,height:region.height);layer.imagePath=name;results.append(CleaningCandidate(title:"تنويع \(index+1)",layer:layer))};return results}catch{for candidate in results{try? FileManager.default.removeItem(at:directory.appendingPathComponent(candidate.layer.imagePath))};throw error}
        }
        guard self.page==page,cleaningGeneration==generation else{for candidate in candidates{try? FileManager.default.removeItem(at:directory.appendingPathComponent(candidate.layer.imagePath))};self.error="تغيرت الصفحة أثناء التنظيف؛ أعد المحاولة على حالتها الحالية.";return}
        cleanCandidates=candidates;cleanPreviewID=candidates.first?.id
        }catch{self.error=error.localizedDescription}
    }
}
