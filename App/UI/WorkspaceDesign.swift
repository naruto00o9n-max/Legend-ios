import SwiftUI

struct SurfaceHeader:View {
    let title:String
    var subtitle:String=""
    var icon:String="square.stack.3d.up"
    var body:some View{HStack(alignment:.center,spacing:14){SurfaceSymbol(icon:icon,size:48);VStack(alignment:.leading,spacing:6){Text(title).font(.system(size:25,weight:.semibold,design:.rounded));if !subtitle.isEmpty{Text(subtitle).font(.system(size:12)).foregroundStyle(Palette.secondary).fixedSize(horizontal:false,vertical:true)}};Spacer(minLength:0)}.padding(.vertical,8)}
}
struct SurfaceSymbol:View {
    let icon:String
    var size:CGFloat=42
    var body:some View{Image(systemName:icon).font(.system(size:size*0.42,weight:.light)).foregroundStyle(.white).frame(width:size,height:size).background(LinearGradient(colors:[.white.opacity(0.1),Palette.gold.opacity(0.09)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:size*0.29)).overlay(RoundedRectangle(cornerRadius:size*0.29).stroke(.white.opacity(0.12),lineWidth:0.75))}
}
struct SectionHeading:View {
    let title:String
    var detail:String=""
    var body:some View{HStack(alignment:.firstTextBaseline,spacing:10){Text(title).font(.system(size:16,weight:.semibold));Spacer(minLength:4);if !detail.isEmpty{Text(detail).font(.system(size:11)).foregroundStyle(Palette.quiet)}}.padding(.top,6)}
}
struct GlassSection<Content:View>:View {
    let title:String
    var icon:String
    var subtitle:String
    @ViewBuilder var content:Content
    init(_ title:String,icon:String,subtitle:String="",@ViewBuilder content:()->Content){self.title=title;self.icon=icon;self.subtitle=subtitle;self.content=content()}
    var body:some View{VStack(alignment:.leading,spacing:16){HStack(spacing:10){Image(systemName:icon).font(.system(size:15)).frame(width:28,height:28).background(.white.opacity(0.055),in:RoundedRectangle(cornerRadius:8));VStack(alignment:.leading,spacing:4){Text(title).font(.system(size:15,weight:.semibold));if !subtitle.isEmpty{Text(subtitle).font(.system(size:11)).foregroundStyle(Palette.quiet)}};Spacer(minLength:0)};Rectangle().fill(Palette.line).frame(height:0.5);content.font(.system(size:14))}.padding(18).glass(24)}
}
struct NavigationRow:View {
    let title:String
    var subtitle:String=""
    let icon:String
    var action:()->Void
    var body:some View{Button(action:action){HStack(spacing:12){SurfaceSymbol(icon:icon,size:36);VStack(alignment:.leading,spacing:4){Text(title).font(.system(size:14,weight:.medium));if !subtitle.isEmpty{Text(subtitle).font(.system(size:11)).foregroundStyle(Palette.quiet).fixedSize(horizontal:false,vertical:true)}};Spacer(minLength:8);Image(systemName:"chevron.left").font(.system(size:10,weight:.medium)).foregroundStyle(Palette.quiet)}.frame(maxWidth:.infinity,minHeight:46).contentShape(Rectangle())}.buttonStyle(.plain)}
}
struct ActionTile:View {
    let title:String
    var subtitle:String=""
    var icon:String
    var prominent=false
    var action:()->Void
    var body:some View{Button(action:action){VStack(alignment:.leading,spacing:14){HStack{SurfaceSymbol(icon:icon);Spacer();Image(systemName:"arrow.up.left").font(.system(size:11)).foregroundStyle(Palette.quiet)};VStack(alignment:.leading,spacing:5){Text(title).font(.system(size:15,weight:.semibold));if !subtitle.isEmpty{Text(subtitle).font(.system(size:11)).foregroundStyle(Palette.secondary).lineLimit(2)}}}.padding(18).frame(maxWidth:.infinity,minHeight:136,alignment:.leading).glass(22).overlay(RoundedRectangle(cornerRadius:22).stroke(prominent ? Palette.gold.opacity(0.36):.clear,lineWidth:0.8))}.buttonStyle(.plain).foregroundStyle(Palette.pale)}
}
struct CapsuleActionStyle:ButtonStyle {
    var selected=false
    func makeBody(configuration:Configuration)->some View{configuration.label.font(.system(size:12,weight:.medium)).foregroundStyle(.white).padding(.horizontal,13).frame(minHeight:36).background(selected ? Palette.gold.opacity(0.16):.white.opacity(configuration.isPressed ? 0.12:0.045),in:Capsule()).overlay(Capsule().stroke(selected ? Palette.gold.opacity(0.55):Palette.line,lineWidth:0.8)).opacity(configuration.isPressed ? 0.78:1)}
}
struct QuietBadge:View {
    let text:String
    var icon:String?=nil
    var body:some View{HStack(spacing:5){if let icon{Image(systemName:icon)};Text(text)}.font(.system(size:10,weight:.medium)).foregroundStyle(Palette.secondary).padding(.horizontal,9).padding(.vertical,6).background(.white.opacity(0.055),in:Capsule()).overlay(Capsule().stroke(Palette.line,lineWidth:0.5))}
}
struct SearchBar:View {
    var placeholder:String
    @Binding var text:String
    var body:some View{HStack(spacing:10){Image(systemName:"magnifyingglass").foregroundStyle(Palette.quiet);TextField(placeholder,text:$text).font(.system(size:13)).autocorrectionDisabled();if !text.isEmpty{Button{text=""}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(Palette.quiet)}.accessibilityLabel("مسح البحث")}}.glassField()}
}
struct SettingToggle:View {
    let title:String
    var detail:String=""
    @Binding var value:Bool
    var id:String=""
    var body:some View{HStack(spacing:16){VStack(alignment:.leading,spacing:5){Text(title).font(.system(size:14));if !detail.isEmpty{Text(detail).font(.system(size:11)).foregroundStyle(Palette.quiet).fixedSize(horizontal:false,vertical:true)}};Spacer(minLength:4);Toggle(title,isOn:$value).labelsHidden().toggleStyle(.switch).tint(Palette.gold).accessibilityLabel(title).accessibilityIdentifier(id)}.frame(minHeight:44)}
}
struct WorkspaceEmpty:View {
    let title:String
    let detail:String
    var icon:String="rectangle.stack"
    var body:some View{VStack(spacing:14){SurfaceSymbol(icon:icon,size:64);Text(title).font(.system(size:19,weight:.semibold));Text(detail).font(.system(size:12)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth:330)}.frame(maxWidth:.infinity).padding(.vertical,34).padding(.horizontal,18).glass(26)}
}
struct ToolModeCard<Actions:View>:View {
    var title:String
    var detail:String
    var icon:String
    var close:()->Void
    @ViewBuilder var actions:Actions
    init(title:String,detail:String,icon:String,close:@escaping ()->Void,@ViewBuilder actions:()->Actions){self.title=title;self.detail=detail;self.icon=icon;self.close=close;self.actions=actions()}
    var body:some View{VStack(alignment:.leading,spacing:12){HStack(spacing:10){SurfaceSymbol(icon:icon,size:34);VStack(alignment:.leading,spacing:4){Text(title).font(.system(size:13,weight:.semibold));Text(detail).font(.system(size:10)).foregroundStyle(Palette.secondary).fixedSize(horizontal:false,vertical:true)};Spacer(minLength:4);IconButton(icon:"xmark",title:"إنهاء الوضع",action:close)};ScrollView(.horizontal,showsIndicators:false){HStack(spacing:10){actions}.buttonStyle(CapsuleActionStyle())}}.padding(12).floatingGlass(20).frame(maxWidth:560).padding(.horizontal,12)}
}

struct MetricField:View {
    let title:String
    @Binding var value:Double
    var unit="px"
    var body:some View{HStack(spacing:12){Text(title).font(.system(size:13));Spacer();TextField(title,value:$value,format:.number).font(.system(size:15,weight:.medium,design:.monospaced)).multilineTextAlignment(.trailing).keyboardType(.numberPad).frame(width:100);Text(unit).font(.system(size:10)).foregroundStyle(Palette.quiet)}.glassField()}
}

/// Fills the available row without leaving unused columns on an iPad. Width is
/// measured locally so split windows and rotation do not depend on screen size.
struct ResponsiveActionGrid<Content:View>:View {
    let itemCount:Int
    var minimumWidth:CGFloat=145
    @ViewBuilder var content:Content
    @State private var width:CGFloat=0
    init(items:Int,minimumWidth:CGFloat=145,@ViewBuilder content:()->Content){
        itemCount=items;self.minimumWidth=minimumWidth;self.content=content()
    }
    private var columns:[GridItem]{
        let available=width>0 ? width:minimumWidth*2+12
        let count=max(1,min(itemCount,Int((available+12)/(minimumWidth+12))))
        return Array(repeating:GridItem(.flexible(minimum:0),spacing:12),count:count)
    }
    var body:some View{
        LazyVGrid(columns:columns,spacing:12){content}
            .background(GeometryReader{geometry in Color.clear.preference(key:ActionGridWidth.self,value:geometry.size.width)})
            .onPreferenceChange(ActionGridWidth.self){value in if value.isFinite,abs(width-value)>1{width=value}}
    }
}
private struct ActionGridWidth:PreferenceKey {
    static var defaultValue:CGFloat=0
    static func reduce(value:inout CGFloat,nextValue:()->CGFloat){value=nextValue()}
}
