import XCTest

final class ServiceUITests:XCTestCase {
    func testLoginAndSignupInterfaces(){
        let app=XCUIApplication();app.launchArguments=["-ui-tests"];app.launch()
        XCTAssertTrue(app.buttons["welcome-start"].waitForExistence(timeout:15));app.buttons["welcome-start"].tap()
        XCTAssertTrue(app.textFields["account-email"].waitForExistence(timeout:10))
        XCTAssertEqual(app.textFields["account-email"].frame.midX,app.frame.midX,accuracy:50);capture(app,"20-account-fullscreen-login")
        app.buttons["إنشاء حساب جديد"].tap();capture(app,"21-original-account-signup")
        app.buttons["account-skip"].tap();XCTAssertTrue(app.buttons["demo-project"].waitForExistence(timeout:8))
        capture(app,"22-online-local-workspace")
        app.buttons["settings"].tap();XCTAssertTrue(app.buttons["المجتمع"].waitForExistence(timeout:5));app.buttons["المجتمع"].tap()
        let post=app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'community-post-'")).firstMatch;XCTAssertTrue(post.waitForExistence(timeout:30));capture(app,"23-original-community")
    }
    func capture(_ app:XCUIApplication,_ name:String){let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}
