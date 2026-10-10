import Foundation

enum StyleComponent:String,CaseIterable,Identifiable {
    case font,paragraph,fill,outline,shadow,background,effects,texture,geometry
    var id:String{rawValue}
    var title:String{switch self{case .font:"الخط وحجمه";case .paragraph:"المحاذاة والتباعد";case .fill:"لون النص وتدرجه";case .outline:"الحدود";case .shadow:"الظل";case .background:"الخلفية";case .effects:"التأثيرات والأبعاد";case .texture:"الخامة";case .geometry:"المنظور والشبكة"}}
    var keys:[String]{switch self{
    case .font:["fontPath","fontSize","isBold","isItalic","isUnderline","isStrikeThrough","fakeBoldWidth","tashkeelOffset"]
    case .paragraph:["alignment","letterSpacing","lineSpacing","lineHeightMultiple"]
    case .fill:["color","textGradient","textGradientAngle","textGradientType","textGradientStops","textGradientPoints","innerOpacity"]
    case .outline:["strokeColor","strokeWidth","strokeGradient","strokeGradientAngle","strokeGradientStops","strokeGradientType","strokeGradientPoints","extraStrokes"]
    case .shadow:["shadowColor","shadowRadius","shadowDx","shadowDy","shadowAlpha","shadowGradient","shadowGradientAngle","shadowGradientStops","shadowGradientType","shadowGradientPoints"]
    case .background:["backgroundColor","backgroundAlpha","backgroundCornerRadius","backgroundPaddingX","backgroundPaddingY"]
    case .effects:["effectType","effectColor","effectValue","effectAngle","effectDetail","effectSecondVal","effectThirdVal","blurDx","blurDy","blurType","threeDDepth","threeDColor","threeDDarken","fadeAmount","fadeAngle"]
    case .texture:["texturePath","textureScaleX","textureScaleY","textureRotation","textureTranslationX","textureTranslationY"]
    case .geometry:["perspectivePoints","isMeshMode","meshRows","meshCols","meshPoints","rotationX","rotationY"]
    }}
    static func merge(_ source:TextStyle,into current:TextStyle,selected:Set<Self>)throws->TextStyle {
        let input=try JSONSerialization.jsonObject(with:JSONEncoder().encode(source)) as! [String:Any]
        var output=try JSONSerialization.jsonObject(with:JSONEncoder().encode(current)) as! [String:Any]
        for component in selected{for key in component.keys{output[key]=input[key]}}
        return try JSONDecoder().decode(TextStyle.self,from:JSONSerialization.data(withJSONObject:output))
    }
}
