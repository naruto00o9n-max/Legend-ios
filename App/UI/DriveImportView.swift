import SwiftUI
import UniformTypeIdentifiers

struct DriveImportView:View {
    @EnvironmentObject private var library:LibraryStore
    @Environment(\.dismiss) private var dismiss
    var parent:UUID?=nil
    var chapter:UUID?=nil
    @State private var address=""
    @State private var title="فصل من Drive"
    @State private var files=false
    @State private var busy=false
    @State private var progress=""
    @State private var failure:String?
    @State private var task:Task<Void,Never>?
    var body:some View{NavigationStack{ZStack{Ambient();ScrollView{VStack(alignment:.leading,spacing:22){
        SurfaceHeader(title:"فصولك من Drive",subtitle:"من رابط المشاركة إلى صفحات مرتبة بأسمائها",icon:"externaldrive.badge.plus")
        GlassSection("رابط عام",icon:"link"){
            TextField("https://drive.google.com/…",text:$address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).environment(\.layoutDirection,.leftToRight).glassField().accessibilityIdentifier("drive-link")
            if chapter==nil{TextField("اسم الفصل",text:$title).glassField()}
            Text("الرابط العام لا يحتاج حسابًا. تُستورد الصور الموجودة مباشرة في المجلد بترتيب أسمائها، دون تصغير أبعادها.").font(.system(size:12)).foregroundStyle(Palette.secondary)
            Button{run()}label:{Label("استيراد الفصل",systemImage:"arrow.down.to.line")}.buttonStyle(GoldButtonStyle(primary:true)).disabled(busy || address.isEmpty).accessibilityIdentifier("drive-import")
        }
        GlassSection("Drive الخاص بك",icon:"person.crop.circle"){
            Text("ثبّت تطبيق Google Drive وسجّل دخولك فيه، ثم فعّله ضمن «الملفات ← استعراض ← تعديل». اختر عدة صور هنا؛ لا يُستخدم حساب المطوّر ولا يحتاج كوكيز إلى كلمة مرورك.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(5)
            Button{files=true}label:{Label("اختيار من Google Drive في الملفات",systemImage:"folder")}.buttonStyle(GoldButtonStyle()).disabled(busy)
        }
        if busy{HStack{ProgressView();Text(progress).font(.system(size:12));Spacer();Button("إلغاء"){task?.cancel()}}.padding(18).glass(18)}
    }.padding(20).frame(maxWidth:650).frame(maxWidth:.infinity)}}.foregroundStyle(Palette.pale).navigationTitle("Google Drive").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){Button("تم"){dismiss()}.disabled(busy)}}}
        .interactiveDismissDisabled(busy)
        .cookiesFileImporter(isPresented:$files,allowedContentTypes:[.image],allowsMultipleSelection:true){result in do{let urls=try result.get();task=Task{await importFiles(urls)}}catch{failure=error.localizedDescription}}
        .cookiesAlert("Google Drive",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}
    }
    private func importFiles(_ urls:[URL])async{
        busy=true;defer{busy=false};var created:UUID?
        do{let destination:UUID;if let chapter{destination=chapter}else{destination=try library.createChapter(title.isEmpty ? "فصل من Drive":title,parent:parent);created=destination};progress="استيراد صفحات الفصل";try await library.importPages(urls,chapter:destination);dismiss()}
        catch{if let created,library.chapter(created)?.pages.isEmpty==true{try? library.commitItems(library.items.filter{$0.id != created})};failure=error.localizedDescription}
    }
    private func run(){task=Task{busy=true;defer{busy=false};let folder=FileManager.default.temporaryDirectory.appendingPathComponent("drive-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:folder)}
        do{progress="قراءة الرابط";let images=try await DriveChapterImport.list(DriveChapterImport.link(address));var urls:[URL]=[],total=0
            for (index,image) in images.enumerated(){try Task.checkCancellation();progress="تنزيل \(index+1) من \(images.count)";let file=try await DriveChapterImport.download(image,into:folder);total += try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0;guard total<=512*1024*1024 else{throw ImageFailure.message("الفصل أكبر من 512 ميغابايت؛ استورده على دفعات")};urls.append(file)}
            await importFiles(urls)
        }catch is CancellationError{}catch{failure=error.localizedDescription}
    }}
}
