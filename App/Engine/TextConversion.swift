import UIKit

extension EditorModel {
    func rasterizeText() async {
        guard let layer=active,layer.kind == .text,!layer.isLocked,!busy else{return}
        let bounds=LayerRenderer.bounds(layer),rect=TextVisualBounds.rect(layer)
        guard rect.width*rect.height<=16_777_216 else{error="النص كبير جدًا للتحويل دفعة واحدة؛ قسّمه إلى طبقات أصغر";return}
        busy=true;defer{busy=false};let directory=self.directory
        do{let filename=try await BackgroundWork.run{()->String in
            let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=false
            let image=UIGraphicsImageRenderer(size:rect.size,format:format).image{output in output.cgContext.translateBy(x:-rect.minX,y:-rect.minY);if layer.isMaskEnabled{output.cgContext.addEllipse(in:CGRect(x:layer.maskX-layer.maskRadius,y:layer.maskY-layer.maskRadius,width:layer.maskRadius*2,height:layer.maskRadius*2));output.cgContext.clip()};LayerRenderer.drawText(layer,rect:bounds,context:output.cgContext,directory:directory)}
            guard let png=image.pngData() else{throw ImageFailure.message("تعذر تحويل النص")};let name=UUID().uuidString+".png";try png.write(to:directory.appendingPathComponent(name),options:.atomic);return name
        }
        guard let index=page.layers.firstIndex(where:{$0.id==layer.id}),page.layers[index]==layer else{try? FileManager.default.removeItem(at:directory.appendingPathComponent(filename));return}
        checkpoint();var result=EditorLayer(kind:.image,name:layer.textContent);result.id=layer.id;result.imagePath=filename;let center=CGPoint(x:rect.midX,y:rect.midY).applying(LayerRenderer.transform(layer));result.frame=Box(x:center.x-rect.width/2,y:center.y-rect.height/2,width:rect.width,height:rect.height);result.rotation=layer.rotation;result.scaleX=layer.scaleX;result.scaleY=layer.scaleY;result.opacity=layer.opacity;result.blend=layer.blend;page.layers[index]=result;panel=nil;tool = .move;save()
        }catch{self.error=error.localizedDescription}
    }
}
