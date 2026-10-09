import UIKit
import PDFKit
import ZIPFoundation

enum PageOperations {
    /// Produces PNG in bands; neither a chapter nor a long page is one giant bitmap.
    static func build(title:String,width:Int,height:Int,root:URL,profile:URL?=nil,rows:(Int,Int)throws->[UInt8])throws->EditorPage {
        guard width>0,height>0,width<=32768,height<=150000,Int64(width)*Int64(height)<=268_435_456 else{throw ImageFailure.message("المقاس يتجاوز مساحة العمل المدعومة")}
        let input=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png")
        defer{try? FileManager.default.removeItem(at:input)}
        var error=[CChar](repeating:0,count:512)
        let writer:OpaquePointer?
        if let profile{writer=LIWriterOpen(profile.path,input.path,Int32(width),Int32(height),&error,error.count)}else{writer=LIWriterOpen(nil,input.path,Int32(width),Int32(height),&error,error.count)}
        guard let writer else{throw ImageFailure.message("تعذر إنشاء الصفحة")};defer{LIWriterClose(writer)}
        for y in stride(from:0,to:height,by:256){try Task.checkCancellation();let count=min(256,height-y);var data=try rows(y,count);guard data.count==width*count*4,LIWriterRows(writer,&data,Int32(count))==1 else{throw ImageFailure.message("تعذر كتابة الصفحة؛ تحقق من مساحة التخزين")}}
        guard LIWriterFinish(writer)==1 else{throw ImageFailure.message("لم يكتمل إنشاء الصفحة")}
        var page=try ImagePipeline.importImage(input,root:root);page.title=title
        try JSONEncoder().encode(page).write(to:root.appendingPathComponent(page.id.uuidString).appendingPathComponent("page.json"),options:.atomic);return page
    }
    static func blank(title:String,width:Int,height:Int,color:String,transparent:Bool,root:URL)throws->EditorPage {
        var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0;UIColor(hex:color).getRed(&r,green:&g,blue:&b,alpha:&a)
        let rgba:[UInt8]=[UInt8(r*255),UInt8(g*255),UInt8(b*255),transparent ? 0:255]
        return try build(title:title,width:width,height:height,root:root){_,count in var bytes=[UInt8](repeating:0,count:width*count*4);for i in stride(from:0,to:bytes.count,by:4){for channel in 0..<4{bytes[i+channel]=rgba[channel]}};return bytes}
    }
    static func copyLayers(_ layers:[EditorLayer],from source:URL,to destination:URL,offset:CGPoint = .zero)throws->[EditorLayer] {
        var map:[String:String]=[:]
        func copy(_ name:String)throws->String {
            if name.isEmpty{return ""};if let existing=map[name]{return existing}
            guard !name.contains("/"),!name.contains("..") else{throw ImageFailure.message("مسار أصل غير صالح")}
            let input=source.appendingPathComponent(name),target=UUID().uuidString+"."+input.pathExtension
            try FileManager.default.copyItem(at:input,to:destination.appendingPathComponent(target));map[name]=target;return target
        }
        return try layers.map{layer in var next=layer;next.id=UUID();next.frame.x+=offset.x;next.frame.y+=offset.y;next.imagePath=try copy(next.imagePath);next.style.texturePath=try copy(next.style.texturePath);return next}
    }
    static func cropped(_ page:EditorPage,rect:CGRect,root:URL)throws->EditorPage {
        let region=rect.integral.intersection(CGRect(x:0,y:0,width:page.width,height:page.height))
        guard !region.isEmpty,region.width>=1,region.height>=1 else{throw ImageFailure.message("منطقة القص خارج الصورة")}
        let source=root.appendingPathComponent(page.id.uuidString)
        var output=try build(title:page.title,width:Int(region.width),height:Int(region.height),root:root,profile:source.appendingPathComponent(page.source)){y,count in try ImagePipeline.tile(source.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:CGRect(x:region.minX,y:region.minY+CGFloat(y),width:region.width,height:CGFloat(count)))}
        output.layers=try copyLayers(page.layers,from:source,to:root.appendingPathComponent(output.id.uuidString),offset:CGPoint(x:-region.minX,y:-region.minY))
        try persist(output,root:root);return output
    }
    static func split(_ page:EditorPage,maximumHeight:Int,root:URL)throws->[EditorPage] {
        guard maximumHeight>0 else{throw ImageFailure.message("اكتب طول الجزء")}
        var pages:[EditorPage]=[]
        do{for y in stride(from:0,to:page.height,by:maximumHeight){var next=try cropped(page,rect:CGRect(x:0,y:y,width:page.width,height:min(maximumHeight,page.height-y)),root:root);next.title=page.title+" — \(pages.count+1)";try persist(next,root:root);pages.append(next)};return pages}
        catch{for p in pages{try? FileManager.default.removeItem(at:root.appendingPathComponent(p.id.uuidString))};throw error}
    }
    static func merged(_ pages:[EditorPage],root:URL,alignment:Int=0)throws->EditorPage {
        guard let first=pages.first else{throw ImageFailure.message("اختر صفحات للدمج")}
        let width=pages.map(\.width).max() ?? first.width,height=pages.reduce(0){$0+$1.height}
        var starts:[Int]=[];var offset=0;for page in pages{starts.append(offset);offset+=page.height}
        var output=try build(title:first.title+" — مدمج",width:width,height:height,root:root,profile:root.appendingPathComponent(first.id.uuidString).appendingPathComponent(first.source)){y,count in
            var bytes=[UInt8](repeating:255,count:width*count*4)
            for (index,page) in pages.enumerated(){let low=max(y,starts[index]),high=min(y+count,starts[index]+page.height);guard high>low else{continue}
                let pixels=try ImagePipeline.tile(root.appendingPathComponent(page.id.uuidString).appendingPathComponent(page.raw),width:page.width,height:page.height,rect:CGRect(x:0,y:low-starts[index],width:page.width,height:high-low))
                let x=alignment==1 ? (width-page.width)/2 : alignment==2 ? width-page.width:0
                for row in 0..<(high-low){let dest=((low-y+row)*width+x)*4;bytes.replaceSubrange(dest..<(dest+page.width*4),with:pixels[(row*page.width*4)..<((row+1)*page.width*4)])}
            };return bytes
        }
        for (index,page) in pages.enumerated(){let x=alignment==1 ? (width-page.width)/2:alignment==2 ? width-page.width:0;output.layers+=try copyLayers(page.layers,from:root.appendingPathComponent(page.id.uuidString),to:root.appendingPathComponent(output.id.uuidString),offset:CGPoint(x:x,y:starts[index]))}
        try persist(output,root:root);return output
    }
    static func resized(_ page:EditorPage,width:Int,height:Int,root:URL)throws->EditorPage {
        guard width>0,height>0 else{throw ImageFailure.message("المقاس غير صالح")}
        let sx=Double(width)/Double(page.width),sy=Double(height)/Double(page.height),source=root.appendingPathComponent(page.id.uuidString)
        var output=try build(title:page.title,width:width,height:height,root:root,profile:source.appendingPathComponent(page.source)){y,count in
            let start=max(0,Int(floor(Double(y)/sy))-2),end=min(page.height,Int(ceil(Double(y+count)/sy))+2)
            let bytes=try ImagePipeline.tile(source.appendingPathComponent(page.raw),width:page.width,height:page.height,rect:CGRect(x:0,y:start,width:page.width,height:end-start))
            guard let cg=ImagePipeline.image(bytes,width:page.width,height:end-start) else{throw ImageFailure.message("تعذر تغيير المقاس")}
            var band=[UInt8](repeating:0,count:width*count*4)
            let ok=band.withUnsafeMutableBytes{data->Bool in guard let c=CGContext(data:data.baseAddress,width:width,height:count,bitsPerComponent:8,bytesPerRow:width*4,space:ImagePipeline.colorSpace(source.appendingPathComponent(page.source)),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false};c.translateBy(x:0,y:CGFloat(count));c.scaleBy(x:1,y:-1);UIGraphicsPushContext(c);defer{UIGraphicsPopContext()};c.interpolationQuality = .high;UIImage(cgImage:cg).draw(in:CGRect(x:0,y:Double(start)*sy-Double(y),width:Double(width),height:Double(end-start)*sy));return true}
            guard ok else{throw ImageFailure.message("تعذر تغيير المقاس")}
            // The renderer produced premultiplied pixels; libpng expects straight RGBA.
            for i in stride(from:0,to:band.count,by:4){let alpha=Int(band[i+3]);if alpha>0 && alpha<255{for c in 0..<3{band[i+c]=UInt8(min(255,Int(band[i+c])*255/alpha))}}};return band
        }
        output.layers=try copyLayers(page.layers,from:source,to:root.appendingPathComponent(output.id.uuidString)).map{layer in var next=layer;let b=LayerRenderer.bounds(layer);next.frame.x=(layer.frame.x+Double(b.width)/2)*sx-Double(b.width)/2;next.frame.y=(layer.frame.y+Double(b.height)/2)*sy-Double(b.height)/2;next.scaleX*=sx;next.scaleY*=sy;return next}
        try persist(output,root:root);return output
    }
    static func importPDF(_ url:URL,root:URL,scale:Double=2)throws->[EditorPage] {
        let scoped=url.startAccessingSecurityScopedResource();defer{if scoped{url.stopAccessingSecurityScopedResource()}}
        guard let document=PDFDocument(url:url),!document.isLocked,document.pageCount>0,document.pageCount<=500 else{throw ImageFailure.message("ملف PDF فارغ أو مقفل أو يحتوي أكثر من 500 صفحة")}
        var result:[EditorPage]=[]
        do{for index in 0..<document.pageCount{try Task.checkCancellation();guard let pdf=document.page(at:index) else{throw ImageFailure.message("تعذر فتح صفحة PDF")};let box=pdf.bounds(for:.mediaBox),width=Int(ceil(box.width*scale)),height=Int(ceil(box.height*scale))
            let page=try build(title:url.deletingPathExtension().lastPathComponent+" — \(index+1)",width:width,height:height,root:root){y,count in
                var bytes=[UInt8](repeating:255,count:width*count*4)
                let ok=bytes.withUnsafeMutableBytes{data->Bool in guard let c=CGContext(data:data.baseAddress,width:width,height:count,bitsPerComponent:8,bytesPerRow:width*4,space:ImagePipeline.space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false};c.translateBy(x:0,y:CGFloat(height-y));c.scaleBy(x:CGFloat(scale),y:-CGFloat(scale));c.translateBy(x:-box.minX,y:-box.minY);pdf.draw(with:.mediaBox,to:c);return true}
                guard ok else{throw ImageFailure.message("تعذر تحويل PDF")};return bytes
            };result.append(page)
        };return result}catch{for page in result{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString))};throw error}
    }
    static func persist(_ page:EditorPage,root:URL)throws{let dir=root.appendingPathComponent(page.id.uuidString);try JSONEncoder().encode(page).write(to:dir.appendingPathComponent("page.json"),options:.atomic);try ImagePipeline.projectThumbnail(page,directory:dir)}
}
