import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct LibraryView:View {
    @EnvironmentObject var library:LibraryStore
    var parent:UUID? = nil;var title="معرضي"
    @State private var filePicker=false;@State private var fontLibrary=false;@State private var community=false;@State private var search=""
    @State private var guide=false
    @State private var projectVault=false
    @State private var accountWorkspace=false
    @State private var trash=false
    @State private var renaming:LibraryItem?
    @State private var renameText=""
    @State private var chapterPrompt=false
    @State private var picker=false;@State private var folderPrompt=false;@State private var name="";@State private var selected:PhotosPickerItem?;@State private var importing=false;@State private var assistant=false;@State private var settings=false
    var children:[LibraryItem]{library.items.filter{$0.parent==parent && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))}.sorted{if $0.folder != $1.folder{return $0.folder};return $0.title.localizedStandardCompare($1.title) == .orderedAscending}}
    var body:some View {
        ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:22){
            HStack(spacing:12){Brand();Spacer(minLength:4);if parent==nil{Text(Date(),format:.dateTime.day().month()).font(.system(size:10)).foregroundStyle(Palette.quiet)};IconButton(icon:"slider.horizontal.3",title:"الإعدادات"){settings=true}.glass(14).accessibilityIdentifier("settings")}
            if ProcessInfo.processInfo.arguments.contains("-ui-tests"),children.isEmpty{Button("افتح فصلًا تجريبيًا"){Task{importing=true;do{let root=library.root;let p=try await BackgroundWork.run{try ImagePipeline.fixture(root:root)};library.add(p,parent:parent)}catch{library.error=error.localizedDescription};importing=false}}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("demo-project")}
            if parent==nil{HomeHero(projects:library.items.filter{!$0.folder}.count,folders:library.items.filter(\.folder).count)}else{SurfaceHeader(title:title,subtitle:"نظّم صفحات الفصل وأعماله في مكان واحد",icon:"folder")}
            ResponsiveActionGrid(items:2){ActionTile(title:"استيراد الصور",subtitle:"ابدأ من مكتبة الصور",icon:"photo.badge.plus",prominent:true){picker=true}.accessibilityIdentifier("import-image");ActionTile(title:"فتح مشروع",subtitle:"صور وملفات ومشاريع محفوظة",icon:"folder.badge.plus"){filePicker=true}.accessibilityIdentifier("import-project")}
            HStack(spacing:8){SectionHeading(title:parent==nil ? "أعمالك":title,detail:children.isEmpty ? "":"\(children.count) عناصر");IconButton(icon:"trash",title:"سلة المحذوفات"){trash=true}.accessibilityIdentifier("library-trash");IconButton(icon:"rectangle.stack.badge.plus",title:"فصل جديد"){chapterPrompt=true}.accessibilityIdentifier("new-chapter");IconButton(icon:"folder.badge.plus",title:"مجلد جديد"){folderPrompt=true}.accessibilityIdentifier("new-folder")}
            if !children.isEmpty{SearchBar(placeholder:"بحث في المشاريع والمجلدات",text:$search)}
            if children.isEmpty{WorkspaceEmpty(title:search.isEmpty ? "مساحة تنتظر حكايتك":"لا توجد نتائج",detail:search.isEmpty ? "أضف صورك، ثم اجمع العمل في مجلد وفصول. يبقى كل مشروع قابلًا للتعديل.":"جرّب اسمًا آخر للبحث.",icon:search.isEmpty ? "rectangle.stack.badge.plus":"magnifyingglass")}
            LazyVGrid(columns:[GridItem(.adaptive(minimum:158),spacing:14)],spacing:14){ForEach(children){item in if item.folder{NavigationLink{LibraryView(parent:item.id,title:item.title)}label:{card(item)}}else if item.isChapter==true{NavigationLink{ChapterGalleryView(id:item.id)}label:{card(item)}}else{NavigationLink{PageDestination(id:item.id)}label:{card(item)}}}.buttonStyle(.plain)}
            SectionHeading(title:"أدوات مساحة العمل",detail:"كل ما تحتاج إليه، قريب منك")
            ResponsiveActionGrid(items:NetworkPolicy.enabled ? 7:4){
                ActionTile(title:"التايبر",subtitle:"نصوص الفصول والوسوم والتقدّم",icon:"text.bubble"){assistant=true}.accessibilityIdentifier("assistant")
                ActionTile(title:"الخطوط",subtitle:"استيراد، مجموعات، ومفضلة",icon:"textformat.alt"){fontLibrary=true}.accessibilityIdentifier("font-library")
                if NetworkPolicy.enabled{ActionTile(title:"حفظ المشاريع",subtitle:"اختر مكان مشاريعك وحرّر مساحة جهازك",icon:"externaldrive.badge.icloud"){projectVault=true}.accessibilityIdentifier("project-vault");ActionTile(title:"الحساب والخدمات",subtitle:"ملفك، الترتيب، والربط",icon:"person.crop.circle"){accountWorkspace=true}.accessibilityIdentifier("account-workspace");ActionTile(title:"المجتمع",subtitle:"الأعمال والنقاشات والملف الشخصي",icon:"person.2"){community=true}.accessibilityIdentifier("community")}
                ActionTile(title:"دليل كوكيز",subtitle:"خطوة بخطوة، من الاستيراد إلى التصدير",icon:"book.closed"){guide=true}.accessibilityIdentifier("app-guide")
                ActionTile(title:"الإعدادات",subtitle:"المظهر، التحرير، والبيانات",icon:"slider.horizontal.3"){settings=true}.accessibilityIdentifier("settings-link")
            }
            HStack{Rectangle().fill(Palette.line).frame(height:1);Text("صنع للحوار والصورة").font(.system(size:10)).foregroundStyle(Palette.quiet);Rectangle().fill(Palette.line).frame(height:1)}.padding(.vertical,12)
        }.padding(20).frame(maxWidth:1100).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).toolbar(parent==nil ? .hidden:.visible,for:.navigationBar)

        .overlay{if importing{ProgressView("جارٍ تجهيز الصورة…").tint(Palette.gold).padding(24).glass()}}
        .sheet(isPresented:$picker){PhotoLibraryPicker(multiple:true){result in
            switch result{case .success(let urls):Task{importing=true;defer{importing=false;for url in urls{try? FileManager.default.removeItem(at:url)}};if urls.count>1{do{let id=try library.createChapter("فصل مستورد",parent:parent);try await library.importPages(urls,chapter:id)}catch{library.error=error.localizedDescription}}else{for url in urls{await library.importImage(url,parent:parent)}}};case .failure(let error):library.error=error.localizedDescription}
        }}

        .cookiesFileImporter(isPresented:$filePicker,allowedContentTypes:[UTType(filenameExtension:"cookies") ?? .zip,UTType(filenameExtension:"cookieschapter") ?? .zip,.zip,.pdf,.image],allowsMultipleSelection:true){result in
            switch result{case .failure(let error):library.error=error.localizedDescription;case .success(let urls):Task{importing=true;for url in urls{await library.importImage(url,parent:parent)};importing=false}}
        }
        .alert("مجلد جديد",isPresented:$folderPrompt){TextField("اسم العمل أو الفصل",text:$name);Button("إنشاء"){if !name.trimmingCharacters(in:.whitespaces).isEmpty{library.createFolder(name,parent:parent);name=""}};Button("إلغاء",role:.cancel){}}
        .alert("فصل جديد",isPresented:$chapterPrompt){TextField("اسم الفصل",text:$name);Button("إنشاء"){do{try library.createChapter(name,parent:parent);name=""}catch{library.error=error.localizedDescription}};Button("إلغاء",role:.cancel){}}
        .alert("تغيير الاسم",isPresented:Binding(get:{renaming != nil},set:{if !$0{renaming=nil}})){TextField("الاسم",text:$renameText);Button("حفظ"){if let item=renaming,!renameText.isEmpty{library.rename(item,to:renameText)};renaming=nil};Button("إلغاء",role:.cancel){renaming=nil}}
        .fullScreenCover(isPresented:$projectVault){ProjectVaultView(vault:library.vault)}.sheet(isPresented:$guide){AppGuideView()}.fullScreenCover(isPresented:$assistant){TyperLibraryView(folder:parent)}.fullScreenCover(isPresented:$settings){SettingsView()}.sheet(isPresented:$fontLibrary){FontLibraryView()}.fullScreenCover(isPresented:$community){ServiceHub()}.fullScreenCover(isPresented:$accountWorkspace){AccountWorkspaceView()}
        .alert("تعذر إكمال العملية",isPresented:Binding(get:{library.error != nil},set:{if !$0{library.error=nil}})){Button("حسنًا"){library.error=nil}}message:{Text(library.error ?? "")}
        .fullScreenCover(isPresented:$trash){LibraryTrashView()}
    }
    func card(_ item:LibraryItem)->some View {
        VStack(alignment:.leading,spacing:12){ZStack{RoundedRectangle(cornerRadius:14).fill(Palette.gold.opacity(0.06));if item.folder{Image(systemName:"folder").font(.system(size:36,weight:.ultraLight))}else{ProjectThumbnail(url:library.directory(item.cover ?? item.pages.first ?? item.id).appendingPathComponent("thumbnail.png"),revision:library.thumbnailRevision,icon:item.isChapter==true ? "rectangle.stack":"photo").frame(height:140).clipped().clipShape(RoundedRectangle(cornerRadius:14))}}.frame(height:140)
            Text(item.title).font(.system(size:14,weight:.medium)).lineLimit(1);Text(item.folder ? "\(library.items.filter{$0.parent==item.id}.count) أعمال":item.isChapter==true ? "\(item.pages.count) صفحة":library.vault.receipt(item.id)?.resident==false ? "محفوظ في الحساب · يُنزّل عند الفتح":"صورة أصلية · محفوظة على الجهاز").font(.system(size:10)).foregroundStyle(Palette.quiet)
        }.padding(12).glass(22).contextMenu{Button("تغيير الاسم"){renameText=item.title;renaming=item};Menu("نقل إلى"){Button("المعرض"){library.move(item,parent:nil)};ForEach(library.items.filter{$0.folder && $0.id != item.id}){folder in Button(folder.title){library.move(item,parent:folder.id)}}};Button("حذف",role:.destructive){library.remove(item)}}.accessibilityIdentifier("project-\(item.id)")
    }
}
struct PageDestination:View {
    @EnvironmentObject var library:LibraryStore
    let id:UUID
    var body:some View{PageSessionView(id:id,library:library)}
}
/// The resource lease follows the navigation destination's lifetime. Covering
/// the editor with settings or another full-screen panel does not close it.
@MainActor final class PageOpenSession:ObservableObject {
    @Published var model:EditorModel?
    @Published var failure:String?
    private let library:LibraryStore
    private let id:UUID
    private let lease=UUID()
    private var opened=false
    private var retainedModel:EditorModel?
    init(id:UUID,library:LibraryStore){self.id=id;self.library=library}
    func load()async {
        guard model==nil else{return};failure=nil
        do{
            try await library.vault.open(id,lease:lease);opened=true
            let directory=library.directory(id)
            let saved=try await BackgroundWork.run{guard let saved=try RecoveryFile.read(EditorPage.self,at:directory.appendingPathComponent("page.json")) else{throw ImageFailure.message("ملف الصفحة مفقود")};return saved}
            try Task.checkCancellation()
            if saved.recovered{library.error="استُعيدت الصفحة من آخر حفظ سليم."}
            let loaded=EditorModel(page:saved.value,library:library);retainedModel=loaded;model=loaded
        }catch{
            if opened{library.vault.close(id,lease:lease);opened=false}
            if !(error is CancellationError){failure=error.localizedDescription}
        }
    }
    deinit{
        let library=library,id=id,lease=lease,model=retainedModel,opened=opened
        Task{@MainActor in let flushed=model?.flushForClosing() ?? true;if opened{library.vault.close(id,lease:lease,allowTransfer:flushed)}}
    }
}
struct PageSessionView:View {
    @StateObject private var session:PageOpenSession
    private let readOnly:Bool
    init(id:UUID,library:LibraryStore,readOnly:Bool=false){_session=StateObject(wrappedValue:PageOpenSession(id:id,library:library));self.readOnly=readOnly}
    var body:some View {
        Group{if let model=session.model{if readOnly{ReadOnlyPage(model:model)}else{EditorView(model:model)}}else if let failure=session.failure{WorkspaceEmpty(title:"تعذر فتح المشروع",detail:failure,icon:"doc.badge.exclamationmark").padding(20)}else{ProgressView("فتح المشروع…")}}
            .task{await session.load()}
    }
}

private struct HomeHero:View {
    var projects:Int
    var folders:Int
    var body:some View{HStack(alignment:.center,spacing:18){VStack(alignment:.leading,spacing:16){QuietBadge(text:"مساحة المانهوا",icon:"sparkles");VStack(alignment:.leading,spacing:6){Text("لكل حكاية صوت.").font(.system(size:30,weight:.semibold,design:.rounded)).minimumScaleFactor(0.85);Text("ولكل حوار مكان.").font(.system(size:23,weight:.light,design:.rounded)).foregroundStyle(Palette.secondary)};Text("حرّر بثقة. رتّب فصولك.\nواجعل النص جزءًا من الصورة.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(5);HStack(spacing:8){QuietBadge(text:"\(projects) مشاريع",icon:"rectangle.stack");QuietBadge(text:"\(folders) مجلدات",icon:"folder")}}.frame(maxWidth:.infinity,alignment:.leading);VStack(spacing:12){Image("CookiesLogo").resizable().scaledToFit().frame(width:62,height:62).clipShape(Circle()).shadow(color:Palette.gold.opacity(0.2),radius:20);RoundedRectangle(cornerRadius:10).stroke(.white.opacity(0.16),lineWidth:1).frame(width:54,height:72).overlay{VStack(spacing:5){ForEach(0..<4,id:\.self){i in Capsule().fill(.white.opacity(0.18)).frame(width:i==0 || i==3 ? 20:32,height:2)}}}}.rotationEffect(.degrees(-8)).accessibilityHidden(true)}.padding(24).glass(28).overlay(alignment:.top){Capsule().fill(LinearGradient(colors:[.clear,Palette.gold.opacity(0.65),.clear],startPoint:.leading,endPoint:.trailing)).frame(height:1).padding(.horizontal,28)}.accessibilityElement(children:.contain)}
}
