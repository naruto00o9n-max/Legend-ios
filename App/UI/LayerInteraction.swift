import UIKit

/// Temporary normal-blend sprites preserve layer order while UIKit transforms
/// them on the compositor. The committed/exported scene still uses LayerRenderer.
final class LayerInteraction {
    enum Phase { case preparing, active, finishing }
    private final class Sprite {
        let view = UIImageView()
        var signature: EditorLayer
        var rect: CGRect
        init(layer: EditorLayer, directory: URL) {
            signature = Self.signature(layer); rect = Self.rect(layer)
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
            let style = layer.style
            let padding = layer.kind == .text ? max(16, style.strokeWidth + style.shadowRadius * 3 + max(abs(style.shadowDx),abs(style.shadowDy)) + style.effectValue * 3 + Double(style.threeDDepth) + max(style.backgroundPaddingX, style.backgroundPaddingY)) : max(2, style.strokeWidth)
            return LayerRenderer.bounds(layer).insetBy(dx: -padding, dy: -padding).integral
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
            let next = Self.signature(layer), nextRect = Self.rect(layer)
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
    init?(page: EditorPage, selected: UUID, directory: URL) {
        guard let index = page.layers.firstIndex(where: { $0.id == selected }) else { return nil }
        let foreground = Array(page.layers[index...]).filter(\.isVisible)
        // Complex blend/drawing stacks retain the software compositor; never
        // silently change their blend or place a selected layer above its peers.
        guard !foreground.isEmpty, foreground.allSatisfy({ $0.blend == .normal && $0.kind != .drawing }) else { return nil }
        let areas = foreground.map { Sprite.rect($0).width * Sprite.rect($0).height }
        guard areas.allSatisfy({ $0 > 0 && $0 <= 4_194_304 }), areas.reduce(0, +) <= 8_388_608 else { return nil }
        self.selected = selected; self.directory = directory
        self.order = foreground.map(\.id); self.excluded = Set(order)
        for layer in foreground { sprites[layer.id] = Sprite(layer: layer, directory: directory); rasterizations += 1 }
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
