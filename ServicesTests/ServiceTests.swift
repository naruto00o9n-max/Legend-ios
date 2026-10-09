import XCTest
@testable import CookiesEditor

final class ServiceTests:XCTestCase {
    func testAuthenticationErrorsRemainSpecific() {
        XCTAssertTrue(ReferenceService.errorMessage(status:500,code:"unexpected_failure",reason:"Database error saving new user").contains("Database error saving new user"))
        XCTAssertTrue(ReferenceService.errorMessage(status:400,code:"email_not_confirmed",reason:"").contains("أكّد"))
    }
    @MainActor func testOriginalPublicAPIFromNativeClient() async throws {
        XCTAssertTrue(NetworkPolicy.enabled)
        let client=ReferenceService();XCTAssertNotNil(client.config)
        let settings=try await client.request("/auth/v1/settings")
        let object=try XCTUnwrap(try JSONSerialization.jsonObject(with:settings) as? [String:Any])
        XCTAssertEqual(object["disable_signup"] as? Bool,false)
        let posts=try await client.request("/rest/v1/community_posts?select=id&status=eq.APPROVED&limit=1")
        XCTAssertNotNil(try JSONSerialization.jsonObject(with:posts) as? [[String:Any]])
        let evidence=XCTAttachment(string:"Native URLSession client: original auth settings and approved community read succeeded. No account created; no password or session logged.")
        evidence.name="original-service-client";evidence.lifetime = .keepAlways;add(evidence)
    }
}
