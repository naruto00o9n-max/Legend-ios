import XCTest
import UIKit
@testable import CookiesEditor

final class WorkspaceExperienceTests:XCTestCase {
    @MainActor func testPanelFilterQueryAndInsertionChoicesSurviveRestartWithoutRewritingChapter()throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let store=TyperStore(directory:root),id=try store.saveChapter(title:"فصل",source:"أول\nثان",separation:.lines),bubble=try XCTUnwrap(store.chapter(id)?.bubbles.last)
        let before=try Data(contentsOf:root.appendingPathComponent("chapters.json"))
        var value=TyperPanelPreferences();value.filter = .unused;value.query="ثان";value.uppercase=true;value.textFormat="circle";value.overrideTag=store.state.tags.last?.id;value.quickFont="bein_normal.ttf";value.expanded=true;value.cursors[id.uuidString]=bubble.id
        try store.savePanelPreferences(value)
        let reopened=TyperStore(directory:root);XCTAssertEqual(reopened.panelPreferences,value);XCTAssertEqual(reopened.state.active,id);XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("chapters.json")),before)
        XCTAssertEqual(DialogueSequence.scrollDestination(try XCTUnwrap(reopened.activeChapter),preferences:reopened.panelPreferences),bubble.id)
    }
    func testResumeUsesLatestUsedBubbleAndWrapsToSkippedDialogue(){
        var chapter=DialogueChapter(title:"الفصل",source:"");chapter.bubbles=(0..<30).map{DialogueBubble(text:"حوار \($0)")};chapter.bubbles[5].usedAt=Date(timeIntervalSince1970:20);chapter.bubbles[20].usedAt=Date(timeIntervalSince1970:30)
        chapter.bubbles[21].noPaste=true
        XCTAssertEqual(DialogueSequence.resume(chapter)?.id,chapter.bubbles[22].id)
        XCTAssertEqual(DialogueSequence.resume(chapter,cursor:chapter.bubbles[8].id)?.id,chapter.bubbles[8].id)
        XCTAssertEqual(DialogueSequence.resume(chapter,cursor:chapter.bubbles[20].id)?.id,chapter.bubbles[22].id)
        for index in 22..<30{chapter.bubbles[index].usedAt=Date(timeIntervalSince1970:40+Double(index))}
        XCTAssertEqual(DialogueSequence.resume(chapter)?.id,chapter.bubbles[0].id)
        for index in chapter.bubbles.indices{chapter.bubbles[index].usedAt=Date()}
        XCTAssertNil(DialogueSequence.resume(chapter))
    }
    func testResumeHonorsPersistedFilterAndSearch(){
        var chapter=DialogueChapter(title:"الفصل",source:"");chapter.bubbles=[DialogueBubble(text:"قبل"),DialogueBubble(text:"مستخدم"),DialogueBubble(text:"بعد")];chapter.bubbles[1].usedAt=Date()
        var prefs=TyperPanelPreferences();prefs.filter = .unused
        XCTAssertEqual(DialogueSequence.scrollDestination(chapter,preferences:prefs),chapter.bubbles[2].id)
        prefs.filter = .used;XCTAssertEqual(DialogueSequence.scrollDestination(chapter,preferences:prefs),chapter.bubbles[1].id)
        prefs.filter = .all;prefs.query="قبل";XCTAssertEqual(DialogueSequence.scrollDestination(chapter,preferences:prefs),chapter.bubbles[0].id)
        prefs.query="غير موجود";XCTAssertNil(DialogueSequence.scrollDestination(chapter,preferences:prefs))
    }
    @MainActor func testTagDisplayColorIsDistinctDurableAndIndependentFromTextInk()throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let store=TyperStore(directory:root);XCTAssertEqual(Set(store.state.tags.map(\.resolvedDisplayColor)).count,store.state.tags.count)
        var narrator=try XCTUnwrap(store.state.tags.first{$0.prefix=="#"});let ink=narrator.style;narrator.displayColor="A5B6C7";try store.saveTag(narrator)
        let extra=DialogueTag(title:"شخصية أخرى",prefix:"@");try store.saveTag(extra)
        let reopened=TyperStore(directory:root),saved=try XCTUnwrap(reopened.tag(narrator.id));XCTAssertEqual(saved.resolvedDisplayColor,"A5B6C7");XCTAssertEqual(saved.style,ink)
        let colors=reopened.state.tags.map(\.resolvedDisplayColor);XCTAssertEqual(Set(colors).count,colors.count)
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(narrator)) as? [String:Any]);json.removeValue(forKey:"displayColor")
        let legacy=try JSONDecoder().decode(DialogueTag.self,from:JSONSerialization.data(withJSONObject:json));XCTAssertNil(legacy.displayColor);XCTAssertEqual(legacy.style,ink);XCTAssertEqual(legacy.resolvedDisplayColor,"C7BE8D")
    }
    @MainActor func testSelectiveBackupRestoresTyperPanelAndTagColors()throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),restored=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root);try? FileManager.default.removeItem(at:restored)}
        let store=TyperStore(directory:root.appendingPathComponent("Typer")),id=try store.saveChapter(title:"الفصل",source:"حوار",separation:.lines)
        var tag=try XCTUnwrap(store.state.tags.first);tag.displayColor="AABBCC";try store.saveTag(tag)
        var prefs=TyperPanelPreferences();prefs.filter = .unused;prefs.cursors[id.uuidString]=store.activeChapter?.bubbles.first?.id;try store.savePanelPreferences(prefs)
        let backup=try AppStorageManager.createBackup(selected:["Typer"],at:root);defer{try? FileManager.default.removeItem(at:backup)}
        _ = try AppStorageManager.restore(backup,selected:["Typer"],at:restored)
        let reopened=TyperStore(directory:restored.appendingPathComponent("Typer"));XCTAssertEqual(reopened.panelPreferences,prefs);XCTAssertEqual(reopened.tag(tag.id)?.displayColor,"AABBCC");XCTAssertEqual(reopened.activeChapter?.id,id)
    }
    @MainActor func testManualNewTextIsBlackWithNoEffectsAndTyperPreservesItsOwnStyle()throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),page=try PageOperations.blank(title:"أصل",width:300,height:600,color:"FFFFFF",transparent:false,root:root);library.add(page,parent:nil)
        let model=EditorModel(page:page,library:library);model.add(.text);let manual=try XCTUnwrap(model.active)
        XCTAssertEqual(manual.style.color,"000000");XCTAssertEqual(manual.style.strokeWidth,0);XCTAssertTrue(manual.style.textGradient.isEmpty);XCTAssertTrue(manual.style.perspectivePoints.isEmpty);XCTAssertTrue(manual.style.texturePath.isEmpty);XCTAssertEqual(manual.style.effectType,.none);XCTAssertEqual(manual.style.backgroundAlpha,0);XCTAssertEqual(manual.style.shadowRadius,0)
        let typer=TyperStore(directory:root.appendingPathComponent("Typer"));var tag=try XCTUnwrap(typer.state.tags.first);tag.style.color="FF0000";tag.style.strokeWidth=4;try typer.saveTag(tag);let id=try typer.saveChapter(title:"حوار",source:"نص موسوم",separation:.lines);try typer.place([try XCTUnwrap(typer.activeChapter?.bubbles.first)],chapter:id,model:model)
        XCTAssertEqual(model.active?.style.color,"FF0000");XCTAssertEqual(model.active?.style.strokeWidth,4)
    }
    @MainActor func testEyedropperReadsActualCompositedColorAndShowsFeedbackAboveTouch()async throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        var page=try PageOperations.blank(title:"لون",width:64,height:64,color:"FFFFFF",transparent:false,root:root),shape=EditorLayer(kind:.shape);shape.frame=Box(x:10,y:10,width:30,height:30);shape.style.color="FF2200";shape.style.strokeWidth=0;page.layers=[shape]
        let sampler=EyedropperSampler(),picked=expectation(description:"composited color")
        sampler.sample(page:page,directory:root.appendingPathComponent(page.id.uuidString),point:CGPoint(x:20,y:20)){color in XCTAssertEqual(color?.hex,"FF2200");picked.fulfill()};await fulfillment(of:[picked],timeout:4)
        let feedback=EyedropperFeedback(frame:.zero),viewport=CGRect(x:0,y:1000,width:390,height:650),touch=CGPoint(x:200,y:1450)
        feedback.show(at:touch,in:viewport,color:UIColor(hex:"FF2200"));XCTAssertFalse(feedback.isHidden);XCTAssertTrue(viewport.contains(feedback.frame));XCTAssertLessThan(feedback.frame.maxY,touch.y);XCTAssertEqual(feedback.accessibilityValue,"FF2200");feedback.hide();XCTAssertTrue(feedback.isHidden)
    }
    func testGuideIsSearchableAndLocalEditionOmitsServiceTopic()throws{
        let local=GuideCatalogue.topics(services:false),connected=GuideCatalogue.topics(services:true)
        XCTAssertEqual(local.count,10);XCTAssertEqual(connected.count,11);XCTAssertFalse(local.contains{$0.serviceOnly});XCTAssertEqual(Set(connected.map(\.id)).count,connected.count)
        XCTAssertTrue(local.contains{$0.matches("القطارة")});XCTAssertTrue(local.contains{$0.matches("بادئة")});XCTAssertTrue(local.allSatisfy{!$0.entries.isEmpty && $0.entries.allSatisfy{!$0.text.isEmpty}})
        XCTAssertEqual(try JSONDecoder().decode(TyperPanelPreferences.self,from:Data("{}".utf8)),TyperPanelPreferences())
    }
}
