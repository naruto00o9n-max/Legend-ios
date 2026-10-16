import SwiftUI
import UniformTypeIdentifiers
import CoreText
import ZIPFoundation

struct FontLibraryView:View {
    var onSelect:((String)->Void)?=nil
    var currentFont:String?=nil
    var embedded=false
    var onClose:(()->Void)?=nil
    @State private var recent=UserDefaults.standard.stringArray(forKey:"fontRecent") ?? []
    @Environment(\.dismiss) var dismiss
    @State private var picker=false
    @State private var importing=false
    @State private var version=0
    @State private var error:String?
    @State private var scripts:[String:Set<String>]=[:]
    @State private var catalogue:[URL]=[]
    @State private var importedNames=Set<String>()
    @State private var classification=UUID()
    @State private var query=""
    @AppStorage("font-library-last-category") private var filter="الكل"
    @State private var favorites=Set(UserDefaults.standard.stringArray(forKey:"fontFavorites") ?? [])
    @State private var groups=UserDefaults.standard.dictionary(forKey:"fontGroups") as? [String:[String]] ?? [:]
    @State private var selected=Set<String>()
    @State private var groupName=""
    @State private var naming=false
    @State private var output:URL?
    private var files:[URL] {catalogue.filter{url in
        let name=url.lastPathComponent
        return (query.isEmpty || name.localizedCaseInsensitiveContains(query)) && (filter=="الكل" || scripts[name]?.contains(filter)==true || (filter=="المفضلة" && favorites.contains(name)) || (filter=="آخر استخدام" && recent.contains(name)) || (filter=="المستوردة" && importedNames.contains(name)) || (groups[filter]?.contains(name)==true))
    }.sorted{if filter=="آخر استخدام"{return (recent.firstIndex(of:$0.lastPathComponent) ?? Int.max)<(recent.firstIndex(of:$1.lastPathComponent) ?? Int.max)};return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending}}
    var body:some View {
        NavigationStack{ZStack{if !embedded{Ambient()};VStack(spacing:embedded ? 8:12){
            if !embedded{HStack(spacing:10){SurfaceSymbol(icon:"textformat.alt",size:36);VStack(alignment:.leading,spacing:3){Text("اختر صوت الحوار").font(.system(size:15,weight:.semibold));Text("\(catalogue.count) خطوط · معاينة مباشرة على الصورة").font(.system(size:10)).foregroundStyle(Palette.secondary)};Spacer(minLength:0)}.padding(.horizontal,16)}

            SearchBar(placeholder:"البحث في الخطوط",text:$query).padding(.horizontal,20)
            ScrollView(.horizontal,showsIndicators:false){HStack{ForEach(["الكل","العربية","الإنجليزية","المفضلة","آخر استخدام","المستوردة"]+groups.keys.sorted(),id:\.self){name in Button(name){filter=name}.buttonStyle(CapsuleActionStyle(selected:filter==name)).accessibilityIdentifier("font-category-"+name).accessibilityLabel(name)}}.padding(.horizontal).padding(.vertical,8)}.frame(height:embedded ? 44:54).accessibilityIdentifier("font-filter-strip")
            List{ForEach(files,id:\.self){url in row(url)}}.id(version).listStyle(.plain).buttonStyle(.borderless).scrollContentBackground(.hidden)
            if !embedded || !selected.isEmpty{HStack{Text("\(selected.count) للتنظيم");Spacer();Button("مجموعة جديدة"){naming=true}.disabled(selected.isEmpty);Button("تصدير"){exportFonts()}.disabled(selected.isEmpty);if let output{ShareLink(item:output){Image(systemName:"square.and.arrow.up")}}}.font(.system(size:12)).padding(14).glass(0)}

        }}.foregroundStyle(Palette.pale).navigationTitle("مكتبة الخطوط").navigationBarTitleDisplayMode(.inline)
        .toolbar{ToolbarItem(placement:.topBarLeading){Button("إغلاق"){if let onClose{onClose()}else{dismiss()}}.accessibilityIdentifier("font-close")};ToolbarItem(placement:.topBarTrailing){Button{picker=true}label:{Image(systemName:"plus")}.accessibilityLabel("استيراد خطوط").accessibilityIdentifier("font-import")}}
        .disabled(importing).overlay{if importing{ProgressView("جارٍ استيراد الخطوط…").padding(20).glass(20)}}
        .cookiesFileImporter(isPresented:$picker,allowedContentTypes:[.data],allowsMultipleSelection:true){result in do{importFonts(try result.get())}catch{self.error=error.localizedDescription}}
        .alert("مجموعة خطوط",isPresented:$naming){TextField("اسم المجموعة",text:$groupName);Button("حفظ"){let name=groupName.trimmingCharacters(in:.whitespacesAndNewlines);if !name.isEmpty{groups[name]=selected.sorted();saveGroups();filter=name;groupName=""}};Button("إلغاء",role:.cancel){}}
        .alert("مكتبة الخطوط",isPresented:Binding(get:{error != nil},set:{if !$0{error=nil}})){Button("حسنًا"){error=nil}}message:{Text(error ?? "")}.onAppear{if !(["الكل","العربية","الإنجليزية","المفضلة","آخر استخدام","المستوردة"]+groups.keys.sorted()).contains(filter){filter="الكل"};classifyFonts()}.onChange(of:version){_,_ in classifyFonts()}.cookiesInterface()}
    }
    private func row(_ url:URL)->some View {
        let name=url.lastPathComponent
        let active=currentFont==name
        return HStack(spacing:10){
            Button{choose(name)}label:{HStack(spacing:10){
                ZStack{RoundedRectangle(cornerRadius:10).fill(active ? Palette.gold.opacity(0.18):.white.opacity(0.04));Image(systemName:active ? "checkmark.circle.fill":"textformat").font(.system(size:19)).foregroundStyle(active ? Palette.gold:Palette.pale)}.frame(width:38,height:48)
                VStack(alignment:.leading,spacing:7){
                    Text(url.deletingPathExtension().lastPathComponent).font(.system(size:11,weight:.semibold)).foregroundStyle(active ? Palette.pale:Palette.secondary).lineLimit(1)
                    Text("حروف تصنع الحوار").font(Font(Fonts.font({var s=TextStyle();s.fontPath=name;s.fontSize=23;return s}()))).foregroundStyle(Palette.pale).lineLimit(2)
                    if active{Text("الخط المستخدم الآن").font(.system(size:9,weight:.medium)).foregroundStyle(Palette.gold)}
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.padding(10).background(active ? Palette.gold.opacity(0.07):.white.opacity(0.025),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(active ? Palette.gold.opacity(0.65):.white.opacity(0.07),lineWidth:active ? 1.2:0.6))}.buttonStyle(.plain).disabled(onSelect==nil).accessibilityIdentifier("font-choice-"+name).accessibilityValue(active ? "مختار":"غير مختار")
            VStack(spacing:12){Button{if favorites.contains(name){favorites.remove(name)}else{favorites.insert(name)};UserDefaults.standard.set(favorites.sorted(),forKey:"fontFavorites")}label:{Image(systemName:favorites.contains(name) ? "star.fill":"star").foregroundStyle(favorites.contains(name) ? Palette.gold:Palette.secondary)}.accessibilityLabel("تفضيل الخط")
                Button{if selected.contains(name){selected.remove(name)}else{selected.insert(name)}}label:{Image(systemName:selected.contains(name) ? "checkmark.square.fill":"square").font(.system(size:13)).foregroundStyle(Palette.quiet)}.accessibilityLabel("تحديد الخط للتنظيم والتصدير")}
        }
        .padding(.vertical,4).listRowInsets(EdgeInsets(top:0,leading:12,bottom:0,trailing:12)).listRowSeparator(.hidden).listRowBackground(Color.clear).contextMenu{
            ForEach(groups.keys.sorted(),id:\.self){group in Button("إضافة إلى \(group)"){groups[group]=Array(Set((groups[group] ?? [])+[name])).sorted();saveGroups()}}
            if groups[filter] != nil{Button("إزالة من المجموعة"){groups[filter]?.removeAll{$0==name};saveGroups()}}
            if importedNames.contains(name){Button("حذف الخط المستورد",role:.destructive){do{try FileManager.default.removeItem(at:url);CTFontManagerUnregisterFontsForURL(url as CFURL,.process,nil);Fonts.register();selected.remove(name);favorites.remove(name);UserDefaults.standard.set(favorites.sorted(),forKey:"fontFavorites");for key in Array(groups.keys){groups[key]?.removeAll{$0==name}};saveGroups();version+=1}catch{self.error=error.localizedDescription}}}
        }
    }
    private func choose(_ name:String){guard let onSelect else{return};recent.removeAll{$0==name};recent.insert(name,at:0);recent=Array(recent.prefix(30));UserDefaults.standard.set(recent,forKey:"fontRecent");onSelect(name)}
    private func classifyFonts(){
        let fonts=Fonts.files+Fonts.otf,token=UUID();catalogue=fonts;importedNames=Set(Fonts.userFiles.map(\.lastPathComponent));classification=token
        Task{do{let result=try await BackgroundWork.run{()->[String:Set<String>] in
            var result:[String:Set<String>]=[:]
            for file in fonts{try Task.checkCancellation();var style=TextStyle();style.fontPath=file.lastPathComponent;let ui=Fonts.font(style),font=CTFontCreateWithName(ui.fontName as CFString,17,nil);var supported=Set<String>();for (label,code) in [("العربية",UniChar(0x0639)),("الإنجليزية",UniChar(0x0041))]{var character=code,glyph=CGGlyph();if CTFontGetGlyphsForCharacters(font,&character,&glyph,1),glyph != 0{supported.insert(label)}};result[file.lastPathComponent]=supported};return result
        };if classification==token{scripts=result}}catch{}}
    }

    private func saveGroups(){UserDefaults.standard.set(groups,forKey:"fontGroups")}
    private func importFonts(_ urls:[URL]) {
        importing=true
        Task {
            defer{importing=false}
            do{
                let imported=try await BackgroundWork.run{try FontPackage.importArchives(urls)}
                let available=Set((Fonts.files+Fonts.otf).map(\.lastPathComponent))
                for (name,names) in imported{groups[name]=Array(Set((groups[name] ?? [])+names.filter{available.contains($0)})).sorted()}
                saveGroups();filter="المستوردة";query="";version+=1
            }catch{self.error=error.localizedDescription}
        }
    }
    private func exportFonts(){do{let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)};for file in Fonts.files+Fonts.otf where selected.contains(file.lastPathComponent){try FileManager.default.copyItem(at:file,to:folder.appendingPathComponent(file.lastPathComponent))};try JSONEncoder().encode(groups.mapValues{$0.filter{selected.contains($0)}}).write(to:folder.appendingPathComponent("collections.json"));let zip=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Fonts-\(UUID().uuidString.prefix(8)).zip");try FileManager.default.zipItem(at:folder,to:zip,shouldKeepParent:false);output=zip}catch{self.error=error.localizedDescription}}
}
