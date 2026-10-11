import SwiftUI

struct WelcomeView:View {
    var begin:()->Void
    var edit:()->Void={}
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var visible=false
    @State private var guide=false
    var body:some View{GeometryReader{geometry in ZStack{Ambient();ScrollView{VStack(spacing:28){
        HStack{Brand();Spacer();Button{guide=true}label:{Image(systemName:"questionmark").font(.system(size:15,weight:.medium)).frame(width:40,height:40).glass(14)}.accessibilityLabel("دليل التطبيق")}.padding(.top,8)
        Spacer(minLength:geometry.size.height>700 ? 30:4)
        ZStack{Circle().stroke(.white.opacity(0.045),lineWidth:1).frame(width:206,height:206);Circle().stroke(LinearGradient(colors:[.clear,Palette.gold.opacity(0.42),.clear],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:1).frame(width:158,height:158);Image("CookiesLogo").resizable().scaledToFit().frame(width:92,height:92).clipShape(Circle()).shadow(color:Palette.gold.opacity(0.18),radius:34);QuietBadge(text:"لكل حوار مكانه",icon:"text.bubble").offset(y:104)}.accessibilityHidden(true)
        VStack(spacing:12){Text("Cookies Editor").font(.system(size:36,weight:.semibold,design:.rounded)).tracking(-1).environment(\.layoutDirection,.leftToRight);Text("حكايتك. بصمتك. إبداعك.").font(.system(size:20,weight:.light));Text("مساحة لتحرير المانهوا، تنسيق حواراتها،\nوترتيب فصولها بدقة صورك الأصلية.").font(.system(size:13)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).lineSpacing(5)}
        HStack(spacing:8){feature("نصوص","textformat");feature("طبقات","square.3.layers.3d");feature("فصول","rectangle.stack")}.frame(maxWidth:480)
        VStack(spacing:12){Button(action:NetworkPolicy.enabled ? begin:edit){Label(NetworkPolicy.enabled ? "تسجيل الدخول":"ابدأ الإبداع",systemImage:NetworkPolicy.enabled ? "person.crop.circle":"arrow.up.left")}.buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("welcome-start");if NetworkPolicy.enabled{Button("متابعة التحرير",action:edit).buttonStyle(GoldButtonStyle())};Text("مساحة عمل مرتّبة. أدوات قريبة. مشاريع محفوظة.").font(.system(size:10)).foregroundStyle(Palette.quiet)}.frame(maxWidth:420)
        Spacer(minLength:24)
    }.padding(.horizontal,24).padding(.bottom,24).frame(maxWidth:900).frame(maxWidth:.infinity).frame(minHeight:geometry.size.height).opacity(visible ? 1:0).offset(y:visible ? 0:8)}}}.foregroundStyle(Palette.pale).onAppear{withAnimation(reduced || !EditorPreferences.motion ? nil:.easeOut(duration:0.45)){visible=true}}.sheet(isPresented:$guide){AppGuideView()}}
    private func feature(_ title:String,_ icon:String)->some View{VStack(spacing:9){Image(systemName:icon).font(.system(size:19,weight:.light));Text(title).font(.system(size:11))}.frame(maxWidth:.infinity).padding(.vertical,16).glass(17)}
}
