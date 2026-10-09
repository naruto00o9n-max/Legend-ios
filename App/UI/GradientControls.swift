import SwiftUI

struct GradientControls:View {
    @ObservedObject var model:EditorModel
    let colors:WritableKeyPath<TextStyle,[String]>
    let stops:WritableKeyPath<TextStyle,[Double]>
    let angle:WritableKeyPath<TextStyle,Double>
    let type:WritableKeyPath<TextStyle,Int>
    private var style:TextStyle{model.active?.style ?? TextStyle()}
    private var values:[String]{style[keyPath:colors]}
    private func position(_ i:Int)->Double{let list=style[keyPath:stops];return list.count==values.count ? list[i]:Double(i)/Double(max(1,values.count-1))}
    var body:some View{VStack(alignment:.leading,spacing:12){
        Toggle("تدرج لوني",isOn:Binding(get:{!values.isEmpty},set:{enabled in model.change{$0.style[keyPath:colors]=enabled ? ["FFFFFF","D4AF37"]:[];$0.style[keyPath:stops]=enabled ? [0,1]:[]}}))
        if !values.isEmpty{
            Picker("النوع",selection:Binding(get:{style[keyPath:type]},set:{v in model.change{$0.style[keyPath:type]=v}})){Text("خطي").tag(0);Text("دائري").tag(1);Text("منعكس").tag(2);Text("زاوي").tag(3)}.pickerStyle(.menu)
            GradientPreview(colors:values,stops:values.indices.map{position($0)},angle:style[keyPath:angle],type:style[keyPath:type]).frame(height:60).clipShape(RoundedRectangle(cornerRadius:12))
            ForEach(Array(values.indices),id:\.self){index in HStack{
                ColorPicker("لون \(index+1)",selection:Binding(get:{Color(uiColor:UIColor(hex:values[index]))},set:{color in model.change{$0.style[keyPath:colors][index]=UIColor(color).hex}}),supportsOpacity:false)
                Slider(value:Binding(get:{position(index)},set:{value in var list=values.indices.map{position($0)};list[index]=value;model.change{$0.style[keyPath:stops]=list}}),in:0...1)
                Button(role:.destructive){var list=values.indices.map{position($0)};list.remove(at:index);model.change{$0.style[keyPath:colors].remove(at:index);$0.style[keyPath:stops]=list}}label:{Image(systemName:"minus.circle")}.disabled(values.count<=2)
            }.font(.system(size:12))}
            Button{var list=values.indices.map{position($0)};list.append(0.5);model.change{$0.style[keyPath:colors].append("FFFFFF");$0.style[keyPath:stops]=list}}label:{Label("إضافة لون",systemImage:"plus.circle")}.disabled(values.count>=16)
            HStack{Text("زاوية التدرج");TextField("الزاوية",value:Binding(get:{style[keyPath:angle]},set:{value in model.change{$0.style[keyPath:angle]=min(360,max(0,value))}}),format:.number).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)}.font(.system(size:12))
            Slider(value:Binding(get:{style[keyPath:angle]},set:{value in model.change{$0.style[keyPath:angle]=value}}),in:0...360)
        }
    }.padding(12).glass(16)}
}
private struct GradientPreview:UIViewRepresentable {
    let colors:[String],stops:[Double],angle:Double,type:Int
    func makeUIView(context:Context)->GradientView{GradientView()}
    func updateUIView(_ view:GradientView,context:Context){view.colors=colors;view.stops=stops;view.angle=angle;view.type=type;view.setNeedsDisplay()}
}
private final class GradientView:UIView {
    var colors:[String]=[],stops:[Double]=[],angle=0.0,type=0
    override func draw(_ rect:CGRect){guard let c=UIGraphicsGetCurrentContext() else{return};GradientPaint.draw(colors:colors,stops:stops,angle:angle,type:type,rect:bounds,in:c)}
}
