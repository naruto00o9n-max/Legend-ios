import XCTest
import UIKit
import CryptoKit
@testable import CookiesEditor

private final class RestorationMockProtocol:URLProtocol {
    static var respond:((URLRequest)throws->(Int,[String:String],Data))?
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){do{let (status,headers,data)=try Self.respond!(request);client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:headers)!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}}
    override func stopLoading(){}
}
final class CloudRestorationTests:XCTestCase {
    private func image(width:Int=32,height:Int=32,mask:Bool=false)->CGImage{let renderer=UIGraphicsImageRenderer(size:CGSize(width:width,height:height),format:{let value=UIGraphicsImageRendererFormat();value.scale=1;return value}());return renderer.image{_ in UIColor.black.setFill();UIRectFill(CGRect(x:0,y:0,width:width,height:height));(mask ? UIColor.white:UIColor.red).setFill();UIRectFill(CGRect(x:0,y:0,width:mask ? width/2:width,height:height))}.cgImage!}
    private func session()->URLSession{let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[RestorationMockProtocol.self];return URLSession(configuration:config)}
    private func digest(_ source:CGImage)->String{SHA256.hash(data:UIImage(cgImage:source).pngData()!).map{String(format:"%02x",$0)}.joined()}
    override func tearDown(){RestorationMockProtocol.respond=nil;super.tearDown()}
    func testExplicitCloudRequestContainsNoAccountAndClipsOpaqueServerReply()async throws{
        let source=image(),mask=image(mask:true),png=UIImage(cgImage:source).pngData()!,hash=digest(source),client=session();defer{client.invalidateAndCancel()}
        RestorationMockProtocol.respond={request in
            XCTAssertEqual(request.url?.absoluteString,"https://restoration.test/v1/restore");XCTAssertEqual(request.httpMethod,"POST");XCTAssertEqual(request.value(forHTTPHeaderField:"User-Agent"),"CookiesEditor/1.1");XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"));XCTAssertEqual(request.value(forHTTPHeaderField:"Cache-Control"),"no-store");XCTAssertTrue(request.value(forHTTPHeaderField:"Content-Type")?.hasPrefix("multipart/form-data; boundary=Cookies-")==true)
            return(200,["X-Cookies-Source-SHA256":hash,"Content-Type":"image/png"],png)
        }
        let result=try await CloudRestoration.repair(source:source,mask:mask,endpoint:URL(string:"https://restoration.test"),session:client),bytes=try BigLaMaSession.rgba(result),selection=try BigLaMaSession.rgba(mask)
        for i in 0..<1024{XCTAssertEqual(bytes[i*4+3],selection[i*4]>0 ? 255:0);if selection[i*4]==0{XCTAssertEqual(Array(bytes[i*4..<i*4+4]),[0,0,0,0])}}
    }
    func testMismatchedSourceDigestOrDimensionsAreRejected()async throws{
        let source=image(),mask=image(mask:true),client=session();defer{client.invalidateAndCancel()}
        for wrongSize in [false,true]{let response=UIImage(cgImage:image(width:wrongSize ? 24:32)).pngData()!,hash=wrongSize ? digest(source):String(repeating:"0",count:64)
            RestorationMockProtocol.respond={_ in(200,["X-Cookies-Source-SHA256":hash],response)}
            do{_ = try await CloudRestoration.repair(source:source,mask:mask,endpoint:URL(string:"https://restoration.test"),session:client);XCTFail("Unrelated or resized patches must never be applied")}catch{XCTAssertTrue(error.localizedDescription.contains("لم تتطابق"))}
        }
    }
    func testCapacityErrorDoesNotBecomeAFalseSuccessfulPatch()async throws{
        let client=session();defer{client.invalidateAndCancel()};RestorationMockProtocol.respond={_ in(429,[:],Data("{\"error\":\"daily_capacity_reached\"}".utf8))}
        do{_ = try await CloudRestoration.repair(source:image(),mask:image(mask:true),endpoint:URL(string:"https://restoration.test"),session:client);XCTFail("Capacity rejection must be visible")}catch{XCTAssertTrue(error.localizedDescription.contains("سعتها"))}
    }
}
