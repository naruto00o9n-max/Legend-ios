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
        let double=UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.doubleTap(_:)));double.numberOfTapsRequired=2;double.delegate=context.coordinator;canvas.addGestureRecognizer(double)
        let pan=UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.pan(_:)));pan.maximumNumberOfTouches=1;pan.delegate=context.coordinator;canvas.addGestureRecognizer(pan);context.coordinator.panGesture=pan;s.panGestureRecognizer.require(toFail:pan)
        let longPress=UILongPressGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.longPress(_:)));canvas.addGestureRecognizer(longPress)
        return s
    }
        func updateUIView(_ s:UIScrollView,context:Context){let c=context.coordinator;c.model=model;c.canvas.gradientMode=readOnly ? nil:model.gradientTarget;c.canvas.deformationMode = !readOnly && model.panel == .perspective;c.canvas.update(page:model.canvasPage,directory:model.directory,selected:readOnly ? nil:model.selected,zoom:s.zoomScale);c.canvas.showSniper(readOnly ? []:model.sniperTargets);s.accessibilityValue="\(model.page.layers.count) طبقات، \(model.page.layers.reduce(0){$0+$1.strokes.count}) خطوط رسم، الحجم \(String(format:"%.2f",model.active?.scaleX ?? 1))";s.panGestureRecognizer.minimumNumberOfTouches=(!readOnly && [Tool.brush,.eraser,.cleaner].contains(model.tool)) ? 2:1
        if !c.fitted{s.layoutIfNeeded();DispatchQueue.main.async{guard !c.fitted,s.bounds.width>0,s.bounds.height>0 else{return};let full=min(s.bounds.width/CGFloat(model.page.width),s.bounds.height/CGFloat(model.page.height));s.minimumZoomScale=max(0.002,full/4);let reading=s.bounds.width/CGFloat(model.page.width)*0.96;s.setZoomScale(reading,animated:false);c.fitted=true
            if c.readOnly,let saved=ReaderBookmark.viewport(page:c.model.page.id){s.setZoomScale(CGFloat(min(128,max(Double(s.minimumZoomScale),saved.zoom))),animated:false);s.setContentOffset(CGPoint(x:max(0,CGFloat(saved.x)*s.zoomScale-s.bounds.width/2),y:max(0,CGFloat(saved.y)*s.zoomScale-s.bounds.height/2)),animated:false)}
            c.updateCenter()}}else{c.updateCenter()}
    }
    class Coordinator:NSObject,UIScrollViewDelegate,UIGestureRecognizerDelegate {
        var model:EditorModel;var canvas:DocumentCanvas!;weak var scroll:UIScrollView?;weak var panGesture:UIPanGestureRecognizer?;var fitted=false;var readOnly=false;var centering=false;var initial:EditorLayer?;var groupInitial:[EditorLayer]=[];var dragHandle:String?;var rotationStart=0.0;var scaleStart=1.0;var stroke:Stroke?;var smudge:SmudgeSession?
        init(_ model:EditorModel){self.model=model}
        func viewForZooming(in scrollView:UIScrollView)->UIView?{canvas}
        func scrollViewDidZoom(_ s:UIScrollView){if !readOnly{model.zoom=Double(s.zoomScale)};canvas.zoom=s.zoomScale;canvas.updateSelection();updateCenter()}
        func scrollViewDidScroll(_ s:UIScrollView){updateCenter()}
        func updateCenter(){guard let s=scroll,!centering else{return};centering=true;defer{centering=false};let horizontal=max(0,(s.bounds.width-canvas.frame.width)/2),vertical=max(0,(s.bounds.height-canvas.frame.height)/2);let insets=UIEdgeInsets(top:vertical,left:horizontal,bottom:vertical,right:horizontal);if s.contentInset != insets{s.contentInset=insets};var offset=s.contentOffset;if horizontal>0{offset.x = -horizontal};if vertical>0{offset.y = -vertical};if offset != s.contentOffset{s.contentOffset=offset};if !readOnly{model.visibleCenter=canvas.convert(CGPoint(x:s.bounds.midX,y:s.bounds.midY),from:s)};canvas.refreshVisible(canvas.convert(s.bounds,from:s));if readOnly,fitted{let center=canvas.convert(CGPoint(x:s.bounds.midX,y:s.bounds.midY),from:s);ReaderBookmark.save(ReaderViewport(x:Double(center.x),y:Double(center.y),zoom:Double(s.zoomScale)),page:model.page.id)}}
        func hit(_ point:CGPoint)->EditorLayer?{model.page.layers.reversed().first{l in guard l.isVisible,!l.isLocked,l.kind != .drawing else{return false};let b=LayerRenderer.bounds(l);return b.insetBy(dx:-18/max(0.01,model.zoom),dy:-36/max(0.01,model.zoom)).contains(point.applying(LayerRenderer.transform(l).inverted()))}}
        func gestureRecognizer(_ gesture:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool {
            if gesture is UITapGestureRecognizer{var view=touch.view;while let current=view{if current is UIControl{return false};view=current.superview}}
            return true
        }
        func gestureRecognizerShouldBegin(_ g:UIGestureRecognizer)->Bool{guard g === panGesture else{return true};if model.sniperMode{return false};if model.drawingShape=="fill",model.tool == .brush{return false};if model.textMaskMode,model.active?.kind == .text{return true};if [.brush,.eraser,.cleaner].contains(model.tool){return true};return canvas.handle(at:g.location(in:canvas)) != nil || hit(g.location(in:canvas)) != nil}
        @objc func tap(_ g:UITapGestureRecognizer){let point=g.location(in:canvas);model.visibleCenter=point
            if model.sniperMode{Task{await model.detectSniper(at:point)};return}
            if model.tool == .brush,model.drawingShape=="fill"{Task{await model.fillBucket(at:point)};return}
            if [.brush,.eraser,.cleaner].contains(model.tool){let dot=Stroke(points:[Point(x:point.x,y:point.y)],width:model.brushWidth,color:model.brushColor,erase:model.tool == .eraser,brush:model.brushStyle,opacity:model.brushOpacity,texturePath:model.brushTexture,shape:model.drawingShape,filled:model.drawingFilled);if model.tool == .cleaner{Task{await model.clean(dot)}}else{if model.active?.kind != .drawing{model.add(.drawing)};model.checkpoint();model.change{$0.strokes.append(dot)}};return}
            if model.tool == .text,hit(point)==nil{model.add(.text)}else if model.tool == .eyedropper{
                if let sample=try? ImagePipeline.compositeRegion(model.page,directory:model.directory,rect:CGRect(x:Int(point.x),y:Int(point.y),width:1,height:1)),let data=sample.dataProvider?.data{let bytes=data as Data;if bytes.count>=4{model.brushColor=String(format:"%02X%02X%02X",bytes[0],bytes[1],bytes[2])}}
            }else{model.selected=hit(point)?.id;if model.active?.kind == .text{model.tool = .text}}
        }
        @objc func doubleTap(_ g:UITapGestureRecognizer){guard let layer=hit(g.location(in:canvas)),layer.kind == .text else{return};let action=UserDefaults.standard.string(forKey:"editor-double-tap") ?? "edit";model.selected=layer.id;if action=="edit"{model.tool = .text;model.panel = .content}else if action=="typer"{model.requestTyper=true}}
        @objc func longPress(_ g:UILongPressGestureRecognizer){if g.state == .began,let l=hit(g.location(in:canvas)),l.kind == .text{model.selected=l.id;model.tool = .text;model.panel = .content}}
        @objc func pan(_ g:UIPanGestureRecognizer){let point=g.location(in:canvas)
            if model.tool == .brush,model.drawingShape=="smudge"{
                if g.state == .began{do{smudge=try SmudgeSession(page:model.page,directory:model.directory,region:canvas.visibleRect.insetBy(dx:-model.brushWidth,dy:-model.brushWidth),point:point,width:model.brushWidth,strength:model.smudgeStrength)}catch{model.error=error.localizedDescription}}
                else if g.state == .changed{smudge?.move(to:point);if let smudge{canvas.showPatch(smudge.image(),rect:smudge.region)}}
                else if g.state == .ended{do{canvas.commitPatch();try smudge?.commit(to:model)}catch{canvas.showPatch(nil);model.error=error.localizedDescription};smudge=nil}
                else if g.state == .cancelled{smudge=nil;canvas.showPatch(nil)}
                return
            }
            if model.textMaskMode,let active=model.active,active.kind == .text,!active.isLocked{
                let local=point.applying(LayerRenderer.transform(active).inverted())
                if g.state == .began{initial=active;model.checkpoint();stroke=Stroke(points:[Point(x:local.x,y:local.y)],width:model.brushWidth,color:"FFFFFF",erase:!model.textMaskRestore);canvas.beginLayerInteraction(active.id)}
                else if g.state == .changed{stroke?.points.append(Point(x:local.x,y:local.y));if let initial,let stroke{model.change(persist:false){$0.textMask=(initial.textMask ?? [])+[stroke]};canvas.update(page:model.page,directory:model.directory,selected:model.selected,zoom:scroll?.zoomScale ?? 1)}}
                else if g.state == .ended || g.state == .cancelled{if g.state == .cancelled,let initial{model.change(persist:false){$0.textMask=initial.textMask}};canvas.endLayerInteraction();stroke=nil;initial=nil;model.save()}
                return
            }
            if [.brush,.eraser,.cleaner].contains(model.tool){
                if g.state == .began{
                    if model.tool != .cleaner{if model.active?.kind != .drawing{model.add(.drawing)};model.checkpoint()};let local=model.tool == .cleaner ? point:point.applying(model.active.map{LayerRenderer.transform($0).inverted()} ?? .identity);stroke=Stroke(points:[Point(x:local.x,y:local.y)],width:model.brushWidth,color:model.tool == .cleaner ? "FFFFFF":model.brushColor,erase:model.tool == .eraser,brush:model.brushStyle,opacity:model.brushOpacity,texturePath:model.brushTexture,shape:model.drawingShape,filled:model.drawingFilled)
                }
                if g.state == .changed || g.state == .ended{let local=model.tool == .cleaner ? point:point.applying(model.active.map{LayerRenderer.transform($0).inverted()} ?? .identity);if model.drawingShape=="free"{stroke?.points.append(Point(x:local.x,y:local.y))}else if let first=stroke?.points.first{stroke?.points=[first,Point(x:local.x,y:local.y)]};canvas.showStroke(stroke,on:model.page,selected:model.selected)}
                if g.state == .cancelled{stroke=nil;canvas.showStroke(nil,on:model.page,selected:model.selected)}
                else if g.state == .ended{if let stroke{if model.tool == .cleaner{canvas.showStroke(nil,on:model.page,selected:model.selected);Task{await model.clean(stroke)}}else{canvas.commitLiveStroke();model.change{$0.strokes.append(stroke)}}};stroke=nil}
                return
            }
            if g.state == .began{let translation=g.translation(in:canvas),origin=CGPoint(x:point.x-translation.x,y:point.y-translation.y);dragHandle=canvas.handle(at:origin);guard let l=(dragHandle != nil ? model.active:hit(point)) else{return};model.selected=l.id;initial=l;groupInitial=model.page.layers;model.checkpoint();canvas.beginLayerInteraction(l.id);let b=LayerRenderer.bounds(l),dx=Double(origin.x)-l.frame.x-Double(b.width)/2,dy=Double(origin.y)-l.frame.y-Double(b.height)/2;rotationStart=atan2(dy,dx);scaleStart=max(1,hypot(dx,dy))}
            if (g.state == .changed || g.state == .ended),let initial {let raw=g.translation(in:canvas),speed=CGFloat(dragHandle==nil ? 1:EditorPreferences.handleSpeed),t=CGPoint(x:raw.x*speed,y:raw.y*speed),b=LayerRenderer.bounds(initial),snapshot=model.page;model.change(persist:false){l in
                if let handle=dragHandle,handle.hasPrefix("gradient-"),let target=model.gradientTarget{
                    let local=point.applying(LayerRenderer.transform(initial).inverted());var values=GradientGeometry.points(initial.style,target:target,size:b.size)
                    values[handle=="gradient-start" ? 0:1]=Point(x:min(2,max(-1,Double(local.x/max(1,b.width)))),y:min(2,max(-1,Double(local.y/max(1,b.height)))))
                    GradientGeometry.set(values,target:target,style:&l.style);return
                }
                if let handle=dragHandle,handle.hasPrefix("deform-"),let index=Int(handle.dropFirst(7)) {
                    let local=point.applying(LayerRenderer.transform(initial).inverted())
                    let p=Point(x:min(2,max(-1,Double(local.x/max(1,b.width)))),y:min(2,max(-1,Double(local.y/max(1,b.height)))))
                    if l.style.isMeshMode,index<l.style.meshPoints.count{l.style.meshPoints[index]=p}
                    else{if l.style.perspectivePoints.count != 4{l.style.perspectivePoints=[Point(x:0,y:0),Point(x:1,y:0),Point(x:1,y:1),Point(x:0,y:1)]};if index<4{l.style.perspectivePoints[index]=p}}
                    return
                }
                let delta=CGSize(width:t.x,height:t.y).applying(CGAffineTransform(rotationAngle:-CGFloat(initial.rotation)*CGFloat.pi/180))
                switch dragHandle {
                case "rotate":let angle=atan2(Double(point.y)-initial.frame.y-Double(b.height)/2,Double(point.x)-initial.frame.x-Double(b.width)/2);l.rotation=initial.rotation+(angle-rotationStart)*180/Double.pi*EditorPreferences.handleSpeed;if EditorPreferences.snap{let snapped=(l.rotation/15).rounded()*15;if abs(snapped-l.rotation)<4{l.rotation=snapped}}
                case "resize":let distance=hypot(Double(point.x)-initial.frame.x-Double(b.width)/2,Double(point.y)-initial.frame.y-Double(b.height)/2),factor=max(0.05,1+(distance/scaleStart-1)*EditorPreferences.handleSpeed);l.scaleX=initial.scaleX*factor;l.scaleY=initial.scaleY*factor
                case "scale-x":l.scaleX=max(0.05,initial.scaleX-Double(delta.width/b.width))
                case "scale-y":l.scaleY=max(0.05,initial.scaleY-Double(delta.height/b.height))
                case "box-width":l.style.boxWidth=max(20,initial.style.boxWidth+Double(delta.width)/max(0.05,initial.scaleX));l.frame.width=l.style.boxWidth
                case "delete","duplicate","edit","styles":break
                default:l.frame.x=initial.frame.x+Double(t.x);l.frame.y=initial.frame.y+Double(t.y)
                    if EditorPreferences.snap{SnapAlignment.apply(&l,page:snapshot,tolerance:8/max(0.01,model.zoom))}
                }
            };if dragHandle==nil || ["resize","rotate"].contains(dragHandle ?? ""){model.transformGroupPeers(from:initial,baseline:groupInitial)};canvas.update(page:model.page,directory:model.directory,selected:model.selected,zoom:scroll?.zoomScale ?? 1)}
            if g.state == .ended || g.state == .cancelled{canvas.endLayerInteraction();initial=nil;groupInitial=[];dragHandle=nil;model.save()}
        }
    }
}
