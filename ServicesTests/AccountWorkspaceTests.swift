import XCTest
@testable import CookiesEditor

private final class AccountTransport:URLProtocol {
    static var handler:((URLRequest)throws->Data)?
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading(){do{let data=try Self.handler!(request);client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}}
    override func stopLoading(){}
}
final class AccountWorkspaceTests:XCTestCase {
    private let id="00112233-4455-6677-8899-AABBCCDDEEFF"
    private func token()throws->String{let data=try JSONSerialization.data(withJSONObject:["exp":Date().timeIntervalSince1970+3600]);return "test."+data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")+".fixture"}
    private func body(_ request:URLRequest)throws->[String:Any]{
        if let data=request.httpBody{return try JSONSerialization.jsonObject(with:data) as? [String:Any] ?? [:]}
        guard let stream=request.httpBodyStream else{return [:]};stream.open();defer{stream.close()};var data=Data(),buffer=[UInt8](repeating:0,count:4096)
        while stream.hasBytesAvailable{let n=stream.read(&buffer,maxLength:buffer.count);if n<=0{break};data.append(contentsOf:buffer.prefix(n))}
        return try JSONSerialization.jsonObject(with:data) as? [String:Any] ?? [:]
    }
    @MainActor private func client(authenticated:Bool=true)throws->(ReferenceService,URLSession){let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[AccountTransport.self];let transport=URLSession(configuration:config);let session=authenticated ? ServiceSession(access_token:try token(),refresh_token:"fixture",user:ServiceUser(id:id,email:nil)):nil;return (ReferenceService(configuration:ReferenceConfig(url:"https://account-workspace.test",key:"anon-fixture"),urlSession:transport,initialSession:session),transport)}
    @MainActor func testPublicLeaderboardUsesOriginalNullUserContractAndDoesNotFabricateOwnRank()async throws{
        let (service,transport)=try client(authenticated:false);defer{transport.invalidateAndCancel();AccountTransport.handler=nil}
        AccountTransport.handler={request in XCTAssertEqual(request.url?.path,"/rest/v1/rpc/get_leaderboard");XCTAssertEqual(request.httpMethod,"POST");XCTAssertTrue(try self.body(request)["current_user_id"] is NSNull);XCTAssertEqual(request.value(forHTTPHeaderField:"Authorization"),"Bearer anon-fixture");return Data("{\"top_10\":[{\"id\":\"public-person\",\"display_name\":\"محرر\",\"total_bubbles_typed\":120}],\"current_user\":null}".utf8)}
        let model=AccountWorkspace(service:service);await model.loadLeaderboard();XCTAssertNil(model.error);XCTAssertEqual(model.leaderboard?.top_10.first?.total_bubbles_typed,120);XCTAssertNil(model.leaderboard?.current_user)
    }
    @MainActor func testOwnNamePatchIsScopedAndOnlySavedAfterReadback()async throws{
        let (service,transport)=try client();defer{transport.invalidateAndCancel();AccountTransport.handler=nil};var value="قديم",patches=0
        AccountTransport.handler={request in XCTAssertTrue(request.url!.query!.contains("id=eq."+self.id));if request.httpMethod=="PATCH"{patches+=1;XCTAssertEqual(request.value(forHTTPHeaderField:"Prefer"),"return=representation");let body=try self.body(request);XCTAssertEqual(Set(body.keys),["display_name"]);value=body["display_name"] as! String;return Data("[]".utf8)};return try JSONSerialization.data(withJSONObject:[["id":self.id,"display_name":value,"total_bubbles_typed":900]])}
        let model=AccountWorkspace(service:service);try await model.updateName("  اسم جديد  ");XCTAssertEqual(model.profile?.name,"اسم جديد");XCTAssertEqual(patches,1)
    }
    @MainActor func testSilentRLSUpdateNeverReportsNameSaved()async throws{
        let (service,transport)=try client();defer{transport.invalidateAndCancel();AccountTransport.handler=nil}
        AccountTransport.handler={request in if request.httpMethod=="PATCH"{return Data("[]".utf8)};return try JSONSerialization.data(withJSONObject:[["id":self.id,"display_name":"الاسم السابق"]])}
        let model=AccountWorkspace(service:service);do{try await model.updateName("الاسم الجديد");XCTFail("Zero-row update must fail readback")}catch{XCTAssertEqual(model.profile?.name,"الاسم السابق")};XCTAssertFalse(model.writing)
    }
    @MainActor func testDiscordTokenIsOriginalProtocolAndConfirmedByOwnedRow()async throws{
        let (service,transport)=try client();defer{transport.invalidateAndCancel();AccountTransport.handler=nil};var token=""
        AccountTransport.handler={request in XCTAssertEqual(request.httpMethod,"PATCH");XCTAssertTrue(request.url!.query!.contains("id=eq."+self.id));let body=try self.body(request);XCTAssertEqual(Set(body.keys),["link_token","link_token_created_at"]);token=body["link_token"] as! String;XCTAssertNotNil(AccountDate.parse(body["link_token_created_at"] as! String));XCTAssertTrue(token.hasPrefix("YTYPER-"));XCTAssertEqual(token.count,13);return try JSONSerialization.data(withJSONObject:[["id":self.id,"link_token":token]])}
        let model=AccountWorkspace(service:service);try await model.generateDiscordCommand();XCTAssertEqual(model.discordCommand,"/link token:"+token);XCTAssertNotNil(model.discordCreated);XCTAssertFalse(model.writing)
    }
    @MainActor func testDiscordSilentUpdateIsRejectedAndCreatesNoCommand()async throws{
        let (service,transport)=try client();defer{transport.invalidateAndCancel();AccountTransport.handler=nil};AccountTransport.handler={_ in Data("[]".utf8)}
        let model=AccountWorkspace(service:service);do{try await model.generateDiscordCommand();XCTFail("Empty update must not expose a fake command")}catch{XCTAssertNil(model.discordCommand)}
    }
    @MainActor func testWrongProfileOwnerAndLoggedOutWritesAreRejected()async throws{
        let (service,transport)=try client();defer{transport.invalidateAndCancel();AccountTransport.handler=nil};var requests=0
        AccountTransport.handler={_ in requests+=1;return Data("[{\"id\":\"another-account\",\"display_name\":\"Other\"}]".utf8)}
        let model=AccountWorkspace(service:service);await model.load();XCTAssertNil(model.profile);XCTAssertNotNil(model.error)
        service.session=nil;let count=requests;do{try await model.updateName("اسمي");XCTFail("Logged-out write must be gated")}catch{};XCTAssertEqual(requests,count)
    }
    @MainActor func testLateProfileResponseCannotRestoreLoggedOutIdentity()async throws{
        let (service,transport)=try client();defer{transport.invalidateAndCancel();AccountTransport.handler=nil}
        AccountTransport.handler={_ in Thread.sleep(forTimeInterval:0.15);return try JSONSerialization.data(withJSONObject:[["id":self.id,"display_name":"الاسم"]])}
        let model=AccountWorkspace(service:service),task=Task{await model.load()};try await Task.sleep(nanoseconds:30_000_000);service.session=nil;await task.value;XCTAssertNil(model.profile);XCTAssertNil(model.updatedAt)
    }
    func testRankPresentationMatchesOriginalThresholdsWithoutMembership(){
        XCTAssertEqual(AccountRank.title(0),"متدرب");XCTAssertEqual(AccountRank.progress(99),99);XCTAssertEqual(AccountRank.title(100),"F-");XCTAssertEqual(AccountRank.progress(100),0);XCTAssertEqual(AccountRank.title(1_000_000),"SSS+");XCTAssertEqual(AccountRank.progress(1_000_000),100);XCTAssertEqual(AccountRank.progress(-1),0)
    }
}
