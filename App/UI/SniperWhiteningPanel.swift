import SwiftUI

struct SniperWhiteningPanel:View {
    @ObservedObject var model:EditorModel
    @ObservedObject private var assets=BigLaMaAssets.shared
    @Environment(\.dismiss) private var dismiss
    private var selected:SniperTarget?{model.sniperTargets.first{$0.id==model.focusedSniperTarget} ?? model.sniperTargets.first}
    private var needsModel:Bool{model.sniperTargets.contains{$0.whiteningMethod == .bigLaMa && $0.restorationExecution == .device}}
    private var needsCloud:Bool{model.sniperTargets.contains{$0.whiteningMethod == .bigLaMa && $0.restorationExecution == .cloud}}
    var body:some View{NavigationStack{ZStack{Ambient();VStack(spacing:0){targetSelector.frame(height:104).padding(.horizontal,20).padding(.vertical,10).disabled(model.busy);ScrollView{VStack(alignment:.leading,spacing:20){
        SurfaceHeader(title:"تبييض الفقاعات",subtitle:"اختر طريقة مستقلة لكل فقاعة، ثم راجع النتيجة",icon:"eraser.fill")
        if model.sniperTargets.isEmpty{WorkspaceEmpty(title:"حدد فقاعة أولًا",detail:"المس داخلها بالقنص، أو ارسم حدودها يدويًا.",icon:"scope")}
        if let target=selected{
            methodSection(target)
            correctionSection(target)
        }
        if selected?.whiteningMethod == .bigLaMa || needsModel{BigLaMaModelCard()}
    }.padding(20).disabled(model.busy).frame(maxWidth:660).frame(maxWidth:.infinity)}.accessibilityIdentifier("whitening-settings-scroll")}}.foregroundStyle(Palette.pale).navigationTitle("التبييض").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarLeading){IconButton(icon:"chevron.right",title:"العودة"){dismiss()}.disabled(model.busy).accessibilityIdentifier("whitening-close")}}
    .safeAreaInset(edge:.bottom){VStack(spacing:10){if model.busy{HStack(spacing:12){ProgressView().tint(Palette.gold);Text("جارٍ تجهيز المعاينة…").font(.system(size:13));Spacer();Button("إيقاف"){model.cancelWhitening()}.buttonStyle(CapsuleActionStyle())}}else{Button{Task{await model.whitenSniperTargets();if !model.cleanCandidates.isEmpty{dismiss()}}}label:{Label("معاينة التبييض",systemImage:"sparkles")}.buttonStyle(GoldButtonStyle()).disabled(model.sniperTargets.isEmpty || (needsModel && (!assets.ready || assets.installing || assets.removing)) || (needsCloud && !CloudRestoration.configured)).accessibilityIdentifier("whitening-preview")};Text("لا تتغير الصورة الأصلية. يمكنك مقارنة النتيجة بالأصل أو إلغاء المعاينة.").font(.system(size:10)).foregroundStyle(Palette.secondary)}.padding(16).glass(0)}
    .interactiveDismissDisabled(model.busy)
    .onAppear{assets.refresh();normalizeUnavailableExecution();if !model.sniperTargets.contains(where:{$0.id==model.focusedSniperTarget}){model.focusedSniperTarget=model.sniperTargets.first?.id}}
    .onChange(of:assets.ready){_,_ in normalizeUnavailableExecution()}
    .alert("تعذر التبييض",isPresented:Binding(get:{model.error != nil},set:{if !$0{model.error=nil}})){Button("حسنًا"){model.error=nil}}message:{Text(model.error ?? "")}
    }.cookiesInterface()}
    private var targetSelector:some View{ScrollView(.horizontal,showsIndicators:false){HStack(spacing:10){ForEach(Array(model.sniperTargets.enumerated()),id:\.element.id){index,target in Button{model.focusedSniperTarget=target.id}label:{VStack(spacing:8){Text("\(index+1)").font(.system(size:20,weight:.semibold,design:.rounded));Image(systemName:target.whiteningMethod == .classic ? "eraser":"sparkles").font(.system(size:14));Text(target.whiteningMethod == .classic ? "معتاد":target.restorationExecution == .cloud && target.restorationProvider == .generative ? "توليدي":"ترميم").font(.system(size:10))}.frame(width:76,height:92).glass(18).overlay(RoundedRectangle(cornerRadius:18).stroke(selected?.id==target.id ? Palette.gold:.clear,lineWidth:1.5))}.buttonStyle(.plain).accessibilityIdentifier("whitening-target-\(index+1)").accessibilityValue(target.whiteningMethod.title+" · "+target.restorationExecution.title).accessibilityAddTraits(selected?.id==target.id ? .isSelected:[])}}}}
    private func methodSection(_ target:SniperTarget)->some View{GlassSection("الفقاعة المحددة",icon:"scope",subtitle:target.manuallySelected ? "محيط مرسوم يدويًا":"محيط القنص"){
                ForEach(BubbleWhiteningMethod.allCases){method in Button{setMethod(method,target:target.id)}label:{HStack(spacing:14){SurfaceSymbol(icon:method == .classic ? "eraser":"sparkles",size:40);VStack(alignment:.leading,spacing:5){Text(method.title).font(.system(size:14,weight:.semibold));Text(method == .classic ? "سريع ومناسب للخلفية البيضاء والمتجانسة":"خدمة تتطلب الإنترنت · ترميم الخلفية خلف النص").font(.system(size:11)).foregroundStyle(Palette.secondary)};Spacer();Image(systemName:target.whiteningMethod==method ? "checkmark.circle.fill":"circle").foregroundStyle(target.whiteningMethod==method ? Palette.gold:Palette.quiet)}.padding(12).background(.white.opacity(target.whiteningMethod==method ? 0.06:0.02),in:RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain).accessibilityIdentifier("whitening-method-\(method.rawValue)")}
                if target.whiteningMethod == .bigLaMa{executionSection(target)}
                Button("تطبيق هذه الطريقة على جميع الفقاعات"){for index in model.sniperTargets.indices{model.sniperTargets[index].whiteningMethod=target.whiteningMethod;model.sniperTargets[index].restorationExecution=target.restorationExecution;model.sniperTargets[index].restorationProvider=target.restorationProvider};WhiteningPreferences.remember(target.whiteningMethod);WhiteningPreferences.remember(target.restorationExecution,available:assets.ready);WhiteningPreferences.remember(target.restorationProvider)}.font(.system(size:12)).buttonStyle(CapsuleActionStyle())
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
        Text("طريقة الاتصال").font(.system(size:12,weight:.semibold))
        HStack(spacing:12){ForEach([RestorationExecution.cloud,.device]){execution in Button{setExecution(execution,target:target.id)}label:{Label(execution.title,systemImage:execution == .device ? "ipad.and.iphone":"network")}.buttonStyle(CapsuleActionStyle(selected:target.restorationExecution==execution)).disabled(execution == .device && (!assets.ready || assets.installing || assets.removing)).accessibilityIdentifier("whitening-execution-\(execution.rawValue)")}}
        Text(target.restorationExecution == .device ? "يُستخدم التنزيل المحفوظ على جهازك ولا تُرسل الصور. قد تتطلب المعالجة ذاكرة ووقتًا إضافيين.":"خدمة تتطلب الإنترنت. تُرسل منطقة الفقاعة وقناع النص فقط للمعالجة، ولا يُرسل الفصل كاملًا.").font(.system(size:11)).foregroundStyle(Palette.secondary).lineSpacing(4).accessibilityIdentifier("whitening-execution-explanation")
        if !assets.ready{Label("يتاح «دون إنترنت» بعد اكتمال التنزيل والتحقق منه أدناه.",systemImage:"arrow.down.circle").font(.system(size:11)).foregroundStyle(Palette.secondary)}
        if target.restorationExecution == .cloud && !CloudRestoration.configured{Text("خدمة الذكاء الاصطناعي غير مهيأة في هذه النسخة").font(.system(size:11)).foregroundStyle(Palette.secondary)}
        if target.restorationExecution == .cloud {
            Text("أسلوب الترميم لهذه الفقاعة").font(.system(size:12,weight:.semibold))
            ForEach(RestorationProvider.allCases){provider in
                Button{setProvider(provider,target:target.id)}label:{HStack(spacing:12){Image(systemName:provider == .balanced ? "circle.lefthalf.filled":"sparkles.rectangle.stack").frame(width:24);VStack(alignment:.leading,spacing:5){Text(provider.title).font(.system(size:13,weight:.semibold));Text(provider.detail).font(.system(size:11)).foregroundStyle(Palette.secondary).fixedSize(horizontal:false,vertical:true)};Spacer(minLength:4);Image(systemName:target.restorationProvider==provider ? "checkmark.circle.fill":"circle").foregroundStyle(target.restorationProvider==provider ? Palette.gold:Palette.quiet)}.padding(14).background(.white.opacity(target.restorationProvider==provider ? 0.07:0.025),in:RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain).accessibilityIdentifier("whitening-provider-\(provider.rawValue)").accessibilityValue(target.restorationProvider==provider ? "محدد":"غير محدد")
            }
            if target.restorationProvider == .generative{Text("هذا الأسلوب يحتاج الإنترنت. قارن المعاينة قبل الاعتماد؛ يمكنك تغيير الأسلوب للفقاعة نفسها. أخطاء الخدمة لا تُحسب كمعالجات ناجحة، وقد تتوقف الخدمة عند بلوغ ميزانية الاستضافة المشتركة.").font(.system(size:11)).foregroundStyle(Palette.secondary).lineSpacing(4)}
        }else{Text("يستخدم التنزيل على الجهاز أسلوب الترميم المتوازن. يبقى اختيار إعادة البناء محفوظًا عند العودة للإنترنت.").font(.system(size:11)).foregroundStyle(Palette.secondary)}
    }}
    private func normalizeUnavailableExecution(){guard !assets.ready else{return};for index in model.sniperTargets.indices where model.sniperTargets[index].restorationExecution == .device{model.sniperTargets[index].restorationExecution = .cloud}}
    private func setMethod(_ method:BubbleWhiteningMethod,target:UUID){guard let index=model.sniperTargets.firstIndex(where:{$0.id==target}),!model.busy else{return};model.sniperTargets[index].whiteningMethod=method;WhiteningPreferences.remember(method)}
    private func setExecution(_ execution:RestorationExecution,target:UUID){guard let index=model.sniperTargets.firstIndex(where:{$0.id==target}),!model.busy,execution != .device || (assets.ready && !assets.installing && !assets.removing) else{return};model.sniperTargets[index].restorationExecution=execution;WhiteningPreferences.remember(execution,available:assets.ready)}
    private func setProvider(_ provider:RestorationProvider,target:UUID){guard let index=model.sniperTargets.firstIndex(where:{$0.id==target}),!model.busy else{return};model.sniperTargets[index].restorationProvider=provider;WhiteningPreferences.remember(provider)}
    private func draw(_ mode:ManualSniperTool,target:UUID){guard !model.busy else{return};model.beginManualSniper(mode,replacing:target,returnToWhitening:true);dismiss()}
}
