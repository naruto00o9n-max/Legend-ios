import Foundation

/// Reads the documented JSON fields of the Android SavedTextStyle export.
/// Unsupported original effects remain tracked in the parity ledger.
enum ReferenceStyleImport {
    static func decode(_ data:Data)throws->[SavedTextStyle] {
        guard let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]],!rows.isEmpty,rows.count<=2000 else{throw ImageFailure.message("ملف أنماط تايبر غير صالح")}
        let defaults=try JSONSerialization.jsonObject(with:JSONEncoder().encode(TextStyle())) as! [String:Any]
        let colorKeys=Set(["color","strokeColor","shadowColor","backgroundColor","effectColor","threeDColor"])
        let gradientKeys=Set(["textGradient","strokeGradient","shadowGradient"])
        return try rows.map{row in
            guard (row["strokeShape"] as? Int ?? 0)==0 else{throw ImageFailure.message("شكل حد النص غير مدعوم بعد؛ احتُفظ بالملف دون تغييره")}
            var dictionary=defaults
            for (key,value) in row where defaults[key] != nil && !(value is NSNull){
                if colorKeys.contains(key){dictionary[key]=color(value)}
                else if gradientKeys.contains(key),let values=value as? [Any]{dictionary[key]=values.map{color($0)}}
                else if key=="effectType",let effect=value as? String{guard let supported=TextEffect(rawValue:effect.lowercased()) else{throw ImageFailure.message("تأثير النمط غير مدعوم بعد: "+effect)};dictionary[key]=supported.rawValue}
                else if ["perspectivePoints","meshPoints"].contains(key),let flat=value as? [Double]{guard flat.count%2==0 else{throw ImageFailure.message("إحداثيات منظور النمط غير صالحة")};dictionary[key]=stride(from:0,to:flat.count,by:2).map{["x":flat[$0],"y":flat[$0+1]]}}
                else{dictionary[key]=value}
            }
            if let path=row["fontPath"] as? String,!path.isEmpty{dictionary["fontPath"]=(path as NSString).lastPathComponent}
            var style=try JSONDecoder().decode(TextStyle.self,from:JSONSerialization.data(withJSONObject:dictionary))
            guard !style.isMeshMode || MeshGeometry.valid(style) else{throw ImageFailure.message("شبكة تشويه النمط غير صالحة أو تتجاوز 8×8")}
            if let opacity=row["innerOpacity"] as? Double{style.innerOpacity=min(1,max(0,opacity/255))}
            if row["isFadeEnabled"] as? Bool==true{style.fadeAmount=min(1,max(0,(row["fadeValue"] as? Double ?? 0)/100));style.fadeAngle=row["fadeAngle"] as? Double}
            if let outlines=row["extraStrokes"] as? [[String:Any]]{style.extraStrokes=try outlines.map{outline in
                guard (outline["strokeShape"] as? Int ?? 0)==0 else{throw ImageFailure.message("شكل الحد الإضافي غير مدعوم بعد؛ احتُفظ بالملف دون تغييره")}
                return ExtraOutline(width:(outline["strokeWidth"] as? Double) ?? (outline["width"] as? Double) ?? 0,color:color(outline["strokeColor"] ?? outline["color"] ?? 0),gradient:(outline["strokeGradient"] as? [Any])?.map{color($0)},stops:outline["strokeGradientStops"] as? [Double],angle:outline["strokeGradientAngle"] as? Double,gradientType:outline["strokeGradientType"] as? Int)
            }}
            return SavedTextStyle(title:(row["name"] as? String) ?? "نمط مستورد",group:(row["folder"] as? String) ?? "أنماط تايبر",style:style)
        }
    }
    private static func color(_ value:Any)->String{if let text=value as? String{return text.replacingOccurrences(of:"#",with:"")};let n=(value as? NSNumber)?.int64Value ?? 0;return String(format:"%06X",UInt32(truncatingIfNeeded:n)&0xFFFFFF)}
}
