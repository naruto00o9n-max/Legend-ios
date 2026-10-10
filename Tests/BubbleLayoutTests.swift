import XCTest
import UIKit
import Combine
@testable import CookiesEditor

final class BubbleLayoutTests:XCTestCase {
    func testEvenAndOddSymmetricProfilesPreserveEveryWord()throws {
        for count in [4,5]{let text=Array(repeating:"word",count:count==4 ? 10:13).joined(separator:" ");let lines=try XCTUnwrap(BubbleLayout.lines(text,count:count,width:Double(count==4 ? 18:16),shape:.oval,measure:{Double($0.count)}))
            XCTAssertEqual(lines.count,count);XCTAssertEqual(lines.joined(separator:" "),text)
            let widths=lines.map(\.count),middle=count/2
            XCTAssertGreaterThanOrEqual(widths[middle],widths[0]);XCTAssertLessThanOrEqual(abs(widths[0]-widths[count-1]),5)
            if count%2==0{XCTAssertEqual(widths[middle],widths[middle-1])}
        }
    }
    func testArabicFitsChosenBoundsWithoutChangingColorOrFont()throws {
        var layer=EditorLayer(kind:.text);layer.textContent="عندما نستقر في هذا المكان سوف نتابع الرحلة إلى الجبال البعيدة";layer.style.color="000000"
        let region=CGRect(x:50,y:60,width:280,height:200)
        for shape in BubbleShape.allCases{
            let fitted=try BubbleLayout.fit(layer,request:BubbleLayoutRequest(bounds:region,shape:shape)),bounds=LayerRenderer.bounds(fitted).applying(LayerRenderer.transform(fitted))
            XCTAssertTrue(region.insetBy(dx:15,dy:15).contains(bounds));XCTAssertEqual(fitted.style.color,layer.style.color);XCTAssertEqual(fitted.style.fontPath,layer.style.fontPath)
            XCTAssertEqual(fitted.textContent.split(whereSeparator:{$0.isWhitespace}),layer.textContent.split(whereSeparator:{$0.isWhitespace}))
            XCTAssertGreaterThan(fitted.style.fontSize,6)
        }
    }
    @MainActor func testGestureDraftDoesNotPublishEveryPoint()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        var page=EditorPage(title:"drag",width:800,height:15000);let layer=EditorLayer(kind:.text);page.layers=[layer]
        let model=EditorModel(page:page,library:LibraryStore(root:root));model.selected=layer.id
        let coordinator=CanvasHost.Coordinator(model);coordinator.gesturePage=page
        var publications=0;let observation=model.objectWillChange.sink{publications+=1};defer{observation.cancel()}
        for i in 0..<100{coordinator.changeGesture{$0.frame.x=Double(i)}}
        XCTAssertEqual(publications,0);XCTAssertEqual(model.page,page);XCTAssertEqual(coordinator.gesturePage?.layers.first?.frame.x,99)
    }
    @MainActor func testFittedTyperInsertionMarksOnlyInsertedBubbleAndKeepsStyle()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),page=try ImagePipeline.fixture(root:root),model=EditorModel(page:page,library:library)
        let typer=TyperStore(directory:root.appendingPathComponent("Typer"));try typer.saveChapter(title:"chapter",source:"first words here\nsecond line",separation:.lines)
        let chapter=try XCTUnwrap(typer.activeChapter),bubble=chapter.pasteable[0]
        try typer.place([bubble],chapter:chapter.id,model:model,bubbleLayout:BubbleLayoutRequest(bounds:CGRect(x:40,y:50,width:250,height:150),shape:.oval))
        XCTAssertEqual(typer.activeChapter?.usedCount,1);XCTAssertEqual(typer.activeChapter?.bubbles[0].usedLayer,model.active?.id);XCTAssertFalse(typer.activeChapter!.bubbles[1].used)
        XCTAssertEqual(model.active?.style.fontPath,typer.tag(bubble.tagID)?.style.fontPath)
        let reopened=TyperStore(directory:typer.directory);XCTAssertEqual(reopened.activeChapter?.usedCount,1)
    }
}
