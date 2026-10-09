import Foundation
import UIKit

struct Point: Codable, Equatable { var x: Double; var y: Double; var cg: CGPoint { CGPoint(x:x,y:y) } }
struct Box: Codable, Equatable {
    var x: Double = 0; var y: Double = 0; var width: Double = 300; var height: Double = 150
    var cg: CGRect { CGRect(x:x,y:y,width:width,height:height) }
}
enum LayerKind: String, Codable, CaseIterable { case text, image, shape, drawing }
enum TextEffect: String, Codable, CaseIterable { case none, blur, glitch, slice, neon, fade, warp, shadow, error }
enum Blend: String, Codable, CaseIterable {
    case normal, multiply, screen, overlay, darken, lighten, difference, add
    var cg: CGBlendMode { switch self {case .normal:.normal;case .multiply:.multiply;case .screen:.screen;case .overlay:.overlay;case .darken:.darken;case .lighten:.lighten;case .difference:.difference;case .add:.plusLighter} }
}
struct TextStyle: Codable, Equatable {
    var fontPath = "bein_normal.ttf"; var fontSize = 48.0; var boxWidth = 320.0
    var color = "FFFFFF"; var isBold = false; var isItalic = false; var isUnderline = false; var isStrikeThrough = false
    var alignment = 1; var letterSpacing = 0.0; var lineSpacing = 0.0; var fakeBoldWidth = 0.0
    var strokeColor = "000000"; var strokeWidth = 0.0
    var shadowColor = "000000"; var shadowRadius = 0.0; var shadowDx = 0.0; var shadowDy = 0.0; var shadowAlpha = 255
    var backgroundColor = "000000"; var backgroundAlpha = 0; var backgroundCornerRadius = 16.0
    var backgroundPaddingX = 12.0; var backgroundPaddingY = 8.0
    var textGradient: [String] = []; var textGradientAngle = 0.0; var textGradientType = 0
    var textGradientStops: [Double] = []; var strokeGradient: [String] = []; var strokeGradientAngle = 0.0
    var strokeGradientStops: [Double] = []; var strokeGradientType = 0; var shadowGradient: [String] = []
    var shadowGradientAngle = 0.0; var shadowGradientStops: [Double] = []; var shadowGradientType = 0
    var effectType = TextEffect.none; var effectColor = "D4AF37"; var effectValue = 4.0; var effectAngle = 0.0
    var effectDetail = 3.0; var effectSecondVal = 0.0; var effectThirdVal = 0.0
    var blurDx = 0.0; var blurDy = 0.0; var blurType = 0
    var rotationX = 0.0; var rotationY = 0.0; var threeDDepth = 0; var threeDColor = "8A6A24"; var threeDDarken = 0.0
    var texturePath = ""; var textureScaleX = 1.0; var textureScaleY = 1.0; var textureRotation = 0.0
    var textureTranslationX = 0.0; var textureTranslationY = 0.0
    var perspectivePoints: [Point] = []; var isMeshMode = false; var meshRows = 3; var meshCols = 3; var meshPoints: [Point] = []
    var spans: [TextRun] = []; var customWidth: Double?; var baseWidth = 0.0; var baseHeight = 0.0
}
struct TextRun: Codable, Equatable { var start: Int; var end: Int; var color: String?; var fontSize: Double?; var isBold: Bool? }
struct Stroke: Codable, Equatable { var points: [Point]; var width: Double; var color: String; var erase = false; var brush = "normal" }
struct EditorLayer: Codable, Equatable, Identifiable {
    var id = UUID(); var kind: LayerKind; var name = "طبقة"; var frame = Box()
    var rotation = 0.0; var scaleX = 1.0; var scaleY = 1.0; var opacity = 1.0
    var isVisible = true; var isLocked = false; var blend = Blend.normal
    var textContent = "نص جديد"; var style = TextStyle(); var imagePath = ""; var shape = 0
    var strokes: [Stroke] = []; var isMaskEnabled = false; var maskX = 0.0; var maskY = 0.0; var maskRadius = 80.0
}
struct EditorPage: Codable, Equatable, Identifiable {
    var id = UUID(); var title: String; var width: Int; var height: Int
    var source = "source.png"; var raw = "pixels.rgba"; var layers: [EditorLayer] = []; var modified = Date()
}
struct LibraryItem: Codable, Equatable, Identifiable {
    var id = UUID(); var parent: UUID?; var title: String; var folder: Bool; var pages: [UUID] = []; var modified = Date()
}
enum Tool: String, CaseIterable {
    case move, text, brush, eraser, shapes, layers, cleaner, eyedropper
    var title: String { switch self {case .move:"تحريك";case .text:"نص";case .brush:"فرشاة";case .eraser:"ممحاة";case .shapes:"أشكال";case .layers:"طبقات";case .cleaner:"تنظيف";case .eyedropper:"قطارة"} }
    var icon: String { switch self {case .move:"hand.draw";case .text:"textformat";case .brush:"paintbrush.pointed";case .eraser:"eraser";case .shapes:"square.on.circle";case .layers:"square.3.layers.3d";case .cleaner:"sparkles";case .eyedropper:"eyedropper"} }
}
enum Panel: String, CaseIterable, Identifiable {
    case content, font, format, color, stroke, background, shadow, position, spacing, threeD, perspective, effects, texture, opacity, styles, mask
    var id: String {rawValue}
    var title: String { switch self {case .content:"النص";case .font:"الخط";case .format:"التنسيق";case .color:"اللون";case .stroke:"الحدود";case .background:"الخلفية";case .shadow:"الظل";case .position:"الموضع";case .spacing:"التباعد";case .threeD:"الأبعاد";case .perspective:"المنظور";case .effects:"التأثيرات";case .texture:"الخامة";case .opacity:"الشفافية";case .styles:"الأنماط";case .mask:"القناع"} }
}
extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {let v=UInt32(hex.replacingOccurrences(of:"#",with:""),radix:16) ?? 0xD4AF37;self.init(red:CGFloat((v>>16)&255)/255,green:CGFloat((v>>8)&255)/255,blue:CGFloat(v&255)/255,alpha:alpha)}
    var hex: String {var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0;getRed(&r,green:&g,blue:&b,alpha:&a);return String(format:"%02X%02X%02X",Int(r*255),Int(g*255),Int(b*255))}
}
