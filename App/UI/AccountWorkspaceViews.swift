import SwiftUI
import UIKit

struct AccountWorkspaceView:View {
    @EnvironmentObject private var service:ReferenceService
    var body:some View{AccountWorkspaceContent(service:service)}
}
private struct AccountWorkspaceContent:View {
    @ObservedObject var service:ReferenceService
    @StateObject private var model:AccountWorkspace
    @Environment(\.dismiss) private var dismiss
    @State private var login=false
    @State private var editName=false
    @State private var destination:AccountDestination?
    init(service:ReferenceService){self.service=service;_model=StateObject(wrappedValue:AccountWorkspace(service:service))}
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(spacing:22){
        SurfaceHeader(title:"حسابك",subtitle:"هويتك، إنجازك، والخدمات المتصلة",icon:"person.crop.circle")
        if service.session != nil{
            profileCard
            if model.loading{ProgressView().tint(Palette.gold)}
            if let error=model.error{AccountFailure(text:error){Task{await model.load()}}}
            GlassSection("إنجازك",icon:"chart.bar",subtitle:"بيانات حسابك من الخادم"){
                HStack(spacing:10){AccountMetric(title:"الفقاعات",value:model.profile?.number("total_bubbles_typed"),icon:"text.bubble");AccountMetric(title:"الموسم",value:model.profile?.number("season_bubbles"),icon:"calendar");AccountMetric(title:"النقاط",value:model.profile?.number("points"),icon:"star")}
                HStack{Label("العضوية",systemImage:"seal");Spacer();Text(membership).font(.system(size:13,weight:.semibold))}.font(.system(size:13)).padding(.top,8)
                if let value=model.profile?.text("subscription_end_date"),let date=AccountDate.parse(value){HStack{Text("نهاية العضوية");Spacer();Text(date,style:.date)}.font(.system(size:12)).foregroundStyle(Palette.secondary)}
                if let bubbles=model.profile?.number("total_bubbles_typed"){VStack(spacing:10){HStack{Text("الرتبة");Spacer();Text(AccountRank.title(bubbles)).environment(\.layoutDirection,.leftToRight);Text("\(AccountRank.progress(bubbles))٪").foregroundStyle(Palette.secondary)}.font(.system(size:12));ProgressView(value:Double(AccountRank.progress(bubbles)),total:100).tint(Palette.gold)}.padding(.top,8)}
            }
        }else{AccountSignIn{login=true}}
        GlassSection("خدمات الحساب",icon:"square.grid.2x2"){
            NavigationRow(title:"المتصدرون",subtitle:"ترتيب الفقاعات ومركزك الحالي",icon:"trophy"){destination = .leaderboard}.accessibilityIdentifier("account-leaderboard")
            NavigationRow(title:"ربط Discord",subtitle:"إنشاء أمر الربط والتحقق من الحساب",icon:"link"){if service.session==nil{login=true}else{destination = .discord}}.accessibilityIdentifier("account-discord")
        }
        if let date=model.updatedAt{Text("آخر تحديث: \(date.formatted(date:.omitted,time:.shortened))").font(.system(size:11)).foregroundStyle(Palette.quiet)}
        if service.session != nil{Button{Task{await service.logout();model.invalidate()}}label:{Label("تسجيل الخروج",systemImage:"rectangle.portrait.and.arrow.right")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("account-logout")}
    }.padding(20).frame(maxWidth:740).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("الحساب").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}.accessibilityIdentifier("account-workspace-close")};ToolbarItem(placement:.topBarTrailing){IconButton(icon:"arrow.clockwise",title:"تحديث"){Task{await model.load()}}.disabled(service.session==nil || model.loading)}}
    .fullScreenCover(isPresented:$login){AccountView()}
    .fullScreenCover(item:$destination){value in if value == .leaderboard{LeaderboardView()}else{DiscordLinkView()}}
    .sheet(isPresented:$editName){ProfileNameEditor(model:model).cookiesInterface().presentationDetents([.height(340)]).presentationBackground(.clear)}
    .task{if service.session != nil{await model.load()}}
    .onChange(of:service.session?.user.id){_,_ in model.invalidate();if service.session != nil{Task{await model.load()}}}
    }.cookiesInterface()}
    private var membership:String{switch model.profile?.text("subscription_tier")?.uppercased(){case "FREE":return "مجانية";case nil:return "—";default:return model.profile?.text("subscription_tier") ?? "—"}}
    private var profileCard:some View{VStack(spacing:16){AccountAvatar(url:model.profile?.avatar,size:82);Text(model.profile?.name ?? "حسابي").font(.system(size:25,weight:.semibold));Text(service.session?.user.email ?? "").font(.system(size:12)).foregroundStyle(Palette.secondary).environment(\.layoutDirection,.leftToRight);Button{editName=true}label:{Label("تعديل الاسم",systemImage:"pencil")}.buttonStyle(CapsuleActionStyle()).disabled(model.profile==nil).accessibilityIdentifier("account-edit-name")}.frame(maxWidth:.infinity).padding(24).glass(28)}
}
private enum AccountDestination:String,Identifiable{case leaderboard,discord;var id:String{rawValue}}
private struct AccountMetric:View {
    let title:String,value:Int?,icon:String
    var body:some View{VStack(spacing:10){Image(systemName:icon).foregroundStyle(Palette.pale);Text(value.map{String($0)} ?? "—").font(.system(size:22,weight:.semibold,design:.rounded)).minimumScaleFactor(0.65).lineLimit(1);Text(title).font(.system(size:11)).foregroundStyle(Palette.secondary)}.frame(maxWidth:.infinity).padding(.vertical,18).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:17))}
}
private struct AccountAvatar:View {
    let url:URL?,size:CGFloat
    var body:some View{ZStack{Circle().fill(.white.opacity(0.06));if let url{AsyncImage(url:url){p in if let image=p.image{image.resizable().scaledToFill()}else{Image(systemName:"person.fill").font(.system(size:size*0.35))}}}else{Image(systemName:"person.fill").font(.system(size:size*0.35))}}.frame(width:size,height:size).clipShape(Circle()).overlay(Circle().stroke(Palette.gold.opacity(0.3),lineWidth:1))}
}
private struct AccountFailure:View {
    let text:String,retry:()->Void
    var body:some View{VStack(alignment:.leading,spacing:12){Label(text,systemImage:"exclamationmark.circle").font(.system(size:13)).lineSpacing(4);Button("إعادة المحاولة",action:retry).buttonStyle(CapsuleActionStyle())}.frame(maxWidth:.infinity,alignment:.leading).padding(18).glass(20)}
}
private struct AccountSignIn:View {
    let action:()->Void
    var body:some View{VStack(spacing:14){SurfaceSymbol(icon:"person.crop.circle",size:64);Text("حساب واحد لإنجازك").font(.system(size:21,weight:.semibold));Text("سجّل الدخول لعرض بياناتك وربط حسابك بالخدمات.").font(.system(size:13)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center);Button("تسجيل الدخول",action:action).buttonStyle(GoldButtonStyle()).accessibilityIdentifier("account-workspace-login")}.padding(24).frame(maxWidth:.infinity).glass(25)}
}
private struct ProfileNameEditor:View {
    @ObservedObject var model:AccountWorkspace
    @Environment(\.dismiss) private var dismiss
    @State private var name=""
    @State private var failure:String?
    var body:some View{VStack(alignment:.leading,spacing:18){HStack{Text("اسمك في الحساب").font(.system(size:20,weight:.semibold));Spacer();IconButton(icon:"xmark",title:"إغلاق"){dismiss()}};TextField("الاسم",text:$name).textInputAutocapitalization(.never).padding(16).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("account-name-field");Text("يُحفظ الاسم في حسابك ويُحدّث ملفك وترتيبك.").font(.system(size:12)).foregroundStyle(Palette.secondary);if let failure{Text(failure).font(.system(size:12))};Button{Task{do{try await model.updateName(name);dismiss()}catch{failure=error.localizedDescription}}}label:{HStack{if model.writing{ProgressView()};Text("حفظ الاسم")}}.buttonStyle(GoldButtonStyle()).disabled(model.writing).accessibilityIdentifier("account-name-save")}.padding(22).glass(25).foregroundStyle(Palette.pale).onAppear{name=model.profile?.name ?? ""}}
}
struct LeaderboardView:View {
    @EnvironmentObject private var service:ReferenceService
    var body:some View{LeaderboardContent(service:service)}
}
private struct LeaderboardContent:View {
    @StateObject private var model:AccountWorkspace
    @Environment(\.dismiss) private var dismiss
    init(service:ReferenceService){_model=StateObject(wrappedValue:AccountWorkspace(service:service))}
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:20){
        SurfaceHeader(title:"المتصدرون",subtitle:"أكثر الحسابات إنجازًا في الفقاعات",icon:"trophy")
        if let me=model.leaderboard?.current_user{VStack(alignment:.leading,spacing:12){Label("مركزك",systemImage:"person.crop.circle").font(.system(size:12)).foregroundStyle(Palette.secondary);HStack{Text(me.display_name ?? "حسابي").font(.system(size:17,weight:.semibold));Spacer();if let rank=me.rank{Text("#\(rank)").font(.system(size:22,weight:.semibold,design:.rounded))}};Text("\(me.total_bubbles_typed ?? 0) فقاعة").font(.system(size:13))}.padding(20).glass(23)}
        if model.loading{ProgressView().frame(maxWidth:.infinity)}
        if let error=model.error{AccountFailure(text:error){Task{await model.loadLeaderboard()}}}
        if let entries=model.leaderboard?.top_10{if entries.isEmpty{WorkspaceEmpty(title:"لا يوجد ترتيب حاليًا",detail:"حاول التحديث لاحقًا.",icon:"trophy")}else{ForEach(Array(entries.enumerated()),id:\.element.id){index,row in HStack(spacing:16){Text(String(index+1)).font(.system(size:20,weight:.semibold,design:.rounded)).frame(width:32);VStack(alignment:.leading,spacing:6){Text(row.display_name ?? "محرر").font(.system(size:15,weight:.semibold));Text("\(row.total_bubbles_typed ?? 0) فقاعة").font(.system(size:12)).foregroundStyle(Palette.secondary)};Spacer();if index<3{Image(systemName:"medal").foregroundStyle(Palette.gold)}}.padding(18).glass(20).accessibilityIdentifier("leaderboard-row-\(index+1)")}}}
        if let date=model.updatedAt{Text("آخر تحديث: \(date.formatted(date:.omitted,time:.shortened))").font(.system(size:11)).foregroundStyle(Palette.quiet)}
    }.padding(20).frame(maxWidth:720).frame(maxWidth:.infinity)}.refreshable{await model.loadLeaderboard()}}.foregroundStyle(Palette.pale).navigationTitle("المتصدرون").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}.accessibilityIdentifier("leaderboard-close")}}.task{await model.loadLeaderboard()}}.cookiesInterface()}
}
struct DiscordLinkView:View {
    @EnvironmentObject private var service:ReferenceService
    var body:some View{DiscordLinkContent(service:service)}
}
private struct DiscordLinkContent:View {
    @ObservedObject var service:ReferenceService
    @StateObject private var model:AccountWorkspace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied=false
    init(service:ReferenceService){self.service=service;_model=StateObject(wrappedValue:AccountWorkspace(service:service))}
    private var linked:Bool{model.profile?.flag("discord_linked")==true || model.profile?.text("discord_id") != nil || model.profile?.text("discord_avatar") != nil}
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:20){
        SurfaceHeader(title:"ربط Discord",subtitle:"ربط الحساب بالسيرفر والبوت الأصلي",icon:"link")
        HStack(spacing:14){SurfaceSymbol(icon:linked ? "checkmark.seal":"link",size:52);VStack(alignment:.leading,spacing:6){Text(linked ? "الحساب مرتبط":"اربط حسابك").font(.system(size:18,weight:.semibold));Text(model.profile?.name ?? "حسابك").font(.system(size:12)).foregroundStyle(Palette.secondary)};Spacer();if model.loading{ProgressView()}}.padding(20).glass(23)
        if let error=model.error{AccountFailure(text:error){Task{await model.load()}}}
        GlassSection("خطوات الربط",icon:"list.number"){
            Text("١ · أنشئ أمر الربط لحسابك.\n٢ · انسخ الأمر وافتح سيرفر Discord.\n٣ · أرسل الأمر إلى البوت، ثم ارجع وحدّث حالة الربط.").font(.system(size:13)).lineSpacing(8)
            if let command=model.discordCommand{Text(command).font(.system(size:14,design:.monospaced)).textSelection(.enabled).environment(\.layoutDirection,.leftToRight).frame(maxWidth:.infinity,alignment:.leading).padding(16).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:15)).accessibilityIdentifier("discord-command");Button{UIPasteboard.general.string=command;copied=true}label:{Label(copied ? "نُسخ الأمر":"نسخ الأمر",systemImage:copied ? "checkmark":"doc.on.doc")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("discord-copy");if let date=model.discordCreated{Text("أُنشئ \(date.formatted(date:.omitted,time:.shortened))").font(.system(size:11)).foregroundStyle(Palette.secondary)}}
            Button{Task{do{copied=false;try await model.generateDiscordCommand()}catch{model.error=error.localizedDescription}}}label:{HStack{if model.writing{ProgressView()};Label(model.discordCommand==nil ? "إنشاء أمر الربط":"إنشاء أمر جديد",systemImage:"key")}}.buttonStyle(GoldButtonStyle()).disabled(model.writing || service.session==nil).accessibilityIdentifier("discord-generate")
            Button{openURL(URL(string:"https://discord.com/invite/wYq59W2qte")!)}label:{Label("فتح سيرفر Discord",systemImage:"arrow.up.right.square")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("discord-open-server")
            Button{Task{await model.load()}}label:{Label("تحديث حالة الربط",systemImage:"arrow.clockwise")}.buttonStyle(CapsuleActionStyle()).disabled(model.loading).accessibilityIdentifier("discord-refresh")
        }
    }.padding(20).frame(maxWidth:700).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("Discord").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}}}.task{await model.load()}}.cookiesInterface()}
}
enum AccountDate {
    static func parse(_ value:String)->Date?{let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds];if let d=f.date(from:value){return d};f.formatOptions=[.withInternetDateTime];return f.date(from:value)}
}
