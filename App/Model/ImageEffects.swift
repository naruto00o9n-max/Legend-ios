import Foundation

/// Independent from text effects: these operate on the source image's pixels.
enum ImageEffectKind:String,Codable,CaseIterable,Identifiable,Hashable {
    case blur,chromatic,glitch,vignette,grain,glow,pixelate,halftone,slice,fade,duotone,mirror,outline
    var id:String{rawValue}
    var title:String{switch self{case .blur:"تمويه";case .chromatic:"فصل قنوات اللون";case .glitch:"خلل رقمي";case .vignette:"تظليل الأطراف";case .grain:"حبيبات";case .glow:"توهج";case .pixelate:"فسيفساء البكسلات";case .halftone:"نقاط الطباعة";case .slice:"تقسيم الصورة";case .fade:"تلاشي";case .duotone:"ثنائي اللون";case .mirror:"انعكاس";case .outline:"حافة خارجية"}}
    var icon:String{switch self{case .blur:"drop.halffull";case .chromatic:"circle.lefthalf.filled";case .glitch:"waveform";case .vignette:"circle.dashed.inset.filled";case .grain:"sparkles";case .glow:"sun.max";case .pixelate:"square.grid.3x3";case .halftone:"circle.grid.3x3";case .slice:"rectangle.split.3x1";case .fade:"sun.haze";case .duotone:"circle.righthalf.filled";case .mirror:"arrow.left.and.right.righttriangle.left.righttriangle.right";case .outline:"square.dashed"}}
    var range:ClosedRange<Double>{switch self{case .blur:1...100;case .chromatic,.glitch,.outline:1...50;case .pixelate:2...80;case .halftone:2...50;default:0...200}}
    var intensityLabel:String{switch self{case .pixelate:"حجم البكسل";case .halftone:"حجم النقاط";case .mirror:"قوة المزج";case .outline:"سماكة الحافة";default:"قوة التأثير"}}
}
struct ImageEffect:Codable,Hashable,Identifiable {
    var id=UUID()
    var kind:ImageEffectKind
    var enabled=true
    var intensity:Double
    var angle=0.0
    var color="00FFFF"
    var color2="FF00FF"
    var parameter1=0.0
    var parameter2=0.0
    var opacity=1.0
    var seed:UInt32=42
    init(_ kind:ImageEffectKind){self.kind=kind;intensity=min(50,kind.range.upperBound);if kind == .pixelate{intensity=12};if kind == .halftone{intensity=20};if kind == .grain{parameter1=2};if kind == .vignette{parameter1=60};if kind == .outline{intensity=6};if kind == .duotone{color="181A24";color2="E4C779"}}
    var sanitized:ImageEffect{var x=self;x.intensity=x.intensity.isFinite ? min(kind.range.upperBound,max(kind.range.lowerBound,x.intensity)):kind.range.lowerBound;x.angle=x.angle.isFinite ? x.angle.truncatingRemainder(dividingBy:360):0;x.opacity=x.opacity.isFinite ? min(1,max(0,x.opacity)):1;x.parameter1=x.parameter1.isFinite ? min(100,max(0,x.parameter1)):0;x.parameter2=x.parameter2.isFinite ? min(100,max(0,x.parameter2)):0;if kind == .blur{x.parameter1=min(4,x.parameter1.rounded())};if kind == .mirror{x.parameter1=min(1,x.parameter1.rounded())};if kind == .grain{x.parameter1=min(10,max(1,x.parameter1))};return x}
}
extension EditorLayer {
    var effectiveImageEffects:[ImageEffect]{(imageEffects ?? []).filter{$0.enabled && $0.opacity>0}.map(\.sanitized)}
}
