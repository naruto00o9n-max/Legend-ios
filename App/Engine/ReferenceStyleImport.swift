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
            var dictionary=defaults
            for (key,value) in row where defaults[key] != nil && !(value is NSNull){
                if colorKeys.contains(key){dictionary[key]=color(value)}
                else if gradientKeys.contains(key),let values=value as? [Any]{dictionary[key]=values.map{color($0)}}
                else if key=="effectType",let effect=value as? String{dictionary[key]=TextEffect(rawValue:effect.lowercased())?.rawValue ?? TextEffect.none.rawValue}
                else if ["perspectivePoints","meshPoints"].contains(key),let flat=value as? [Double]{guard flat.count%2==0 else{throw ImageFailure.message("إحداثيات منظور النمط غير صالحة")};dictionary[key]=stride(from:0,to:flat.count,by:2).map{["x":flat[$0],"y":flat[$0+1]]}}
                else{dictionary[key]=value}
            }
            if let path=row["fontPath"] as? String,!path.isEmpty{dictionary["fontPath"]=(path as NSString).lastPathComponent}
            var style=try JSONDecoder().decode(TextStyle.self,from:JSONSerialization.data(withJSONObject:dictionary))
            if let opacity=row["innerOpacity"] as? Double{style.innerOpacity=min(1,max(0,opacity/255))}
            if row["isFadeEnabled"] as? Bool==true{style.fadeAmount=min(1,max(0,(row["fadeValue"] as? Double ?? 0)/100));style.fadeAngle=row["fadeAngle"] as? Double}
            if let outlines=row["extraStrokes"] as? [[String:Any]]{style.extraStrokes=outlines.map{ExtraOutline(width:($0["width"] as? Double) ?? 0,color:color($0["color"] ?? 0))}}
            return SavedTextStyle(title:(row["name"] as? String) ?? "نمط مستورد",group:(row["folder"] as? String) ?? "أنماط تايبر",style:style)
        }
    }
    private static func color(_ value:Any)->String{if let text=value as? String{return text.replacingOccurrences(of:"#",with:"")};let n=(value as? NSNumber)?.int64Value ?? 0;return String(format:"%06X",UInt32(truncatingIfNeeded:n)&0xFFFFFF)}
}
