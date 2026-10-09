import SwiftUI

enum Palette {
    static let gold=Color(red:0.83,green:0.69,blue:0.22)
    static let pale=Color.white
    static let ink=Color(red:0.025,green:0.025,blue:0.03)
    static let quiet=Color.white.opacity(0.54)
}
struct Glass:ViewModifier {
    var radius:CGFloat=22
    func body(content:Content)->some View {
        content.background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:radius,style:.continuous))
            .background(RoundedRectangle(cornerRadius:radius).fill(.black.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius:radius).stroke(LinearGradient(colors:[Palette.pale.opacity(0.36),Palette.gold.opacity(0.06),Palette.gold.opacity(0.2)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.6).allowsHitTesting(false))
            .shadow(color:.black.opacity(0.22),radius:16,y:8)
    }
}
struct CookiesInterface: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
            .preferredColorScheme(.dark).tint(Palette.pale)
    }
}
extension View {
    func glass(_ radius:CGFloat=22)->some View{modifier(Glass(radius:radius))}
    func cookiesInterface()->some View{modifier(CookiesInterface())}
}
struct GoldButtonStyle:ButtonStyle {
    var primary=false
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:15,weight:.semibold)).foregroundStyle(primary ? Palette.ink:Palette.pale)
            .frame(minHeight:46).frame(maxWidth:.infinity)
            .background(primary ? AnyShapeStyle(LinearGradient(colors:[Palette.gold.opacity(0.92),Palette.gold],startPoint:.topLeading,endPoint:.bottomTrailing)):AnyShapeStyle(.ultraThinMaterial),in:RoundedRectangle(cornerRadius:16))
            .overlay(RoundedRectangle(cornerRadius:16).stroke(Palette.gold.opacity(primary ? 0:0.3),lineWidth:0.6))
            .scaleEffect(configuration.isPressed ? 0.98:1)
    }
}
struct IconButton:View {
    var icon:String;var title:String;var selected=false;var action:()->Void
    var body:some View {Button(action:action){Image(systemName:icon).font(.system(size:18,weight:.medium)).frame(width:44,height:44).background(selected ? Palette.gold.opacity(0.18):.clear,in:RoundedRectangle(cornerRadius:12))}.foregroundStyle(Palette.pale).accessibilityLabel(title)}
}
struct Brand:View {
    var body:some View{HStack(spacing:10){Image("CookiesLogo").resizable().scaledToFit().frame(width:34,height:34).clipShape(Circle());VStack(alignment:.leading,spacing:1){Text("COOKIES").font(.system(size:13,weight:.semibold,design:.rounded)).tracking(3);Text("EDITOR").font(.system(size:9,weight:.medium)).tracking(4).foregroundStyle(Palette.quiet)}}.foregroundStyle(Palette.pale).environment(\.layoutDirection,.leftToRight)}
}
struct Ambient:View {
    @Environment(\.accessibilityReduceMotion) var reduced
    var body:some View {ZStack{Palette.ink;RadialGradient(colors:[Palette.gold.opacity(0.14),.clear],center:.topTrailing,startRadius:5,endRadius:400);RadialGradient(colors:[Palette.gold.opacity(0.07),.clear],center:.bottomLeading,startRadius:20,endRadius:380)}.ignoresSafeArea()}
}
