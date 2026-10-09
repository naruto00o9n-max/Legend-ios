import UIKit
import ImageIO

extension EditorModel {
    func fillBucket(at point:CGPoint) async {
        guard !busy else{return};guard Int64(page.width)*Int64(page.height)<=16_777_216 else{error="التعبئة تدعم حتى 16 مليون بكسل؛ قسّم الصفحة الأكبر أولًا";return}
        busy=true;defer{busy=false};let snapshot=page,directory=self.directory,color=UIColor(hex:brushColor,alpha:CGFloat(brushOpacity)),tolerance=fillTolerance
        do{let filename=try await BackgroundWork.run{()->String in
            let composite=try ImagePipeline.exportPNG(snapshot,directory:directory);defer{try? FileManager.default.removeItem(at:composite)}
            guard let source=UIImage(contentsOfFile:composite.path),let patch=CookiesFillBucket(source,point,color,tolerance),let png=patch.pngData() else{throw ImageFailure.message("تعذر تعبئة المنطقة")}
            let name=UUID().uuidString+".png";try png.write(to:directory.appendingPathComponent(name),options:.atomic);return name
        }
        guard page==snapshot else{try? FileManager.default.removeItem(at:directory.appendingPathComponent(filename));return};checkpoint();var layer=EditorLayer(kind:.image,name:"تعبئة منطقة");layer.imagePath=filename;layer.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height));page.layers.append(layer);selected=layer.id;save()
        }catch{self.error=error.localizedDescription}
    }
}
