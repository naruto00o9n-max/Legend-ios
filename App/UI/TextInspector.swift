import SwiftUI

struct TextInspector:View {
    @ObservedObject var model:EditorModel;var panel:Panel
    @Environment(\.dismiss) var dismiss
    var close:(()->Void)? = nil
    @State private var texturePicker=false
    @State private var fontLibrary=false
    @AppStorage("editor-panel-density") private var panelDensity=1.0
    @State private var textRange=NSRange(location:0,length:0)
    @State private var rangeColor=Color.white
    @State private var rangeSize=48.0
    @State private var rangeBold=false
    @State private var rangeFormatting=false
    @State private var selectedLineOnly=false
    @AppStorage("text-inline-dock") private var docking="bottom"
    var style:TextStyle {model.active?.style ?? TextStyle()}
    func value(_ key:WritableKeyPath<TextStyle,Double>)->Binding<Double>{Binding(get:{style[keyPath:key]},set:{v in model.change{$0.style[keyPath:key]=v}})}
    func flag(_ key:WritableKeyPath<TextStyle,Bool>)->Binding<Bool>{Binding(get:{style[keyPath:key]},set:{v in model.change{$0.style[keyPath:key]=v}})}
    var body:some View {VStack(spacing:0){HStack{Text(panel.title).font(.system(size:15,weight:.semibold));Spacer();IconButton(icon:"checkmark",title:"تم"){model.commitTextMask();model.save();model.gradientTarget=nil;model.textMaskMode=false;if let close{close()}else{dismiss()}}.accessibilityIdentifier("text-inspector-close")}.padding(.horizontal,18).frame(height:52)
        ScrollView{VStack(alignment:.leading,spacing:18*min(1.15,max(0.85,panelDensity))){content}.padding(.horizontal,20*min(1.15,max(0.85,panelDensity))).padding(.bottom,24)}.accessibilityIdentifier("text-inspector-scroll")
    }.foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.75)).glass(28).ignoresSafeArea(edges:.bottom).onAppear{model.checkpoint()}.onDisappear{if panel == .mask{model.commitTextMask()}}.scrollDismissesKeyboard(.interactively)
        .sheet(isPresented:$fontLibrary){FontLibraryView(onSelect:{name in model.change{$0.style.fontPath=name}},currentFont:style.fontPath)}
        .sheet(isPresented:$texturePicker){PhotoLibraryPicker{result in
            switch result{case .failure(let error):model.error=error.localizedDescription;case .success(let urls):if let url=urls.first{defer{try? FileManager.default.removeItem(at:url)};do{let name=UUID().uuidString+"."+url.pathExtension;try FileManager.default.copyItem(at:url,to:model.directory.appendingPathComponent(name));model.change{$0.style.texturePath=name}}catch{model.error=error.localizedDescription}}}
        }}
    }
    @ViewBuilder var content:some View {
        switch panel {
        case .content:ArabicTextEditor(text:Binding(get:{model.active?.textContent ?? ""},set:{v in model.change{layer in layer.style.spans=TextRanges.adjusted(layer.style.spans,from:layer.textContent,to:v);layer.textContent=v}}),layer:model.active,selectionChanged:{textRange=$0;model.textSelection=$0;model.textSelectionLayer=model.selected},requestedSelection:textRange).frame(minHeight:140).padding(12).glass(16).accessibilityIdentifier("text-input")
            ScrollView(.horizontal,showsIndicators:false){HStack(spacing:16){
                Button{copySelection()}label:{Label("نسخ",systemImage:"doc.on.doc")}
                Button{if let text=UIPasteboard.general.string{replaceSelection(text)}}label:{Label("لصق",systemImage:"doc.on.clipboard")}
                Button{copySelection();if textRange.length>0{replaceSelection("")}}label:{Label("قص",systemImage:"scissors")}.disabled(textRange.length==0)
                Button("ABC"){changeCase(upper:true)};Button("abc"){changeCase(upper:false)};Button("ـ"){replaceSelection("ـ")}
                Button{docking=docking=="bottom" ? "top":"bottom"}label:{Label("إرساء",systemImage:docking=="bottom" ? "arrow.up.to.line":"arrow.down.to.line")}
            }.font(.system(size:11)).padding(.vertical,4)}
            DisclosureGroup("تنسيق التحديد (\(textRange.length) حرف)",isExpanded:$rangeFormatting){
                ColorPicker("لون التحديد",selection:$rangeColor,supportsOpacity:false);Toggle("التحديد غامق",isOn:$rangeBold);knob("حجم التحديد",$rangeSize,8...240)
                Button("تطبيق على التحديد"){if textRange.length>0{model.change{$0.style.spans.append(TextRun(start:textRange.location,end:textRange.location+textRange.length,color:UIColor(rangeColor).hex,fontSize:rangeSize,isBold:rangeBold))}}}.disabled(textRange.length==0)
                Button("مسح تنسيق التحديد"){let start=textRange.location,end=start+textRange.length;model.change{$0.style.spans.removeAll{$0.start<end && $0.end>start}}}.disabled(textRange.length==0)
            }.font(.system(size:12))
        case .font:
            Button{fontLibrary=true}label:{Label("الخطوط · بحث ومفضلة واستيراد",systemImage:"textformat.alt")}.buttonStyle(.bordered).accessibilityIdentifier("editor-font-library")
            ForEach((Fonts.files+Fonts.otf).sorted{$0.lastPathComponent<$1.lastPathComponent},id:\.self){url in Button{model.change{$0.style.fontPath=url.lastPathComponent};var recent=UserDefaults.standard.stringArray(forKey:"fontRecent") ?? [];recent.removeAll{$0==url.lastPathComponent};recent.insert(url.lastPathComponent,at:0);UserDefaults.standard.set(Array(recent.prefix(30)),forKey:"fontRecent")}label:{HStack{Text("حروف تصنع الحوار - "+url.deletingPathExtension().lastPathComponent).font(Font(Fonts.font({var s=style;s.fontPath=url.lastPathComponent;s.fontSize=20;return s}())));Spacer();if style.fontPath==url.lastPathComponent{Image(systemName:"checkmark")}}.padding(12).glass(14)}}
        case .format:
            knob("الحجم",value(\.fontSize),8...240);knob("عرض النص",value(\.boxWidth),40...Double(model.page.width))
            HStack{Toggle("غامق",isOn:flag(\.isBold));Toggle("مائل",isOn:flag(\.isItalic))}.toggleStyle(.button)
            HStack{Toggle("تسطير",isOn:flag(\.isUnderline));Toggle("شطب",isOn:flag(\.isStrikeThrough))}.toggleStyle(.button)
            Picker("المحاذاة",selection:Binding(get:{style.alignment},set:{v in model.change{$0.style.alignment=v}})){Text("يسار").tag(0);Text("وسط").tag(1);Text("يمين").tag(2);Text("ضبط").tag(3)}.pickerStyle(.segmented)
            Toggle("تنسيق السطر المحدد فقط",isOn:$selectedLineOnly).font(.system(size:12)).disabled(model.textSelectionLayer != model.selected)
            HStack{Button("تنسيق مربع"){typeset("box")};Button("تنسيق دائري"){typeset("circle")};Button("الكشيدة"){typeset("kashida")}}.font(.system(size:12))
        case .color:
            swatches(model.active?.kind == .shape ? "لون الشكل":"لون النص",\.color)
            if model.active?.kind == .text{GradientControls(model:model,colors:\.textGradient,stops:\.textGradientStops,angle:\.textGradientAngle,type:\.textGradientType)}
        case .gradientMap:GradientMapView(model:model)
        case .stroke:
            if model.active?.kind == .text{ForEach(style.extraStrokes ?? []){outline in ExtraOutlineControls(model:model,id:outline.id)}
            Button("إضافة حد"){model.change{$0.style.extraStrokes=($0.style.extraStrokes ?? [])+[ExtraOutline(width:6,color:"FFFFFF")]}}.disabled((style.extraStrokes?.count ?? 0)>=8)}
            knob("السماكة",value(\.strokeWidth),0...18);swatches("لون الحدود",\.strokeColor);if model.active?.kind == .text{GradientControls(model:model,colors:\.strokeGradient,stops:\.strokeGradientStops,angle:\.strokeGradientAngle,type:\.strokeGradientType)}
        case .background:knob("الشفافية",Binding(get:{Double(style.backgroundAlpha)},set:{v in model.change{$0.style.backgroundAlpha=Int(v)}}),0...255);knob("الاستدارة",value(\.backgroundCornerRadius),0...80);swatches("الخلفية",\.backgroundColor);knob("الحشو أفقيًا",value(\.backgroundPaddingX),0...100);knob("الحشو رأسيًا",value(\.backgroundPaddingY),0...100)
        case .shadow:GradientControls(model:model,colors:\.shadowGradient,stops:\.shadowGradientStops,angle:\.shadowGradientAngle,type:\.shadowGradientType);knob("النعومة",value(\.shadowRadius),0...50);knob("أفقي",value(\.shadowDx),-80...80);knob("رأسي",value(\.shadowDy),-80...80);swatches("لون الظل",\.shadowColor);knob("شفافية الظل",Binding(get:{Double(style.shadowAlpha)},set:{v in model.change{$0.style.shadowAlpha=Int(v)}}),0...255)
        case .position:
            knob("الموضع أفقيًا",Binding(get:{model.active?.frame.x ?? 0},set:{v in model.change{$0.frame.x=v}}),-Double(model.page.width)...Double(model.page.width))
            knob("الموضع رأسيًا",Binding(get:{model.active?.frame.y ?? 0},set:{v in model.change{$0.frame.y=v}}),-Double(model.page.height)...Double(model.page.height))
            Toggle("مسطرة حدود النص",isOn:Binding(get:{style.rulerEnabled ?? false},set:{v in model.change{$0.style.rulerEnabled=v}}))
            if model.active?.kind == .text{Button("تحويل النص إلى طبقة PNG"){Task{await model.rasterizeText()}}}
            HStack{Button("توسيط أفقي"){model.change{$0.frame.x=(Double(model.page.width)-Double(LayerRenderer.bounds($0).width))/2}};Button("توسيط رأسي"){model.change{$0.frame.y=(Double(model.page.height)-Double(LayerRenderer.bounds($0).height))/2}}}.font(.system(size:12))
            HStack{Button("قلب أفقي"){model.change{$0.scaleX *= -1}};Button("قلب رأسي"){model.change{$0.scaleY *= -1}};Button("←"){model.change{$0.frame.x-=1}};Button("→"){model.change{$0.frame.x+=1}};Button("↑"){model.change{$0.frame.y-=1}};Button("↓"){model.change{$0.frame.y+=1}}}.font(.system(size:12))
            knob("الدوران",Binding(get:{model.active?.rotation ?? 0},set:{v in model.change{$0.rotation=v}}),-180...180)
            knob("الحجم أفقيًا",Binding(get:{abs(model.active?.scaleX ?? 1)},set:{v in model.change{$0.scaleX=($0.scaleX<0 ? -1:1)*v}}),0.1...6)
            knob("الحجم رأسيًا",Binding(get:{abs(model.active?.scaleY ?? 1)},set:{v in model.change{$0.scaleY=($0.scaleY<0 ? -1:1)*v}}),0.1...6)
        case .spacing:knob("بين الحروف",value(\.letterSpacing),-4...20);knob("بين الأسطر",value(\.lineSpacing),0...60);knob("إزاحة التشكيل",Binding(get:{style.tashkeelOffset ?? 0},set:{v in model.change{$0.style.tashkeelOffset=v}}),-20...20)
        case .threeD:knob("عمق البروز",Binding(get:{Double(style.threeDDepth)},set:{v in model.change{$0.style.threeDDepth=Int(v)}}),0...40);swatches("لون البروز",\.threeDColor)
        case .effects:
            Picker("التأثير",selection:Binding(get:{style.effectType},set:{v in model.change{$0.style.effectType=v}})){ForEach(TextEffect.allCases,id:\.self){Text($0.title).tag($0)}}.pickerStyle(.menu)
            knob("القوة",value(\.effectValue),0...50);knob("التفاصيل",value(\.effectDetail),2...20);swatches("لون التأثير",\.effectColor)
        case .opacity:
            knob("شفافية الحروف",Binding(get:{style.innerOpacity ?? 1},set:{v in model.change{$0.style.innerOpacity=v}}),0...1)
            knob("تلاشي الحروف",Binding(get:{style.fadeAmount ?? 0},set:{v in model.change{$0.style.fadeAmount=v}}),0...1)
            knob("اتجاه التلاشي",Binding(get:{style.fadeAngle ?? 0},set:{v in model.change{$0.style.fadeAngle=v}}),0...360)
            knob("شفافية الطبقة",Binding(get:{model.active?.opacity ?? 1},set:{v in model.change{$0.opacity=v}}),0...1)
            Picker("المزج",selection:Binding(get:{model.active?.blend ?? .normal},set:{v in model.change{$0.blend=v}})){ForEach(Blend.allCases,id:\.self){Text($0.title).tag($0)}}.pickerStyle(.menu)
        case .mask:
            Toggle("مسح حروف النص بالإصبع",isOn:Binding(get:{model.textMaskMode},set:{enabled in if enabled{model.beginTextMask()}else{model.commitTextMask()}}))
            if model.textMaskMode{HStack{Button("اعتماد المسح"){model.commitTextMask()};Button("إلغاء تغييرات المسح",role:.cancel){model.cancelTextMask()}};Toggle("استرجاع الحروف بدل المسح",isOn:$model.textMaskRestore);knob("حجم قلم القناع",$model.brushWidth,1...160);Button("إعادة القناع كاملًا"){model.checkpoint();model.change{$0.textMask=[]}};Text("ارسم على النص داخل اللوحة؛ استرجاع القناع يعيد الحروف الأصلية فقط.").font(.system(size:12)).foregroundStyle(Palette.quiet)}
            Toggle("تفعيل قناع دائري",isOn:Binding(get:{model.active?.isMaskEnabled ?? false},set:{v in model.change{$0.isMaskEnabled=v}}));knob("نصف القطر",Binding(get:{model.active?.maskRadius ?? 80},set:{v in model.change{$0.maskRadius=v}}),5...400)
            knob("المركز أفقيًا",Binding(get:{model.active?.maskX ?? 0},set:{v in model.change{$0.maskX=v}}),0...500);knob("المركز رأسيًا",Binding(get:{model.active?.maskY ?? 0},set:{v in model.change{$0.maskY=v}}),0...500)
        case .styles:
            StyleLibraryView(model:model)
        case .perspective:GeometryInspector(model:model);knob("دوران أفقي ثلاثي الأبعاد",value(\.rotationY),-70...70);knob("دوران رأسي ثلاثي الأبعاد",value(\.rotationX),-70...70)
        case .texture:
            Button("استيراد خامة من الصور"){texturePicker=true}.buttonStyle(GoldButtonStyle())
            if !style.texturePath.isEmpty{knob("الحجم أفقيًا",value(\.textureScaleX),0.1...5);knob("الحجم رأسيًا",value(\.textureScaleY),0.1...5);knob("دوران الخامة",value(\.textureRotation),-180...180);knob("إزاحة أفقية",value(\.textureTranslationX),-500...500);knob("إزاحة رأسية",value(\.textureTranslationY),-500...500);Button("إزالة الخامة"){model.change{$0.style.texturePath=""}}}
        }
    }
    private func typeset(_ mode:String){
        guard let layer=model.active else{return};let formatter=Typesetter(measure:{Double(($0 as NSString).size(withAttributes:[.font:Fonts.font(layer.style)]).width)})
        let source=layer.textContent as NSString
        let range=selectedLineOnly && model.textSelectionLayer==layer.id ? source.lineRange(for:NSRange(location:min(source.length,model.textSelection.location),length:min(model.textSelection.length,max(0,source.length-model.textSelection.location)))):NSRange(location:0,length:source.length)
        let original=source.substring(with:range)
        var transformed=mode=="circle" ? formatter.circle(original,width:layer.style.boxWidth,fontSize:layer.style.fontSize):formatter.box(original,width:layer.style.boxWidth,tatweel:mode=="kashida")
        if selectedLineOnly,original.hasSuffix("\n"),!transformed.hasSuffix("\n"){transformed+="\n"}
        let text=source.replacingCharacters(in:range,with:transformed);model.checkpoint();model.change{$0.style.spans=TextRanges.adjusted($0.style.spans,from:$0.textContent,to:text);$0.textContent=text}
    }

    func copySelection(){guard let layer=model.active else{return};let source=layer.textContent as NSString,start=min(source.length,max(0,textRange.location)),length=min(textRange.length,source.length-start);UIPasteboard.general.string=length>0 ? source.substring(with:NSRange(location:start,length:length)):layer.textContent}
    func replaceSelection(_ value:String,range:NSRange?=nil){guard let layer=model.active else{return};let result=TextRanges.replacement(layer.textContent,range:range ?? textRange,with:value,spans:layer.style.spans);model.change{$0.textContent=result.0;$0.style.spans=result.1};textRange=result.2;model.textSelection=result.2;model.textSelectionLayer=model.selected}
    func changeCase(upper:Bool){guard let layer=model.active else{return};let source=layer.textContent as NSString,start=min(source.length,max(0,textRange.location)),length=min(textRange.length,source.length-start),range=length>0 ? NSRange(location:start,length:length):NSRange(location:0,length:source.length);let selected=source.substring(with:range);replaceSelection(upper ? selected.uppercased():selected.lowercased(),range:range)}
    func knob(_ label:String,_ source:Binding<Double>,_ range:ClosedRange<Double>)->some View{let binding=Binding<Double>(get:{min(range.upperBound,max(range.lowerBound,source.wrappedValue))},set:{source.wrappedValue=min(range.upperBound,max(range.lowerBound,$0))});return VStack(alignment:.leading,spacing:8){HStack{Text(label).font(.system(size:12));Spacer();TextField(label,value:binding,format:.number.precision(.fractionLength(0...1))).font(.system(size:12,design:.monospaced)).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).frame(width:70).accessibilityIdentifier("value-\(label)")};Slider(value:binding,in:range).tint(Palette.gold)}.padding(12).glass(16)}
    func swatches(_ label:String,_ key:WritableKeyPath<TextStyle,String>)->some View {VStack(alignment:.leading,spacing:12){Text(label).font(.system(size:12));HStack(spacing:12){ForEach(["FFFFFF","000000","D4AF37","F5DF99","E74646","46A4D8","7957B7"],id:\.self){hex in Button{model.change{$0.style[keyPath:key]=hex}}label:{Circle().fill(Color(uiColor:UIColor(hex:hex))).frame(width:26,height:26).overlay(Circle().stroke(style[keyPath:key]==hex ? Palette.gold:.clear,lineWidth:3))}}}.environment(\.layoutDirection,.leftToRight);ColorPicker("لون مخصص",selection:Binding(get:{Color(uiColor:UIColor(hex:style[keyPath:key]))},set:{v in model.change{$0.style[keyPath:key]=UIColor(v).hex}}),supportsOpacity:false).font(.system(size:12))}.padding(12).glass(16)}
}
