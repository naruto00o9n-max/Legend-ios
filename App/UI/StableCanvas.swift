import UIKit

/// Persistent image tiles: scrolling never invalidates source pixels or empties a tile.
/// A small full-document preview remains behind them while a new detail level loads.
final class DocumentCanvas: UIView {
    private final class Tile {
        let view = UIImageView()
        var revision = -1
        var pending = false
        let rect: CGRect
        let sample: Int
        init(rect: CGRect, sample: Int) {
            self.rect = rect; self.sample = sample
            view.frame = rect; view.layer.magnificationFilter = .nearest
            view.layer.minificationFilter = .linear
            view.isUserInteractionEnabled = false
        }
    }
    private let worker = DispatchQueue(label: "cookies.canvas.tiles", qos: .userInitiated)
    private let sourceCache = NSCache<NSString, UIImage>()
    private var tiles: [String: Tile] = [:]
    private let preview = UIImageView()
    private let border = CAShapeLayer()
    private let stem = CAShapeLayer()
    private let liveInk = CAShapeLayer()
    private let sniperOverlay=CALayer()
    private var sniperTargets:[SniperTarget]=[]
    private var sniperZoom:CGFloat=0
    private var pendingInk: [(revision: Int, layer: CAShapeLayer)] = []
    private var strokeCommitRevision: Int?
    private var stagedImages: [String: UIImage] = [:]
    private var interaction: LayerInteraction?
    private var interactionRevision: Int?
    private var renderedLayers: [EditorLayer] = []
    private var handles: [String: UIButton] = [:]
    private var currentKeys = Set<String>()
    private var visible = CGRect.zero
    private var sourceIdentity = ""
    private(set) var revision = 0
    private(set) var sourceReads = 0
    var page: EditorPage?
    var directory: URL?
    var selected: UUID?
    var zoom: CGFloat = 1
    var onHandle: ((String) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false; backgroundColor = .clear; clipsToBounds = false
        preview.frame = bounds; preview.isUserInteractionEnabled = false
        preview.layer.magnificationFilter = .nearest; addSubview(preview)
        sourceCache.totalCostLimit = 48 * 1024 * 1024
        liveInk.lineCap = .round; liveInk.lineJoin = .round
        liveInk.fillColor = UIColor.clear.cgColor; layer.addSublayer(liveInk)
        layer.addSublayer(sniperOverlay)
        for shape in [border, stem] { shape.fillColor = UIColor.clear.cgColor; shape.strokeColor = UIColor.white.cgColor; layer.addSublayer(shape) }
        for (name, icon) in [("delete","xmark"),("duplicate","plus.square.on.square"),("edit","pencil"),("resize","arrow.up.left.and.arrow.down.right"),("rotate","arrow.clockwise"),("scale-x","arrow.left.and.right"),("scale-y","arrow.up.and.down"),("box-width","rectangle"),("styles","square.grid.2x2")] {
            let button = UIButton(type: .custom)
            button.setImage(UIImage(systemName: icon), for: .normal)
            button.tintColor = .white; button.backgroundColor = UIColor(white: 0.06, alpha: 0.94)
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.48).cgColor
            button.addAction(UIAction { [weak self] _ in self?.onHandle?(name) }, for: .touchUpInside)
            button.accessibilityIdentifier = "selection-" + name
            button.accessibilityLabel = ["delete":"حذف الطبقة","duplicate":"نسخ الطبقة","edit":"تعديل النص","resize":"تكبير متناسب بالسحب","rotate":"تدوير بالسحب","scale-x":"تمديد أفقي بالسحب","scale-y":"تمديد عمودي بالسحب","box-width":"عرض مربع النص بالسحب","styles":"أنماط النص"][name]
            addSubview(button); handles[name] = button
        }
        accessibilityIdentifier = "document-canvas"
        accessibilityLabel = "مساحة الصورة بالأبعاد الأصلية"
    }
    required init?(coder: NSCoder) { fatalError() }
    func update(page: EditorPage, directory: URL, selected: UUID?, zoom: CGFloat) {
        let identity = directory.path + "/" + page.raw
        let sourceChanged = sourceIdentity != identity
        if sourceChanged { interaction?.remove(); interaction = nil; interactionRevision = nil }
        let renderPage = rasterPage(page)
        let pixelsChanged = sourceChanged || renderedLayers != renderPage.layers
        renderedLayers = renderPage.layers
        self.page = page; self.directory = directory; self.selected = selected; self.zoom = zoom
        if sourceChanged {
            sourceIdentity = identity; sourceCache.removeAllObjects()
            tiles.values.forEach { $0.view.removeFromSuperview() }; tiles.removeAll(); preview.image = nil
            liveInk.path = nil; strokeCommitRevision = nil; stagedImages.removeAll()
            pendingInk.forEach { $0.layer.removeFromSuperlayer() }; pendingInk.removeAll()
            interaction?.remove(); interaction = nil; interactionRevision = nil
            loadPreview(page, directory: directory, identity: identity)
        }
        if pixelsChanged { revision += 1 }
        interaction?.update(page)
        updateSelection()
        if !visible.isEmpty { refreshVisible(visible) }
    }
    func refreshVisible(_ rect: CGRect) {
        guard let fullPage = page, let directory else { return }
        let page = rasterPage(fullPage)
        visible = rect
        let imageBounds = CGRect(x: 0, y: 0, width: page.width, height: page.height)
        var sample = 1
        let resolution = max(0.0001, zoom * max(1, traitCollection.displayScale))
        while CGFloat(sample * 2) * resolution <= 1 { sample *= 2 }
        let extent = CGFloat(512 * sample)
        let area = rect.insetBy(dx: -extent * 0.5, dy: -extent * 0.5).intersection(imageBounds)
        guard !area.isNull, !area.isEmpty else { return }
        var keys = Set<String>()
        let x0 = Int(floor(area.minX / extent)), x1 = Int(ceil(area.maxX / extent))
        let y0 = Int(floor(area.minY / extent)), y1 = Int(ceil(area.maxY / extent))
        for y in y0..<y1 { for x in x0..<x1 {
            let box = CGRect(x: CGFloat(x) * extent, y: CGFloat(y) * extent, width: extent, height: extent).intersection(imageBounds)
            let key = "\(sample):\(x):\(y)"; keys.insert(key)
            let tile: Tile
            if let existing = tiles[key] { tile = existing } else {
                tile = Tile(rect: box, sample: sample); tiles[key] = tile
                insertSubview(tile.view, aboveSubview: preview)
            }
            if tile.revision != revision && !tile.pending { render(tile, key: key, page: page, directory: directory) }
        } }
        currentKeys = keys
        retireOldDetail()
        // Selection controls stay above every image tile.
        pendingInk.forEach { layer.addSublayer($0.layer) }
        interaction?.bringForward(in: self)
        layer.addSublayer(liveInk);layer.addSublayer(sniperOverlay); layer.addSublayer(border); layer.addSublayer(stem)
        handles.values.forEach { bringSubviewToFront($0) }
    }
    private func loadPreview(_ page: EditorPage, directory: URL, identity: String) {
        worker.async { [weak self] in
            var sample = 1
            while ((page.width + sample - 1) / sample) * ((page.height + sample - 1) / sample) > 1_000_000 { sample *= 2 }
            let rect = CGRect(x: 0, y: 0, width: page.width, height: page.height)
            let pixels = try? ImagePipeline.tile(directory.appendingPathComponent(page.raw), width: page.width, height: page.height, rect: rect, sample: sample)
            let cg = pixels.flatMap { ImagePipeline.image($0, width: (page.width + sample - 1) / sample, height: (page.height + sample - 1) / sample, colorSpace: ImagePipeline.colorSpace(directory.appendingPathComponent(page.source))) }
            DispatchQueue.main.async { guard let self, self.sourceIdentity == identity else { return }; self.preview.image = cg.map { UIImage(cgImage: $0) } }
        }
    }
    private func render(_ tile: Tile, key: String, page: EditorPage, directory: URL) {
        tile.pending = true
        let requested = revision, identity = sourceIdentity, cache = sourceCache
        worker.async { [weak self] in
            let base: UIImage?
            var read = false
            let cacheKey = (identity + "|" + key) as NSString
            if let cached = cache.object(forKey: cacheKey) { base = cached } else {
                read = true
                let pixels = try? ImagePipeline.tile(directory.appendingPathComponent(page.raw), width: page.width, height: page.height, rect: tile.rect, sample: tile.sample)
                let cg = pixels.flatMap { ImagePipeline.image($0, width: (Int(tile.rect.width) + tile.sample - 1) / tile.sample, height: (Int(tile.rect.height) + tile.sample - 1) / tile.sample, colorSpace: ImagePipeline.colorSpace(directory.appendingPathComponent(page.source))) }
                base = cg.map { UIImage(cgImage: $0) }
                if let base { cache.setObject(base, forKey: cacheKey, cost: Int(base.size.width * base.size.height) * 4) }
            }
            var composite = base
            if let base, !page.layers.isEmpty {
                let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false; format.preferredRange = .standard
                composite = UIGraphicsImageRenderer(size: base.size, format: format).image { output in
                    base.draw(in: CGRect(origin: .zero, size: base.size))
                    let context = output.cgContext
                    context.scaleBy(x: base.size.width / tile.rect.width, y: base.size.height / tile.rect.height)
                    context.translateBy(x: -tile.rect.minX, y: -tile.rect.minY)
                    LayerRenderer.draw(page.layers, in: context, directory: directory)
                }
            }
            DispatchQueue.main.async {
                guard let self, self.sourceIdentity == identity, self.tiles[key] === tile else { return }
                tile.pending = false
                if read { self.sourceReads += 1 }
                if requested == self.revision {
                    // Keep the previous contents until its replacement is complete.
                    if let composite {
                        if let commit = [self.strokeCommitRevision, self.interactionRevision].compactMap({ $0 }).min(), requested >= commit { self.stagedImages[key] = composite }
                        else { tile.view.image = composite }
                    }; tile.revision = requested
                }
                if tile.revision != self.revision, let latest = self.page, let directory = self.directory {
                    self.render(tile, key: key, page: self.rasterPage(latest), directory: directory)
                } else { self.retireOldDetail() }
            }
        }
    }
    private func retireOldDetail() {
        guard !currentKeys.isEmpty, currentKeys.allSatisfy({ tiles[$0]?.revision == revision }) else { return }
        if let commit = [strokeCommitRevision, interactionRevision].compactMap({ $0 }).min(), revision >= commit {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for (key, image) in stagedImages { tiles[key]?.view.image = image }
            stagedImages.removeAll()
            pendingInk.removeAll { item in if item.revision <= revision { item.layer.removeFromSuperlayer(); return true }; return false }
            strokeCommitRevision = pendingInk.map(\.revision).min()
            if let target = interactionRevision, revision >= target {
                if interaction?.phase == .preparing { interaction?.reveal() }
                else if interaction?.phase == .finishing { interaction?.remove(); interaction = nil }
                interactionRevision = nil
            }
            CATransaction.commit()
        }
        for key in Array(tiles.keys) where !currentKeys.contains(key) { tiles.removeValue(forKey: key)?.view.removeFromSuperview() }
    }
    func updateSelection() {
        renderSniper()
        guard let item = page?.layers.first(where: { $0.id == selected && $0.isVisible }), item.kind != .drawing else {
            border.path = nil; stem.path = nil; handles.values.forEach { $0.isHidden = true }; return
        }
        let box = LayerRenderer.bounds(item), transform = LayerRenderer.transform(item), size = 32 / max(0.002, zoom)
        let path = UIBezierPath(rect: box); path.apply(transform)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        border.path = path.cgPath; border.lineWidth = 1 / max(0.002, zoom); border.lineDashPattern = [5 / max(0.002, zoom), 3 / max(0.002, zoom)].map { NSNumber(value: Double($0)) }
        // Reference 4.5: delete / vertical scale / rotate across the top,
        // horizontal scale and box width at the sides; text actions below.
        let padding = 32 / max(0.002, zoom)
        let controls = box.insetBy(dx: -padding / max(0.05, CGFloat(abs(item.scaleX))), dy: -padding / max(0.05, CGFloat(abs(item.scaleY))))
        let positions: [String: CGPoint] = [
            "delete": CGPoint(x: controls.minX, y: controls.minY),
            "scale-y": CGPoint(x: controls.midX, y: controls.minY),
            "rotate": CGPoint(x: controls.maxX, y: controls.minY),
            "scale-x": CGPoint(x: controls.minX, y: controls.midY),
            "box-width": CGPoint(x: controls.maxX, y: controls.midY),
            "edit": CGPoint(x: controls.minX, y: controls.maxY),
            "duplicate": CGPoint(x: item.kind == .text ? controls.minX + controls.width * 0.35 : controls.minX, y: controls.maxY),
            "styles": CGPoint(x: controls.minX + controls.width * 0.7, y: controls.maxY),
            "resize": CGPoint(x: controls.maxX, y: controls.maxY)
        ]
        for (name, point) in positions { place(name, at: point.applying(transform), size: size) }
        stem.path = nil
        handles["edit"]?.isHidden = item.kind != .text
        handles["styles"]?.isHidden = item.kind != .text
        handles["box-width"]?.isHidden = item.kind != .text
        CATransaction.commit()
    }
    private func place(_ name: String, at point: CGPoint, size: CGFloat) {
        guard let button = handles[name] else { return }
        button.tintColor = .white
        button.isHidden = false; button.bounds = CGRect(x: 0, y: 0, width: 32, height: 32)
        button.center = point; button.transform = CGAffineTransform(scaleX: size / 32, y: size / 32)
        button.layer.cornerRadius = 16; button.layer.borderWidth = 0.8
        button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .medium), forImageIn: .normal)
    }
    func handle(at point: CGPoint) -> String? {
        handles.first { !$0.value.isHidden && hypot($0.value.center.x - point.x, $0.value.center.y - point.y) < 24 / max(0.002, zoom) }?.key
    }
    func showStroke(_ stroke: Stroke?, on page: EditorPage, selected: UUID?) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let stroke, let first = stroke.points.first else {
            liveInk.path = nil; return
        }
        let path = UIBezierPath(); path.move(to: first.cg)
        for point in stroke.points.dropFirst() { path.addLine(to: point.cg) }
        let item = page.layers.first { $0.id == selected }
        liveInk.setAffineTransform(item.map { LayerRenderer.transform($0) } ?? .identity)
        liveInk.lineWidth = CGFloat(stroke.width)
        liveInk.strokeColor = UIColor(hex: stroke.erase ? "FFFFFF" : stroke.color).cgColor
        liveInk.opacity = Float((item?.opacity ?? 1) * (stroke.erase ? 0.35 : (stroke.brush == "water" ? 0.25 : 1)))
        liveInk.lineDashPattern = stroke.erase ? [4, 4] : nil
        liveInk.shadowColor = UIColor(hex: stroke.color).cgColor
        liveInk.shadowOpacity = stroke.brush == "neon" ? 1 : 0
        liveInk.shadowRadius = stroke.brush == "neon" ? CGFloat(stroke.width) : 0
        liveInk.shadowOffset = .zero; liveInk.path = path.cgPath
        pendingInk.forEach { layer.addSublayer($0.layer) }
        layer.addSublayer(liveInk); layer.addSublayer(border); layer.addSublayer(stem)
        handles.values.forEach { bringSubviewToFront($0) }
    }
    func commitLiveStroke() {
        let committed = CAShapeLayer(layer: liveInk), target = revision + 1
        layer.addSublayer(committed); pendingInk.append((target, committed)); liveInk.path = nil
        strokeCommitRevision = pendingInk.map(\.revision).min()
    }
    var liveStrokeVisible: Bool { liveInk.path != nil || !pendingInk.isEmpty }
    private func rasterPage(_ page: EditorPage) -> EditorPage {
        guard let interaction, interaction.phase != .finishing else { return page }
        var result = page; result.layers.removeAll { interaction.excluded.contains($0.id) }; return result
    }
    @discardableResult func beginLayerInteraction(_ id: UUID) -> Bool {
        guard let page, let directory, interaction == nil,
              let preview = LayerInteraction(page: page, selected: id, directory: directory) else { return false }
        interaction = preview; preview.attach(to: self); interactionRevision = revision + 1
        update(page: page, directory: directory, selected: selected, zoom: zoom)
        return true
    }
    func endLayerInteraction() {
        guard let interaction, let page, let directory else { return }
        interaction.phase = .finishing; interactionRevision = revision + 1
        update(page: page, directory: directory, selected: selected, zoom: zoom)
    }
    var interactionRasterizations: Int { interaction?.rasterizations ?? 0 }
    var interactiveLayerCenter: CGPoint? { interaction?.center }
    func showSniper(_ targets:[SniperTarget]) {
        guard targets != sniperTargets || sniperZoom != zoom else{return}
        sniperTargets=targets;sniperZoom=0;renderSniper()
    }
    private func renderSniper() {
        guard sniperZoom != zoom else{return};sniperZoom=zoom
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        sniperOverlay.sublayers?.forEach{$0.removeFromSuperlayer()}
        let unit=1/max(0.002,zoom)
        for (index,target) in sniperTargets.enumerated() {
            let path=UIBezierPath()
            if let first=target.outline.first{path.move(to:first.cg);for p in target.outline.dropFirst(){path.addLine(to:p.cg)};path.close()}
            else{path.append(UIBezierPath(ovalIn:CGRect(x:target.point.x-16*unit,y:target.point.y-16*unit,width:32*unit,height:32*unit)))}
            let outline=CAShapeLayer();outline.path=path.cgPath;outline.fillColor=UIColor.clear.cgColor;outline.strokeColor=UIColor(hex:"D4AF37").cgColor;outline.lineWidth=1.5*unit;sniperOverlay.addSublayer(outline)
            let label=CATextLayer();label.string="\(index+1)";label.fontSize=12*unit;label.alignmentMode = .center;label.contentsScale=traitCollection.displayScale;label.foregroundColor=UIColor.white.cgColor;label.backgroundColor=UIColor.black.withAlphaComponent(0.8).cgColor;label.cornerRadius=10*unit
            label.frame=CGRect(x:target.point.x-12*unit,y:target.point.y-12*unit,width:24*unit,height:24*unit);sniperOverlay.addSublayer(label)
        }
    }
}
