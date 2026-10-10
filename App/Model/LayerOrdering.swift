import SwiftUI

extension EditorModel {
    func reorderLayers(kind:LayerKind?,from source:IndexSet,to destination:Int){
        var ordered=Array(page.layers.reversed());let positions=ordered.indices.filter{kind==nil || ordered[$0].kind==kind}
        guard destination>=0,destination<=positions.count,source.allSatisfy({$0>=0 && $0<positions.count}) else{return}
        var visible=positions.map{ordered[$0]};visible.move(fromOffsets:source,toOffset:destination)
        for (index,position) in positions.enumerated(){ordered[position]=visible[index]}
        checkpoint();page.layers=Array(ordered.reversed());save()
    }
}
