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

}
