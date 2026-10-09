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
    var filtered:[SavedTextStyle]{store.styles.filter{(group=="الكل" || $0.group==group) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query))}}
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            HStack{Button{editing=nil;name=model.active?.textContent.prefix(20).description ?? "";naming=true}label:{Label("حفظ نمط جديد",systemImage:"plus")}.accessibilityIdentifier("style-create");Spacer();Menu{
                Button{importer=true}label:{Label("استيراد حزمة",systemImage:"square.and.arrow.down")}
                Button{perform{exported=try store.export(tags:typer.state.tags)}}label:{Label("تصدير الأنماط والوسوم",systemImage:"square.and.arrow.up")}
                Button{if let layer=model.active{store.copy(layer,from:model.directory)}}label:{Label("نسخ نمط المحدد",systemImage:"eyedropper")}
                Button{pasteOptions=true}label:{Label("لصق خصائص النمط…",systemImage:"doc.on.clipboard")}
            }label:{Image(systemName:"ellipsis.circle")}}
            HStack{Image(systemName:"magnifyingglass");TextField("بحث في الأنماط",text:$query);Picker("المجموعة",selection:$group){Text("الكل").tag("الكل");ForEach(store.groups,id:\.self){Text($0).tag($0)}}.pickerStyle(.menu)}.font(.system(size:12))
            Toggle("تطبيق عرض النص والمنظور المحفوظ أيضًا",isOn:$includeLayout).font(.system(size:11))
            if filtered.isEmpty{Text("احفظ تنسيق النص المحدد ليظهر هنا؛ يمكنك إنشاء أنماطك الخاصة.").font(.system(size:12)).foregroundStyle(Palette.quiet)}
            LazyVGrid(columns:[GridItem(.adaptive(minimum:150))],spacing:10){ForEach(filtered){item in
                Button{perform{try store.apply(item,to:model,includeLayout:includeLayout)}}label:{VStack(alignment:.leading,spacing:6){StylePreview(item:item,directory:store.directory).frame(height:54);Text(item.title).font(.system(size:12)).lineLimit(1);Text(item.group).font(.system(size:10)).foregroundStyle(Palette.quiet)}.padding(10).frame(maxWidth:.infinity).glass(12)}.accessibilityIdentifier("saved-style-\(item.id)").contextMenu{
                    Button("تعديل الاسم والمجموعة"){editing=item;name=item.title;category=item.group;naming=true}
                    Button("استبدال بالنص المحدد"){perform{if let layer=model.active{try store.save(title:item.title,group:item.group,layer:layer,from:model.directory,replacing:item.id)}}}
                    Button("نسخ النمط"){perform{try store.duplicate(item.id)}}
                    Button("تصدير النمط"){perform{exported=try store.export(ids:[item.id])}}
                    Button("حذف",role:.destructive){perform{try store.remove(item.id)}}
                }
            }}
            if let exported{ShareLink(item:exported){Label("مشاركة الحزمة",systemImage:"square.and.arrow.up")}}
        }
        .sheet(isPresented:$pasteOptions){NavigationStack{List{ForEach(StyleComponent.allCases){component in Toggle(component.title,isOn:Binding(get:{components.contains(component)},set:{if $0{components.insert(component)}else{components.remove(component)}})).listRowBackground(Color.clear)}}.scrollContentBackground(.hidden).background(Palette.ink).navigationTitle("خصائص النمط").toolbar{ToolbarItem(placement:.cancellationAction){Button("إلغاء"){pasteOptions=false}};ToolbarItem(placement:.confirmationAction){Button("لصق"){perform{try store.paste(to:model,components:components);pasteOptions=false}}.disabled(components.isEmpty)}}}.preferredColorScheme(.dark)}
        .alert(editing==nil ? "نمط جديد":"تعديل النمط",isPresented:$naming){TextField("اسم النمط",text:$name);TextField("المجموعة",text:$category);Button("حفظ"){perform{if let editing{try store.rename(editing.id,title:name,group:category)}else if let layer=model.active{try store.save(title:name,group:category,layer:layer,from:model.directory)}}};Button("إلغاء",role:.cancel){}}
        .fileImporter(isPresented:$importer,allowedContentTypes:[UTType(filenameExtension:"cookiesstyles") ?? .zip,.zip]){result in perform{let tags=try store.importPackage(result.get());for tag in tags{try typer.saveTag(tag)}}}
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
        image=UIGraphicsImageRenderer(size:size.size,format:format).image{output in output.cgContext.translateBy(x:-size.minX,y:-size.minY);LayerRenderer.draw([layer],in:output.cgContext,directory:directory)}
    }}
}
