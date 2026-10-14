import SwiftUI

struct CanvasGridSettingsView:View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("editor-grid-data") private var data=Data()
    private var settings:CanvasGridSettings{CanvasGridSettings.decode(data)}
    private func binding<T>(_ key:WritableKeyPath<CanvasGridSettings,T>)->Binding<T>{Binding(get:{settings[keyPath:key]},set:{var value=settings;value[keyPath:key]=$0;data=value.data})}
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(spacing:20){
        SurfaceHeader(title:"شبكة اللوحة",subtitle:"دلائل ثابتة على الصورة، مع تحكم مباشر في ظهورها",icon:"grid")
        GlassSection("العرض",icon:"eye"){
            Toggle("إظهار الشبكة",isOn:binding(\.enabled)).tint(Palette.gold).accessibilityIdentifier("grid-enabled")
            Picker("التقسيم",selection:binding(\.kind)){ForEach(CanvasGridKind.allCases){value in Text(value.title).tag(value)}}.pickerStyle(.segmented).accessibilityIdentifier("grid-kind")
            if settings.kind == .squares{control("المسافة بالبكسل",binding(\.spacing),1...512,1).accessibilityIdentifier("grid-spacing")}
            control("الشفافية",binding(\.opacity),0.05...1,0.05)
            control("سماكة الدليل",binding(\.width),0.5...3,0.25)
            HStack(spacing:14){Text("لون الشبكة").font(.system(size:13));Spacer();ForEach(["FFFFFF","000000","D4AF37"],id:\.self){value in Button{var changed=settings;changed.color=value;data=changed.data}label:{Circle().fill(Color(uiColor:UIColor(hex:value))).frame(width:30,height:30).overlay(Circle().stroke(settings.color==value ? Palette.gold:Palette.secondary,lineWidth:settings.color==value ? 2:1))}.accessibilityLabel(value=="FFFFFF" ? "شبكة بيضاء":value=="000000" ? "شبكة سوداء":"شبكة ذهبية")}}
        }
        Text("تخف كثافة الخطوط عند التصغير لتبقى اللوحة سلسة. الشبكة دليل تحرير فقط؛ لا تظهر في الصور المصدرة.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(5)
        Button{data=CanvasGridSettings().data}label:{Label("إعادة إعدادات الشبكة",systemImage:"arrow.counterclockwise")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("grid-reset")
    }.padding(20).frame(maxWidth:600).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("الشبكة").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"checkmark",title:"تم"){dismiss()}.accessibilityIdentifier("grid-close")}}}.cookiesInterface()}
    private func control(_ title:String,_ value:Binding<Double>,_ range:ClosedRange<Double>,_ step:Double)->some View{VStack(spacing:10){HStack{Text(title).font(.system(size:13));Spacer();Text(value.wrappedValue,format:.number.precision(.fractionLength(0...2))).font(.system(size:12,design:.monospaced)).foregroundStyle(Palette.secondary)};StepSlider(value:value,in:range,step:step)}}
}
