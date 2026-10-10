import XCTest
import UIKit
import ZIPFoundation
@testable import CookiesEditor

final class StorageAndInteractionTests:XCTestCase {
    private func fixture(_ root:URL,title:String)throws->EditorPage{
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:80,height:150),format:format).image{ctx in UIColor.red.setFill();ctx.fill(CGRect(x:0,y:0,width:80,height:150))}
        let file=root.appendingPathComponent(title+".png");try XCTUnwrap(image.pngData()).write(to:file)
        return try ImagePipeline.importImage(file,root:root)
    }
    func testSelectiveBackupRestorePreservesUnselectedProjectsAndRebuildsExactPixels()throws{
        let fm=FileManager.default,root=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString),target=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? fm.removeItem(at:root);try? fm.removeItem(at:target)}
        let first=try fixture(root,title:"first"),second=try fixture(root,title:"second")
        let items=[first,second].map{LibraryItem(id:$0.id,title:$0.title,folder:false,pages:[$0.id])};try JSONEncoder().encode(items).write(to:root.appendingPathComponent("library.json"))
        let directory=root.appendingPathComponent(first.id.uuidString),original=try Data(contentsOf:directory.appendingPathComponent(first.raw))
        let file=try AppStorageManager.createBackup(selected:[first.id.uuidString],at:root);defer{try? fm.removeItem(at:file)}
        let manifest=try AppStorageManager.inspect(file);XCTAssertEqual(manifest.units.count,1);XCTAssertFalse(manifest.files.contains{$0.path.hasSuffix(".rgba")})
        let unselected=try fixture(target,title:"keep");try JSONEncoder().encode([LibraryItem(id:unselected.id,title:"keep",folder:false,pages:[unselected.id])]).write(to:target.appendingPathComponent("library.json"))
        _ = try AppStorageManager.restore(file,selected:[first.id.uuidString],at:target)
        let restored=target.appendingPathComponent(first.id.uuidString);XCTAssertFalse(fm.fileExists(atPath:restored.appendingPathComponent(first.raw).path));XCTAssertTrue(fm.fileExists(atPath:target.appendingPathComponent(unselected.id.uuidString).path));XCTAssertFalse(fm.fileExists(atPath:target.appendingPathComponent(second.id.uuidString).path))
        _ = try ImagePipeline.tile(restored.appendingPathComponent(first.raw),width:first.width,height:first.height,rect:CGRect(x:0,y:0,width:80,height:150))
        XCTAssertEqual(try Data(contentsOf:restored.appendingPathComponent(first.raw)),original)
        XCTAssertEqual(Set(try AppStorageManager.library(at:target).map(\.id)),[first.id,unselected.id])
    }
    func testCacheCleaningCannotDestroyPixelsWhenOriginalIsCorrupt()throws {
        let fm=FileManager.default,root=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? fm.removeItem(at:root)}
        let page=try fixture(root,title:"page"),directory=root.appendingPathComponent(page.id.uuidString),raw=directory.appendingPathComponent(page.raw)
        let original=try Data(contentsOf:raw),source=directory.appendingPathComponent(page.source),png=try Data(contentsOf:source)
        try Data("bad PNG".utf8).write(to:source);XCTAssertThrowsError(try AppStorageManager.cleanDecodedCaches(at:root));XCTAssertEqual(try Data(contentsOf:raw),original)
        try png.write(to:source);try AppStorageManager.cleanDecodedCaches(at:root);XCTAssertFalse(fm.fileExists(atPath:raw.path));_ = try ImagePipeline.tile(raw,width:page.width,height:page.height,rect:CGRect(x:0,y:0,width:80,height:150));XCTAssertEqual(try Data(contentsOf:raw),original)
    }
    func testTamperedBackupFailsBeforeReplacingLocalData()throws {
        let fm=FileManager.default,root=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? fm.removeItem(at:root)}
        let page=try fixture(root,title:"page");try JSONEncoder().encode([LibraryItem(id:page.id,title:"safe",folder:false,pages:[page.id])]).write(to:root.appendingPathComponent("library.json"))
        let file=try AppStorageManager.createBackup(selected:[page.id.uuidString],at:root);defer{try? fm.removeItem(at:file)}
        let archive=try Archive(url:file,accessMode:.update),path=page.id.uuidString+"/"+page.source,entry=try XCTUnwrap(archive[path]);try archive.remove(entry)
        let replacement=root.appendingPathComponent("modified.png");let count=Int(entry.uncompressedSize);try Data(repeating:0,count:count).write(to:replacement);try archive.addEntry(with:path,fileURL:replacement)
        let before=try Data(contentsOf:root.appendingPathComponent("library.json"));XCTAssertThrowsError(try AppStorageManager.restore(file,selected:[page.id.uuidString],at:root));XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("library.json")),before)
    }
    func testInlineTextAlwaysWhiteWithoutChangingLayerColorsOrFont()throws {
        var layer=EditorLayer(kind:.text,name:"test");layer.textContent="نص";layer.style.color="000000";layer.style.fontPath="hayah.ttf";layer.style.spans=[TextRun(start:0,end:1,color:"FF0000")]
        let edited=ArabicTextEditor.presentation(layer)
        edited.enumerateAttribute(.foregroundColor,in:NSRange(location:0,length:edited.length)){value,_,_ in XCTAssertEqual(value as? UIColor,UIColor.white)}
        XCTAssertEqual(layer.style.color,"000000");XCTAssertEqual(layer.style.spans.first?.color,"FF0000");XCTAssertEqual((edited.attribute(.font,at:0,effectiveRange:nil) as? UIFont)?.fontName,Fonts.font(layer.style).fontName)
    }
    @MainActor func testTextOutsideImageRemainsInHitRegion()throws {
        var page=EditorPage(title:"test",width:80,height:150),layer=EditorLayer(kind:.text,name:"outside");layer.textContent="Outside";layer.frame=Box(x:110,y:20,width:120,height:50);layer.style.boxWidth=120;layer.style.fontSize=20;page.layers=[layer]
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:80,height:150));canvas.page=page;canvas.selected=layer.id;canvas.updateSelection()
        XCTAssertTrue(canvas.point(inside:CGPoint(x:120,y:30),with:nil),"Text remains selectable on black workspace")
        XCTAssertFalse(canvas.point(inside:CGPoint(x:1000,y:1000),with:nil))
    }
}
