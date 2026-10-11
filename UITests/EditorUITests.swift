import XCTest

final class EditorUITests:XCTestCase {
    var app:XCUIApplication!
    override func setUp(){continueAfterFailure=false;app=XCUIApplication();app.launchArguments=["-ui-tests"];app.launch()}
    func capture(_ name:String){Thread.sleep(forTimeInterval:0.5);let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    func start(){let start=app.buttons["welcome-start"];XCTAssertTrue(start.waitForExistence(timeout:15));Thread.sleep(forTimeInterval:0.8);capture("01-welcome");start.tap();if app.buttons["account-skip"].waitForExistence(timeout:3){app.buttons["account-skip"].tap()};XCTAssertTrue(app.buttons["demo-project"].waitForExistence(timeout:8));capture("02-library");assertLayout()}
    func openEditor(){start();openDemoFromLibrary()}
    func openDemoFromLibrary(){app.buttons["demo-project"].tap();let project=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch;let link=app.otherElements.matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch
        if project.waitForExistence(timeout:30){project.tap()}else{XCTAssertTrue(link.waitForExistence(timeout:30));link.tap()}
        XCTAssertTrue(app.buttons["tool-text"].waitForExistence(timeout:15));capture("03-editor-long-image");assertLayout()
    }
    func reveal(_ button:XCUIElement,in strip:XCUIElement){
        for _ in 0..<12{let frame=button.frame;if frame.width>1 && frame.height>1 && frame.minX>=app.frame.minX && frame.maxX<=app.frame.maxX{if button.isHittable{return}};let forward=frame.maxX>app.frame.maxX;let start=strip.coordinate(withNormalizedOffset:CGVector(dx:forward ? 0.75:0.25,dy:0.5)),end=strip.coordinate(withNormalizedOffset:CGVector(dx:forward ? 0.25:0.75,dy:0.5));start.press(forDuration:0.05,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0.25)}
        XCTFail("Control did not become visible: \(button.identifier)")
    }
    func revealVertical(_ element:XCUIElement,in view:XCUIElement?=nil){
        let scroll=view ?? app.scrollViews.firstMatch
        for _ in 0..<16{if element.exists && element.isHittable && element.frame.minY>=scroll.frame.minY && element.frame.maxY<=scroll.frame.maxY{return};if element.exists && element.frame.minY<scroll.frame.minY{scroll.swipeDown()}else{scroll.swipeUp()}}
        XCTAssertTrue(element.isHittable,"Control must be reachable by scrolling: "+element.identifier)
    }
    func tapVisible(_ name:String){let element=app.buttons[name];revealVertical(element);element.tap()}
    func tool(_ name:String){if app.buttons["object-back"].exists{app.buttons["object-back"].tap()};if name=="layers"{app.buttons["layers-header"].tap();return};if name != "text",app.buttons["text-back"].exists{app.buttons["text-back"].tap()};if !["brush","eraser"].contains(name),app.buttons["brush-back"].exists{app.buttons["brush-back"].tap()};let button=app.buttons["tool-"+name];reveal(button,in:app.scrollViews["tool-strip"]);button.tap()}
    func assertLayout(){let screen=app.frame;for button in app.buttons.allElementsBoundByIndex where !button.identifier.hasPrefix("tool-") && !button.identifier.hasPrefix("panel-") && button.isHittable {let f=button.frame;XCTAssertLessThanOrEqual(f.width,screen.width+1,button.label);XCTAssertGreaterThanOrEqual(f.minX,screen.minX-1,button.label);XCTAssertLessThanOrEqual(f.maxX,screen.maxX+1,button.label)
        // A partially visible card in a vertical ScrollView is intentional.
        // Overflowing fixed controls must still fail this check.
        if f.maxY>screen.maxY+1{let identifier=button.identifier.isEmpty ? button.label:button.identifier;XCTAssertTrue(app.scrollViews.containing(.button,identifier:identifier).firstMatch.exists,"Overflow without scrolling: "+button.label)}
    }}
    func testPhotosImportAndIPadOrientation() {
        start();app.buttons["import-image"].tap()
        // Current Photos uses image elements for assets. Its first collection
        // cell is the sidebar's Photos tab, not a selectable photograph.
        let asset=app.images.matching(identifier:"PXGGridLayout-Info").firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout:30),app.debugDescription)
        capture("30-photos-picker");asset.tap()
        let add=app.buttons.matching(NSPredicate(format:"label == 'Add' OR label == 'إضافة' OR label == 'تم' OR label == 'Done'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout:5));XCTAssertTrue(add.isEnabled,"A real photo must be selected before Add");capture("30-photos-selected");add.tap()
        let project=app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch
        XCTAssertTrue(project.waitForExistence(timeout:40),"Photos selection must create an editable project")
        project.tap();XCTAssertTrue(app.buttons["tool-text"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["canvas-zoom"].label.contains("800 × 15000"))
        capture("31-photos-import-editor")
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in self.app.frame.width>self.app.frame.height},object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[landscape],timeout:10),.completed)
        capture("32-ipad-landscape-editor");assertLayout()
        tool("text");XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:5));app.buttons["تم"].tap()
        XCTAssertFalse(app.scrollViews["tool-strip"].exists)
        let landscapeHandle=app.buttons["selection-resize"]
        XCTAssertTrue(landscapeHandle.isHittable,"New text must stay editable after rotation")
        XCTAssertTrue(app.scrollViews["canvas-scroll"].frame.contains(landscapeHandle.frame),"The resize handle must stay inside the landscape canvas, clear of the tool strip")
        capture("33-landscape-text-handles");assertLayout()
        app.buttons["text-back"].tap();XCTAssertTrue(app.scrollViews["tool-strip"].exists)
        XCUIDevice.shared.orientation = .portrait
        let portrait=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in self.app.frame.height>self.app.frame.width},object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[portrait],timeout:10),.completed)
        capture("34-portrait-return")
    }
    func testTextHandlesKeepImageWhileEditing() {
        openEditor();tool("text");XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:5));app.buttons["تم"].tap()
        let copy=app.buttons["selection-duplicate"];XCTAssertTrue(copy.waitForExistence(timeout:10));copy.tap()
        let canvas=app.scrollViews["canvas-scroll"];XCTAssertTrue((canvas.value as? String ?? "").contains("2 طبقات"))
        capture("35-text-duplicated-with-stable-image")
        let resize=app.buttons["selection-resize"];XCTAssertTrue(resize.isHittable)
        let before=canvas.value as? String ?? ""
        let start=resize.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:40,dy:20)))
        XCTAssertNotEqual(canvas.value as? String,before,"Selection handle must resize the layer")
        capture("36-text-resized-with-stable-image")
        app.buttons["selection-edit"].tap();XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:5))
    }
    func testCreateUserStyleAndApplyGlyphGradient(){
        openEditor();tool("text");XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:6));app.textViews["text-input"].tap();app.textViews["text-input"].typeText("نمط الحوار");XCTAssertEqual(app.textViews["text-input"].value as? String,"نمط الحوار","Typing into a new text layer must replace its placeholder");app.buttons["تم"].tap()
        reveal(app.buttons["panel-color"],in:app.scrollViews["panel-strip"]);app.buttons["panel-color"].tap();let gradient=app.switches["تدرج لوني"];for _ in 0..<5{if gradient.isHittable{break};app.scrollViews["text-inspector-scroll"].swipeUp()};XCTAssertTrue(gradient.exists);gradient.tap();capture("batch-11-glyph-gradient");app.buttons["تم"].tap()
        reveal(app.buttons["panel-styles"],in:app.scrollViews["panel-strip"]);app.buttons["panel-styles"].tap();XCTAssertTrue(app.buttons["style-create"].waitForExistence(timeout:5));app.buttons["style-create"].tap();capture("batch-12-create-style");app.alerts.buttons["حفظ"].tap();let saved=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'saved-style-'")).firstMatch;XCTAssertTrue(saved.waitForExistence(timeout:10));capture("batch-13-custom-style-library");saved.tap();XCTAssertFalse(app.alerts["تعذر حفظ النمط"].exists);app.buttons["تم"].tap();capture("batch-14-styled-text-on-canvas")
    }
    func testChapterBlankMergeSplitReaderAndExport(){
        func page(_ index:Int)->XCUIElement{app.descendants(matching:.any).matching(identifier:"chapter-page-\(index)").firstMatch}
        start();app.buttons["new-chapter"].tap();app.alerts.textFields.firstMatch.tap();app.alerts.textFields.firstMatch.typeText("فصل الجودة");app.alerts.buttons["إنشاء"].tap()
        let project=app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch;XCTAssertTrue(project.waitForExistence(timeout:10));project.tap();XCTAssertTrue(app.buttons["chapter-actions"].waitForExistence(timeout:10));capture("batch-01-chapter-empty")
        for index in 0..<2{tapVisible("chapter-actions");app.buttons["لوحة فارغة"].tap();XCTAssertTrue(app.buttons["chapter-operation-apply"].waitForExistence(timeout:5));capture("batch-02-blank-canvas-options");app.buttons["chapter-operation-apply"].tap();XCTAssertTrue(page(index).waitForExistence(timeout:30))}
        capture("batch-03-two-pages");tapVisible("chapter-select");revealVertical(page(0));page(0).tap();revealVertical(page(1));page(1).tap();capture("batch-04-multiple-selection")
        tapVisible("chapter-actions");app.buttons["دمج المحدد"].tap();XCTAssertTrue(app.buttons["chapter-operation-apply"].waitForExistence(timeout:5));capture("batch-05-merge-studio");app.buttons["chapter-operation-apply"].tap()
        let merged=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in !page(1).exists && !self.app.buttons["chapter-operation-apply"].exists},object:nil);XCTAssertEqual(XCTWaiter.wait(for:[merged],timeout:30),.completed)
        tapVisible("chapter-select");tapVisible("chapter-actions");app.buttons["تقسيم الصفحات"].tap();XCTAssertTrue(app.buttons["chapter-operation-apply"].waitForExistence(timeout:5));capture("batch-06-split-options");app.buttons["chapter-operation-apply"].tap();XCTAssertTrue(page(1).waitForExistence(timeout:30));capture("batch-07-split-result")
        app.buttons["chapter-reader"].tap();XCTAssertTrue(app.buttons["إغلاق"].waitForExistence(timeout:10));capture("batch-08-multipage-reader");app.buttons["إغلاق"].tap();app.buttons["chapter-export-open"].tap();XCTAssertTrue(app.buttons["chapter-export"].waitForExistence(timeout:10));capture("batch-09-export-studio");app.buttons["chapter-export"].tap();XCTAssertTrue(app.buttons["chapter-export-share"].waitForExistence(timeout:60));capture("batch-10-export-complete")
    }
    func testWelcomeFoldersAndAssistant(){start();app.buttons["new-folder"].tap();capture("04-new-folder");app.alerts.textFields.firstMatch.tap();app.alerts.textFields.firstMatch.typeText("الفصل الأول");app.alerts.buttons["إنشاء"].tap();capture("05-folder-created");tapVisible("assistant");XCTAssertTrue(app.buttons["typer-new"].waitForExistence(timeout:5));app.buttons["typer-new"].tap();let source=app.textViews["typer-source"];XCTAssertTrue(source.waitForExistence(timeout:5));source.tap();source.typeText("حوار أول\nحوار ثان");capture("06-typer-chapter-source");app.buttons["typer-save"].tap();XCTAssertTrue(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'typer-chapter-'")).firstMatch.waitForExistence(timeout:5));capture("37-typer-saved-chapter");assertLayout()}
    func testTyperPlacesBubbleAndRetainsGreyUsedProgress(){
        openEditor();app.buttons["tool-assistant"].tap();XCTAssertTrue(app.buttons["إضافة نص الفصل"].waitForExistence(timeout:5));app.buttons["إضافة نص الفصل"].tap();app.buttons["typer-new"].tap();let source=app.textViews["typer-source"];XCTAssertTrue(source.waitForExistence(timeout:5));source.tap();source.typeText("حوار أول\nحوار ثان");app.buttons["typer-save"].tap();XCTAssertTrue(app.buttons["typer-close"].waitForExistence(timeout:5));app.buttons["typer-close"].tap()
        let first=app.buttons["typer-bubble-0"];XCTAssertTrue(first.waitForExistence(timeout:5));first.tap();XCTAssertEqual(first.value as? String,"مستخدمة");XCTAssertTrue((app.scrollViews["canvas-scroll"].value as? String ?? "").contains("1 طبقات"));capture("38-typer-bubble-used-on-canvas")
        app.buttons["typer-panel-close"].tap();XCTAssertTrue(app.buttons["selection-edit"].waitForExistence(timeout:5));app.buttons["tool-assistant"].tap();XCTAssertEqual(app.buttons["typer-bubble-0"].value as? String,"مستخدمة");app.buttons["typer-next"].tap();XCTAssertEqual(app.buttons["typer-bubble-1"].value as? String,"مستخدمة");capture("39-typer-next-bubble");app.buttons["typer-panel-close"].tap()
    }

    func testEditorTextLayersAndExport(){openEditor();tool("text");let text=app.textViews["text-input"];XCTAssertTrue(text.waitForExistence(timeout:6));XCTAssertFalse(app.scrollViews["tool-strip"].exists,"Text mode replaces primary tools");XCTAssertTrue(app.buttons["text-add"].exists);text.tap();text.typeText("كوكيز إيدتور\nاختبار الحوار العربي");capture("07-text-entry-keyboard");app.buttons["تم"].tap();capture("08-text-layer");assertLayout();reveal(app.buttons["panel-format"],in:app.scrollViews["panel-strip"]);app.buttons["panel-format"].tap();capture("09-format");app.buttons["تم"].tap();tool("layers");capture("10-layers");app.buttons["تم"].tap();app.buttons["export"].tap();capture("11-export-settings");app.buttons["export-png"].tap();XCTAssertTrue(app.buttons["share-png"].waitForExistence(timeout:60));capture("12-export-complete")}
    func testLayerTypeChipsMatchTheVisibleRows(){
        openEditor();tool("text");XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:5));app.buttons["تم"].tap();tool("shapes");app.buttons["شكل 1"].tap();tool("layers")
        let text=app.buttons["layers-filter-text"];XCTAssertTrue(text.waitForExistence(timeout:5));text.tap();XCTAssertEqual(text.value as? String,"مختار")
        XCTAssertTrue(app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'layer-row-text-'")).firstMatch.exists);XCTAssertFalse(app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'layer-row-shape-'")).firstMatch.exists);capture("batch-19-layer-type-filter");assertLayout()
        app.buttons["layers-filter-all"].tap();XCTAssertTrue(app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'layer-row-shape-'")).firstMatch.exists);capture("batch-20-layer-types-and-actions")
    }
    func testLocalDiagnosticReportsScreen(){
        start();app.buttons["settings"].tap();let button=app.buttons["settings-diagnostics"];if !button.isHittable{app.scrollViews.firstMatch.swipeUp()};XCTAssertTrue(button.waitForExistence(timeout:5));button.tap();XCTAssertTrue(app.buttons["diagnostics-close"].waitForExistence(timeout:5));capture("batch-18-diagnostic-reports");assertLayout();app.buttons["diagnostics-close"].tap()
    }
    func testEveryTextInspectorAndFontLibrary(){
        openEditor();tool("text");XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:6));app.buttons["تم"].tap()
        for panel in ["font","format","color","gradientMap","stroke","background","shadow","position","spacing","threeD","perspective","effects","texture","opacity","styles","mask"]{
            let button=app.buttons["panel-"+panel];reveal(button,in:app.scrollViews["panel-strip"]);button.tap();XCTAssertTrue(app.buttons["تم"].waitForExistence(timeout:6));capture("inspector-"+panel);app.buttons["تم"].tap()
        }
    }
    func testShapeToolsReplaceMainStripAndKeepGeometryEditable(){
        openEditor();tool("shapes");app.buttons["شكل 1"].tap()
        XCTAssertTrue(app.buttons["object-position"].waitForExistence(timeout:5));XCTAssertFalse(app.scrollViews["tool-strip"].exists);capture("batch-15-shape-tool-mode")
        app.buttons["object-position"].tap();XCTAssertTrue(app.textFields["value-الموضع أفقيًا"].waitForExistence(timeout:5));capture("batch-16-object-position");app.buttons["تم"].tap()
        reveal(app.buttons["shape-color"],in:app.scrollViews["object-strip"]);app.buttons["shape-color"].tap();XCTAssertFalse(app.switches["تدرج لوني"].exists);capture("batch-17-shape-color");app.buttons["تم"].tap()
        app.buttons["object-back"].tap();XCTAssertTrue(app.buttons["tool-text"].exists)
    }
    func testPinchAndDrawing(){openEditor();let canvas=app.scrollViews["canvas-scroll"],zoom=app.staticTexts["canvas-zoom"],before=zoom.label;canvas.pinch(withScale:3,velocity:1);let changed=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in zoom.label != before},object:zoom);XCTAssertEqual(XCTWaiter.wait(for:[changed],timeout:8),.completed,"Pinch must change the displayed zoom");capture("13-pinch-zoom");tool("brush");let start=canvas.coordinate(withNormalizedOffset:CGVector(dx:0.3,dy:0.3));start.press(forDuration:0.05,thenDragTo:canvas.coordinate(withNormalizedOffset:CGVector(dx:0.7,dy:0.5)));XCTAssertTrue(app.buttons["undo"].isEnabled,"Drawing must create an undoable edit");XCTAssertTrue((canvas.value as? String ?? "").contains("1 خطوط رسم"),"Drawing gesture must commit a stroke");capture("14-drawing");assertLayout();let editorZoom=zoom.label;tool("reader");XCTAssertTrue(app.buttons["إغلاق القراءة"].waitForExistence(timeout:5));capture("24-reader-after-editing");app.buttons["إغلاق القراءة"].tap();XCTAssertEqual(zoom.label,editorZoom,"Returning from reading must preserve editor zoom")}
    func testShapesReaderBrushSettingsAndFontLibrary(){
        start();app.buttons["settings"].tap();XCTAssertTrue(app.buttons["settings-font-library"].waitForExistence(timeout:5));capture("15-settings");tapVisible("settings-font-library");XCTAssertTrue(app.buttons["font-close"].waitForExistence(timeout:5));capture("16-font-library");app.buttons["font-close"].tap();app.buttons["settings-close"].tap()
        app.buttons["demo-project"].tap();let project=app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'project-'")).firstMatch;XCTAssertTrue(project.waitForExistence(timeout:30));project.tap();XCTAssertTrue(app.buttons["tool-brush"].waitForExistence(timeout:10))
        tool("brush");app.buttons["إعدادات الفرشاة"].tap();XCTAssertTrue(app.buttons["brush-close"].waitForExistence(timeout:5));capture("17-brush-settings");app.buttons["brush-close"].tap();tool("shapes");XCTAssertTrue(app.buttons["شكل 1"].waitForExistence(timeout:5));capture("18-shapes");app.buttons["شكل 1"].tap();tool("reader");XCTAssertTrue(app.buttons["إغلاق القراءة"].waitForExistence(timeout:5));capture("19-reader");app.buttons["إغلاق القراءة"].tap()
    }
    func testLayerButtonsActuallyHideUnlockAndDelete() {
        openEditor();tool("text");app.buttons["text-inspector-close"].tap();tool("layers")
        let eye=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'layer-eye-' ")).firstMatch,lock=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'layer-lock-' ")).firstMatch,delete=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'layer-delete-' ")).firstMatch
        XCTAssertTrue(eye.waitForExistence(timeout:5));XCTAssertEqual(eye.value as? String,"visible");eye.tap();XCTAssertEqual(eye.value as? String,"hidden");eye.tap();XCTAssertEqual(eye.value as? String,"visible")
        lock.tap();XCTAssertEqual(lock.value as? String,"locked");XCTAssertFalse(delete.isEnabled);lock.tap();XCTAssertEqual(lock.value as? String,"unlocked");XCTAssertTrue(delete.isEnabled);capture("fix-layer-controls");delete.tap();XCTAssertFalse(eye.exists);app.buttons["layers-close"].tap();XCTAssertTrue((app.scrollViews["canvas-scroll"].value as? String ?? "").hasPrefix("0 طبقات"))
    }
    func testCanvasTapDoesNotCreateUnrequestedTextAndFontsStayInsideEditor() {
        openEditor();tool("text");app.buttons["text-inspector-close"].tap();let canvas=app.scrollViews["canvas-scroll"]
        canvas.coordinate(withNormalizedOffset:CGVector(dx:0.15,dy:0.18)).tap();XCTAssertTrue((canvas.value as? String ?? "").hasPrefix("1 طبقات"));XCTAssertFalse(app.buttons["canvas-add-text-confirm"].exists)
        app.buttons["text-add"].tap();app.buttons["text-inspector-close"].tap();let button=app.buttons["panel-font"];reveal(button,in:app.scrollViews["panel-strip"]);button.tap();revealVertical(app.buttons["editor-font-library"],in:app.scrollViews["text-inspector-scroll"]);app.buttons["editor-font-library"].tap();XCTAssertTrue(app.buttons["font-close"].waitForExistence(timeout:5));let filters=app.scrollViews["font-filter-strip"];for name in ["العربية","المفضلة","آخر استخدام"]{let item=app.buttons["font-category-"+name];for _ in 0..<8{if item.exists && item.isHittable{break};filters.swipeRight()};XCTAssertTrue(item.exists)};capture("fix-in-editor-font-library");app.buttons["font-close"].tap();XCTAssertTrue(app.buttons["text-add"].exists)
    }
    func testRealStorageScreenShowsProjectsAndSelection() {
        start();app.buttons["settings"].tap();let storage=app.buttons["settings-storage"];for _ in 0..<4 where !storage.isHittable{app.swipeUp()};storage.tap();XCTAssertTrue(app.staticTexts["storage-total"].waitForExistence(timeout:10));XCTAssertTrue(app.buttons["storage-clear-cache"].exists);XCTAssertTrue(app.buttons["storage-backup-selected"].exists);capture("fix-storage-backup-selection");assertLayout()
    }

    func testTextTapSuggestionRequiresExplicitConfirmation() {
        start();app.buttons["settings"].tap();tapVisible("settings-workspace");XCTAssertTrue(app.buttons["workspace-settings-close"].waitForExistence(timeout:5));let matches=app.switches.matching(NSPredicate(format:"identifier == %@ OR label == %@","setting-tap-text","اقتراح إضافة نص عند لمس مساحة فارغة"));XCTAssertTrue(matches.firstMatch.waitForExistence(timeout:8),app.debugDescription)
        // SwiftUI can expose both the labeled row and its nested UISwitch as
        // switches. A row-center tap misses the actual RTL switch at the left.
        let candidates=matches.allElementsBoundByIndex.filter{ $0.isHittable }
        let toggle=candidates.min(by:{$0.frame.width<$1.frame.width}) ?? matches.firstMatch
        print("Tap-text switch candidates:",candidates.map{["frame":String(describing:$0.frame),"value":$0.value as? String ?? "nil"]})
        XCTAssertEqual(toggle.value as? String,"0")
        if toggle.frame.width>100{toggle.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:30,dy:toggle.frame.height/2)).tap()}else{toggle.tap()};let enabled=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","1"),object:toggle);XCTAssertEqual(XCTWaiter.wait(for:[enabled],timeout:3),.completed);app.buttons["workspace-settings-close"].tap();app.buttons["settings-close"].tap();openDemoFromLibrary()
        let canvas=app.scrollViews["canvas-scroll"];canvas.coordinate(withNormalizedOffset:CGVector(dx:0.45,dy:0.3)).tap();let confirm=app.buttons["canvas-add-text-confirm"];XCTAssertTrue(confirm.waitForExistence(timeout:5));XCTAssertTrue((canvas.value as? String ?? "").hasPrefix("0 طبقات"));capture("fix-text-add-confirmation");confirm.tap();XCTAssertTrue(app.textViews["text-input"].waitForExistence(timeout:5));XCTAssertTrue((canvas.value as? String ?? "").hasPrefix("1 طبقات"));XCTAssertFalse(confirm.exists)
    }

    func testStrokePlusMinusChangesByExactlyOneWithoutDragging() {
        openEditor();tool("text");app.buttons["text-inspector-close"].tap()
        let panel=app.buttons["panel-stroke"];reveal(panel,in:app.scrollViews["panel-strip"]);panel.tap()
        let field=app.textFields["value-السماكة"];XCTAssertTrue(field.waitForExistence(timeout:5))
        let parser=NumberFormatter();parser.locale=Locale(identifier:"ar");parser.numberStyle = .decimal
        let old=field.value as? String ?? "",before=parser.number(from:old)?.doubleValue ?? -100
        let plus=app.buttons["زيادة القيمة"].firstMatch;XCTAssertTrue(plus.exists);plus.tap()
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value != %@",old),object:field)
        XCTAssertEqual(XCTWaiter.wait(for:[changed],timeout:3),.completed)
        XCTAssertEqual(parser.number(from:field.value as? String ?? "")?.doubleValue ?? -100,before+1,accuracy:0.001)
        let minus=app.buttons["إنقاص القيمة"].firstMatch;XCTAssertTrue(minus.isEnabled);minus.tap()
        let restored=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@",old),object:field)
        XCTAssertEqual(XCTWaiter.wait(for:[restored],timeout:3),.completed)
    }

    func testTyperFilterPersistsAndReopensAtLatestUnusedBubble(){
        openEditor();app.buttons["tool-assistant"].tap();app.buttons["إضافة نص الفصل"].tap();app.buttons["typer-new"].tap()
        let source=app.textViews["typer-source"];XCTAssertTrue(source.waitForExistence(timeout:8));source.tap();source.typeText((1...26).map{String(format:"Bubble %02d",$0)}.joined(separator:"\n"));app.buttons["typer-save"].tap();XCTAssertTrue(app.buttons["typer-close"].waitForExistence(timeout:8));app.buttons["typer-close"].tap()
        let filter=app.buttons["typer-filter-unused"];XCTAssertTrue(filter.waitForExistence(timeout:8));filter.tap();XCTAssertEqual(filter.value as? String,"مختار")
        let chosen=app.buttons["typer-bubble-20"];revealVertical(chosen,in:app.scrollViews["typer-bubbles"]);chosen.tap()
        let progress=app.staticTexts["typer-progress"],inserted=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","1 / 26"),object:progress);XCTAssertEqual(XCTWaiter.wait(for:[inserted],timeout:10),.completed)
        app.buttons["typer-panel-close"].tap();app.buttons["tool-assistant"].tap();XCTAssertEqual(app.buttons["typer-filter-unused"].value as? String,"مختار");let next=app.buttons["typer-bubble-21"];XCTAssertTrue(next.waitForExistence(timeout:8));let resumed=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in next.isHittable},object:next);XCTAssertEqual(XCTWaiter.wait(for:[resumed],timeout:5),.completed,"Opening must scroll to the dialogue after the latest used bubble, even when earlier bubbles were skipped");capture("fix-glass-typer-resumed");assertLayout()
    }
    func testOrganizedSettingsAndDetailedGuide(){
        start();app.buttons["settings"].tap();XCTAssertTrue(app.buttons["settings-appearance"].exists);XCTAssertTrue(app.buttons["settings-typer"].exists);XCTAssertTrue(app.buttons["settings-storage"].exists);tapVisible("settings-appearance");XCTAssertTrue(app.buttons["workspace-category-appearance"].waitForExistence(timeout:5));capture("fix-appearance-sections");assertLayout();app.buttons["workspace-settings-close"].tap();tapVisible("settings-guide");XCTAssertTrue(app.buttons["guide-close"].waitForExistence(timeout:5));let topic=app.buttons["guide-topic-typer"];revealVertical(topic);topic.tap();XCTAssertTrue(app.staticTexts["ألوان الوسوم وأنماطها"].waitForExistence(timeout:5));capture("fix-detailed-guide");assertLayout()
    }
    func testRealFilesPickerImportsFontAndReturnsToLibrary(){
        start();app.buttons["settings"].tap();tapVisible("settings-font-library");XCTAssertTrue(app.buttons["font-import"].waitForExistence(timeout:8));app.buttons["font-import"].tap()
        let filename=NSPredicate(format:"label BEGINSWITH %@","Cookies-Import-Fixture")
        let file=app.staticTexts.matching(filename).firstMatch
        if !file.waitForExistence(timeout:3){
            let browse=app.buttons.matching(NSPredicate(format:"label == 'Browse' OR label == 'تصفح' OR label == 'استعراض'")).firstMatch
            if browse.exists{browse.tap()}
            let local=app.descendants(matching:.any).matching(NSPredicate(format:"label == 'On My iPad' OR label == 'On My iPhone' OR label == 'على الـ iPad' OR label == 'على الـ iPhone' OR label == 'على iPad الخاص بي' OR label == 'على iPhone الخاص بي'")).firstMatch
            if !local.waitForExistence(timeout:3),browse.exists{browse.tap()}
            XCTAssertTrue(local.waitForExistence(timeout:6),app.debugDescription);local.tap()
            let folder=app.staticTexts.matching(NSPredicate(format:"label == 'Cookies Editor' OR label == 'CookiesEditor'")).firstMatch;XCTAssertTrue(folder.waitForExistence(timeout:8),app.debugDescription);folder.tap()
        }
        XCTAssertTrue(file.waitForExistence(timeout:8),app.debugDescription);file.tap()
        let done=app.buttons.matching(NSPredicate(format:"label == 'Done' OR label == 'تم' OR label == 'Open' OR label == 'فتح'")).firstMatch
        if done.exists && done.isHittable{done.tap()}
        XCTAssertTrue(app.buttons["font-close"].waitForExistence(timeout:20),"The document picker must dismiss after selection")
        let filter=app.buttons["font-category-المستوردة"];reveal(filter,in:app.scrollViews["font-filter-strip"]);filter.tap()
        let installed=app.staticTexts.matching(filename).firstMatch;XCTAssertTrue(installed.waitForExistence(timeout:15),"Selected font must be installed and shown in the imported list");capture("fix-real-files-font-import");app.buttons["font-close"].tap();XCTAssertTrue(app.buttons["settings-font-library"].exists)
    }

}
