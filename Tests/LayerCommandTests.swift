import XCTest
import UIKit
@testable import CookiesEditor

final class LayerCommandTests:XCTestCase {
    private func fixture()throws->(EditorPage,URL,URL){
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:96,height:128),format:format).image{c in UIColor.red.setFill();c.fill(CGRect(x:0,y:0,width:96,height:128))}
        let source=root.appendingPathComponent("input.png");try XCTUnwrap(image.pngData()).write(to:source)
        let page=try ImagePipeline.importImage(source,root:root)
        return(page,root,root.appendingPathComponent(page.id.uuidString))
    }
    private func rectangle(_ color:String)->EditorLayer{
        var l=EditorLayer(kind:.shape,name:color);l.frame=Box(x:0,y:0,width:96,height:128);l.style.color=color;l.style.strokeWidth=0;return l
    }
    private func sample(_ page:EditorPage,_ directory:URL,_ x:Int=48,_ y:Int=64)throws->[UInt8]{
        let image=try ImagePipeline.compositeRegion(page,directory:directory,rect:CGRect(x:x,y:y,width:1,height:1))
        var bytes=[UInt8](repeating:0,count:4)
        let context=try XCTUnwrap(CGContext(data:&bytes,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image,in:CGRect(x:0,y:0,width:1,height:1));return bytes
    }
    func testErasingImageRevealsOnlyLowerLayerAndNeverChangesSource()throws{
        var (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let original=try Data(contentsOf:directory.appendingPathComponent(page.raw)),source=try Data(contentsOf:directory.appendingPathComponent(page.source))
        var image=EditorLayer(kind:.image);image.imagePath=page.source;image.frame=Box(x:0,y:0,width:96,height:128)
        image.appendEditorStroke(Stroke(points:[Point(x:48,y:64)],width:24,color:"FFFFFF",erase:true))
        page.baseHidden=true;page.layers=[rectangle("0000FF"),image]
        let center=try sample(page,directory),outside=try sample(page,directory,4,4)
        XCTAssertGreaterThan(center[2],245);XCTAssertLessThan(center[0],10)
        XCTAssertGreaterThan(outside[0],245);XCTAssertLessThan(outside[2],10)
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.raw)),original)
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),source)
    }
    func testPartialOpacityErasureIsPartialAndGroupOpacityAppliesOnce()throws{
        var (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        var layer=rectangle("FFFFFF");layer.opacity=0.5
        layer.appendEditorStroke(Stroke(points:[Point(x:48,y:64)],width:24,color:"000000",erase:true,opacity:0.5))
        page.baseHidden=true;page.layers=[layer]
        let center=try sample(page,directory),outside=try sample(page,directory,4,4)
        XCTAssertEqual(Double(outside[3]),128,accuracy:2);XCTAssertEqual(Double(center[3]),64,accuracy:2)
    }
    func testEraserRoutingPreservesEditableTextAndDrawingHistory()throws{
        let mark=Stroke(points:[Point(x:20,y:20)],width:12,color:"000000",erase:true)
        for kind in LayerKind.allCases{
            var layer=EditorLayer(kind:kind);layer.textContent="حوار قابل للتعديل";let original=layer.textContent
            layer.appendEditorStroke(mark)
            XCTAssertEqual(layer.textContent,original)
            XCTAssertEqual(layer.erasures?.count ?? 0,[LayerKind.drawing,.image].contains(kind) ? 0:1)
            XCTAssertEqual(layer.strokes.count,[LayerKind.drawing,.image].contains(kind) ? 1:0)
            XCTAssertEqual(try JSONDecoder().decode(EditorLayer.self,from:JSONEncoder().encode(layer)),layer)
        }
    }
    @MainActor func testPromotingBaseForEraserReferencesOriginalAndUndoRestoresDocument()throws{
        let (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let source=try Data(contentsOf:directory.appendingPathComponent(page.source)),raw=try Data(contentsOf:directory.appendingPathComponent(page.raw))
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()}
        XCTAssertTrue(model.prepareEraserTarget());XCTAssertEqual(model.active?.kind,.image);XCTAssertEqual(model.active?.imagePath,page.source)
        XCTAssertEqual(model.page.baseHidden,true);XCTAssertEqual(model.active?.imagePixelFile,page.raw)
        model.undo();XCTAssertEqual(model.page.layers,page.layers);XCTAssertEqual(model.page.baseHidden,page.baseHidden)
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),source);XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.raw)),raw)
    }
    @MainActor func testLockedAndHiddenTargetsNeverCreateAnEmptyDrawingLayer()throws{
        var (page,root,_)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        var layer=EditorLayer(kind:.text);layer.isLocked=true;page.layers=[layer]
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()};model.selected=layer.id
        XCTAssertFalse(model.prepareEraserTarget());XCTAssertEqual(model.page.layers,[layer]);XCTAssertTrue(model.undoStack.isEmpty)
        model.page.layers[0].isLocked=false;model.page.layers[0].isVisible=false
        XCTAssertFalse(model.prepareEraserTarget());XCTAssertEqual(model.page.layers.count,1)
    }
    @MainActor func testDuplicateStaysAboveItsSourceWithoutMovingAndCommandsAreUndoable()throws{
        var (page,root,_)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        var first=EditorLayer(kind:.text);first.textContent="الأصل";first.frame.x=17;first.rotation=30
        let top=EditorLayer(kind:.shape);page.layers=[first,top]
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()};model.selected=first.id
        model.duplicate();let copy=try XCTUnwrap(model.active)
        XCTAssertEqual(model.page.layers.map(\.id),[first.id,copy.id,top.id]);XCTAssertEqual(copy.frame,first.frame);XCTAssertEqual(copy.rotation,30)
        model.renameLayer(copy.id,to:"اختبار");XCTAssertEqual(model.active?.name,"اختبار");XCTAssertEqual(model.active?.textContent,"الأصل")
        model.flipActiveLayer(horizontal:true);XCTAssertEqual(model.active?.scaleX,-1)
        model.moveActiveLayer(by:1);XCTAssertEqual(model.page.layers.last?.id,copy.id)
        model.undo();XCTAssertEqual(model.page.layers[1].id,copy.id)
    }
    @MainActor func testClearAndRestoreImageMaskRemainEditableAfterReopening()throws{
        var (page,root,_)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let layer=rectangle("00FF00");page.layers=[layer];page.baseHidden=true
        let library=LibraryStore(root:root),model=EditorModel(page:page,library:library);defer{model.cancelPendingSaves()};model.selected=layer.id
        model.clearActiveLayer();model.save();XCTAssertEqual(model.page.layers.count,1)
        XCTAssertEqual(try sample(model.page,model.directory)[3],0)
        XCTAssertEqual(try library.load(page.id).layers.first?.erasures?.count,1)
        model.restoreActiveErasure();XCTAssertGreaterThan(try sample(model.page,model.directory)[1],245)
    }
    @MainActor func testTransparentLayerExportAndRasterizationKeepSourceAndVisibleResult()async throws{
        var (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        var layer=rectangle("00FF00");layer.frame=Box(x:20,y:20,width:40,height:60);page.layers=[layer]
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()};model.selected=layer.id
        let original=try Data(contentsOf:directory.appendingPathComponent(page.source))
        let exported=await model.exportActiveLayerPNG();let output=try XCTUnwrap(exported);defer{try? FileManager.default.removeItem(at:output)}
        let result=try XCTUnwrap(UIImage(contentsOfFile:output.path)?.cgImage);XCTAssertEqual(result.width,96);XCTAssertEqual(result.height,128)
        let before=try sample(model.page,directory,40,40)
        await model.rasterizeActiveLayer();XCTAssertNil(model.error);XCTAssertEqual(model.active?.kind,.image)
        XCTAssertEqual(try sample(model.page,directory,40,40),before);XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),original)
        model.undo();XCTAssertEqual(model.page.layers,[layer])
    }
    @MainActor func testPhotoLayerImportPreservesNativePixelsAndInsertsAboveSelection()async throws{
        var (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let lower=EditorLayer(kind:.text),upper=EditorLayer(kind:.shape);page.layers=[lower,upper]
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()};model.selected=lower.id
        let source=directory.appendingPathComponent(page.source),original=try Data(contentsOf:source)
        await model.importImageLayer(source)
        XCTAssertNil(model.error);let imported=try XCTUnwrap(model.active)
        XCTAssertEqual(model.page.layers.map(\.id),[lower.id,imported.id,upper.id]);XCTAssertEqual(imported.kind,.image)
        let provider=try ImageAssetPixels.provider(imported,directory:directory)
        XCTAssertEqual(provider.width,96);XCTAssertEqual(provider.height,128)
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(imported.imagePath)),original)
        model.undo();XCTAssertEqual(model.page.layers,[lower,upper]);XCTAssertEqual(try Data(contentsOf:source),original)
    }
}

extension LayerCommandTests {
    @MainActor func testBrushReusesSelectedImageOrExistingDrawingAcrossRepeatedTouches()throws{
        var (page,root,_)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()}
        for _ in 0..<20{XCTAssertTrue(model.prepareBrushTarget());model.change{$0.appendEditorStroke(Stroke(points:[Point(x:20,y:20)],width:4,color:"FFFFFF"))}}
        XCTAssertEqual(model.page.layers.count,1);XCTAssertEqual(model.active?.strokes.count,20)
        model.selected=nil;XCTAssertTrue(model.prepareBrushTarget());XCTAssertEqual(model.page.layers.count,1)
        var image=EditorLayer(kind:.image);image.imagePath=page.source;image.frame=Box(x:0,y:0,width:96,height:128);page.layers=[image];model.page=page;model.selected=image.id
        XCTAssertTrue(model.prepareBrushTarget());XCTAssertEqual(model.active?.id,image.id);XCTAssertEqual(model.page.layers.count,1)
    }
    func testImagePaintAndEraseStayChronologicalAndExportDoesNotBypassThem()throws{
        var (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let source=try Data(contentsOf:directory.appendingPathComponent(page.source))
        var image=EditorLayer(kind:.image);image.isWorkingImage=true;image.imagePath=page.source;image.imagePixelFile=page.raw;image.imagePixelWidth=page.width;image.imagePixelHeight=page.height;image.frame=Box(x:0,y:0,width:96,height:128)
        image.appendEditorStroke(Stroke(points:[Point(x:48,y:64)],width:30,color:"FFFFFF"))
        image.appendEditorStroke(Stroke(points:[Point(x:48,y:64)],width:10,color:"000000",erase:true))
        page.baseHidden=true;page.layers=[image]
        XCTAssertLessThan(try sample(page,directory)[3],5)
        XCTAssertGreaterThan(try sample(page,directory,58,64)[1],245)
        let file=try ImagePipeline.exportPNG(page,directory:directory);defer{try? FileManager.default.removeItem(at:file)}
        XCTAssertNotEqual(try Data(contentsOf:file),source,"Working-image shortcut must include edits")
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),source)
    }
    @MainActor func testTyperObjectsShareLayerButStayIndividuallyEditable()throws{
        let (page,root,_)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()}
        let ids=try model.insertDialogues([("الأول",.plainText()),("الثاني",.plainText())])
        XCTAssertEqual(model.page.layers.count,2);XCTAssertEqual(Set(model.page.layers.compactMap(\.stackID)).count,1)
        _ = try model.insertDialogues([("الثالث",.plainText())]);XCTAssertEqual(Set(model.page.layers.compactMap(\.stackID)).count,1)
        model.selected=ids[0];model.change{$0.textContent="نص معدل"};XCTAssertEqual(model.page.layers[1].textContent,"الثاني")
        model.setStackVisibility(ids[0],false);XCTAssertTrue(model.page.layers.allSatisfy{!$0.isVisible})
        model.undo();XCTAssertTrue(model.page.layers.allSatisfy(\.isVisible))
        model.selected=ids[0];model.stackSelection=true;model.delete();XCTAssertTrue(model.page.layers.isEmpty)
        model.undo();XCTAssertEqual(model.page.layers.count,3)
    }
}

extension LayerCommandTests {
    @MainActor func testRasterFillCommandsReuseLayerAndCanBeErasedWithoutHarmingSource()async throws{
        let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let source=try Data(contentsOf:directory.appendingPathComponent(page.source)),model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()}
        model.brushColor="FFFFFF";await model.fillBucket(at:CGPoint(x:20,y:20));XCTAssertNil(model.error)
        XCTAssertEqual(model.page.layers.count,1);XCTAssertEqual(model.active?.strokes.first?.brush,"image-patch")
        XCTAssertGreaterThan(try sample(model.page,directory)[1],245)
        let id=try XCTUnwrap(model.selected);model.brushColor="0000FF";await model.fillBucket(at:CGPoint(x:20,y:20))
        XCTAssertEqual(model.page.layers.count,1);XCTAssertEqual(model.selected,id);XCTAssertEqual(model.active?.strokes.count,2)
        XCTAssertGreaterThan(try sample(model.page,directory)[2],245)
        model.change{$0.appendEditorStroke(Stroke(points:[Point(x:48,y:64)],width:20,color:"000000",erase:true))}
        let pixel=try sample(model.page,directory);XCTAssertGreaterThan(pixel[0],245);XCTAssertLessThan(pixel[2],10,"Erasing ink reveals the red source, not black paint")
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),source)
        let archive=try ProjectArchive.export(model.page,directory:directory);defer{try? FileManager.default.removeItem(at:archive)}
        let target=root.appendingPathComponent("restored");try FileManager.default.createDirectory(at:target,withIntermediateDirectories:true)
        let restored=try ProjectArchive.importFile(archive,root:target)
        XCTAssertEqual(restored.layers[0].strokes.count,3);XCTAssertEqual(try sample(restored,target.appendingPathComponent(restored.id.uuidString)),pixel)
    }
}

extension LayerCommandTests {
    @MainActor func testLegacyTextStackMigrationDoesNotInventUserUndoHistory()throws{
        var(page,root,_)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        var first=EditorLayer(kind:.text),second=EditorLayer(kind:.text);first.textContent="الأول";second.textContent="الثاني";page.layers=[first,second]
        let model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()};model.organizeLegacyTextLayers()
        XCTAssertEqual(model.logicalLayerCount,1);XCTAssertTrue(model.undoStack.isEmpty);XCTAssertEqual(model.page.layers.map(\.textContent),page.layers.map(\.textContent))
        let migrated=model.page;model.organizeLegacyTextLayers();XCTAssertEqual(model.page,migrated)
    }
}

extension LayerCommandTests {
    @MainActor func testBaseEraserWhitensPaperInPreviewAndExportWhileLayerPNGStaysTransparent()async throws{
        let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let original=try Data(contentsOf:directory.appendingPathComponent(page.source)),model=EditorModel(page:page,library:LibraryStore(root:root));defer{model.cancelPendingSaves()}
        XCTAssertTrue(model.prepareEraserTarget());XCTAssertEqual(model.page.paperWhite,true)
        model.change{$0.appendEditorStroke(Stroke(points:[Point(x:48,y:64)],width:24,color:"000000",erase:true))}
        XCTAssertEqual(try sample(model.page,directory),[255,255,255,255])
        let export=try ImagePipeline.exportPNG(model.page,directory:directory);defer{try? FileManager.default.removeItem(at:export)}
        let bytes=try BigLaMaSession.rgba(XCTUnwrap(UIImage(contentsOfFile:export.path)?.cgImage)),center=(64*96+48)*4
        XCTAssertEqual(Array(bytes[center..<center+4]),[255,255,255,255])
        let layerFile=await model.exportActiveLayerPNG();let layerPNG=try XCTUnwrap(layerFile);defer{try? FileManager.default.removeItem(at:layerPNG)}
        let layerBytes=try BigLaMaSession.rgba(XCTUnwrap(UIImage(contentsOfFile:layerPNG.path)?.cgImage));XCTAssertEqual(layerBytes[center+3],0)
        model.setPaperWhite(false);XCTAssertEqual(try sample(model.page,directory)[3],0)
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),original)
    }
}
