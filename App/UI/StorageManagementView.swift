import SwiftUI
import UniformTypeIdentifiers
import CoreText

struct StorageManagementView:View {
    @EnvironmentObject private var service:ReferenceService
    @Environment(\.dismiss) private var dismiss
    @State private var usage=StorageUsage()
    @State private var choices:[BackupUnit]=[]
    @State private var selection=Set<String>()
    @State private var busy=false
    @State private var importing=false
    @State private var archive:URL?
    @State private var restoreFile:URL?
    @State private var message:String?
    @State private var confirmation=""
    @State private var confirming=false
    private func bytes(_ size:Int64)->String{ByteCountFormatter.string(fromByteCount:size,countStyle:.file)}
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:20){
        VStack(alignment:.leading,spacing:14){Text("مساحة بيانات التطبيق").font(.headline);Text(bytes(usage.total)).font(.system(size:38,weight:.light,design:.rounded)).accessibilityIdentifier("storage-total");amount("المشاريع والبيانات",usage.documents);amount("الملفات المؤقتة",usage.temporary+usage.cache);amount("نسخ بكسلات قابلة لإعادة البناء",usage.rebuildable);Divider();amount("المتاح على الجهاز",usage.available)}.padding(22).glass(22)
        Text("لا تشمل هذه الأرقام حجم التطبيق المثبّت. تنظيف نسخ البكسلات لا يمس الصورة الأصلية أو الطبقات؛ تُجهّز مجددًا عند فتح المشروع.").font(.footnote).foregroundStyle(Palette.quiet)
        Button{confirmation="cache";confirming=true}label:{Label("تنظيف الملفات المؤقتة",systemImage:"sparkles")}.accessibilityIdentifier("storage-clear-cache").buttonStyle(.bordered)
        VStack(alignment:.leading,spacing:14){HStack{Text(restoreFile==nil ? "نسخ احتياطي انتقائي":"اختر ما تريد استعادته").font(.headline);Spacer();Button(selection.count==choices.count ? "إلغاء الكل":"تحديد الكل"){selection=selection.count==choices.count ? []:Set(choices.map(\.id))}.font(.caption)}
            Text("اختر المشاريع والخطوط بشكل منفرد، أو مجموعات الأنماط والتايبر والإعدادات. النسخة تشمل أصولها وخاماتها؛ لا تشمل كلمات المرور أو جلسة الدخول.").font(.footnote).foregroundStyle(Palette.quiet)
            ForEach(Array(Set(choices.map(\.group))).sorted(),id:\.self){group in DisclosureGroup(group){ForEach(choices.filter{$0.group==group}){unit in Toggle(unit.title,isOn:Binding(get:{selection.contains(unit.id)},set:{value in if value{selection.insert(unit.id)}else{selection.remove(unit.id)}})).font(.system(size:13)).tint(Palette.gold)}}}
            if restoreFile != nil{Text("البيانات المحددة تستبدل نظيرتها فقط. المشاريع الأخرى تبقى؛ الفصول تُدمج بحسب هويتها. احفظ نسخة من بياناتك الحالية قبل الاستعادة.").font(.footnote).foregroundStyle(Palette.quiet);Button("استعادة المحدد"){confirmation="restore";confirming=true}.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("storage-restore-selected");Button("إلغاء الاستعادة"){restoreFile=nil;refresh()}}
            else{Button("إنشاء النسخة المحددة"){backup()}.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("storage-backup-selected");Button{importing=true}label:{Label("فتح نسخة للاستعادة",systemImage:"arrow.down.doc")}.buttonStyle(.bordered)}
            if let archive{ShareLink(item:archive){Label("حفظ النسخة خارج التطبيق",systemImage:"square.and.arrow.up")}.buttonStyle(.bordered);Text("احفظها في iCloud Drive أو وحدة خارجية قبل حذف البيانات. ملف النسخة داخل التطبيق مؤقت حتى تحفظه.").font(.footnote).foregroundStyle(Palette.quiet)}
        }.padding(22).glass(22)
        Button(role:.destructive){confirmation="reset";confirming=true}label:{Label("حذف جميع بيانات التطبيق",systemImage:"trash")}.accessibilityIdentifier("storage-reset")
    }.padding(22).frame(maxWidth:760).frame(maxWidth:.infinity)}}.foregroundStyle(.white).navigationTitle("المساحة والنسخ الاحتياطي").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.disabled(busy)}}
        .disabled(busy).overlay{if busy{ZStack{Color.black.opacity(0.55).ignoresSafeArea();ProgressView("جارٍ معالجة بياناتك…").padding(26).glass(20)}}}
        .fileImporter(isPresented:$importing,allowedContentTypes:[UTType(filenameExtension:"cookiesbackup") ?? .data,.zip]){result in do{let url=try result.get(),access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};let copied=FileManager.default.temporaryDirectory.appendingPathComponent("Restore-\(UUID()).cookiesbackup");try FileManager.default.copyItem(at:url,to:copied);load(copied)}catch{message=error.localizedDescription}}
        .confirmationDialog(confirmation=="reset" ? "حذف كل البيانات وتسجيل الخروج؟":confirmation=="restore" ? "استبدال البيانات المحددة بالنسخة؟":"تنظيف الملفات القابلة لإعادة البناء؟",isPresented:$confirming,titleVisibility:.visible){Button(confirmation=="reset" ? "حذف جميع البيانات":confirmation=="restore" ? "استعادة المحدد":"تنظيف",role:confirmation=="reset" ? .destructive:nil){perform()};Button("إلغاء",role:.cancel){}}message:{Text(confirmation=="reset" ? "ستُحذف المشاريع والخطوط والأنماط والفصول والإعدادات والجلسة المحلية. النسخ المحفوظة خارج التطبيق وحسابك على الخادم تبقى.":"لن تتغير الصور الأصلية. سيُحذف أي ملف نسخة احتياطية مؤقت لم تحفظه خارج التطبيق.")}
        .alert("إدارة البيانات",isPresented:Binding(get:{message != nil},set:{if !$0{message=nil}})){Button("حسنًا"){message=nil}}message:{Text(message ?? "")}.task{refresh()}.cookiesInterface()}
    }
    private func amount(_ name:String,_ value:Int64)->some View{HStack{Text(name).font(.system(size:13));Spacer();Text(bytes(value)).font(.system(size:12,design:.monospaced)).foregroundStyle(Palette.quiet)}}
    private func refresh(){Task{do{let result=try await Task.detached{(AppStorageManager.usage(),try AppStorageManager.units())}.value;usage=result.0;choices=result.1;selection=Set(choices.map(\.id))}catch{message=error.localizedDescription}}}
    private func load(_ file:URL){busy=true;Task{defer{busy=false};do{let manifest=try await Task.detached{try AppStorageManager.inspect(file)}.value;restoreFile=file;choices=manifest.units;selection=Set(choices.map(\.id))}catch{try? FileManager.default.removeItem(at:file);message=error.localizedDescription}}}
    private func backup(){busy=true;let selected=selection;let settings:Data;do{settings=try AppStorageManager.settingsData()}catch{busy=false;message=error.localizedDescription;return};Task{defer{busy=false};do{archive=try await Task.detached{try AppStorageManager.createBackup(selected:selected,settings:settings)}.value;usage=AppStorageManager.usage()}catch{message=error.localizedDescription}}}
    private func perform(){busy=true;let action=confirmation,selected=selection,file=restoreFile;Task{defer{busy=false};do{
        if action=="reset"{service.discardLocalSession();try AppStorageManager.resetLocalData();ImagePipeline.clearMemoryCaches();dismiss();NotificationCenter.default.post(name:AppStorageManager.reset,object:nil)}
        else if action=="restore",let file{for font in Fonts.userFiles{CTFontManagerUnregisterFontsForURL(font as CFURL,.process,nil)};defer{Fonts.register()};let settings=try await Task.detached{try AppStorageManager.restore(file,selected:selected)}.value;if let settings{for (key,value) in settings{UserDefaults.standard.set(value,forKey:key)}};Fonts.register();ImagePipeline.clearMemoryCaches();dismiss();NotificationCenter.default.post(name:AppStorageManager.changed,object:nil)}
        else{restoreFile=nil;try await Task.detached{try AppStorageManager.cleanCaches()}.value;ImagePipeline.clearMemoryCaches();archive=nil;refresh();usage=AppStorageManager.usage();message="نُظفت الملفات المؤقتة. مشاريعك وأصولها وطبقاتها محفوظة."}
    }catch{message=error.localizedDescription}}}
}
