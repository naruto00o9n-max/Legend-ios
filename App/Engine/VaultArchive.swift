import Foundation
import ZIPFoundation
import CryptoKit

struct VaultChunk:Codable,Equatable {var bytes:Int;var sha256:String}
struct VaultHead:Codable,Equatable {
    var version=1;var title:String;var bytes:Int;var sha256:String;var chunks:[VaultChunk];var width:Int;var height:Int
    func validate()throws {
        let hex=CharacterSet(charactersIn:"0123456789abcdef")
        func validHash(_ value:String)->Bool{value.count==64 && value.unicodeScalars.allSatisfy(hex.contains)}
        guard version==1,title.count<=256,bytes>0,bytes<=VaultArchive.limit,width>0,height>0,width<=32768,height<=1000000,Int64(width)*Int64(height)<=200_000_000,validHash(sha256),chunks.count==(bytes+VaultArchive.chunkSize-1)/VaultArchive.chunkSize else{throw ImageFailure.message("فهرس المشروع المحفوظ غير صالح")}
        for (i,c) in chunks.enumerated(){guard c.bytes==min(VaultArchive.chunkSize,bytes-i*VaultArchive.chunkSize),validHash(c.sha256) else{throw ImageFailure.message("أجزاء المشروع غير متطابقة")}}
    }
}
/// Streams assets directly into ZIP. Rebuildable RGBA, thumbnails of discarded
/// edits and unreferenced intermediate images never consume remote capacity.
enum VaultArchive {
    static let chunkSize=8*1024*1024,limit=128*1024*1024
    static func assets(_ page:EditorPage)->Set<String> {
        var paths:Set<String>=[page.source]
        for layer in page.layers{for path in [layer.imagePath,layer.style.texturePath]+(layer.strokes+(layer.erasures ?? [])).compactMap(\.texturePath) where !path.isEmpty{paths.insert(path)}}
        return paths
    }
    static func create(_ page:EditorPage,directory:URL)throws->(URL,VaultHead) {
        guard AppStorageManager.validPage(page),Int64(page.width)*Int64(page.height)<=200_000_000,LIValidatePNG(directory.appendingPathComponent(page.source).path,Int32(page.width),Int32(page.height))==1 else{throw ImageFailure.message("تعذر التحقق من الصورة الأصلية قبل الرفع")}
        let output=FileManager.default.temporaryDirectory.appendingPathComponent("vault-"+UUID().uuidString+".zip")
        do{
            let archive=try Archive(url:output,accessMode:.create)
            let json=try JSONEncoder().encode(page)
            try archive.addEntry(with:"page.json",type:.file,uncompressedSize:Int64(json.count),compressionMethod:.deflate){position,size in json.subdata(in:Int(position)..<min(json.count,Int(position)+size))}
            for path in assets(page).sorted(){try Task.checkCancellation();guard AppStorageManager.safe(path),!path.contains("/"),path != page.raw,!path.hasSuffix(".rgba") else{throw ImageFailure.message("أصل غير صالح للحفظ")};try archive.addEntry(with:path,fileURL:directory.appendingPathComponent(path),compressionMethod:.none)}
            let used=Set(page.layers.map{ $0.style.fontPath })
            for font in Fonts.userFiles where used.contains(font.lastPathComponent){try archive.addEntry(with:"Fonts/"+font.lastPathComponent,fileURL:font,compressionMethod:.none)}
            // ZIPFoundation writes the central directory as entries are added.
            return(output,try manifest(output,page:page))
        }catch{try? FileManager.default.removeItem(at:output);throw error}
    }
    static func manifest(_ file:URL,page:EditorPage)throws->VaultHead {
        let handle=try FileHandle(forReadingFrom:file);defer{try? handle.close()};var chunks:[VaultChunk]=[],total=0,hash=SHA256()
        while let data=try handle.read(upToCount:chunkSize),!data.isEmpty{try Task.checkCancellation();total+=data.count;guard total<=limit else{throw ImageFailure.message("يتجاوز هذا المشروع حد النقل الحالي، 128 ميغابايت؛ بقي محفوظًا على جهازك")};hash.update(data:data);chunks.append(VaultChunk(bytes:data.count,sha256:SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()))}
        let head=VaultHead(title:String(page.title.prefix(256)),bytes:total,sha256:hash.finalize().map{String(format:"%02x",$0)}.joined(),chunks:chunks,width:page.width,height:page.height);try head.validate();return head
    }
    static func unpack(_ file:URL,head:VaultHead,id:UUID,staging:URL)throws->EditorPage {
        try head.validate();guard try AppStorageManager.hash(file)==head.sha256 else{throw ImageFailure.message("لم يكتمل تنزيل المشروع بصورة سليمة؛ أعد المحاولة")}
        let archive=try Archive(url:file,accessMode:.read);var names=Set<String>(),total:UInt64=0
        for entry in archive{
            guard entry.uncompressedSize<=512*1024*1024-total else{throw ImageFailure.message("أصول المشروع أكبر من الحد المدعوم")}
            total+=entry.uncompressedSize
            guard names.count<4096,total<=512*1024*1024,names.insert(entry.path).inserted,entry.type == .file,AppStorageManager.safe(entry.path),!entry.path.hasSuffix(".rgba"),entry.path.split(separator:"/").count==1 || (entry.path.hasPrefix("Fonts/") && entry.path.split(separator:"/").count==2) else{throw ImageFailure.message("أصول المشروع غير صالحة للاستعادة")}
        }
        try FileManager.default.createDirectory(at:staging,withIntermediateDirectories:true)
        do{
            try FileManager.default.unzipItem(at:file,to:staging)
            guard let data=try? Data(contentsOf:staging.appendingPathComponent("page.json")),let page=try? JSONDecoder().decode(EditorPage.self,from:data),page.id==id,AppStorageManager.validPage(page),page.width==head.width,page.height==head.height,assets(page).isSubset(of:names),LIValidatePNG(staging.appendingPathComponent(page.source).path,Int32(page.width),Int32(page.height))==1 else{throw ImageFailure.message("لا تتطابق أصول المشروع مع فهرسه")}
            let fonts=names.filter{$0.hasPrefix("Fonts/")};for name in fonts{guard ["ttf","otf"].contains(URL(fileURLWithPath:name).pathExtension.lowercased()) else{throw ImageFailure.message("ملف خط غير صالح")}}
            return page
        }catch{try? FileManager.default.removeItem(at:staging);throw error}
    }
}
