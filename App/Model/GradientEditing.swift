import Foundation

/// A removed SwiftUI row may still ask its Binding for a value during teardown.
/// Reads and writes are valid only for stops which still exist in the current layer.
enum GradientEditing {
    static func color(_ colors:[String],at index:Int,fallback:String="FFFFFF")->String {
        colors.indices.contains(index) ? colors[index]:fallback
    }
    static func position(_ colors:[String],stops:[Double],at index:Int)->Double {
        guard colors.indices.contains(index) else{return 0.5}
        if stops.count==colors.count,stops[index].isFinite{return min(1,max(0,stops[index]))}
        return Double(index)/Double(max(1,colors.count-1))
    }
    static func setColor(_ value:String,at index:Int,colors:inout [String]) {
        guard colors.indices.contains(index) else{return};colors[index]=value
    }
    static func setPosition(_ value:Double,at index:Int,colors:[String],stops:inout [Double]) {
        guard value.isFinite,colors.indices.contains(index) else{return}
        var normalized=colors.indices.map{position(colors,stops:stops,at:$0)}
        normalized[index]=min(1,max(0,value));stops=normalized
    }
    static func remove(at index:Int,colors:inout [String],stops:inout [Double]) {
        guard colors.count>2,colors.indices.contains(index) else{return}
        var normalized=colors.indices.map{position(colors,stops:stops,at:$0)}
        colors.remove(at:index);normalized.remove(at:index);stops=normalized
    }
}

struct GradientMapBaseline:Codable,Equatable,Hashable {
    struct Channel:Codable,Equatable,Hashable {
        var colors:[String];var stops:[Double];var angle:Double;var type:Int;var points:[Point]?
    }
    var text:Channel;var stroke:Channel;var shadow:Channel
    var strokeWidth:Double;var shadowRadius:Double;var shadowDy:Double
    init(_ s:TextStyle){
        text=Channel(colors:s.textGradient,stops:s.textGradientStops,angle:s.textGradientAngle,type:s.textGradientType,points:s.textGradientPoints)
        stroke=Channel(colors:s.strokeGradient,stops:s.strokeGradientStops,angle:s.strokeGradientAngle,type:s.strokeGradientType,points:s.strokeGradientPoints)
        shadow=Channel(colors:s.shadowGradient,stops:s.shadowGradientStops,angle:s.shadowGradientAngle,type:s.shadowGradientType,points:s.shadowGradientPoints)
        strokeWidth=s.strokeWidth;shadowRadius=s.shadowRadius;shadowDy=s.shadowDy
    }
    func restore(_ s:inout TextStyle){
        s.textGradient=text.colors;s.textGradientStops=text.stops;s.textGradientAngle=text.angle;s.textGradientType=text.type;s.textGradientPoints=text.points
        s.strokeGradient=stroke.colors;s.strokeGradientStops=stroke.stops;s.strokeGradientAngle=stroke.angle;s.strokeGradientType=stroke.type;s.strokeGradientPoints=stroke.points;s.strokeWidth=strokeWidth
        s.shadowGradient=shadow.colors;s.shadowGradientStops=shadow.stops;s.shadowGradientAngle=shadow.angle;s.shadowGradientType=shadow.type;s.shadowGradientPoints=shadow.points;s.shadowRadius=shadowRadius;s.shadowDy=shadowDy
    }
}
