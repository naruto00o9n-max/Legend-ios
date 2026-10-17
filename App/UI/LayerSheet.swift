import SwiftUI

/// The stack, commands and current-layer controls have stable positions.
/// Row buttons never rely on a surrounding row tap to find their target.
struct LayerSheet:View {
    @ObservedObject var model:EditorModel
    var onImport:(()->Void)?
    var onClose:(()->Void)?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("editor-layer-filter") private var filter="all"
    @State private var expandedStacks=Set<UUID>()
    @State private var multiple=false
    @State private var selection=Set<UUID>()
    @State private var preview:EditorLayer?
    @State private var grouping=false
    @State private var groupName=""
    @State private var renaming=false
    @State private var layerName=""
    @State private var confirmation:LayerConfirmation?
    @State private var shared:URL?
    private var layers:[EditorLayer]{
        var seen=Set<UUID>()
        return model.page.layers.reversed().filter{item in
            guard filter=="all" || item.kind.rawValue==filter else{return false}
            guard let stack=item.stackID else{return true};return seen.insert(stack).inserted
        }
    }
    private func members(_ item:EditorLayer)->[EditorLayer]{Array(model.layerObjects(item.id).reversed())}
    private func isSelected(_ item:EditorLayer)->Bool{model.currentLayerID==(item.stackID ?? item.id)}
    private var activeIndex:Int?{model.page.layers.firstIndex{$0.id==model.selected}}
    private var editable:Bool{model.active?.isLocked==false && !model.busy}
    var body:some View {
        VStack(spacing:0){
            header
            filters
            if multiple{selectionCommands}
            GeometryReader{geometry in
                VStack(spacing:0){
                    HStack(spacing:0){
                        if geometry.size.width>=680{inspector.frame(width:min(250,geometry.size.width*0.3));Divider().overlay(.white.opacity(0.06))}
                        layerList
                        commandRail
                    }
                    if geometry.size.height>240{currentControls}
                }
            }
            footer
        }
        .foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.94)).glass(26)
        .sheet(item:$preview){ExpandedLayerPreview(layer:$0,directory:model.directory)}
        .cookiesAlert("اسم الطبقة",isPresented:$renaming){TextField("الاسم",text:$layerName);Button("حفظ"){if let id=model.selected{model.renameLayer(id,to:layerName)}};Button("إلغاء",role:.cancel){}}
        .cookiesAlert("مجموعة طبقات",isPresented:$grouping){TextField("اسم المجموعة",text:$groupName);Button("حفظ"){model.groupLayers(selection,name:groupName.isEmpty ? "مجموعة":groupName)};Button("إلغاء",role:.cancel){}}
        .cookiesAlert(confirmation?.title ?? "",isPresented:Binding(get:{confirmation != nil},set:{if !$0{confirmation=nil}})){
            Button("تنفيذ",role:.destructive){performConfirmation()};Button("إلغاء",role:.cancel){confirmation=nil}
        }message:{Text(confirmation?.detail ?? "")}
        .onAppear{model.organizeLegacyTextLayers();model.recoverCurrentLayer();if let item=model.currentLayerObjects.last{model.selectLogicalLayer(item)}}
        .onChange(of:model.page.layers.map(\.id)){_,ids in selection.formIntersection(Set(ids))}
        .onChange(of:model.selected){_,_ in shared=nil}
    }
    private func close(){if let onClose{onClose()}else{dismiss()}}
    private var header:some View {
        HStack(spacing:12){
            SurfaceSymbol(icon:"square.3.layers.3d",size:36)
            VStack(alignment:.leading,spacing:3){Text("الطبقات").font(.system(size:17,weight:.semibold));Text("\(layers.count) طبقات · عناصر النص تبقى قابلة للتحرير").font(.system(size:10)).foregroundStyle(Palette.secondary)}
            Spacer(minLength:4)
            Button{multiple.toggle();selection=[]}label:{Image(systemName:multiple ? "checkmark.circle.fill":"checkmark.circle").frame(width:40,height:40)}
                .buttonStyle(.plain).accessibilityLabel("تحديد متعدد").accessibilityIdentifier("layers-multiple").accessibilityValue(multiple ? "مفعل":"غير مفعل")
            IconButton(icon:"chevron.down",title:"تم"){close()}.accessibilityIdentifier("layers-close")
        }.padding(.horizontal,16).padding(.vertical,12)
    }
    private var filters:some View {
        ScrollView(.horizontal,showsIndicators:false){HStack(spacing:7){
            filterChip("الكل","all");filterChip("النصوص","text");filterChip("الصور","image");filterChip("الرسم","drawing");filterChip("الأشكال","shape")
        }.padding(.horizontal,16).padding(.bottom,10)}
    }
    private func filterChip(_ title:String,_ type:String)->some View {
        Button{filter=type}label:{Text(title).font(.system(size:11,weight:.medium)).padding(.horizontal,14).frame(height:32)
            .background(filter==type ? .white.opacity(0.1):.white.opacity(0.025),in:Capsule())
            .overlay(Capsule().stroke(filter==type ? Palette.gold.opacity(0.6):.white.opacity(0.06),lineWidth:0.7))}
        .buttonStyle(.plain).accessibilityIdentifier("layers-filter-"+type).accessibilityValue(filter==type ? "مختار":"غير مختار")
    }
    private var layerList:some View {
        List {
            ForEach(layers){item in
                row(item)
                if let stack=item.stackID,expandedStacks.contains(stack){ForEach(members(item)){object in
                    Button{model.selected=object.id;model.tool = object.kind == .text ? .text:.move;model.panel=nil}label:{HStack(spacing:10){Image(systemName:object.kind == .text ? "text.bubble":object.kind == .image ? "photo":"paintbrush.pointed");Text(object.kind == .text ? object.textContent:object.name).lineLimit(2);Spacer();if model.selected==object.id && !model.stackSelection{Image(systemName:"checkmark.circle.fill").foregroundStyle(Palette.gold)}}.font(.system(size:11)).padding(.vertical,10).padding(.leading,24)}.buttonStyle(.plain).listRowBackground(Color.white.opacity(0.025)).accessibilityIdentifier("layer-object-"+object.id.uuidString)
                }}
            }.onMove{source,destination in model.reorderLayerStacks(layers.map(\.id),from:source,to:destination)}
            if !model.page.layers.contains(where:{$0.isWorkingImage==true || $0.stackID==model.page.baseLayerID}){backgroundRow}
            if model.page.baseHidden==true{HStack(spacing:12){Image(systemName:"square.on.square");VStack(alignment:.leading,spacing:3){Text("خلفية اللوحة").font(.system(size:12));Text("تُحفظ أيضًا في الصورة المصدّرة").font(.system(size:9)).foregroundStyle(Palette.quiet)};Spacer();Menu{Button("بيضاء"){model.setPaperWhite(true)};Button("شفافة"){model.setPaperWhite(false)}}label:{Text(model.page.paperWhite==true ? "بيضاء":"شفافة").font(.system(size:11)).padding(8).background(.white.opacity(0.05),in:Capsule())}}.padding(.vertical,5).listRowBackground(Color.clear)}
        }.listStyle(.plain).scrollContentBackground(.hidden).environment(\.editMode,.constant(.active)).buttonStyle(.borderless)
        .overlay{if layers.isEmpty && filter != "all"{Text("لا توجد طبقات في هذا القسم").font(.footnote).foregroundStyle(Palette.quiet).allowsHitTesting(false)}}
    }
    private func row(_ item:EditorLayer)->some View {
        HStack(spacing:10){
            if multiple{Image(systemName:selection.contains(item.id) ? "checkmark.circle.fill":"circle").font(.system(size:18))}
            Button{model.setStackVisibility(item.id,!item.isVisible)}label:{Image(systemName:item.isVisible ? "eye":"eye.slash").font(.system(size:16)).frame(width:32,height:44).foregroundStyle(item.isVisible ? Palette.pale:Palette.quiet)}
                .accessibilityLabel("إظهار الطبقة").accessibilityIdentifier("layer-eye-"+item.id.uuidString).accessibilityValue(item.isVisible ? "visible":"hidden")
            Button{select(item)}label:{
                HStack(spacing:10){
                    LayerThumbnail(layer:item,directory:model.directory).frame(width:50,height:50).clipShape(RoundedRectangle(cornerRadius:9))
                        .overlay(RoundedRectangle(cornerRadius:9).stroke(isSelected(item) ? Palette.gold.opacity(0.6):.white.opacity(0.1),lineWidth:1))
                    VStack(alignment:.leading,spacing:5){
                        HStack(spacing:6){Text("\((model.page.layers.firstIndex{$0.id==item.id} ?? 0)+1)").font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet);Text(item.stackName ?? item.name).font(.system(size:12,weight:.medium)).lineLimit(1)}
                        Text(item.stackID != nil ? "\(members(item).count) عناصر":item.kind == .text ? item.textContent:"\(Int(item.opacity*100))% · "+item.blend.title).font(.system(size:10)).foregroundStyle(Palette.secondary).lineLimit(1)
                        if let group=item.groupName{Label(group,systemImage:"folder").font(.system(size:9)).foregroundStyle(Palette.quiet)}
                    }.frame(maxWidth:.infinity,alignment:.leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if let stack=item.stackID{Button{if expandedStacks.contains(stack){expandedStacks.remove(stack)}else{expandedStacks.insert(stack)}}label:{Image(systemName:expandedStacks.contains(stack) ? "chevron.up":"chevron.down").frame(width:24,height:36)}.accessibilityLabel("عناصر الطبقة")}
            Button{model.setStackLocked(item.id,!item.isLocked)}label:{Image(systemName:item.isLocked ? "lock.fill":"lock.open").font(.system(size:13)).frame(width:30,height:44).foregroundStyle(item.isLocked ? Palette.pale:Palette.quiet)}
                .accessibilityLabel("قفل الطبقة").accessibilityIdentifier("layer-lock-"+item.id.uuidString).accessibilityValue(item.isLocked ? "locked":"unlocked")
        }
        .padding(.vertical,4).accessibilityElement(children:.contain).accessibilityIdentifier("layer-row-"+item.kind.rawValue+"-"+item.id.uuidString)
        .listRowInsets(EdgeInsets(top:2,leading:8,bottom:2,trailing:2))
        .listRowBackground(isSelected(item) ? Palette.gold.opacity(0.09):.clear)
        .contextMenu{
            Button{preview=item}label:{Label("معاينة مكبرة",systemImage:"viewfinder")}
            Button{model.selectLogicalLayer(item);layerName=item.stackName ?? item.name;renaming=true}label:{Label("إعادة التسمية",systemImage:"pencil")}
            Button{model.selectLogicalLayer(item);model.duplicate()}label:{Label("نسخ الطبقة",systemImage:"doc.on.doc")}
            Button(role:.destructive){model.selectLogicalLayer(item);model.delete()}label:{Label("حذف الطبقة",systemImage:"trash")}.disabled(item.isLocked)
        }
    }
    private func select(_ item:EditorLayer) {
        if multiple{
            let ids:Set<UUID>=item.groupID.map{group in Set(model.page.layers.filter{$0.groupID==group}.map(\.id))} ?? Set(model.layerObjects(item.id).map(\.id))
            if selection.contains(item.id){selection.subtract(ids)}else{selection.formUnion(ids)}
        }else{model.selectLogicalLayer(item)}
    }
    private var backgroundRow:some View {
        HStack(spacing:10){
            Image(systemName:"photo").frame(width:32,height:44)
            Button{model.selectOriginalLayer()}label:{VStack(alignment:.leading,spacing:4){Text("الصورة الأصلية").font(.system(size:12));Text("\(model.page.width) × \(model.page.height)").font(.system(size:10,design:.monospaced)).foregroundStyle(Palette.quiet)}.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())}.buttonStyle(.plain).accessibilityIdentifier("layer-original-select")
            Spacer(minLength:2)
            Button{model.checkpoint();model.page.baseHidden = !(model.page.baseHidden ?? false);model.save()}label:{Image(systemName:model.page.baseHidden==true ? "eye.slash":"eye").frame(width:34,height:44)}
                .accessibilityIdentifier("layer-base-visibility")
            Button{model.selectOriginalLayer();if model.prepareEraserTarget(){filter="all"}}label:{Image(systemName:"square.and.pencil").frame(width:34,height:44)}
                .disabled(model.page.baseHidden==true || model.busy).accessibilityLabel("تحويل الأصل إلى طبقة قابلة للتعديل")
        }.listRowBackground(Color.clear)
    }
    private var inspector:some View {
        VStack(spacing:16){
            Spacer(minLength:6)
            if let active=model.active{
                LayerThumbnail(layer:active,directory:model.directory,previewSize:180).frame(width:180,height:180).clipShape(RoundedRectangle(cornerRadius:16))
                    .onTapGesture{preview=active}
                Text(active.name).font(.system(size:13,weight:.semibold)).lineLimit(2)
                Text("معاينة الطبقة المختارة").font(.system(size:10)).foregroundStyle(Palette.secondary)
                HStack(spacing:8){Image(systemName:active.isLocked ? "lock.fill":"lock.open");Text(active.isLocked ? "مقفلة":"قابلة للتعديل")}.font(.system(size:10)).foregroundStyle(Palette.quiet)
                Button{layerName=active.name;renaming=true}label:{Label("إعادة التسمية",systemImage:"pencil")}.buttonStyle(CapsuleActionStyle())
                if !(active.erasures ?? []).isEmpty{Button{model.restoreActiveErasure()}label:{Label("استعادة الأجزاء الممسوحة",systemImage:"arrow.uturn.backward")}.font(.system(size:10)).disabled(!editable)}
            }else{Image(systemName:"square.3.layers.3d").font(.system(size:34)).foregroundStyle(Palette.quiet);Text("اختر طبقة لمعاينتها").font(.system(size:12)).foregroundStyle(Palette.secondary)}
            Spacer(minLength:6)
        }.padding(12)
    }
    private var commandRail:some View {
        ScrollView(showsIndicators:false){VStack(spacing:5){
            command("arrow.up","أعلى",id:"layer-move-up",enabled:editable && (activeIndex ?? -1)<model.page.layers.count-1){model.moveActiveLayer(by:1)}
            command("arrow.down","أسفل",id:"layer-move-down",enabled:editable && (activeIndex ?? 0)>0){model.moveActiveLayer(by:-1)}
            command("move.3d","تحويل",id:"layer-transform",enabled:editable){model.tool = .move;model.objectControlsOpen=true;model.panel=nil;close()}
            command("arrow.left.and.right.righttriangle.left.righttriangle.right","قلب أفقي",id:"layer-flip-horizontal",enabled:editable){model.flipActiveLayer(horizontal:true)}
            command("arrow.up.and.down.righttriangle.up.righttriangle.down","قلب رأسي",id:"layer-flip-vertical",enabled:editable){model.flipActiveLayer(horizontal:false)}
            command("square.3.layers.3d.down.right","دمج لأسفل",id:"layer-merge-down",enabled:editable && (activeIndex ?? 0)>0){Task{await model.mergeActiveDown()}}
            command("rectangle.dashed","إفراغ",id:"layer-clear",enabled:editable){confirmation = .clear}
            command("trash","حذف",id:"layer-delete",enabled:editable){model.delete()}
        }.padding(.vertical,8)}.frame(width:65).background(.white.opacity(0.025))
    }
    private func command(_ icon:String,_ title:String,id:String,enabled:Bool=true,action:@escaping()->Void)->some View {
        Button(action:action){VStack(spacing:5){Image(systemName:icon).font(.system(size:17));Text(title).font(.system(size:8)).lineLimit(1)}.frame(width:57,height:52)}
            .buttonStyle(.plain).disabled(!enabled).foregroundStyle(enabled ? Palette.pale:Palette.quiet.opacity(0.45)).accessibilityLabel(title).accessibilityIdentifier(id)
    }
    private var selectionCommands:some View {
        ScrollView(.horizontal,showsIndicators:false){HStack(spacing:10){
            Button{selection=Set(layers.flatMap{members($0)}.map(\.id))}label:{Label("الكل",systemImage:"checkmark.circle")}
            Button{Task{await model.mergeLayers(selection)}}label:{Label("دمج المحدد",systemImage:"square.3.layers.3d.down.right")}.disabled(selection.count<2 || model.busy)
            Button{grouping=true}label:{Label("تجميع",systemImage:"folder.badge.plus")}.disabled(selection.isEmpty)
            Button{model.ungroupLayers(selection)}label:{Label("فك التجميع",systemImage:"folder.badge.minus")}.disabled(selection.isEmpty)
        }.font(.system(size:11)).buttonStyle(CapsuleActionStyle()).padding(.horizontal,16).padding(.vertical,8)}
    }
    @ViewBuilder private var currentControls:some View {
        if let active=model.active{
            VStack(spacing:10){
                HStack(spacing:10){Text("\(Int(active.opacity*100))%").font(.system(size:11,design:.monospaced)).frame(width:42);StepSlider(value:Binding(get:{model.active?.opacity ?? 1},set:{v in model.changeLayerObjects{$0.opacity=v}}),in:0...1,onEditingChanged:{editing in if editing{model.checkpoint()};model.setContinuousEditing(editing)});Text("الشفافية").font(.system(size:11))}.disabled(!editable)
                HStack(spacing:12){
                    Menu{ForEach(Blend.allCases,id:\.self){blend in Button(blend.title){model.checkpoint();model.changeLayerObjects{$0.blend=blend}}}}label:{HStack{Text("المزج · "+active.blend.title);Image(systemName:"chevron.up.chevron.down")}.font(.system(size:11)).padding(.horizontal,13).frame(height:34).background(.white.opacity(0.055),in:Capsule())}.disabled(!editable).accessibilityIdentifier("layer-blend")
                    Spacer(minLength:2)
                    Button{preview=active}label:{Image(systemName:"viewfinder").frame(width:36,height:34)}.accessibilityLabel("معاينة مكبرة")
                    Button{layerName=active.name;renaming=true}label:{Image(systemName:"pencil").frame(width:36,height:34)}.accessibilityLabel("إعادة التسمية")
                    if active.kind == .text{Button{model.tool = .text;model.panel = .content;close()}label:{Label("تعديل النص",systemImage:"textformat")}.font(.system(size:11)).disabled(!editable)}
                }
            }.padding(.horizontal,16).padding(.vertical,10).background(.black.opacity(0.2))
        }
    }
    private var footer:some View {
        HStack(spacing:10){
            IconButton(icon:"plus",title:"طبقة رسم"){model.createLayer();filter="all"}.accessibilityIdentifier("layer-add")
            if let onImport{IconButton(icon:"photo.badge.plus",title:"استيراد صورة"){onImport()}.accessibilityIdentifier("layer-import-image")}
            IconButton(icon:"doc.on.doc",title:"نسخ الطبقة"){model.duplicate()}.disabled(model.active==nil || model.busy).accessibilityIdentifier("layer-duplicate")
            Spacer(minLength:0)
            if let shared{ShareLink(item:shared){Image(systemName:"square.and.arrow.up").frame(width:38,height:42)}.accessibilityLabel("مشاركة الطبقة")}
            Menu{
                Button{Task{shared=await model.exportActiveLayerPNG()}}label:{Label("حفظ الطبقة PNG شفاف",systemImage:"square.and.arrow.up")}.disabled(model.active==nil || model.busy)
                Button{confirmation = .rasterize}label:{Label("تحويل إلى صورة",systemImage:"square.grid.3x3.fill")}.disabled(!editable)
                Button{confirmation = .flatten}label:{Label("تسطيح العمل",systemImage:"square.3.layers.3d")}.disabled(model.page.layers.isEmpty || model.busy)
            }label:{Image(systemName:"ellipsis.circle").frame(width:42,height:42)}.accessibilityLabel("أوامر الطبقات")
        }.padding(.horizontal,14).padding(.vertical,6).background(.white.opacity(0.025))
    }
    private func performConfirmation() {
        switch confirmation{case .clear:model.clearActiveLayer();case .rasterize:Task{await model.rasterizeActiveLayer()};case .flatten:Task{await model.flattenLayers()};case nil:break};confirmation=nil
    }
}
private enum LayerConfirmation {
    case clear,rasterize,flatten
    var title:String{switch self{case .clear:"إفراغ محتوى الطبقة؟";case .rasterize:"تحويل الطبقة إلى صورة؟";case .flatten:"تسطيح العمل؟"}}
    var detail:String{switch self{case .clear:"يبقى موضع الطبقة وترتيبها محفوظين. يمكنك التراجع لاستعادة المحتوى.";case .rasterize:"يتحول المحتوى داخل اللوحة إلى صورة؛ تصبح النصوص غير قابلة للكتابة عليها. التراجع يعيد الطبقة الأصلية.";case .flatten:"تتحول الصورة والطبقات إلى صورة واحدة داخل اللوحة. التراجع يعيد الطبقات القابلة للتعديل."}}
}
