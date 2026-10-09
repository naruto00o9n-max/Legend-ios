import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct LibraryView:View {
    @EnvironmentObject var library:LibraryStore
    var parent:UUID? = nil;var title="معرضي"
    @State private var filePicker=false;@State private var fontLibrary=false;@State private var community=false;@State private var search=""
    @State private var renaming:LibraryItem?
    @State private var renameText=""
    @State private var picker=false;@State private var folderPrompt=false;@State private var name="";@State private var selected:PhotosPickerItem?;@State private var importing=false;@State private var assistant=false;@State private var settings=false
    var children:[LibraryItem]{library.items.filter{$0.parent==parent && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))}.sorted{if $0.folder != $1.folder{return $0.folder};return $0.title.localizedStandardCompare($1.title) == .orderedAscending}}
    var body:some View {
        ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:22){
            HStack{VStack(alignment:.leading,spacing:4){Text(parent==nil ? "Cookies Editor":title).font(.system(size:24,weight:.semibold));Text(parent==nil ? "مساحة عملك": "صور الفصل ومجلداته").font(.system(size:12)).foregroundStyle(Palette.quiet)};Spacer();IconButton(icon:"person.crop.circle",title:"حسابي"){settings=true}.accessibilityIdentifier("settings")}
            HStack(spacing:12){importCard("استيراد الصور","من مكتبة الصور","photo",id:"import-image"){picker=true};importCard("استيراد مشروع","ملف Cookies","folder",id:"import-project"){filePicker=true}}
            HStack{Rectangle().fill(Palette.gold).frame(width:3,height:20);Text(parent==nil ? "المشاريع الأخيرة":title).font(.system(size:17,weight:.semibold));Spacer();IconButton(icon:"folder.badge.plus",title:"مجلد جديد"){folderPrompt=true}.accessibilityIdentifier("new-folder")}
            if !children.isEmpty{HStack{Image(systemName:"magnifyingglass").foregroundStyle(Palette.quiet);TextField("بحث في المشاريع",text:$search).font(.system(size:14));if !search.isEmpty{Button{search=""}label:{Image(systemName:"xmark.circle.fill")}}}.padding(12).glass(12)}
            if children.isEmpty{VStack(spacing:16){Image(systemName:"rectangle.stack").font(.system(size:38,weight:.ultraLight));Text("بداية فصل جديد").font(.system(size:19,weight:.medium));Text("أضف صور الفصل أو أنشئ مجلدًا\nلتجميع أعمالك وفصولها.").font(.system(size:13)).multilineTextAlignment(.center).foregroundStyle(Palette.quiet)}.frame(maxWidth:.infinity).padding(.vertical,60).glass()
                if ProcessInfo.processInfo.arguments.contains("-ui-tests"){Button("افتح فصلًا تجريبيًا") {Task{importing=true;do{let root=library.root;let p=try await Task.detached{try ImagePipeline.fixture(root:root)}.value;library.add(p,parent:parent)}catch{library.error=error.localizedDescription};importing=false}}.font(.system(size:13)).accessibilityIdentifier("demo-project")}
            }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:145),spacing:12)],spacing:12){ForEach(children){item in
                if item.folder{NavigationLink{LibraryView(parent:item.id,title:item.title)}label:{card(item)}}else{NavigationLink{PageDestination(id:item.id)}label:{card(item)}}
            }}
            HStack{Rectangle().fill(Palette.gold.opacity(0.7)).frame(width:3,height:18);Text("مساحة العمل").font(.system(size:14,weight:.medium));Spacer();Rectangle().fill(.white.opacity(0.08)).frame(height:1)}.padding(.top,4)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:150),spacing:12)],spacing:12){
                workspace("مكتبة الخطوط","textformat.alt",id:"font-library"){fontLibrary=true}
                workspace("المجتمع","person.2",id:"community"){community=true}
                workspace("مساعد الحوارات","text.bubble",id:"assistant"){assistant=true}
                workspace("الإعدادات","slider.horizontal.3",id:"settings-link"){settings=true}
            }

        }.padding(24).frame(maxWidth:1100).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).toolbar(parent==nil ? .hidden:.visible,for:.navigationBar)
        .overlay{if importing{ProgressView("جارٍ تجهيز الصورة…").tint(Palette.gold).padding(24).glass()}}
        .sheet(isPresented:$picker){PhotoLibraryPicker(multiple:true){result in
            switch result{case .success(let urls):Task{importing=true;for url in urls{await library.importImage(url,parent:parent);try? FileManager.default.removeItem(at:url)};importing=false};case .failure(let error):library.error=error.localizedDescription}
        }}

        .fileImporter(isPresented:$filePicker,allowedContentTypes:[UTType(filenameExtension:"cookies") ?? .zip],allowsMultipleSelection:true){result in
            switch result{case .failure(let error):library.error=error.localizedDescription;case .success(let urls):Task{importing=true;for url in urls{await library.importImage(url,parent:parent)};importing=false}}
        }
        .alert("مجلد جديد",isPresented:$folderPrompt){TextField("اسم العمل أو الفصل",text:$name);Button("إنشاء"){if !name.trimmingCharacters(in:.whitespaces).isEmpty{library.createFolder(name,parent:parent);name=""}};Button("إلغاء",role:.cancel){}}
        .alert("تغيير الاسم",isPresented:Binding(get:{renaming != nil},set:{if !$0{renaming=nil}})){TextField("الاسم",text:$renameText);Button("حفظ"){if let item=renaming,!renameText.isEmpty{library.rename(item,to:renameText)};renaming=nil};Button("إلغاء",role:.cancel){renaming=nil}}
        .sheet(isPresented:$assistant){AssistantView()}.fullScreenCover(isPresented:$settings){SettingsView()}.sheet(isPresented:$fontLibrary){FontLibraryView()}.fullScreenCover(isPresented:$community){ServiceHub()}
        .alert("تعذر إكمال العملية",isPresented:Binding(get:{library.error != nil},set:{if !$0{library.error=nil}})){Button("حسنًا"){library.error=nil}}message:{Text(library.error ?? "")}
    }
    func importCard(_ title:String,_ subtitle:String,_ icon:String,id:String,action:@escaping ()->Void)->some View{Button(action:action){HStack(spacing:12){Image(systemName:icon).font(.system(size:24,weight:.regular)).frame(width:46,height:46).background(Palette.gold.opacity(0.08),in:Circle());VStack(alignment:.leading,spacing:5){Text(title).font(.system(size:14,weight:.semibold));Text(subtitle).font(.system(size:11)).foregroundStyle(Palette.quiet)};Spacer(minLength:0)}.padding(16).frame(maxWidth:.infinity,minHeight:98).glass(20)}.accessibilityIdentifier(id)}
    func workspace(_ title:String,_ icon:String,id:String,action:@escaping ()->Void)->some View{Button(action:action){VStack(spacing:14){Image(systemName:icon).font(.system(size:26,weight:.light));Text(title).font(.system(size:13,weight:.medium))}.frame(maxWidth:.infinity).frame(height:110).glass(20)}.accessibilityIdentifier(id)}
    func card(_ item:LibraryItem)->some View {
        VStack(alignment:.leading,spacing:12){ZStack{RoundedRectangle(cornerRadius:14).fill(Palette.gold.opacity(0.06));if item.folder{Image(systemName:"folder").font(.system(size:36,weight:.ultraLight))}else if let image=UIImage(contentsOfFile:library.directory(item.id).appendingPathComponent("thumbnail.png").path){Image(uiImage:image).resizable().scaledToFill().frame(height:140).clipped().clipShape(RoundedRectangle(cornerRadius:14))}else{Image(systemName:"photo")}}.frame(height:140)
            Text(item.title).font(.system(size:14,weight:.medium)).lineLimit(1);Text(item.folder ? "\(library.items.filter{$0.parent==item.id}.count) أعمال":"صورة أصلية · محفوظة محليًا").font(.system(size:10)).foregroundStyle(Palette.quiet)
        }.padding(12).glass(22).contextMenu{Button("تغيير الاسم"){renameText=item.title;renaming=item};Menu("نقل إلى"){Button("المعرض"){library.move(item,parent:nil)};ForEach(library.items.filter{$0.folder && $0.id != item.id}){folder in Button(folder.title){library.move(item,parent:folder.id)}}};Button("حذف",role:.destructive){library.remove(item)}}.accessibilityIdentifier("project-\(item.id)")
    }
}
struct PageDestination:View {
    @EnvironmentObject var library:LibraryStore;let id:UUID
    var body:some View{if let page=try? library.load(id){EditorView(model:EditorModel(page:page,library:library))}else{Text("تعذر فتح المشروع").foregroundStyle(Palette.gold)}}
}
