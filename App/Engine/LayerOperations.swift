import UIKit

extension EditorModel {
    func transformGroupPeers(from original:EditorLayer,baseline:[EditorLayer]) {
        guard let group=original.groupID,let current=active,current.id==original.id else{return}
        let delta=LayerRenderer.transform(original).inverted().concatenating(LayerRenderer.transform(current))
        let sx=current.scaleX/original.scaleX,sy=current.scaleY/original.scaleY
        guard sx.isFinite,sy.isFinite else{return}
        for old in baseline where old.groupID==group && old.id != original.id && !old.isLocked {
            guard let index=page.layers.firstIndex(where:{$0.id==old.id}) else{continue}
            let box=LayerRenderer.bounds(old),center=CGPoint(x:box.midX,y:box.midY).applying(LayerRenderer.transform(old)).applying(delta)
            let transformed=LayerRenderer.transform(old).concatenating(delta)
            let scaleX=hypot(Double(transformed.a),Double(transformed.b))*(old.scaleX<0 ? -1:1)
            guard abs(scaleX)>0.000001 else{continue}
            let rotation=atan2(Double(transformed.b)/scaleX,Double(transformed.a)/scaleX)
            let scaleY=Double(transformed.a*transformed.d-transformed.b*transformed.c)/scaleX
            guard abs(scaleY)>0.000001 else{continue}
            let shear=(Double(transformed.c)*cos(rotation)+Double(transformed.d)*sin(rotation))/scaleY
            var next=old;next.frame.x=Double(center.x-box.width/2);next.frame.y=Double(center.y-box.height/2);next.rotation=rotation*180/Double.pi;next.scaleX=scaleX;next.scaleY=scaleY;next.shearX=abs(shear)>0.000001 ? shear:nil;page.layers[index]=next
        }
    }
    func groupLayers(_ ids:Set<UUID>,name:String){guard !ids.isEmpty else{return};checkpoint();let group=UUID();for i in page.layers.indices where ids.contains(page.layers[i].id){page.layers[i].groupID=group;page.layers[i].groupName=name};save()}
    func ungroupLayers(_ ids:Set<UUID>){checkpoint();for i in page.layers.indices where ids.contains(page.layers[i].id){page.layers[i].groupID=nil;page.layers[i].groupName=nil};save()}
    func mergeLayers(_ ids:Set<UUID>) async {
        let indices=page.layers.indices.filter{ids.contains(page.layers[$0].id)}
        guard indices.count>=2,let first=indices.first,let last=indices.last else{return}
        guard indices==Array(first...last) else{error="اختر طبقات متجاورة للحفاظ على ترتيب الرسم";return}
        let layers=indices.map{page.layers[$0]}
        guard layers.allSatisfy({$0.blend == .normal && !$0.isLocked}) else{error="الدمج الجزئي يحتاج طبقات عادية غير مقفلة؛ التسطيح الكامل يحفظ نتيجة أوضاع المزج";return}
        guard !busy else{return};busy=true;defer{busy=false}
        let snapshot=page,directory=self.directory
        do{let result=try await BackgroundWork.run{try LayerBitmap.merge(layers,page:snapshot,directory:directory)}
            guard page==snapshot else{return};checkpoint();page.layers.replaceSubrange(first...last,with:[result]);selected=result.id;save()
        }catch{self.error=error.localizedDescription}
    }
    func flattenLayers() async {
        guard !busy,!page.layers.isEmpty else{return};busy=true;defer{busy=false};let snapshot=page,directory=self.directory
        do{let file=try await BackgroundWork.run{try ImagePipeline.exportPNG(snapshot,directory:directory)};defer{try? FileManager.default.removeItem(at:file)};guard page==snapshot else{return};let name=UUID().uuidString+".png";try FileManager.default.copyItem(at:file,to:directory.appendingPathComponent(name));checkpoint();var layer=EditorLayer(kind:.image,name:"تسطيح العمل");layer.imagePath=name;layer.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height));page.layers=[layer];page.baseHidden=true;selected=layer.id;save()
        }catch{self.error=error.localizedDescription}
    }
}
enum LayerBitmap {
    static func merge(_ layers:[EditorLayer],page:EditorPage,directory:URL)throws->EditorLayer {
        var region=CGRect.null
        for l in layers where l.isVisible{let pad=max(4,l.style.strokeWidth+l.style.shadowRadius*3+Double(l.style.threeDDepth)+max(abs(l.style.shadowDx),abs(l.style.shadowDy)));region=region.union((l.kind == .text ? TextVisualBounds.rect(l):LayerRenderer.bounds(l).insetBy(dx:-pad,dy:-pad)).applying(LayerRenderer.transform(l)))}
        region=region.integral.intersection(CGRect(x:0,y:0,width:page.width,height:page.height));guard !region.isEmpty,!region.isNull else{throw ImageFailure.message("الطبقات المحددة خارج اللوحة")}
        let name=UUID().uuidString+".png",file=directory.appendingPathComponent(name);var error=[CChar](repeating:0,count:512)
        guard let writer=LIWriterOpen(directory.appendingPathComponent(page.source).path,file.path,Int32(region.width),Int32(region.height),&error,error.count) else{throw ImageFailure.message("تعذر بدء دمج الطبقات")};defer{LIWriterClose(writer)}
        var completed=false;defer{if !completed{try? FileManager.default.removeItem(at:file)}}
        let width=Int(region.width),height=Int(region.height)
        for y in stride(from:0,to:height,by:256){try Task.checkCancellation();let rows=min(256,height-y);var data=[UInt8](repeating:0,count:width*rows*4)
            for layer in layers where layer.isVisible{var overlay=[UInt8](repeating:0,count:data.count);let rendered=overlay.withUnsafeMutableBytes{bytes->Bool in guard let c=CGContext(data:bytes.baseAddress,width:width,height:rows,bitsPerComponent:8,bytesPerRow:width*4,space:ImagePipeline.colorSpace(directory.appendingPathComponent(page.source)),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false};c.translateBy(x:0,y:CGFloat(rows));c.scaleBy(x:1,y:-1);c.translateBy(x:-region.minX,y:-region.minY-CGFloat(y));LayerRenderer.draw([layer],in:c,directory:directory);return true};guard rendered else{throw ImageFailure.message("تعذر تركيب الطبقات")};LICompositeBlend(&data,&overlay,width*rows,0)}
            guard LIWriterRows(writer,&data,Int32(rows))==1 else{throw ImageFailure.message("تعذر كتابة الدمج")}
        }
        guard LIWriterFinish(writer)==1 else{throw ImageFailure.message("لم يكتمل دمج الطبقات")};completed=true
        var output=EditorLayer(kind:.image,name:"طبقات مدمجة");output.imagePath=name;output.frame=Box(x:region.minX,y:region.minY,width:region.width,height:region.height);return output
    }
}
