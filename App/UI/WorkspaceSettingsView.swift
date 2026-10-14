import SwiftUI

enum WorkspaceSettingsCategory:String,CaseIterable,Identifiable {
    case editing,appearance,quality,reading
    var id:String{rawValue}
    var title:String{switch self{case .editing:"التحرير";case .appearance:"المظهر";case .quality:"المعاينة";case .reading:"القراءة"}}
    var icon:String{switch self{case .editing:"slider.horizontal.3";case .appearance:"sparkles";case .quality:"viewfinder";case .reading:"book"}}
}
struct WorkspaceSettingsView:View {
    @Environment(\.dismiss) var dismiss
    var initialCategory=WorkspaceSettingsCategory.editing
    @State private var grid=false
    @State private var category=WorkspaceSettingsCategory.editing
    @AppStorage("editor-panel-density") private var density=1.0
    @AppStorage("editor-icon-scale") private var icons=1.0
    @AppStorage("editor-toolbar-scale") private var toolbar=1.0
    @AppStorage("editor-label-scale") private var labels=1.0
    @AppStorage("editor-handle-speed") private var handleSpeed=1.0
    @AppStorage("typer-insert-scale") private var typerScale=1.0
    @AppStorage("editor-double-tap") private var doubleTap="edit"
    @AppStorage("editor-handle-scale") private var handles=1.0
    @AppStorage("editor-preview-quality") private var quality=1.0
    @AppStorage("editor-tap-add-text") private var tapText=false
    @AppStorage("editor-smart-position") private var smartPosition=true
    @AppStorage("editor-snap") private var snap=false
    @AppStorage("editor-haptics") private var haptics=true
    @AppStorage("editor-reduce-motion") private var reduced=false
    @AppStorage("editor-clean-radius") private var cleaner=3.0
    @AppStorage("reader-direction") private var direction="rtl"
    var body:some View{NavigationStack{ZStack{Ambient();VStack(spacing:0){
        ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){ForEach(WorkspaceSettingsCategory.allCases){item in Button{category=item}label:{Label(item.title,systemImage:item.icon)}.buttonStyle(CapsuleActionStyle(selected:category==item)).accessibilityIdentifier("workspace-category-"+item.rawValue)}}.padding(.horizontal,20).padding(.vertical,12)}
        ScrollView{VStack(alignment:.leading,spacing:18){SurfaceHeader(title:category.title,subtitle:subtitle,icon:category.icon);content;Button{restore()}label:{Label("استعادة إعدادات مساحة العمل",systemImage:"arrow.counterclockwise")}.buttonStyle(GoldButtonStyle()).padding(.top,4);Text("تُحفظ التغييرات تلقائيًا. لا يؤثر هذا الزر في مشاريعك أو خطوطك أو أنماطك.").font(.system(size:11)).foregroundStyle(Palette.quiet).lineSpacing(4)}.padding(20).frame(maxWidth:720).frame(maxWidth:.infinity)}.accessibilityIdentifier("workspace-settings-form")
    }}.foregroundStyle(Palette.pale).navigationTitle("مساحة العمل").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.accessibilityIdentifier("workspace-settings-close")}}}.cookiesInterface().sheet(isPresented:$grid){CanvasGridSettingsView()}
    .onAppear{category=initialCategory}}
    private var subtitle:String{switch category{case .editing:"اضبط التفاعل ليوافق طريقة عملك";case .appearance:"زجاج داكن، تفاصيل واضحة، ولمسة ذهبية";case .quality:"وازن تفاصيل العرض مع استهلاك الذاكرة";case .reading:"تابع صفحات الفصل بالطريقة التي تناسبك"}}
    @ViewBuilder private var content:some View{
        switch category{
        case .editing:
            GlassSection("إضافة النص",icon:"text.bubble",subtitle:"أنت من يقرر متى تُضاف فقاعة جديدة"){
                SettingToggle(title:"اقتراح إضافة نص عند لمس مساحة فارغة",detail:"يظهر سؤال «نضيف نص؟»؛ لا يُنشأ النص إلا بعد تأكيدك.",value:$tapText,id:"setting-tap-text")
                SettingToggle(title:"إضافة النص في منطقة العمل الحالية",detail:"يظهر النص بالقرب من موضع العمل بدل أعلى الصورة.",value:$smartPosition)
                scale("حجم إدراج التايبر",$typerScale,0.5...2)
                Picker("النقر المزدوج على النص",selection:$doubleTap){Text("تحرير النص").tag("edit");Text("فتح التايبر").tag("typer");Text("بلا إجراء").tag("none")}.pickerStyle(.menu)
            }
            GlassSection("شبكة اللوحة",icon:"grid"){NavigationRow(title:"الشبكة وإعداداتها",subtitle:"التقسيم، المسافة، اللون، والشفافية",icon:"grid"){grid=true}.accessibilityIdentifier("settings-grid")}
            GlassSection("الحركة والمقابض",icon:"hand.draw"){scale("حساسية المقابض",$handleSpeed,0.25...2);scale("حجم مقابض النص",$handles,0.8...1.5);SettingToggle(title:"التقاط إلى المركز وحواف الصورة",detail:"يساعد على المحاذاة أثناء التحريك والتدوير.",value:$snap);SettingToggle(title:"استجابة اللمس",value:$haptics)}
            GlassSection("التنظيف والقطارة",icon:"eyedropper"){scale("نصف قطر إعادة البناء",$cleaner,1...12);Text("اضغط مطولًا على الصورة لالتقاط لون. تظهر دائرة فوق إصبعك وتعرض اللون أثناء تحريكه؛ يُعتمد اللون عند رفع الإصبع.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)}
        case .appearance:
            GlassSection("مقاسات الواجهة",icon:"rectangle.3.group",subtitle:"معاينة فورية مع حدود مقاسات آمنة"){scale("كثافة لوحات الأدوات",$density,0.85...1.15);scale("الأيقونات",$icons,0.8...1.2);scale("شريط الأدوات",$toolbar,0.85...1.15);scale("تسميات الأدوات",$labels,0.85...1.3);HStack(spacing:12){SurfaceSymbol(icon:"textformat",size:42*icons);Text("إضافة نص").font(.system(size:12*labels));Spacer();QuietBadge(text:"معاينة")}.padding(12).frame(minHeight:56*toolbar).glass(16)}
            GlassSection("المؤثرات والانتقالات",icon:"sparkles"){SettingToggle(title:"تقليل الحركة",detail:"انتقالات هادئة. يُحترم إعداد تقليل الحركة في النظام أيضًا.",value:$reduced);Text("النصوص والأيقونات بيضاء على خلفية داكنة، مع ذهبي لتحديد الإجراءات والتركيز.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)}
        case .quality:
            GlassSection("جودة معاينة اللوحة",icon:"viewfinder"){Picker("جودة العرض",selection:$quality){Text("اقتصادية").tag(0.5);Text("متوازنة").tag(1.0);Text("دقيقة").tag(2.0)}.pickerStyle(.segmented);Text("يتغيّر مقدار تفاصيل المعاينة واستهلاك الذاكرة فقط. يبقى التصدير بأبعاد الصورة الأصلية، وتُرسم النصوص عند التصدير من بياناتها.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(5)}
        case .reading:
            GlassSection("اتجاه الصفحات",icon:"book"){Picker("انتقال الصفحات",selection:$direction){Text("من اليمين إلى اليسار").tag("rtl");Text("من اليسار إلى اليمين").tag("ltr")}.pickerStyle(.menu);Text("يتذكر القارئ الصفحة وموضع القراءة عند العودة إلى الفصل.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)}
        }
    }
    private func scale(_ name:String,_ binding:Binding<Double>,_ range:ClosedRange<Double>)->some View{VStack(spacing:10){HStack{Text(name).font(.system(size:13));Spacer();Text(binding.wrappedValue,format:.number.precision(.fractionLength(2))).font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.secondary)};StepSlider(value:binding,in:range)}}
    private func restore(){density=1;icons=1;toolbar=1;labels=1;handles=1;handleSpeed=1;typerScale=1;doubleTap="edit";quality=1;smartPosition=true;tapText=false;snap=false;haptics=true;reduced=false;cleaner=3;direction="rtl"}
}
