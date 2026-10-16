import XCTest
import UIKit
@testable import CookiesEditor

final class DriveChapterTests:XCTestCase {
    func testOnlyRealDriveURLsAreAccepted()throws{
        XCTAssertEqual(try DriveChapterImport.link("https://drive.google.com/drive/folders/1234567890_abc?usp=sharing"),.folder("1234567890_abc",nil))
        XCTAssertEqual(try DriveChapterImport.link("https://drive.google.com/file/d/1234567890/view?resourcekey=key"),.file("1234567890","key"))
        for url in ["https://drive.google.com.attacker.test/drive/folders/1234567890","http://drive.google.com/file/d/1234567890/view","file:///tmp/private"]{XCTAssertThrowsError(try DriveChapterImport.link(url))}
    }
    func testPublicFolderParsesNamesAndSortsPagesWithoutDownloadingThumbnails()throws{
        let rows:[[Any]]=[["1234567890_2",[],"10.jpg","image/jpeg"],["1234567890_1",[],"2.jpg","image/jpeg"],["1234567890_dir",[],"folder","application/vnd.google-apps.folder"]]
        let encoded=try JSONSerialization.data(withJSONObject:[rows,NSNull()]),json=String(decoding:encoded,as:UTF8.self)
        let quoted=try JSONSerialization.data(withJSONObject:json,options:.fragmentsAllowed),literal=String(decoding:quoted.dropFirst().dropLast(),as:UTF8.self).replacingOccurrences(of:"[",with:"\\x5b")
        let images=try DriveChapterImport.images(in:"<script>window['_DRIVE_ivd'] = '"+literal+"';</script>")
        XCTAssertEqual(images.map(\.name),["2.jpg","10.jpg"])
        XCTAssertThrowsError(try DriveChapterImport.images(in:"<html>Sign in</html>"))
    }
    @MainActor func testFilesAndPhotosShareChapterImportAndProjectsCanJoinChapter()async throws{
        let fm=FileManager.default,root=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? fm.removeItem(at:root)};try fm.createDirectory(at:root,withIntermediateDirectories:true)
        let renderer=UIGraphicsImageRenderer(size:CGSize(width:32,height:64));let image=renderer.image{UIColor.white.setFill();$0.fill(CGRect(x:0,y:0,width:32,height:64))}
        let urls=try ["01","02"].map{name->URL in let url=root.appendingPathComponent(name+".png");try XCTUnwrap(image.pngData()).write(to:url);return url}
        let library=LibraryStore(root:root);try await library.importSelection(urls,parent:nil)
        let chapter=try XCTUnwrap(library.items.first{$0.isChapter==true});XCTAssertEqual(chapter.pages.count,2);XCTAssertEqual(try chapter.pages.map{try library.load($0).title},["01","02"])
        await library.importImage(urls[0],parent:nil);let project=try XCTUnwrap(library.items.first{$0.isChapter != true});let id=project.pages[0]
        try library.collectProjects([project.id],in:chapter.id);XCTAssertEqual(library.chapter(chapter.id)?.pages.count,3);XCTAssertTrue(library.chapter(chapter.id)?.pages.contains(id)==true);XCTAssertFalse(library.items.contains{$0.id==project.id})
    }
    func testPhotoProviderSuggestedFilenameSurvivesTemporaryProviderURL()throws{
        let file=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".jpg");try Data([1,2,3]).write(to:file);defer{try? FileManager.default.removeItem(at:file)}
        let owned=try PhotoImport.ownFile(file,suggestedName:"Chapter 12 - 003.jpg");defer{try? FileManager.default.removeItem(at:owned.deletingLastPathComponent())};XCTAssertEqual(owned.lastPathComponent,"Chapter 12 - 003.jpg")
    }
}
