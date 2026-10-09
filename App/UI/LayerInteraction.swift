import UIKit

/// Temporary normal-blend sprites preserve layer order while UIKit transforms
/// them on the compositor. The committed/exported scene still uses LayerRenderer.
final class LayerInteraction {
    enum Phase { case preparing, active, finishing }
    private final class Sprite {
        let view = UIImageView()
        var signature: EditorLayer
        var rect: CGRect
        let viewport:CGRect?
        init(layer: EditorLayer, directory: URL,viewport:CGRect?=nil) {
            self.viewport=viewport
            signature = Self.signature(layer); rect = viewport ?? Self.rect(layer)
            view.isUserInteractionEnabled = false; view.isHidden = true
            view.layer.magnificationFilter = .nearest
            view.image = Self.raster(signature, rect: rect, directory: directory)
            updateTransform(layer)
        }
        static func signature(_ layer: EditorLayer) -> EditorLayer {
            var value = layer
            value.frame.x = 0; value.frame.y = 0; value.rotation = 0
            value.scaleX = 1; value.scaleY = 1; value.opacity = 1
            value.isLocked = false; value.isVisible = true
            return value
        }
        static func rect(_ layer: EditorLayer) -> CGRect {
            if layer.kind == .text{return TextVisualBounds.rect(layer)}
            return LayerRenderer.bounds(layer).insetBy(dx:-max(2,layer.style.strokeWidth),dy:-max(2,layer.style.strokeWidth)).integral
        }

        static func raster(_ layer: EditorLayer, rect: CGRect, directory: URL) -> UIImage {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            format.opaque = false; format.preferredRange = .standard
            return UIGraphicsImageRenderer(size: rect.size, format: format).image { output in
                output.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
                LayerRenderer.draw([layer], in: output.cgContext, directory: directory)
            }
        }
        func update(_ layer: EditorLayer, directory: URL) -> Bool {
            let next = Self.signature(layer), nextRect = viewport ?? Self.rect(layer)
            let changed = next != signature || nextRect != rect
            if changed { signature = next; rect = nextRect; view.image = Self.raster(next, rect: rect, directory: directory) }
            updateTransform(layer); return changed
        }
        private func updateTransform(_ layer: EditorLayer) {
            let transform = LayerRenderer.transform(layer)
            view.bounds = CGRect(origin: .zero, size: rect.size)
            view.center = CGPoint(x: rect.midX, y: rect.midY).applying(transform)
            view.transform = CGAffineTransform(a: transform.a, b: transform.b, c: transform.c, d: transform.d, tx: 0, ty: 0)
            view.alpha = CGFloat(layer.opacity)
        }
    }
    let selected: UUID
    let excluded: Set<UUID>
    private let directory: URL
    private var sprites: [UUID: Sprite] = [:]
    private let order: [UUID]
    var phase = Phase.preparing
    private(set) var rasterizations = 0
    init?(page: EditorPage, selected: UUID, directory: URL,drawingViewport:CGRect?=nil) {
        guard let selectedIndex=page.layers.firstIndex(where:{$0.id==selected}) else{return nil}
        let group=page.layers[selectedIndex].groupID
        let index=group.flatMap{id in page.layers.firstIndex(where:{$0.groupID==id})} ?? selectedIndex
        let foreground = Array(page.layers[index...]).filter(\.isVisible)
        // Complex blend/drawing stacks retain the software compositor; never
        // silently change their blend or place a selected layer above its peers.
        guard !foreground.isEmpty, foreground.allSatisfy({ $0.blend == .normal && ($0.kind != .drawing || drawingViewport != nil) }) else { return nil }
        func spriteRect(_ layer:EditorLayer)->CGRect{if layer.kind == .drawing,let drawingViewport{return drawingViewport.applying(LayerRenderer.transform(layer).inverted()).integral.intersection(LayerRenderer.bounds(layer))};return Sprite.rect(layer)}
        let areas = foreground.map { spriteRect($0).width * spriteRect($0).height }
        guard areas.allSatisfy({ $0 > 0 && $0 <= 4_194_304 }), areas.reduce(0, +) <= 8_388_608 else { return nil }
        self.selected = selected; self.directory = directory
        self.order = foreground.map(\.id); self.excluded = Set(order)
        for layer in foreground { sprites[layer.id] = Sprite(layer: layer, directory: directory,viewport:layer.kind == .drawing ? spriteRect(layer):nil); rasterizations += 1 }
    }
    func attach(to canvas: UIView) { for id in order { if let sprite = sprites[id] { canvas.addSubview(sprite.view) } } }
    func update(_ page: EditorPage) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for item in page.layers { if sprites[item.id]?.update(item, directory: directory) == true { rasterizations += 1 } }
        CATransaction.commit()
    }
    func bringForward(in canvas: UIView) { for id in order { if let sprite = sprites[id] { canvas.bringSubviewToFront(sprite.view) } } }
    func reveal() { sprites.values.forEach { $0.view.isHidden = false }; phase = .active }
    func remove() { sprites.values.forEach { $0.view.removeFromSuperview() } }
    var center: CGPoint? { sprites[selected]?.view.center }
}
