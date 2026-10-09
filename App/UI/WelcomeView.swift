import SwiftUI

struct WelcomeView: View {
    var begin: () -> Void
    var edit: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var visible = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Ambient()
                Canvas { context, size in
                    for i in 0..<110 {
                        let x = CGFloat((i * 73 + 19) % 997) / 997 * size.width
                        let y = CGFloat((i * 127 + 53) % 991) / 991 * size.height
                        let radius: CGFloat = i % 9 == 0 ? 1.1 : 0.55
                        context.fill(Path(ellipseIn: CGRect(x:x,y:y,width:radius*2,height:radius*2)),with:.color(Palette.gold.opacity(i % 9 == 0 ? 0.3:0.1)))
                    }
                }.accessibilityHidden(true)
                VStack(spacing: 0) {
                    HStack { Brand(); Spacer(); Text("مساحة للإبداع").font(.system(size:11)).foregroundStyle(Palette.quiet) }.padding(.top,24)
                    Spacer(minLength:40)
                    VStack(spacing:22) {
                        Image("CookiesLogo").resizable().scaledToFit().frame(width:84,height:84).clipShape(Circle()).shadow(color:Palette.gold.opacity(0.14),radius:35)
                        VStack(spacing:6) {
                            Text("Cookies").font(.system(size:48,weight:.semibold,design:.rounded)).tracking(-2)
                            Text("E D I T O R").font(.system(size:12,weight:.medium)).tracking(5).foregroundStyle(Palette.quiet)
                        }.environment(\.layoutDirection,.leftToRight)
                        Capsule().fill(LinearGradient(colors:[.clear,Palette.gold.opacity(0.8),.clear],startPoint:.leading,endPoint:.trailing)).frame(width:150,height:1)
                        Text("لكل حوار مكانه.").font(.system(size:17,weight:.medium)).padding(.top,6)
                    }.opacity(visible ? 1:0).offset(y:visible ? 0:12)
                    Spacer(minLength:44)
                    VStack(spacing:14) {
                        Button("تسجيل الدخول",action:begin).buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("welcome-start")
                        Button("متابعة التحرير",action:edit).font(.system(size:14)).frame(height:44).frame(maxWidth:.infinity).glass(16)
                        Text("نصوص وطبقات، بدقة صورك الأصلية").font(.system(size:11)).foregroundStyle(Palette.quiet).padding(.top,10)
                    }.frame(maxWidth:420).padding(.bottom,max(30,geometry.size.height*0.05))
                }.padding(.horizontal,28).frame(maxWidth:1000).frame(maxWidth:.infinity).foregroundStyle(Palette.pale)
            }
        }.onAppear { withAnimation(reduced ? nil:.easeOut(duration:0.55)) { visible=true } }
    }
}
