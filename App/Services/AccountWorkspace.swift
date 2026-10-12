import Foundation
import Combine

struct LeaderboardPerson:Decodable,Identifiable {
    let id:String
    let display_name:String?
    let total_bubbles_typed:Int?
    let rank:Int?
}
struct LeaderboardResponse:Decodable {
    let top_10:[LeaderboardPerson]
    let current_user:LeaderboardPerson?
}
struct AccountProfile {
    let values:[String:Any]
    var id:String{values["id"] as? String ?? ""}
    func text(_ key:String)->String?{let value=values[key] as? String;return value?.isEmpty==false ? value:nil}
    func number(_ key:String)->Int?{if let n=values[key] as? NSNumber{return n.intValue};if let s=values[key] as? String{return Int(s)};return nil}
    func flag(_ key:String)->Bool{values[key] as? Bool ?? false}
    var name:String{text("display_name") ?? "حسابي"}
    var avatar:URL?{guard let value=text("discord_avatar"),let url=URL(string:value),url.scheme=="https" else{return nil};return url}
}

/// Own-account operations share the existing authenticated client. A late reply
/// cannot populate the next user's profile or report a silent RLS update as saved.
@MainActor final class AccountWorkspace:ObservableObject {
    let service:ReferenceService
    @Published var profile:AccountProfile?
    @Published var leaderboard:LeaderboardResponse?
    @Published var loading=false
    @Published var writing=false
    @Published var error:String?
    @Published var updatedAt:Date?
    @Published var discordCommand:String?
    @Published var discordCreated:Date?
    private var owner:String?
    init(service:ReferenceService){self.service=service}
    func invalidate(){owner=nil;profile=nil;leaderboard=nil;discordCommand=nil;discordCreated=nil;error=nil;updatedAt=nil}
    private func ownID()throws->String{
        guard let id=service.session?.user.id,UUID(uuidString:id) != nil else{throw ImageFailure.message("سجّل الدخول إلى حسابك أولًا")};return id
    }
    private func checkOwner(_ id:String)throws{guard service.session?.user.id==id else{invalidate();throw CancellationError()}}
    @discardableResult func readProfile()async throws->AccountProfile{
        let id=try ownID()
        if owner != id{invalidate();owner=id}
        let data=try await service.request("/rest/v1/vw_user_profiles?select=*&id=eq.\(id)",authenticated:true)
        try checkOwner(id)
        guard let row=(try JSONSerialization.jsonObject(with:data) as? [[String:Any]])?.first,row["id"] as? String==id else{throw ImageFailure.message("لم يُرجع الخادم ملف حسابك؛ حاول التحديث مجددًا")}
        let result=AccountProfile(values:row);profile=result;updatedAt=Date();return result
    }
    func load()async{
        guard !loading else{return};loading=true;error=nil;defer{loading=false}
        do{_ = try await readProfile()}catch is CancellationError{}catch{self.error=error.localizedDescription}
    }
    func loadLeaderboard()async{
        guard !loading else{return};loading=true;error=nil;defer{loading=false}
        let id=service.session?.user.id
        do{
            let body:[String:Any]=["current_user_id":id.map{$0 as Any} ?? NSNull()]
            let data=try await service.request("/rest/v1/rpc/get_leaderboard",method:"POST",body:body,authenticated:id != nil)
            guard service.session?.user.id==id else{throw CancellationError()}
            let result=try JSONDecoder().decode(LeaderboardResponse.self,from:data)
            guard result.current_user==nil || result.current_user?.id==id else{throw ImageFailure.message("لم تتطابق استجابة المركز مع حسابك")}
            leaderboard=result;updatedAt=Date()
        }catch is CancellationError{}catch{self.error=error.localizedDescription}
    }
    func updateName(_ value:String)async throws{
        guard !writing else{throw ImageFailure.message("انتظر اكتمال العملية الحالية")}
        let name=value.trimmingCharacters(in:.whitespacesAndNewlines)
        guard (2...40).contains(name.count) else{throw ImageFailure.message("اكتب اسمًا بين حرفين و٤٠ حرفًا")}
        let id=try ownID();writing=true;defer{writing=false}
        _ = try await service.request("/rest/v1/user_profiles?id=eq.\(id)",method:"PATCH",body:["display_name":name],authenticated:true,returnRepresentation:true)
        try checkOwner(id)
        let current=try await readProfile()
        guard current.text("display_name")==name else{throw ImageFailure.message("لم يُحفظ الاسم في الخادم؛ احتُفظ بالاسم السابق")}
    }
    func generateDiscordCommand()async throws{
        guard !writing else{throw ImageFailure.message("انتظر اكتمال العملية الحالية")}
        let id=try ownID(),alphabet=Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"),token="YTYPER-"+String((0..<6).map{_ in alphabet.randomElement()!}),date=Date()
        let formatter=ISO8601DateFormatter();formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        writing=true;defer{writing=false}
        let data=try await service.request("/rest/v1/user_profiles?id=eq.\(id)&select=id,link_token",method:"PATCH",body:["link_token":token,"link_token_created_at":formatter.string(from:date)],authenticated:true,returnRepresentation:true)
        try checkOwner(id)
        guard let row=(try JSONSerialization.jsonObject(with:data) as? [[String:Any]])?.first,row["id"] as? String==id,row["link_token"] as? String==token else{throw ImageFailure.message("لم يُحفظ رمز الربط في الخادم؛ حاول مجددًا")}
        discordCommand="/link token:"+token;discordCreated=date
    }
}
