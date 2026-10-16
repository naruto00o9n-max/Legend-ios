import SwiftUI

struct LibraryTrashView:View {
    @EnvironmentObject private var library:LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected=Set<UUID>()
    @State private var deletion=Set<UUID>()
    @State private var confirm=false
    @State private var failure:String?
    @State private var bytes:Int64=0
    @State private var usageToken=UUID()
    private var roots:[LibraryItem]{library.trashRoots}
    private var recoverable:Set<UUID>{Set(roots.filter{$0.purgePending != true}.map(\.id))}
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:20){
        SurfaceHeader(title:"سلة المحذوفات",subtitle:"استعد مشروعك، أو أفرغ مساحته عندما تنتهي منه",icon:"trash")
        overview
        controls
        LazyVStack(spacing:12){ForEach(roots){item in row(item)}}
    }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("المحذوفات").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}.accessibilityIdentifier("trash-close")}}
    .disabled(library.purgingTrash)
    .cookiesAlert("حذف نهائي؟",isPresented:$confirm){Button("حذف \(deletion.count) عناصر نهائيًا",role:.destructive){let ids=deletion;Task{do{try await library.purgeTrash(ids);selected.subtract(ids);await measure()}catch{failure=error.localizedDescription}}}.accessibilityIdentifier("trash-confirm-purge");Button("إلغاء",role:.cancel){deletion=[]}}message:{Text("ستُحذف الصور والتعديلات التابعة لهذه العناصر من الجهاز. لن يمكن استعادتها من السلة.")}
    .cookiesAlert("تعذر إكمال العملية",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}
    .task{await library.resumeTrashPurge();if let error=library.error{failure=error;library.error=nil};await measure()}
    .onChange(of:library.trashedItems){_,_ in selected.formIntersection(Set(roots.map(\.id)));Task{await measure()}}
    }.cookiesInterface()}
    private var overview:some View{VStack(alignment:.leading,spacing:16){HStack{QuietBadge(text:"\(roots.count) عناصر",icon:"rectangle.stack");Spacer();Text(ByteCountFormatter.string(fromByteCount:bytes,countStyle:.file)).font(.system(size:15,weight:.semibold,design:.rounded))}.padding(20).glass(22)
        Text("المساحة المعروضة قابلة للتحرير بإفراغ السلة. تبقى الصفحات المشتركة مع أعمال المعرض محفوظة، ويمكن تضمين السلة في النسخ الاحتياطي.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(5)
        if library.purgingTrash{HStack(spacing:12){ProgressView().tint(Palette.gold);Text("إفراغ الملفات…").font(.system(size:13))}.padding(18).glass(18)}
        if roots.isEmpty{WorkspaceEmpty(title:"السلة فارغة",detail:"المشاريع والمجلدات التي تحذفها ستظهر هنا.",icon:"trash")}}}
    @ViewBuilder private var controls:some View{if !roots.isEmpty{HStack(spacing:12){Button(selected.isEmpty ? "تحديد الكل":"إلغاء التحديد"){selected=selected.isEmpty ? Set(roots.map(\.id)):[]}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("trash-select-all");Spacer();Menu{Button("استعادة الكل"){restore(recoverable)};Button("إفراغ السلة",role:.destructive){askDelete(Set(roots.map(\.id)))}}label:{Image(systemName:"ellipsis.circle").frame(width:44,height:44)}.accessibilityIdentifier("trash-options")}
            if !selected.isEmpty{HStack(spacing:12){Button{restore(selected.intersection(recoverable))}label:{Label("استعادة المحدد",systemImage:"arrow.uturn.backward")}.buttonStyle(CapsuleActionStyle()).disabled(selected.intersection(recoverable).isEmpty);Button{askDelete(selected)}label:{Label("حذف نهائي",systemImage:"trash")}.buttonStyle(CapsuleActionStyle())}.accessibilityIdentifier("trash-selection-actions")}
        }}
    private func row(_ item:LibraryItem)->some View{VStack(alignment:.leading,spacing:14){HStack(spacing:14){Button{if !selected.insert(item.id).inserted{selected.remove(item.id)}}label:{Image(systemName:selected.contains(item.id) ? "checkmark.circle.fill":"circle").font(.system(size:22)).foregroundStyle(selected.contains(item.id) ? Palette.gold:Palette.secondary)}.accessibilityLabel("تحديد "+item.title);Image(systemName:item.folder ? "folder":item.isChapter==true ? "rectangle.stack":"photo").font(.system(size:24,weight:.light)).frame(width:44,height:44).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:12));VStack(alignment:.leading,spacing:6){Text(item.title).font(.system(size:16,weight:.semibold)).lineLimit(2);if let date=item.deletedAt{Text(date,format:.dateTime.day().month().year()).font(.system(size:11)).foregroundStyle(Palette.secondary)};if item.purgePending==true{Text("حذف نهائي غير مكتمل").font(.system(size:11)).foregroundStyle(Palette.secondary)};let pages=Set(library.trashMembers(item.id).flatMap(\.pages)).count;Text("\(pages) صفحات").font(.system(size:11)).foregroundStyle(Palette.quiet)};Spacer(minLength:0)}
        HStack(spacing:12){Button{restore([item.id])}label:{Label("استعادة",systemImage:"arrow.uturn.backward")}.buttonStyle(CapsuleActionStyle()).disabled(item.purgePending==true).accessibilityIdentifier("trash-restore-\(item.id)");Button{askDelete([item.id])}label:{Label(item.purgePending==true ? "إكمال الحذف":"حذف نهائي",systemImage:"trash")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("trash-purge-\(item.id)")}
    }.padding(18).glass(23).accessibilityElement(children:.contain).accessibilityIdentifier("trash-item-\(item.id)")}
    private func restore(_ ids:Set<UUID>){do{try library.restoreTrash(ids);selected.subtract(ids);Task{await measure()}}catch{failure=error.localizedDescription}}
    private func askDelete(_ ids:Set<UUID>){deletion=ids;confirm = !ids.isEmpty}
    private func measure()async{let token=UUID();usageToken=token;let retained=Set(library.items.flatMap(\.pages)),paths=Set(library.trashedItems.flatMap(\.pages)).subtracting(retained).map{library.directory($0)};let result=(try? await BackgroundWork.run{paths.reduce(Int64(0)){$0+AppStorageManager.size($1)}}) ?? 0;if usageToken==token{bytes=result}}
}
