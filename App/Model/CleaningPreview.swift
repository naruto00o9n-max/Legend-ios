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
    var canvasPage:EditorPage{
        var value=page
        if let selected=cleanPreviewID,let preview=cleanCandidates.first(where:{$0.id==selected}){
            if preview.underlays{value.layers.insert(contentsOf:preview.allLayers,at:0)}else{value.layers.append(contentsOf:preview.allLayers)}
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
        if preview.underlays{next.layers.insert(contentsOf:preview.allLayers,at:0)}else{next.layers.append(contentsOf:preview.allLayers)}
        next.modified=Date()
        do{try library.persist(next)}catch{self.error=error.localizedDescription;return}
        checkpoint();page=next;self.selected=preview.layer.id
        for item in cleanCandidates where item.id != selected{for layer in item.allLayers{try? FileManager.default.removeItem(at:directory.appendingPathComponent(layer.imagePath))}}
        if preview.underlays{sniperTargets=[];sniperMode=false}
        cleanCandidates=[];cleanPreviewID=nil;save()
    }
    func whitenSniperTargets()async {
        guard !busy,!sniperTargets.isEmpty else{return}
        let targets=sniperTargets,snapshot=page,directory=self.directory
        guard targets.count<=40 else{error="عالِج حتى 40 فقاعة في المرة الواحدة لتقليل استهلاك الذاكرة";return}
        guard snapshot.baseHidden != true else{error="أظهر الصورة الأصلية قبل تبييض نصها";return}
        busy=true;defer{busy=false};discardCleaning();let generation=cleaningGeneration
        do{
            let candidate=try await BackgroundWork.run{()->CleaningCandidate in
                var results:[BubbleWhiteningResult]=[],skipped=0
                do{
                    for target in targets{
                        try Task.checkCancellation()
                        do{results.append(try autoreleasepool{try BubbleWhitening.prepare(page:snapshot,directory:directory,target:target)})}catch{skipped+=1}
                    }
                    guard let first=results.first else{throw ImageFailure.message("تعذر فصل نص الفقاعات المحددة بأمان. أعد تحديد داخل الفقاعة أو استخدم فرشاة التنظيف.")}
                    let review=results.filter(\.reviewRequired).count
                    var detail="أزيل النص المكتشف داخل \(results.count) فقاعة. الصورة الأصلية محفوظة، والحدود خارج القناع لم تُعدّل."
                    if skipped>0{detail += " تُركت \(skipped) فقاعة دون تعديل لعدم وضوح النص أو المحيط."}
                    if review>0{detail += " راجع \(review) فقاعة: استُخدم ترميم أو تحليل دون تعرف مؤكد على النص."}
                    return CleaningCandidate(title:"تبييض \(results.count) فقاعات",layer:first.layer,additionalLayers:results.dropFirst().map(\.layer),underlays:true,detail:detail,baseline:snapshot)
                }catch{for result in results{try? FileManager.default.removeItem(at:directory.appendingPathComponent(result.layer.imagePath))};throw error}
            }
            guard page==snapshot,cleaningGeneration==generation else{for layer in candidate.allLayers{try? FileManager.default.removeItem(at:directory.appendingPathComponent(layer.imagePath))};return}
            cleanCandidates=[candidate];cleanPreviewID=candidate.id
        }catch{self.error=error.localizedDescription}
    }
}
