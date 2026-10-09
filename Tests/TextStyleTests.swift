import XCTest
import UIKit
@testable import CookiesEditor

final class TextStyleTests:XCTestCase {
    private func raster(_ layer:EditorLayer,directory:URL)->[UInt8] {
        var bytes=[UInt8](repeating:0,count:400*240*4)
        bytes.withUnsafeMutableBytes{buffer in
            let context=CGContext(data:buffer.baseAddress,width:400,height:240,bitsPerComponent:8,bytesPerRow:400*4,space:ImagePipeline.space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.translateBy(x:0,y:240);context.scaleBy(x:1,y:-1)
            LayerRenderer.draw([layer],in:context,directory:directory)
        }
        return bytes
    }
    func testGradientPreservesGlyphAlphaAndEmptyLetterHoles() throws {
        var layer=EditorLayer(kind:.text);layer.textContent="OO";layer.frame.x=50;layer.frame.y=40;layer.style.boxWidth=250;layer.style.fontSize=88;layer.style.strokeWidth=0;layer.style.color="FFFFFF"
        let dir=FileManager.default.temporaryDirectory
        let plain=raster(layer,directory:dir)
        layer.style.textGradient=["FF0000","0000FF"]
        let gradient=raster(layer,directory:dir)
        var changed=0,painted=0
        for index in stride(from:0,to:plain.count,by:4){
            XCTAssertEqual(Double(gradient[index+3]),Double(plain[index+3]),accuracy:1,"Gradient may change glyph RGB, never paint its bounding rectangle")
            if plain[index+3]==0{XCTAssertEqual(gradient[index+3],0)}else{painted+=1;if gradient[index] != plain[index] || gradient[index+2] != plain[index+2]{changed+=1}}
        }
        XCTAssertGreaterThan(painted,500);XCTAssertGreaterThan(changed,500)
    }
    @MainActor func testSavedStyleSurvivesProjectRemovalAndKeepsTextAndPosition() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),store=StyleStore(directory:root.appendingPathComponent("style-library"))
        let page=try ImagePipeline.fixture(root:root);library.add(page,parent:nil)
        let model=EditorModel(page:page,library:library);model.add(.text);model.change{$0.textContent="حوار أول";$0.style.color="AA1188";$0.style.fontSize=53;$0.style.textGradient=["FF0000","0000FF"]}
        let id=try store.save(title:"نمط المستخدم",group:"حوار",layer:try XCTUnwrap(model.active),from:model.directory)
        let reloaded=StyleStore(directory:store.directory);XCTAssertEqual(reloaded.styles.first?.id,id)
        model.add(.text);model.change{$0.textContent="النص الجديد";$0.frame.x=321;$0.style.boxWidth=220}
        try reloaded.apply(try XCTUnwrap(reloaded.styles.first),to:model)
        XCTAssertEqual(model.active?.textContent,"النص الجديد");XCTAssertEqual(model.active?.frame.x,321)
        XCTAssertEqual(model.active?.style.boxWidth,220);XCTAssertEqual(model.active?.style.fontSize,53)
        let package=try reloaded.export();let imported=StyleStore(directory:root.appendingPathComponent("imported-styles"))
        try imported.importPackage(package);XCTAssertEqual(imported.styles.count,1);XCTAssertEqual(imported.styles.first?.style.textGradient,["FF0000","0000FF"])
        try reloaded.rename(id,title:"حوار خاص",group:"فصل أول");try reloaded.duplicate(id);XCTAssertEqual(reloaded.styles.count,2)
        library.remove(try XCTUnwrap(library.items.first));XCTAssertEqual(StyleStore(directory:store.directory).styles.count,2)
    }
    @MainActor func testPerspectiveUsesCanvasHandlesInsteadOfAnIndependentRectangle() {
        var layer=EditorLayer(kind:.text);layer.style.perspectivePoints=[Point(x:0.15,y:0),Point(x:1,y:0.1),Point(x:0.9,y:1),Point(x:0,y:0.85)]
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:600));canvas.deformationMode=true
        canvas.update(page:EditorPage(title:"منظور",width:800,height:600,layers:[layer]),directory:FileManager.default.temporaryDirectory,selected:layer.id,zoom:1)
        let handles=canvas.subviews.compactMap{$0 as? UIButton}.filter{!$0.isHidden}
        XCTAssertEqual(handles.count,4);XCTAssertTrue(handles.allSatisfy{$0.accessibilityIdentifier?.hasPrefix("selection-deform-")==true})
    }
}
