import SwiftUI

struct SniperWhiteningPanel:View {
    @ObservedObject var model:EditorModel
    @ObservedObject private var assets=BigLaMaAssets.shared
    @Environment(\.dismiss) private var dismiss
    private var selected:SniperTarget?{model.sniperTargets.first{$0.id==model.focusedSniperTarget} ?? model.sniperTargets.first}
    private var needsModel:Bool{model.sniperTargets.contains{$0.whiteningMethod == .bigLaMa && $0.restorationExecution == .device}}
    private var needsCloud:Bool{model.sniperTargets.contains{$0.whiteningMethod == .bigLaMa && $0.restorationExecution == .cloud}}
    var body:some View{NavigationStack{ZStack{Ambient();VStack(spacing:0){targetSelector.padding(.horizontal,20).padding(.vertical,10);ScrollView{VStack(alignment:.leading,spacing:20){
        SurfaceHeader(title:"تبييض الفقاعات",subtitle:"اختر طريقة مستقلة لكل فقاعة، ثم راجع النتيجة",icon:"eraser.fill")
        if model.sniperTargets.isEmpty{WorkspaceEmpty(title:"حدد فقاعة أولًا",detail:"المس داخلها بالقنص، أو ارسم حدودها يدويًا.",icon:"scope")}
        if let target=selected{
            methodSection(target)
            correctionSection(target)
        }
        if needsModel{BigLaMaModelCard()}
    }.padding(20).disabled(model.busy).frame(maxWidth:660).frame(maxWidth:.infinity)}.accessibilityIdentifier("whitening-settings-scroll")}}.foregroundStyle(Palette.pale).navigationTitle("التبييض").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}.disabled(model.busy).accessibilityIdentifier("whitening-close")}}
    .safeAreaInset(edge:.bottom){VStack(spacing:10){if model.busy{HStack(spacing:12){ProgressView().tint(Palette.gold);Text("جارٍ تجهيز المعاينة…").font(.system(size:13));Spacer();Button("إيقاف"){model.cancelWhitening()}.buttonStyle(CapsuleActionStyle())}}else{Button{Task{await model.whitenSniperTargets();if !model.cleanCandidates.isEmpty{dismiss()}}}label:{Label("معاينة التبييض",systemImage:"sparkles")}.buttonStyle(GoldButtonStyle()).disabled(model.sniperTargets.isEmpty || (needsModel && (!assets.ready || assets.installing)) || (needsCloud && !CloudRestoration.configured)).accessibilityIdentifier("whitening-preview")};Text("لا تتغير الصورة الأصلية. يمكنك مقارنة النتيجة بالأصل أو إلغاء المعاينة.").font(.system(size:10)).foregroundStyle(Palette.secondary)}.padding(16).glass(0)}
    .interactiveDismissDisabled(model.busy)
    .onAppear{assets.refresh();if !model.sniperTargets.contains(where:{$0.id==model.focusedSniperTarget}){model.focusedSniperTarget=model.sniperTargets.first?.id}}
    .alert("تعذر التبييض",isPresented:Binding(get:{model.error != nil},set:{if !$0{model.error=nil}})){Button("حسنًا"){model.error=nil}}message:{Text(model.error ?? "")}
    }.cookiesInterface()}
    private var targetSelector:some View{ScrollView(.horizontal,showsIndicators:false){HStack(spacing:10){ForEach(Array(model.sniperTargets.enumerated()),id:\.element.id){index,target in Button{model.focusedSniperTarget=target.id}label:{VStack(spacing:8){Text("\(index+1)").font(.system(size:20,weight:.semibold,design:.rounded));Image(systemName:target.whiteningMethod == .classic ? "eraser":"sparkles").font(.system(size:14));Text(target.whiteningMethod == .classic ? "معتاد":"ترميم").font(.system(size:10))}.frame(width:76,height:92).glass(18).overlay(RoundedRectangle(cornerRadius:18).stroke(selected?.id==target.id ? Palette.gold:.clear,lineWidth:1.5))}.buttonStyle(.plain).accessibilityIdentifier("whitening-target-\(index+1)").accessibilityValue("\(target.whiteningMethod.rawValue)/\(target.restorationExecution.rawValue)").accessibilityAddTraits(selected?.id==target.id ? .isSelected:[])}}}}
    private func methodSection(_ target:SniperTarget)->some View{GlassSection("الفقاعة المحددة",icon:"scope",subtitle:target.manuallySelected ? "محيط مرسوم يدويًا":"محيط القنص"){
                ForEach(BubbleWhiteningMethod.allCases){method in Button{setMethod(method,target:target.id)}label:{HStack(spacing:14){SurfaceSymbol(icon:method == .classic ? "eraser":"sparkles",size:40);VStack(alignment:.leading,spacing:5){Text(method.title).font(.system(size:14,weight:.semibold));Text(method == .classic ? "سريع ومناسب للخلفية البيضاء والمتجانسة":"يعيد بناء الخلفية الملونة خلف النص").font(.system(size:11)).foregroundStyle(Palette.secondary)};Spacer();Image(systemName:target.whiteningMethod==method ? "checkmark.circle.fill":"circle").foregroundStyle(target.whiteningMethod==method ? Palette.gold:Palette.quiet)}.padding(12).background(.white.opacity(target.whiteningMethod==method ? 0.06:0.02),in:RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain).accessibilityIdentifier("whitening-method-\(method.rawValue)")}
                if target.whiteningMethod == .bigLaMa{executionSection(target)}
                Button("تطبيق هذه الطريقة على جميع الفقاعات"){for index in model.sniperTargets.indices{model.sniperTargets[index].whiteningMethod=target.whiteningMethod;model.sniperTargets[index].restorationExecution=target.restorationExecution}}.font(.system(size:12)).buttonStyle(CapsuleActionStyle())
            }}
    private func correctionSection(_ target:SniperTarget)->some View{GlassSection("تصحيح التحديد",icon:"pencil.and.outline"){
                HStack(spacing:12){Button{draw(.rectangle,target:target.id)}label:{Label("مستطيل",systemImage:"rectangle.dashed")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("whitening-manual-rectangle");Button{draw(.freehand,target:target.id)}label:{Label("محيط حر",systemImage:"lasso")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("whitening-manual-freehand")}
                if target.whiteningMethod == .bigLaMa{
                    Text("إذا لم يلتقط الكاشف كل الحروف، ارسم مستطيلًا حول النص. يمكنك تكرار الرسم لعدة أسطر؛ سيبقى محيط الفقاعة محميًا.").font(.system(size:12)).foregroundStyle(Palette.secondary).lineSpacing(4)
                    Button{draw(.textRectangle,target:target.id)}label:{Label("تحديد منطقة النص",systemImage:"text.viewfinder")}.buttonStyle(CapsuleActionStyle()).accessibilityIdentifier("whitening-manual-text")
                    if !target.manualTextRegions.isEmpty{HStack{Text("\(target.manualTextRegions.count) مناطق نص يدوية").font(.system(size:11));Spacer();Button("العودة للكشف التلقائي"){if let index=model.sniperTargets.firstIndex(where:{$0.id==target.id}){model.sniperTargets[index].manualTextRegions=[]}}.font(.system(size:11))}}
                }
                Button(role:.destructive){model.sniperTargets.removeAll{$0.id==target.id};model.focusedSniperTarget=model.sniperTargets.first?.id}label:{Label("إزالة هذه الفقاعة من التحديد",systemImage:"minus.circle")}.buttonStyle(CapsuleActionStyle())
            }}
    private func executionSection(_ target:SniperTarget)->some View{VStack(alignment:.leading,spacing:12){
        Text("مكان التنفيذ لهذه الفقاعة").font(.system(size:12,weight:.semibold))
        HStack(spacing:12){ForEach(RestorationExecution.allCases){execution in Button{if let index=model.sniperTargets.firstIndex(where:{$0.id==target.id}){model.sniperTargets[index].restorationExecution=execution}}label:{Label(execution.title,systemImage:execution == .device ? "ipad.and.iphone":"cloud")}.buttonStyle(CapsuleActionStyle(selected:target.restorationExecution==execution)).accessibilityIdentifier("whitening-execution-\(execution.rawValue)")}}
        Text(target.restorationExecution == .device ? "يعمل دون إنترنت بعد تنزيل النموذج. إذا لم تكفِ ذاكرة الجهاز، اختر التنفيذ السحابي.":"لا يحتاج تنزيل النموذج. تُرسل منطقة الفقاعة وقناع النص فقط إلى خدمة الترميم، ولا تُحفظ صورك على الخادم.").font(.system(size:11)).foregroundStyle(Palette.secondary).lineSpacing(4).accessibilityIdentifier("whitening-execution-explanation")
        if target.restorationExecution == .cloud && !CloudRestoration.configured{Text("الخدمة السحابية غير مهيأة في هذه النسخة").font(.system(size:11)).foregroundStyle(Palette.secondary)}
    }}
    private func setMethod(_ method:BubbleWhiteningMethod,target:UUID){guard let index=model.sniperTargets.firstIndex(where:{$0.id==target}),!model.busy else{return};model.sniperTargets[index].whiteningMethod=method}
    private func draw(_ mode:ManualSniperTool,target:UUID){guard !model.busy else{return};model.beginManualSniper(mode,replacing:target,returnToWhitening:true);dismiss()}
}
