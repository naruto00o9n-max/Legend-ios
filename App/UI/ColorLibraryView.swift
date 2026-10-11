import SwiftUI

/// Shared entry point for every color tool, including gradients and tag settings.
struct CookiesColorWell:View {
    let title:String
    @Binding var selection:Color
    @State private var open=false
    init(_ title:String,selection:Binding<Color>,supportsOpacity:Bool=false){self.title=title;_selection=selection}
    var body:some View{Button{open=true}label:{HStack(spacing:12){Text(title).foregroundStyle(Palette.pale);Spacer();Circle().fill(selection).frame(width:27,height:27).overlay(Circle().stroke(.white.opacity(0.7),lineWidth:1));Image(systemName:"square.grid.3x3.fill").font(.system(size:13)).foregroundStyle(Palette.secondary)}}.buttonStyle(.plain).accessibilityIdentifier("color-well-"+title).sheet(isPresented:$open){ColorLibraryView(selection:$selection,title:title).presentationDetents([.medium,.large]).presentationDragIndicator(.visible)}}
}
struct ColorLibraryView:View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @ObservedObject private var store=ColorLibraryStore.shared
    @Binding var selection:Color
    var title="لوحة الألوان"
    @State private var section="recent"
    @State private var hex=""
    @State private var revision=0
    @State private var naming=false
    @State private var name=""
    @State private var editingGroup:ColorGroup?
    var current:String{UIColor(selection).hex}
    var colors:[StoredColor]{if section=="recent"{return Array(store.recent.prefix(80))};if section=="favorites"{return store.recent.filter(\.favorite)};if let id=UUID(uuidString:section){return store.recent.filter{$0.groups.contains(id)}};return store.recent}
    var body:some View{NavigationStack{ZStack{Palette.ink.ignoresSafeArea();ScrollView{VStack(alignment:.leading,spacing:18){
        HStack(spacing:16){RoundedRectangle(cornerRadius:16).fill(selection).frame(width:62,height:62).overlay(RoundedRectangle(cornerRadius:16).stroke(.white.opacity(0.4),lineWidth:1));VStack(alignment:.leading,spacing:7){Text(title).font(.system(size:19,weight:.semibold));Text("#"+current).font(.system(size:13,design:.monospaced)).foregroundStyle(Palette.secondary)};Spacer();Button{store.favorite(current)}label:{Image(systemName:store.library.colors.first{$0.hex==current}?.favorite==true ? "star.fill":"star")}.accessibilityIdentifier("color-favorite").tint(Palette.gold)}.padding(18).glass(22)
        VStack(spacing:14){ColorPicker("الطيف الكامل",selection:$selection,supportsOpacity:false).accessibilityIdentifier("color-spectrum");HStack{Text("HEX").font(.system(size:12,design:.monospaced));TextField("RRGGBB",text:$hex).textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).font(.system(size:14,design:.monospaced)).accessibilityIdentifier("color-hex");Button("تطبيق"){if let value=ColorLibraryStore.normalized(hex){choose(value)}}.disabled(ColorLibraryStore.normalized(hex)==nil)}.environment(\.layoutDirection,.leftToRight);ForEach(0..<3,id:\.self){channel in HStack{Text(["R","G","B"][channel]).font(.system(size:12,design:.monospaced)).frame(width:18);StepSlider(value:rgb(channel),in:0...255);Text("\(Int(rgb(channel).wrappedValue))").font(.system(size:11,design:.monospaced)).frame(width:30)}}.environment(\.layoutDirection,.leftToRight)}.padding(18).glass(22)
        ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){tab("الأخيرة",id:"recent",icon:"clock");tab("المفضلة",id:"favorites",icon:"star");tab("الكل",id:"all",icon:"square.grid.2x2");ForEach(store.library.groups){group in tab(group.title,id:group.id.uuidString,icon:"folder").contextMenu{Button("إعادة تسمية"){editingGroup=group;name=group.title;naming=true};Button("حذف المجموعة",role:.destructive){store.removeGroup(group.id);section="all"}}};Button{editingGroup=nil;name="";naming=true}label:{Image(systemName:"folder.badge.plus").padding(12).glass(12)}.accessibilityLabel("إنشاء مجموعة ألوان")}}.accessibilityIdentifier("color-sections")
        if colors.isEmpty{VStack(spacing:8){Image(systemName:"paintpalette").font(.title2);Text(section=="favorites" ? "أضف ألوانك المهمة إلى المفضلة":"تظهر هنا الألوان التي تستخدمها").font(.system(size:13))}.foregroundStyle(Palette.secondary).frame(maxWidth:.infinity).padding(24)}
        LazyVGrid(columns:[GridItem(.adaptive(minimum:64),spacing:12)],spacing:14){ForEach(colors){color in Button{choose(color.hex)}label:{VStack(spacing:7){RoundedRectangle(cornerRadius:14).fill(Color(uiColor:UIColor(hex:color.hex))).frame(height:48).overlay(RoundedRectangle(cornerRadius:14).stroke(current==color.hex ? Palette.gold:.white.opacity(0.2),lineWidth:current==color.hex ? 2:1));HStack(spacing:3){Text(color.hex).font(.system(size:9,design:.monospaced));if color.favorite{Image(systemName:"star.fill").font(.system(size:8)).foregroundStyle(Palette.gold)}}}.foregroundStyle(Palette.pale)}.buttonStyle(.plain).accessibilityIdentifier("stored-color-"+color.hex).contextMenu{Button(color.favorite ? "إزالة من المفضلة":"إضافة إلى المفضلة"){store.favorite(color.hex)};ForEach(store.library.groups){group in Button{store.toggleGroup(color.hex,group.id)}label:{Label(group.title,systemImage:color.groups.contains(group.id) ? "checkmark.circle":"circle")}}}}}
        if let error=store.error{Text(error).font(.footnote).foregroundStyle(Palette.secondary)}
    }.padding(20).frame(maxWidth:720).frame(maxWidth:.infinity)}}.navigationTitle("الألوان").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("تم"){commit();dismiss()}.accessibilityIdentifier("color-done")}}.alert(editingGroup==nil ? "مجموعة جديدة":"اسم المجموعة",isPresented:$naming){TextField("اسم المجموعة",text:$name);Button("حفظ"){if let group=editingGroup{store.renameGroup(group.id,name)}else if let id=store.createGroup(name){section=id.uuidString}};Button("إلغاء",role:.cancel){}}}.cookiesInterface().onAppear{revision=store.revision;store.beginChoice();hex=current}.onChange(of:current){_,value in hex=value}.onDisappear{commit();store.endChoice()}.onChange(of:phase){_,value in if value != .active{commit()}}}
    func choose(_ value:String){selection=Color(uiColor:UIColor(hex:value));hex=value;store.record(value)}
    func commit(){guard revision==store.revision else{return};store.record(current);do{try store.flush()}catch{store.error=error.localizedDescription}}
    func rgb(_ index:Int)->Binding<Double>{Binding(get:{let value=UInt32(current,radix:16) ?? 0;return Double((value >> ((2-index)*8)) & 255)},set:{value in let old=UInt32(current,radix:16) ?? 0,shift=(2-index)*8;let next=(old & ~(UInt32(255)<<shift)) | (UInt32(max(0,min(255,Int(value))))<<shift);selection=Color(uiColor:UIColor(hex:String(format:"%06X",next)))})}
    func tab(_ title:String,id:String,icon:String)->some View{Button{section=id}label:{Label(title,systemImage:icon).font(.system(size:12,weight:.medium)).padding(.horizontal,12).padding(.vertical,10).background(section==id ? Palette.gold.opacity(0.14):.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(section==id ? Palette.gold.opacity(0.5):.white.opacity(0.08),lineWidth:1))}.buttonStyle(.plain).accessibilityIdentifier("colors-"+id)}
}
