import XCTest
import UIKit
import CryptoKit
@testable import CookiesEditor

private final class GenerativeMock:URLProtocol {
    static var respond:((URLRequest)throws->(Int,[String:String],Data))?
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){do{let(s,h,b)=try Self.respond!(request);client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:s,httpVersion:nil,headerFields:h)!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:b);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}}
    override func stopLoading(){}
}
final class GenerativeRestorationTests:XCTestCase {
    private func source()->CGImage{GenerativeRestoration.render(CGSize(width:80,height:100)){context in UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:80,height:100));UIColor.black.setFill();context.fill(CGRect(x:25,y:35,width:30,height:30))}}
    private func mask()->CGImage{GenerativeRestoration.render(CGSize(width:80,height:100)){context in UIColor.black.setFill();context.fill(CGRect(x:0,y:0,width:80,height:100));UIColor.white.setFill();context.fill(CGRect(x:15,y:25,width:50,height:50))}}
    private func generated()->CGImage{GenerativeRestoration.render(CGSize(width:512,height:512)){context in UIColor(white:0.8,alpha:1).setFill();context.fill(CGRect(x:0,y:0,width:512,height:512))}}
    private func session()->URLSession{let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[GenerativeMock.self];return URLSession(configuration:c)}
    override func tearDown(){GenerativeMock.respond=nil;super.tearDown()}
    func testFixedInputLetterboxingPreservesAspectRatioAndMarksOnlyText()throws {
        let input=try GenerativeRestoration.prepare(source:source(),mask:mask())
        XCTAssertEqual(input.content,CGRect(x:48,y:0,width:384,height:480))
        let a=try XCTUnwrap(UIImage(data:input.image)?.cgImage),b=try XCTUnwrap(UIImage(data:input.marked)?.cgImage),original=try BigLaMaSession.rgba(a),marked=try BigLaMaSession.rgba(b)
        XCTAssertEqual(a.width,480);XCTAssertEqual(a.height,480)
        XCTAssertEqual(Array(original[0..<3]),[10,10,10]);XCTAssertEqual(Array(marked[0..<3]),[10,10,10])
        let center=(240*480+240)*4;XCTAssertEqual(Array(marked[center..<center+3]),[255,0,255])
        let outside=(50*480+240)*4;XCTAssertEqual(Array(original[outside..<outside+4]),Array(marked[outside..<outside+4]))
    }
    func testSeamMatchingErasesGlyphAndClipsEveryOutsidePixel()throws {
        let original=source(),selection=mask(),input=try GenerativeRestoration.prepare(source:original,mask:selection)
        let patch=try GenerativeRestoration.finish(generated(),input:input,source:original,mask:selection),bytes=try BigLaMaSession.rgba(patch),maskBytes=try BigLaMaSession.rgba(selection)
        XCTAssertEqual(patch.width,80);XCTAssertEqual(patch.height,100)
        for i in 0..<8000{if maskBytes[i*4]==0{XCTAssertEqual(Array(bytes[i*4..<i*4+4]),[0,0,0,0])}else{XCTAssertEqual(bytes[i*4+3],255)}}
        XCTAssertGreaterThan(bytes[(50*80+40)*4],230,"Former black text must not survive color matching")
        XCTAssertThrowsError(try GenerativeRestoration.finish(source(),input:input,source:original,mask:selection))
    }
    func testHostedRequestUsesNormalizedDigestWithoutAccountCredentials()async throws {
        let original=source(),selection=mask(),input=try GenerativeRestoration.prepare(source:original,mask:selection),digest=SHA256.hash(data:input.image).map{String(format:"%02x",$0)}.joined(),png=try XCTUnwrap(UIImage(cgImage:generated()).pngData()),client=session();defer{client.invalidateAndCancel()}
        GenerativeMock.respond={request in XCTAssertEqual(request.url?.absoluteString,"https://restoration.test/v1/reconstruct");XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"));XCTAssertEqual(request.value(forHTTPHeaderField:"Cache-Control"),"no-store");return(200,["X-Cookies-Source-SHA256":digest],png)}
        let patch=try await GenerativeRestoration.repair(source:original,mask:selection,endpoint:URL(string:"https://restoration.test"),session:client)
        XCTAssertEqual(patch.width,80);XCTAssertEqual(patch.height,100)
        GenerativeMock.respond={_ in(200,["X-Cookies-Source-SHA256":String(repeating:"0",count:64)],png)}
        do{_ = try await GenerativeRestoration.repair(source:original,mask:selection,endpoint:URL(string:"https://restoration.test"),session:client);XCTFail("Mismatched input accepted")}catch{XCTAssertTrue(error.localizedDescription.contains("لم تتطابق"))}
    }
    func testCapacityAndCancellationNeverBecomeSuccessfulPatches()async throws {
        let client=session();defer{client.invalidateAndCancel()}
        GenerativeMock.respond={_ in(429,[:],Data("{\"error\":\"daily_capacity_reached\"}".utf8))}
        do{_ = try await GenerativeRestoration.repair(source:source(),mask:mask(),endpoint:URL(string:"https://restoration.test"),session:client);XCTFail("Capacity accepted")}catch{XCTAssertTrue(error.localizedDescription.contains("سعتها المشتركة"))}
        let task=Task{try Task.checkCancellation();return try await GenerativeRestoration.repair(source:source(),mask:mask(),endpoint:URL(string:"https://restoration.test"),session:client)};task.cancel()
        do{_ = try await task.value;XCTFail("Cancelled work accepted")}catch{XCTAssertTrue(error is CancellationError)}
    }
    func testProviderPreferenceDoesNotChangeExistingTargetsOrDeviceAvailability()throws {
        let name=UUID().uuidString,d=try XCTUnwrap(UserDefaults(suiteName:name));defer{d.removePersistentDomain(forName:name)}
        var first=SniperTarget(bounds:Box(x:0,y:0,width:100,height:100),point:Point(x:50,y:50))
        WhiteningPreferences.remember(RestorationProvider.generative,defaults:d);WhiteningPreferences.apply(to:&first,available:false,defaults:d)
        XCTAssertEqual(first.restorationProvider,.generative);XCTAssertEqual(first.restorationExecution,.cloud)
        WhiteningPreferences.remember(RestorationProvider.balanced,defaults:d);XCTAssertEqual(first.restorationProvider,.generative)
        XCTAssertEqual(WhiteningPreferences.provider(defaults:d),.balanced)
    }
}

extension GenerativeRestorationTests {
    func testFreeHostedAlternativeUsesMaskAndNoPersonalQuotaOrCredentials()async throws{
        let client=session();defer{client.invalidateAndCancel()}
        let png=try XCTUnwrap(UIImage(cgImage:generated()).pngData());var calls=0
        GenerativeMock.respond={request in
            calls+=1;XCTAssertEqual(request.url?.path,"/api/v1/inpaint");XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
            // URLProtocol can deliver request bytes through either body API.
            if let data=request.httpBody{let body=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:String]);XCTAssertNotNil(body["image"]);XCTAssertNotNil(body["mask"]);XCTAssertEqual(body["hd_strategy"],"Original")}
            return(200,[:],png)
        }
        for _ in 0..<2{
            let original=source(),selection=mask(),patch=try await HostedTextureRestoration.repair(source:original,mask:selection,endpoint:URL(string:"https://free.test/api/v1/inpaint"),session:client)
            XCTAssertEqual(patch.width,80);XCTAssertEqual(patch.height,100)
            let bytes=try BigLaMaSession.rgba(patch),ink=try BigLaMaSession.rgba(selection)
            for p in stride(from:0,to:bytes.count,by:4){if ink[p]==0{XCTAssertEqual(bytes[p+3],0)}else{XCTAssertEqual(bytes[p+3],255)}}
        }
        XCTAssertEqual(calls,2)
        GenerativeMock.respond={_ in calls+=1;return(429,[:],Data())}
        do{_ = try await HostedTextureRestoration.repair(source:source(),mask:mask(),endpoint:URL(string:"https://free.test/api/v1/inpaint"),session:client);XCTFail("Busy service accepted")}
        catch{XCTAssertTrue(error.localizedDescription.contains("سعتها المشتركة"))}
        XCTAssertEqual(calls,3,"Never retry or rotate hosts to bypass service capacity")
        GenerativeMock.respond={_ in(200,[:],Data("not an image".utf8))}
        do{_ = try await HostedTextureRestoration.repair(source:source(),mask:mask(),endpoint:URL(string:"https://free.test/api/v1/inpaint"),session:client);XCTFail("Invalid response accepted")}catch{}
    }
}
