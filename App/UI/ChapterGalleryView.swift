import SwiftUI
import UniformTypeIdentifiers

struct ChapterGalleryView:View {
    @EnvironmentObject var library:LibraryStore
    let id:UUID
    @State private var selection=Set<UUID>()
    @State private var selecting=false
    @State private var deleting=false
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
    var chosen:[UUID]{selecting ? ids.filter{selection.contains($0)}:ids}
    var body:some View {
        ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:20){
            SurfaceHeader(title:chapter?.title ?? "الفصل",subtitle:"استورد، رتّب، وحرّر صفحاتك في استوديو واحد",icon:"rectangle.stack")
            HStack(spacing:8){QuietBadge(text:"\(ids.count) صفحة",icon:"rectangle.stack");if selecting{QuietBadge(text:"\(selection.count) محدد",icon:"checkmark.circle")};Spacer();Button(selecting ? "تم":"تحديد"){selecting.toggle();if !selecting{selection=[]}}.buttonStyle(CapsuleActionStyle(selected:selecting)).accessibilityIdentifier("chapter-select")}
            ResponsiveActionGrid(items:4){
                ActionTile(title:"إضافة صور",subtitle:"من مكتبة الجهاز",icon:"photo.badge.plus"){photos=true}.accessibilityIdentifier("chapter-import-photos")
                ActionTile(title:"فتح ملفات",subtitle:"صور وحزم ومشاريع",icon:"folder.badge.plus"){files=true}.accessibilityIdentifier("chapter-import-files")
                ActionTile(title:"سحب الفصل",subtitle:"من رابط إلى صفحات مرتبة",icon:"globe"){browser=true}.accessibilityIdentifier("chapter-webtoon")
                ActionTile(title:"دمج الصفحات",subtitle:selecting ? "دمج \(chosen.count) صفحات مختارة":"اجمع صفحات الفصل في صورة طويلة",icon:"rectangle.stack",prominent:chosen.count>1){operation="دمج"}.disabled(chosen.count<2).accessibilityIdentifier("chapter-merge")
            }
            GlassSection("استوديو الصفحات",icon:"slider.horizontal.3",subtitle:selecting ? "تُطبق العمليات على المحدد فقط":"تُطبق العمليات على صفحات الفصل"){
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:10){Button{operation="لوحة فارغة"}label:{Label("لوحة",systemImage:"rectangle.badge.plus")};Button{operation="تقسيم"}label:{Label("تقسيم",systemImage:"square.split.1x2")}.disabled(chosen.isEmpty);Button{operation="تغيير المقاس"}label:{Label("المقاس",systemImage:"arrow.up.left.and.arrow.down.right")}.disabled(chosen.isEmpty);Button{operation="تغيير الأسماء"}label:{Label("الأسماء",systemImage:"pencil")}.disabled(chosen.isEmpty)}}.buttonStyle(CapsuleActionStyle())
                HStack{if selecting{Button(selection.count==ids.count ? "إلغاء التحديد":"تحديد الكل"){selection=selection.count==ids.count ? []:Set(ids)}.font(.system(size:12))};Spacer();pageActions}
            }
            SectionHeading(title:"صفحات الفصل",detail:selecting ? "المس الصفحات لاختيارها":"المس صفحة لفتح المحرر")
            if ids.isEmpty{WorkspaceEmpty(title:"أول صفحة في حكايتك",detail:"أضف صور الفصل، اسحبه من رابط، أو ابدأ بلوحة فارغة.",icon:"rectangle.stack.badge.plus")}
            LazyVGrid(columns:[GridItem(.adaptive(minimum:150),spacing:14)],spacing:14){ForEach(Array(ids.enumerated()),id:\.element){index,pageID in
                Group{if selecting{Button{if selection.contains(pageID){selection.remove(pageID)}else{selection.insert(pageID)}}label:{card(pageID,index:index)}}else{NavigationLink{PageDestination(id:pageID)}label:{card(pageID,index:index)}}}
                .contextMenu{Button("اجعلها الغلاف"){perform{try library.setCover(pageID,chapter:id)}};Button("تقديم الصفحة"){shift(pageID,by:-1)}.disabled(index==0);Button("تأخير الصفحة"){shift(pageID,by:1)}.disabled(index==ids.count-1)}.accessibilityIdentifier("chapter-page-\(index)")
            }}.buttonStyle(.plain)
        }.padding(20).frame(maxWidth:1100).frame(maxWidth:.infinity)}}

        .foregroundStyle(Palette.pale).navigationTitle(chapter?.title ?? "الفصل").navigationBarTitleDisplayMode(.inline)
        .toolbar{ToolbarItemGroup(placement:.topBarTrailing){Button{reading=true}label:{Image(systemName:"book")}.disabled(ids.isEmpty).accessibilityIdentifier("chapter-reader");Button{exporting=true}label:{Image(systemName:"square.and.arrow.up")}.disabled(chosen.isEmpty).accessibilityIdentifier("chapter-export-open")}}
        .overlay{if busy{VStack(spacing:12){ProgressView("جارٍ تجهيز الصفحات…");Button("إلغاء"){task?.cancel()}}.padding(24).glass(20)}}
        .sheet(isPresented:$photos){PhotoLibraryPicker(multiple:true){result in switch result{case .failure(let error):failure=error.localizedDescription;case .success(let urls):importFiles(urls,owned:true)}}}
        .cookiesFileImporter(isPresented:$files,allowedContentTypes:[.image,.pdf,.zip,UTType(filenameExtension:"cookies") ?? .zip,UTType(filenameExtension:"cookieschapter") ?? .zip],allowsMultipleSelection:true){result in switch result{case .failure(let error):failure=error.localizedDescription;case .success(let urls):importFiles(urls)}}
        .sheet(isPresented:Binding(get:{operation != nil},set:{if !$0{operation=nil}})){PageOperationSheet(chapter:id,ids:chosen,operation:operation ?? "",completed:{operation=nil}).cookiesInterface()}
        .sheet(isPresented:$exporting){ChapterExportSheet(chapter:id,ids:chosen).cookiesInterface()}
        .fullScreenCover(isPresented:$reading){ChapterReaderView(chapter:id).cookiesInterface()}
        .fullScreenCover(isPresented:$browser){WebtoonImportView(chapter:id).cookiesInterface()}
        .confirmationDialog("إزالة \(chosen.count) صفحة من الفصل؟",isPresented:$deleting,titleVisibility:.visible){Button("إزالة الصفحات",role:.destructive){perform{try library.setPages(ids.filter{!chosen.contains($0)},chapter:id);selection=[]}}}
        .alert("تعذر إكمال العملية",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}
    }
    private var pageActions:some View{Menu{
        Button{operation="لوحة فارغة"}label:{Label("لوحة فارغة",systemImage:"rectangle.badge.plus")}
        Button{operation="دمج"}label:{Label("دمج المحدد",systemImage:"rectangle.stack")}.disabled(chosen.count<2)
        Button{operation="تقسيم"}label:{Label("تقسيم الصفحات",systemImage:"square.split.1x2")}.disabled(chosen.isEmpty)
        Button{operation="تغيير المقاس"}label:{Label("تغيير المقاس الذكي",systemImage:"arrow.up.left.and.arrow.down.right")}.disabled(chosen.isEmpty)
        Button{operation="تغيير الأسماء"}label:{Label("تغيير الأسماء",systemImage:"pencil")}.disabled(chosen.isEmpty)
        Menu("نقل المحدد إلى"){ForEach(library.items.filter{$0.isChapter==true && $0.id != id}){item in Button(item.title){perform{try library.movePages(Set(chosen),from:id,to:item.id);selection=[]}}}}
        Button{perform{try library.restoreChapter(id)}}label:{Label("استعادة الصفحات قبل آخر عملية",systemImage:"arrow.uturn.backward")}
        Button(role:.destructive){deleting=true}label:{Label("حذف المحدد من الفصل",systemImage:"trash")}.disabled(chosen.isEmpty)
    }label:{Label("إدارة الصفحات",systemImage:"ellipsis.circle").font(.system(size:12))}.accessibilityIdentifier("chapter-actions")}
    func card(_ page:UUID,index:Int)->some View{ChapterPageCard(directory:library.directory(page),index:index,selecting:selecting,selected:selection.contains(page),cover:chapter?.cover==page)}
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
    @State private var splitMode="height"
    @State private var splitCount=2.0
    @State private var resizeMode="scale"
    @State private var transparent=false
    @State private var color=Color.white
    @State private var name="صفحة"
    @State private var alignment=0
    @State private var busy=false
    @State private var failure:String?
    @State private var job:Task<Void,Never>?
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:18){
        SurfaceHeader(title:operation,subtitle:operation=="لوحة فارغة" ? "صفحة جديدة بمقاساتك":"\(ids.count) صفحات · عملية قابلة للاستعادة من الفصل",icon:operation=="دمج" ? "rectangle.stack":"slider.horizontal.3")
        GlassSection("خيارات العملية",icon:"slider.horizontal.3"){
            if operation=="لوحة فارغة" || operation=="تغيير الأسماء"{TextField("الاسم",text:$name).glassField()}
            if operation=="لوحة فارغة" || operation=="تغيير المقاس"{MetricField(title:"العرض",value:$width);if operation=="تغيير المقاس"{Picker("طريقة تغيير المقاس",selection:$resizeMode){Text("تحجيم المحتوى والطبقات").tag("scale");Text("مساحة اللوحة فقط").tag("canvas")}.pickerStyle(.menu);SettingToggle(title:"حفظ النسبة لكل صفحة",value:$keepRatio)}}
            if operation=="تقسيم"{Picker("طريقة التقسيم",selection:$splitMode){Text("بالطول").tag("height");Text("بالعدد").tag("count")}.pickerStyle(.segmented);if splitMode=="count"{MetricField(title:"عدد الأجزاء",value:$splitCount,unit:"أجزاء")}}
            if (operation=="تقسيم" && splitMode=="height") || operation=="لوحة فارغة" || (operation=="تغيير المقاس" && !keepRatio){MetricField(title:operation=="تقسيم" ? "أقصى طول الجزء":"الطول",value:$height)}
            if operation=="لوحة فارغة"{Menu{Button("مانهوا 800 × 15000"){width=800;height=15000};Button("صفحة 800 × 1200"){width=800;height=1200};Button("مربع 1080 × 1080"){width=1080;height=1080};Button("A4 — 2480 × 3508"){width=2480;height=3508}}label:{Label("مقاسات جاهزة",systemImage:"rectangle.3.group")}.buttonStyle(CapsuleActionStyle());SettingToggle(title:"خلفية شفافة",value:$transparent);if !transparent{CookiesColorWell("لون الخلفية",selection:$color,supportsOpacity:false)}}
            if operation=="دمج"{Picker("محاذاة الصور المختلفة العرض",selection:$alignment){Text("يسار").tag(0);Text("وسط").tag(1);Text("يمين").tag(2)}.pickerStyle(.segmented);Text("تُضم الصور وطبقاتها بأبعادها الأصلية. يمكن استعادة صفحات الفصل قبل آخر عملية من إدارة الصفحات.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(5)}
        }
        if busy{VStack(spacing:14){ProgressView("جارٍ تنفيذ العملية…");Button{job?.cancel()}label:{Label("إلغاء العملية",systemImage:"xmark")}.buttonStyle(CapsuleActionStyle())}.frame(maxWidth:.infinity).padding(20).glass(22)}else{Button{run()}label:{Label("تنفيذ "+operation,systemImage:"checkmark")}.buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("chapter-operation-apply")}
    }.padding(20).frame(maxWidth:700).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).interactiveDismissDisabled(busy).navigationTitle(operation).navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){if !busy{completed()}}}}.alert("تعذر تعديل الصفحات",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}}}

    func run(){job=Task{busy=true;defer{busy=false};do{
        guard let item=library.chapter(chapter) else{throw ImageFailure.message("الفصل غير موجود")}
        if operation=="تغيير الأسماء"{try library.renamePages(Set(ids),prefix:name,chapter:chapter);completed();return}
        let pages=try ids.map{try library.load($0)},root=library.root,op=operation,w=Int(width),h=Int(height),ratio=keepRatio,align=alignment,splitByCount=splitMode=="count",parts=max(1,Int(splitCount)),resizing=resizeMode,background=UIColor(color).hex,clear=transparent,title=name
        let output=try await BackgroundWork.run{()->[EditorPage] in
            if op=="لوحة فارغة"{return [try PageOperations.blank(title:title,width:w,height:h,color:background,transparent:clear,root:root)]}
            if op=="دمج"{return [try PageOperations.merged(pages,root:root,alignment:align)]}
            var result:[EditorPage]=[]
            do{for page in pages{try Task.checkCancellation();if op=="تقسيم"{result+=try PageOperations.split(page,maximumHeight:splitByCount ? max(1,(page.height+parts-1)/parts):h,root:root)}else{let targetHeight=ratio ? max(1,Int(Double(page.height)*Double(w)/Double(page.width))):h;result.append(try resizing=="canvas" ? PageOperations.canvasResized(page,width:w,height:targetHeight,root:root):PageOperations.resized(page,width:w,height:targetHeight,root:root))}};return result}
            catch{for page in result{try? FileManager.default.removeItem(at:root.appendingPathComponent(page.id.uuidString))};throw error}
        }
        var next=item.pages
        if op=="لوحة فارغة"{next+=output.map(\.id)}else if let first=next.firstIndex(where:{ids.contains($0)}){next.removeAll{ids.contains($0)};next.insert(contentsOf:output.map(\.id),at:min(first,next.count))}
        do{try library.setPages(next,chapter:chapter)}catch{for page in output{try? FileManager.default.removeItem(at:library.directory(page.id))};throw error};completed()
    }catch is CancellationError{}catch{failure=error.localizedDescription}}}
}

struct ChapterReaderView:View {
    @EnvironmentObject var library:LibraryStore
    @Environment(\.dismiss) var dismiss
    let chapter:UUID
    @State private var index=0
    @AppStorage("reader-direction") private var readingDirection="rtl"
    var pages:[UUID]{library.chapter(chapter)?.pages ?? []}
    var body:some View {NavigationStack{Group{if pages.indices.contains(index){ChapterReaderPage(id:pages[index]).id(pages[index])}else{Text("لا توجد صفحات")}}.safeAreaInset(edge:.bottom){HStack{Button{index=max(0,index-1)}label:{Image(systemName:readingDirection=="rtl" ? "chevron.right":"chevron.left")}.disabled(index==0);Spacer();Text("\(index+1) / \(pages.count)").font(.system(size:12));Spacer();Button{index=min(pages.count-1,index+1)}label:{Image(systemName:readingDirection=="rtl" ? "chevron.left":"chevron.right")}.disabled(index>=pages.count-1)}.padding().glass(0)}.toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){dismiss()}};ToolbarItem(placement:.topBarTrailing){if pages.indices.contains(index){NavigationLink("تعديل"){PageDestination(id:pages[index])}}}}}.foregroundStyle(Palette.pale).onAppear{index=ReaderBookmark.index(chapter:chapter,count:pages.count)}.onChange(of:index){_,value in ReaderBookmark.save(index:value,chapter:chapter)}}
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
    @Environment(\.dismiss) private var dismiss
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:18){
        SurfaceHeader(title:"استوديو التصدير",subtitle:"\(ids.count) صفحات · اختر الحزمة المناسبة لعملك",icon:"square.and.arrow.up")
        GlassSection("صيغة الحزمة",icon:"doc.zipper"){Picker("الصيغة",selection:$format){ForEach(["PNG","JPEG","PSD","مشروع","فصل قابل للتعديل"],id:\.self){Text($0)}}.pickerStyle(.menu);TextField("بادئة أسماء الصفحات",text:$prefix).glassField();if format=="JPEG"{HStack{Text("جودة JPEG");Spacer();Text("\(Int(quality*100))%").font(.system(size:11,design:.monospaced))};StepSlider(value:$quality,in:0.1...1)};Text(format=="JPEG" ? "JPEG يستخدم ضغطًا مع فقدان. PNG يحفظ الصورة بلا فقدان.":format=="PSD" ? "PSD يحتفظ بالطبقات مرسومة؛ احتفظ بملف المشروع لتعديل النصوص.":"المشروع والفصل القابل للتعديل يحتفظان بأصول الصور والطبقات.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)}
        if format != "فصل قابل للتعديل"{GlassSection("تصدير ذكي",icon:"square.split.1x2"){SettingToggle(title:"دمج ثم تقطيع",detail:"اجمع صفحات الفصل ثم قسّمها بطول ثابت.",value:$smart);if smart{MetricField(title:"طول الجزء",value:$maxHeight)}}}
        if busy{VStack(spacing:12){ProgressView(value:Double(completed),total:Double(max(1,total))).tint(Palette.gold);Text("\(completed) / \(total)").font(.system(size:12,design:.monospaced));Button("إلغاء"){task?.cancel()}.buttonStyle(CapsuleActionStyle())}.padding(20).glass(22)}else{Button{export()}label:{Label("تصدير \(ids.count) صفحة",systemImage:"square.and.arrow.up")}.buttonStyle(GoldButtonStyle(primary:true)).accessibilityIdentifier("chapter-export")}
        if let output{ShareLink(item:output){Label("حفظ أو مشاركة الحزمة",systemImage:"square.and.arrow.up")}.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("chapter-export-share")}
        Button{savePhotos()}label:{Label("حفظ المحدد في الاستوديو",systemImage:"photo")}.buttonStyle(GoldButtonStyle()).disabled(busy)
        Text("الحفظ في الصور يستخدم PNG بالأبعاد الأصلية. لا تصغّر الأبعاد إلا عند اختيار تغيير المقاس صراحةً.").font(.system(size:11)).foregroundStyle(Palette.quiet).lineSpacing(4)
    }.padding(20).frame(maxWidth:700).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("تصدير الفصل").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.disabled(busy)}}}.alert("تعذر التصدير",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}}

    func savePhotos(){task=Task{busy=true;completed=0;total=ids.count;defer{busy=false};do{for id in ids{try Task.checkCancellation();let page=try library.load(id),directory=library.directory(id);let file=try await BackgroundWork.run{try ImagePipeline.exportPNG(page,directory:directory)};defer{try? FileManager.default.removeItem(at:file)};try await PhotoSave.save(file);completed+=1}}catch is CancellationError{}catch{failure=error.localizedDescription}}}
    func export(){task=Task{busy=true;completed=0;total=ids.count;defer{busy=false};do{
        let pages=try ids.map{try library.load($0)},root=library.root,format=self.format,prefix=self.prefix,quality=self.quality,h=smart ? Int(maxHeight):nil
        if format=="فصل قابل للتعديل",var item=library.chapter(chapter){item.pages=ids;output=try await BackgroundWork.run{try ChapterArchive.export(item,root:root)}}
        else{output=try await BackgroundWork.run{try BatchExport.export(pages:pages,root:root,format:format,quality:quality,prefix:prefix,smartHeight:h){done,count in Task{@MainActor in completed=done;total=count}}}}
    }catch is CancellationError{}catch{failure=error.localizedDescription}}}
}

private struct ChapterPageCard:View {
    let directory:URL
    let index:Int
    var selecting:Bool
    var selected:Bool
    var cover:Bool
    @State private var title=""
    @State private var image:UIImage?
    var body:some View{VStack(alignment:.leading,spacing:12){ZStack(alignment:.topTrailing){ZStack{Color(white:0.07);if let image{Image(uiImage:image).resizable().scaledToFill()}else{Image(systemName:"photo").foregroundStyle(Palette.quiet)}}.frame(height:148).clipped().clipShape(RoundedRectangle(cornerRadius:15));HStack{QuietBadge(text:String(format:"%02d",index+1));Spacer();if selecting{Image(systemName:selected ? "checkmark.circle.fill":"circle").foregroundStyle(selected ? Palette.gold:.white).font(.system(size:22)).padding(3).background(.black.opacity(0.6),in:Circle())}}.padding(8)};Text(title.isEmpty ? "صفحة \(index+1)":title).font(.system(size:13,weight:.medium)).lineLimit(1);HStack{Text("جاهزة للتحرير").font(.system(size:10)).foregroundStyle(Palette.quiet);Spacer();if cover{Image(systemName:"photo").font(.system(size:10)).foregroundStyle(Palette.gold)}}}.padding(12).glass(22).overlay(RoundedRectangle(cornerRadius:22).stroke(selected ? Palette.gold.opacity(0.75):.clear,lineWidth:1)).task(id:directory){let directory=self.directory;let result=try? await BackgroundWork.run{()->(String,UIImage?) in let page=try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:directory.appendingPathComponent("page.json")));return(page.title,ImagePipeline.asset(directory.appendingPathComponent("thumbnail.png")))};if !Task.isCancelled,let result{title=result.0;image=result.1}}}
}
