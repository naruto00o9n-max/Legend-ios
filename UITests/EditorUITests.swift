import XCTest

final class EditorUITests:XCTestCase {
    var app:XCUIApplication!
    override func setUp(){continueAfterFailure=false;app=XCUIApplication();app.launchArguments=["-ui-tests"];app.launch()}
    func capture(_ name:String){Thread.sleep(forTimeInterval:0.5);let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    func start(){let start=app.buttons["welcome-start"];XCTAssertTrue(start.waitForExistence(timeout:15));Thread.sleep(forTimeInterval:0.8);capture("01-welcome");start.tap();XCTAssertTrue(app.buttons["demo-project"].waitForExistence(timeout:8));capture("02-library");assertLayout()}
    func openEditor(){start();app.buttons["demo-project"].tap();let project=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch;let link=app.otherElements.matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch
        if project.waitForExistence(timeout:30){project.tap()}else{XCTAssertTrue(link.waitForExistence(timeout:30));link.tap()}
        XCTAssertTrue(app.buttons["tool-text"].waitForExistence(timeout:15));capture("03-editor-long-image");assertLayout()
    }
    func reveal(_ button:XCUIElement,in strip:XCUIElement){
        for _ in 0..<12{let frame=button.frame;if frame.width>1 && frame.height>1 && frame.minX>=app.frame.minX && frame.maxX<=app.frame.maxX{if button.isHittable{return}};let forward=frame.maxX>app.frame.maxX;let start=strip.coordinate(withNormalizedOffset:CGVector(dx:forward ? 0.75:0.25,dy:0.5)),end=strip.coordinate(withNormalizedOffset:CGVector(dx:forward ? 0.25:0.75,dy:0.5));start.press(forDuration:0.05,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0.25)}
        XCTFail("Control did not become visible: \(button.identifier)")
    }
    func tool(_ name:String){let button=app.buttons["tool-"+name];reveal(button,in:app.scrollViews["tool-strip"]);button.tap()}
    func assertLayout(){let screen=app.frame;for button in app.buttons.allElementsBoundByIndex where !button.identifier.hasPrefix("tool-") && !button.identifier.hasPrefix("panel-") && button.isHittable {let f=button.frame;XCTAssertLessThanOrEqual(f.width,screen.width+1,button.label);XCTAssertGreaterThanOrEqual(f.minX,screen.minX-1,button.label);XCTAssertLessThanOrEqual(f.maxX,screen.maxX+1,button.label);XCTAssertLessThanOrEqual(f.maxY,screen.maxY+1,button.label)}}
    func testWelcomeFoldersAndAssistant(){start();app.buttons["new-folder"].tap();capture("04-new-folder");app.alerts.textFields.firstMatch.tap();app.alerts.textFields.firstMatch.typeText("الفصل الأول");app.alerts.buttons["إنشاء"].tap();capture("05-folder-created");app.buttons["assistant"].tap();XCTAssertTrue(app.textViews["assistant-text"].waitForExistence(timeout:5));app.textViews["assistant-text"].tap();app.textViews["assistant-text"].typeText("حوار أول\n\nحوار ثان");capture("06-assistant");assertLayout()}
    func testEditorTextLayersAndExport(){openEditor();tool("text");let text=app.textViews["text-input"];XCTAssertTrue(text.waitForExistence(timeout:6));text.tap();text.typeText("كوكيز إيدتور\nاختبار الحوار العربي");capture("07-text-entry-keyboard");app.buttons["تم"].tap();capture("08-text-layer");assertLayout();reveal(app.buttons["panel-format"],in:app.scrollViews["panel-strip"]);app.buttons["panel-format"].tap();capture("09-format");app.buttons["تم"].tap();tool("layers");capture("10-layers");app.buttons["تم"].tap();app.buttons["export"].tap();capture("11-export-settings");app.buttons["export-png"].tap();XCTAssertTrue(app.buttons["share-png"].waitForExistence(timeout:60));capture("12-export-complete")}
    func testEveryTextInspectorAndFontLibrary(){
        openEditor();tool("text");XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:6));app.buttons["تم"].tap()
        for panel in ["font","format","color","stroke","background","shadow","position","spacing","threeD","perspective","effects","texture","opacity","styles","mask"]{
            let button=app.buttons["panel-"+panel];reveal(button,in:app.scrollViews["panel-strip"]);button.tap();XCTAssertTrue(app.buttons["تم"].waitForExistence(timeout:6));capture("inspector-"+panel);app.buttons["تم"].tap()
        }
    }
    func testPinchAndDrawing(){openEditor();let canvas=app.scrollViews["canvas-scroll"],zoom=app.staticTexts["canvas-zoom"],before=zoom.label;canvas.pinch(withScale:3,velocity:1);let changed=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in zoom.label != before},object:zoom);XCTAssertEqual(XCTWaiter.wait(for:[changed],timeout:8),.completed,"Pinch must change the displayed zoom");capture("13-pinch-zoom");tool("brush");let start=canvas.coordinate(withNormalizedOffset:CGVector(dx:0.3,dy:0.3));start.press(forDuration:0.05,thenDragTo:canvas.coordinate(withNormalizedOffset:CGVector(dx:0.7,dy:0.5)));XCTAssertTrue(app.buttons["undo"].isEnabled,"Drawing must create an undoable edit");XCTAssertTrue((canvas.value as? String ?? "").contains("1 خطوط رسم"),"Drawing gesture must commit a stroke");capture("14-drawing");assertLayout()}
    func testShapesReaderBrushSettingsAndFontLibrary(){
        start();app.buttons["settings"].tap();XCTAssertTrue(app.buttons["font-library"].waitForExistence(timeout:5));capture("15-settings");app.buttons["font-library"].tap();XCTAssertTrue(app.buttons["font-close"].waitForExistence(timeout:5));capture("16-font-library");app.buttons["font-close"].tap();app.buttons["settings-close"].tap()
        app.buttons["demo-project"].tap();let project=app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch;XCTAssertTrue(project.waitForExistence(timeout:30));project.tap();XCTAssertTrue(app.buttons["tool-brush"].waitForExistence(timeout:10))
        tool("brush");app.buttons["إعدادات الفرشاة"].tap();XCTAssertTrue(app.buttons["brush-close"].waitForExistence(timeout:5));capture("17-brush-settings");app.buttons["brush-close"].tap();tool("shapes");XCTAssertTrue(app.buttons["شكل 1"].waitForExistence(timeout:5));capture("18-shapes");app.buttons["شكل 1"].tap();tool("reader");XCTAssertTrue(app.buttons["إغلاق القراءة"].waitForExistence(timeout:5));capture("19-reader");app.buttons["إغلاق القراءة"].tap()
    }
}
