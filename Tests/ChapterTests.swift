import XCTest
import UIKit
import ZIPFoundation
@testable import CookiesEditor

final class ChapterTests:XCTestCase {
    private func root()throws->URL {let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true);return url}
    func testSplitMergeKeepsEverySourceByteAndLayerCoordinates()throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)}
        var page=try PageOperations.build(title:"فصل",width:32,height:520,root:root){y,count in var data=[UInt8](repeating:255,count:32*count*4);for row in 0..<count{for x in 0..<32{data[(row*32+x)*4]=UInt8((y+row)%256);data[(row*32+x)*4+1]=UInt8(x)}};return data}
        var layer=EditorLayer(kind:.text);layer.frame.y=315;layer.textContent="آخر الصفحة";page.layers=[layer];try PageOperations.persist(page,root:root)
        let pieces=try PageOperations.split(page,maximumHeight:260,root:root)
        XCTAssertEqual(pieces.map(\.height),[260,260]);XCTAssertEqual(pieces[1].layers[0].frame.y,55)
        let merged=try PageOperations.merged(pieces,root:root)
        let original=try Data(contentsOf:root.appendingPathComponent(page.id.uuidString).appendingPathComponent(page.raw))
        XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent(merged.id.uuidString).appendingPathComponent(merged.raw)),original)
        XCTAssertEqual(merged.width,32);XCTAssertEqual(merged.height,520)
    }
    @MainActor func testChapterOrderCoverHistoryAndArchiveSurviveRestart()async throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),id=try library.createChapter("الفصل الأول",parent:nil)
        let one=try PageOperations.blank(title:"أ",width:32,height:50,color:"FF0000",transparent:false,root:root)
        let two=try PageOperations.blank(title:"ب",width:32,height:60,color:"0000FF",transparent:false,root:root)
        library.add(one,parent:id);library.add(two,parent:id);try library.setCover(two.id,chapter:id)
        try library.setPages([two.id,one.id],chapter:id)
        XCTAssertEqual(LibraryStore(root:root).chapter(id)?.pages,[two.id,one.id])
        XCTAssertEqual(LibraryStore(root:root).chapter(id)?.cover,two.id)
        try library.restoreChapter(id);XCTAssertEqual(library.chapter(id)?.pages,[one.id,two.id])
        let archive=try ChapterArchive.export(try XCTUnwrap(library.chapter(id)),root:root)
        let restored=try ChapterArchive.importFile(archive,root:root)
        XCTAssertEqual(restored.map(\.title),["أ","ب"]);XCTAssertEqual(restored.map(\.height),[50,60])
        let zip=try BatchExport.export(pages:[one,two],root:root,format:"PNG",progress:{_,_ in})
        let exported=try Archive(url:zip,accessMode:.read);XCTAssertEqual(Array(exported).filter{$0.path.hasSuffix(".png")}.count,2)
    }
    func testPDFTopAndBottomDoNotFlipAndPageCountIsPreserved()throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)}
        let file=root.appendingPathComponent("chapter.pdf")
        UIGraphicsBeginPDFContextToFile(file.path,CGRect(x:0,y:0,width:40,height:300),nil)
        for _ in 0..<2{UIGraphicsBeginPDFPage();UIColor.red.setFill();UIRectFill(CGRect(x:0,y:0,width:40,height:150));UIColor.blue.setFill();UIRectFill(CGRect(x:0,y:150,width:40,height:150))}
        UIGraphicsEndPDFContext()
        let pages=try PageOperations.importPDF(file,root:root,scale:1);XCTAssertEqual(pages.count,2)
        let raw=root.appendingPathComponent(pages[0].id.uuidString).appendingPathComponent(pages[0].raw)
        let top=try ImagePipeline.tile(raw,width:40,height:300,rect:CGRect(x:10,y:10,width:1,height:1))
        let bottom=try ImagePipeline.tile(raw,width:40,height:300,rect:CGRect(x:10,y:290,width:1,height:1))
        XCTAssertGreaterThan(top[0],240);XCTAssertLessThan(top[2],10)
        XCTAssertGreaterThan(bottom[2],240);XCTAssertLessThan(bottom[0],10)
    }
}
