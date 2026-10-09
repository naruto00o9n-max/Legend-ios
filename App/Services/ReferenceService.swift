import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

struct ServiceSession:Codable {var access_token:String;var refresh_token:String;var user:ServiceUser}
struct ServiceUser:Codable {var id:String;var email:String?}
struct ReferenceConfig:Decodable {var url:String;var key:String}
enum NetworkPolicy {
    static var enabled:Bool {Bundle.main.object(forInfoDictionaryKey:"CookiesServicesEnabled") as? Bool ?? false}
}
@MainActor final class ReferenceService:NSObject,ObservableObject,ASWebAuthenticationPresentationContextProviding {
    @Published var session:ServiceSession?
    @Published var message:String?
    @Published var busy=false
    @Published var rows:[[String:Any]]=[]
    private var web:ASWebAuthenticationSession?
    override init(){super.init();if NetworkPolicy.enabled,let data=Keychain.read("session"),let saved=try? JSONDecoder().decode(ServiceSession.self,from:data){session=saved}}
    var config:ReferenceConfig? {guard NetworkPolicy.enabled,let url=Bundle.main.url(forResource:"ReferenceService",withExtension:"json"),let data=try? Data(contentsOf:url) else{return nil};return try? JSONDecoder().decode(ReferenceConfig.self,from:data)}
    func request(_ path:String,method:String="GET",body:[String:Any]?=nil,authenticated:Bool=false) async throws->Data {
        guard NetworkPolicy.enabled else{throw ImageFailure.message("هذه النسخة تعمل محليًا دون اتصال")}
        guard let config,let url=URL(string:config.url+path) else{throw ImageFailure.message("لم يُجهّز اتصال الخدمة")}
        if let token=session?.access_token,!path.hasPrefix("/auth/v1/token"),tokenExpiry(token)<Date().timeIntervalSince1970+60{try await refresh()}
        if authenticated&&session==nil{throw ImageFailure.message("سجّل الدخول إلى حسابك أولًا")}
        var r=URLRequest(url:url);r.httpMethod=method;r.timeoutInterval=25;r.setValue(config.key,forHTTPHeaderField:"apikey");r.setValue("Bearer "+(session?.access_token ?? config.key),forHTTPHeaderField:"Authorization");r.setValue("application/json",forHTTPHeaderField:"Content-Type");if let body{r.httpBody=try JSONSerialization.data(withJSONObject:body)}
        let (data,response)=try await URLSession.shared.data(for:r)
        guard let http=response as? HTTPURLResponse else{throw ImageFailure.message("تعذر قراءة استجابة الخادم")}
        guard (200..<300).contains(http.statusCode) else{
            let json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
            let code=(json?["error_code"] ?? json?["code"]) as? String ?? ""
            let reason=(json?["msg"] ?? json?["message"] ?? json?["error_description"] ?? json?["error"]) as? String ?? ""
            throw ImageFailure.message(Self.errorMessage(status:http.statusCode,code:code,reason:reason))
        };return data
    }
    func login(email:String,password:String,signup:Bool,name:String="") async {
        let email=email.trimmingCharacters(in:.whitespacesAndNewlines)
        guard email.contains("@"),!password.isEmpty else{message="اكتب بريدًا إلكترونيًا صحيحًا وكلمة المرور.";return}
        guard !signup || password.count>=6 else{message="كلمة المرور للحساب الجديد يجب أن تحتوي على ستة أحرف على الأقل.";return}
        busy=true;defer{busy=false}
        do{let data=try await request(signup ? "/auth/v1/signup":"/auth/v1/token?grant_type=password",method:"POST",body:signup ? ["email":email,"password":password,"data":["full_name":name.trimmingCharacters(in:.whitespacesAndNewlines),"display_name":name.trimmingCharacters(in:.whitespacesAndNewlines)]]:["email":email,"password":password])
            if let s=try? JSONDecoder().decode(ServiceSession.self,from:data){store(s);message=nil}else{message="أُرسل تأكيد الحساب إلى بريدك. أكّد البريد ثم سجّل الدخول."}
        }catch{message=error.localizedDescription}
    }
    private func tokenExpiry(_ token:String)->Double {
        let segments=token.split(separator:".");guard segments.count==3 else{return 0}
        var payload=String(segments[1]).replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/");payload+=String(repeating:"=",count:(4-payload.count%4)%4)
        guard let bytes=Data(base64Encoded:payload),let object=try? JSONSerialization.jsonObject(with:bytes) as? [String:Any] else{return 0};return object["exp"] as? Double ?? 0
    }
    private func store(_ session:ServiceSession){self.session=session;Keychain.save("session",data:(try? JSONEncoder().encode(session)) ?? Data())}
    func logout() async {if session != nil{_ = try? await request("/auth/v1/logout",method:"POST",authenticated:true)};session=nil;Keychain.remove("session")}
    func refresh() async throws{guard let refresh=session?.refresh_token else{return};let d=try await request("/auth/v1/token?grant_type=refresh_token",method:"POST",body:["refresh_token":refresh]);store(try JSONDecoder().decode(ServiceSession.self,from:d))}
    static func errorMessage(status:Int,code:String,reason:String)->String {
        switch code{case "invalid_credentials":return "البريد أو كلمة المرور غير صحيحة. حساب Google يحتاج الدخول باستخدام Google ما لم تُعيّن له كلمة مرور."
        case "email_not_confirmed":return "أكّد بريدك الإلكتروني من رسالة التأكيد ثم سجّل الدخول."
        case "over_email_send_rate_limit","over_request_rate_limit":return "وصلت إلى حد المحاولات. انتظر قليلًا ثم حاول مجددًا."
        case "signup_disabled":return "الخادم لا يسمح بإنشاء حسابات جديدة حاليًا."
        default:break}
        if status>=500{return "تعذر إتمام العملية في الخادم (\(status)). \(reason)"}
        return "\(reason.isEmpty ? "لم يقبل الخادم الطلب":reason) (\(status)\(code.isEmpty ? "":", "+code))"
    }
    static let callback="cookies-editor://auth/callback"
    func google() {
        guard !busy,let config else{message="تعذر تجهيز اتصال الحساب";return}
        busy=true;message=nil
        let verifier=UUID().uuidString+UUID().uuidString
        let challenge=Data(SHA256.hash(data:Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
        var components=URLComponents(string:config.url+"/auth/v1/authorize")!
        components.queryItems=[URLQueryItem(name:"provider",value:"google"),URLQueryItem(name:"redirect_to",value:Self.callback),URLQueryItem(name:"code_challenge",value:challenge),URLQueryItem(name:"code_challenge_method",value:"s256")]
        web=ASWebAuthenticationSession(url:components.url!,callbackURLScheme:"cookies-editor"){[weak self] url,error in Task{@MainActor in
            guard let self else{return};defer{self.busy=false;self.web=nil}
            guard let url else{if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin{self.message=error?.localizedDescription ?? "لم يكتمل تسجيل الدخول"};return}
            let items=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems ?? []
            if let failure=items.first(where:{$0.name=="error_description"})?.value{self.message=failure;return}
            guard let code=items.first(where:{$0.name=="code"})?.value else{self.message="لم يُرجع الخادم رمز الدخول إلى التطبيق. يلزم قبول عنوان العودة الخاص بنسخة iOS لدى الخدمة.";return}
            do{let data=try await self.request("/auth/v1/token?grant_type=pkce",method:"POST",body:["auth_code":code,"code_verifier":verifier]);self.store(try JSONDecoder().decode(ServiceSession.self,from:data));self.message=nil}catch{self.message=error.localizedDescription}
        }}
        web?.presentationContextProvider=self;web?.prefersEphemeralWebBrowserSession=false
        if web?.start() != true{busy=false;message="تعذر فتح صفحة تسجيل الدخول"}
    }
    func presentationAnchor(for session:ASWebAuthenticationSession)->ASPresentationAnchor {UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap(\.windows).first(where:\.isKeyWindow) ?? UIWindow()}
    func fetch(_ section:String) async {
        busy=true;defer{busy=false}
        do{let path:String
            switch section{case "profile":guard let id=session?.user.id else{throw ImageFailure.message("سجّل الدخول لعرض ملفك")};path="/rest/v1/user_profiles?select=*&id=eq.\(id)";case "community":path="/rest/v1/community_posts?select=*&status=eq.APPROVED&order=is_pinned.desc,last_bumped_at.desc&limit=30";default:path="/rest/v1/app_config?select=*&limit=30"}
            rows=(try JSONSerialization.jsonObject(with:try await request(path,authenticated:section=="profile"))) as? [[String:Any]] ?? [];message=nil
        }catch{message=error.localizedDescription;rows=[]}
    }
}
enum Keychain {
    static func query(_ key:String)->[String:Any]{[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:Bundle.main.bundleIdentifier ?? "Cookies",kSecAttrAccount as String:key]}
    static func save(_ key:String,data:Data){var q=query(key);SecItemDelete(q as CFDictionary);q[kSecValueData as String]=data;q[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;SecItemAdd(q as CFDictionary,nil)}
    static func read(_ key:String)->Data?{var q=query(key);q[kSecReturnData as String]=true;q[kSecMatchLimit as String]=kSecMatchLimitOne;var data:CFTypeRef?;return SecItemCopyMatching(q as CFDictionary,&data)==errSecSuccess ? data as? Data:nil}
    static func remove(_ key:String){SecItemDelete(query(key) as CFDictionary)}
}
