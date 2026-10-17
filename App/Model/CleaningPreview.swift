import UIKit

struct CleaningCandidate:Identifiable {
    var id=UUID();var title:String;var layer:EditorLayer
    var additionalLayers:[EditorLayer]=[]
    var underlays=false
    var detail=""
    var baseline:EditorPage?
    var allLayers:[EditorLayer]{[layer]+additionalLayers}
}
extension EditorModel {
    /// A cleaning patch is content of the active layer. Keep the preview and
    /// committed order identical: above its raster background, below its text.
    private func insertCleaning(_ preview:CleaningCandidate,into value:inout EditorPage){
        let id=currentLayerID ?? value.id
        let title=currentLayerTitle
        let objects=preview.allLayers.map{item -> EditorLayer in var copy=item;copy.stackID=id;copy.stackName=title;return copy}
        let members=value.layers.indices.filter{(value.layers[$0].stackID ?? value.layers[$0].id)==id}
        let position:Int
        if preview.underlays{position=members.first(where:{value.layers[$0].kind == .text}) ?? members.last.map{$0+1} ?? value.layers.count}
        else{position=members.last.map{$0+1} ?? value.layers.count}
        value.layers.insert(contentsOf:objects,at:position)
    }

    var canvasPage:EditorPage{
        var value=page
        if let selected=cleanPreviewID,let preview=cleanCandidates.first(where:{$0.id==selected}){
            insertCleaning(preview,into:&value)
        }
        return value
    }
    func discardCleaning(){
        cleaningGeneration=UUID()
        for item in cleanCandidates{for layer in item.allLayers{try? FileManager.default.removeItem(at:directory.appendingPathComponent(layer.imagePath))}}
        cleanCandidates=[];cleanPreviewID=nil
    }
    func acceptCleaning(){
        guard let selected=cleanPreviewID,let preview=cleanCandidates.first(where:{$0.id==selected}) else{return}
        if let baseline=preview.baseline,baseline != page{error="تغيرت الصفحة منذ المعاينة؛ أعد التبييض على حالتها الحالية";return}
        var next=page
        insertCleaning(preview,into:&next)
        next.modified=Date()
        do{try library.persist(next)}catch{self.error=error.localizedDescription;return}
        checkpoint();page=next;self.selected=preview.layer.id
        for item in cleanCandidates where item.id != selected{for layer in item.allLayers{try? FileManager.default.removeItem(at:directory.appendingPathComponent(layer.imagePath))}}
        if preview.underlays{sniperTargets=[];sniperMode=false;focusedSniperTarget=nil;manualSniperTool=nil}
        cleanCandidates=[];cleanPreviewID=nil;save()
    }
    func whitenSniperTargets()async {
        guard !busy,!sniperTargets.isEmpty else{return}
        let targets=sniperTargets,snapshot=page,directory=self.directory
        guard targets.count<=40 else{error="عالِج حتى 40 فقاعة في المرة الواحدة لتقليل استهلاك الذاكرة";return}
        guard snapshot.baseHidden != true || snapshot.layers.contains(where:{$0.isWorkingImage==true && $0.isVisible}) else{error="أظهر الصورة الأصلية قبل تبييض نصها";return}
        let needsModel=targets.contains{$0.whiteningMethod == .bigLaMa && $0.restorationExecution == .device}
        var compiled:URL?
        do{if needsModel{compiled=try BigLaMaAssets.shared.acquire()}}catch{self.error=error.localizedDescription;return}
        busy=true;defer{busy=false;whiteningTask=nil;if needsModel{BigLaMaAssets.shared.release()}};discardCleaning();let generation=cleaningGeneration
        do{
            let task=Task.detached(priority:.userInitiated){()async throws->CleaningCandidate in
                var engine:BigLaMaSession?
                func session()throws->BigLaMaSession{if let engine{return engine};guard let compiled else{throw ImageFailure.message("نموذج الترميم غير متوفر")};let value=try BigLaMaSession(compiled:compiled);engine=value;return value}
                var results:[BubbleWhiteningResult]=[],skipped=0,firstFailure:String?
                do{
                    for target in targets{
                        try Task.checkCancellation()
                        do{
                            if target.whiteningMethod == .bigLaMa && target.restorationExecution == .cloud{results.append(try await BubbleWhitening.prepareCloud(page:snapshot,directory:directory,target:target))}
                            else{results.append(try autoreleasepool{target.whiteningMethod == .classic ? try BubbleWhitening.prepare(page:snapshot,directory:directory,target:target):try BubbleWhitening.prepareBigLaMa(page:snapshot,directory:directory,target:target,session:session)})}
                        }catch is CancellationError{throw CancellationError()}catch{skipped+=1;if firstFailure==nil{firstFailure=error.localizedDescription}}
                    }
                    try Task.checkCancellation()
                    guard let first=results.first else{throw ImageFailure.message(firstFailure ?? "تعذر فصل نص الفقاعات المحددة بأمان. أعد تحديد داخل الفقاعة أو استخدم فرشاة التنظيف.")}
                    let review=results.filter(\.reviewRequired).count
                    var detail="أزيل النص المكتشف داخل \(results.count) فقاعة. الصورة الأصلية محفوظة، والحدود خارج القناع لم تُعدّل."
                    if skipped>0{detail += " تُركت \(skipped) فقاعة دون تعديل.";if let firstFailure{detail += " "+firstFailure}}
                    if review>0{detail += " راجع \(review) فقاعة: استُخدم ترميم أو تحليل دون تعرف مؤكد على النص."}
                    var layer=first.layer
                    if results.count>1{
                        layer=try LayerBitmap.merge(results.map(\.layer),page:snapshot,directory:directory)
                        for result in results{try? FileManager.default.removeItem(at:directory.appendingPathComponent(result.layer.imagePath))}
                    }
                    layer.name="تبييض \(results.count) فقاعات"
                    return CleaningCandidate(title:layer.name,layer:layer,underlays:true,detail:detail,baseline:snapshot)
                }catch{for result in results{try? FileManager.default.removeItem(at:directory.appendingPathComponent(result.layer.imagePath))};throw error}
            }
            whiteningTask=task
            let candidate=try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})
            guard page==snapshot,cleaningGeneration==generation,!Task.isCancelled else{for layer in candidate.allLayers{try? FileManager.default.removeItem(at:directory.appendingPathComponent(layer.imagePath))};return}
            cleanCandidates=[candidate];cleanPreviewID=candidate.id
        }catch is CancellationError{}catch{self.error=error.localizedDescription}
    }
}
