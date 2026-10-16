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
            XCTAssertEqual(layer.erasures?.count ?? 0,kind == .drawing ? 0:1)
            XCTAssertEqual(layer.strokes.count,kind == .drawing ? 1:0)
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
