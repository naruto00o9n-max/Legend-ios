import XCTest

final class ServiceUITests:XCTestCase {
    func testLoginAndSignupInterfaces(){
        let app=XCUIApplication();app.launchArguments=["-ui-tests"];app.launch()
        XCTAssertTrue(app.buttons["welcome-start"].waitForExistence(timeout:15));app.buttons["welcome-start"].tap()
        XCTAssertTrue(app.textFields["account-email"].waitForExistence(timeout:10))
        capture(app,"20-original-account-login")
        app.buttons["إنشاء حساب جديد"].tap();capture(app,"21-original-account-signup")
        app.buttons["العودة إلى التحرير المحلي"].tap();XCTAssertTrue(app.buttons["demo-project"].waitForExistence(timeout:8))
        capture(app,"22-online-local-workspace")
    }
    func capture(_ app:XCUIApplication,_ name:String){let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)}
}
