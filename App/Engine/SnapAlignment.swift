import UIKit

enum SnapAlignment {
    static func apply(_ layer:inout EditorLayer,page:EditorPage,tolerance:Double){
        let box=LayerRenderer.bounds(layer).applying(LayerRenderer.transform(layer))
        var xs=[0.0,Double(page.width)/2,Double(page.width)],ys=[0.0,Double(page.height)/2,Double(page.height)]
        for other in page.layers where other.id != layer.id && other.isVisible && (layer.groupID==nil || other.groupID != layer.groupID){
            let b=LayerRenderer.bounds(other).applying(LayerRenderer.transform(other));xs += [Double(b.minX),Double(b.midX),Double(b.maxX)];ys += [Double(b.minY),Double(b.midY),Double(b.maxY)]
        }
        func shift(_ anchors:[Double],_ edges:[Double])->Double{anchors.flatMap{a in edges.map{a-$0}}.filter{abs($0)<=tolerance}.min{abs($0)<abs($1)} ?? 0}
        layer.frame.x+=shift(xs,[Double(box.minX),Double(box.midX),Double(box.maxX)])
        layer.frame.y+=shift(ys,[Double(box.minY),Double(box.midY),Double(box.maxY)])
    }
}
