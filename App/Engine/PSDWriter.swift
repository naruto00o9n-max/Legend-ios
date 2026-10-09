import UIKit

// PSD v1, 8-bit RGB. Layers stay separate as raster layers; editable text metadata
// stays in .cookies projects. All channels are streamed in bands.
enum PSDWriter {
    struct Item {var layer:EditorLayer;var rect:CGRect;var raw:URL}
    static func export(_ page:EditorPage,directory:URL)throws->URL {
        guard page.width<=30000,page.height<=30000,page.layers.count<30000 else{throw ImageFailure.message("تجاوز المشروع حدود صيغة PSD؛ استخدم PNG أو ملف المشروع")}
        let fm=FileManager.default,work=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try fm.createDirectory(at:work,withIntermediateDirectories:true);defer{try? fm.removeItem(at:work)}
        let composite=try ImagePipeline.exportPNG(page,directory:directory);defer{try? fm.removeItem(at:composite)}
        let merged=work.appendingPathComponent("merged.rgba");var width:Int32=0,height:Int32=0,error=[CChar](repeating:0,count:512)
        guard LIImportPNG(composite.path,merged.path,&width,&height,&error,error.count)==1 else{throw ImageFailure.message("تعذر تجهيز PSD")}
        var background=EditorLayer(kind:.image,name:"الصورة الأصلية");background.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height))
        var items=[Item(layer:background,rect:CGRect(x:0,y:0,width:page.width,height:page.height),raw:directory.appendingPathComponent(page.raw))]
        for layer in page.layers {
            let padding=max(4,layer.style.strokeWidth+layer.style.shadowRadius*3+layer.style.effectValue*3+Double(layer.style.threeDDepth))
            let rect=LayerRenderer.bounds(layer).insetBy(dx:-padding,dy:-padding).applying(LayerRenderer.transform(layer)).intersection(CGRect(x:0,y:0,width:page.width,height:page.height)).integral
            guard !rect.isEmpty else{continue}
            let raw=work.appendingPathComponent(layer.id.uuidString+".rgba");fm.createFile(atPath:raw.path,contents:nil);let file=try FileHandle(forWritingTo:raw);defer{try? file.close()}
            var copy=layer;copy.isVisible=true;copy.opacity=1;copy.blend = .normal
            for y in stride(from:0,to:Int(rect.height),by:256){let rows=min(256,Int(rect.height)-y);var bytes=[UInt8](repeating:0,count:Int(rect.width)*rows*4)
                let ok=bytes.withUnsafeMutableBytes{buffer->Bool in guard let ctx=CGContext(data:buffer.baseAddress,width:Int(rect.width),height:rows,bitsPerComponent:8,bytesPerRow:Int(rect.width)*4,space:ImagePipeline.space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false};ctx.translateBy(x:-rect.minX,y:CGFloat(rows)+rect.minY+CGFloat(y));ctx.scaleBy(x:1,y:-1);LayerRenderer.draw([copy],in:ctx,directory:directory);return true}
                guard ok else{throw ImageFailure.message("تعذر رسم طبقة PSD")}
                for offset in stride(from:0,to:bytes.count,by:4){let alpha=Int(bytes[offset+3]);if alpha>0{for channel in 0..<3{bytes[offset+channel]=UInt8(min(255,(Int(bytes[offset+channel])*255+alpha/2)/alpha))}}}
                try file.write(contentsOf:Data(bytes))
            }
            items.append(Item(layer:layer,rect:rect,raw:raw))
        }
        items.reverse()
        var records=Data();records.i16(-Int16(items.count))
        var pixels:UInt64=0
        for item in items {
            let r=item.rect;records.i32(Int32(r.minY));records.i32(Int32(r.minX));records.i32(Int32(r.maxY));records.i32(Int32(r.maxX));records.u16(4)
            for channel:Int16 in [-1,0,1,2]{records.i16(channel);records.u32(UInt32(Int(r.width*r.height)+2))}
            records.ascii("8BIM");records.ascii(blend(item.layer.blend));records.append(UInt8(min(255,max(0,item.layer.opacity*255))));records.append(0);records.append(item.layer.isVisible ? 0:2);records.append(0)
            var extra=Data();extra.u32(0);extra.u32(0)
            let name=item.layer.name,encoded=Data(name.utf8.prefix(255));extra.append(UInt8(encoded.count));extra.append(encoded);while extra.count%4 != 0{extra.append(0)}
            var unicode=Data();unicode.u32(UInt32(name.utf16.count));for character in name.utf16{unicode.u16(character)}
            extra.ascii("8BIM");extra.ascii("luni");extra.u32(UInt32(unicode.count));extra.append(unicode);if unicode.count%2 != 0{extra.append(0)}
            records.u32(UInt32(extra.count));records.append(extra)
            pixels+=UInt64(Int(r.width*r.height)*4+8)
        }
        let infoLength=UInt64(records.count)+pixels,paddedLength=infoLength+(infoLength%2)
        guard paddedLength+8<UInt64(UInt32.max) else{throw ImageFailure.message("ملف PSD كبير جدًا")}
        let output=fm.temporaryDirectory.appendingPathComponent("Cookies-\(page.id)-\(UUID()).psd");fm.createFile(atPath:output.path,contents:nil);let file=try FileHandle(forWritingTo:output);defer{try? file.close()}
        var header=Data();header.ascii("8BPS");header.u16(1);header.append(Data(repeating:0,count:6));header.u16(4);header.u32(UInt32(page.height));header.u32(UInt32(page.width));header.u16(8);header.u16(3);header.u32(0)
        var resources=Data();var profileLength=0
        if let profile=LICopyPNGProfile(directory.appendingPathComponent(page.source).path,&profileLength){resources.ascii("8BIM");resources.u16(1039);resources.u16(0);resources.u32(UInt32(profileLength));resources.append(Data(bytes:profile,count:profileLength));if profileLength%2 != 0{resources.append(0)};LIFreeBuffer(profile)}
        header.u32(UInt32(resources.count));header.append(resources);header.u32(UInt32(paddedLength+8));header.u32(UInt32(paddedLength));header.append(records);try file.write(contentsOf:header)
        for item in items{for channel in [3,0,1,2]{try file.write(contentsOf:Data([0,0]));try plane(item.raw,width:Int(item.rect.width),height:Int(item.rect.height),channel:channel,to:file)}}
        if infoLength%2 != 0{try file.write(contentsOf:Data([0]))};try file.write(contentsOf:Data([0,0,0,0,0,0])) // global mask length, then merged compression
        for channel in 0..<4{try plane(merged,width:page.width,height:page.height,channel:channel,to:file)}
        return output
    }
    static func plane(_ input:URL,width:Int,height:Int,channel:Int,to output:FileHandle)throws {
        for y in stride(from:0,to:height,by:256){let rows=min(256,height-y),rgba=try ImagePipeline.tile(input,width:width,height:height,rect:CGRect(x:0,y:y,width:width,height:rows));var bytes=[UInt8](repeating:0,count:width*rows);for i in bytes.indices{bytes[i]=rgba[i*4+channel]};try output.write(contentsOf:Data(bytes))}
    }
    static func blend(_ value:Blend)->String {switch value{case .normal:"norm";case .multiply:"mul ";case .screen:"scrn";case .overlay:"over";case .darken:"dark";case .lighten:"lite";case .difference:"diff";case .add:"lddg"}}
}
private extension Data {
    mutating func ascii(_ string:String){append(contentsOf:string.utf8)}
    mutating func u16(_ value:UInt16){append(UInt8(truncatingIfNeeded:value>>8));append(UInt8(truncatingIfNeeded:value))}
    mutating func i16(_ value:Int16){u16(UInt16(bitPattern:value))}
    mutating func u32(_ value:UInt32){for shift in [24,16,8,0]{append(UInt8(truncatingIfNeeded:value>>shift))}}
    mutating func i32(_ value:Int32){u32(UInt32(bitPattern:value))}
}
