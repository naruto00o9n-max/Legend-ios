import SwiftUI
import UIKit

struct CanvasHost:UIViewRepresentable {
    @ObservedObject var model:EditorModel
    var readOnly=false
    func makeCoordinator()->Coordinator {Coordinator(model)}
    func makeUIView(context:Context)->UIScrollView {
        let s=UIScrollView();context.coordinator.readOnly=readOnly;s.backgroundColor=UIColor(hex:"080808");s.delegate=context.coordinator;s.bouncesZoom=true;s.showsVerticalScrollIndicator=false;s.showsHorizontalScrollIndicator=false;s.maximumZoomScale=128;s.contentInsetAdjustmentBehavior = .never;s.accessibilityIdentifier="canvas-scroll"
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:model.page.width,height:model.page.height));s.addSubview(canvas);context.coordinator.canvas=canvas;context.coordinator.scroll=s;canvas.onHandle={ [weak coordinator=context.coordinator] name in guard let c=coordinator else{return};switch name{case "delete":c.model.delete();case "duplicate":c.model.duplicate();case "edit":c.model.tool = .text;c.model.panel = .content;case "styles":c.model.tool = .text;c.model.panel = .styles;default:break}}
        if readOnly{return s}
        let tap=UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.tap(_:)));tap.delegate=context.coordinator;canvas.addGestureRecognizer(tap)
        let pan=UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.pan(_:)));pan.maximumNumberOfTouches=1;pan.delegate=context.coordinator;canvas.addGestureRecognizer(pan);context.coordinator.panGesture=pan
        let longPress=UILongPressGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.longPress(_:)));canvas.addGestureRecognizer(longPress)
        return s
    }
    func updateUIView(_ s:UIScrollView,context:Context){let c=context.coordinator;c.model=model;c.canvas.update(page:model.page,directory:model.directory,selected:readOnly ? nil:model.selected,zoom:s.zoomScale);s.accessibilityValue="\(model.page.layers.count) طبقات، \(model.page.layers.reduce(0){$0+$1.strokes.count}) خطوط رسم، الحجم \(String(format:"%.2f",model.active?.scaleX ?? 1))";s.panGestureRecognizer.minimumNumberOfTouches=(!readOnly && [Tool.brush,.eraser,.cleaner].contains(model.tool)) ? 2:1
        if !c.fitted{s.layoutIfNeeded();DispatchQueue.main.async{guard !c.fitted,s.bounds.width>0,s.bounds.height>0 else{return};let full=min(s.bounds.width/CGFloat(model.page.width),s.bounds.height/CGFloat(model.page.height));s.minimumZoomScale=max(0.002,full/4);let reading=s.bounds.width/CGFloat(model.page.width)*0.96;s.setZoomScale(reading,animated:false);c.fitted=true;c.updateCenter()}}else{c.updateCenter()}
    }
    class Coordinator:NSObject,UIScrollViewDelegate,UIGestureRecognizerDelegate {
        var model:EditorModel;var canvas:DocumentCanvas!;weak var scroll:UIScrollView?;weak var panGesture:UIPanGestureRecognizer?;var fitted=false;var readOnly=false;var centering=false;var initial:EditorLayer?;var dragHandle:String?;var rotationStart=0.0;var stroke:Stroke?
        init(_ model:EditorModel){self.model=model}
        func viewForZooming(in scrollView:UIScrollView)->UIView?{canvas}
        func scrollViewDidZoom(_ s:UIScrollView){if !readOnly{model.zoom=Double(s.zoomScale)};canvas.zoom=s.zoomScale;canvas.updateSelection();updateCenter()}
        func scrollViewDidScroll(_ s:UIScrollView){updateCenter()}
        func updateCenter(){guard let s=scroll,!centering else{return};centering=true;defer{centering=false};let horizontal=max(0,(s.bounds.width-canvas.frame.width)/2),vertical=max(0,(s.bounds.height-canvas.frame.height)/2);let insets=UIEdgeInsets(top:vertical,left:horizontal,bottom:vertical,right:horizontal);if s.contentInset != insets{s.contentInset=insets};var offset=s.contentOffset;if horizontal>0{offset.x = -horizontal};if vertical>0{offset.y = -vertical};if offset != s.contentOffset{s.contentOffset=offset};if !readOnly{model.visibleCenter=canvas.convert(CGPoint(x:s.bounds.midX,y:s.bounds.midY),from:s)};canvas.refreshVisible(canvas.convert(s.bounds,from:s))}
        func hit(_ point:CGPoint)->EditorLayer?{model.page.layers.reversed().first{l in guard l.isVisible,!l.isLocked,l.kind != .drawing else{return false};let b=LayerRenderer.bounds(l);return b.insetBy(dx:-18/max(0.01,model.zoom),dy:-36/max(0.01,model.zoom)).contains(point.applying(LayerRenderer.transform(l).inverted()))}}
        func gestureRecognizer(_ gesture:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool {
            if gesture is UITapGestureRecognizer{var view=touch.view;while let current=view{if current is UIControl{return false};view=current.superview}}
            return true
        }
        func gestureRecognizerShouldBegin(_ g:UIGestureRecognizer)->Bool{guard g === panGesture else{return true};if [.brush,.eraser,.cleaner].contains(model.tool){return true};return canvas.handle(at:g.location(in:canvas)) != nil || hit(g.location(in:canvas)) != nil}
        @objc func tap(_ g:UITapGestureRecognizer){let point=g.location(in:canvas);model.visibleCenter=point
            if [.brush,.eraser,.cleaner].contains(model.tool){let dot=Stroke(points:[Point(x:point.x,y:point.y)],width:model.brushWidth,color:model.brushColor,erase:model.tool == .eraser,brush:model.brushStyle);if model.tool == .cleaner{Task{await model.clean(dot)}}else{if model.active?.kind != .drawing{model.add(.drawing)};model.checkpoint();model.change{$0.strokes.append(dot)}};return}
            if model.tool == .text,hit(point)==nil{model.add(.text)}else if model.tool == .eyedropper{
                if let bytes=try? ImagePipeline.tile(model.directory.appendingPathComponent(model.page.raw),width:model.page.width,height:model.page.height,rect:CGRect(x:Int(point.x),y:Int(point.y),width:1,height:1)),bytes.count>=4{model.brushColor=String(format:"%02X%02X%02X",bytes[0],bytes[1],bytes[2])}
            }else{model.selected=hit(point)?.id;if model.active?.kind == .text{model.tool = .text}}
        }
        @objc func longPress(_ g:UILongPressGestureRecognizer){if g.state == .began,let l=hit(g.location(in:canvas)),l.kind == .text{model.selected=l.id;model.tool = .text;model.panel = .content}}
        @objc func pan(_ g:UIPanGestureRecognizer){let point=g.location(in:canvas)
            if [.brush,.eraser,.cleaner].contains(model.tool){
                if g.state == .began{
                    if model.tool != .cleaner{if model.active?.kind != .drawing{model.add(.drawing)};model.checkpoint()};stroke=Stroke(points:[Point(x:point.x,y:point.y)],width:model.brushWidth,color:model.tool == .cleaner ? "FFFFFF":model.brushColor,erase:model.tool == .eraser,brush:model.brushStyle)
                }else if g.state == .changed{stroke?.points.append(Point(x:point.x,y:point.y));canvas.showStroke(stroke,on:model.page,selected:model.selected)}
                else if g.state == .cancelled{stroke=nil;canvas.showStroke(nil,on:model.page,selected:model.selected)}
                else if g.state == .ended{if let stroke{if model.tool == .cleaner{Task{await model.clean(stroke)}}else{model.change{$0.strokes.append(stroke)}}};stroke=nil}
                return
            }
            if g.state == .began{dragHandle=canvas.handle(at:point);guard let l=(dragHandle != nil ? model.active:hit(point)) else{return};model.selected=l.id;initial=l;model.checkpoint();let b=LayerRenderer.bounds(l);rotationStart=atan2(Double(point.y)-l.frame.y-Double(b.height)/2,Double(point.x)-l.frame.x-Double(b.width)/2)}
            else if g.state == .changed,let initial {let t=g.translation(in:canvas),b=LayerRenderer.bounds(initial);model.change{l in
                let delta=CGSize(width:t.x,height:t.y).applying(CGAffineTransform(rotationAngle:-CGFloat(initial.rotation)*CGFloat.pi/180))
                switch dragHandle {
                case "rotate":let angle=atan2(Double(point.y)-initial.frame.y-Double(b.height)/2,Double(point.x)-initial.frame.x-Double(b.width)/2);l.rotation=initial.rotation+(angle-rotationStart)*180/Double.pi
                case "resize":let factor=max(0.05,1+Double(delta.width)/max(1,Double(b.width)*initial.scaleX));l.scaleX=initial.scaleX*factor;l.scaleY=initial.scaleY*factor
                case "scale-x":l.scaleX=max(0.05,initial.scaleX-Double(delta.width/b.width))
                case "scale-y":l.scaleY=max(0.05,initial.scaleY-Double(delta.height/b.height))
                case "box-width":l.style.boxWidth=max(20,initial.style.boxWidth+Double(delta.width)/max(0.05,initial.scaleX));l.frame.width=l.style.boxWidth
                case "delete","duplicate","edit","styles":break
                default:l.frame.x=initial.frame.x+Double(t.x);l.frame.y=initial.frame.y+Double(t.y)
                }
            }}
            else if g.state == .ended || g.state == .cancelled{initial=nil;dragHandle=nil;model.save()}
        }
    }
}
