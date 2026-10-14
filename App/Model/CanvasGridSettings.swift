import Foundation
import CoreGraphics

enum CanvasGridKind:String,Codable,CaseIterable,Identifiable {
    case squares,thirds,center
    var id:String{rawValue}
    var title:String{switch self{case .squares:"مربعات";case .thirds:"أثلاث";case .center:"المركز"}}
}
struct CanvasGridSettings:Codable,Equatable {
    var enabled=false
    var kind=CanvasGridKind.squares
    var spacing=64.0
    var opacity=0.45
    var width=1.0
    var color="FFFFFF"
    var normalized:Self{var value=self;value.spacing=spacing.isFinite ? min(512,max(1,spacing)):64;value.opacity=opacity.isFinite ? min(1,max(0.05,opacity)):0.45;value.width=width.isFinite ? min(3,max(0.5,width)):1;if !["FFFFFF","000000","D4AF37"].contains(color){value.color="FFFFFF"};return value}
    static func decode(_ data:Data)->Self{((try? JSONDecoder().decode(Self.self,from:data)) ?? Self()).normalized}
    var data:Data{(try? JSONEncoder().encode(normalized)) ?? Data()}
}
struct CanvasGridLine {let start:CGPoint;let end:CGPoint}
enum CanvasGridGeometry {
    /// Geometry is limited to the visible image and a bounded screen density.
    /// Coordinates remain anchored to the original image while zooming/panning.
    static func lines(settings:CanvasGridSettings,image:CGRect,visible:CGRect,zoom:CGFloat)->[CanvasGridLine]{
        let settings=settings.normalized,area=image.intersection(visible)
        guard settings.enabled,!area.isNull,!area.isEmpty,zoom.isFinite,zoom>0,area.minX.isFinite,area.minY.isFinite,area.width.isFinite,area.height.isFinite else{return []}
        var output:[CanvasGridLine]=[]
        func vertical(_ x:CGFloat){if x>=area.minX && x<=area.maxX{output.append(CanvasGridLine(start:CGPoint(x:x,y:area.minY),end:CGPoint(x:x,y:area.maxY)))}}
        func horizontal(_ y:CGFloat){if y>=area.minY && y<=area.maxY{output.append(CanvasGridLine(start:CGPoint(x:area.minX,y:y),end:CGPoint(x:area.maxX,y:y)))}}
        switch settings.kind {
        case .squares:
            let base=CGFloat(settings.spacing),factor=CGFloat(pow(2.0,max(0.0,ceil(log2(Double(12/(base*zoom))))))),step=base*factor
            guard step.isFinite,step>0 else{return []}
            let x0=ceil(area.minX/step)*step,y0=ceil(area.minY/step)*step
            for i in 0..<min(512,max(0,Int(floor((area.maxX-x0)/step))+1)){vertical(x0+CGFloat(i)*step)}
            for i in 0..<min(512,max(0,Int(floor((area.maxY-y0)/step))+1)){horizontal(y0+CGFloat(i)*step)}
        case .thirds:for i in 1...2{vertical(image.minX+image.width*CGFloat(i)/3);horizontal(image.minY+image.height*CGFloat(i)/3)}
        case .center:vertical(image.midX);horizontal(image.midY)
        }
        return output
    }
}
