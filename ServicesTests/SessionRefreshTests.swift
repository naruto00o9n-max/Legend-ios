import XCTest
@testable import CookiesEditor

private final class SessionTransport:URLProtocol {
    static var handler:((URLRequest)throws->Data)?
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){
        do{let data=try Self.handler!(request);client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}
    }
    override func stopLoading(){}
}
final class SessionRefreshTests:XCTestCase {
    private func jwt(_ expiry:Double)throws->String {
        let bytes=try JSONSerialization.data(withJSONObject:["exp":expiry]);return "header."+bytes.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")+".signature"
    }
    @MainActor func testConcurrentAuthenticatedReadsRefreshOnceAndUseRenewedToken() async throws {
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[SessionTransport.self];let transport=URLSession(configuration:config);defer{transport.invalidateAndCancel();SessionTransport.handler=nil}
        let fresh=try jwt(Date().timeIntervalSince1970+3600),expired=try jwt(1),lock=NSLock();var refreshes=0;var authorizations:[String]=[]
        SessionTransport.handler={request in
            lock.lock();defer{lock.unlock()}
            if request.url!.path=="/auth/v1/token"{refreshes+=1;return try JSONEncoder().encode(ServiceSession(access_token:fresh,refresh_token:"rotated",user:ServiceUser(id:"user",email:nil)))}
            authorizations.append(request.value(forHTTPHeaderField:"Authorization") ?? "");return Data("[]".utf8)
        }
        let client=ReferenceService(configuration:ReferenceConfig(url:"https://session.test",key:"anon"),urlSession:transport,initialSession:ServiceSession(access_token:expired,refresh_token:"refresh",user:ServiceUser(id:"user",email:nil)))
        async let first=client.request("/rest/v1/first",authenticated:true)
        async let second=client.request("/rest/v1/second",authenticated:true)
        _ = try await (first,second)
        XCTAssertEqual(refreshes,1);XCTAssertEqual(authorizations,["Bearer "+fresh,"Bearer "+fresh]);XCTAssertEqual(client.session?.refresh_token,"rotated")
    }
    @MainActor func testPublicReadDoesNotRefreshExpiredSessionAndLogoutClearsIt() async throws {
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[SessionTransport.self];let transport=URLSession(configuration:config);defer{transport.invalidateAndCancel();SessionTransport.handler=nil}
        let lock=NSLock();var paths:[String]=[];var authorization=""
        SessionTransport.handler={request in lock.lock();defer{lock.unlock()};paths.append(request.url!.path);if request.url!.path.contains("community"){authorization=request.value(forHTTPHeaderField:"Authorization") ?? ""};return Data("[]".utf8)}
        let client=ReferenceService(configuration:ReferenceConfig(url:"https://session.test",key:"anon"),urlSession:transport,initialSession:ServiceSession(access_token:try jwt(1),refresh_token:"refresh",user:ServiceUser(id:"user",email:nil)))
        _ = try await client.request("/rest/v1/community")
        XCTAssertEqual(authorization,"Bearer anon");XCTAssertFalse(paths.contains("/auth/v1/token"))
        await client.logout();XCTAssertNil(client.session)
        do{_ = try await client.request("/rest/v1/private",authenticated:true);XCTFail("Signed-out request must fail locally")}catch{}
    }
}
