import SwiftUI
import UniformTypeIdentifiers
import CoreText

struct FontLibraryView:View {
    @Environment(\.dismiss) var dismiss
    @State private var picker=false
    @State private var version=0
    @State private var error:String?
    var body:some View {
        ZStack {Ambient();VStack(spacing:12){
            HStack{Text("مكتبة الخطوط").font(.system(size:21,weight:.semibold));Spacer();IconButton(icon:"plus",title:"استيراد خط"){picker=true};IconButton(icon:"xmark",title:"إغلاق"){dismiss()}}.padding(.horizontal,20)
            List {ForEach(Fonts.files+Fonts.otf,id:\.self){url in
                VStack(alignment:.leading,spacing:8){Text(url.lastPathComponent).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet).lineLimit(1);Text("كلمات تُقرأ كما تريد").font(Font(Fonts.font({var style=TextStyle();style.fontPath=url.lastPathComponent;style.fontSize=22;return style}())))}.padding(.vertical,8).listRowBackground(Color.clear)
            }}.id(version).scrollContentBackground(.hidden).listStyle(.plain)
        }}.foregroundStyle(Palette.pale)
        .fileImporter(isPresented:$picker,allowedContentTypes:[UTType(filenameExtension:"ttf") ?? .data,UTType(filenameExtension:"otf") ?? .data]){result in
            do {let url=try result.get(),access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};try FileManager.default.createDirectory(at:Fonts.userDirectory,withIntermediateDirectories:true);let target=Fonts.userDirectory.appendingPathComponent(url.lastPathComponent);guard !FileManager.default.fileExists(atPath:target.path) else{throw ImageFailure.message("الخط موجود بالفعل")};try FileManager.default.copyItem(at:url,to:target);var cfError:Unmanaged<CFError>?;guard CTFontManagerRegisterFontsForURL(target as CFURL,.process,&cfError) else{try? FileManager.default.removeItem(at:target);throw ImageFailure.message("ملف الخط غير صالح أو اسمه مسجل بالفعل")};version+=1
            }catch{self.error=error.localizedDescription}
        }
        .alert("تعذر استيراد الخط",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}
    }
}
