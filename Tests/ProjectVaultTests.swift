import XCTest
import UIKit
import ZIPFoundation
@testable import CookiesEditor

private final class VaultMockProtocol:URLProtocol {
    static var respond:((URLRequest)throws->(Int,Data))?
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){do{let(status,data)=try Self.respond!(request);client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}}
    override func stopLoading(){}
}
final class ProjectVaultTests:XCTestCase {
    private func fixture()throws->(EditorPage,URL,URL) {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:80,height:100),format:format).image{context in UIColor.cyan.setFill();context.fill(CGRect(x:0,y:0,width:80,height:100))}
        let input=root.appendingPathComponent("input.png");try XCTUnwrap(image.pngData()).write(to:input)
        var page=try ImagePipeline.importImage(input,root:root)
        var text=EditorLayer(kind:.text,name:"نص قابل للتحرير");text.textContent="الصورة الأصلية";text.style=TextStyle.plainText();text.erasures=[Stroke(points:[Point(x:10,y:10)],width:5,color:"FFFFFF",erase:true)]
        page.layers=[text]
        let directory=root.appendingPathComponent(page.id.uuidString);try JSONEncoder().encode(page).write(to:directory.appendingPathComponent("page.json"))
        return(page,root,directory)
    }
    private func remote(_ id:UUID,_ head:VaultHead)->VaultProject{VaultProject(owner_id:UUID().uuidString.lowercased(),project_id:id,revision_id:UUID(),generation:1,head:head)}
    func testProjectArchiveStreamsOnlyDurableReferencedAssetsAndRoundTripsEditableText()throws {
        let (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        try Data(repeating:127,count:500000).write(to:directory.appendingPathComponent("discarded-preview.png"))
        let (file,head)=try VaultArchive.create(page,directory:directory);defer{try? FileManager.default.removeItem(at:file)}
        let archive=try Archive(url:file,accessMode:.read)
        XCTAssertNil(archive[page.raw]);XCTAssertNil(archive["discarded-preview.png"]);XCTAssertNotNil(archive[page.source]);XCTAssertNotNil(archive["page.json"])
        let staging=root.appendingPathComponent(".vault-stage-test")
        let restored=try VaultArchive.unpack(file,head:head,id:page.id,staging:staging)
        XCTAssertEqual(restored,page);XCTAssertEqual(try Data(contentsOf:staging.appendingPathComponent(page.source)),try Data(contentsOf:directory.appendingPathComponent(page.source)))
        XCTAssertFalse(FileManager.default.fileExists(atPath:staging.appendingPathComponent(page.raw).path))
    }
    func testCorruptArchiveAndDifferentPageIDCannotBeRestored()throws {
        let (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let (file,head)=try VaultArchive.create(page,directory:directory);defer{try? FileManager.default.removeItem(at:file)}
        let staging=root.appendingPathComponent(".vault-stage-test")
        XCTAssertThrowsError(try VaultArchive.unpack(file,head:head,id:UUID(),staging:staging))
        XCTAssertFalse(FileManager.default.fileExists(atPath:staging.path))
        var bad=head;bad.sha256=String(repeating:"0",count:64)
        XCTAssertThrowsError(try VaultArchive.unpack(file,head:bad,id:page.id,staging:staging))
        XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path))
    }
    func testArchiveRejectsTraversalEvenWhenArchiveHashIsValid()throws {
        let (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let (file,_)=try VaultArchive.create(page,directory:directory);defer{try? FileManager.default.removeItem(at:file)}
        let archive=try Archive(url:file,accessMode:.update)
        try archive.addEntry(with:"../escape",type:.file,uncompressedSize:Int64(1)){_,_ in Data([1])}
        let head=try VaultArchive.manifest(file,page:page),staging=root.appendingPathComponent(".vault-stage-test")
        XCTAssertThrowsError(try VaultArchive.unpack(file,head:head,id:page.id,staging:staging))
        XCTAssertFalse(FileManager.default.fileExists(atPath:root.appendingPathComponent("escape").path))
    }
    func testEvictionRetainsMetadataAndVerifiedHydrationRebuildsPixelsWithoutChangingSource()throws {
        let (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let original=try Data(contentsOf:directory.appendingPathComponent(page.source))
        let (file,head)=try VaultArchive.create(page,directory:directory);defer{try? FileManager.default.removeItem(at:file)}
        let project=remote(page.id,head)
        try VaultFiles.evict(page,project:project,directory:directory,root:root)
        XCTAssertFalse(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path));XCTAssertFalse(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.raw).path))
        XCTAssertEqual(try VaultFiles.receipt(directory)?.project,project);XCTAssertEqual(try VaultFiles.receipt(directory)?.resident,false)
        let staging=root.appendingPathComponent(".vault-stage-test")
        _ = try VaultArchive.unpack(file,head:head,id:page.id,staging:staging)
        try VaultFiles.write(VaultReceipt(project:project,resident:true),directory:staging);try VaultFiles.replace(staging,id:page.id,root:root)
        try ImagePipeline.ensureDecoded(directory.appendingPathComponent(page.raw),width:page.width,height:page.height)
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),original)
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath:directory.appendingPathComponent(page.raw).path)[.size] as? NSNumber)?.intValue,page.width*page.height*4)
        XCTAssertEqual(try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:directory.appendingPathComponent("page.json"))),page)
    }
    func testInterruptedDirectorySwapRestoresOriginalAtBothFailureBoundaries()throws {
        for targetExists in [false,true] {
            let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
            let old=root.appendingPathComponent(".vault-old-test"),staged=root.appendingPathComponent(".vault-stage-test"),journal=root.appendingPathComponent(".vault-swap-test.json")
            try FileManager.default.moveItem(at:directory,to:old)
            try FileManager.default.createDirectory(at:staged,withIntermediateDirectories:true)
            if targetExists{try FileManager.default.moveItem(at:staged,to:directory);try Data([0]).write(to:directory.appendingPathComponent("incomplete"))}
            try JSONEncoder().encode(VaultFiles.Swap(id:page.id,old:old.lastPathComponent,staged:staged.lastPathComponent)).write(to:journal)
            try VaultFiles.recover(root:root)
            XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path));XCTAssertFalse(FileManager.default.fileExists(atPath:directory.appendingPathComponent("incomplete").path));XCTAssertFalse(FileManager.default.fileExists(atPath:journal.path))
        }
    }
    @MainActor func testActiveCanvasCannotBeEvictedAndLocalModeNeedsNoAccount()async throws {
        let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);try await library.vault.open(page.id)
        await library.vault.store(page.id,evict:true)
        XCTAssertNil(library.vault.error);XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path));XCTAssertNil(try VaultFiles.receipt(directory))
    }
    @MainActor func testRemoteDeleteOfOpenProjectReportsReasonAndPreservesSource()async throws {
        let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let original=try Data(contentsOf:directory.appendingPathComponent(page.source))
        let library=LibraryStore(root:root);try await library.vault.open(page.id)
        let hash=String(repeating:"a",count:64)
        let project=remote(page.id,VaultHead(title:page.title,bytes:1,sha256:hash,chunks:[VaultChunk(bytes:1,sha256:hash)],width:page.width,height:page.height))
        await library.vault.removeRemote(project)
        XCTAssertTrue(library.vault.error?.contains("أغلق محرر") == true)
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),original)
        XCTAssertNil(try VaultFiles.receipt(directory))
    }
    func testManifestRejectsInconsistentChunkBoundaryAndOversizedProject()throws {
        let hash=String(repeating:"a",count:64)
        var head=VaultHead(title:"فصل",bytes:VaultArchive.chunkSize+1,sha256:hash,chunks:[VaultChunk(bytes:VaultArchive.chunkSize,sha256:hash),VaultChunk(bytes:1,sha256:hash)],width:800,height:15000)
        XCTAssertNoThrow(try head.validate());head.chunks[0].bytes-=1;XCTAssertThrowsError(try head.validate());head.bytes=VaultArchive.limit+1;XCTAssertThrowsError(try head.validate())
    }
    override func tearDown(){VaultMockProtocol.respond=nil;super.tearDown()}
    private func client()->ProjectVaultClient{let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[VaultMockProtocol.self];return ProjectVaultClient(token:"ordinary-user-session",transport:URLSession(configuration:c),endpoint:URL(string:"https://vault.test/")!)}
    func testDownloadChecksEveryChunkAndWholeArchiveBeforeAcceptingBytes()async throws {
        let data=Data("exact original bytes".utf8),hash=ProjectVaultClient.hash(data),head=VaultHead(title:"فصل",bytes:data.count,sha256:hash,chunks:[VaultChunk(bytes:data.count,sha256:hash)],width:800,height:15000),project=remote(UUID(),head),c=client();defer{c.transport.invalidateAndCancel()}
        VaultMockProtocol.respond={r in XCTAssertEqual(r.value(forHTTPHeaderField:"Authorization"),"Bearer ordinary-user-session");return(200,data)}
        try await c.verify(project)
        VaultMockProtocol.respond={_ in (200,Data(repeating:1,count:data.count))}
        do{try await c.verify(project);XCTFail("Corrupted chunk accepted")}catch{XCTAssertTrue(error.localizedDescription.contains("التحقق"))}
        var bad=project;bad.head.sha256=String(repeating:"0",count:64)
        VaultMockProtocol.respond={_ in(200,data)}
        do{try await c.verify(bad);XCTFail("Wrong full archive checksum accepted")}catch{XCTAssertTrue(error.localizedDescription.contains("التحقق"))}
    }
    func testExpiredSessionAndConflictingHeadNeverLookLikeSuccessfulDownload()async throws {
        let hash=String(repeating:"a",count:64),head=VaultHead(title:"فصل",bytes:10,sha256:hash,chunks:[VaultChunk(bytes:10,sha256:hash)],width:800,height:15000),c=client();defer{c.transport.invalidateAndCancel()}
        for status in [401,409,507]{VaultMockProtocol.respond={_ in(status,Data())};do{try await c.verify(remote(UUID(),head));XCTFail("Failed response accepted")}catch{XCTAssertTrue(error.localizedDescription.contains(status==401 ? "جلسة":status==409 ? "تغيّرت":"مساحة"))}}
    }
    func testPromotedOriginalReusesRebuiltProjectPixelsAfterCloudHydration()throws {
        var(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        var layer=EditorLayer(kind:.image);layer.imagePath=page.source;layer.isWorkingImage=true;layer.imagePixelFile=page.raw;layer.imagePixelWidth=page.width;layer.imagePixelHeight=page.height;page.layers.append(layer)
        try JSONEncoder().encode(page).write(to:directory.appendingPathComponent("page.json"));try FileManager.default.removeItem(at:directory.appendingPathComponent(page.raw));ImageAssetPixels.clear()
        let provider=try ImageAssetPixels.provider(layer,directory:directory)
        XCTAssertEqual(provider.url.standardizedFileURL,directory.appendingPathComponent(page.raw).standardizedFileURL)
        XCTAssertEqual(provider.width,page.width);XCTAssertEqual(provider.height,page.height)
    }

    @MainActor func testLivePrivateVaultRoundTripEvictionAndReopen()async throws {
        struct Fixture:Decodable{var configuration:ReferenceConfig;var session:ServiceSession}
        guard let file=Bundle(for:Self.self).url(forResource:"TransientVaultSession",withExtension:"json") else{throw XCTSkip("CI provisioned ordinary vault account required")}
        let identity=try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:file))
        let service=ReferenceService(configuration:identity.configuration,urlSession:.shared,initialSession:identity.session)
        let (page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let original=try Data(contentsOf:directory.appendingPathComponent(page.source)),library=LibraryStore(root:root)
        XCTAssertTrue(library.add(page,parent:nil));library.vault.service=service
        await library.vault.store(page.id,evict:true)
        XCTAssertNil(library.vault.error);XCTAssertEqual(try VaultFiles.receipt(directory)?.resident,false)
        XCTAssertFalse(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path));XCTAssertThrowsError(try library.load(page.id))
        try await library.vault.open(page.id)
        XCTAssertEqual(try library.load(page.id),page);XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),original)
        var edited=try library.load(page.id);edited.layers[0].textContent="تعديل بعد الاستعادة";try library.persist(edited)
        library.vault.close(page.id);await library.vault.waitForPendingTransfer(page.id)
        XCTAssertNil(library.vault.error);XCTAssertEqual(try VaultFiles.receipt(directory)?.project.generation,2);XCTAssertEqual(try VaultFiles.receipt(directory)?.resident,false)
        let project=try XCTUnwrap(VaultFiles.receipt(directory)?.project)
        await library.vault.removeRemote(project)
        XCTAssertNil(library.vault.error);XCTAssertEqual(try library.load(page.id),edited);XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(page.source)),original);XCTAssertEqual(try VaultFiles.receipt(directory)?.managed,false)
    }

    @MainActor func testReaderAndEditorLeasesProtectTheSameProjectIndependently()async throws {
        let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),reader=UUID(),editor=UUID()
        try await library.vault.open(page.id,lease:reader);try await library.vault.open(page.id,lease:editor)
        library.vault.close(page.id,lease:editor)
        await library.vault.store(page.id,evict:true)
        XCTAssertNil(library.vault.error);XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path))
        library.vault.suspended=true;library.vault.close(page.id,lease:reader)
    }
    @MainActor func testClosingDuringGestureFlushesTheActualEditableDocument()throws {
        let(page,root,_)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),model=EditorModel(page:page,library:library)
        model.setContinuousEditing(true);model.page.layers[0].textContent="آخر تعديل في الإيماءة"
        XCTAssertTrue(model.flushForClosing());XCTAssertEqual(try library.load(page.id),model.page)
    }
    @MainActor func testFailedFlushBlocksAutomaticTransferForAllRemainingLeases()async throws {
        let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let defaults=UserDefaults.standard,key="storage-projects-server",old=defaults.object(forKey:key);defaults.set(true,forKey:key);defer{if let old{defaults.set(old,forKey:key)}else{defaults.removeObject(forKey:key)}}
        let library=LibraryStore(root:root),first=UUID(),second=UUID()
        try await library.vault.open(page.id,lease:first);try await library.vault.open(page.id,lease:second)
        library.vault.close(page.id,lease:first,allowTransfer:false);library.vault.close(page.id,lease:second)
        await library.vault.waitForPendingTransfer(page.id)
        XCTAssertNil(library.vault.error,"No upload may start after a failed flush");XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path))
    }
}

extension ProjectVaultTests {
    @MainActor func testOpeningResidentProjectDoesNotWaitForAnotherUploadOrItsOwnQueuedClose()async throws{
        let(page,root,directory)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),lease=UUID()
        let defaults=UserDefaults.standard,key="storage-projects-server",old=defaults.object(forKey:key);defaults.set(true,forKey:key);defer{if let old{defaults.set(old,forKey:key)}else{defaults.removeObject(forKey:key)}}
        library.vault.busy=true
        try await library.vault.open(page.id,lease:lease)
        library.vault.close(page.id,lease:lease)
        let began=Date();try await library.vault.open(page.id,lease:lease)
        XCTAssertLessThan(Date().timeIntervalSince(began),1,"A queued close must not block the resident canvas")
        XCTAssertEqual(try library.load(page.id),page)
        XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent(page.source).path))
        library.vault.suspended=true;library.vault.busy=false;library.vault.close(page.id,lease:lease)
        await library.vault.waitForPendingTransfer(page.id)
    }
}
