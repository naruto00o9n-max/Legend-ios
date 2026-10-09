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
        if let data=try? Data(contentsOf:self.root.appendingPathComponent("library.json")),let saved=try? JSONDecoder().decode([LibraryItem].self,from:data){items=saved}
    }
    func save() { do {try JSONEncoder().encode(items).write(to:root.appendingPathComponent("library.json"),options:.atomic)}catch{self.error=error.localizedDescription} }
    func directory(_ page: UUID)->URL {root.appendingPathComponent(page.uuidString,isDirectory:true)}
    func createFolder(_ name: String,parent:UUID?) {items.append(LibraryItem(parent:parent,title:name,folder:true));save()}
    func add(_ page:EditorPage,parent:UUID?) {if let index=items.firstIndex(where:{$0.id==parent && $0.isChapter==true}){items[index].pages.append(page.id);items[index].modified=Date()}else{items.append(LibraryItem(id:page.id,parent:parent,title:page.title,folder:false,pages:[page.id]))};save()}
    func load(_ id:UUID)throws->EditorPage {try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:directory(id).appendingPathComponent("page.json")))}
    func persist(_ page:EditorPage)throws {try JSONEncoder().encode(page).write(to:directory(page.id).appendingPathComponent("page.json"),options:.atomic)}
    func remove(_ item:LibraryItem) {for child in items.filter({$0.parent==item.id}){remove(child)};items.removeAll{$0.id==item.id};if !item.folder{for id in item.pages{try? FileManager.default.removeItem(at:directory(id))}};save()}
    func move(_ item:LibraryItem,parent:UUID?){
        var next=parent,visited=Set<UUID>();while let id=next{guard id != item.id,visited.insert(id).inserted else{error="لا يمكن نقل مجلد داخل نفسه";return};next=items.first{$0.id==id}?.parent}
        if let index=items.firstIndex(where:{$0.id==item.id}){items[index].parent=parent;save()}
    }
    func rename(_ item:LibraryItem,to name:String) {if let i=items.firstIndex(where:{$0.id==item.id}){do{if !item.folder,item.isChapter != true{var page=try load(item.id);page.title=name;try persist(page)};items[i].title=name;save()}catch{self.error=error.localizedDescription}}}
    func importImage(_ url:URL,parent:UUID?) async {
        if ["pdf","zip","cookieschapter"].contains(url.pathExtension.lowercased()) {do{let id=try createChapter(url.deletingPathExtension().lastPathComponent,parent:parent);try await importPages([url],chapter:id)}catch{self.error=error.localizedDescription};return}
        do {let root=self.root;let page=try await Task.detached(priority:.userInitiated){try url.pathExtension.lowercased()=="cookies" ? ProjectArchive.importFile(url,root:root):ImagePipeline.importImage(url,root:root)}.value;add(page,parent:parent)}catch{self.error=error.localizedDescription}
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
    @Published var drawingShape="free"
    @Published var drawingFilled=false
    @Published var zoom = 1.0
    @Published var error:String?
    @Published var busy = false
    @Published var exported:URL?
    @Published var undoStack:[[EditorLayer]]=[]
    @Published var redoStack:[[EditorLayer]]=[]
    @Published var sniperTargets:[SniperTarget]=[]
    @Published var sniperMode=false
    let library:LibraryStore; var visibleCenter=CGPoint.zero
    private var previewTask:Task<Void,Never>?
    init(page:EditorPage,library:LibraryStore){self.page=page;self.library=library}
    var directory:URL {library.directory(page.id)}
    var active:EditorLayer? {page.layers.first{$0.id==selected}}
    @discardableResult func insertDialogues(_ values:[(String,TextStyle?)],targets:[SniperTarget]=[])throws->[UUID] {
        let previous=page.layers;var next=page
        let center=visibleCenter == .zero ? CGPoint(x:Double(page.width)/2,y:200):visibleCenter
        for (index,value) in values.enumerated() {
            var item=EditorLayer(kind:.text,name:value.0);item.textContent=value.0
            if let style=value.1{item.style=style}
            item.style.boxWidth=min(item.style.boxWidth,Double(page.width));item.frame=Box(x:max(0,center.x-160),y:max(0,center.y-65),width:item.style.boxWidth,height:130)
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
    func checkpoint() {undoStack.append(page.layers);if undoStack.count>60{undoStack.removeFirst()};redoStack=[]}
    func change(persist:Bool=true,_ body:(inout EditorLayer)->Void) {guard let i=page.layers.firstIndex(where:{$0.id==selected}),!page.layers[i].isLocked else{return};body(&page.layers[i]);page.modified=Date();if persist{save()}}
    func add(_ kind:LayerKind,shape:Int=0) {
        checkpoint();let center=visibleCenter == .zero ? CGPoint(x:Double(page.width)/2,y:200):visibleCenter
        var l=EditorLayer(kind:kind,name:kind == .text ? "نص جديد":"طبقة \(page.layers.count+1)");l.frame=Box(x:max(0,Double(center.x)-160),y:max(0,Double(center.y)-65),width:min(320,Double(page.width)),height:130);l.style.boxWidth=l.frame.width;l.style.fontSize=UserDefaults.standard.object(forKey:"default-text-size") as? Double ?? 48;l.shape=shape
        if kind == .drawing{l.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))}
        page.layers.append(l);selected=l.id;save();if kind == .text{panel = .content}
    }
    func delete() {guard let selected else{return};checkpoint();page.layers.removeAll{$0.id==selected};self.selected=nil;save()}
    func duplicate() {guard var l=active else{return};checkpoint();l.id=UUID();l.frame.x+=20;l.frame.y+=20;page.layers.append(l);selected=l.id;save()}
    func undo(){guard let previous=undoStack.popLast() else{return};redoStack.append(page.layers);page.layers=previous;selected=nil;save()}
    func redo(){guard let next=redoStack.popLast() else{return};undoStack.append(page.layers);page.layers=next;selected=nil;save()}
    func save(){do{try library.persist(page)}catch{self.error=error.localizedDescription}
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
        guard !stroke.points.isEmpty else{return};busy=true;defer{busy=false}
        let xs=stroke.points.map(\.x),ys=stroke.points.map(\.y),padding=stroke.width+20
        let region=CGRect(x:max(0,(xs.min() ?? 0)-padding),y:max(0,(ys.min() ?? 0)-padding),width:(xs.max() ?? 0)-(xs.min() ?? 0)+padding*2,height:(ys.max() ?? 0)-(ys.min() ?? 0)+padding*2).intersection(CGRect(x:0,y:0,width:page.width,height:page.height)).integral
        guard region.width*region.height<=4_194_304 else{error="اختر مساحة تنظيف أصغر";return}
        let page=self.page,directory=self.directory,radius=EditorPreferences.cleanRadius
        do{let filename=try await Task.detached(priority:.userInitiated){()->String in
            let rgba=try ImagePipeline.tile(directory.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:region)
            guard let cg=ImagePipeline.image(rgba,width:Int(region.width),height:Int(region.height)) else{throw ImageFailure.message("تعذر قراءة منطقة التنظيف")}
            let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
            let mask=UIGraphicsImageRenderer(size:region.size,format:format).image{ctx in UIColor.black.setFill();ctx.fill(CGRect(origin:.zero,size:region.size));UIColor.white.setStroke();let path=UIBezierPath();path.lineWidth=CGFloat(stroke.width);path.lineCapStyle = .round;path.move(to:CGPoint(x:stroke.points[0].x-Double(region.minX),y:stroke.points[0].y-Double(region.minY)));for p in stroke.points.dropFirst(){path.addLine(to:CGPoint(x:p.x-Double(region.minX),y:p.y-Double(region.minY)))};if stroke.points.count==1{UIColor.white.setFill();let point=stroke.points[0];UIBezierPath(ovalIn:CGRect(x:point.x-Double(region.minX)-stroke.width/2,y:point.y-Double(region.minY)-stroke.width/2,width:stroke.width,height:stroke.width)).fill()}else{path.stroke()}}
            guard let patch=CookiesInpaint(UIImage(cgImage:cg),mask,radius),let data=patch.pngData() else{throw ImageFailure.message("تعذر تنظيف المنطقة")};let name=UUID().uuidString+".png";try data.write(to:directory.appendingPathComponent(name));return name
        }.value
        checkpoint();var l=EditorLayer(kind:.image,name:"تنظيف ذكي");l.frame=Box(x:region.minX,y:region.minY,width:region.width,height:region.height);l.imagePath=filename;self.page.layers.append(l);selected=l.id;save()
        }catch{self.error=error.localizedDescription}
    }
}
