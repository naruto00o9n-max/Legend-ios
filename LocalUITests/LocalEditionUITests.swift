import XCTest

final class LocalEditionUITests:XCTestCase {
    private var app:XCUIApplication!
    override func setUp(){continueAfterFailure=false;app=XCUIApplication();app.launchArguments=["-ui-tests"];app.launch()}
    private func start(){let start=app.buttons["welcome-start"];XCTAssertTrue(start.waitForExistence(timeout:15));XCTAssertTrue(start.label.contains("ابدأ الإبداع"));start.tap();XCTAssertTrue(app.buttons["demo-project"].waitForExistence(timeout:10));XCTAssertFalse(app.buttons["account-workspace"].exists);XCTAssertFalse(app.textFields["account-email"].exists);XCTAssertFalse(app.buttons["account-google"].exists)}
    private func reveal(_ element:XCUIElement){for _ in 0..<12{if element.exists && element.isHittable{return};app.scrollViews.firstMatch.swipeUp()};XCTAssertTrue(element.isHittable,app.debugDescription)}
    private func revealTool(_ element:XCUIElement){
        let strip=app.scrollViews["tool-strip"]
        for _ in 0..<16{let visible=strip.frame.intersection(app.frame),frame=element.frame;if frame.width>1 && frame.height>1 && frame.minX>=visible.minX && frame.maxX<=visible.maxX && element.isHittable{return};let forward=frame.maxX>visible.maxX;let start=strip.coordinate(withNormalizedOffset:CGVector(dx:forward ? 0.72:0.28,dy:0.5)),end=strip.coordinate(withNormalizedOffset:CGVector(dx:forward ? 0.28:0.72,dy:0.5));start.press(forDuration:0.02,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0.12)}
        XCTAssertTrue(element.isHittable,"Local editor tool must be reachable by scrolling: \(element.frame), strip \(strip.frame)")
    }
    private func capture(_ name:String){let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
    func testNoAccountOrCommunityAndGuideRetainsLocalTools(){
        start();capture("fix-local-welcome-library");app.buttons["settings"].tap()
        XCTAssertFalse(app.buttons["settings-account"].exists);XCTAssertFalse(app.buttons["settings-community"].exists)
        XCTAssertTrue(app.buttons["settings-workspace"].exists);XCTAssertTrue(app.buttons["settings-font-library"].exists);XCTAssertTrue(app.buttons["settings-storage"].exists)
        let guide=app.buttons["settings-guide"];reveal(guide);guide.tap();XCTAssertTrue(app.buttons["guide-close"].waitForExistence(timeout:5));XCTAssertFalse(app.buttons["guide-topic-community"].exists)
        let typer=app.buttons["guide-topic-typer"];reveal(typer);typer.tap();XCTAssertTrue(app.staticTexts["ألوان الوسوم وأنماطها"].waitForExistence(timeout:5));capture("fix-local-guide-typer")
    }
    func testLocalPhotosEditingAndOriginalSizeExport(){
        start();app.buttons["import-image"].tap();let asset=app.images.matching(identifier:"PXGGridLayout-Info").firstMatch;let ready=asset.waitForExistence(timeout:45);if !ready{capture("failure-local-photos-picker");print("LOCAL_PHOTOS_FAILURE_HIERARCHY\n"+app.debugDescription)};XCTAssertTrue(ready,"A real Photos asset must be visible; no fake import fallback");asset.tap()
        let add=app.buttons.matching(NSPredicate(format:"label == 'Add' OR label == 'إضافة' OR label == 'تم' OR label == 'Done'")).firstMatch;XCTAssertTrue(add.waitForExistence(timeout:5));XCTAssertTrue(add.isEnabled);add.tap()
        let project=app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'project-' ")).firstMatch;XCTAssertTrue(project.waitForExistence(timeout:40));project.tap();XCTAssertTrue(app.buttons["tool-text"].waitForExistence(timeout:15));XCTAssertTrue(app.staticTexts["canvas-zoom"].label.contains("800 × 15000"));XCTAssertFalse(app.buttons["tool-more"].exists)
        let text=app.buttons["tool-text"];revealTool(text);text.tap();XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:8));app.textViews["text-input"].tap();app.textViews["text-input"].typeText("حوار النسخة المحلية");app.buttons["text-inspector-close"].tap();XCTAssertTrue((app.scrollViews["canvas-scroll"].value as? String ?? "").hasPrefix("1 طبقات"));app.buttons["export"].tap();XCTAssertTrue(app.buttons["export-png"].waitForExistence(timeout:8));app.buttons["export-png"].tap();XCTAssertTrue(app.buttons["share-png"].waitForExistence(timeout:60));capture("fix-local-original-size-export")
    }
}
