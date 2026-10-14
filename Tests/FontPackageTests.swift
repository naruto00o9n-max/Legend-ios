import XCTest
import CoreText
@testable import CookiesEditor

final class FontPackageTests:XCTestCase {
    func testReimportingBundledFontIsIdempotentAndInvalidPackageCopiesNothing()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let font=try XCTUnwrap(Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts")?.first),target=root.appendingPathComponent("fonts")
        try FontPackage.importFiles([font],directory:target);try FontPackage.importFiles([font],directory:target)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at:target,includingPropertiesForKeys:nil).map(\.lastPathComponent),[font.lastPathComponent],"An explicitly imported bundled font must have a durable imported copy")
        let bad=root.appendingPathComponent("invalid.ttf");try Data("invalid".utf8).write(to:bad)
        let fresh=root.appendingPathComponent("fresh")
        XCTAssertThrowsError(try FontPackage.importFiles([font,bad],directory:fresh));XCTAssertFalse(FileManager.default.fileExists(atPath:fresh.path))
    }
    func testMultipleOriginalNamesAreImportedTogetherAndInvalidBatchIsAtomic()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let fonts=Array((Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts") ?? []).prefix(2));XCTAssertEqual(fonts.count,2)
        let target=root.appendingPathComponent("imported")
        _ = try FontPackage.importArchives(fonts,directory:target)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(at:target,includingPropertiesForKeys:nil).map(\.lastPathComponent)),Set(fonts.map(\.lastPathComponent)))
        for font in fonts{XCTAssertEqual(try Data(contentsOf:font),try Data(contentsOf:target.appendingPathComponent(font.lastPathComponent)))}
        let bad=root.appendingPathComponent("invalid.ttf");try Data("not a font".utf8).write(to:bad)
        let fresh=root.appendingPathComponent("must-not-exist")
        XCTAssertThrowsError(try FontPackage.importArchives([fonts[0],bad],directory:fresh));XCTAssertFalse(FileManager.default.fileExists(atPath:fresh.path))
    }
}
