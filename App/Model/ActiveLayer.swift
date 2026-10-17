import UIKit

extension EditorModel {
    var currentLayerObjects:[EditorLayer]{
        guard let id=currentLayerID else{return []}
        return page.layers.filter{($0.stackID ?? $0.id)==id}
    }
    var currentLayerTitle:String{currentLayerObjects.first.map{$0.stackName ?? $0.name} ?? "الصورة الأصلية"}
    var currentContent:EditorLayer?{
        if let active{return active}
        if let currentContentID,let item=currentLayerObjects.first(where:{$0.id==currentContentID}){return item}
        return currentLayerObjects.last
    }
    func selectLogicalLayer(_ item:EditorLayer){
        guard !busy else{return}
        selected=item.id;stackSelection=true;objectControlsOpen=false;currentLayerID=item.stackID ?? item.id;currentContentID=item.id
        page.activeLayerID=currentLayerID;panel=nil;tool = .move;scheduleEditSave()
    }
    func selectOriginalLayer(){
        selected=nil;currentLayerID=page.id;currentContentID=page.layers.first{$0.isWorkingImage==true}?.id
        page.activeLayerID=currentLayerID;panel=nil;tool = .move;scheduleEditSave()
    }
    /// Hides object editing handles; the selected paint layer and its target
    /// survive every tool/back transition until the user changes the layer.
    func finishObjectEditing(){objectControlsOpen=false;panel=nil;gradientTarget=nil;imageEffectsOpen=false;selected=nil;tool = .move}
    @discardableResult func canEditCurrentLayer()->Bool{
        guard !currentLayerObjects.contains(where:{$0.isLocked}) else{error="الطبقة مقفلة؛ افتح قفلها أولًا";return false}
        guard !(currentLayerID==page.id && page.baseHidden==true && currentLayerObjects.isEmpty),!currentLayerObjects.contains(where:{!$0.isVisible}) else{error="الطبقة مخفية؛ أظهرها أولًا";return false}
        return true
    }
    /// The untouched source already is a layer. Materializing it is a reference
    /// to the original asset, never a duplicate image or an additional stack row.
    func materializeCurrentLayer(){
        if currentLayerID==nil{currentLayerID=page.layers.last.map{$0.stackID ?? $0.id} ?? page.id}
        guard currentLayerID==page.id,!currentLayerObjects.contains(where:{$0.kind != .drawing || !$0.strokes.isEmpty}),page.baseHidden != true else{return}
        var original=EditorLayer(kind:.image,name:"الصورة الأصلية")
        original.stackID=page.id;original.stackName="الصورة الأصلية";original.imagePath=page.source;original.isWorkingImage=true
        original.imagePixelFile=page.raw;original.imagePixelWidth=page.width;original.imagePixelHeight=page.height
        original.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))
        page.layers.insert(original,at:0);page.baseHidden=true
    }
    func attachToCurrentLayer(_ item:inout EditorLayer){
        if currentLayerID==nil{recoverCurrentLayer()}
        let id=currentLayerID ?? page.id;item.stackID=id
        item.stackName=currentLayerObjects.first.map{$0.stackName ?? $0.name} ?? "الصورة الأصلية"
    }
    func insertInCurrentLayer(_ item:EditorLayer){
        let id=item.stackID ?? item.id
        let index=page.layers.lastIndex(where:{($0.stackID ?? $0.id)==id}).map{$0+1} ?? page.layers.count
        page.layers.insert(item,at:index);selected=item.id;page.activeLayerID=currentLayerID
    }
    /// Only this explicit command creates a user-visible layer. Text, image,
    /// shape, Typer and brush operations add contents to the active layer.
    func createLayer(name:String?=nil){
        guard !busy,stylePreviewLayer==nil else{return}
        checkpoint();var item=EditorLayer(kind:.drawing,name:name ?? "طبقة \(logicalLayerCount+1)")
        item.stackID=item.id;item.stackName=item.name;item.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))
        let index=currentLayerObjects.last.flatMap{last in page.layers.firstIndex{$0.id==last.id}}.map{$0+1} ?? page.layers.count
        page.layers.insert(item,at:index);selected=item.id;lastDrawingLayer=item.id;page.activeLayerID=currentLayerID;panel=nil;tool = .move;save()
    }
    func recoverCurrentLayer(){
        if let id=currentLayerID,(id==page.id && page.baseHidden != true) || page.layers.contains(where:{($0.stackID ?? $0.id)==id}){return}
        currentLayerID=page.activeLayerID.flatMap{id in ((id==page.id && page.baseHidden != true) || page.layers.contains(where:{($0.stackID ?? $0.id)==id})) ? id:nil} ?? page.layers.last.map{$0.stackID ?? $0.id} ?? page.id
        currentContentID=currentLayerObjects.last?.id
    }
}

extension EditorModel {
    /// Pixel erasing is destructive to this logical layer, not to the scene
    /// underneath it. Composite raster contents in-place once, at original size;
    /// editable vectors require the explicit confirmation shown by the editor.
    func rasterizeCurrentLayerForErasing()async {
        guard !busy,canEditCurrentLayer(),let layerID=currentLayerID else{return}
        let contents=currentLayerObjects
        guard !contents.isEmpty else{return}
        busy=true;defer{busy=false}
        let before=page,directory=self.directory
        let includesOriginal=layerID==page.id && page.baseHidden != true
        var isolated=page;isolated.layers=contents;isolated.baseHidden = !includesOriginal;isolated.paperWhite=false
        do{
            let file=try await BackgroundWork.run{try ImagePipeline.exportPNG(isolated,directory:directory)}
            defer{try? FileManager.default.removeItem(at:file)}
            guard currentLayerID==layerID,page==before else{return}
            let name="pixels-"+UUID().uuidString+".png",target=directory.appendingPathComponent(name)
            try FileManager.default.moveItem(at:file,to:target)
            var layer=EditorLayer(kind:.image,name:currentLayerTitle)
            layer.id=contents[0].id;layer.groupID=contents[0].groupID;layer.groupName=contents[0].groupName;layer.stackID=layerID;layer.stackName=currentLayerTitle;layer.imagePath=name
            layer.isWorkingImage=includesOriginal || contents.contains{$0.isWorkingImage==true}
            layer.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))
            let ids=Set(contents.map(\.id)),index=page.layers.firstIndex{ids.contains($0.id)} ?? page.layers.count
            checkpoint();if includesOriginal{page.baseHidden=true};page.layers.removeAll{ids.contains($0.id)};page.layers.insert(layer,at:min(index,page.layers.count))
            if layer.isWorkingImage==true,page.paperWhite==nil{page.paperWhite=true}
            selected=layer.id;objectControlsOpen=false;tool = .eraser;save()
        }catch{self.error=error.localizedDescription}
    }
}
