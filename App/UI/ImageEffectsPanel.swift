import SwiftUI

struct ImageEffectsPanel:View {
    @ObservedObject var model:EditorModel
    @State private var catalog=true
    @State private var focused:UUID?
    private var effects:[ImageEffect]{model.active?.imageEffects ?? []}
    var body:some View {
        VStack(spacing:0){
            HStack(spacing:12){Image(systemName:"photo.stack").foregroundStyle(Palette.gold);VStack(alignment:.leading,spacing:3){Text("تأثيرات الصورة").font(.system(size:16,weight:.semibold));Text(model.active?.name ?? "الصورة").font(.system(size:11)).foregroundStyle(Palette.secondary)};Spacer();IconButton(icon:"checkmark",title:"تم"){model.imageEffectsOpen=false;model.save()}.accessibilityIdentifier("image-effects-close")}.padding(16)
            HStack(spacing:10){Button{catalog=true}label:{Label("المكتبة",systemImage:"square.grid.2x2")}.buttonStyle(CapsuleActionStyle(selected:catalog)).accessibilityIdentifier("image-effects-library");Button{catalog=false}label:{Label("التأثيرات · \(effects.count)",systemImage:"square.3.layers.3d")}.buttonStyle(CapsuleActionStyle(selected:!catalog)).accessibilityIdentifier("image-effects-stack");Spacer();Button{model.clearImageEffects();focused=nil;catalog=true}label:{Label("الأصل",systemImage:"arrow.uturn.backward")}.disabled(effects.isEmpty).accessibilityIdentifier("image-effects-original")}.font(.system(size:12)).padding(.horizontal,16).padding(.bottom,12)
            ScrollView{LazyVStack(alignment:.leading,spacing:14){
                if catalog{LazyVGrid(columns:[GridItem(.adaptive(minimum:125),spacing:12)],spacing:12){ForEach(ImageEffectKind.allCases){kind in Button{focused=model.addImageEffect(kind);catalog=false}label:{VStack(alignment:.leading,spacing:8){ImageEffectThumbnail(kind:kind).frame(height:68).clipShape(RoundedRectangle(cornerRadius:12));Label(kind.title,systemImage:kind.icon).font(.system(size:11,weight:.medium)).lineLimit(1)}.padding(10).glass(16)}.buttonStyle(.plain).disabled(model.active?.isLocked==true).accessibilityIdentifier("image-effect-card-"+kind.rawValue)}}}
                else if effects.isEmpty{VStack(spacing:12){Image(systemName:"photo.on.rectangle.angled").font(.system(size:28));Text("صورتك دون تأثيرات").font(.system(size:15,weight:.semibold));Text("اختر تأثيرًا من المكتبة؛ يبقى الأصل محفوظًا.").font(.system(size:12)).foregroundStyle(Palette.secondary);Button("فتح المكتبة"){catalog=true}.buttonStyle(GoldButtonStyle())}.frame(maxWidth:.infinity).padding(18).glass(20)}
                else{ForEach(Array(effects.enumerated()),id:\.element.id){index,effect in
                    VStack(alignment:.leading,spacing:12){
                        HStack(spacing:8){Button{focused=focused==effect.id ? nil:effect.id}label:{Label(effect.kind.title,systemImage:effect.kind.icon).font(.system(size:14,weight:.semibold))}.buttonStyle(.plain).accessibilityIdentifier("image-effect-edit-\(effect.kind.rawValue)");Spacer();Toggle("تفعيل",isOn:Binding(get:{effects.first(where:{$0.id==effect.id})?.enabled ?? false},set:{value in model.checkpoint();model.editImageEffect(effect.id){$0.enabled=value}})).labelsHidden().tint(Palette.gold).accessibilityIdentifier("image-effect-enabled-\(effect.kind.rawValue)")}
                        HStack(spacing:14){Text("\(index+1)").font(.system(size:11,design:.monospaced)).foregroundStyle(Palette.secondary);Text(effect.enabled ? "قابل للتعديل":"متوقف").font(.system(size:11)).foregroundStyle(Palette.secondary);Spacer();Button{model.moveImageEffect(effect.id,by:-1)}label:{Image(systemName:"arrow.up")}.disabled(index==0).accessibilityLabel("تقديم التأثير").accessibilityIdentifier("image-effect-up-\(effect.kind.rawValue)");Button{model.moveImageEffect(effect.id,by:1)}label:{Image(systemName:"arrow.down")}.disabled(index==effects.count-1).accessibilityLabel("تأخير التأثير");Button(role:.destructive){model.removeImageEffect(effect.id);if focused==effect.id{focused=nil}}label:{Image(systemName:"trash")}.accessibilityLabel("حذف التأثير").accessibilityIdentifier("image-effect-remove-\(effect.kind.rawValue)")}
                        if focused==effect.id{ImageEffectControls(model:model,id:effect.id).disabled(!effect.enabled || model.active?.isLocked==true)}
                    }.padding(16).glass(20)
                }}
                Text("التأثيرات تُطبّق بالترتيب المعروض وتُحفظ مع المشروع. أثناء السحب تظهر معاينة خفيفة، ثم تعود الدقة الكاملة عند الاستقرار.").font(.system(size:11)).foregroundStyle(Palette.secondary).lineSpacing(4)
            }.padding(.horizontal,16).padding(.bottom,24)}.accessibilityIdentifier("image-effects-scroll")
        }.foregroundStyle(Palette.pale).glass(26).onAppear{model.checkpoint();focused=effects.last?.id;catalog=effects.isEmpty}.onChange(of:model.selected){_,_ in focused=effects.last?.id;catalog=effects.isEmpty}.onDisappear{model.imageEffectsOpen=false;model.setContinuousEditing(false);model.save()}.environment(\.editorSliderEditing,{model.setContinuousEditing($0)})
    }
}
private struct ImageEffectControls:View {
    @ObservedObject var model:EditorModel
    let id:UUID
    var effect:ImageEffect{model.active?.imageEffects?.first(where:{$0.id==id}) ?? ImageEffect(.blur)}
    private func value(_ key:WritableKeyPath<ImageEffect,Double>)->Binding<Double>{Binding(get:{effect[keyPath:key]},set:{v in model.editImageEffect(id){$0[keyPath:key]=v}})}
    private func knob(_ title:String,_ key:WritableKeyPath<ImageEffect,Double>,_ range:ClosedRange<Double>)->some View{VStack(alignment:.leading,spacing:8){HStack{Text(title).font(.system(size:12));Spacer();TextField(title,value:value(key),format:.number.precision(.fractionLength(0...1))).font(.system(size:12,design:.monospaced)).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(width:62).accessibilityIdentifier("image-value-"+title)};StepSlider(value:value(key),in:range)}.padding(12).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:14))}
    private func color(_ title:String,_ key:WritableKeyPath<ImageEffect,String>)->some View{CookiesColorWell(title,selection:Binding(get:{Color(uiColor:UIColor(hex:effect[keyPath:key]))},set:{v in let hex=UIColor(v).hex;model.editImageEffect(id){$0[keyPath:key]=hex};model.colorStore.record(hex)}),supportsOpacity:false).font(.system(size:12)).padding(12).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:14))}
    var body:some View{VStack(spacing:12){
        if effect.kind == .blur{Picker("نوع التمويه",selection:Binding(get:{Int(effect.parameter1)},set:{v in model.editImageEffect(id){$0.parameter1=Double(v)}})){ForEach(Array(["ناعم","صلب","تكبير","دوران","حركة"].enumerated()),id:\.offset){i,name in Text(name).tag(i)}}.pickerStyle(.menu).accessibilityIdentifier("image-blur-mode")}
        if effect.kind != .duotone{knob(effect.kind.intensityLabel,\.intensity,effect.kind.range)}
        if [.chromatic,.slice,.fade,.halftone].contains(effect.kind) || (effect.kind == .blur && effect.parameter1>=2){knob("الزاوية",\.angle,effect.kind == .halftone ? 0...90:0...360)}
        if effect.kind == .vignette{knob("المنطقة الداخلية",\.parameter1,0...100)}
        if effect.kind == .grain{knob("حجم الحبيبات",\.parameter1,1...10)}
        if effect.kind == .fade{knob("جزيئات التلاشي",\.parameter2,0...100)}
        if effect.kind == .mirror{Picker("محور الانعكاس",selection:Binding(get:{Int(effect.parameter1)},set:{v in model.editImageEffect(id){$0.parameter1=Double(v)}})){Text("أفقي").tag(0);Text("عمودي").tag(1)}.pickerStyle(.segmented)}
        if [.glitch,.glow,.outline,.duotone].contains(effect.kind){color(effect.kind == .duotone ? "اللون الداكن":"اللون الأول",\.color)}
        if [.glitch,.duotone].contains(effect.kind){color(effect.kind == .duotone ? "اللون الفاتح":"اللون الثاني",\.color2)}
        knob("شفافية التأثير",\.opacity,0...1)
        if [.grain,.glitch,.fade].contains(effect.kind){Button{model.editImageEffect(id){$0.seed=$0.seed &+ 1}}label:{Label("توزيع جديد",systemImage:"shuffle")}.font(.system(size:12)).accessibilityIdentifier("image-effect-new-seed")}
    }}
}
private struct ImageEffectThumbnail:View {
    let kind:ImageEffectKind
    @State private var image:UIImage?
    private static let worker=DispatchQueue(label:"cookies.image.effect.cards",qos:.utility,autoreleaseFrequency:.workItem)
    private static let cache=NSCache<NSString,UIImage>()
    private static let context=CIContext(options:[.cacheIntermediates:false])
    var body:some View{ZStack{Color.white.opacity(0.04);if let image{Image(uiImage:image).resizable().scaledToFill()}else{Image(systemName:kind.icon).foregroundStyle(Palette.secondary)}}.task(id:kind){
        if let hit=Self.cache.object(forKey:kind.rawValue as NSString){image=hit;return}
        let value:UIImage=await withCheckedContinuation{continuation in Self.worker.async{
            let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
            let original=UIGraphicsImageRenderer(size:CGSize(width:160,height:92),format:format).image{r in
                let colors=[UIColor(hex:"18243B").cgColor,UIColor(hex:"D3A659").cgColor];if let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,1]){r.cgContext.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:160,y:92),options:[])};UIColor.white.withAlphaComponent(0.9).setFill();UIBezierPath(ovalIn:CGRect(x:22,y:16,width:48,height:48)).fill();UIColor(hex:"263B50").setFill();UIBezierPath(roundedRect:CGRect(x:72,y:44,width:65,height:36),cornerRadius:12).fill()
            }
            let result:UIImage=RenderBudget.screen(interactive:true){let graph=ImageEffectGraph.apply(CIImage(cgImage:original.cgImage!),effects:[ImageEffect(kind)],size:original.size);return Self.context.createCGImage(graph,from:CGRect(origin:.zero,size:original.size)).map{UIImage(cgImage:$0)} ?? original}
            Self.cache.totalCostLimit=2*1024*1024;Self.cache.setObject(result,forKey:kind.rawValue as NSString,cost:160*92*4);continuation.resume(returning:result)
        }};if !Task.isCancelled{image=value}
    }}
}
