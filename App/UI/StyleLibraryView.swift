import SwiftUI
import UniformTypeIdentifiers

struct StyleLibraryView:View {
    @EnvironmentObject var store:StyleStore
    @EnvironmentObject var typer:TyperStore
    @ObservedObject var model:EditorModel
    @State private var query=""
    @State private var group="الكل"
    @State private var naming=false
    @State private var editing:SavedTextStyle?
    @State private var name=""
    @State private var category="أنماطي"
    @State private var importer=false
    @State private var exported:URL?
    @State private var includeLayout=false
    @State private var pasteOptions=false
    @State private var components=Set(StyleComponent.allCases)
    @State private var failure:String?
    @State private var section="all"
    @State private var folderNaming=false
    @State private var folderName=""
    @State private var renamedFolder:String?
    @State private var designing:DialogueTag?
    @State private var designID:UUID?
    @State private var bulk=false
    @State private var selected:Set<UUID>=[]
    @State private var keywords=""
    var filtered:[SavedTextStyle]{store.styles.filter{(group=="الكل" || $0.group==group || $0.group.hasPrefix(group+"/")) && (section != "favorites" || $0.favorite==true) && (section != "recent" || $0.lastUsed != nil) && (query.isEmpty || ($0.title+" "+($0.keywords ?? []).joined(separator:" ")).localizedCaseInsensitiveContains(query))}.sorted{section=="recent" ? ($0.lastUsed ?? .distantPast)>($1.lastUsed ?? .distantPast):$0.modified>$1.modified}}
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            HStack{Button{editing=nil;keywords="";name=model.active?.textContent.prefix(20).description ?? "";naming=true}label:{Label("حفظ نمط جديد",systemImage:"plus")}.accessibilityIdentifier("style-create");Spacer();Menu{
                Button{designID=nil;designing=DialogueTag(title:"نمط جديد",prefix:"",style:.plainText())}label:{Label("تصميم نمط في المحرر",systemImage:"textformat")}
                Button{renamedFolder=nil;folderName="";folderNaming=true}label:{Label("إنشاء مجلد",systemImage:"folder.badge.plus")}
                if group != "الكل"{Button("إعادة تسمية المجلد"){renamedFolder=group;folderName=group;folderNaming=true};Button("إزالة المجلد مع إبقاء أنماطه"){perform{try store.removeFolder(group);group="الكل"}}}
                Button{bulk.toggle();selected=[]}label:{Label(bulk ? "إنهاء التحديد":"تحديد عدة أنماط",systemImage:"checkmark.circle")}
                Button{importer=true}label:{Label("استيراد حزمة",systemImage:"square.and.arrow.down")}
                Button{perform{exported=try store.export(tags:typer.state.tags)}}label:{Label("تصدير الأنماط والوسوم",systemImage:"square.and.arrow.up")}
                Button{if let layer=model.active{store.copy(layer,from:model.directory)}}label:{Label("نسخ نمط المحدد",systemImage:"eyedropper")}
                Button{pasteOptions=true}label:{Label("لصق خصائص النمط…",systemImage:"doc.on.clipboard")}
            }label:{Image(systemName:"ellipsis.circle")}}
            HStack{Image(systemName:"magnifyingglass");TextField("بحث في الأنماط",text:$query);Picker("المجموعة",selection:$group){Text("الكل").tag("الكل");ForEach(store.groups,id:\.self){Text($0).tag($0)}}.pickerStyle(.menu)}.font(.system(size:12))
            Picker("عرض الأنماط",selection:$section){Text("الكل").tag("all");Text("المفضلة").tag("favorites");Text("الأخيرة").tag("recent")}.pickerStyle(.segmented)
            if bulk{HStack(spacing:16){Text("\(selected.count) محدد").font(.footnote);Menu("نقل إلى"){ForEach(store.groups,id:\.self){folder in Button(folder){perform{try store.move(selected,to:folder)}}}};Button("تصدير"){perform{exported=try store.export(ids:selected)}}.disabled(selected.isEmpty);Button("حذف",role:.destructive){perform{try store.remove(selected);selected=[]}}.disabled(selected.isEmpty)}}
            Toggle("تطبيق عرض النص والمنظور المحفوظ أيضًا",isOn:$includeLayout).font(.system(size:11))
            if filtered.isEmpty{Text("احفظ تنسيق النص المحدد ليظهر هنا؛ يمكنك إنشاء أنماطك الخاصة.").font(.system(size:12)).foregroundStyle(Palette.quiet)}
            LazyVGrid(columns:[GridItem(.adaptive(minimum:150))],spacing:10){ForEach(filtered){item in
                Button{if bulk{if selected.contains(item.id){selected.remove(item.id)}else{selected.insert(item.id)}}else{perform{try store.apply(item,to:model,includeLayout:includeLayout)}}}label:{VStack(alignment:.leading,spacing:6){StylePreview(item:item,directory:store.directory).frame(height:54);HStack{Text(item.title).font(.system(size:12));if item.favorite==true{Image(systemName:"star.fill").font(.system(size:10)).foregroundStyle(Palette.gold)};if selected.contains(item.id){Image(systemName:"checkmark.circle.fill").foregroundStyle(Palette.gold)}}.lineLimit(1);Text(item.group).font(.system(size:10)).foregroundStyle(Palette.quiet)}.padding(10).frame(maxWidth:.infinity).glass(12)}.accessibilityIdentifier("saved-style-\(item.id)").contextMenu{
                    Button(item.favorite==true ? "إزالة من المفضلة":"إضافة إلى المفضلة"){perform{try store.toggleFavorite(item.id)}}
                    Button("تحرير النمط بأدوات النص"){designID=item.id;category=item.group;designing=DialogueTag(title:item.title,prefix:"",style:item.style,textTransform:item.transform)}
                    Button("تعديل الاسم والمجموعة"){editing=item;keywords=(item.keywords ?? []).joined(separator:", ");name=item.title;category=item.group;naming=true}
                    Button("استبدال بالنص المحدد"){perform{if let layer=model.active{try store.save(title:item.title,group:item.group,layer:layer,from:model.directory,replacing:item.id)}}}
                    Button("نسخ النمط"){perform{try store.duplicate(item.id)}}
                    Button("تصدير النمط"){perform{exported=try store.export(ids:[item.id])}}
                    Button("حذف",role:.destructive){perform{try store.remove(item.id)}}
                }
            }}
            if let exported{ShareLink(item:exported){Label("مشاركة الحزمة",systemImage:"square.and.arrow.up")}}
        }
        .sheet(isPresented:$pasteOptions){NavigationStack{List{ForEach(StyleComponent.allCases){component in Toggle(component.title,isOn:Binding(get:{components.contains(component)},set:{if $0{components.insert(component)}else{components.remove(component)}})).listRowBackground(Color.clear)}}.scrollContentBackground(.hidden).background(Palette.ink).navigationTitle("خصائص النمط").toolbar{ToolbarItem(placement:.cancellationAction){Button("إلغاء"){pasteOptions=false}};ToolbarItem(placement:.confirmationAction){Button("لصق"){perform{try store.paste(to:model,components:components);pasteOptions=false}}.disabled(components.isEmpty)}}}.preferredColorScheme(.dark)}
        .sheet(isPresented:$naming){NavigationStack{VStack(spacing:20){SurfaceHeader(title:editing==nil ? "احفظ أسلوبك":"تفاصيل النمط",subtitle:"اسم ومجلد ووسوم للعثور عليه سريعًا",icon:"textformat");TextField("اسم النمط",text:$name).padding(16).glass(16).accessibilityIdentifier("style-name");TextField("المجلد · استخدم / للمجلدات الفرعية",text:$category).padding(16).glass(16);TextField("وسوم البحث مفصولة بفاصلة",text:$keywords).padding(16).glass(16);Spacer()}.padding(24).background(Palette.ink).toolbar{ToolbarItem(placement:.cancellationAction){Button("إلغاء"){naming=false}};ToolbarItem(placement:.confirmationAction){Button("حفظ"){perform{let id:UUID;if let editing{id=editing.id;try store.rename(id,title:name,group:category)}else if let layer=model.active{id=try store.save(title:name,group:category,layer:layer,from:model.directory)}else{throw ImageFailure.message("حدد نصًا أو استخدم تصميم نمط في المحرر")};try store.updateKeywords(id,keywords);naming=false}}.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityIdentifier("style-save-details")}}}.cookiesInterface().presentationDetents([.medium,.large])}
        .alert(renamedFolder==nil ? "مجلد أنماط جديد":"تعديل المجلد",isPresented:$folderNaming){TextField("اسم المجلد",text:$folderName);Button("حفظ"){perform{if let old=renamedFolder{try store.renameFolder(old,to:folderName)}else{try store.createFolder(folderName)};group=folderName}};Button("إلغاء",role:.cancel){}}
        .fullScreenCover(item:$designing){tag in SavedStyleDesigner(tag:tag,replacing:designID,group:category)}
        .cookiesFileImporter(isPresented:$importer,allowedContentTypes:[UTType(filenameExtension:"cookiesstyles") ?? .zip,.zip]){result in perform{let tags=try store.importPackage(result.get());for tag in tags{try typer.saveTag(tag)}}}
        .alert("تعذر حفظ النمط",isPresented:Binding(get:{failure != nil},set:{if !$0{failure=nil}})){Button("حسنًا"){failure=nil}}message:{Text(failure ?? "")}
    }
    func perform(_ action:()throws->Void){do{try action()}catch{failure=error.localizedDescription}}
}
struct StylePreview:View {
    let item:SavedTextStyle
    let directory:URL
    @State private var image:UIImage?
    var body:some View{Group{if let image{Image(uiImage:image).resizable().scaledToFit()}else{ProgressView()}}.task(id:item){
        var layer=EditorLayer(kind:.text);layer.textContent="كوكيز Aa";layer.style=item.style;layer.style.boxWidth=360;layer.style.fontSize=min(48,layer.style.fontSize)
        let size=TextVisualBounds.rect(layer),format=UIGraphicsImageRendererFormat();format.scale=1
        let snapshot=layer,location=directory
        let rendered=try? await BackgroundWork.run{UIGraphicsImageRenderer(size:size.size,format:format).image{output in output.cgContext.translateBy(x:-size.minX,y:-size.minY);LayerRenderer.draw([snapshot],in:output.cgContext,directory:location)}}
        if !Task.isCancelled{image=rendered}
    }}
}

struct SavedStyleDesigner:View {
    let tag:DialogueTag
    let replacing:UUID?
    let group:String
    @EnvironmentObject private var store:StyleStore
    @State private var title=""
    var body:some View{TagStyleEditorView(tag:tag,savingStyle:true){layer,directory in try store.save(title:title.isEmpty ? tag.title:title,group:group,layer:layer,from:directory,replacing:replacing)}.safeAreaInset(edge:.top){TextField("اسم النمط",text:$title).padding(12).glass(12).padding(.horizontal,12)}.onAppear{title=tag.title}}
}
