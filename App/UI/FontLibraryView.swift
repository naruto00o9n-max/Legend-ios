import SwiftUI
import UniformTypeIdentifiers
import CoreText
import ZIPFoundation

struct FontLibraryView:View {
    @Environment(\.dismiss) var dismiss
    @State private var picker=false
    @State private var version=0
    @State private var error:String?
    @State private var query=""
    @State private var filter="الكل"
    @State private var favorites=Set(UserDefaults.standard.stringArray(forKey:"fontFavorites") ?? [])
    @State private var groups=UserDefaults.standard.dictionary(forKey:"fontGroups") as? [String:[String]] ?? [:]
    @State private var selected=Set<String>()
    @State private var groupName=""
    @State private var naming=false
    @State private var output:URL?
    private var files:[URL] {(Fonts.files+Fonts.otf).filter{url in
        let name=url.lastPathComponent
        return (query.isEmpty || name.localizedCaseInsensitiveContains(query)) && (filter=="الكل" || (filter=="المفضلة" && favorites.contains(name)) || (filter=="المستوردة" && url.path.hasPrefix(Fonts.userDirectory.path)) || (groups[filter]?.contains(name)==true))
    }.sorted{$0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending}}
    var body:some View {
        NavigationStack{ZStack{Ambient();VStack(spacing:12){
            TextField("البحث في الخطوط",text:$query).padding(12).glass(14).padding(.horizontal)
            ScrollView(.horizontal,showsIndicators:false){HStack{ForEach(["الكل","المفضلة","المستوردة"]+groups.keys.sorted(),id:\.self){name in Button(name){filter=name}.buttonStyle(.bordered).tint(filter==name ? Palette.gold:Palette.pale)}}.padding(.horizontal)}
            List{ForEach(files,id:\.self){url in row(url)}}.id(version).listStyle(.plain).scrollContentBackground(.hidden)
            HStack{Text("\(selected.count) محدد");Spacer();Button("مجموعة جديدة"){naming=true}.disabled(selected.isEmpty);Button("تصدير"){exportFonts()}.disabled(selected.isEmpty);if let output{ShareLink(item:output){Image(systemName:"square.and.arrow.up")}}}.font(.system(size:12)).padding(14).glass(0)
        }}.foregroundStyle(Palette.pale).navigationTitle("مكتبة الخطوط").navigationBarTitleDisplayMode(.inline)
        .toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){dismiss()}.accessibilityIdentifier("font-close")};ToolbarItem(placement:.topBarTrailing){Button{picker=true}label:{Image(systemName:"plus")}}}
        .fileImporter(isPresented:$picker,allowedContentTypes:[UTType(filenameExtension:"ttf") ?? .data,UTType(filenameExtension:"otf") ?? .data,.zip]){result in do{try importFonts(result.get())}catch{self.error=error.localizedDescription}}
        .alert("مجموعة خطوط",isPresented:$naming){TextField("اسم المجموعة",text:$groupName);Button("حفظ"){let name=groupName.trimmingCharacters(in:.whitespacesAndNewlines);if !name.isEmpty{groups[name]=selected.sorted();saveGroups();filter=name;groupName=""}};Button("إلغاء",role:.cancel){}}
        .alert("مكتبة الخطوط",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}.cookiesInterface()}
    }
    private func row(_ url:URL)->some View {
        let name=url.lastPathComponent
        return HStack{Button{if selected.contains(name){selected.remove(name)}else{selected.insert(name)}}label:{Image(systemName:selected.contains(name) ? "checkmark.circle.fill":"circle")};VStack(alignment:.leading,spacing:8){Text(name).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet).lineLimit(1);Text("كلمات تُقرأ كما تريد • Cookies").font(Font(Fonts.font({var s=TextStyle();s.fontPath=name;s.fontSize=22;return s}())))};Spacer();Button{if favorites.contains(name){favorites.remove(name)}else{favorites.insert(name)};UserDefaults.standard.set(favorites.sorted(),forKey:"fontFavorites")}label:{Image(systemName:favorites.contains(name) ? "star.fill":"star")}}
        .padding(.vertical,8).listRowBackground(Color.clear).contextMenu{
            ForEach(groups.keys.sorted(),id:\.self){group in Button("إضافة إلى \(group)"){groups[group]=Array(Set((groups[group] ?? [])+[name])).sorted();saveGroups()}}
            if groups[filter] != nil{Button("إزالة من المجموعة"){groups[filter]?.removeAll{$0==name};saveGroups()}}
            if url.path.hasPrefix(Fonts.userDirectory.path){Button("حذف الخط المستورد",role:.destructive){do{try FileManager.default.removeItem(at:url);CTFontManagerUnregisterFontsForURL(url as CFURL,.process,nil);Fonts.register();selected.remove(name);favorites.remove(name);UserDefaults.standard.set(favorites.sorted(),forKey:"fontFavorites");for key in Array(groups.keys){groups[key]?.removeAll{$0==name}};saveGroups();version+=1}catch{self.error=error.localizedDescription}}}
        }
    }
    private func saveGroups(){UserDefaults.standard.set(groups,forKey:"fontGroups")}
    private func importFonts(_ url:URL)throws {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        let archive=url.pathExtension.lowercased()=="zip" ? try ChapterArchive.staging(url):nil
        defer{if let archive{try? FileManager.default.removeItem(at:archive)}}
        let candidates: [URL]
        if let archive{candidates=(FileManager.default.enumerator(at:archive,includingPropertiesForKeys:nil)?.allObjects as? [URL] ?? []).filter{["ttf","otf"].contains($0.pathExtension.lowercased())}}else{candidates=[url]}
        guard !candidates.isEmpty,candidates.count<=200 else{throw ImageFailure.message("الحزمة يجب أن تحتوي من خط واحد إلى 200 خط")}
        for file in candidates{let size=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0;guard size<=16*1024*1024,let provider=CGDataProvider(url:file as CFURL),CGFont(provider) != nil else{throw ImageFailure.message("خط غير صالح: \(file.lastPathComponent)")}}
        try FileManager.default.createDirectory(at:Fonts.userDirectory,withIntermediateDirectories:true)
        var added:[URL]=[]
        do{for file in candidates{let target=Fonts.userDirectory.appendingPathComponent(file.lastPathComponent);if FileManager.default.fileExists(atPath:target.path){continue};try FileManager.default.copyItem(at:file,to:target);added.append(target);var registrationError:Unmanaged<CFError>?;guard CTFontManagerRegisterFontsForURL(target as CFURL,.process,&registrationError) else{throw ImageFailure.message("تعذر تسجيل \(file.lastPathComponent)؛ قد يكون اسم الخط مكررًا")}}}catch{for file in added{CTFontManagerUnregisterFontsForURL(file as CFURL,.process,nil);try? FileManager.default.removeItem(at:file)};Fonts.register();throw error}
        if let archive,let data=try? Data(contentsOf:archive.appendingPathComponent("collections.json")),let imported=try? JSONDecoder().decode([String:[String]].self,from:data){let available=Set((Fonts.files+Fonts.otf).map(\.lastPathComponent));for (name,names) in imported{groups[name]=Array(Set((groups[name] ?? [])+names.filter{available.contains($0)})).sorted()};saveGroups()}
        Fonts.register();version+=1
    }
    private func exportFonts(){do{let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)};for file in Fonts.files+Fonts.otf where selected.contains(file.lastPathComponent){try FileManager.default.copyItem(at:file,to:folder.appendingPathComponent(file.lastPathComponent))};try JSONEncoder().encode(groups.mapValues{$0.filter{selected.contains($0)}}).write(to:folder.appendingPathComponent("collections.json"));let zip=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Fonts-\(UUID().uuidString.prefix(8)).zip");try FileManager.default.zipItem(at:folder,to:zip,shouldKeepParent:false);output=zip}catch{self.error=error.localizedDescription}}
}
