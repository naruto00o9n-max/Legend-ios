import XCTest
import UIKit
@testable import CookiesEditor

final class BatchToolTests:XCTestCase {
    func testReferenceBrushAssetsArePackagedAndUsableTextureProducesTintedAlphaStamps()throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)}
        for name in ["censor"]+(1...8).map({"b\($0)"}) {
            let source=try XCTUnwrap(Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Brushes") ?? Bundle.main.url(forResource:name,withExtension:"png")),asset=root.appendingPathComponent(name+".png");try FileManager.default.copyItem(at:source,to:asset)
            let format=UIGraphicsImageRendererFormat();format.scale=1
            let image=UIGraphicsImageRenderer(size:CGSize(width:100,height:100),format:format).image{out in BrushRenderer.draw(Stroke(points:[Point(x:25,y:50),Point(x:75,y:50)],width:20,color:"FF0000",brush:"texture",texturePath:name+".png"),in:out.cgContext,directory:root)}
            let file=root.appendingPathComponent("test-"+name+".png");try XCTUnwrap(image.pngData()).write(to:file);let bytes=try rgba(file)
            let visible=stride(from:0,to:bytes.count,by:4).filter{bytes[$0+3]>128}
            if name != "censor"{XCTAssertTrue(visible.isEmpty,"Original APK contains transparent reserved brush slots; UI must not advertise them as functioning presets");continue}
            XCTAssertFalse(visible.isEmpty,name)
            for i in visible{XCTAssertGreaterThan(bytes[i],230);XCTAssertLessThan(bytes[i+1],15);XCTAssertLessThan(bytes[i+2],15)}
            XCTAssertEqual(bytes[3],0,"Brush texture must not paint the canvas rectangle")
        }
    }
    @MainActor func testGroupedLayersMoveTogetherAndUndoAsOneEdit()throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try PageOperations.blank(title:"مجموعة",width:200,height:300,color:"FFFFFF",transparent:false,root:root)
        let group=UUID();var a=EditorLayer(kind:.shape);a.frame=Box(x:10,y:20,width:30,height:30);a.groupID=group;var b=a;b.id=UUID();b.frame.x=80;b.frame.y=100;page.layers=[a,b];try library.persist(page)
        let model=EditorModel(page:page,library:library);model.selected=a.id;model.checkpoint();model.change(persist:false){$0.frame.x+=25;$0.frame.y+=40};model.transformGroupPeers(from:a,baseline:page.layers);model.save()
        XCTAssertEqual(model.page.layers[1].frame.x,105,accuracy:0.001);XCTAssertEqual(model.page.layers[1].frame.y,140,accuracy:0.001);model.undo();XCTAssertEqual(model.page.layers,page.layers)
    }
    @MainActor func testFilteredReorderingKeepsOtherLayerTypesAtTheirPositions()throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)};let library=LibraryStore(root:root);var page=try PageOperations.blank(title:"ترتيب",width:100,height:200,color:"FFFFFF",transparent:false,root:root)
        let a=EditorLayer(kind:.text),b=EditorLayer(kind:.image),c=EditorLayer(kind:.text),d=EditorLayer(kind:.image),e=EditorLayer(kind:.text);page.layers=[a,b,c,d,e];try library.persist(page)
        let model=EditorModel(page:page,library:library);model.reorderLayers(kind:.text,from:IndexSet(integer:0),to:3)
        XCTAssertEqual(model.page.layers.map(\.id),[e.id,b.id,a.id,d.id,c.id]);model.undo();XCTAssertEqual(model.page.layers,page.layers)
    }
    @MainActor func testNonUniformGroupResizePreservesRotatedPeerAffineCorners()throws {
        let root=try root();defer{try? FileManager.default.removeItem(at:root)};let library=LibraryStore(root:root);var page=try PageOperations.blank(title:"مجموعة",width:400,height:600,color:"FFFFFF",transparent:false,root:root)
        let group=UUID();var a=EditorLayer(kind:.shape);a.groupID=group;a.frame=Box(x:10,y:20,width:80,height:90);var b=a;b.id=UUID();b.rotation=35;b.frame.x=180;b.frame.y=200;page.layers=[a,b];try library.persist(page)
        let model=EditorModel(page:page,library:library);model.selected=a.id;model.change(persist:false){$0.scaleX=1.7;$0.scaleY=0.6};let delta=LayerRenderer.transform(a).inverted().concatenating(LayerRenderer.transform(try XCTUnwrap(model.active)));model.transformGroupPeers(from:a,baseline:page.layers)
        let transformed=LayerRenderer.transform(model.page.layers[1]);for point in [CGPoint.zero,CGPoint(x:80,y:0),CGPoint(x:80,y:90),CGPoint(x:0,y:90)]{let expected=point.applying(LayerRenderer.transform(b)).applying(delta),actual=point.applying(transformed);XCTAssertEqual(actual.x,expected.x,accuracy:0.0001);XCTAssertEqual(actual.y,expected.y,accuracy:0.0001)}
        XCTAssertNotNil(model.page.layers[1].shearX)
    }
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
