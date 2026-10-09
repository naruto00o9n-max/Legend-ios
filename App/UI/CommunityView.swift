import SwiftUI

struct CommunityEntry: Decodable, Identifiable {
    let id:String
    let title:String?
    let description:String?
    let author_name:String?
    let media_urls:[String]?
    let tags:[String]?
    let is_pinned:Bool?
    let upvotes:Int?
    let created_at:String?
}
struct CommunityComment:Decodable,Identifiable {
    let id:String
    let author_name:String?
    let content:String
    let created_at:String?
}
struct ServiceHub: View {
    @EnvironmentObject private var service:ReferenceService
    @Environment(\.dismiss) private var dismiss
    @State private var posts:[CommunityEntry]=[]
    @State private var search=""
    @State private var loading=false
    @State private var failure:String?
    @State private var account=false
    @State private var profile=false
    var filtered:[CommunityEntry] {posts.filter{search.isEmpty || (($0.title ?? "")+($0.description ?? "")+($0.tags ?? []).joined(separator:" ")).localizedCaseInsensitiveContains(search)}}
    var body:some View {
        NavigationStack {
            ZStack {
                Ambient()
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:18) {
                        HStack { Image(systemName:"magnifyingglass").foregroundStyle(Palette.quiet);TextField("ابحث في المجتمع",text:$search).font(.system(size:14));if !search.isEmpty{Button{search=""}label:{Image(systemName:"xmark.circle.fill")}} }.padding(14).glass(14)
                        if loading && posts.isEmpty{ProgressView("جارٍ تحميل المنشورات…").frame(maxWidth:.infinity).padding(30)}
                        if let failure{VStack(alignment:.leading,spacing:12){Text(failure).font(.system(size:13));Button("إعادة المحاولة"){Task{await load()}}}.padding(18).glass(18)}
                        ForEach(Array(filtered.enumerated()),id:\.element.id) { index,post in
                            NavigationLink { CommunityDetail(post:post) } label: { CommunityCard(post:post) }.buttonStyle(.plain).accessibilityIdentifier("community-post-\(index)")
                        }
                        if !loading && failure==nil && filtered.isEmpty{Text(search.isEmpty ? "لا توجد منشورات بعد":"لا توجد نتائج لهذا البحث").font(.system(size:14)).foregroundStyle(Palette.quiet).frame(maxWidth:.infinity).padding(40)}
                    }.padding(24).frame(maxWidth:760).frame(maxWidth:.infinity)
                }.refreshable{await load()}
            }.navigationTitle("المجتمع").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}};ToolbarItem(placement:.topBarTrailing){IconButton(icon:"person.crop.circle",title:"حسابي"){if service.session==nil{account=true}else{profile=true}}}}
            .foregroundStyle(Palette.pale).task{await load()}
            .fullScreenCover(isPresented:$account){AccountView()}.fullScreenCover(isPresented:$profile){ProfileView()}
        }.tint(Palette.pale)
    }
    private func load() async {
        loading=true;defer{loading=false}
        do{let data=try await service.request("/rest/v1/community_posts?select=*&status=eq.APPROVED&order=is_pinned.desc,last_bumped_at.desc&limit=50");posts=try JSONDecoder().decode([CommunityEntry].self,from:data);failure=nil}catch{failure=error.localizedDescription}
    }
}
struct CommunityCard:View {
    let post:CommunityEntry
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack(spacing:10) { Image(systemName:"person.crop.circle.fill").font(.system(size:28)).foregroundStyle(Palette.quiet);VStack(alignment:.leading,spacing:4){Text(post.author_name ?? "عضو المجتمع").font(.system(size:12,weight:.medium));Text("من مجتمع المترجمين").font(.system(size:10)).foregroundStyle(Palette.quiet)};Spacer();if post.is_pinned==true{Image(systemName:"pin.fill").font(.system(size:13)).foregroundStyle(Palette.gold)} }
            Text(post.title ?? "").font(.system(size:18,weight:.semibold)).multilineTextAlignment(.leading)
            if let text=post.description,!text.isEmpty{Text(text).font(.system(size:14)).foregroundStyle(.white.opacity(0.8)).lineSpacing(5).lineLimit(4).multilineTextAlignment(.leading)}
            if let media=post.media_urls?.first,let url=URL(string:media){AsyncImage(url:url){phase in switch phase{case .success(let image):image.resizable().scaledToFit();case .failure:Image(systemName:"photo").frame(height:80).frame(maxWidth:.infinity).foregroundStyle(Palette.quiet);default:ProgressView().frame(height:180).frame(maxWidth:.infinity)}}.frame(maxHeight:320).clipShape(RoundedRectangle(cornerRadius:14))}
            if let tags=post.tags,!tags.isEmpty{Text(tags.map{$0.hasPrefix("#") ? $0:"#"+$0}.joined(separator:"  ")).font(.system(size:11)).foregroundStyle(Palette.quiet)}
            Divider().overlay(.white.opacity(0.08))
            HStack { Label("\(post.upvotes ?? 0)",systemImage:"hand.thumbsup");Spacer();Label("المنشور والتعليقات",systemImage:"bubble.right") }.font(.system(size:12)).foregroundStyle(Palette.quiet)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(20).glass(22)
    }
}
struct CommunityDetail: View {
    let post:CommunityEntry
    @EnvironmentObject private var service:ReferenceService
    @State private var comments:[CommunityComment]=[]
    @State private var reply=""
    @State private var info:String?
    @State private var busy=false
    @State private var account=false
    var body:some View {
        ZStack { Ambient();ScrollView { VStack(alignment:.leading,spacing:20) {
            CommunityCard(post:post)
            if let text=post.description{Text(text).font(.system(size:15)).lineSpacing(6).textSelection(.enabled)}
            Button{Task{await vote()}}label:{Label("الإعجاب بالمنشور",systemImage:"hand.thumbsup")}.buttonStyle(GoldButtonStyle()).disabled(busy)
            HStack{Text("التعليقات").font(.system(size:18,weight:.semibold));Spacer();Text("\(comments.count)").font(.system(size:12)).foregroundStyle(Palette.quiet)}
            ForEach(comments){comment in VStack(alignment:.leading,spacing:9){Text(comment.author_name ?? "عضو المجتمع").font(.system(size:12,weight:.semibold));Text(comment.content).font(.system(size:14)).lineSpacing(5)}.frame(maxWidth:.infinity,alignment:.leading).padding(16).glass(16)}
            if comments.isEmpty{Text("لا توجد تعليقات معتمدة بعد").font(.system(size:12)).foregroundStyle(Palette.quiet)}
            if service.session==nil{Button("سجّل الدخول للمشاركة"){account=true}.buttonStyle(GoldButtonStyle())}else{
                ArabicTextEditor(text:$reply,identifier:"community-reply").frame(height:100).glass(16)
                Button("إرسال التعليق"){Task{await submit()}}.buttonStyle(GoldButtonStyle(primary:true)).disabled(busy || reply.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
            if let info{Text(info).font(.system(size:12)).lineSpacing(5).textSelection(.enabled)}
        }.padding(24).frame(maxWidth:760).frame(maxWidth:.infinity) } }.navigationTitle("المنشور").navigationBarTitleDisplayMode(.inline).foregroundStyle(Palette.pale).task{await loadComments()}.fullScreenCover(isPresented:$account){AccountView()}
    }
    private func loadComments() async {
        guard UUID(uuidString:post.id) != nil else{return}
        do{comments=try JSONDecoder().decode([CommunityComment].self,from:try await service.request("/rest/v1/post_comments?select=*&post_id=eq.\(post.id)&status=eq.APPROVED&order=created_at.asc&limit=100"))}catch{info=error.localizedDescription}
    }
    private func vote() async {
        guard let id=service.session?.user.id else{account=true;return}
        busy=true;defer{busy=false}
        do{let data=try await service.request("/rest/v1/rpc/increment_post_upvote",method:"POST",body:["target_post_id":post.id,"target_user_id":id],authenticated:true);info=(try? JSONSerialization.jsonObject(with:data,options:.fragmentsAllowed)) as? Bool == true ? "تم تسجيل الإعجاب":"سبق أن سجّلت إعجابك بهذا المنشور"}catch{info=error.localizedDescription}
    }
    private func submit() async {
        guard let user=service.session?.user else{return}
        busy=true;defer{busy=false}
        do{_ = try await service.request("/rest/v1/post_comments",method:"POST",body:["post_id":post.id,"user_id":user.id,"author_name":user.email?.components(separatedBy:"@").first ?? "عضو","content":reply,"status":"PENDING"],authenticated:true);reply="";info="أُرسل تعليقك للمراجعة؛ يظهر بعد اعتماده."}catch{info=error.localizedDescription}
    }
}
