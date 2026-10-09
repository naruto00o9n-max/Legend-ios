import XCTest

final class EditorUITests:XCTestCase {
    var app:XCUIApplication!
    override func setUp(){continueAfterFailure=false;app=XCUIApplication();app.launchArguments=["-ui-tests"];app.launch()}
    func capture(_ name:String){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    func start(){let start=app.buttons["welcome-start"];XCTAssertTrue(start.waitForExistence(timeout:15));Thread.sleep(forTimeInterval:0.8);capture("01-welcome");start.tap();XCTAssertTrue(app.buttons["demo-project"].waitForExistence(timeout:8));capture("02-library");assertLayout()}
    func openEditor(){start();app.buttons["demo-project"].tap();let project=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch;let link=app.otherElements.matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch
        if project.waitForExistence(timeout:30){project.tap()}else{XCTAssertTrue(link.waitForExistence(timeout:30));link.tap()}
        XCTAssertTrue(app.buttons["tool-text"].waitForExistence(timeout:15));capture("03-editor-long-image");assertLayout()
    }
    func tool(_ name:String){let button=app.buttons["tool-"+name];let strip=app.scrollViews["tool-strip"];for _ in 0..<5{if button.isHittable{button.tap();return};strip.swipeRight()};XCTAssertTrue(button.isHittable);button.tap()}
    func assertLayout(){let screen=app.frame;for button in app.buttons.allElementsBoundByIndex where button.isHittable && !button.identifier.hasPrefix("tool-") && !button.identifier.hasPrefix("panel-") {let f=button.frame;XCTAssertLessThanOrEqual(f.width,screen.width+1,button.label);XCTAssertGreaterThanOrEqual(f.minX,screen.minX-1,button.label);XCTAssertLessThanOrEqual(f.maxX,screen.maxX+1,button.label);XCTAssertLessThanOrEqual(f.maxY,screen.maxY+1,button.label)}}
    func testWelcomeFoldersAndAssistant(){start();app.buttons["new-folder"].tap();capture("04-new-folder");app.alerts.textFields.firstMatch.tap();app.alerts.textFields.firstMatch.typeText("الفصل الأول");app.alerts.buttons["إنشاء"].tap();capture("05-folder-created");app.buttons["assistant"].tap();XCTAssertTrue(app.textViews["assistant-text"].waitForExistence(timeout:5));app.textViews["assistant-text"].tap();app.textViews["assistant-text"].typeText("حوار أول\n\nحوار ثان");capture("06-assistant");assertLayout()}
    func testEditorTextLayersAndExport(){openEditor();tool("text");let text=app.textViews["text-input"];XCTAssertTrue(text.waitForExistence(timeout:6));text.tap();text.typeText("كوكيز إيدتور\nاختبار الحوار العربي");capture("07-text-entry-keyboard");app.buttons["تم"].tap();capture("08-text-layer");assertLayout();app.buttons["panel-format"].tap();capture("09-format");app.buttons["تم"].tap();tool("layers");capture("10-layers");app.buttons["تم"].tap();app.buttons["export"].tap();capture("11-export-settings");app.buttons["export-png"].tap();XCTAssertTrue(app.buttons["share-png"].waitForExistence(timeout:60));capture("12-export-complete")}
    func testPinchAndDrawing(){openEditor();let canvas=app.scrollViews["canvas-scroll"];canvas.pinch(withScale:3,velocity:1);capture("13-pinch-zoom");tool("brush");let start=canvas.coordinate(withNormalizedOffset:CGVector(dx:0.3,dy:0.3));start.press(forDuration:0.05,thenDragTo:canvas.coordinate(withNormalizedOffset:CGVector(dx:0.7,dy:0.5)));capture("14-drawing");assertLayout()}
}
