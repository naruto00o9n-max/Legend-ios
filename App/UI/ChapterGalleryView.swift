import SwiftUI
import UniformTypeIdentifiers

struct ChapterGalleryView:View {
    @EnvironmentObject var library:LibraryStore
    let id:UUID
    @State private var selection=Set<UUID>()
    @State private var selecting=false
    @State private var photos=false
    @State private var files=false
    @State private var operation:String?
    @State private var exporting=false
    @State private var reading=false
    @State private var browser=false
    @State private var busy=false
    @State private var task:Task<Void,Never>?
    @State private var failure:String?
    var chapter:LibraryItem?{library.chapter(id)}
    var ids:[UUID]{chapter?.pages ?? []}
    var chosen:[UUID]{selection.isEmpty ? ids:ids.filter{selection.contains($0)}}
    var body:some View {
        ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:16){
            HStack{Text("\(ids.count) صفحة").font(.system(size:12)).foregroundStyle(Palette.quiet);Spacer();if selecting{Button(selection.count==ids.count ? "إلغاء التحديد":"تحديد الكل"){selection=selection.count==ids.count ? []:Set(ids)}};Button(selecting ? "تم":"تحديد"){selecting.toggle();if !selecting{selection=[]}}.accessibilityIdentifier("chapter-select")}
            HStack(spacing:14){Button{photos=true}label:{Label("صور",systemImage:"photo.badge.plus")};Button{files=true}label:{Label("ملف",systemImage:"folder")};Button{browser=true}label:{Label("سحب الفصل",systemImage:"globe")};Spacer();Menu{
                Button{operation="لوحة فارغة"}label:{Label("لوحة فارغة",systemImage:"rectangle.badge.plus")}
                Button{operation="دمج"}label:{Label("دمج المحدد",systemImage:"rectangle.stack")}.disabled(chosen.count<2)
                Button{operation="تقسيم"}label:{Label("تقسيم الصفحات",systemImage:"square.split.1x2")}.disabled(chosen.isEmpty)
                Button{operation="تغيير المقاس"}label:{Label("تغيير المقاس الذكي",systemImage:"arrow.up.left.and.arrow.down.right")}.disabled(chosen.isEmpty)
                Button{operation="تغيير الأسماء"}label:{Label("تغيير الأسماء",systemImage:"pencil")}.disabled(chosen.isEmpty)
                Menu("نقل المحدد إلى"){ForEach(library.items.filter{$0.isChapter==true && $0.id != id}){item in Button(item.title){perform{try library.movePages(Set(chosen),from:id,to:item.id);selection=[]}}}}
                Button{perform{try library.restoreChapter(id)}}label:{Label("استعادة الصفحات قبل آخر عملية",systemImage:"arrow.uturn.backward")}
                Button(role:.destructive){perform{try library.setPages(ids.filter{!chosen.contains($0)},chapter:id);selection=[]}}label:{Label("حذف المحدد من الفصل",systemImage:"trash")}
            }label:{Image(systemName:"ellipsis.circle")}}
            if ids.isEmpty{ContentUnavailableView("فصل جديد",systemImage:"rectangle.stack",description:Text("أضف صور الفصل أو اسحبه من رابط أو أنشئ لوحة فارغة."))}
            LazyVGrid(columns:[GridItem(.adaptive(minimum:150),spacing:12)],spacing:12){ForEach(Array(ids.enumerated()),id:\.element){index,pageID in
                Group{if selecting{Button{if selection.contains(pageID){selection.remove(pageID)}else{selection.insert(pageID)}}label:{card(pageID,index:index)}}else{NavigationLink{PageDestination(id:pageID)}label:{card(pageID,index:index)}}}
                .contextMenu{
                    Button("اجعلها الغلاف"){perform{try library.setCover(pageID,chapter:id)}}
                    Button("تقديم الصفحة"){shift(pageID,by:-1)}.disabled(index==0)
                    Button("تأخير الصفحة"){shift(pageID,by:1)}.disabled(index==ids.count-1)
                }.accessibilityIdentifier("chapter-page-\(index)")
            }}
        }.padding(20).frame(maxWidth:1200).frame(maxWidth:.infinity)}}
        .foregroundStyle(Palette.pale).navigationTitle(chapter?.title ?? "الفصل").navigationBarTitleDisplayMode(.inline)
        .toolbar{ToolbarItemGroup(placement:.topBarTrailing){Button{reading=true}label:{Image(systemName:"book")}.disabled(ids.isEmpty);Button{exporting=true}label:{Image(systemName:"square.and.arrow.up")}.disabled(chosen.isEmpty)}}
        .overlay{if busy{VStack(spacing:12){ProgressView("جارٍ تجهيز الصفحات…");Button("إلغاء"){task?.cancel()}}.padding(24).glass(20)}}
        .sheet(isPresented:$photos){PhotoLibraryPicker(multiple:true){result in switch result{case .failure(let error):failure=error.localizedDescription;case .success(let urls):importFiles(urls,owned:true)}}}
        .fileImporter(isPresented:$files,allowedContentTypes:[.image,.pdf,.zip,UTType(filenameExtension:"cookies") ?? .zip,UTType(filenameExtension:"cookieschapter") ?? .zip],allowsMultipleSelection:true){result in switch result{case .failure(let error):failure=error.localizedDescription;case .success(let urls):importFiles(urls)}}
        .sheet(isPresented:Binding(get:{operation != nil},set:{if !$0{operation=nil}})){PageOperationSheet(chapter:id,ids:chosen,operation:operation ?? "",completed:{operation=nil}).cookiesInterface()}
        .sheet(isPresented:$exporting){ChapterExportSheet(chapter:id,ids:chosen).cookiesInterface()}
        .fullScreenCover(isPresented:$reading){ChapterReaderView(chapter:id).cookiesInterface()}
        .fullScreenCover(isPresented:$browser){WebtoonImportView(chapter:id).cookiesInterface()}
        .alert("تعذر إكمال العملية",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}
    }
    func card(_ page:UUID,index:Int)->some View {
        VStack(alignment:.leading,spacing:8){ZStack(alignment:.topTrailing){if let image=UIImage(contentsOfFile:library.directory(page).appendingPathComponent("thumbnail.png").path){Image(uiImage:image).resizable().scaledToFill().frame(height:120).clipped()}else{Rectangle().fill(.white.opacity(0.05)).frame(height:120)};if selecting{Image(systemName:selection.contains(page) ? "checkmark.circle.fill":"circle").padding(8).background(.black.opacity(0.65),in:Circle())}}
            Text((try? library.load(page).title) ?? "صفحة \(index+1)").font(.system(size:12)).lineLimit(1)
            HStack{Text("\(index+1)");Spacer();if chapter?.cover==page{Image(systemName:"photo")}}.font(.system(size:10)).foregroundStyle(Palette.quiet)
        }.padding(10).glass(16)
    }
    func perform(_ action:()throws->Void){do{try action()}catch{failure=error.localizedDescription}}
    func shift(_ page:UUID,by delta:Int){perform{var next=ids;guard let index=next.firstIndex(of:page),next.indices.contains(index+delta) else{return};next.swapAt(index,index+delta);try library.setPages(next,chapter:id)}}
    func importFiles(_ urls:[URL],owned:Bool=false){task=Task{busy=true;defer{busy=false;if owned{for url in urls{try? FileManager.default.removeItem(at:url)}}};do{try await library.importPages(urls,chapter:id)}catch is CancellationError{}catch{failure=error.localizedDescription}}}
}

struct PageOperationSheet:View {
    @EnvironmentObject var library:LibraryStore
    let chapter:UUID;let ids:[UUID];let operation:String;var completed:()->Void
    @State private var width=800.0
    @State private var height=1500.0
    @State private var keepRatio=true
    @State private var transparent=false
    @State private var color=Color.white
    @State private var name="صفحة"
    @State private var alignment=0
    @State private var busy=false
    @State private var failure:String?
    @State private var job:Task<Void,Never>?
    var body:some View {NavigationStack{Form{
        if operation=="لوحة فارغة" || operation=="تغيير الأسماء"{TextField("الاسم",text:$name)}
        if operation=="لوحة فارغة" || operation=="تغيير المقاس"{HStack{Text("العرض px");TextField("العرض",value:$width,format:.number).keyboardType(.numberPad)};if operation=="تغيير المقاس"{Toggle("حفظ النسبة لكل صفحة",isOn:$keepRatio)}}
        if operation=="تقسيم" || operation=="لوحة فارغة" || (operation=="تغيير المقاس" && !keepRatio){HStack{Text(operation=="تقسيم" ? "أقصى طول الجزء px":"الطول px");TextField("الطول",value:$height,format:.number).keyboardType(.numberPad)}}
        if operation=="لوحة فارغة"{Toggle("خلفية شفافة",isOn:$transparent);ColorPicker("لون الخلفية",selection:$color,supportsOpacity:false)}
        if operation=="دمج"{Picker("محاذاة الصور المختلفة العرض",selection:$alignment){Text("يسار").tag(0);Text("وسط").tag(1);Text("يمين").tag(2)};Text("لن تتغير دقة الصور؛ تُدمج بأبعادها وطبقاتها الأصلية.")}
        if busy{ProgressView("جارٍ تنفيذ العملية…");Button("إلغاء العملية"){job?.cancel()}}else{Button("تنفيذ"){run()}.accessibilityIdentifier("chapter-operation-apply")}
    }.navigationTitle(operation).navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){if !busy{completed()}}}}.alert("تعذر تعديل الصفحات",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}}}
    func run(){job=Task{busy=true;defer{busy=false};do{
        guard let item=library.chapter(chapter) else{throw ImageFailure.message("الفصل غير موجود")}
        if operation=="تغيير الأسماء"{try library.renamePages(Set(ids),prefix:name,chapter:chapter);completed();return}
        let pages=try ids.map{try library.load($0)},root=library.root,op=operation,w=Int(width),h=Int(height),ratio=keepRatio,align=alignment,background=UIColor(color).hex,clear=transparent,title=name
        let output=try await BackgroundWork.run{()->[EditorPage] in
            if op=="لوحة فارغة"{return [try PageOperations.blank(title:title,width:w,height:h,color:background,transparent:clear,root:root)]}
            if op=="دمج"{return [try PageOperations.merged(pages,root:root,alignment:align)]}
            var result:[EditorPage]=[]
            do{for page in pages{try Task.checkCancellation();if op=="تقسيم"{result+=try PageOperations.split(page,maximumHeight:h,root:root)}else{result.append(try PageOperations.resized(page,width:w,height:ratio ? max(1,Int(Double(page.height)*Double(w)/Double(page.width))):h,root:root))}};return result}
            catch{for page in result{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString))};throw error}
        }
        var next=item.pages
        if op=="لوحة فارغة"{next+=output.map(\.id)}else if let first=next.firstIndex(where:{ids.contains($0)}){next.removeAll{ids.contains($0)};next.insert(contentsOf:output.map(\.id),at:min(first,next.count))}
        try library.setPages(next,chapter:chapter);completed()
    }catch is CancellationError{}catch{failure=error.localizedDescription}}}
}

struct ChapterReaderView:View {
    @EnvironmentObject var library:LibraryStore
    @Environment(\.dismiss) var dismiss
    let chapter:UUID
    @State private var index=0
    var pages:[UUID]{library.chapter(chapter)?.pages ?? []}
    var body:some View {NavigationStack{Group{if pages.indices.contains(index){ChapterReaderPage(id:pages[index]).id(pages[index])}else{Text("لا توجد صفحات")}}.safeAreaInset(edge:.bottom){HStack{Button{index=max(0,index-1)}label:{Image(systemName:"chevron.right")}.disabled(index==0);Spacer();Text("\(index+1) / \(pages.count)").font(.system(size:12));Spacer();Button{index=min(pages.count-1,index+1)}label:{Image(systemName:"chevron.left")}.disabled(index>=pages.count-1)}.padding().glass(0)}.toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){dismiss()}};ToolbarItem(placement:.topBarTrailing){if pages.indices.contains(index){NavigationLink("تعديل"){PageDestination(id:pages[index])}}}}}.foregroundStyle(Palette.pale)}
}
struct ChapterReaderPage:View {
    @EnvironmentObject var library:LibraryStore
    let id:UUID
    var body:some View{if let page=try? library.load(id){ReadOnlyPage(model:EditorModel(page:page,library:library))}else{Text("تعذر فتح الصفحة")}}
}
struct ReadOnlyPage:View {@StateObject var model:EditorModel;var body:some View{CanvasHost(model:model,readOnly:true)}}

struct ChapterExportSheet:View {
    @EnvironmentObject var library:LibraryStore
    let chapter:UUID;let ids:[UUID]
    @State private var format="PNG"
    @State private var prefix="صفحة"
    @State private var smart=false
    @State private var maxHeight=15000.0
    @State private var quality=0.95
    @State private var busy=false
    @State private var completed=0
    @State private var total=0
    @State private var output:URL?
    @State private var failure:String?
    @State private var task:Task<Void,Never>?
    var body:some View{NavigationStack{Form{
        Picker("الصيغة",selection:$format){ForEach(["PNG","JPEG","PSD","مشروع","فصل قابل للتعديل"],id:\.self){Text($0)}}
        TextField("بادئة أسماء الصفحات",text:$prefix)
        if format=="JPEG"{Slider(value:$quality,in:0.1...1);Text("الجودة \(Int(quality*100))%")}
        if format != "فصل قابل للتعديل"{Toggle("تصدير ذكي: دمج ثم تقطيع",isOn:$smart);if smart{TextField("طول الجزء px",value:$maxHeight,format:.number).keyboardType(.numberPad)}}
        if busy{ProgressView(value:Double(completed),total:Double(max(1,total)));Text("\(completed) / \(total)");Button("إلغاء"){task?.cancel()}}else{Button("تصدير \(ids.count) صفحة"){export()}.accessibilityIdentifier("chapter-export")}
        if let output{ShareLink(item:output){Label("حفظ أو مشاركة الحزمة",systemImage:"square.and.arrow.up")}}
    }.navigationTitle("استوديو التصدير").navigationBarTitleDisplayMode(.inline)}.alert("تعذر التصدير",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}}
    func export(){task=Task{busy=true;completed=0;total=ids.count;defer{busy=false};do{
        let pages=try ids.map{try library.load($0)},root=library.root,format=self.format,prefix=self.prefix,quality=self.quality,h=smart ? Int(maxHeight):nil
        if format=="فصل قابل للتعديل",var item=library.chapter(chapter){item.pages=ids;output=try await BackgroundWork.run{try ChapterArchive.export(item,root:root)}}
        else{output=try await BackgroundWork.run{try BatchExport.export(pages:pages,root:root,format:format,quality:quality,prefix:prefix,smartHeight:h){done,count in Task{@MainActor in completed=done;total=count}}}}
    }catch is CancellationError{}catch{failure=error.localizedDescription}}}
}
