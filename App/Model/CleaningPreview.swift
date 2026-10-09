import UIKit

struct CleaningCandidate:Identifiable {var id=UUID();var title:String;var layer:EditorLayer}
extension EditorModel {
    var canvasPage:EditorPage{var value=page;if let selected=cleanPreviewID,let preview=cleanCandidates.first(where:{$0.id==selected}){value.layers.append(preview.layer)};return value}
    func discardCleaning(){cleaningGeneration=UUID();for item in cleanCandidates{try? FileManager.default.removeItem(at:directory.appendingPathComponent(item.layer.imagePath))};cleanCandidates=[];cleanPreviewID=nil}
    func acceptCleaning(){guard let selected=cleanPreviewID,let preview=cleanCandidates.first(where:{$0.id==selected}) else{return};checkpoint();page.layers.append(preview.layer);self.selected=preview.layer.id;for item in cleanCandidates where item.id != selected{try? FileManager.default.removeItem(at:directory.appendingPathComponent(item.layer.imagePath))};cleanCandidates=[];cleanPreviewID=nil;save()}
}
