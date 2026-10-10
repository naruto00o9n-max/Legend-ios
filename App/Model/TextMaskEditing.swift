import Foundation

struct TextMaskDraft {
    var page:EditorPage
    var undo:[[EditorLayer]]
    var redo:[[EditorLayer]]
    var undoDocuments:[EditorPage]
    var redoDocuments:[EditorPage]
}
extension EditorModel {
    func beginTextMask(){
        guard active?.kind == .text,active?.isLocked==false,textMaskDraft==nil else{return}
        textMaskDraft=TextMaskDraft(page:page,undo:undoStack,redo:redoStack,undoDocuments:undoDocuments,redoDocuments:redoDocuments)
        undoStack=[];redoStack=[];undoDocuments=[];redoDocuments=[]
        textMaskMode=true
    }
    func commitTextMask(){
        guard let draft=textMaskDraft else{textMaskMode=false;return}
        textMaskDraft=nil;textMaskMode=false
        undoStack=draft.undo;redoStack=draft.redo;undoDocuments=draft.undoDocuments;redoDocuments=draft.redoDocuments
        if page != draft.page{undoStack.append(draft.page.layers);undoDocuments.append(draft.page);if undoStack.count>60{undoStack.removeFirst();undoDocuments.removeFirst()};redoStack=[];redoDocuments=[]}
        save()
    }
    func cancelTextMask(){
        guard let draft=textMaskDraft else{textMaskMode=false;return}
        textMaskDraft=nil;textMaskMode=false;page=draft.page
        undoStack=draft.undo;redoStack=draft.redo;undoDocuments=draft.undoDocuments;redoDocuments=draft.redoDocuments
        save()
    }
}
