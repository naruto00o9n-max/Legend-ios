import UIKit

/// Two vector paths in viewport coordinates. No full-image grid bitmap,
/// source invalidation, export layer, or offscreen shadow rasterization.
final class CanvasGridOverlay {
    private let contrast=CAShapeLayer(),ink=CAShapeLayer()
    private weak var viewport:UIScrollView?
    private var lastSettings:CanvasGridSettings?
    private var lastArea:CGRect = .null
    private var lastBounds:CGRect = .null
    private var lastZoom:CGFloat=0
    private(set) var visibleLineCount=0
    func update(settings:CanvasGridSettings,canvas:UIView,viewport:UIScrollView){
        if self.viewport !== viewport{contrast.removeFromSuperlayer();ink.removeFromSuperlayer();self.viewport=viewport;viewport.layer.addSublayer(contrast);viewport.layer.addSublayer(ink);contrast.fillColor=nil;ink.fillColor=nil;contrast.contentsScale=viewport.traitCollection.displayScale;ink.contentsScale=viewport.traitCollection.displayScale;lastSettings=nil}
        let settings=settings.normalized,area=canvas.convert(viewport.bounds,from:viewport)
        guard settings != lastSettings || area != lastArea || viewport.bounds != lastBounds || viewport.zoomScale != lastZoom else{return}
        lastSettings=settings;lastArea=area;lastBounds=viewport.bounds;lastZoom=viewport.zoomScale
        let lines=CanvasGridGeometry.lines(settings:settings,image:canvas.bounds,visible:area,zoom:viewport.zoomScale),path=CGMutablePath();visibleLineCount=lines.count
        for line in lines{let a=canvas.convert(line.start,to:viewport),b=canvas.convert(line.end,to:viewport);path.move(to:CGPoint(x:a.x-viewport.bounds.minX,y:a.y-viewport.bounds.minY));path.addLine(to:CGPoint(x:b.x-viewport.bounds.minX,y:b.y-viewport.bounds.minY))}
        CATransaction.begin();CATransaction.setDisableActions(true)
        for layer in [contrast,ink]{layer.frame=viewport.bounds;layer.path=path;layer.isHidden=lines.isEmpty}
        contrast.strokeColor=(settings.color=="000000" ? UIColor.white:UIColor.black).withAlphaComponent(settings.opacity*0.6).cgColor;contrast.lineWidth=settings.width+1
        ink.strokeColor=UIColor(hex:settings.color,alpha:settings.opacity).cgColor;ink.lineWidth=settings.width
        CATransaction.commit()
    }
}
