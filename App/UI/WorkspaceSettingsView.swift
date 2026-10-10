import SwiftUI

struct WorkspaceSettingsView:View {
    @Environment(\.dismiss) var dismiss
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
    var body:some View{NavigationStack{Form{
        Section("مقاسات مساحة العمل"){
            scale("كثافة لوحات الأدوات",$density,0.85...1.15);scale("الأيقونات",$icons,0.8...1.2);scale("شريط الأدوات",$toolbar,0.85...1.15);scale("تسميات الأدوات",$labels,0.85...1.3);scale("مقابض النص",$handles,0.8...1.5)
            HStack{Image(systemName:"textformat").font(.system(size:20*icons));Text("إضافة نص").font(.system(size:10*labels))}.frame(height:60*toolbar)
        }
        Section("التحرير السريع"){Toggle("اقتراح إضافة نص عند لمس مساحة فارغة",isOn:$tapText).accessibilityIdentifier("setting-tap-text");Text("يعرض اللمس سؤالًا؛ لا يُضاف النص إلا بعد تأكيده. الضغط المطول على الصورة يلتقط لونها.").font(.system(size:12));Toggle("إضافة النص في منطقة العمل الحالية",isOn:$smartPosition);scale("حساسية المقابض",$handleSpeed,0.25...2);scale("حجم إدراج التايبر",$typerScale,0.5...2);Picker("النقر المزدوج على النص",selection:$doubleTap){Text("تحرير النص").tag("edit");Text("فتح التايبر").tag("typer");Text("بلا إجراء").tag("none")}}
        Section("المحاذاة والقارئ") {Toggle("التقاط إلى المركز وحواف الصورة",isOn:$snap);Picker("اتجاه انتقال الصفحات",selection:$direction){Text("من اليمين إلى اليسار").tag("rtl");Text("من اليسار إلى اليمين").tag("ltr")}}
        Section("المعاينة"){Picker("جودة معاينة اللوحة",selection:$quality){Text("اقتصادية").tag(0.5);Text("متوازنة").tag(1.0);Text("دقيقة").tag(2.0)};Text("هذا الإعداد يغيّر تفاصيل المعاينة واستهلاك الذاكرة فقط. التصدير يستخدم أبعاد الصورة الأصلية.").font(.system(size:12)).foregroundStyle(Palette.quiet)}
        Section("التنظيف الذكي"){scale("نصف قطر إعادة البناء",$cleaner,1...12)}
        Section("الحركة والاستجابة"){Toggle("استجابة اللمس",isOn:$haptics);Toggle("تقليل الحركة",isOn:$reduced);Text("يُحترم إعداد تقليل الحركة في iPadOS أيضًا.").font(.system(size:12))}
        Button("استعادة الإعدادات الافتراضية"){density=1;icons=1;toolbar=1;labels=1;handles=1;handleSpeed=1;typerScale=1;doubleTap="edit";quality=1;smartPosition=true;tapText=false;snap=false;haptics=true;reduced=false;cleaner=3;direction="rtl"}
    }.accessibilityIdentifier("workspace-settings-form").navigationTitle("مساحة العمل").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.accessibilityIdentifier("workspace-settings-close")}}}.cookiesInterface()}
    private func scale(_ name:String,_ binding:Binding<Double>,_ range:ClosedRange<Double>)->some View{VStack{HStack{Text(name);Spacer();Text(binding.wrappedValue,format:.number.precision(.fractionLength(1)))};Slider(value:binding,in:range)}}
}
