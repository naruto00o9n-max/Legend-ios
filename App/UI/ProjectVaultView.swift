import SwiftUI

struct ProjectVaultView:View {
    @ObservedObject var vault:ProjectVaultStore
    @EnvironmentObject private var library:LibraryStore
    @EnvironmentObject private var service:ReferenceService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("storage-projects-server") private var server=false
    @State private var account=false
    @State private var deleting:VaultProject?
    private var pages:[(UUID,String)] {
        library.items.filter{!$0.folder}.flatMap{item in item.pages.enumerated().map{($0.element,item.pages.count==1 ? item.title:"\(item.title) · \($0.offset+1)")}}
    }
    private func bytes(_ value:Int64)->String{ByteCountFormatter.string(fromByteCount:value,countStyle:.file)}
    var body:some View {
        NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:22){
            SurfaceHeader(title:"مساحة لمشاريعك",subtitle:"اختر أين تحفظ عملك، مع بقاء أدوات التحرير على جهازك",icon:"externaldrive.badge.icloud")
            if service.session==nil {
                GlassSection("حسابك يحفظ ملكيتك",icon:"person.crop.circle.badge.checkmark"){Text("سجّل الدخول لتجد مشاريعك على أجهزتك. يستمر التحرير المعتاد على الجهاز دون تسجيل.").font(.subheadline).foregroundStyle(Palette.secondary);Button("تسجيل الدخول"){account=true}.buttonStyle(GoldButtonStyle())}
            }else{
                GlassSection("مكان حفظ المشاريع",icon:"folder.badge.gearshape"){
                    Toggle(isOn:$server){VStack(alignment:.leading,spacing:6){Text("الحفظ في الخادم");Text("عند إغلاق المشروع: يرفع، ثم يتحقق منه، ثم يخلي الصور من الجهاز. عند فتحه: ينزّل المشروع المفتوح فقط.").font(.caption).foregroundStyle(Palette.secondary)}}.tint(Palette.gold).accessibilityIdentifier("vault-server-mode")
                    Text("إيقاف الخيار يجعل المشاريع الجديدة على الجهاز. المشاريع المرتبطة بالخادم تستمر بالمزامنة حتى تختار «إبقاء على الجهاز» لها. إذا انقطع الاتصال أو امتلأت المساحة، تبقى النسخة على جهازك.").font(.caption).foregroundStyle(Palette.quiet)
                }
                if let listing=vault.listing {
                    GlassSection("مساحتك في الخدمة",icon:"chart.bar"){
                        HStack{Text(bytes(listing.used));Spacer();Text("من "+bytes(listing.limit)).foregroundStyle(Palette.secondary)}.font(.subheadline)
                        ProgressView(value:min(1,Double(listing.used)/Double(max(1,listing.limit)))).tint(Palette.gold)
                        Text("تشمل المساحة نسخ النقل المؤقتة حتى تنظيفها. الخدمة مشتركة بحد إجمالي مجاني 1 غيغابايت؛ يُرفض الرفع بأمان عند امتلائه.").font(.caption).foregroundStyle(Palette.quiet)
                    }
                    if !listing.projects.isEmpty {
                        SectionHeading(title:"محفوظة في حسابك",detail:"\(listing.projects.count) مشاريع")
                        ForEach(listing.projects){project in remoteRow(project)}
                    }
                }
                SectionHeading(title:"مشاريع هذا الجهاز",detail:"انقل مشروعًا موجودًا أو أبقه متاحًا دون اتصال")
                if pages.isEmpty{WorkspaceEmpty(title:"لم تضف مشروعًا بعد",detail:"استورد صورة من المعرض لتبدأ.",icon:"photo.badge.plus")}
                ForEach(pages,id:\.0){id,title in localRow(id,title:title)}
            }
            GlassSection("ما الذي يُحفظ؟",icon:"checkmark.shield"){
                Text("الصورة الأصلية، الطبقات القابلة للتحرير، أصولها والخطوط المستوردة المستخدمة في المشروع. لا تُرفع نسخ البكسلات الكبيرة القابلة لإعادة البناء.").font(.subheadline).foregroundStyle(Palette.secondary)
                Text("مكتبات الأنماط والتايبر والخطوط غير المستخدمة والإعدادات العامة تُحفظ في النسخ الاحتياطي من إدارة البيانات. يلزم تنزيل المشروع قبل تصديره أو إدراجه في نسخة احتياطية كاملة. الصور النقطية المفتوحة وملفات النقل المؤقتة تحتاج مساحة على جهازك أثناء العمل.").font(.caption).foregroundStyle(Palette.quiet)
            }
        }.padding(22).frame(maxWidth:800).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("حفظ المشاريع").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}};ToolbarItem(placement:.topBarTrailing){Button{Task{await vault.refresh()}}label:{Image(systemName:"arrow.clockwise")}.accessibilityLabel("تحديث المشاريع").disabled(vault.busy || service.session==nil)}}
            .safeAreaInset(edge:.bottom){if vault.busy{VStack(spacing:8){HStack{ProgressView().tint(.white);Text(vault.activity).font(.subheadline);Spacer();Text(vault.progress,format:.percent.precision(.fractionLength(0))).font(.caption)};ProgressView(value:vault.progress).tint(Palette.gold)}.padding(18).glass(22).padding(12)}}
            .fullScreenCover(isPresented:$account){AccountView()}
            .task(id:service.session?.user.id){vault.service=service;if service.session != nil{await vault.refresh()}}
            .vaultRemovalConfirmation(project:$deleting){project in Task{await vault.removeRemote(project)}}
            .cookiesAlert("حفظ المشاريع",isPresented:Binding(get:{vault.error != nil},set:{if !$0{vault.error=nil}})){Button("حسنًا"){vault.error=nil}}message:{Text(vault.error ?? "")}
        }.cookiesInterface()
    }
    private func remoteRow(_ project:VaultProject)->some View {
        HStack(spacing:14){Image(systemName:"checkmark.icloud").font(.title2).foregroundStyle(Palette.gold);VStack(alignment:.leading,spacing:6){Text(project.head.title).font(.subheadline);Text(bytes(Int64(project.head.bytes))+" · نسخة \(project.generation)").font(.caption).foregroundStyle(Palette.secondary)};Spacer();if !library.items.contains(where:{$0.pages.contains(project.id)}){Button("تنزيل"){Task{do{try await vault.download(project,installInLibrary:true)}catch{vault.error=error.localizedDescription}}}.buttonStyle(CapsuleActionStyle()).disabled(vault.busy)};Button{deleting=project}label:{Image(systemName:"trash")}.accessibilityLabel("حذف نسخة الخادم").accessibilityIdentifier("vault-delete-"+project.id.uuidString).disabled(vault.busy)}.padding(18).glass(22)
    }
    private func localRow(_ id:UUID,title:String)->some View {
        let receipt=vault.receipt(id)
        return VStack(alignment:.leading,spacing:14){HStack{Image(systemName:receipt?.resident==false ? "icloud.and.arrow.down":"photo.on.rectangle");Text(title).font(.subheadline);Spacer()};Text(receipt?.resident==false ? "الصور في الخادم؛ تُنزّل عند الفتح":receipt==nil ? "محفوظ على الجهاز":receipt?.managed==false ? "متاح على الجهاز دون إخلاء تلقائي":"على الجهاز؛ سيرفع ويخلى بعد الإغلاق").font(.caption).foregroundStyle(Palette.secondary)
            HStack(spacing:12){if receipt?.resident != false{Button("رفع وإخلاء المساحة"){Task{await vault.store(id,evict:true)}}.buttonStyle(CapsuleActionStyle())};if receipt != nil{Button("إبقاء على الجهاز"){Task{await vault.keepOnDevice(id)}}.buttonStyle(CapsuleActionStyle())}}.disabled(vault.busy)
        }.padding(18).glass(22)
    }
}

/// Shared by the real account screen and the isolated DEBUG presentation check.
/// Taking the selected item here keeps the exact target valid until confirmation.
struct VaultRemovalConfirmation:ViewModifier {
    @Binding var project:VaultProject?
    let remove:(VaultProject)->Void
    func body(content:Content)->some View {
        content.cookiesConfirmationDialog("حذف نسخة الخادم؟",isPresented:Binding(get:{project != nil},set:{if !$0{project=nil}})){
            Button("إبقاء نسخة الجهاز وحذف نسخة الخادم",role:.destructive){if let target=project{remove(target)}}
                .accessibilityIdentifier("vault-confirm-delete")
            Button("إلغاء",role:.cancel){}
        }message:{
            Text("المشروع: \(project?.head.title ?? "")\n\nتبقى نسخة المشروع على جهازك. إذا كانت الصور محفوظة في الخادم فقط، سينزّلها التطبيق ويتحقق منها أولًا لحماية عملك، ثم يحذف نسخة الخادم. عند فشل التنزيل لن تُحذف نسخة الخادم.\n\nقد تبقى النسخة المحذوفة ضمن المساحة لفترة التنظيف القصيرة.")
        }
    }
}
extension View {
    func vaultRemovalConfirmation(project:Binding<VaultProject?>,remove:@escaping (VaultProject)->Void)->some View {
        modifier(VaultRemovalConfirmation(project:project,remove:remove))
    }
}
