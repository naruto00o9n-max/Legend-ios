import SwiftUI

struct UserProfile:Decodable {
    let id:String
    let display_name:String?
    let discord_avatar:String?
    let subscription_tier:String?
    let points:Int?
    let total_bubbles_typed:Int?
    let season_bubbles:Int?
}
struct ProfileView:View {
    @EnvironmentObject private var service:ReferenceService
    @Environment(\.dismiss) private var dismiss
    @State private var profile:UserProfile?
    @State private var failure:String?
    @State private var loading=true
    var body:some View {
        NavigationStack { ZStack {Ambient();ScrollView {VStack(spacing:24) {
            ZStack { Circle().fill(.white.opacity(0.05));if let avatar=profile?.discord_avatar,let url=URL(string:avatar){AsyncImage(url:url){phase in if let image=phase.image{image.resizable().scaledToFill()}else{Image(systemName:"person.fill").font(.system(size:38)).foregroundStyle(Palette.quiet)}}}else{Image(systemName:"person.fill").font(.system(size:38)).foregroundStyle(Palette.quiet)} }.frame(width:92,height:92).clipShape(Circle()).overlay(Circle().stroke(Palette.gold.opacity(0.35),lineWidth:1)).padding(.top,25)
            VStack(spacing:8){Text(profile?.display_name ?? "حسابي").font(.system(size:26,weight:.semibold));Text(service.session?.user.email ?? "").font(.system(size:13)).foregroundStyle(Palette.quiet).environment(\.layoutDirection,.leftToRight)}
            if loading{ProgressView()}
            if let profile{HStack(spacing:12){stat("الفقاعات",profile.total_bubbles_typed ?? 0,"text.bubble");stat("النقاط",profile.points ?? 0,"star")};HStack{Label("العضوية",systemImage:"seal");Spacer();Text(profile.subscription_tier ?? "FREE").font(.system(size:12,weight:.semibold))}.font(.system(size:14)).padding(20).glass(20)}
            if let failure{Text(failure).font(.system(size:13)).lineSpacing(5);Button("إعادة المحاولة"){Task{await load()}}}
            Button("تسجيل الخروج"){Task{await service.logout();dismiss()}}.buttonStyle(GoldButtonStyle())
        }.padding(24).frame(maxWidth:660).frame(maxWidth:.infinity)} }.foregroundStyle(Palette.pale).navigationTitle("الملف الشخصي").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}}}.task{await load()}.tint(Palette.pale)}
    }
    private func stat(_ title:String,_ value:Int,_ icon:String)->some View {VStack(spacing:12){Image(systemName:icon).font(.system(size:22));Text("\(value)").font(.system(size:28,weight:.semibold,design:.rounded));Text(title).font(.system(size:12)).foregroundStyle(Palette.quiet)}.frame(maxWidth:.infinity).padding(22).glass(20)}
    private func load() async {
        guard let id=service.session?.user.id,UUID(uuidString:id) != nil else{loading=false;failure="سجّل الدخول لعرض ملفك الشخصي";return}
        loading=true;defer{loading=false}
        do{let data=try await service.request("/rest/v1/vw_user_profiles?select=id,display_name,discord_avatar,subscription_tier,points,total_bubbles_typed,season_bubbles&id=eq.\(id)",authenticated:true);profile=try JSONDecoder().decode([UserProfile].self,from:data).first;failure=profile==nil ? "لم يُرجع الخادم ملفًا لهذا الحساب":nil}catch{failure=error.localizedDescription}
    }
}
