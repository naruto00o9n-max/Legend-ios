import UIKit

enum GradientGeometry {
    static func points(_ style:TextStyle,target:String,size:CGSize)->[Point]{
        let custom=target=="stroke" ? style.strokeGradientPoints:target=="shadow" ? style.shadowGradientPoints:style.textGradientPoints
        if let custom,custom.count==2{return custom}
        let angle=target=="stroke" ? style.strokeGradientAngle:target=="shadow" ? style.shadowGradientAngle:style.textGradientAngle
        let type=target=="stroke" ? style.strokeGradientType:target=="shadow" ? style.shadowGradientType:style.textGradientType
        let dx=cos(angle*Double.pi/180),dy=sin(angle*Double.pi/180),radius=(abs(dx)*Double(size.width)+abs(dy)*Double(size.height))/2
        let a=Point(x:0.5-dx*radius/max(1,Double(size.width)),y:0.5-dy*radius/max(1,Double(size.height))),b=Point(x:0.5+dx*radius/max(1,Double(size.width)),y:0.5+dy*radius/max(1,Double(size.height)))
        return [type==0 ? a:Point(x:0.5,y:0.5),b]
    }
    static func set(_ points:[Point],target:String,style:inout TextStyle){if target=="stroke"{style.strokeGradientPoints=points}else if target=="shadow"{style.shadowGradientPoints=points}else{style.textGradientPoints=points}}
}
