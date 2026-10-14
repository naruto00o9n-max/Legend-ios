import Foundation
import UIKit

struct Point: Codable, Equatable, Hashable { var x: Double; var y: Double; var cg: CGPoint { CGPoint(x:x,y:y) } }
struct Box: Codable, Equatable, Hashable {
    var x: Double = 0; var y: Double = 0; var width: Double = 300; var height: Double = 150
    var cg: CGRect { CGRect(x:x,y:y,width:width,height:height) }
}
enum LayerKind: String, Codable, CaseIterable { case text, image, shape, drawing }
enum TextOrigin:String,Codable {case manual,typer,tagPreview}
/// Position and selected-character ranges belong to a particular dialogue.
/// These reusable transforms, unlike a canvas position, are part of its look.
struct TextLayerTransform:Codable,Equatable, Hashable {
    var opacity=1.0;var rotation=0.0;var scaleX=1.0;var scaleY=1.0;var shearX:Double?
    init(){}
    init(_ layer:EditorLayer){opacity=layer.opacity;rotation=layer.rotation;scaleX=layer.scaleX;scaleY=layer.scaleY;shearX=layer.shearX}
    func apply(to layer:inout EditorLayer){layer.opacity=opacity;layer.rotation=rotation;layer.scaleX=scaleX;layer.scaleY=scaleY;layer.shearX=shearX}
}
struct ManualTextPreset:Codable,Equatable, Hashable {var style:TextStyle;var transform=TextLayerTransform()}
enum TextEffect: String, Codable, CaseIterable {
    case none, chromatic, blur, glitch, slice, neon, fade, warp, shadow, error
    case strokeBoth,stainedGlass,wetEdge,innerGlow,bevelInner,bevelOuter,emboss,relief,waterdrop,strokeOuter,outerGlow,satin,dropShadow,extrude,godRays
    var isStyle:Bool{Self.styleCases.contains(self)}
    static let styleCases:[TextEffect]=[.strokeBoth,.stainedGlass,.wetEdge,.innerGlow,.bevelInner,.bevelOuter,.emboss,.relief,.waterdrop,.strokeOuter,.outerGlow,.satin,.dropShadow,.extrude,.godRays]
    var title:String {switch self {case .none:"بلا تأثير";case .chromatic:"إزاحة قنوات RGB";case .blur:"تمويه";case .glitch:"تشويش";case .slice:"تقطيع";case .neon:"توهج";case .fade:"تلاشي";case .warp:"تشويه";case .shadow:"ظل";case .error:"خلل";case .strokeBoth:"حد داخلي وخارجي";case .stainedGlass:"زجاج ملوّن";case .wetEdge:"حافة رطبة";case .innerGlow:"توهج داخلي";case .bevelInner:"شطبة داخلية";case .bevelOuter:"شطبة خارجية";case .emboss:"نقش بارز";case .relief:"نحت بارز";case .waterdrop:"قطرة ماء";case .strokeOuter:"حد خارجي";case .outerGlow:"توهج خارجي";case .satin:"ساتان";case .dropShadow:"ظل ساقط";case .extrude:"بروز";case .godRays:"أشعة الضوء"}}
}
struct StyleEffectSettings:Codable,Equatable,Hashable {
    var radius=4.0;var softness=3.0;var depth=12.0;var angle=45.0;var opacity=0.8
    var color="000000";var highlightColor="FFFFFF";var baseColor="888888"
    var cellSize=24.0;var saturation=0.7;var seed:UInt32=7;var density=24
}

enum Blend: String, Codable, CaseIterable {
    case normal, multiply, screen, overlay, darken, lighten, difference, add
    var title:String {switch self {case .normal:"عادي";case .multiply:"ضرب";case .screen:"شاشة";case .overlay:"تراكب";case .darken:"تغميق";case .lighten:"تفتيح";case .difference:"فرق";case .add:"جمع"}}
    var cg: CGBlendMode { switch self {case .normal:.normal;case .multiply:.multiply;case .screen:.screen;case .overlay:.overlay;case .darken:.darken;case .lighten:.lighten;case .difference:.difference;case .add:.plusLighter} }
}
struct TextStyle: Codable, Equatable, Hashable {
    var fontPath = "bein_normal.ttf"; var fontSize = 48.0; var boxWidth = 320.0
    var color = "FFFFFF"; var isBold = false; var isItalic = false; var isUnderline = false; var isStrikeThrough = false
    var alignment = 1; var letterSpacing = 0.0; var lineSpacing = 0.0; var lineHeightMultiple:Double?; var fakeBoldWidth = 0.0
    var strokeColor = "000000"; var strokeWidth = 2.0
    var shadowColor = "000000"; var shadowRadius = 0.0; var shadowDx = 0.0; var shadowDy = 0.0; var shadowAlpha = 255
    var backgroundColor = "000000"; var backgroundAlpha = 0; var backgroundCornerRadius = 16.0
    var backgroundPaddingX = 12.0; var backgroundPaddingY = 8.0
    var textGradientPoints:[Point]?;var strokeGradientPoints:[Point]?;var shadowGradientPoints:[Point]?
    var textGradient: [String] = []; var textGradientAngle = 0.0; var textGradientType = 0
    var textGradientStops: [Double] = []; var strokeGradient: [String] = []; var strokeGradientAngle = 0.0
    var strokeGradientStops: [Double] = []; var strokeGradientType = 0; var shadowGradient: [String] = []
    var shadowGradientAngle = 0.0; var shadowGradientStops: [Double] = []; var shadowGradientType = 0
    var styleEffect:StyleEffectSettings?
    var effectType = TextEffect.none; var effectColor = "D4AF37"; var effectValue = 4.0; var effectAngle = 0.0
    var effectDetail = 3.0; var effectSecondVal = 0.0; var effectThirdVal = 0.0
    var blurDx = 0.0; var blurDy = 0.0; var blurType = 0
    var rotationX = 0.0; var rotationY = 0.0; var threeDDepth = 0; var threeDColor = "8A6A24"; var threeDDarken = 0.0
    var texturePath = ""; var textureScaleX = 1.0; var textureScaleY = 1.0; var textureRotation = 0.0
    var textureTranslationX = 0.0; var textureTranslationY = 0.0
    var perspectivePoints: [Point] = []; var isMeshMode = false; var meshRows = 3; var meshCols = 3; var meshPoints: [Point] = []
    var tashkeelOffset:Double?
    var innerOpacity:Double?;var fadeAmount:Double?;var fadeAngle:Double?;var rulerEnabled:Bool?
    var art:TextArtSettings?
    var extraStrokes:[ExtraOutline]?
    var spans: [TextRun] = []; var customWidth: Double?; var baseWidth = 0.0; var baseHeight = 0.0
}
extension TextStyle {
    static func plainText(fontSize:Double=48,boxWidth:Double=320)->TextStyle{
        var style=TextStyle();style.fontSize=fontSize;style.boxWidth=boxWidth;style.color="000000";style.strokeWidth=0;return style
    }
}
struct ExtraOutline:Codable,Equatable,Identifiable, Hashable {var id=UUID();var width:Double;var color:String;var gradient:[String]?;var stops:[Double]?;var angle:Double?;var gradientType:Int?}
struct TextRun: Codable, Equatable, Hashable { var start: Int; var end: Int; var color: String?; var fontSize: Double?; var isBold: Bool? }
struct Stroke: Codable, Equatable, Hashable { var points: [Point]; var width: Double; var color: String; var erase = false; var brush = "normal";var opacity:Double?;var texturePath:String?;var shape:String?;var filled:Bool? }
struct EditorLayer: Codable, Equatable, Identifiable, Hashable {
    var id = UUID(); var kind: LayerKind; var name = "طبقة"; var frame = Box()
    var rotation = 0.0; var scaleX = 1.0; var scaleY = 1.0; var opacity = 1.0
    var shearX:Double?
    var isVisible = true; var isLocked = false; var blend = Blend.normal
    var textContent = "نص جديد"; var style = TextStyle(); var imagePath = ""; var shape = 0
    // Optional so existing projects retain their original appearance on decode.
    var imageEffects:[ImageEffect]?
    var isWorkingImage:Bool?
    var imagePixelFile:String?
    var imagePixelWidth:Int?
    var imagePixelHeight:Int?
    var textOrigin:TextOrigin?
    var gradientMapBaseline:GradientMapBaseline?
    var textMask:[Stroke]?
    var groupID:UUID?;var groupName:String?
    var strokes: [Stroke] = []; var isMaskEnabled = false; var maskX = 0.0; var maskY = 0.0; var maskRadius = 80.0
}
struct EditorPage: Codable, Equatable, Identifiable {
    var id = UUID(); var title: String; var width: Int; var height: Int
    var baseHidden:Bool?
    var source = "source.png"; var raw = "pixels.rgba"; var layers: [EditorLayer] = []; var modified = Date()
}
struct LibraryItem: Codable, Equatable, Identifiable {
    var id = UUID(); var parent: UUID?; var title: String; var folder: Bool; var pages: [UUID] = []; var modified = Date()
    var isChapter:Bool?;var cover:UUID?
    var deletedAt:Date?;var trashGroup:UUID?;var purgePending:Bool?
}
enum Tool: String, CaseIterable {
    case move, text, brush, eraser, shapes, layers, cleaner, eyedropper
    var title: String { switch self {case .move:"تحريك";case .text:"نص";case .brush:"فرشاة";case .eraser:"ممحاة";case .shapes:"أشكال";case .layers:"طبقات";case .cleaner:"تنظيف";case .eyedropper:"قطارة"} }
    var icon: String { switch self {case .move:"hand.draw";case .text:"textformat";case .brush:"paintbrush.pointed";case .eraser:"eraser";case .shapes:"square.on.circle";case .layers:"square.3.layers.3d";case .cleaner:"sparkles";case .eyedropper:"eyedropper"} }
}
enum Panel: String, CaseIterable, Identifiable {
    case content, font, format, color, gradientMap, stroke, background, shadow, position, spacing, threeD, perspective, effects, texture, opacity, styles, mask
    var icon:String {switch self{case .content:"text.bubble";case .font:"textformat.alt";case .format:"textformat.size";case .color:"paintpalette";case .gradientMap:"circle.hexagongrid.fill";case .stroke:"a.square";case .background:"rectangle.fill";case .shadow:"shadow";case .position:"move.3d";case .spacing:"arrow.left.and.right";case .threeD:"cube";case .perspective:"view.3d";case .effects:"sparkles";case .texture:"square.stack.3d.up";case .opacity:"circle.lefthalf.filled";case .styles:"square.grid.2x2";case .mask:"circle.dashed"}}
    var id: String {rawValue}
    var title: String { switch self {case .content:"النص";case .font:"الخط";case .format:"التنسيق";case .color:"اللون";case .gradientMap:"خرائط التدرج";case .stroke:"الحدود";case .background:"الخلفية";case .shadow:"الظل";case .position:"الموضع";case .spacing:"التباعد";case .threeD:"الأبعاد";case .perspective:"المنظور";case .effects:"التأثيرات";case .texture:"الخامة";case .opacity:"الشفافية";case .styles:"الأنماط";case .mask:"القناع"} }
}
extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {let v=UInt32(hex.replacingOccurrences(of:"#",with:""),radix:16) ?? 0xD4AF37;self.init(red:CGFloat((v>>16)&255)/255,green:CGFloat((v>>8)&255)/255,blue:CGFloat(v&255)/255,alpha:alpha)}
    var hex: String {var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0;getRed(&r,green:&g,blue:&b,alpha:&a);return String(format:"%02X%02X%02X",Int(r*255),Int(g*255),Int(b*255))}
}

extension TextStyle {
    var usedColors:[String]{var values=textGradient.isEmpty ? [color]:textGradient;if strokeWidth>0{values+=strokeGradient.isEmpty ? [strokeColor]:strokeGradient};if shadowAlpha>0 && (shadowRadius>0 || shadowDx != 0 || shadowDy != 0){values+=shadowGradient.isEmpty ? [shadowColor]:shadowGradient};if backgroundAlpha>0{values.append(backgroundColor)};if [.neon,.error].contains(effectType){values.append(effectColor)};if effectType.isStyle{let settings=styleEffect ?? StyleEffectSettings();values+=[settings.color,settings.highlightColor,settings.baseColor]};values+=spans.compactMap(\.color);for outline in extraStrokes ?? []{values+=outline.gradient?.isEmpty==false ? outline.gradient!:[outline.color]};return Array(Set(values))}
}
struct TextArtSettings:Codable,Equatable, Hashable {
    var distance=4.0
    var angle=0.0
    var order=0
    var bandHeight=26.0
    var strength=10.0
    var colorShift=4.0
    var seed:UInt32=7
}
