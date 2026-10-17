import UIKit

extension EditorLayer {
    /// Raster strokes erase their own ink history. Other kinds retain editable
    /// content and use a separate alpha mask in the same local coordinate space.
    mutating func appendEditorStroke(_ stroke:Stroke) {
        if stroke.erase && kind != .drawing && kind != .image{erasures=(erasures ?? [])+[stroke]}
        else{strokes.append(stroke)}
    }
}

extension EditorModel {
    var logicalLayerCount:Int{var ids=Set(page.layers.map{$0.stackID ?? $0.id});if page.baseHidden != true{ids.insert(page.id)};return ids.count}
    /// Older documents encoded each text object as a stack row. Adjacent text
    /// objects can share a logical text layer without rasterization or reordering.
    func organizeLegacyTextLayers(){
        var next=page,stack:UUID?,changed=false
        for i in next.layers.indices{
            if next.layers[i].kind != .text{stack=nil;continue}
            if let existing=next.layers[i].stackID{stack=existing;continue}
            let id=stack ?? UUID();stack=id;next.layers[i].stackID=id;next.layers[i].stackName="النصوص";changed=true
        }
        if changed{page=next;save()}
    }
    var selectedLayerObjects:Set<UUID>{
        guard let active else{return []}
        if stackSelection,let stack=active.stackID{return Set(page.layers.filter{$0.stackID==stack}.map(\.id))}
        return [active.id]
    }
    func layerObjects(_ id:UUID)->[EditorLayer]{
        guard let layer=page.layers.first(where:{$0.id==id}) else{return []}
        guard let stack=layer.stackID else{return [layer]}
        return page.layers.filter{$0.stackID==stack}
    }
    @discardableResult func prepareBrushTarget()->Bool {
        guard canEditCurrentLayer() else{return false}
        if let item=currentLayerObjects.last,[LayerKind.drawing,.image].contains(item.kind){selected=item.id;if item.kind == .drawing{lastDrawingLayer=item.id};return true}
        // A paint record belongs to the selected layer. Reuse it after each
        // finger lift; do not jump to another layer or create a stack row.
        checkpoint();var item=EditorLayer(kind:.drawing,name:"الرسم")
        item.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))
        attachToCurrentLayer(&item);insertInCurrentLayer(item);lastDrawingLayer=item.id;save();return true
    }
    @discardableResult func appendRasterPatch(_ patch:EditorLayer)->Bool{
        guard prepareBrushTarget(),let active else{return false}
        let inverse=LayerRenderer.transform(active).inverted(),rect=patch.frame.cg
        let points=[CGPoint(x:rect.minX,y:rect.minY),CGPoint(x:rect.maxX,y:rect.minY),CGPoint(x:rect.minX,y:rect.maxY)].map{$0.applying(inverse)}.map{Point(x:Double($0.x),y:Double($0.y))}
        let mark=Stroke(points:points,width:1,color:"FFFFFF",brush:"image-patch",texturePath:patch.imagePath,patchSize:Point(x:rect.width,y:rect.height))
        checkpoint();change{$0.appendEditorStroke(mark)};save();return true
    }
    func reorderLayerStacks(_ rows:[UUID],from source:IndexSet,to destination:Int){
        guard source.count==1,let index=source.first,rows.indices.contains(index) else{return}
        let ids=Set(layerObjects(rows[index]).map(\.id)),objects=page.layers.filter{ids.contains($0.id)}
        var remaining=page.layers.filter{!ids.contains($0.id)}
        let anchor=destination<rows.count ? rows[destination]:nil
        let position:Int
        if let anchor,!ids.contains(anchor){let anchors=Set(layerObjects(anchor).map(\.id));position=(remaining.lastIndex{anchors.contains($0.id)}).map{$0+1} ?? remaining.count}
        else if destination>=rows.count{let bottom=rows.reversed().first{!ids.contains($0)};let anchors=Set(bottom.map{layerObjects($0).map(\.id)} ?? []);position=remaining.firstIndex{anchors.contains($0.id)} ?? 0}
        else{return}
        checkpoint();remaining.insert(contentsOf:objects,at:position);page.layers=remaining;save()
    }
    func changeLayerObjects(_ body:(inout EditorLayer)->Void){
        let ids=selectedLayerObjects;var next=page
        for index in next.layers.indices where ids.contains(next.layers[index].id) && !next.layers[index].isLocked{body(&next.layers[index])}
        next.modified=Date();page=next;scheduleEditSave()
    }
    func setStackVisibility(_ id:UUID,_ visible:Bool){
        let objects=layerObjects(id),ids=Set(objects.map(\.id));checkpoint()
        if objects.first?.stackID==page.id,!objects.contains(where:{$0.isWorkingImage==true}){page.baseHidden = !visible}
        for index in page.layers.indices where ids.contains(page.layers[index].id){page.layers[index].isVisible=visible};save()
    }
    func setStackLocked(_ id:UUID,_ locked:Bool){
        let ids=Set(layerObjects(id).map(\.id));checkpoint()
        for index in page.layers.indices where ids.contains(page.layers[index].id){page.layers[index].isLocked=locked};save()
    }
    func importImageLayer(_ input:URL) async {
        guard !busy else{return};busy=true;defer{busy=false}
        let directory=self.directory,pageID=page.id
        do{
            let result=try await BackgroundWork.run{()->(String,Int,Int) in
                let scratch=FileManager.default.temporaryDirectory.appendingPathComponent("layer-import-"+UUID().uuidString)
                try FileManager.default.createDirectory(at:scratch,withIntermediateDirectories:true)
                defer{try? FileManager.default.removeItem(at:scratch)}
                let imported=try ImagePipeline.importImage(input,root:scratch),name="picture-"+UUID().uuidString+".png"
                try FileManager.default.copyItem(at:scratch.appendingPathComponent(imported.id.uuidString).appendingPathComponent(imported.source),to:directory.appendingPathComponent(name))
                return(name,imported.width,imported.height)
            }
            guard page.id==pageID else{try? FileManager.default.removeItem(at:directory.appendingPathComponent(result.0));return}
            let center=visibleCenter == .zero ? CGPoint(x:Double(page.width)/2,y:Double(page.height)/2):visibleCenter
            let width=min(Double(result.1),Double(page.width)*0.75),height=width*Double(result.2)/Double(result.1)
            var layer=EditorLayer(kind:.image,name:input.deletingPathExtension().lastPathComponent)
            layer.imagePath=result.0;layer.frame=Box(x:center.x-width/2,y:center.y-height/2,width:width,height:height)
            guard canEditCurrentLayer() else{try? FileManager.default.removeItem(at:directory.appendingPathComponent(result.0));return}
            checkpoint();attachToCurrentLayer(&layer);insertInCurrentLayer(layer);tool = .move;panel=nil;save()
        }catch{self.error=error.localizedDescription}
    }
    /// Returns false for locked/hidden targets rather than silently making a
    /// new layer that has nothing to erase. The base is promoted by reference.
    @discardableResult func prepareEraserTarget()->Bool {
        guard canEditCurrentLayer() else{return false}
        let contents=currentLayerObjects.filter{$0.kind != .drawing || !$0.strokes.isEmpty || !($0.erasures ?? []).isEmpty}
        if contents.count+(currentLayerID==page.id && page.baseHidden != true ? 1:0)>1{
            if contents.contains(where:{$0.kind == .text || $0.kind == .shape}){layerRasterizationRequested=true}
            else if !busy{Task{await rasterizeCurrentLayerForErasing()}}
            return false
        }
        if let item=contents.first {
            guard !item.isLocked,item.isVisible else{error="اختر عنصرًا ظاهرًا وغير مقفل للمسح";return false}
            selected=item.id
            if item.isWorkingImage==true,page.baseHidden==true,page.paperWhite==nil{checkpoint();page.paperWhite=true;save()}
            return true
        }
        // The only implicit backing is the existing original image, by
        // reference. A missing selection never falls through to brush creation.
        guard currentLayerID==page.id,page.baseHidden != true else{error="هذه الطبقة فارغة؛ لا يوجد شيء لمسحه";return false}
        checkpoint();materializeCurrentLayer();page.paperWhite=true
        if let item=currentLayerObjects.first{selected=item.id};save();return active != nil
    }
    func setPaperWhite(_ white:Bool){guard page.paperWhite != white else{return};checkpoint();page.paperWhite=white;save()}
    func renameLayer(_ id:UUID,to name:String) {
        if stackSelection,let stack=active?.stackID{let title=name.trimmingCharacters(in:.whitespacesAndNewlines);guard !title.isEmpty else{return};checkpoint();for i in page.layers.indices where page.layers[i].stackID==stack{page.layers[i].stackName=String(title.prefix(120))};save();return}
        let title=name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !title.isEmpty,let index=page.layers.firstIndex(where:{$0.id==id}),page.layers[index].name != title else{return}
        checkpoint();page.layers[index].name=String(title.prefix(120));save()
    }
    func setLayerVisibility(_ id:UUID,_ visible:Bool) {
        guard let index=page.layers.firstIndex(where:{$0.id==id}),page.layers[index].isVisible != visible else{return}
        checkpoint();page.layers[index].isVisible=visible;save()
    }
    func setLayerLocked(_ id:UUID,_ locked:Bool) {
        guard let index=page.layers.firstIndex(where:{$0.id==id}),page.layers[index].isLocked != locked else{return}
        checkpoint();page.layers[index].isLocked=locked;save()
    }
    func moveActiveLayer(by distance:Int) {
        guard let id=selected,let index=page.layers.firstIndex(where:{$0.id==id}),!page.layers[index].isLocked else{return}
        let ids=selectedLayerObjects,objects=page.layers.filter{ids.contains($0.id)}
        var remaining=page.layers.filter{!ids.contains($0.id)}
        let position=min(remaining.count,max(0,index+(distance>0 ? 1:-1)))
        checkpoint();remaining.insert(contentsOf:objects,at:position);page.layers=remaining;save()
    }
    func flipActiveLayer(horizontal:Bool) {
        guard active?.isLocked==false else{return};checkpoint()
        change{if horizontal{$0.scaleX *= -1}else{$0.scaleY *= -1}}
    }
    /// A clear is reversible and leaves the layer in its stack position. For
    /// pictures/shapes the mask replaces prior marks without altering the source.
    func clearActiveLayer() {
        guard let active,!active.isLocked else{return};checkpoint()
        let bounds=LayerRenderer.bounds(active)
        changeLayerObjects{layer in
            switch layer.kind {
            case .drawing:layer.strokes=[];layer.erasures=nil
            case .text:layer.textContent="";layer.textMask=nil;layer.erasures=nil
            case .image,.shape:
                layer.erasures=[Stroke(points:[Point(x:bounds.minX,y:bounds.minY),Point(x:bounds.maxX,y:bounds.maxY)],width:1,color:"000000",erase:true,shape:"rectangle",filled:true)]
            }
        }
    }
    func restoreActiveErasure() {
        guard active?.isLocked==false,!(active?.erasures ?? []).isEmpty else{return}
        checkpoint();change{$0.erasures=nil}
    }
    func mergeActiveDown() async {
        guard let id=selected,let index=page.layers.firstIndex(where:{$0.id==id}),index>0 else{return}
        await mergeLayers([id,page.layers[index-1].id])
    }
    func exportActiveLayerPNG() async->URL? {
        guard active != nil,!busy else{return nil};busy=true;defer{busy=false}
        var snapshot=page;snapshot.baseHidden=true;snapshot.paperWhite=false;snapshot.layers=page.layers.filter{selectedLayerObjects.contains($0.id)}
        let directory=self.directory
        do{return try await BackgroundWork.run{try ImagePipeline.exportPNG(snapshot,directory:directory)}}
        catch{self.error=error.localizedDescription;return nil}
    }
    func rasterizeActiveLayer() async {
        guard let active,!active.isLocked,!busy else{return}
        let ids=selectedLayerObjects,indices=page.layers.indices.filter{ids.contains(page.layers[$0].id)}
        guard let first=indices.first,let last=indices.last,indices==Array(first...last),indices.allSatisfy({!page.layers[$0].isLocked}) else{error="اختر طبقة متجاورة وغير مقفلة";return}
        busy=true;defer{busy=false};let snapshot=page,directory=self.directory,objects=indices.map{page.layers[$0]}
        do {
            let result=try await BackgroundWork.run{try LayerBitmap.merge(objects,page:snapshot,directory:directory)}
            guard page==snapshot else{try? FileManager.default.removeItem(at:directory.appendingPathComponent(result.imagePath));return}
            var raster=result;raster.id=active.id;raster.name=active.stackName ?? active.name;raster.isVisible=active.isVisible
            raster.stackID=active.stackID;raster.stackName=active.stackName;raster.groupID=active.groupID;raster.groupName=active.groupName;raster.blend=active.blend
            checkpoint();page.layers.replaceSubrange(first...last,with:[raster]);selected=raster.id;save()
        }catch{self.error=error.localizedDescription}
    }
}
