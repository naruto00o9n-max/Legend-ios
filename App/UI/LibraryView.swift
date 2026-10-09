import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct LibraryView:View {
    @EnvironmentObject var library:LibraryStore
    var parent:UUID? = nil;var title="معرضي"
    @State private var renaming:LibraryItem?
    @State private var renameText=""
    @State private var picker=false;@State private var folderPrompt=false;@State private var name="";@State private var selected:PhotosPickerItem?;@State private var importing=false;@State private var assistant=false;@State private var settings=false
    var children:[LibraryItem]{library.items.filter{$0.parent==parent}.sorted{if $0.folder != $1.folder{return $0.folder};return $0.title.localizedStandardCompare($1.title) == .orderedAscending}}
    var body:some View {
        ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:22){
            HStack{VStack(alignment:.leading,spacing:5){Text(title).font(.system(size:28,weight:.semibold));Text("رتّب العمل، ثم امنحه صوتك.").font(.system(size:13)).foregroundStyle(Palette.quiet)};Spacer();Brand().scaleEffect(0.75,anchor:.trailing)}
            HStack(spacing:10){Button{picker=true}label:{Label("استيراد صورة",systemImage:"plus")}.buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("import-image");Button{folderPrompt=true}label:{Image(systemName:"folder.badge.plus").frame(width:46,height:46).glass(16)}.accessibilityLabel("مجلد جديد").accessibilityIdentifier("new-folder")}
            if children.isEmpty{VStack(spacing:16){Image(systemName:"rectangle.stack").font(.system(size:38,weight:.ultraLight));Text("بداية فصل جديد").font(.system(size:19,weight:.medium));Text("أضف صور الفصل أو أنشئ مجلدًا\nلتجميع أعمالك وفصولها.").font(.system(size:13)).multilineTextAlignment(.center).foregroundStyle(Palette.quiet)}.frame(maxWidth:.infinity).padding(.vertical,60).glass()
                Button("افتح فصلًا تجريبيًا") {Task{importing=true;do{let root=library.root;let p=try await Task.detached{try ImagePipeline.fixture(root:root)}.value;library.add(p,parent:parent)}catch{library.error=error.localizedDescription};importing=false}}.font(.system(size:13)).accessibilityIdentifier("demo-project")
            }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:145),spacing:12)],spacing:12){ForEach(children){item in
                if item.folder{NavigationLink{LibraryView(parent:item.id,title:item.title)}label:{card(item)}}else{NavigationLink{PageDestination(id:item.id)}label:{card(item)}}
            }}
            HStack(spacing:12){Button{assistant=true}label:{Label("مساعد الحوارات",systemImage:"text.bubble").font(.system(size:13)).frame(maxWidth:.infinity).padding(16).glass(18)}.accessibilityIdentifier("assistant");Button{settings=true}label:{Image(systemName:"slider.horizontal.3").frame(width:48,height:48).glass(16)}.accessibilityLabel("الإعدادات").accessibilityIdentifier("settings")}
        }.padding(20)}}.foregroundStyle(Palette.pale).toolbar(parent==nil ? .hidden:.visible,for:.navigationBar)
        .overlay{if importing{ProgressView("جارٍ تجهيز الصورة…").tint(Palette.gold).padding(24).glass()}}
        .fileImporter(isPresented:$picker,allowedContentTypes:[.image,UTType(filenameExtension:"cookies") ?? .zip],allowsMultipleSelection:true){result in if case let .success(urls)=result{Task{importing=true;for url in urls{await library.importImage(url,parent:parent)};importing=false}}}
        .alert("مجلد جديد",isPresented:$folderPrompt){TextField("اسم العمل أو الفصل",text:$name);Button("إنشاء"){if !name.trimmingCharacters(in:.whitespaces).isEmpty{library.createFolder(name,parent:parent);name=""}};Button("إلغاء",role:.cancel){}}
        .alert("تغيير الاسم",isPresented:Binding(get:{renaming != nil},set:{if !$0{renaming=nil}})){TextField("الاسم",text:$renameText);Button("حفظ"){if let item=renaming,!renameText.isEmpty{library.rename(item,to:renameText)};renaming=nil};Button("إلغاء",role:.cancel){renaming=nil}}
        .sheet(isPresented:$assistant){AssistantView()}.sheet(isPresented:$settings){SettingsView()}
        .alert("تعذر إكمال العملية",isPresented:Binding(get:{library.error != nil},set:{if !$0{library.error=nil}})){Button("حسنًا"){library.error=nil}}message:{Text(library.error ?? "")}
    }
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
