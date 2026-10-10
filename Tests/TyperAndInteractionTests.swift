import XCTest
@testable import CookiesEditor

final class TyperAndInteractionTests:XCTestCase {
    func testDistributionStartsAtChosenBubbleAndSkipsTitlesAndUsedText(){
        var chapter=DialogueChapter(title:"فصل",source:"");let first=DialogueBubble(text:"قبل المحددة"),chosen=DialogueBubble(text:"المحددة"),heading=DialogueBubble(text:"عنوان",noPaste:true);var used=DialogueBubble(text:"مستخدمة");used.usedAt=Date();let last=DialogueBubble(text:"الأخيرة");chapter.bubbles=[first,chosen,heading,used,last]
        XCTAssertEqual(DialogueSequence.next(chapter,from:chosen.id,count:3).map(\.id),[chosen.id,last.id]);XCTAssertEqual(DialogueSequence.next(chapter,from:nil,count:1).map(\.id),[first.id])
    }
    @MainActor func testDraftAndDeletedTagFormattingSurviveRestart()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let store=TyperStore(directory:root),tag=try XCTUnwrap(store.state.tags.first)
        let draft=DialogueChapter(title:"مسودة",source:"نص لم يُعتمد")
        try store.saveDraft(draft);try store.removeTag(tag.id)
        let reopened=TyperStore(directory:root);XCTAssertEqual(reopened.state.drafts?.first?.source,draft.source);XCTAssertEqual(reopened.tag(tag.id)?.style,tag.style)
        try reopened.removeDraft(draft.id);XCTAssertTrue(TyperStore(directory:root).state.drafts?.isEmpty==true)
    }
    @MainActor func testTagGroupsBubbleOrderAndTrashPersistWithoutLosingProgress() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let store=TyperStore(directory:root),originalGroup=try XCTUnwrap(store.state.activeTagSet)
        let id=try store.saveChapter(title:"فصل",source:"أول\nثان",separation:.lines)
        let bubbles=try XCTUnwrap(store.chapter(id)).bubbles
        try store.mark(bubbles[0].id,in:id,used:true)
        try store.createTagSet(title:"الفصل الثاني",copyActive:true)
        XCTAssertEqual(store.tagSets.count,2);XCTAssertNotEqual(store.state.activeTagSet,originalGroup)
        XCTAssertNotNil(store.tag(bubbles[0].tagID),"A chapter keeps resolving tags from its original group")
        try store.activateTagSet(originalGroup)
        var edited=try XCTUnwrap(store.chapter(id)).bubbles[0];edited.text="أول معدل"
        try store.updateBubble(edited,in:id);try store.reorderBubbles(bubbles.reversed().map(\.id),in:id)
        try store.setQuickFonts(["bein_normal.ttf"]);try store.setLinkPrefix("@@")
        try store.remove(id);XCTAssertNil(store.chapter(id))
        let reopened=TyperStore(directory:root);try reopened.restore(id)
        let restored=try XCTUnwrap(reopened.chapter(id))
        XCTAssertEqual(restored.bubbles.map(\.id),bubbles.reversed().map(\.id));XCTAssertTrue(restored.bubbles[1].used);XCTAssertEqual(restored.bubbles[1].text,"أول معدل")
        XCTAssertEqual(reopened.state.quickFonts,["bein_normal.ttf"]);XCTAssertEqual(reopened.state.linkPrefix,"@@")
    }
    @MainActor func testTranscriptIdentityAndProgressSurviveRestart() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let store=TyperStore(directory:root)
        let id=try store.saveChapter(title:"الفصل الأول",source:"## عنوان\nحوار مكرر\nحوار ثان\nحوار مكرر",separation:.lines)
        let before=try XCTUnwrap(store.chapter(id));XCTAssertEqual(before.bubbles.count,4);XCTAssertTrue(before.bubbles[0].noPaste)
        try store.mark(before.bubbles[1].id,in:id,page:UUID(),layer:UUID(),used:true)
        _ = try store.saveChapter(id:id,title:"الفصل الأول",source:"سطر مضاف\n## عنوان\nحوار مكرر\nحوار ثان\nحوار مكرر",separation:.lines)
        let after=try XCTUnwrap(TyperStore(directory:root).chapter(id))
        XCTAssertEqual(after.bubbles[2].id,before.bubbles[1].id);XCTAssertTrue(after.bubbles[2].used);XCTAssertFalse(after.bubbles[4].used,"Duplicate text must keep independent used states");XCTAssertEqual(after.usedCount,1)
        let utf16=try XCTUnwrap("\u{FEFF}حوار أول\r\nحوار ثان".data(using:.utf16LittleEndian))
        XCTAssertEqual(try TranscriptParser.decode(utf16),"حوار أول\nحوار ثان")
        XCTAssertEqual(TranscriptParser.parse("أول\nسطر تابع\n\nثان",separation:.paragraphs,tags:store.state.tags,link:"//").count,2)
    }
    @MainActor func testChapterInsertionSavesRealTextLayerAndUsedBubble() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),page=try ImagePipeline.fixture(root:root);library.add(page,parent:nil)
        let typer=TyperStore(directory:root.appendingPathComponent("Typer")),chapter=try typer.saveChapter(title:"الفصل",source:"النص الأول\nالنص الثاني",separation:.lines),bubble=try XCTUnwrap(typer.activeChapter?.bubbles.first)
        let model=EditorModel(page:page,library:library);model.visibleCenter=CGPoint(x:400,y:14800)
        try typer.place([bubble],chapter:chapter,model:model)
        XCTAssertEqual(try library.load(page.id).layers.first?.textContent,bubble.text);XCTAssertEqual(typer.activeChapter?.usedCount,1);XCTAssertNil(model.panel);XCTAssertNotNil(model.active);XCTAssertGreaterThan(model.active?.frame.y ?? 0,14000)
        let reopened=TyperStore(directory:typer.directory);XCTAssertEqual(reopened.activeChapter?.bubbles.first?.usedLayer,model.active?.id)
        model.undo();XCTAssertTrue(model.page.layers.isEmpty);XCTAssertEqual(reopened.activeChapter?.usedCount,1,"User can explicitly return a bubble to remaining; undo does not silently shift chapter progress")
    }
    @MainActor func testLiveDrawingIsVisibleBeforeCommitWithoutRecomposingTiles() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try ImagePipeline.fixture(root:root);page.layers=[EditorLayer(kind:.drawing)]
        page.layers[0].frame=Box(x:0,y:0,width:800,height:15000)
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:15000));canvas.update(page:page,directory:library.directory(page.id),selected:page.layers[0].id,zoom:1);canvas.refreshVisible(CGRect(x:0,y:0,width:400,height:600))
        try await Task.sleep(nanoseconds:1_000_000_000);let revision=canvas.revision,reads=canvas.sourceReads
        var stroke=Stroke(points:[Point(x:50,y:50)],width:12,color:"FFFFFF")
        for value in 60...100 {stroke.points.append(Point(x:Double(value),y:Double(value)));canvas.showStroke(stroke,on:page,selected:page.layers[0].id);XCTAssertTrue(canvas.liveStrokeVisible)}
        XCTAssertEqual(canvas.revision,revision);XCTAssertEqual(canvas.sourceReads,reads);XCTAssertTrue(page.layers[0].strokes.isEmpty,"Finger preview precedes the committed model")
        canvas.commitLiveStroke();page.layers[0].strokes.append(stroke);canvas.update(page:page,directory:library.directory(page.id),selected:page.layers[0].id,zoom:1)
        XCTAssertTrue(canvas.liveStrokeVisible,"Keep ink until replacement tiles exist");try await Task.sleep(nanoseconds:1_000_000_000);XCTAssertFalse(canvas.liveStrokeVisible);XCTAssertEqual(canvas.sourceReads,reads)
    }
    @MainActor func testTextTransformsReuseRasterAndKeepForegroundOrder() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try ImagePipeline.fixture(root:root);var text=EditorLayer(kind:.text);text.textContent="نص متحرك";text.frame=Box(x:50,y:50,width:250,height:90);text.style.boxWidth=250
        var upper=EditorLayer(kind:.shape);upper.frame=Box(x:40,y:200,width:100,height:100);page.layers=[text,upper]
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:15000));canvas.update(page:page,directory:library.directory(page.id),selected:text.id,zoom:1);canvas.refreshVisible(CGRect(x:0,y:0,width:400,height:600));try await Task.sleep(nanoseconds:1_000_000_000)
        XCTAssertTrue(canvas.beginLayerInteraction(text.id));let revision=canvas.revision,rasterizations=canvas.interactionRasterizations
        let before=canvas.interactiveLayerCenter
        for value in 1...100{page.layers[0].frame.x=50+Double(value);page.layers[0].rotation=Double(value)/5;page.layers[0].scaleX=1;canvas.update(page:page,directory:library.directory(page.id),selected:text.id,zoom:1)}
        XCTAssertEqual(canvas.revision,revision,"Dragging transforms sprites instead of software tiles");XCTAssertEqual(canvas.interactionRasterizations,rasterizations);XCTAssertNotEqual(canvas.interactiveLayerCenter,before)
        canvas.endLayerInteraction();XCTAssertGreaterThan(canvas.revision,revision)
        page.layers[1].blend = .multiply;canvas.update(page:page,directory:library.directory(page.id),selected:text.id,zoom:1);try await Task.sleep(nanoseconds:1_000_000_000);XCTAssertFalse(canvas.beginLayerInteraction(text.id),"Complex blend stacks must preserve their actual compositor")
    }
    func testSniperDetectsClosedBubbleAndFallsBackToPin() throws {
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:600,height:600),format:format).image{output in UIColor.black.setFill();output.fill(CGRect(x:0,y:0,width:600,height:600));UIColor.white.setFill();UIBezierPath(ovalIn:CGRect(x:120,y:100,width:320,height:300)).fill()}
        let result=try XCTUnwrap(CookiesDetectBubble(image,CGPoint(x:280,y:230)) as? [String:Any])
        XCTAssertEqual(result["pin"] as? Bool,false);XCTAssertGreaterThan((result["width"] as? NSNumber)?.doubleValue ?? 0,200);XCTAssertEqual((result["y"] as? NSNumber)?.doubleValue ?? 0,130,accuracy:15)
        let outside=try XCTUnwrap(CookiesDetectBubble(image,CGPoint(x:20,y:20)) as? [String:Any]);XCTAssertEqual(outside["pin"] as? Bool,true)
    }
}
