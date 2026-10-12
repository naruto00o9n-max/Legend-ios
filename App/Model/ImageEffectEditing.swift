import Foundation

extension EditorModel {
    func openImageEffects() async {
        guard !busy else{return}
        if let active,active.kind == .image {guard !active.isLocked else{return};imageEffectsOpen=true;return}
        if let existing=page.layers.first(where:{$0.isWorkingImage==true && $0.isVisible}){selected=existing.id;tool = .move;imageEffectsOpen=true;return}
        busy=true;defer{busy=false}
        let before=page,directory=self.directory,name="working-\(UUID().uuidString).png"
        do {
            try await BackgroundWork.run{try FileManager.default.copyItem(at:directory.appendingPathComponent(before.source),to:directory.appendingPathComponent(name))}
            guard page==before else{try? FileManager.default.removeItem(at:directory.appendingPathComponent(name));return}
            var layer=EditorLayer(kind:.image);layer.name="صورة العمل";layer.imagePath=name;layer.isWorkingImage=true
            layer.imagePixelFile=before.raw;layer.imagePixelWidth=before.width;layer.imagePixelHeight=before.height
            layer.frame=Box(x:0,y:0,width:Double(before.width),height:Double(before.height))
            checkpoint();page.layers.insert(layer,at:0);page.baseHidden=true;selected=layer.id;tool = .move;save();imageEffectsOpen=true
        }catch{self.error=error.localizedDescription}
    }
    @discardableResult func addImageEffect(_ kind:ImageEffectKind)->UUID? {
        guard active?.kind == .image,active?.isLocked==false else{return nil}
        checkpoint();let effect=ImageEffect(kind);change{$0.imageEffects=($0.imageEffects ?? [])+[effect]};return effect.id
    }
    func editImageEffect(_ id:UUID,_ change:(inout ImageEffect)->Void){self.change{layer in guard let index=layer.imageEffects?.firstIndex(where:{$0.id==id}) else{return};change(&layer.imageEffects![index]);layer.imageEffects![index]=layer.imageEffects![index].sanitized}}
    func removeImageEffect(_ id:UUID){checkpoint();change{$0.imageEffects?.removeAll{$0.id==id}}}
    func moveImageEffect(_ id:UUID,by delta:Int){guard let values=active?.imageEffects,let index=values.firstIndex(where:{$0.id==id}),values.indices.contains(index+delta) else{return};checkpoint();change{$0.imageEffects?.swapAt(index,index+delta)}}
    func clearImageEffects(){guard !(active?.imageEffects ?? []).isEmpty else{return};checkpoint();change{$0.imageEffects=[]}}
}
