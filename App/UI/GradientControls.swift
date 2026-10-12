import SwiftUI

struct GradientControls:View {
    @ObservedObject var model:EditorModel
    let colors:WritableKeyPath<TextStyle,[String]>
    let stops:WritableKeyPath<TextStyle,[Double]>
    let angle:WritableKeyPath<TextStyle,Double>
    let type:WritableKeyPath<TextStyle,Int>
    private var style:TextStyle{model.active?.style ?? TextStyle()}
    private var target:String{colors == \.strokeGradient ? "stroke":colors == \.shadowGradient ? "shadow":"text"}
    private var values:[String]{style[keyPath:colors]}
    private func position(_ i:Int)->Double{GradientEditing.position(values,stops:style[keyPath:stops],at:i)}
    var body:some View{VStack(alignment:.leading,spacing:12){
        Toggle("تدرج لوني",isOn:Binding(get:{!values.isEmpty},set:{enabled in model.change{$0.style[keyPath:colors]=enabled ? ["FFFFFF","D4AF37"]:[];$0.style[keyPath:stops]=enabled ? [0,1]:[]}}))
        if !values.isEmpty{
            Button{model.gradientTarget=colors == \.strokeGradient ? "stroke":colors == \.shadowGradient ? "shadow":"text"}label:{Label("مقابض التدرج داخل اللوحة",systemImage:"point.topleft.down.curvedto.point.bottomright.up")}.font(.system(size:12))
            Button("إعادة اتجاه التدرج الافتراضي"){model.change{let target=colors == \.strokeGradient ? "stroke":colors == \.shadowGradient ? "shadow":"text";GradientGeometry.set([],target:target,style:&$0.style)}}.font(.system(size:11))
            Picker("النوع",selection:Binding(get:{style[keyPath:type]},set:{v in model.change{$0.style[keyPath:type]=v}})){Text("خطي").tag(0);Text("دائري").tag(1);Text("منعكس").tag(2);Text("زاوي").tag(3)}.pickerStyle(.menu)
            GradientPreview(colors:values,stops:values.indices.map{position($0)},angle:style[keyPath:angle],type:style[keyPath:type],points:target=="stroke" ? style.strokeGradientPoints:target=="shadow" ? style.shadowGradientPoints:style.textGradientPoints).frame(height:60).clipShape(RoundedRectangle(cornerRadius:12))
            ForEach(Array(values.indices),id:\.self){index in HStack{
                CookiesColorWell("لون \(index+1)",selection:Binding(get:{Color(uiColor:UIColor(hex:GradientEditing.color(values,at:index)))},set:{color in model.change{GradientEditing.setColor(UIColor(color).hex,at:index,colors:&$0.style[keyPath:colors])}}),supportsOpacity:false)
                StepSlider(value:Binding(get:{position(index)},set:{value in model.change{var list=$0.style[keyPath:stops];GradientEditing.setPosition(value,at:index,colors:$0.style[keyPath:colors],stops:&list);$0.style[keyPath:stops]=list}}),in:0...1)
                Button(role:.destructive){model.change{var current=$0.style[keyPath:colors],list=$0.style[keyPath:stops];GradientEditing.remove(at:index,colors:&current,stops:&list);$0.style[keyPath:colors]=current;$0.style[keyPath:stops]=list}}label:{Image(systemName:"minus.circle")}.disabled(values.count<=2)
            }.font(.system(size:12))}
            Button{var list=values.indices.map{position($0)};list.append(0.5);model.change{$0.style[keyPath:colors].append("FFFFFF");$0.style[keyPath:stops]=list}}label:{Label("إضافة لون",systemImage:"plus.circle")}.disabled(values.count>=16)
            HStack{Text("زاوية التدرج");TextField("الزاوية",value:Binding(get:{style[keyPath:angle]},set:{value in model.change{$0.style[keyPath:angle]=min(360,max(0,value));GradientGeometry.set([],target:target,style:&$0.style)}}),format:.number).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)}.font(.system(size:12))
            StepSlider(value:Binding(get:{style[keyPath:angle]},set:{value in model.change{$0.style[keyPath:angle]=value;GradientGeometry.set([],target:target,style:&$0.style)}}),in:0...360)
        }
    }.padding(12).glass(16)}
}
struct GradientPreview:UIViewRepresentable {
    let colors:[String],stops:[Double],angle:Double,type:Int
    var points:[Point]?=nil
    func makeUIView(context:Context)->GradientView{GradientView()}
    func updateUIView(_ view:GradientView,context:Context){view.colors=colors;view.stops=stops;view.angle=angle;view.type=type;view.points=points;view.setNeedsDisplay()}
}
final class GradientView:UIView {
    var colors:[String]=[],stops:[Double]=[],angle=0.0,type=0
    var points:[Point]?
    override func draw(_ rect:CGRect){guard let c=UIGraphicsGetCurrentContext() else{return};GradientPaint.draw(colors:colors,stops:stops,angle:angle,type:type,rect:bounds,points:points,in:c)}
}
