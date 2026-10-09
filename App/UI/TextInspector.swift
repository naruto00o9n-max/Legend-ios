import SwiftUI

struct TextInspector:View {
    @ObservedObject var model:EditorModel;var panel:Panel
    @Environment(\.dismiss) var dismiss
    var close:(()->Void)? = nil
    @State private var texturePicker=false
    var style:TextStyle {model.active?.style ?? TextStyle()}
    func value(_ key:WritableKeyPath<TextStyle,Double>)->Binding<Double>{Binding(get:{style[keyPath:key]},set:{v in model.change{$0.style[keyPath:key]=v}})}
    func flag(_ key:WritableKeyPath<TextStyle,Bool>)->Binding<Bool>{Binding(get:{style[keyPath:key]},set:{v in model.change{$0.style[keyPath:key]=v}})}
    var body:some View {VStack(spacing:0){HStack{Text(panel.title).font(.system(size:15,weight:.semibold));Spacer();IconButton(icon:"checkmark",title:"تم"){model.save();if let close{close()}else{dismiss()}}}.padding(.horizontal,18).frame(height:52)
        ScrollView{VStack(alignment:.leading,spacing:18){content}.padding(.horizontal,20).padding(.bottom,24)}
    }.foregroundStyle(Palette.pale).background(Palette.ink.opacity(0.75)).glass(28).ignoresSafeArea(edges:.bottom).onAppear{model.checkpoint()}.scrollDismissesKeyboard(.interactively)
        .sheet(isPresented:$texturePicker){PhotoLibraryPicker{result in
            switch result{case .failure(let error):model.error=error.localizedDescription;case .success(let urls):if let url=urls.first{defer{try? FileManager.default.removeItem(at:url)};do{let name=UUID().uuidString+"."+url.pathExtension;try FileManager.default.copyItem(at:url,to:model.directory.appendingPathComponent(name));model.change{$0.style.texturePath=name}}catch{model.error=error.localizedDescription}}}
        }}
    }
    @ViewBuilder var content:some View {
        switch panel {
        case .content:ArabicTextEditor(text:Binding(get:{model.active?.textContent ?? ""},set:{v in model.change{$0.textContent=v}})).frame(minHeight:140).padding(12).glass(16).accessibilityIdentifier("text-input")
        case .font:
            ForEach((Fonts.files+Fonts.otf).sorted{$0.lastPathComponent<$1.lastPathComponent},id:\.self){url in Button{model.change{$0.style.fontPath=url.lastPathComponent}}label:{HStack{Text("حروف تصنع الحوار").font(Font(Fonts.font({var s=style;s.fontPath=url.lastPathComponent;s.fontSize=20;return s}())));Spacer();if style.fontPath==url.lastPathComponent{Image(systemName:"checkmark")}}.padding(12).glass(14)}}
        case .format:
            knob("الحجم",value(\.fontSize),8...240);knob("عرض النص",value(\.boxWidth),40...Double(model.page.width))
            HStack{Toggle("غامق",isOn:flag(\.isBold));Toggle("مائل",isOn:flag(\.isItalic))}.toggleStyle(.button)
            HStack{Toggle("تسطير",isOn:flag(\.isUnderline));Toggle("شطب",isOn:flag(\.isStrikeThrough))}.toggleStyle(.button)
            Picker("المحاذاة",selection:Binding(get:{style.alignment},set:{v in model.change{$0.style.alignment=v}})){Text("يسار").tag(0);Text("وسط").tag(1);Text("يمين").tag(2);Text("ضبط").tag(3)}.pickerStyle(.segmented)
        case .color:
            swatches("لون النص",\.color)
            Toggle("تدرج لوني",isOn:Binding(get:{!style.textGradient.isEmpty},set:{v in model.change{$0.style.textGradient=v ? ["D4AF37","FFFFFF"]:[]}}))
            if !style.textGradient.isEmpty {ForEach(0..<2,id:\.self){index in ColorPicker(index==0 ? "البداية":"النهاية",selection:Binding(get:{Color(uiColor:UIColor(hex:style.textGradient[index]))},set:{v in model.change{$0.style.textGradient[index]=UIColor(v).hex}}),supportsOpacity:false)};knob("زاوية التدرج",value(\.textGradientAngle),0...360)}
        case .stroke:knob("السماكة",value(\.strokeWidth),0...18);swatches("لون الحدود",\.strokeColor)
        case .background:knob("الشفافية",Binding(get:{Double(style.backgroundAlpha)},set:{v in model.change{$0.style.backgroundAlpha=Int(v)}}),0...255);knob("الاستدارة",value(\.backgroundCornerRadius),0...80);swatches("الخلفية",\.backgroundColor)
        case .shadow:knob("النعومة",value(\.shadowRadius),0...50);knob("أفقي",value(\.shadowDx),-80...80);knob("رأسي",value(\.shadowDy),-80...80);swatches("لون الظل",\.shadowColor)
        case .position:
            knob("الدوران",Binding(get:{model.active?.rotation ?? 0},set:{v in model.change{$0.rotation=v}}),-180...180)
            knob("الحجم أفقيًا",Binding(get:{model.active?.scaleX ?? 1},set:{v in model.change{$0.scaleX=v}}),0.1...6)
            knob("الحجم رأسيًا",Binding(get:{model.active?.scaleY ?? 1},set:{v in model.change{$0.scaleY=v}}),0.1...6)
        case .spacing:knob("بين الحروف",value(\.letterSpacing),-4...20);knob("بين الأسطر",value(\.lineSpacing),0...60)
        case .threeD:knob("عمق البروز",Binding(get:{Double(style.threeDDepth)},set:{v in model.change{$0.style.threeDDepth=Int(v)}}),0...40);swatches("لون البروز",\.threeDColor)
        case .effects:
            Picker("التأثير",selection:Binding(get:{style.effectType},set:{v in model.change{$0.style.effectType=v}})){ForEach(TextEffect.allCases,id:\.self){Text($0.title).tag($0)}}.pickerStyle(.menu)
            knob("القوة",value(\.effectValue),0...50);knob("التفاصيل",value(\.effectDetail),2...20);swatches("لون التأثير",\.effectColor)
        case .opacity:
            knob("شفافية الطبقة",Binding(get:{model.active?.opacity ?? 1},set:{v in model.change{$0.opacity=v}}),0...1)
            Picker("المزج",selection:Binding(get:{model.active?.blend ?? .normal},set:{v in model.change{$0.blend=v}})){ForEach(Blend.allCases,id:\.self){Text($0.title).tag($0)}}.pickerStyle(.menu)
        case .mask:
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
    func knob(_ label:String,_ source:Binding<Double>,_ range:ClosedRange<Double>)->some View{let binding=Binding<Double>(get:{min(range.upperBound,max(range.lowerBound,source.wrappedValue))},set:{source.wrappedValue=min(range.upperBound,max(range.lowerBound,$0))});return VStack(alignment:.leading,spacing:8){HStack{Text(label).font(.system(size:12));Spacer();TextField(label,value:binding,format:.number.precision(.fractionLength(0...1))).font(.system(size:12,design:.monospaced)).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).frame(width:70).accessibilityIdentifier("value-\(label)")};Slider(value:binding,in:range).tint(Palette.gold)}.padding(12).glass(16)}
    func swatches(_ label:String,_ key:WritableKeyPath<TextStyle,String>)->some View {VStack(alignment:.leading,spacing:12){Text(label).font(.system(size:12));HStack(spacing:12){ForEach(["FFFFFF","000000","D4AF37","F5DF99","E74646","46A4D8","7957B7"],id:\.self){hex in Button{model.change{$0.style[keyPath:key]=hex}}label:{Circle().fill(Color(uiColor:UIColor(hex:hex))).frame(width:26,height:26).overlay(Circle().stroke(style[keyPath:key]==hex ? Palette.gold:.clear,lineWidth:3))}}}.environment(\.layoutDirection,.leftToRight);ColorPicker("لون مخصص",selection:Binding(get:{Color(uiColor:UIColor(hex:style[keyPath:key]))},set:{v in model.change{$0.style[keyPath:key]=UIColor(v).hex}}),supportsOpacity:false).font(.system(size:12))}.padding(12).glass(16)}
}
