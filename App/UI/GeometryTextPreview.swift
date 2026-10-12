import SwiftUI
import UIKit

/// The inspector must never run the text/effect export pipeline from SwiftUI body.
struct GeometryTextPreview:UIViewRepresentable {
    let layer:EditorLayer?
    let directory:URL
    let size:CGSize
    func makeUIView(context:Context)->GeometryPreviewImageView{GeometryPreviewImageView()}
    func updateUIView(_ view:GeometryPreviewImageView,context:Context){if let layer{view.submit(layer,directory:directory,size:size)}}
    static func dismantleUIView(_ view:GeometryPreviewImageView,coordinator:()){view.cancel()}
}
final class GeometryPreviewImageView:UIImageView {
    private static let worker=DispatchQueue(label:"cookies.geometry.preview",qos:.userInitiated,autoreleaseFrequency:.workItem)
    private var signature:TextRenderKey?
    private var latest:(EditorLayer,URL,CGSize,Bool)?
    private var generation=0
    private var rendering=false
    private var cancelled=false
    private(set) var presentedFrames=0
    private(set) var renderedOnMain=false
    init(){super.init(frame:.zero);contentMode = .scaleAspectFit;isUserInteractionEnabled=false;accessibilityIdentifier="geometry-text-preview";isAccessibilityElement=true;accessibilityTraits = .image;accessibilityLabel="معاينة النص في المنظور"}
    required init?(coder:NSCoder){fatalError()}
    func cancel(){cancelled=true;latest=nil}
    func submit(_ source:EditorLayer,directory:URL,size:CGSize){
        guard !cancelled,size.width>0,size.height>0 else{return}
        var layer=source;layer.frame.x=0;layer.frame.y=0;layer.rotation=0;layer.scaleX=1;layer.scaleY=1
        let key=TextRenderKey(layer,directory:directory,resolution:1,size:size)
        guard key != signature else{return};signature=key;generation+=1;latest=(layer,directory,size,true);renderLatest()
        let token=generation
        DispatchQueue.main.asyncAfter(deadline:.now()+0.3){[weak self] in
            guard let self,!self.cancelled,self.generation==token else{return}
            self.latest=(layer,directory,size,false);self.renderLatest()
        }
    }
    private func renderLatest(){
        guard !cancelled,!rendering,let request=latest else{return}
        latest=nil;rendering=true
        Self.worker.async{[weak self] in
            guard self != nil else{return}
            let main=Thread.isMainThread
            let image=RenderBudget.screen(interactive:request.3){Self.render(request.0,directory:request.1,size:request.2)}
            DispatchQueue.main.async{[weak self] in
                guard let self,!self.cancelled else{return}
                self.rendering=false;self.image=image;self.presentedFrames+=1;self.renderedOnMain=main
                self.renderLatest()
            }
        }
    }
    private static func render(_ layer:EditorLayer,directory:URL,size:CGSize)->UIImage {
        let bounds=LayerRenderer.bounds(layer),scale=min(size.width/max(1,bounds.width),size.height/max(1,bounds.height))*0.75
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=false;format.preferredRange = .standard
        return UIGraphicsImageRenderer(size:size,format:format).image{output in
            let c=output.cgContext;c.translateBy(x:(size.width-bounds.width*scale)/2,y:(size.height-bounds.height*scale)/2);c.scaleBy(x:scale,y:scale)
            LayerRenderer.drawText(layer,rect:bounds,context:c,directory:directory)
        }
    }
}
