import XCTest
import UIKit
@testable import CookiesEditor

final class BatchToolTests:XCTestCase {
    private func root()throws->URL{let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true);return url}
    private func rgba(_ file:URL)throws->Data {let raw=file.deletingPathExtension().appendingPathExtension("rgba");defer{try? FileManager.default.removeItem(at:raw)};var width:Int32=0,height:Int32=0,error=[CChar](repeating:0,count:512);XCTAssertEqual(LIImportPNG(file.path,raw.path,&width,&height,&error,error.count),1);return try Data(contentsOf:raw)}
    @MainActor func testNormalMergeAndTransparentFlattenRetainCompositeAndUndo()async throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try PageOperations.build(title:"شفافية",width:80,height:160,root:root){_,rows in Array(repeating:[UInt8(0),200,50,128],count:80*rows).flatMap{$0}}
        var red=EditorLayer(kind:.shape);red.frame=Box(x:10,y:20,width:50,height:60);red.style.color="FF0000";red.style.strokeWidth=0;red.opacity=0.6
        var blue=red;blue.id=UUID();blue.frame.x=25;blue.frame.y=45;blue.style.color="0000FF";page.layers=[red,blue];try library.persist(page)
        let model=EditorModel(page:page,library:library),before=try rgba(ImagePipeline.exportPNG(page,directory:model.directory))
        await model.mergeLayers(Set([red.id,blue.id]));XCTAssertNil(model.error);XCTAssertEqual(model.page.layers.count,1)
        let merged=try rgba(ImagePipeline.exportPNG(model.page,directory:model.directory));XCTAssertEqual(merged.count,before.count)
        XCTAssertLessThanOrEqual(zip(merged,before).map{pair in abs(Int(pair.0)-Int(pair.1))}.max() ?? 0,2)
        model.undo();XCTAssertEqual(model.page.layers,[red,blue])
        await model.flattenLayers();XCTAssertTrue(model.page.baseHidden==true);XCTAssertNil(model.error)
        let flattened=try rgba(ImagePipeline.exportPNG(model.page,directory:model.directory));XCTAssertLessThanOrEqual(zip(flattened,before).map{pair in abs(Int(pair.0)-Int(pair.1))}.max() ?? 0,2)
        model.undo();XCTAssertNil(model.page.baseHidden);XCTAssertEqual(model.page.layers,[red,blue])
    }
    @MainActor func testCleanerPreviewDoesNotCommitBeforeAcceptAndCanCancel()async throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)};let library=LibraryStore(root:root),page=try PageOperations.blank(title:"تنظيف",width:128,height:128,color:"FFFFFF",transparent:false,root:root),model=EditorModel(page:page,library:library)
        await model.clean(Stroke(points:[Point(x:64,y:64)],width:12,color:"FFFFFF"));XCTAssertEqual(model.cleanCandidates.count,3);XCTAssertTrue(model.page.layers.isEmpty);XCTAssertEqual(model.canvasPage.layers.count,1)
        model.discardCleaning();XCTAssertTrue(model.page.layers.isEmpty);XCTAssertTrue(model.cleanCandidates.isEmpty)
        await model.clean(Stroke(points:[Point(x:64,y:64)],width:12,color:"FFFFFF"));model.acceptCleaning();XCTAssertEqual(model.page.layers.count,1);XCTAssertTrue(model.cleanCandidates.isEmpty);model.undo();XCTAssertTrue(model.page.layers.isEmpty)
    }
    func testFillBucketStopsAtClosedBoundary()throws {
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let source=UIGraphicsImageRenderer(size:CGSize(width:100,height:100),format:format).image{out in UIColor.white.setFill();out.fill(CGRect(x:0,y:0,width:100,height:100));UIColor.black.setStroke();let p=UIBezierPath(rect:CGRect(x:20,y:20,width:60,height:60));p.lineWidth=4;p.stroke()}
        let result=try XCTUnwrap(CookiesFillBucket(source,CGPoint(x:50,y:50),.red,0)),file=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png");defer{try? FileManager.default.removeItem(at:file)};try XCTUnwrap(result.pngData()).write(to:file);let bytes=try rgba(file)
        XCTAssertEqual(bytes[(50*100+50)*4],255);XCTAssertEqual(bytes[(50*100+50)*4+3],255);XCTAssertEqual(bytes[(10*100+10)*4+3],0)
    }
}
