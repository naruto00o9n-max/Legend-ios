import SwiftUI

struct WelcomeView:View {
    var begin:()->Void
    @Environment(\.accessibilityReduceMotion) var reduced
    @State private var appeared=false
    var body:some View {
        GeometryReader{g in ZStack{Ambient();ScrollView{VStack(spacing:24){HStack{Brand();Spacer();Image(systemName:"sparkle").foregroundStyle(Palette.quiet)}
            HeroArtwork().frame(height:min(230,g.size.height*0.28)).padding(.top,20)
            VStack(spacing:14){Text("حوارك، بكل تفاصيله.").font(.system(size:29,weight:.semibold)).minimumScaleFactor(0.8).lineLimit(2);Text("مساحة هادئة لتحرير المانهوا\nنصوص وطبقات وصور بدقتها الأصلية").font(.system(size:14)).foregroundStyle(Palette.quiet).multilineTextAlignment(.center).lineSpacing(5)}
            HStack(spacing:8){ForEach(["صور طويلة","خطوط عربية","طبقات"],id:\.self){Text($0).font(.system(size:11)).padding(.horizontal,12).padding(.vertical,9).glass(20)}}
            VStack(spacing:12){Button("افتح مساحتك",action:begin).buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("welcome-start");Text("COOKIES / IPHONE").font(.system(size:9,weight:.medium)).tracking(4).foregroundStyle(Palette.quiet)}.padding(.top,8)
        }.padding(.horizontal,26).padding(.vertical,20).frame(minHeight:g.size.height).foregroundStyle(Palette.pale).opacity(appeared ? 1:0).offset(y:appeared ? 0:10)}}}
        .onAppear{withAnimation(reduced ? nil:.easeOut(duration:0.6)){appeared=true}}
    }
}
struct HeroArtwork:View {
    var body:some View {ZStack{
        Circle().fill(RadialGradient(colors:[Palette.gold.opacity(0.2),.clear],center:.center,startRadius:0,endRadius:110)).frame(width:220,height:220)
        VStack(spacing:8){HStack{Capsule().fill(Palette.gold.opacity(0.3)).frame(width:40,height:3);Spacer();Image(systemName:"square.3.layers.3d").font(.system(size:11))};RoundedRectangle(cornerRadius:12).fill(Palette.gold.opacity(0.08)).overlay{
            VStack(spacing:10){HStack{Spacer();Text("كل كلمة\nفي مكانها.").font(.system(size:14,weight:.semibold)).multilineTextAlignment(.center).padding(12).background(Palette.gold.opacity(0.18),in:RoundedRectangle(cornerRadius:14))};Image(systemName:"moon.stars").font(.system(size:38,weight:.ultraLight)).foregroundStyle(Palette.gold.opacity(0.5));Spacer()}.padding(15)
        };HStack{Text("800 × 15000").font(.system(size:8,design:.monospaced));Spacer();Circle().fill(Palette.gold).frame(width:4,height:4)}}.padding(12).frame(width:175,height:205).glass(20).rotationEffect(.degrees(-8))
        HStack(spacing:8){Image(systemName:"textformat").font(.system(size:21));VStack(alignment:.leading,spacing:3){Text("حروف عربية").font(.system(size:10,weight:.semibold));Text("دقة في التفاصيل").font(.system(size:8)).foregroundStyle(Palette.quiet)}}.padding(12).glass(14).rotationEffect(.degrees(6)).offset(x:72,y:65)
    }.foregroundStyle(Palette.pale).accessibilityHidden(true)}
}
