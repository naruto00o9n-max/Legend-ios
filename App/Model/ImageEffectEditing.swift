import Foundation

extension EditorModel {
    func openImageEffects() async {
        guard !busy else{return}
        if let active,active.kind == .image {guard !active.isLocked else{return};imageEffectsOpen=true;return}
        if let existing=page.layers.first(where:{$0.isWorkingImage==true && $0.isVisible}){guard !existing.isLocked else{error="افتح قفل طبقة صورة العمل لتعديل التأثيرات";return};selected=existing.id;tool = .move;imageEffectsOpen=true;return}
        guard page.baseHidden != true else{error="اختر طبقة الصورة التي تريد تعديل تأثيراتها";return}
        let sourceObjects=page.layers.filter{$0.stackID==page.id}
        guard !sourceObjects.contains(where:{$0.isLocked || !$0.isVisible}) else{error="أظهر طبقة الصورة الأصلية وافتح قفلها أولًا";return}
        // Promote the existing source layer by reference. Opening effects does
        // not duplicate its file or create a separate user-visible layer.
        var layer=EditorLayer(kind:.image,name:"الصورة الأصلية");layer.imagePath=page.source;layer.isWorkingImage=true
        layer.stackID=page.id;layer.stackName=sourceObjects.first?.stackName ?? "الصورة الأصلية"
        layer.imagePixelFile=page.raw;layer.imagePixelWidth=page.width;layer.imagePixelHeight=page.height
        layer.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))
        checkpoint();page.layers.insert(layer,at:0);page.baseHidden=true;selected=layer.id;tool = .move;save();imageEffectsOpen=true
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
