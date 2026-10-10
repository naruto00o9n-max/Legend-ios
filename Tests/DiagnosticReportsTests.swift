import XCTest
@testable import CookiesEditor

final class DiagnosticReportsTests:XCTestCase {
    func testReportsStayLocalBoundedAndCanBeRemoved()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let store=DiagnosticReports(directory:root)
        XCTAssertTrue(try store.reports().isEmpty)
        XCTAssertThrowsError(try store.record(Data("broken".utf8)))
        XCTAssertFalse(FileManager.default.fileExists(atPath:root.path))
        for index in 0..<20{try store.record(JSONSerialization.data(withJSONObject:["crashDiagnostics":[["diagnosticMetaData":["testSequence":index]]]]))}
        let reports=try store.reports();XCTAssertEqual(reports.count,15);XCTAssertTrue(reports.allSatisfy{$0.crashes==1})
        let saved=try XCTUnwrap(reports.first);try store.remove(saved);XCTAssertFalse(FileManager.default.fileExists(atPath:saved.url.path));XCTAssertEqual(try store.reports().count,14)
        let outside=root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString);try Data("keep".utf8).write(to:outside);defer{try? FileManager.default.removeItem(at:outside)}
        XCTAssertThrowsError(try store.remove(DiagnosticReport(url:outside,date:Date(),crashes:0)));XCTAssertEqual(try Data(contentsOf:outside),Data("keep".utf8))
    }
}
