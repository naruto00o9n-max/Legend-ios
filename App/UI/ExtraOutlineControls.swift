import SwiftUI

struct ExtraOutlineControls:View {
    @ObservedObject var model:EditorModel
    let id:UUID
    @State private var expanded=false
    private var outline:ExtraOutline?{model.active?.style.extraStrokes?.first{$0.id==id}}
    private func update(_ action:(inout ExtraOutline)->Void){model.change{layer in if let index=layer.style.extraStrokes?.firstIndex(where:{$0.id==id}){action(&layer.style.extraStrokes![index])}}}
    var body:some View{if let outline{VStack(alignment:.leading,spacing:10){
        HStack{ColorPicker("حد إضافي",selection:Binding(get:{Color(uiColor:UIColor(hex:outline.color))},set:{value in update{$0.color=UIColor(value).hex}}),supportsOpacity:false);Text("\(Int(outline.width)) px").font(.system(size:10,design:.monospaced));Button{expanded.toggle()}label:{Image(systemName:"slider.horizontal.3")}.accessibilityLabel("تدرج الحد الإضافي");Button(role:.destructive){model.change{$0.style.extraStrokes?.removeAll{$0.id==id}}}label:{Image(systemName:"trash")}}
        Slider(value:Binding(get:{outline.width},set:{value in update{$0.width=value}}),in:0...40)
        if expanded{
            Toggle("تدرج مستقل",isOn:Binding(get:{!(outline.gradient ?? []).isEmpty},set:{enabled in update{$0.gradient=enabled ? [outline.color,"FFFFFF"]:[];$0.stops=enabled ? [0,1]:[]}}))
            if let colors=outline.gradient,!colors.isEmpty{
                Picker("نوع التدرج",selection:Binding(get:{outline.gradientType ?? 0},set:{value in update{$0.gradientType=value}})){Text("خطي").tag(0);Text("شعاعي").tag(1);Text("منعكس").tag(2);Text("زاوي").tag(3)}.pickerStyle(.menu)
                Slider(value:Binding(get:{outline.angle ?? 0},set:{value in update{$0.angle=value}}),in:0...360)
                ForEach(colors.indices,id:\.self){index in HStack{
                    ColorPicker("لون \(index+1)",selection:Binding(get:{Color(uiColor:UIColor(hex:colors[index]))},set:{value in update{$0.gradient?[index]=UIColor(value).hex}}),supportsOpacity:false)
                    Slider(value:Binding(get:{let stops=outline.stops ?? [];return index<stops.count ? stops[index]:Double(index)/Double(max(1,colors.count-1))},set:{value in update{item in var stops=item.stops ?? colors.indices.map{Double($0)/Double(max(1,colors.count-1))};if stops.count != colors.count{stops=colors.indices.map{Double($0)/Double(max(1,colors.count-1))}};stops[index]=value;item.stops=stops}}),in:0...1)
                    Button(role:.destructive){update{item in item.gradient?.remove(at:index);if item.stops?.count==colors.count{item.stops?.remove(at:index)}}}label:{Image(systemName:"minus.circle")}.disabled(colors.count<=2)
                }}
                Button("إضافة لون"){update{item in item.gradient=(item.gradient ?? [])+["FFFFFF"];item.stops=item.gradient!.indices.map{Double($0)/Double(item.gradient!.count-1)}}}.disabled(colors.count>=8)
            }
        }
    }.font(.system(size:12)).padding(12).glass(14)}}
}
