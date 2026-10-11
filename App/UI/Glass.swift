import SwiftUI

enum Palette {
    static let gold=Color(red:0.83,green:0.69,blue:0.22)
    static let pale=Color.white
    static let ink=Color(red:0.025,green:0.025,blue:0.03)
    static let quiet=Color.white.opacity(0.54)
    static let secondary=Color.white.opacity(0.7)
    static let line=Color.white.opacity(0.09)
}
struct Glass:ViewModifier {
    var radius:CGFloat=22
    func body(content:Content)->some View {
        // Static reflective surfaces keep scrolling inexpensive. Reserve live
        // backdrop blur for the floating panel, rather than every list row.
        content.background(RoundedRectangle(cornerRadius:radius,style:.continuous).fill(LinearGradient(colors:[Color(white:0.14).opacity(0.84),Color(white:0.06).opacity(0.9),Color(white:0.09).opacity(0.88)],startPoint:.topLeading,endPoint:.bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius:radius,style:.continuous).stroke(LinearGradient(colors:[.white.opacity(0.26),.white.opacity(0.045),Palette.gold.opacity(0.16)],startPoint:.topLeading,endPoint:.bottomTrailing),lineWidth:0.75).allowsHitTesting(false))
            .shadow(color:.black.opacity(0.18),radius:6,y:4)
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
    func floatingGlass(_ radius:CGFloat=24)->some View{
        background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:radius,style:.continuous)).glass(radius)
    }
    func glassField()->some View{padding(14).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Palette.line,lineWidth:1))}
    func cookiesInterface()->some View{modifier(CookiesInterface())}
}
struct GoldButtonStyle:ButtonStyle {
    var primary=false
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:15,weight:.semibold)).foregroundStyle(primary ? Palette.ink:Palette.pale)
            .frame(minHeight:46).frame(maxWidth:.infinity)
            .background(primary ? AnyShapeStyle(LinearGradient(colors:[Color(red:0.89,green:0.76,blue:0.36),Palette.gold],startPoint:.topLeading,endPoint:.bottomTrailing)):AnyShapeStyle(Color(white:0.13).opacity(0.9)),in:RoundedRectangle(cornerRadius:16))
            .overlay(RoundedRectangle(cornerRadius:16).stroke(Palette.gold.opacity(primary ? 0:0.3),lineWidth:0.6))
            .scaleEffect(configuration.isPressed && EditorPreferences.motion ? 0.98:1)
    }
}
struct IconButton:View {
    @Environment(\.isEnabled) private var enabled
    var icon:String;var title:String;var selected=false;var action:()->Void
    var body:some View {Button{EditorPreferences.feedback();action()}label:{Image(systemName:icon).font(.system(size:18,weight:.medium)).frame(width:44,height:44).background(selected ? Palette.gold.opacity(0.18):.clear,in:RoundedRectangle(cornerRadius:12))}.foregroundStyle(enabled ? Palette.pale:Color(white:0.35)).accessibilityLabel(title)}
}
struct Brand:View {
    var body:some View{HStack(spacing:10){Image("CookiesLogo").resizable().scaledToFit().frame(width:34,height:34).clipShape(Circle());VStack(alignment:.leading,spacing:1){Text("COOKIES").font(.system(size:13,weight:.semibold,design:.rounded)).tracking(3);Text("EDITOR").font(.system(size:9,weight:.medium)).tracking(4).foregroundStyle(Palette.quiet)}}.foregroundStyle(Palette.pale).environment(\.layoutDirection,.leftToRight)}
}
struct Ambient:View {
    @Environment(\.accessibilityReduceMotion) var reduced
    var body:some View {ZStack{Palette.ink;RadialGradient(colors:[Palette.gold.opacity(0.12),.clear],center:.topTrailing,startRadius:5,endRadius:460);RadialGradient(colors:[.white.opacity(0.035),.clear],center:.bottomLeading,startRadius:20,endRadius:380)
        Canvas{context,size in var path=Path();for i in 0..<5{let x=size.width*CGFloat(i)/4;path.move(to:CGPoint(x:x,y:0));path.addLine(to:CGPoint(x:x,y:size.height))};context.stroke(path,with:.color(.white.opacity(0.018)),lineWidth:0.5)}.accessibilityHidden(true)
    }.ignoresSafeArea().allowsHitTesting(false)}
}
