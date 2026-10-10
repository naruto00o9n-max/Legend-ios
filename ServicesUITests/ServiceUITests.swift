import XCTest

final class ServiceUITests:XCTestCase {
    override func setUp(){continueAfterFailure=false}
    func testLoginAndSignupInterfaces(){
        let app=XCUIApplication();app.launchArguments=["-ui-tests"];app.launch()
        XCTAssertTrue(app.buttons["welcome-start"].waitForExistence(timeout:15));app.buttons["welcome-start"].tap()
        XCTAssertTrue(app.textFields["account-email"].waitForExistence(timeout:10))
        XCTAssertEqual(app.textFields["account-email"].frame.midX,app.frame.midX,accuracy:50);capture(app,"20-account-fullscreen-login")
        app.buttons["إنشاء حساب جديد"].tap();capture(app,"21-original-account-signup")
        app.buttons["account-skip"].tap();XCTAssertTrue(app.buttons["demo-project"].waitForExistence(timeout:8))
        capture(app,"22-unified-workspace")
        app.buttons["settings"].tap();let community=app.buttons["settings-community"];XCTAssertTrue(community.waitForExistence(timeout:5));XCTAssertGreaterThanOrEqual(community.frame.height,44,"The whole row must respond to a tap");XCTAssertGreaterThan(community.images["person.2"].frame.midX,community.staticTexts["المجتمع"].frame.midX,"Settings must lay out Arabic from the right");community.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        let post=app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'community-post-'")).firstMatch;XCTAssertTrue(post.waitForExistence(timeout:60),app.debugDescription);capture(app,"23-community")
        post.tap();XCTAssertTrue(app.buttons["سجّل الدخول للمشاركة"].waitForExistence(timeout:10));capture(app,"25-community-post-comments")
    }
    func capture(_ app:XCUIApplication,_ name:String){let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}
