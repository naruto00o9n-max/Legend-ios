import XCTest
import UIKit
@testable import CookiesEditor

final class TextCreationWorkflowTests:XCTestCase {
    private func root()->URL{FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)}
    @MainActor private func model(_ root:URL)throws->EditorModel{let page=try PageOperations.blank(title:"نصوص",width:800,height:900,color:"FFFFFF",transparent:false,root:root);return EditorModel(page:page,library:LibraryStore(root:root))}
    @MainActor func testManualConfirmationRemembersCompleteAppearanceAcrossProjectsAndTyperCannotReplaceIt()throws{
        let root=root();defer{try? FileManager.default.removeItem(at:root)}
        let model=try self.model(root);model.add(.text)
        XCTAssertEqual(model.active?.style.color,"000000");XCTAssertEqual(model.active?.style.strokeWidth,0)
        var style=try XCTUnwrap(model.active?.style);style.fontPath="hayah.ttf";style.color="1E3456";style.fontSize=31;style.strokeWidth=3;style.strokeColor="FFFFEE";style.textGradient=["223344","8899AA"];style.textGradientStops=[0,1];style.lineSpacing=8;style.isItalic=true;style.effectType = .shadow;style.shadowRadius=2;style.rotationY=12
        model.change{$0.style=style;$0.opacity=0.8;$0.rotation=9;$0.scaleX=1.15}
        XCTAssertTrue(model.confirmTextSettings());let expected=try XCTUnwrap(model.manualTextStore.manualTextPreset())
        let second=try self.model(root);second.add(.text);XCTAssertEqual(second.active?.style,style);XCTAssertEqual(second.active?.opacity,0.8);XCTAssertEqual(second.active?.rotation,9);XCTAssertEqual(second.active?.scaleX,1.15)
        let typer=TyperStore(directory:root.appendingPathComponent("Typer"));var tag=try XCTUnwrap(typer.state.tags.first{$0.prefix.isEmpty});tag.style.color="FF7700";tag.style.strokeWidth=0;try typer.saveTag(tag)
        let chapter=try typer.saveChapter(title:"فصل",source:"نص الفصل",separation:.lines);try typer.place([try XCTUnwrap(typer.activeChapter?.bubbles.first)],chapter:chapter,model:second)
        XCTAssertEqual(second.active?.textOrigin,.typer);second.change{$0.style.color="FF0000"};XCTAssertTrue(second.confirmTextSettings())
        XCTAssertEqual(try second.manualTextStore.manualTextPreset(),expected);second.add(.text);XCTAssertEqual(second.active?.style,style)
    }
    @MainActor func testUnconfirmedManualEditDoesNotChangePresetAndLegacyOriginsStaySafe()throws{
        let root=root();defer{try? FileManager.default.removeItem(at:root)}
        let model=try self.model(root);model.add(.text);model.change{$0.style.color="ABCDEF"};model.save();model.add(.text)
        XCTAssertEqual(model.active?.style.color,"000000");XCTAssertNil(try model.manualTextStore.manualTextPreset())
        var legacy=EditorLayer(kind:.text);legacy.style.color="FF0000"
        let data=try JSONEncoder().encode(legacy),decoded=try JSONDecoder().decode(EditorLayer.self,from:data)
        XCTAssertNil(decoded.textOrigin);try model.manualTextStore.rememberManualText(decoded,from:model.directory);XCTAssertNil(try model.manualTextStore.manualTextPreset())
    }
    @MainActor func testUnmarkedAndNarratorBubblesUseTheirExactTagInBothSniperAndDrawnLayoutDespiteOldOverrides()throws{
        let root=root();defer{try? FileManager.default.removeItem(at:root)}
        let model=try self.model(root),typer=TyperStore(directory:root.appendingPathComponent("Typer"))
        var ordinary=try XCTUnwrap(typer.state.tags.first{$0.prefix.isEmpty}),narrator=try XCTUnwrap(typer.state.tags.first{$0.prefix=="#"})
        ordinary.style=TextStyle.plainText();ordinary.style.fontPath="hayah.ttf";ordinary.style.color="112233";ordinary.style.strokeWidth=1;ordinary.style.strokeColor="778899";ordinary.style.textGradient=["112233","445566"]
        narrator.style=TextStyle.plainText();narrator.style.fontPath="hacen_samra_lt.ttf";narrator.style.color="773311";narrator.style.isBold=true;narrator.style.shadowRadius=1
        try typer.saveTag(ordinary);try typer.saveTag(narrator)
        let chapter=try typer.saveChapter(title:"فصل",source:"حوار عادي بلا رمز\n# صوت الراوي هنا",separation:.lines),bubbles=try XCTUnwrap(typer.activeChapter?.bubbles)
        let oldOverride=try XCTUnwrap(typer.state.tags.first{$0.prefix==":"})
        for mode in 0..<2{for (index,bubble) in bubbles.enumerated(){
            let input=try typer.dialogueLayer(bubble),expected=index==0 ? ordinary.style:narrator.style
            let rect=CGRect(x:80,y:80,width:400,height:260),target=SniperTarget(bounds:Box(x:80,y:80,width:400,height:260),outline:[Point(x:80,y:80),Point(x:480,y:80),Point(x:480,y:340),Point(x:80,y:340)],point:Point(x:280,y:210))
            let prepared=mode==0 ? try BubbleLayout.fit(input,request:BubbleLayoutRequest(bounds:rect,shape:.oval)):try SniperDetector.fitted(input,to:target)
            try typer.place([bubble],chapter:chapter,model:model,targets:mode==1 ? [target]:[],overrideTag:oldOverride.id,font:"bein_normal.ttf",preparedLayout:mode==0 ? prepared:nil,preparedLayouts:mode==1 ? [prepared]:[])
            let saved=try XCTUnwrap(model.active);XCTAssertEqual(saved.style.fontPath,expected.fontPath);XCTAssertEqual(saved.style.color,expected.color);XCTAssertEqual(saved.style.strokeWidth,expected.strokeWidth);XCTAssertEqual(saved.style.textGradient,expected.textGradient);XCTAssertEqual(saved.style.isBold,expected.isBold);XCTAssertEqual(saved.style.shadowRadius,expected.shadowRadius);XCTAssertEqual(saved.textOrigin,.typer)
        }}
        let unmarked=DialogueBubble(text:"حوار قديم بلا رقم وسم");XCTAssertEqual(try typer.dialogueLayer(unmarked).style,ordinary.style)
    }
    @MainActor func testSamePrefixInAnotherTagGroupDoesNotSilentlyReplaceActualBubbleTag()throws{
        let root=root();defer{try? FileManager.default.removeItem(at:root)}
        let typer=TyperStore(directory:root),chapter=try typer.saveChapter(title:"فصل",source:"حوار",separation:.lines),bubble=try XCTUnwrap(typer.chapter(chapter)?.bubbles.first)
        var original=try typer.insertionTag(for:bubble);original.style.color="123456";try typer.saveTag(original)
        try typer.createTagSet(title:"أخرى",copyActive:false);let other=try XCTUnwrap(typer.tagSets.last);try typer.activateTagSet(other.id)
        var replacement=try XCTUnwrap(typer.state.tags.first{$0.prefix.isEmpty});replacement.style.color="FF0000";try typer.saveTag(replacement)
        XCTAssertEqual(try typer.dialogueLayer(bubble).style.color,"123456")
    }
    @MainActor func testReusableTextureSurvivesPreviewDeletionAndSelectiveBackupWithoutSavedStyleList()throws{
        let root=root(),preview=root.appendingPathComponent("Preview"),restored=self.root();defer{try? FileManager.default.removeItem(at:root);try? FileManager.default.removeItem(at:restored)}
        let styles=StyleStore(directory:root.appendingPathComponent("Styles"));try FileManager.default.createDirectory(at:preview,withIntermediateDirectories:true)
        let image=UIGraphicsImageRenderer(size:CGSize(width:8,height:8)).image{c in UIColor.red.setFill();c.fill(CGRect(x:0,y:0,width:8,height:8))},bytes=try XCTUnwrap(image.pngData());try bytes.write(to:preview.appendingPathComponent("texture.png"))
        var layer=EditorLayer(kind:.text);layer.textOrigin = .manual;layer.style=TextStyle.plainText();layer.style.texturePath="texture.png";layer.style.strokeGradient=["334455","AABBCC"];layer.style.extraStrokes=[ExtraOutline(width:2,color:"112233")]
        try styles.rememberManualText(layer,from:preview);try styles.rememberManualText(layer,from:preview)
        let preset=try XCTUnwrap(styles.manualTextPreset());XCTAssertEqual(try FileManager.default.contentsOfDirectory(at:styles.directory,includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.count,1)
        try FileManager.default.removeItem(at:preview)
        let backup=try AppStorageManager.createBackup(selected:["Styles"],at:root);defer{try? FileManager.default.removeItem(at:backup)};_ = try AppStorageManager.restore(backup,selected:["Styles"],at:restored)
        let reopened=StyleStore(directory:restored.appendingPathComponent("Styles")),saved=try XCTUnwrap(reopened.manualTextPreset());XCTAssertEqual(saved,preset);XCTAssertEqual(try Data(contentsOf:reopened.directory.appendingPathComponent(saved.style.texturePath)),bytes)
        let model=try self.model(restored);model.add(.text);XCTAssertNil(model.error);let actual=try XCTUnwrap(model.active);XCTAssertEqual(actual.style.strokeGradient,layer.style.strokeGradient);XCTAssertEqual(actual.style.extraStrokes,layer.style.extraStrokes);XCTAssertEqual(try Data(contentsOf:model.directory.appendingPathComponent(actual.style.texturePath)),bytes)
        try reopened.resetManualText();model.add(.text);XCTAssertEqual(model.active?.style.color,"000000");XCTAssertEqual(model.active?.style.strokeWidth,0)
    }
    @MainActor func testVisualTagPresetStoresAllTextToolsAndTransformsWithoutChangingManualDefault()throws{
        let root=root();defer{try? FileManager.default.removeItem(at:root)}
        let model=try self.model(root),styles=model.manualTextStore,typer=TyperStore(directory:root.appendingPathComponent("Typer"))
        var preview=EditorLayer(kind:.text);preview.textOrigin = .tagPreview;preview.style.fontPath="hayah.ttf";preview.style.color="123456";preview.style.textGradient=["112233","AABBCC"];preview.style.strokeGradient=["000000","FFFFFF"];preview.style.lineSpacing=7;preview.style.effectType = .neon;preview.style.effectValue=3;preview.style.rotationX=10;preview.style.innerOpacity=0.75;preview.style.extraStrokes=[ExtraOutline(width:1,color:"FFFFFF")];preview.opacity=0.7;preview.rotation=12;preview.scaleX=1.2
        var tag=try XCTUnwrap(typer.state.tags.first{$0.prefix.isEmpty});tag.style=try styles.ownedReusableStyle(preview.style,from:model.directory);tag.textTransform=TextLayerTransform(preview);try typer.saveTag(tag)
        let reopened=TyperStore(directory:typer.directory);XCTAssertEqual(reopened.tag(tag.id)?.style,preview.style);XCTAssertEqual(reopened.tag(tag.id)?.textTransform,TextLayerTransform(preview))
        model.page.layers=[preview];model.selected=preview.id;XCTAssertTrue(model.confirmTextSettings());XCTAssertNil(try styles.manualTextPreset())
        let chapter=try reopened.saveChapter(title:"فصل",source:"حوار",separation:.lines);try reopened.place([try XCTUnwrap(reopened.activeChapter?.bubbles.first)],chapter:chapter,model:model);XCTAssertEqual(model.active?.style,preview.style);XCTAssertEqual(model.active?.opacity,preview.opacity);XCTAssertEqual(model.active?.rotation,preview.rotation);XCTAssertEqual(model.active?.scaleX,preview.scaleX)
        model.add(.text);XCTAssertEqual(model.active?.style.color,"000000");XCTAssertEqual(model.active?.style.strokeWidth,0)
    }
}
