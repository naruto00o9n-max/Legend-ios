import SwiftUI
import UIKit

final class DocumentTiles:CATiledLayer {
    override class func fadeDuration()->CFTimeInterval {0}
}
final class DocumentCanvas:UIView {
    override class var layerClass:AnyClass {DocumentTiles.self}
    private let stateLock=NSLock()
    private var state:(EditorPage?,URL?,UUID?,CGFloat)=(nil,nil,nil,1)
    var page:EditorPage?{get{stateLock.lock();defer{stateLock.unlock()};return state.0}set{stateLock.lock();state.0=newValue;stateLock.unlock()}}
    var directory:URL?{get{stateLock.lock();defer{stateLock.unlock()};return state.1}set{stateLock.lock();state.1=newValue;stateLock.unlock()}}
    var selected:UUID?{get{stateLock.lock();defer{stateLock.unlock()};return state.2}set{stateLock.lock();state.2=newValue;stateLock.unlock()}}
    var zoom:CGFloat{get{stateLock.lock();defer{stateLock.unlock()};return state.3}set{stateLock.lock();state.3=newValue;stateLock.unlock()}}
    func snapshot()->(EditorPage?,URL?,UUID?,CGFloat){stateLock.lock();defer{stateLock.unlock()};return state}
    func update(page:EditorPage,directory:URL,selected:UUID?,zoom:CGFloat){stateLock.lock();state=(page,directory,selected,zoom);stateLock.unlock();setNeedsDisplay()}
    override init(frame:CGRect){super.init(frame:frame);backgroundColor = .clear;isOpaque=false;let l=layer as! CATiledLayer;l.tileSize=CGSize(width:256,height:256);l.levelsOfDetail=6;l.levelsOfDetailBias=7;accessibilityIdentifier="document-canvas";accessibilityLabel="مساحة الصورة بالأبعاد الأصلية"}
    required init?(coder:NSCoder){fatalError()}
    override func draw(_ rect:CGRect){let (savedPage,savedDirectory,selected,zoom)=snapshot();guard let page=savedPage,let directory=savedDirectory,let c=UIGraphicsGetCurrentContext() else{return}
        let area=c.boundingBoxOfClipPath.intersection(CGRect(x:0,y:0,width:page.width,height:page.height)).integral;guard !area.isEmpty else{return}
        let factor=max(1,Int(1/max(0.01,abs(c.ctm.a))))
        if let data=try? ImagePipeline.tile(directory.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:area,sample:factor),let image=ImagePipeline.image(data,width:(Int(area.width)+factor-1)/factor,height:(Int(area.height)+factor-1)/factor,colorSpace:ImagePipeline.colorSpace(directory.appendingPathComponent(page.source))){c.saveGState();c.interpolationQuality = factor==1 ? .none:.low;c.translateBy(x:area.minX,y:area.maxY);c.scaleBy(x:1,y:-1);c.draw(image,in:CGRect(origin:.zero,size:area.size));c.restoreGState()}
        LayerRenderer.draw(page.layers,in:c,directory:directory)
        if let l=page.layers.first(where:{$0.id==selected}),l.kind != .drawing{
            let b=LayerRenderer.bounds(l);c.saveGState();c.concatenate(LayerRenderer.transform(l));let r=b
            let effective=max(0.01,zoom*CGFloat(min(abs(l.scaleX),abs(l.scaleY))))
            c.setStrokeColor(UIColor(hex:"D4AF37").cgColor);c.setLineWidth(1/effective);c.setLineDash(phase:0,lengths:[5/effective,3/effective]);c.stroke(r);c.setLineDash(phase:0,lengths:[])
            let points=[CGPoint(x:r.minX,y:r.minY),CGPoint(x:r.maxX,y:r.minY),CGPoint(x:r.minX,y:r.maxY),CGPoint(x:r.maxX,y:r.maxY),CGPoint(x:r.midX,y:r.minY-28/effective)]
            c.move(to:CGPoint(x:r.midX,y:r.minY));c.addLine(to:points[4]);c.strokePath()
            for p in points{let radius=5/effective;c.setFillColor(UIColor.black.cgColor);c.fillEllipse(in:CGRect(x:p.x-radius,y:p.y-radius,width:radius*2,height:radius*2));c.strokeEllipse(in:CGRect(x:p.x-radius,y:p.y-radius,width:radius*2,height:radius*2))};c.restoreGState()
        }
    }
}
struct CanvasHost:UIViewRepresentable {
    @ObservedObject var model:EditorModel
    var readOnly=false
    func makeCoordinator()->Coordinator {Coordinator(model)}
    func makeUIView(context:Context)->UIScrollView {
        let s=UIScrollView();s.backgroundColor=UIColor(hex:"080808");s.delegate=context.coordinator;s.bouncesZoom=true;s.showsVerticalScrollIndicator=false;s.showsHorizontalScrollIndicator=false;s.maximumZoomScale=128;s.contentInsetAdjustmentBehavior = .never;s.accessibilityIdentifier="canvas-scroll"
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:model.page.width,height:model.page.height));s.addSubview(canvas);context.coordinator.canvas=canvas;context.coordinator.scroll=s
        if readOnly{return s}
        let tap=UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.tap(_:)));canvas.addGestureRecognizer(tap)
        let pan=UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.pan(_:)));pan.maximumNumberOfTouches=1;pan.delegate=context.coordinator;canvas.addGestureRecognizer(pan);context.coordinator.panGesture=pan
        let longPress=UILongPressGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.longPress(_:)));canvas.addGestureRecognizer(longPress)
        return s
    }
    func updateUIView(_ s:UIScrollView,context:Context){let c=context.coordinator;c.model=model;c.canvas.update(page:model.page,directory:model.directory,selected:readOnly ? nil:model.selected,zoom:s.zoomScale);s.panGestureRecognizer.minimumNumberOfTouches=[Tool.brush,.eraser,.cleaner].contains(model.tool) ? 2:1
        if !c.fitted{s.layoutIfNeeded();DispatchQueue.main.async{guard !c.fitted,s.bounds.width>0 else{return};let full=min(s.bounds.width/CGFloat(model.page.width),s.bounds.height/CGFloat(model.page.height));s.minimumZoomScale=max(0.002,full/4);let reading=s.bounds.width/CGFloat(model.page.width);s.setZoomScale(reading,animated:false);c.fitted=true;c.updateCenter()}}
    }
    class Coordinator:NSObject,UIScrollViewDelegate,UIGestureRecognizerDelegate {
        var model:EditorModel;var canvas:DocumentCanvas!;weak var scroll:UIScrollView?;weak var panGesture:UIPanGestureRecognizer?;var fitted=false;var initial:EditorLayer?;var resizing=false;var rotating=false;var rotationStart=0.0;var stroke:Stroke?
        init(_ model:EditorModel){self.model=model}
        func viewForZooming(in scrollView:UIScrollView)->UIView?{canvas}
        func scrollViewDidZoom(_ s:UIScrollView){model.zoom=Double(s.zoomScale);canvas.zoom=s.zoomScale;updateCenter()}
        func scrollViewDidScroll(_ s:UIScrollView){updateCenter()}
        func updateCenter(){guard let s=scroll else{return};model.visibleCenter=canvas.convert(CGPoint(x:s.bounds.midX,y:s.bounds.midY),from:s)}
        func hit(_ point:CGPoint)->EditorLayer?{model.page.layers.reversed().first{l in guard l.isVisible,!l.isLocked,l.kind != .drawing else{return false};let b=LayerRenderer.bounds(l);return b.insetBy(dx:-18/max(0.01,model.zoom),dy:-36/max(0.01,model.zoom)).contains(point.applying(LayerRenderer.transform(l).inverted()))}}
        func gestureRecognizerShouldBegin(_ g:UIGestureRecognizer)->Bool{guard g === panGesture else{return true};if [.brush,.eraser,.cleaner].contains(model.tool){return true};return hit(g.location(in:canvas)) != nil}
        @objc func tap(_ g:UITapGestureRecognizer){let point=g.location(in:canvas);model.visibleCenter=point
            if [.brush,.eraser,.cleaner].contains(model.tool){let dot=Stroke(points:[Point(x:point.x,y:point.y)],width:model.brushWidth,color:model.brushColor,erase:model.tool == .eraser,brush:model.brushStyle);if model.tool == .cleaner{Task{await model.clean(dot)}}else{if model.active?.kind != .drawing{model.add(.drawing)};model.checkpoint();model.change{$0.strokes.append(dot)}};return}
            if model.tool == .text,hit(point)==nil{model.add(.text)}else if model.tool == .eyedropper{
                if let bytes=try? ImagePipeline.tile(model.directory.appendingPathComponent(model.page.raw),width:model.page.width,height:model.page.height,rect:CGRect(x:Int(point.x),y:Int(point.y),width:1,height:1)),bytes.count>=4{model.brushColor=String(format:"%02X%02X%02X",bytes[0],bytes[1],bytes[2])}
            }else{model.selected=hit(point)?.id;if model.tool == .text,model.selected != nil{model.panel = .content}}
        }
        @objc func longPress(_ g:UILongPressGestureRecognizer){if g.state == .began,let l=hit(g.location(in:canvas)),l.kind == .text{model.selected=l.id;model.panel = .content}}
        @objc func pan(_ g:UIPanGestureRecognizer){let point=g.location(in:canvas)
            if [.brush,.eraser,.cleaner].contains(model.tool){
                if g.state == .began{
                    if model.tool != .cleaner{if model.active?.kind != .drawing{model.add(.drawing)};model.checkpoint()};stroke=Stroke(points:[Point(x:point.x,y:point.y)],width:model.brushWidth,color:model.tool == .cleaner ? "FFFFFF":model.brushColor,erase:model.tool == .eraser,brush:model.brushStyle)
                }else if g.state == .changed{stroke?.points.append(Point(x:point.x,y:point.y));canvas.page=model.page;if let stroke,var page=canvas.page,let i=page.layers.firstIndex(where:{$0.id==model.selected}){page.layers[i].strokes.append(stroke);canvas.page=page};canvas.setNeedsDisplay()}
                else if g.state == .ended{if let stroke{if model.tool == .cleaner{Task{await model.clean(stroke)}}else{model.change{$0.strokes.append(stroke)}}};stroke=nil}
                return
            }
            if g.state == .began{guard let l=hit(point) else{return};model.selected=l.id;initial=l;model.checkpoint();let b=LayerRenderer.bounds(l),local=point.applying(LayerRenderer.transform(l).inverted()),tolerance=24/max(model.zoom*min(abs(l.scaleX),abs(l.scaleY)),0.01);resizing=hypot(local.x-b.maxX,local.y-b.maxY)<tolerance;rotating=local.y<0 && abs(local.x-b.midX)<tolerance;rotationStart=atan2(Double(point.y)-l.frame.y-Double(b.height)/2,Double(point.x)-l.frame.x-Double(b.width)/2)}
            else if g.state == .changed,let initial {let t=g.translation(in:canvas),b=LayerRenderer.bounds(initial);model.change{l in if rotating{let angle=atan2(Double(point.y)-initial.frame.y-Double(b.height)/2,Double(point.x)-initial.frame.x-Double(b.width)/2);l.rotation=initial.rotation+(angle-rotationStart)*180/Double.pi}else if resizing{let delta=CGSize(width:t.x,height:t.y).applying(CGAffineTransform(rotationAngle:-CGFloat(initial.rotation)*CGFloat.pi/180));l.scaleX=max(0.05,initial.scaleX+Double(delta.width/b.width));l.scaleY=max(0.05,initial.scaleY+Double(delta.height/b.height))}else{l.frame.x=initial.frame.x+Double(t.x);l.frame.y=initial.frame.y+Double(t.y)}}}
            else if g.state == .ended{initial=nil;model.save()}
        }
    }
}
