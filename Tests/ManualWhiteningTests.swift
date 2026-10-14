import XCTest
import UIKit
@testable import CookiesEditor

final class ManualWhiteningTests:XCTestCase {
    @MainActor private func setup()throws->(URL,EditorModel){let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),library=LibraryStore(root:root),page=try PageOperations.blank(title:"فقاعات",width:400,height:600,color:"FFFFFF",transparent:false,root:root);XCTAssertTrue(library.add(page,parent:nil));return(root,EditorModel(page:page,library:library))}
    private let rectangle=[CGPoint(x:30,y:40),CGPoint(x:250,y:40),CGPoint(x:250,y:260),CGPoint(x:30,y:260)]
    @MainActor func testManualContourIsRealTargetAndDoesNotEditImage()throws{
        let (root,model)=try setup();defer{try? FileManager.default.removeItem(at:root)};let before=model.page
        model.beginManualSniper(.rectangle);model.finishManualSniper(rectangle)
        let target=try XCTUnwrap(model.sniperTargets.first);XCTAssertTrue(target.manuallySelected);XCTAssertFalse(target.pin);XCTAssertEqual(target.outline.count,4);XCTAssertEqual(target.whiteningMethod,.classic);XCTAssertEqual(model.page,before);XCTAssertNil(model.manualSniperTool)
    }
    @MainActor func testReplacingContourKeepsPerBubbleMethodIdentityAndReturnsToInspector()throws{
        let (root,model)=try setup();defer{try? FileManager.default.removeItem(at:root)};model.beginManualSniper(.rectangle);model.finishManualSniper(rectangle);let id=try XCTUnwrap(model.sniperTargets.first?.id);model.sniperTargets[0].whiteningMethod = .bigLaMa;model.sniperTargets[0].restorationExecution = .cloud
        model.beginManualSniper(.rectangle);model.finishManualSniper(rectangle.map{CGPoint(x:$0.x+10,y:$0.y+280)})
        model.beginManualSniper(.freehand,replacing:id,returnToWhitening:true);model.finishManualSniper([CGPoint(x:50,y:50),CGPoint(x:180,y:65),CGPoint(x:210,y:180),CGPoint(x:45,y:220)])
        XCTAssertEqual(model.sniperTargets.count,2);XCTAssertEqual(model.sniperTargets[0].id,id);XCTAssertEqual(model.sniperTargets[0].whiteningMethod,.bigLaMa);XCTAssertEqual(model.sniperTargets[1].whiteningMethod,.classic);XCTAssertEqual(model.sniperTargets[0].restorationExecution,.cloud);XCTAssertEqual(model.sniperTargets[1].restorationExecution,.device);XCTAssertTrue(model.sniperWhiteningOpen);XCTAssertEqual(model.focusedSniperTarget,id)
    }
    @MainActor func testManualTextRegionsAreClippedAndOutsideOrTinyContoursAreRejected()throws{
        let (root,model)=try setup();defer{try? FileManager.default.removeItem(at:root)};model.beginManualSniper(.rectangle);model.finishManualSniper(rectangle);let id=try XCTUnwrap(model.sniperTargets.first?.id)
        model.beginManualSniper(.textRectangle,replacing:id,returnToWhitening:true);model.finishManualSniper([CGPoint(x:0,y:0),CGPoint(x:100,y:0),CGPoint(x:100,y:100),CGPoint(x:0,y:100)])
        XCTAssertEqual(model.sniperTargets[0].manualTextRegions,[Box(x:30,y:40,width:70,height:60)])
        model.beginManualSniper(.textRectangle,replacing:id);model.finishManualSniper([CGPoint(x:300,y:400),CGPoint(x:350,y:400),CGPoint(x:350,y:450),CGPoint(x:300,y:450)]);XCTAssertEqual(model.sniperTargets[0].manualTextRegions.count,1);XCTAssertNotNil(model.error)
        model.beginManualSniper(.rectangle);model.finishManualSniper([.zero,CGPoint(x:4,y:0),CGPoint(x:4,y:4),CGPoint(x:0,y:4)]);XCTAssertEqual(model.sniperTargets.count,1)
    }
    func testNeuralTextMaskProtectsBubbleBorderAndOutsideEvenForOversizedTextRect()throws{
        let outline=[CGPoint(x:20,y:20),CGPoint(x:180,y:20),CGPoint(x:180,y:180),CGPoint(x:20,y:180)].map{NSValue(cgPoint:$0)}
        let result=try XCTUnwrap(CookiesCreateBubbleTextMask(CGSize(width:200,height:200),outline,[NSValue(cgRect:CGRect(x:0,y:0,width:100,height:100))],3) as? [String:Any]),image=try XCTUnwrap((result["mask"] as? UIImage)?.cgImage),bytes=try BigLaMaSession.rgba(image)
        XCTAssertEqual(bytes[(50*200+50)*4],255)
        for y in 0..<200{for x in 0..<200 where x<=21 || y<=21 || x>=179 || y>=179{XCTAssertEqual(bytes[(y*200+x)*4],0)}}
        XCTAssertNil(CookiesCreateBubbleTextMask(CGSize(width:200,height:200),outline,[NSValue(cgRect:CGRect(x:1000,y:1000,width:10,height:10))],3))
    }
    @MainActor func testFailedTextLocalizationDoesNotLoadNeuralModelOrWritePatch()throws{
        let (root,model)=try setup();defer{try? FileManager.default.removeItem(at:root)};model.beginManualSniper(.rectangle);model.finishManualSniper(rectangle);var target=try XCTUnwrap(model.sniperTargets.first);target.manualTextRegions=[Box(x:350,y:500,width:20,height:20)]
        XCTAssertThrowsError(try BubbleWhitening.prepareBigLaMa(page:model.page,directory:model.directory,target:target,session:{XCTFail("A rejected mask must not load the large model");throw LaMaFailure.message("Unexpected") }))
        let files=try FileManager.default.contentsOfDirectory(atPath:model.directory.path);XCTAssertFalse(files.contains{$0.hasPrefix("bubble-lama-")})
    }
    @MainActor func testOptionalModelSpecificationIsPinnedAndAbsentCacheDoesNotDownload()throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)};let assets=BigLaMaAssets(root:root),spec=try BigLaMaSpecification.bundled()
        XCTAssertEqual(spec.revision,"c3c0c9e468934d62e79c329e35d82dd09ff8c444");XCTAssertEqual(spec.downloadSize,208044816);XCTAssertEqual(spec.files.count,1);XCTAssertFalse(assets.ready);XCTAssertFalse(assets.installing);XCTAssertThrowsError(try assets.acquire());XCTAssertEqual(assets.activeUses,0)
    }
    @MainActor func testModelRemovalLocksAcquisitionAndCacheCleanupWithoutDownloading()async throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let assets=BigLaMaAssets(root:root)
        try await assets.beginCacheCleanup();XCTAssertTrue(assets.removing);XCTAssertThrowsError(try assets.acquire())
        assets.startInstallation();XCTAssertFalse(assets.installing)
        do{try await assets.remove();XCTFail("Concurrent removal must be rejected")}catch{}
        assets.endCacheCleanup();XCTAssertFalse(assets.removing);XCTAssertFalse(assets.ready)
    }

}
