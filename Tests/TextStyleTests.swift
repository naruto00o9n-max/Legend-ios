import XCTest
import UIKit
@testable import CookiesEditor

final class TextStyleTests:XCTestCase {
    @MainActor func testGradientHandlesBelongToTheTextAndUseSavedEndpoints(){
        var layer=EditorLayer(kind:.text);layer.frame.x=50;layer.frame.y=60;layer.style.textGradient=["FF0000","0000FF"];layer.style.textGradientPoints=[Point(x:0.2,y:0.3),Point(x:0.8,y:0.7)]
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:600));canvas.gradientMode="text";canvas.update(page:EditorPage(title:"تدرج",width:800,height:600,layers:[layer]),directory:FileManager.default.temporaryDirectory,selected:layer.id,zoom:1)
        let handles=canvas.subviews.compactMap{$0 as? UIButton}.filter{!$0.isHidden};XCTAssertEqual(handles.count,2);XCTAssertTrue(handles.allSatisfy{$0.accessibilityIdentifier?.hasPrefix("selection-gradient-")==true})
        let box=LayerRenderer.bounds(layer),first=handles.first{$0.accessibilityIdentifier=="selection-gradient-start"};XCTAssertEqual(first?.center.x ?? 0,50+box.width*0.2,accuracy:0.01);XCTAssertEqual(first?.center.y ?? 0,60+box.height*0.3,accuracy:0.01)
    }
    func testMeshPaddingIdentityAndResamplingKeepTextCoordinates() {
        var style=TextStyle();style.meshRows=2;style.meshCols=4;style.meshPoints=MeshGeometry.grid(rows:2,cols:4)
        let padded=MeshGeometry.target(x:-0.15,y:1.2,style:style)
        XCTAssertEqual(padded.x,-0.15,accuracy:0.000001);XCTAssertEqual(padded.y,1.2,accuracy:0.000001)
        style.meshPoints=style.meshPoints.map{Point(x:$0.x+0.3,y:$0.y-0.2)}
        let shifted=MeshGeometry.target(x:0.25,y:0.5,style:style)
        XCTAssertEqual(shifted.x,0.55,accuracy:0.000001);XCTAssertEqual(shifted.y,0.3,accuracy:0.000001)
    }
    func testGradientCatalogTargetsTheGlyphOutlineAndShadowIndependently()throws {
        let presets=try GradientPreset.catalog();XCTAssertEqual(presets.count,37)
        let gold=try XCTUnwrap(presets.first{$0.id=="gold_royal_cinematic"});var style=TextStyle()
        gold.apply(to:&style,target:"stroke");XCTAssertTrue(style.textGradient.isEmpty);XCTAssertEqual(style.strokeGradient,gold.colors);XCTAssertTrue(style.shadowGradient.isEmpty)
        gold.apply(to:&style,target:"all");XCTAssertEqual(style.textGradientStops,gold.stops);XCTAssertEqual(style.strokeGradient,gold.stroke);XCTAssertEqual(style.shadowGradient,gold.shadow)
        for preset in presets{XCTAssertEqual(preset.colors.count,preset.stops.count);XCTAssertTrue(preset.stops.allSatisfy{(0...1).contains($0)})}
    }
    @MainActor func testRasterConversionPreservesRotatedScaledDeformedTextAndUndo()async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try PageOperations.blank(title:"نص",width:400,height:240,color:"000000",transparent:true,root:root)
        var text=EditorLayer(kind:.text);text.textContent="OO";text.frame.x=90;text.frame.y=75;text.style.boxWidth=160;text.style.fontSize=50;text.style.strokeWidth=3;text.style.textGradient=["FF0000","0000FF"];text.style.perspectivePoints=[Point(x:-0.2,y:0),Point(x:1.2,y:0),Point(x:1,y:1),Point(x:0,y:1)];text.rotation=18;text.scaleX=1.2;text.scaleY=0.8;page.layers=[text];try library.persist(page)
        let model=EditorModel(page:page,library:library);model.selected=text.id
        let before=raster(text,directory:model.directory);await model.rasterizeText();let converted=try XCTUnwrap(model.active);XCTAssertEqual(converted.kind,.image)
        let after=raster(converted,directory:model.directory)
        var mismatch=0;for i in before.indices where abs(Int(before[i])-Int(after[i]))>8{mismatch+=1}
        XCTAssertLessThan(mismatch,4000,"Raster conversion retains transformed position and visible glyph pixels")
        model.undo();XCTAssertEqual(model.page.layers,[text])
    }
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
    func testAndroidStyleSchemaPreservesColorsStopsAndDeformation() throws {
        let row:[String:Any]=["name":"نمط عربي","folder":"حوار","color":-65536,"textGradient":[-65536,-16776961],"textGradientStops":[0.2,0.8],"fontSize":57,"boxWidth":300,"perspectivePoints":[0.1,0,1,0,1,1,0,1]]
        let styles=try ReferenceStyleImport.decode(JSONSerialization.data(withJSONObject:[row]))
        XCTAssertEqual(styles[0].title,"نمط عربي");XCTAssertEqual(styles[0].style.color,"FF0000");XCTAssertEqual(styles[0].style.textGradient,["FF0000","0000FF"]);XCTAssertEqual(styles[0].style.textGradientStops,[0.2,0.8]);XCTAssertEqual(styles[0].style.perspectivePoints.first,Point(x:0.1,y:0))
    }
    func testSpanBoldOverridesOnlySelectedUTF16Range() {
        var layer=EditorLayer(kind:.text);layer.textContent="عربي ABC";layer.style.spans=[TextRun(start:5,end:8,color:"FF0000",fontSize:70,isBold:true)]
        let attributed=LayerRenderer.attributed(layer)
        XCTAssertEqual((attributed.attribute(.font,at:5,effectiveRange:nil) as? UIFont)?.pointSize,70)
        XCTAssertEqual((attributed.attribute(.font,at:0,effectiveRange:nil) as? UIFont)?.pointSize,48)
    }
    func testHomographyPaddingKeepsIdentityAndTranslatedTextCoordinates() throws {
        let corners=[Point(x:0,y:0),Point(x:1,y:0),Point(x:1,y:1),Point(x:0,y:1)]
        let values=try XCTUnwrap(PerspectiveGeometry.extended(corners,width:200,height:100,padding:20));XCTAssertEqual(values,[Point(x:-0.1,y:-0.2),Point(x:1.1,y:-0.2),Point(x:1.1,y:1.2),Point(x:-0.1,y:1.2)])
        let translated=corners.map{Point(x:$0.x+0.3,y:$0.y-0.1)},shifted=try XCTUnwrap(PerspectiveGeometry.extended(translated,width:200,height:100,padding:20));XCTAssertEqual(shifted[0].x,0.2,accuracy:0.0001);XCTAssertEqual(shifted[0].y,-0.3,accuracy:0.0001)
    }
    func testRichRangeTracksInsertionAndDeletionBeforeArabicText() {
        let run=TextRun(start:4,end:7,color:"FF0000",fontSize:22,isBold:true)
        let inserted=TextRanges.adjusted([run],from:"abc عربي",to:"Xabc عربي");XCTAssertEqual(inserted.first?.start,5);XCTAssertEqual(inserted.first?.end,8)
        let deleted=TextRanges.adjusted(inserted,from:"Xabc عربي",to:"عربي");XCTAssertEqual(deleted.first?.start,0);XCTAssertEqual(deleted.first?.end,3)
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
