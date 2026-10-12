import UIKit

/// A text/style edit invalidates its old and new visual extents, not every tile
/// of a long chapter. Reordering remains a full repaint to preserve blend order.
enum LayerInvalidation {
    static func dirtyRect(before:[EditorLayer],after:[EditorLayer])->CGRect? {
        guard before.map(\.id)==after.map(\.id) else{return nil}
        var rect=CGRect.null
        for (old,new) in zip(before,after) where old != new {
            for item in [old,new] where item.isVisible {
                let local=item.kind == .text ? TextVisualBounds.rect(item):LayerRenderer.bounds(item).insetBy(dx:-max(2,item.style.strokeWidth),dy:-max(2,item.style.strokeWidth))
                rect=rect.union(local.applying(LayerRenderer.transform(item)))
            }
        }
        return rect.isNull ? .zero:rect.integral.insetBy(dx:-2,dy:-2)
    }
}
