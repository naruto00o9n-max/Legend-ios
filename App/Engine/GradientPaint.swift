import UIKit

enum GradientPaint {
    static func normalized(_ colors:[String],_ stops:[Double])->[(Double,String)] {
        guard !colors.isEmpty else{return []}
        return colors.enumerated().map{index,color in (stops.count==colors.count ? min(1,max(0,stops[index])):Double(index)/Double(max(1,colors.count-1)),color)}.sorted{$0.0<$1.0}
    }
    static func draw(colors:[String],stops:[Double],angle:Double,type:Int,rect:CGRect,in ctx:CGContext) {
        var values=normalized(colors,stops);guard !values.isEmpty else{return};if values.count==1{values.append((1,values[0].1))}
        let locations=values.map{CGFloat($0.0)},cg=values.map{UIColor(hex:$0.1).cgColor}
        guard let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:cg as CFArray,locations:locations) else{return}
        let center=CGPoint(x:rect.midX,y:rect.midY),radians=angle*Double.pi/180
        let dx=CGFloat(cos(radians)),dy=CGFloat(sin(radians))
        let radius=(abs(dx)*rect.width+abs(dy)*rect.height)/2
        switch type {
        case 1:ctx.drawRadialGradient(gradient,startCenter:center,startRadius:0,endCenter:center,endRadius:max(rect.width,rect.height)/2,options:[.drawsAfterEndLocation])
        case 2:
            ctx.saveGState();ctx.translateBy(x:center.x,y:center.y);ctx.rotate(by:CGFloat(radians));ctx.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:radius,y:0),options:[.drawsAfterEndLocation]);ctx.scaleBy(x:-1,y:1);ctx.drawLinearGradient(gradient,start:.zero,end:CGPoint(x:radius,y:0),options:[.drawsAfterEndLocation]);ctx.restoreGState()
        case 3:
            // Angular gradient: bounded wedges keep memory independent of canvas height.
            for step in 0..<720{let t=Double(step)/720,theta=CGFloat(t*Double.pi*2)+CGFloat(radians),next=theta+CGFloat.pi/360+0.002;let color=sample(t,values);ctx.setFillColor(color.cgColor);ctx.beginPath();ctx.move(to:center);ctx.addArc(center:center,radius:hypot(rect.width,rect.height),startAngle:theta,endAngle:next,clockwise:false);ctx.closePath();ctx.fillPath()}
        default:ctx.drawLinearGradient(gradient,start:CGPoint(x:center.x-dx*radius,y:center.y-dy*radius),end:CGPoint(x:center.x+dx*radius,y:center.y+dy*radius),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        }
    }
    private static func sample(_ t:Double,_ values:[(Double,String)])->UIColor {
        guard let first=values.first,let last=values.last else{return .clear};if t<=first.0{return UIColor(hex:first.1)};if t>=last.0{return UIColor(hex:last.1)}
        let i=values.firstIndex{$0.0>=t} ?? values.count-1,a=values[i-1],b=values[i],f=CGFloat((t-a.0)/max(0.00001,b.0-a.0))
        var ar:CGFloat=0,ag:CGFloat=0,ab:CGFloat=0,aa:CGFloat=0,br:CGFloat=0,bg:CGFloat=0,bb:CGFloat=0,ba:CGFloat=0
        UIColor(hex:a.1).getRed(&ar,green:&ag,blue:&ab,alpha:&aa);UIColor(hex:b.1).getRed(&br,green:&bg,blue:&bb,alpha:&ba)
        return UIColor(red:ar+(br-ar)*f,green:ag+(bg-ag)*f,blue:ab+(bb-ab)*f,alpha:aa+(ba-aa)*f)
    }
}
