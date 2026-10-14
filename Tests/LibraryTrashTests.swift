import XCTest
@testable import CookiesEditor

final class LibraryTrashTests:XCTestCase {
    @MainActor private func setup()throws->(URL,LibraryStore,EditorPage){let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);let library=LibraryStore(root:root),page=try PageOperationsBlank(root:root);return (root,library,page)}
    @MainActor private func PageOperationsBlank(root:URL)throws->EditorPage{try PageOperations.blank(title:"صفحة محفوظة",width:80,height:150,color:"FFFFFF",transparent:false,root:root)}
    @MainActor func testSoftDeleteReopenRestoreKeepsSourceAndLayers()throws {
        let (root,library,original)=try setup();defer{try? FileManager.default.removeItem(at:root)};var page=original;page.layers=[EditorLayer(kind:.text,name:"حوار")];page.layers[0].textContent="نص عربي";try library.persist(page);XCTAssertTrue(library.add(page,parent:nil))
        let item=try XCTUnwrap(library.items.first),file=library.directory(page.id).appendingPathComponent(page.source),before=try Data(contentsOf:file);library.remove(item);XCTAssertTrue(library.items.isEmpty);XCTAssertEqual(library.trashRoots.count,1);XCTAssertEqual(try Data(contentsOf:file),before)
        let reopened=LibraryStore(root:root);XCTAssertTrue(reopened.items.isEmpty);try reopened.restoreTrash([item.id]);XCTAssertTrue(reopened.trashedItems.isEmpty);XCTAssertEqual(reopened.items.first?.id,item.id);XCTAssertEqual(try reopened.load(page.id),page);XCTAssertEqual(try Data(contentsOf:file),before)
    }
    @MainActor func testFolderChapterAndNestedFolderReturnWithTheirRelationships()throws {
        let (root,library,page)=try setup();defer{try? FileManager.default.removeItem(at:root)};library.createFolder("عمل",parent:nil);let parent=try XCTUnwrap(library.items.first);library.createFolder("مجلد داخلي",parent:parent.id);let nested=try XCTUnwrap(library.items.last);let chapter=try library.createChapter("فصل",parent:nested.id);XCTAssertTrue(library.add(page,parent:chapter));let before=library.items
        library.remove(parent);XCTAssertTrue(library.items.isEmpty);XCTAssertEqual(library.trashRoots.count,1);XCTAssertEqual(library.trashMembers(parent.id).count,3);try library.restoreTrash([parent.id]);XCTAssertEqual(library.items,before)
    }
    @MainActor func testRestorationFallsBackToGalleryWhenOriginalParentWasDeletedLater()throws {
        let (root,library,page)=try setup();defer{try? FileManager.default.removeItem(at:root)};library.createFolder("مجلد",parent:nil);let folder=try XCTUnwrap(library.items.first);XCTAssertTrue(library.add(page,parent:folder.id));let project=try XCTUnwrap(library.items.last);library.remove(project);library.remove(folder);try library.restoreTrash([project.id]);XCTAssertNil(library.items.first?.parent);XCTAssertEqual(library.trashRoots.map(\.id),[folder.id])
    }
    @MainActor func testPermanentDeletionRetainsPagesSharedByActiveChapter()async throws {
        let (root,library,page)=try setup();defer{try? FileManager.default.removeItem(at:root)};XCTAssertTrue(library.add(page,parent:nil));let project=try XCTUnwrap(library.items.first);let chapter=try library.createChapter("فصل آخر",parent:nil);try library.setPages([page.id],chapter:chapter);library.remove(project);try await library.purgeTrash([project.id]);XCTAssertTrue(library.trashedItems.isEmpty);XCTAssertEqual(try library.load(page.id),page);XCTAssertEqual(library.chapter(chapter)?.pages,[page.id])
    }
    @MainActor func testPermanentDeletionAndPendingCrashIntentFinishWithoutResurrection()async throws {
        let (root,library,page)=try setup();defer{try? FileManager.default.removeItem(at:root)};XCTAssertTrue(library.add(page,parent:nil));let project=try XCTUnwrap(library.items.first);library.remove(project);var trash=library.trashedItems;trash[0].purgePending=true;try library.writeLibrary(active:[],trash:trash)
        let reopened=LibraryStore(root:root);XCTAssertThrowsError(try reopened.restoreTrash([project.id]));await reopened.resumeTrashPurge();XCTAssertTrue(reopened.trashedItems.isEmpty);XCTAssertFalse(FileManager.default.fileExists(atPath:reopened.directory(page.id).path));let again=LibraryStore(root:root);XCTAssertTrue(again.items.isEmpty);XCTAssertTrue(again.trashedItems.isEmpty)
    }
    @MainActor func testIndexFailurePreventsIrreversibleFileDeletion()async throws {
        let (root,library,page)=try setup();defer{try? FileManager.default.removeItem(at:root)};XCTAssertTrue(library.add(page,parent:nil));let item=try XCTUnwrap(library.items.first);library.remove(item);let before=library.trashedItems,index=root.appendingPathComponent("library.json");try FileManager.default.removeItem(at:index);try FileManager.default.createDirectory(at:index,withIntermediateDirectories:true)
        do{try await library.purgeTrash([item.id]);XCTFail("Must fail before unlinking any source")}catch{};XCTAssertEqual(library.trashedItems,before);XCTAssertFalse(library.purgingTrash);XCTAssertTrue(FileManager.default.fileExists(atPath:library.directory(page.id).appendingPathComponent(page.source).path))
    }
    @MainActor func testSelectedTrashBackupRestoresDeletedStateAndSource()throws {
        let (root,library,page)=try setup();let destination=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root);try? FileManager.default.removeItem(at:destination)};XCTAssertTrue(library.add(page,parent:nil));let item=try XCTUnwrap(library.items.first);library.remove(item);let choices=try AppStorageManager.units(at:root);XCTAssertEqual(choices.first{$0.id==page.id.uuidString}?.group,"سلة المحذوفات");let selected:Set<String>=[page.id.uuidString,"gallery"],archive=try AppStorageManager.createBackup(selected:selected,at:root);defer{try? FileManager.default.removeItem(at:archive)}
        _ = try AppStorageManager.restore(archive,selected:selected,at:destination);let restored=LibraryStore(root:destination);XCTAssertTrue(restored.items.isEmpty);XCTAssertEqual(restored.trashRoots.map(\.id),[item.id]);try restored.restoreTrash([item.id]);XCTAssertEqual(try restored.load(page.id),page);XCTAssertEqual(try Data(contentsOf:restored.directory(page.id).appendingPathComponent(page.source)),try Data(contentsOf:library.directory(page.id).appendingPathComponent(page.source)))
    }
    @MainActor func testMissingPageCannotBeReportedAsRestoredAndPendingPurgeNotBackedUp()throws {
        let (root,library,page)=try setup();defer{try? FileManager.default.removeItem(at:root)};XCTAssertTrue(library.add(page,parent:nil));let item=try XCTUnwrap(library.items.first);library.remove(item);try FileManager.default.removeItem(at:library.directory(page.id).appendingPathComponent("page.json"));XCTAssertThrowsError(try library.restoreTrash([item.id]));XCTAssertTrue(library.items.isEmpty)
        try library.persist(page);var pending=library.trashedItems;pending[0].purgePending=true;try library.writeLibrary(active:[],trash:pending);XCTAssertFalse(try AppStorageManager.units(at:root).contains{$0.id==page.id.uuidString})
    }
}
