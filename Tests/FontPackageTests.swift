import XCTest
import CoreText
@testable import CookiesEditor

final class FontPackageTests:XCTestCase {
    func testReimportingBundledFontIsIdempotentAndInvalidPackageCopiesNothing()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let font=try XCTUnwrap(Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts")?.first),target=root.appendingPathComponent("fonts")
        try FontPackage.importFiles([font],directory:target);try FontPackage.importFiles([font],directory:target)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(at:target,includingPropertiesForKeys:nil).isEmpty,"Existing bundled font is reused rather than failing duplicate registration")
        let bad=root.appendingPathComponent("invalid.ttf");try Data("invalid".utf8).write(to:bad)
        let fresh=root.appendingPathComponent("fresh")
        XCTAssertThrowsError(try FontPackage.importFiles([font,bad],directory:fresh));XCTAssertFalse(FileManager.default.fileExists(atPath:fresh.path))
    }
}
