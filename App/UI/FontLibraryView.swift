import SwiftUI
import UniformTypeIdentifiers
import CoreText
import ZIPFoundation

struct FontLibraryView:View {
    var onSelect:((String)->Void)?=nil
    var currentFont:String?=nil
    @State private var recent=UserDefaults.standard.stringArray(forKey:"fontRecent") ?? []
    @Environment(\.dismiss) var dismiss
    @State private var picker=false
    @State private var version=0
    @State private var error:String?
    @State private var scripts:[String:Set<String>]=[:]
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
        return (query.isEmpty || name.localizedCaseInsensitiveContains(query)) && (filter=="الكل" || scripts[name]?.contains(filter)==true || (filter=="المفضلة" && favorites.contains(name)) || (filter=="آخر استخدام" && recent.contains(name)) || (filter=="المستوردة" && url.path.hasPrefix(Fonts.userDirectory.path)) || (groups[filter]?.contains(name)==true))
    }.sorted{if filter=="آخر استخدام"{return (recent.firstIndex(of:$0.lastPathComponent) ?? Int.max)<(recent.firstIndex(of:$1.lastPathComponent) ?? Int.max)};return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending}}
    var body:some View {
        NavigationStack{ZStack{Ambient();VStack(spacing:12){
            TextField("البحث في الخطوط",text:$query).padding(12).glass(14).padding(.horizontal)
            ScrollView(.horizontal,showsIndicators:false){HStack{ForEach(["الكل","العربية","الإنجليزية","المفضلة","آخر استخدام","المستوردة"]+groups.keys.sorted(),id:\.self){name in Button(name){filter=name}.buttonStyle(.bordered).tint(filter==name ? Palette.gold:Palette.pale)}}.padding(.horizontal)}
            List{ForEach(files,id:\.self){url in row(url)}}.id(version).listStyle(.plain).buttonStyle(.borderless).scrollContentBackground(.hidden)
            HStack{Text("\(selected.count) محدد");Spacer();Button("مجموعة جديدة"){naming=true}.disabled(selected.isEmpty);Button("تصدير"){exportFonts()}.disabled(selected.isEmpty);if let output{ShareLink(item:output){Image(systemName:"square.and.arrow.up")}}}.font(.system(size:12)).padding(14).glass(0)
        }}.foregroundStyle(Palette.pale).navigationTitle("مكتبة الخطوط").navigationBarTitleDisplayMode(.inline)
        .toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){dismiss()}.accessibilityIdentifier("font-close")};ToolbarItem(placement:.topBarTrailing){Button{picker=true}label:{Image(systemName:"plus")}}}
        .fileImporter(isPresented:$picker,allowedContentTypes:[UTType(filenameExtension:"ttf") ?? .data,UTType(filenameExtension:"otf") ?? .data,.zip]){result in do{try importFonts(result.get())}catch{self.error=error.localizedDescription}}
        .alert("مجموعة خطوط",isPresented:$naming){TextField("اسم المجموعة",text:$groupName);Button("حفظ"){let name=groupName.trimmingCharacters(in:.whitespacesAndNewlines);if !name.isEmpty{groups[name]=selected.sorted();saveGroups();filter=name;groupName=""}};Button("إلغاء",role:.cancel){}}
        .alert("مكتبة الخطوط",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}.onAppear{classifyFonts()}.onChange(of:version){_,_ in classifyFonts()}.cookiesInterface()}
    }
    private func row(_ url:URL)->some View {
        let name=url.lastPathComponent
        return HStack{Button{if selected.contains(name){selected.remove(name)}else{selected.insert(name)}}label:{Image(systemName:selected.contains(name) ? "checkmark.circle.fill":"circle")};Button{choose(name)}label:{VStack(alignment:.leading,spacing:8){Text(name).font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet).lineLimit(1);Text("حروف تصنع الحوار - "+url.deletingPathExtension().lastPathComponent).font(Font(Fonts.font({var s=TextStyle();s.fontPath=name;s.fontSize=22;return s}()))).lineLimit(2)}}.disabled(onSelect==nil);if currentFont==name{Image(systemName:"checkmark")};Spacer();Button{if favorites.contains(name){favorites.remove(name)}else{favorites.insert(name)};UserDefaults.standard.set(favorites.sorted(),forKey:"fontFavorites")}label:{Image(systemName:favorites.contains(name) ? "star.fill":"star")}}
        .padding(.vertical,8).listRowBackground(Color.clear).contextMenu{
            ForEach(groups.keys.sorted(),id:\.self){group in Button("إضافة إلى \(group)"){groups[group]=Array(Set((groups[group] ?? [])+[name])).sorted();saveGroups()}}
            if groups[filter] != nil{Button("إزالة من المجموعة"){groups[filter]?.removeAll{$0==name};saveGroups()}}
            if url.path.hasPrefix(Fonts.userDirectory.path){Button("حذف الخط المستورد",role:.destructive){do{try FileManager.default.removeItem(at:url);CTFontManagerUnregisterFontsForURL(url as CFURL,.process,nil);Fonts.register();selected.remove(name);favorites.remove(name);UserDefaults.standard.set(favorites.sorted(),forKey:"fontFavorites");for key in Array(groups.keys){groups[key]?.removeAll{$0==name}};saveGroups();version+=1}catch{self.error=error.localizedDescription}}}
        }
    }
    private func choose(_ name:String){guard let onSelect else{return};recent.removeAll{$0==name};recent.insert(name,at:0);recent=Array(recent.prefix(30));UserDefaults.standard.set(recent,forKey:"fontRecent");onSelect(name)}
    private func classifyFonts(){var result:[String:Set<String>]=[:];for file in Fonts.files+Fonts.otf{var style=TextStyle();style.fontPath=file.lastPathComponent;let ui=Fonts.font(style),font=CTFontCreateWithName(ui.fontName as CFString,17,nil);var supported=Set<String>();for (label,code) in [("العربية",UniChar(0x0639)),("الإنجليزية",UniChar(0x0041))]{var character=code,glyph=CGGlyph();if CTFontGetGlyphsForCharacters(font,&character,&glyph,1),glyph != 0{supported.insert(label)}};result[file.lastPathComponent]=supported};scripts=result}
    private func saveGroups(){UserDefaults.standard.set(groups,forKey:"fontGroups")}
    private func importFonts(_ url:URL)throws {
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        let archive=url.pathExtension.lowercased()=="zip" ? try ChapterArchive.staging(url):nil
        defer{if let archive{try? FileManager.default.removeItem(at:archive)}}
        let candidates: [URL]
        if let archive{candidates=(FileManager.default.enumerator(at:archive,includingPropertiesForKeys:nil)?.allObjects as? [URL] ?? []).filter{["ttf","otf"].contains($0.pathExtension.lowercased())}}else{candidates=[url]}
        try FontPackage.importFiles(candidates)
        if let archive,let data=try? Data(contentsOf:archive.appendingPathComponent("collections.json")),let imported=try? JSONDecoder().decode([String:[String]].self,from:data){let available=Set((Fonts.files+Fonts.otf).map(\.lastPathComponent));for (name,names) in imported{groups[name]=Array(Set((groups[name] ?? [])+names.filter{available.contains($0)})).sorted()};saveGroups()}
        Fonts.register();version+=1
    }
    private func exportFonts(){do{let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)};for file in Fonts.files+Fonts.otf where selected.contains(file.lastPathComponent){try FileManager.default.copyItem(at:file,to:folder.appendingPathComponent(file.lastPathComponent))};try JSONEncoder().encode(groups.mapValues{$0.filter{selected.contains($0)}}).write(to:folder.appendingPathComponent("collections.json"));let zip=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Fonts-\(UUID().uuidString.prefix(8)).zip");try FileManager.default.zipItem(at:folder,to:zip,shouldKeepParent:false);output=zip}catch{self.error=error.localizedDescription}}
}
