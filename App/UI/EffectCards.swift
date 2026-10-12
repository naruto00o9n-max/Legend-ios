import SwiftUI

struct EffectCards:View {
    @ObservedObject var model:EditorModel
    var body:some View{LazyVGrid(columns:[GridItem(.adaptive(minimum:130),spacing:10)],spacing:10){ForEach(TextEffect.allCases,id:\.self){effect in
        Button{model.checkpoint();model.change{$0.style.effectType=effect;if effect.isStyle && $0.style.styleEffect==nil{$0.style.styleEffect=StyleEffectSettings()}}}label:{VStack(alignment:.leading,spacing:8){EffectCardPreview(effect:effect).frame(height:78).clipped().clipShape(RoundedRectangle(cornerRadius:10));HStack{Text(effect.title).font(.system(size:11,weight:.medium)).lineLimit(2);Spacer(minLength:2);if model.active?.style.effectType==effect{Image(systemName:"checkmark.circle.fill").foregroundStyle(Palette.gold)}}.frame(minHeight:28)}.padding(10).glass(16).overlay{RoundedRectangle(cornerRadius:16).stroke(model.active?.style.effectType==effect ? Palette.gold.opacity(0.7):.clear,lineWidth:1)}}.buttonStyle(.plain).accessibilityIdentifier("effect-card-"+effect.rawValue)
    }}}
}
private struct EffectCardPreview:View {
    let effect:TextEffect
    @State private var image:UIImage?
    var body:some View{ZStack{Color(white:0.22);if let image{Image(uiImage:image).resizable().scaledToFit()}else{ProgressView().tint(.white)}}.task(id:effect){let next=await EffectPreviewCache.image(effect);guard !Task.isCancelled else{return};image=next}.accessibilityHidden(true)}
}
private enum EffectPreviewCache {
    static let cache=NSCache<NSString,UIImage>()
    static let worker=DispatchQueue(label:"cookies.effect.cards",qos:.utility,autoreleaseFrequency:.workItem)
    static func image(_ effect:TextEffect)async->UIImage{
        await withCheckedContinuation{continuation in worker.async{
            let key=effect.rawValue as NSString
            if let image=cache.object(forKey:key){continuation.resume(returning:image);return}
            let image=RenderBudget.screen{()->UIImage in
                var layer=EditorLayer(kind:.text);layer.textContent="كوكيز";layer.style=TextStyle.plainText(fontSize:32,boxWidth:130);layer.style.color="FFFFFF";layer.style.effectColor="D4AF37";layer.style.effectType=effect
                var settings=StyleEffectSettings();settings.color="D4AF37";settings.radius=2;settings.softness=2;settings.depth=7;settings.cellSize=14;layer.style.styleEffect=settings
                layer.style.art=effect == .chromatic || effect == .glitch ? TextArtSettings(distance:3,bandHeight:5,strength:3,colorShift:2):nil
                let format=UIGraphicsImageRendererFormat();format.scale=2;format.opaque=false;format.preferredRange = .standard
                return UIGraphicsImageRenderer(size:CGSize(width:160,height:84),format:format).image{out in out.cgContext.translateBy(x:15,y:15);LayerRenderer.drawText(layer,rect:LayerRenderer.bounds(layer),context:out.cgContext,directory:FileManager.default.temporaryDirectory)}
            }
            cache.totalCostLimit=6*1024*1024;cache.setObject(image,forKey:key,cost:(image.cgImage.map{$0.bytesPerRow*$0.height} ?? 0));continuation.resume(returning:image)
        }}
    }
}
