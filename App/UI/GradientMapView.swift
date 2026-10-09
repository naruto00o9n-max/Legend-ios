import SwiftUI

struct GradientPreset:Codable,Identifiable {
    var id:String;var title:String;var english:String;var category:String
    var colors:[String];var stops:[Double];var angle:Double;var type:Int
    var stroke:[String];var shadow:[String]
    static func catalog()throws->[GradientPreset]{guard let file=Bundle.main.url(forResource:"gradient-presets",withExtension:"json") else{throw ImageFailure.message("تعذر تحميل مكتبة التدرجات")};return try JSONDecoder().decode([GradientPreset].self,from:Data(contentsOf:file))}
    func apply(to style:inout TextStyle,target:String){
        if target=="all" || target=="text"{style.textGradientPoints=nil;style.textGradient=colors;style.textGradientStops=stops;style.textGradientAngle=angle;style.textGradientType=type}
        if target=="all" || target=="stroke"{style.strokeGradientPoints=nil;style.strokeGradient=target=="all" && !stroke.isEmpty ? stroke:colors;style.strokeGradientStops=style.strokeGradient.count==stops.count ? stops:[];style.strokeGradientAngle=angle;style.strokeGradientType=type;style.strokeWidth=max(2,style.strokeWidth)}
        if target=="all" || target=="shadow"{style.shadowGradientPoints=nil;style.shadowGradient=target=="all" && !shadow.isEmpty ? shadow:colors;style.shadowGradientStops=style.shadowGradient.count==stops.count ? stops:[];style.shadowGradientAngle=angle;style.shadowGradientType=type;style.shadowRadius=max(4,style.shadowRadius);style.shadowDy=max(3,style.shadowDy)}
    }
}
struct GradientMapView:View {
    @ObservedObject var model:EditorModel
    @State private var target="all"
    @State private var category="ALL"
    @State private var query=""
    @State private var presets:[GradientPreset]=[]
    private let labels=["ALL":"الكل","GOLD":"ذهب","METALLIC":"معدني","NEON":"نيون","DARK":"داكن","OCEAN":"محيط","SUNSET":"غروب","PASTEL":"باستيل","AURA":"هالة","SYSTEM":"نظام","SHOUNEN":"شونين","SHOUJO":"شوجو","WEBTOON":"ويبتون"]
    var body:some View{VStack(alignment:.leading,spacing:14){
        Picker("تطبيق التدرج",selection:$target){Text("الكل").tag("all");Text("النص").tag("text");Text("الحدود").tag("stroke");Text("الظل").tag("shadow")}.pickerStyle(.segmented)
        TextField("بحث في التدرجات",text:$query).textFieldStyle(.roundedBorder)
        ScrollView(.horizontal,showsIndicators:false){HStack{ForEach(["ALL"]+Array(Set(presets.map(\.category))).sorted(),id:\.self){key in Button(labels[key] ?? key){category=key}.font(.system(size:11)).padding(9).background(category==key ? Palette.gold.opacity(0.15):Color.white.opacity(0.04),in:Capsule())}}}
        LazyVGrid(columns:[GridItem(.adaptive(minimum:130),spacing:10)],spacing:10){ForEach(presets.filter{(category=="ALL" || $0.category==category) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.english.localizedCaseInsensitiveContains(query))}){preset in
            Button{model.change{preset.apply(to:&$0.style,target:target)}}label:{VStack(alignment:.leading,spacing:8){GradientPreview(colors:preset.colors,stops:preset.stops,angle:preset.angle,type:preset.type).frame(height:45).clipShape(RoundedRectangle(cornerRadius:9));Text(preset.title).font(.system(size:12)).foregroundStyle(Palette.pale).lineLimit(1)}.padding(10).glass(14)}.accessibilityIdentifier("gradient-preset-"+preset.id)
        }}
        Button{model.change{layer in
            if target=="all" || target=="text"{let pair=reverse(layer.style.textGradient,layer.style.textGradientStops);layer.style.textGradient=pair.0;layer.style.textGradientStops=pair.1}
            if target=="all" || target=="stroke"{let pair=reverse(layer.style.strokeGradient,layer.style.strokeGradientStops);layer.style.strokeGradient=pair.0;layer.style.strokeGradientStops=pair.1}
            if target=="all" || target=="shadow"{let pair=reverse(layer.style.shadowGradient,layer.style.shadowGradientStops);layer.style.shadowGradient=pair.0;layer.style.shadowGradientStops=pair.1}
        }}label:{Label("عكس الألوان",systemImage:"arrow.left.arrow.right")}.font(.system(size:12))
    }.task{do{presets=try GradientPreset.catalog()}catch{model.error=error.localizedDescription}}}
    private func reverse(_ colors:[String],_ stops:[Double])->([String],[Double]){(Array(colors.reversed()),stops.reversed().map{1-$0})}
}
