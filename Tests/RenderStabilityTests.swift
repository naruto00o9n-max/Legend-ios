import XCTest
import UIKit
@testable import CookiesEditor

final class RenderStabilityTests:XCTestCase {
    func testRemovedGradientRowsRemainSafeDuringSwiftUIBindingTeardown(){
        var colors=["000000","FFFFFF","D4AF37"],stops=[0.0,0.5,1.0]
        GradientEditing.remove(at:1,colors:&colors,stops:&stops)
        XCTAssertEqual(colors,["000000","D4AF37"]);XCTAssertEqual(stops,[0,1])
        colors=[];stops=[]
        for i in [-1,0,1,2,100]{XCTAssertEqual(GradientEditing.color(colors,at:i),"FFFFFF");XCTAssertEqual(GradientEditing.position(colors,stops:stops,at:i),0.5);GradientEditing.setColor("ABCDEF",at:i,colors:&colors);GradientEditing.setPosition(0.3,at:i,colors:colors,stops:&stops);GradientEditing.remove(at:i,colors:&colors,stops:&stops)}
        XCTAssertTrue(colors.isEmpty);XCTAssertTrue(stops.isEmpty)
        colors=["000000","FFFFFF"];stops=[.nan,.infinity];XCTAssertEqual(GradientEditing.position(colors,stops:stops,at:1),1)
        GradientEditing.setPosition(.nan,at:0,colors:colors,stops:&stops);XCTAssertTrue(stops[0].isNaN)
    }
    func testOriginalGradientRestorationPersistsAndPreservesUnrelatedEdits()throws{
        var layer=EditorLayer(kind:.text);layer.style=TextStyle.plainText();let original=layer.style
        layer.gradientMapBaseline=GradientMapBaseline(original);layer.style.textGradient=["AABBCC","112233"];layer.style.strokeGradient=["FF0000","00FF00"];layer.style.strokeWidth=8;layer.style.shadowRadius=9;layer.style.shadowDy=3;layer.style.fontSize=72
        var reopened=try JSONDecoder().decode(EditorLayer.self,from:JSONEncoder().encode(layer));try XCTUnwrap(reopened.gradientMapBaseline).restore(&reopened.style)
        XCTAssertEqual(reopened.style.textGradient,original.textGradient);XCTAssertEqual(reopened.style.strokeGradient,original.strokeGradient);XCTAssertEqual(reopened.style.shadowRadius,original.shadowRadius);XCTAssertEqual(reopened.style.strokeWidth,original.strokeWidth);XCTAssertEqual(reopened.style.fontSize,72)
    }
    func testTextCacheKeyReusesMovementButDistinguishesActualRendering(){
        let root=FileManager.default.temporaryDirectory;var layer=EditorLayer(kind:.text);layer.textContent="حوار"
        func key(_ value:EditorLayer)->TextRenderKey{TextRenderKey(value,directory:root,resolution:2,size:CGSize(width:300,height:100))}
        let first=key(layer);layer.id=UUID();layer.frame.x=200;layer.rotation=32;layer.scaleX=2;layer.opacity=0.4;XCTAssertEqual(first,key(layer));XCTAssertEqual(first.hash,key(layer).hash)
        layer.style.textGradient=["000000","FFFFFF"];XCTAssertNotEqual(first,key(layer))
    }
    func testGlitchComposesManyBandsFromOneCachedGlyphSet(){
        TextArtRenderer.cache.removeAllObjects();let before=TextArtRenderer.cacheBuilds
        var layer=EditorLayer(kind:.text);layer.textContent="حوار\nواضح";layer.style=TextStyle.plainText(fontSize:50,boxWidth:200);layer.style.effectType = .glitch;layer.style.art=TextArtSettings(bandHeight:2)
        let format=UIGraphicsImageRendererFormat();format.scale=2
        func draw(_ value:EditorLayer){RenderBudget.screen{_ = UIGraphicsImageRenderer(size:CGSize(width:300,height:250),format:format).image{c in c.cgContext.translateBy(x:40,y:40);LayerRenderer.drawText(value,rect:LayerRenderer.bounds(value),context:c.cgContext,directory:FileManager.default.temporaryDirectory)}}}
        draw(layer);XCTAssertEqual(TextArtRenderer.cacheBuilds-before,1)
        for i in 0..<12{layer.style.art?.strength=Double(i);layer.style.art?.seed=UInt32(i);draw(layer)}
        XCTAssertEqual(TextArtRenderer.cacheBuilds-before,1,"Changing slice offsets must not shape/color text again for every band")
    }
    func testDirtyRegionIncludesOldAndNewTextButNotWholeChapter(){
        var old=EditorLayer(kind:.text);old.textContent="حوار";old.frame=Box(x:100,y:1000,width:200,height:100);old.style=TextStyle.plainText(fontSize:40,boxWidth:200)
        var new=old;new.frame.x+=100;new.style.strokeWidth=10
        let dirty=LayerInvalidation.dirtyRect(before:[old],after:[new])!
        XCTAssertTrue(dirty.contains(TextVisualBounds.rect(old).applying(LayerRenderer.transform(old))));XCTAssertTrue(dirty.contains(TextVisualBounds.rect(new).applying(LayerRenderer.transform(new))));XCTAssertLessThan(dirty.height,1000)
        var another=new;another.id=UUID();XCTAssertNil(LayerInvalidation.dirtyRect(before:[old,another],after:[another,new]))
    }
    func testPreviewBudgetDoesNotLeakIntoExports(){
        XCTAssertFalse(RenderBudget.isPreview);RenderBudget.screen{XCTAssertTrue(RenderBudget.isPreview);RenderBudget.screen{XCTAssertTrue(RenderBudget.isPreview)};XCTAssertTrue(RenderBudget.isPreview)};XCTAssertFalse(RenderBudget.isPreview)
    }
    func testEveryStyleFilterRendersChangesAndRoundTripsWithoutFlatteningText()throws{
        var layer=EditorLayer(kind:.text);layer.textContent="كوكيز";layer.style=TextStyle.plainText(fontSize:64,boxWidth:240);layer.style.color="331188";layer.style.textGradient=["331188","882299"];layer.style.effectValue=16
        let f=UIGraphicsImageRendererFormat();f.scale=1;f.opaque=false
        func render(_ value:EditorLayer)->Data{let image=RenderBudget.screen{UIGraphicsImageRenderer(size:CGSize(width:480,height:280),format:f).image{out in out.cgContext.translateBy(x:100,y:90);LayerRenderer.drawText(value,rect:LayerRenderer.bounds(value),context:out.cgContext,directory:FileManager.default.temporaryDirectory)}};return image.pngData()!}
        let original=render(layer)
        XCTAssertEqual(TextEffect.styleCases.count,15)
        for effect in TextEffect.allCases where effect != .none{
            layer.style.effectType=effect;var settings=StyleEffectSettings();settings.color="E09010";settings.radius=6;settings.softness=2;settings.depth=14;layer.style.styleEffect=settings
            let output=render(layer);XCTAssertNotEqual(output,original,effect.rawValue)
            let reopened=try JSONDecoder().decode(EditorLayer.self,from:JSONEncoder().encode(layer));XCTAssertEqual(reopened,layer);XCTAssertEqual(render(reopened),output,effect.rawValue)
            if effect.isStyle{layer.style.styleEffect?.opacity=0;XCTAssertEqual(render(layer),original,"Zero effect opacity must restore the original glyph fill: \(effect.rawValue)")}
            layer.style.effectType = .none;XCTAssertEqual(render(layer),original,"Removing \(effect.rawValue) must preserve text, font, and fill")
        }
    }

    func testBrushCullingKeepsSoftNeonAndFilledShapeExtents(){
        let clip=CGRect(x:0,y:0,width:100,height:100)
        var stroke=Stroke(points:[Point(x:500,y:500)],width:20,color:"000000")
        XCTAssertFalse(BrushRenderer.visible(stroke,in:clip));stroke.brush="texture";XCTAssertTrue(BrushRenderer.visible(stroke,in:clip))
        stroke.brush="neon";stroke.points=[Point(x:150,y:50)];XCTAssertTrue(BrushRenderer.visible(stroke,in:clip))
        stroke.brush="soft";stroke.points=[Point(x:105,y:50)];XCTAssertTrue(BrushRenderer.visible(stroke,in:clip))
        stroke.shape="rectangle";stroke.filled=true;stroke.points=[Point(x:-100,y:-100),Point(x:200,y:200)];XCTAssertTrue(BrushRenderer.visible(stroke,in:clip))
    }

    func testStainedGlassProceduralKernelCompilesOnTheNativeRuntime(){XCTAssertTrue(StyleEffectRenderer.glassKernelAvailable)}

    func testCompoundedGradientEffectReusesGlyphsAndDecoratedBaseWhilePerspectiveChanges(){
        ImagePipeline.clearMemoryCaches()
        var layer=EditorLayer(kind:.text);layer.textContent="حوار متدرج\nبتأثير ومنظور"
        layer.style=TextStyle.plainText(fontSize:42,boxWidth:260)
        layer.style.textGradient=["442299","CC4488"];layer.style.strokeWidth=3
        layer.style.strokeGradient=["FFFFFF","DDCCFF"];layer.style.shadowGradient=["221144","9966AA"];layer.style.shadowRadius=4;layer.style.shadowDy=3
        layer.style.effectType = .bevelInner;layer.style.styleEffect=StyleEffectSettings()
        let glyphs=TextGlyphMask.buildCount,bases=TextRaster.baseRasterBuilds
        let f=UIGraphicsImageRendererFormat();f.scale=2;f.opaque=false
        func render(){RenderBudget.screen{_ = UIGraphicsImageRenderer(size:CGSize(width:500,height:350),format:f).image{out in out.cgContext.translateBy(x:80,y:80);LayerRenderer.drawText(layer,rect:LayerRenderer.bounds(layer),context:out.cgContext,directory:FileManager.default.temporaryDirectory)}}}
        render()
        for index in 1...12{let inset=Double(index)/200;layer.style.perspectivePoints=[Point(x:inset,y:0),Point(x:1-inset,y:0),Point(x:1,y:1),Point(x:0,y:1)];render()}
        XCTAssertEqual(TextGlyphMask.buildCount-glyphs,1,"Perspective must not reshape the same glyphs")
        XCTAssertEqual(TextRaster.baseRasterBuilds-bases,1,"Perspective must reuse gradient, outline and style filtering")
        for index in 1...8{layer.style.textGradientAngle=Double(index)*10;render()}
        XCTAssertEqual(TextGlyphMask.buildCount-glyphs,1,"Gradient controls reuse typography")
        XCTAssertGreaterThan(TextRaster.baseRasterBuilds-bases,1,"Actual color edits still invalidate decoration")
        layer.style.fontSize+=1;render();XCTAssertGreaterThan(TextGlyphMask.buildCount-glyphs,1)
    }
    @MainActor func testToolEditsKeepTilesStableAndPresentIntermediateCompoundFrames() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try ImagePipeline.fixture(root:root)
        var text=EditorLayer(kind:.text);text.textContent="حوار متدرج";text.frame.x=50;text.frame.y=50
        text.style=TextStyle.plainText(fontSize:42,boxWidth:240)
        text.style.textGradient=["442299","CC4488"];text.style.strokeWidth=3
        text.style.strokeGradient=["FFFFFF","DDCCFF"];text.style.shadowGradient=["221144","9966AA"];text.style.shadowRadius=4;text.style.shadowDy=3
        text.style.effectType = .bevelInner;text.style.styleEffect=StyleEffectSettings()
        page.layers=[text]
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:15000)),directory=library.directory(page.id)
        canvas.update(page:page,directory:directory,selected:text.id,zoom:1)
        canvas.refreshVisible(CGRect(x:0,y:0,width:400,height:600));canvas.prepareTextEditing(text.id)
        for _ in 0..<200{if canvas.isTextPreviewReady{break};try await Task.sleep(nanoseconds:50_000_000)}
        XCTAssertTrue(canvas.isTextPreviewReady)
        XCTAssertGreaterThan(canvas.interactivePresentedFrames,0)
        let revision=canvas.revision,frames=canvas.interactivePresentedFrames,reads=canvas.sourceReads
        let start=Date()
        for index in 0..<60{
            page.layers[0].style.styleEffect?.radius=Double(index%8)+1
            let inset=Double(index%10)/100
            page.layers[0].style.perspectivePoints=[Point(x:inset,y:0),Point(x:1,y:0),Point(x:1-inset,y:1),Point(x:0,y:1)]
            page.layers[0].frame.x=50+Double(index)
            canvas.update(page:page,directory:directory,selected:text.id,zoom:1)
            try await Task.sleep(nanoseconds:30_000_000)
        }
        XCTAssertEqual(canvas.revision,revision,"Tool sliders must not rebuild the image tiles")
        XCTAssertEqual(canvas.sourceReads,reads,"Tool edits must not reread the original image")
        XCTAssertGreaterThan(canvas.interactivePresentedFrames,frames,"Completed previews must appear before the continuous edit ends")
        print("COMPOUND_PREVIEW edits=60 presented=\(canvas.interactivePresentedFrames-frames) elapsed=\(Date().timeIntervalSince(start))")
        canvas.prepareTextEditing(nil);XCTAssertGreaterThan(canvas.revision,revision)
    }
    @MainActor func testContinuousSliderEditingDefersDocumentWritesUntilRelease() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try ImagePipeline.fixture(root:root)
        var layer=EditorLayer(kind:.text);layer.textContent="نص";page.layers=[layer];try library.persist(page)
        let model=EditorModel(page:page,library:library);defer{model.cancelPendingSaves()};model.selected=layer.id
        model.setContinuousEditing(true);model.change{$0.style.textGradientAngle=123}
        try await Task.sleep(nanoseconds:400_000_000)
        let stored=try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:model.directory.appendingPathComponent("page.json")))
        XCTAssertEqual(stored.layers[0].style.textGradientAngle,0)
        model.setContinuousEditing(false)
        try await Task.sleep(nanoseconds:400_000_000)
        let saved=try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:model.directory.appendingPathComponent("page.json")))
        XCTAssertEqual(saved.layers[0].style.textGradientAngle,123)
    }

    @MainActor func testGeometryInspectorDoesNotRenderCompoundTextOnMainThread() async throws {
        var layer=EditorLayer(kind:.text);layer.textContent="معاينة المنظور"
        layer.style=TextStyle.plainText(fontSize:42,boxWidth:240)
        layer.style.textGradient=["442299","CC4488"];layer.style.strokeWidth=3
        layer.style.strokeGradient=["FFFFFF","DDCCFF"];layer.style.shadowGradient=["221144","9966AA"];layer.style.shadowRadius=4;layer.style.shadowDy=3
        layer.style.effectType = .bevelInner;layer.style.styleEffect=StyleEffectSettings()
        let view=GeometryPreviewImageView(),directory=FileManager.default.temporaryDirectory
        for index in 0..<40{layer.style.rotationY=Double(index);view.submit(layer,directory:directory,size:CGSize(width:260,height:148));try await Task.sleep(nanoseconds:30_000_000)}
        for _ in 0..<200{if view.presentedFrames>0{break};try await Task.sleep(nanoseconds:50_000_000)}
        XCTAssertNotNil(view.image);XCTAssertFalse(view.renderedOnMain)
        let frames=view.presentedFrames;view.cancel();view.submit(layer,directory:directory,size:CGSize(width:300,height:148))
        try await Task.sleep(nanoseconds:150_000_000);XCTAssertEqual(view.presentedFrames,frames)
    }

    func testCachedGlyphMaskKeepsItalicOverhangAndTashkeelOutsideLayoutBox(){
        var layer=EditorLayer(kind:.text);layer.textContent="فَكّرْ Aa";layer.style=TextStyle.plainText(fontSize:64,boxWidth:240)
        layer.style.isItalic=true;layer.style.tashkeelOffset=18
        let rect=LayerRenderer.bounds(layer),resolution:CGFloat=2,pad=TextGlyphMask.padding(layer.style)
        let mask=TextGlyphMask.image(layer,rect:rect,resolution:resolution,directory:FileManager.default.temporaryDirectory)
        let f=UIGraphicsImageRendererFormat();f.scale=resolution;f.opaque=false;f.preferredRange = .standard
        let reference=UIGraphicsImageRenderer(size:CGSize(width:rect.width+pad*2,height:rect.height+pad*2),format:f).image{_ in LayerRenderer.attributed(layer,color:.white).draw(with:rect.offsetBy(dx:pad,dy:pad),options:[.usesLineFragmentOrigin,.usesFontLeading],context:nil)}
        XCTAssertEqual(mask.pngData(),reference.pngData(),"Caching must preserve accents and italic glyph overhang")
    }

    func testDraftScreenAndExportCachesRemainSeparateAtIdenticalResolution(){
        let layer=EditorLayer(kind:.text),directory=FileManager.default.temporaryDirectory,size=CGSize(width:240,height:100)
        func key()->TextRenderKey{TextRenderKey(layer,directory:directory,resolution:1,size:size)}
        let export=key(),screen=RenderBudget.screen{key()},draft=RenderBudget.screen(interactive:true){key()}
        XCTAssertNotEqual(export,screen);XCTAssertNotEqual(export,draft);XCTAssertNotEqual(screen,draft)
        XCTAssertFalse(RenderBudget.isInteractive);XCTAssertFalse(RenderBudget.isPreview)
    }

    @MainActor func testPersistentToolPreviewHonorsHiddenReorderedAndDrawingForeground() throws {
        let root=FileManager.default.temporaryDirectory
        var page=EditorPage(title:"ترتيب الطبقات",width:800,height:15000)
        var text=EditorLayer(kind:.text);text.textContent="نص";text.style=TextStyle.plainText()
        var shape=EditorLayer(kind:.shape);shape.frame=Box(x:20,y:20,width:100,height:100)
        page.layers=[text,shape]
        let preview=try XCTUnwrap(LayerInteraction(page:page,selected:text.id,directory:root))
        XCTAssertTrue(preview.matchesToolForeground(page))
        page.layers[1].isVisible=false;XCTAssertFalse(preview.matchesToolForeground(page))
        page.layers=[shape,text];XCTAssertFalse(preview.matchesToolForeground(page))
        page.layers=[text,EditorLayer(kind:.drawing)];XCTAssertNil(LayerInteraction.toolForeground(page,selected:text.id))
        page.layers=[text,shape];page.layers[1].blend = .multiply;XCTAssertNil(LayerInteraction.toolForeground(page,selected:text.id))
    }

}
