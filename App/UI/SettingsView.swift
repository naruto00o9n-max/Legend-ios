import SwiftUI

struct SettingsView:View {
    @EnvironmentObject private var service:ReferenceService
    @Environment(\.dismiss) private var dismiss
    @State private var account=false
    @State private var profile=false
    @State private var hub=false
    @State private var fonts=false
    @State private var typerSettings=false
    @State private var typerLibrary=false
    @State private var workspaceSettings=false
    @State private var diagnostics=false
    @State private var storage=false
    @State private var trash=false
    @State private var guide=false
    @State private var category=WorkspaceSettingsCategory.editing
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:20){
        SurfaceHeader(title:"على طريقتك",subtitle:"إعدادات واضحة، ومساحة عمل تناسبك",icon:"slider.horizontal.3")
        if NetworkPolicy.enabled{Button{if service.session==nil{account=true}else{profile=true}}label:{HStack(spacing:14){SurfaceSymbol(icon:"person.crop.circle",size:54);VStack(alignment:.leading,spacing:6){Text(service.session==nil ? "تسجيل الدخول":"حسابك في كوكيز").font(.system(size:17,weight:.semibold));Text(service.session?.user.email ?? "ملفك الشخصي والخدمات المتصلة").font(.system(size:12)).foregroundStyle(Palette.secondary).lineLimit(1)};Spacer(minLength:4);Image(systemName:"chevron.left").font(.system(size:11)).foregroundStyle(Palette.quiet)}.padding(20).glass(24)}.buttonStyle(.plain).accessibilityIdentifier("settings-account")}
        GlassSection("المظهر والتحرير",icon:"sparkles",subtitle:"مقاسات الواجهة وسلوك أدواتك"){
            NavigationRow(title:"المظهر والمؤثرات",subtitle:"المقاسات، الحركة، ومعاينة الواجهة",icon:"sparkles"){category = .appearance;workspaceSettings=true}.accessibilityIdentifier("settings-appearance")
            NavigationRow(title:"مساحة العمل",subtitle:"إضافة النص، المقابض، المحاذاة، والقطارة",icon:"slider.horizontal.3"){category = .editing;workspaceSettings=true}.accessibilityIdentifier("settings-workspace")
            NavigationRow(title:"جودة العرض والقراءة",subtitle:"المعاينة واستهلاك الذاكرة واتجاه الصفحات",icon:"viewfinder"){category = .quality;workspaceSettings=true}.accessibilityIdentifier("settings-quality")
        }
        GlassSection("النصوص والمكتبات",icon:"text.bubble",subtitle:"فصولك وخطوطك ووسومك"){
            NavigationRow(title:"فصول التايبر",subtitle:"نصوص الفصول والمسودات وتقدّم الإدراج",icon:"text.bubble"){typerLibrary=true}.accessibilityIdentifier("settings-typer-library")
            NavigationRow(title:"الوسوم وألوان التايبر",subtitle:"لون مستقل لكل وسم، وخطوط وأنماط الإدراج",icon:"tag"){typerSettings=true}.accessibilityIdentifier("settings-typer")
            NavigationRow(title:"مكتبة الخطوط",subtitle:"الخطوط المستوردة والمفضلة والمجموعات",icon:"textformat.alt"){fonts=true}.accessibilityIdentifier("settings-font-library")
        }
        GlassSection("البيانات والصيانة",icon:"externaldrive",subtitle:"تحكّم في المساحة، واحمِ عملك"){
            NavigationRow(title:"سلة المحذوفات",subtitle:"استعادة المشاريع والفصول أو حذف ملفاتها نهائيًا",icon:"trash"){trash=true}.accessibilityIdentifier("settings-trash")
            NavigationRow(title:"المساحة والنسخ الاحتياطي",subtitle:"قياس البيانات، نسخة انتقائية، واستعادة وحذف",icon:"externaldrive"){storage=true}.accessibilityIdentifier("settings-storage")
            NavigationRow(title:"تقارير الأعطال والأداء",subtitle:"مراجعة التقارير ومشاركتها عند الحاجة",icon:"doc.text.magnifyingglass"){diagnostics=true}.accessibilityIdentifier("settings-diagnostics")
        }
        if NetworkPolicy.enabled{GlassSection("الحساب والخدمات",icon:"person.crop.circle"){
            NavigationRow(title:"الحساب والخدمات",subtitle:"الملف الشخصي، الترتيب، وربط Discord",icon:"square.grid.2x2"){profile=true}.accessibilityIdentifier("settings-account-workspace")
            NavigationRow(title:"المجتمع",subtitle:"الأعمال والمنشورات والنقاشات",icon:"person.2"){hub=true}.accessibilityIdentifier("settings-community")
            NavigationRow(title:service.session==nil ? "تسجيل الدخول":"الملف الشخصي",icon:"person.crop.circle"){if service.session==nil{account=true}else{profile=true}}
        }}
        GlassSection("تعلّم كوكيز",icon:"book.closed"){
            NavigationRow(title:"دليل التطبيق",subtitle:"شرح مفصل للأدوات والواجهات وخطوات العمل",icon:"book.closed"){guide=true}.accessibilityIdentifier("settings-guide")
        }
        HStack{Brand();Spacer();Text("\(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.0") · iPhone / iPad").font(.system(size:10)).foregroundStyle(Palette.quiet)}.padding(.vertical,10)
    }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("الإعدادات").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"إغلاق"){dismiss()}.accessibilityIdentifier("settings-close")}}
    .fullScreenCover(isPresented:$account){if NetworkPolicy.enabled{AccountView()}}
    .fullScreenCover(isPresented:$profile){if NetworkPolicy.enabled{ProfileView()}}
    .fullScreenCover(isPresented:$hub){if NetworkPolicy.enabled{ServiceHub()}}
    .sheet(isPresented:$fonts){FontLibraryView()}
    .sheet(isPresented:$workspaceSettings){WorkspaceSettingsView(initialCategory:category)}
    .sheet(isPresented:$storage){StorageManagementView()}
    .fullScreenCover(isPresented:$trash){LibraryTrashView()}
    .sheet(isPresented:$diagnostics){DiagnosticReportsView()}
    .sheet(isPresented:$guide){AppGuideView()}
    .fullScreenCover(isPresented:$typerLibrary){TyperLibraryView()}
    .sheet(isPresented:$typerSettings){TyperSettingsView()}}.cookiesInterface()}
}
