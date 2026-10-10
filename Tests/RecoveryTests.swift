import XCTest
@testable import CookiesEditor

final class RecoveryTests:XCTestCase {
    func testBrokenCurrentDocumentRecoversValidatedPreviousAndPreservesDamagedBytes()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("library.json")
        try RecoveryFile.write(["chapter-one"],at:file);try RecoveryFile.write(["chapter-one","chapter-two"],at:file)
        try Data("broken".utf8).write(to:file)
        let restored=try XCTUnwrap(RecoveryFile.read([String].self,at:file));XCTAssertTrue(restored.recovered);XCTAssertEqual(restored.value,["chapter-one"])
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
        let damaged=try XCTUnwrap(files.first{$0.lastPathComponent.contains("damaged-")});XCTAssertEqual(try Data(contentsOf:damaged),Data("broken".utf8))
        XCTAssertFalse(try XCTUnwrap(RecoveryFile.read([String].self,at:file)).recovered)
    }
    func testInvalidCurrentDoesNotOverwriteLastGoodBackup()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("page.json");try RecoveryFile.write([1],at:file);try RecoveryFile.write([2],at:file);try Data("broken".utf8).write(to:file);try RecoveryFile.write([3],at:file)
        XCTAssertEqual(try JSONDecoder().decode([Int].self,from:Data(contentsOf:RecoveryFile.backup(file))),[1])
    }
    @MainActor func testCorruptTyperWithoutBackupCannotOverwriteUserData()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("chapters.json"),broken=Data("broken-user-data".utf8);try broken.write(to:file)
        let store=TyperStore(directory:folder);XCTAssertNotNil(store.error)
        XCTAssertThrowsError(try store.saveChapter(title:"جديد",source:"حوار",separation:.lines))
        XCTAssertEqual(try Data(contentsOf:file),broken)
    }
    @MainActor func testTyperRestoresPreviousDraftAfterCorruption()throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:folder)}
        let store=TyperStore(directory:folder);let id=try store.saveChapter(title:"فصل",source:"حوار",separation:.lines);try store.setLinkPrefix("@@")
        try Data("broken".utf8).write(to:folder.appendingPathComponent("chapters.json"))
        let restored=TyperStore(directory:folder);XCTAssertNotNil(restored.error);XCTAssertEqual(restored.chapter(id)?.bubbles.first?.text,"حوار")
    }

    @MainActor func testFailedLibraryIndexWriteNeverDeletesProjectOrChangesVisibleFolders()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),page=try PageOperations.blank(title:"محفوظ",width:24,height:40,color:"FFFFFF",transparent:false,root:root);XCTAssertTrue(library.add(page,parent:nil));let item=try XCTUnwrap(library.items.first)
        let index=root.appendingPathComponent("library.json");try FileManager.default.removeItem(at:index);try FileManager.default.createDirectory(at:index,withIntermediateDirectories:true)
        library.remove(item);XCTAssertNotNil(library.error);XCTAssertEqual(library.items,[item]);XCTAssertTrue(FileManager.default.fileExists(atPath:library.directory(page.id).appendingPathComponent(page.source).path))
        library.createFolder("جديد",parent:nil);XCTAssertEqual(library.items,[item])
        library.rename(item,to:"اسم لم يُحفظ");XCTAssertEqual(library.items,[item]);XCTAssertEqual(try library.load(page.id).title,"محفوظ")
    }

}
