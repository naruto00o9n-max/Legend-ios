import CoreGraphics

enum PerspectiveGeometry {
    /// Extend a four-corner homography to padding, so handles belong to text
    /// coordinates and outlines/shadows aren't clipped at the original edges.
    static func extended(_ corners:[Point],width:Double,height:Double,padding:Double)->[Point]? {
        guard corners.count==4,width>0,height>0 else{return nil}
        let p=corners,dx1=p[1].x-p[2].x,dx2=p[3].x-p[2].x,dx3=p[0].x-p[1].x+p[2].x-p[3].x,dy1=p[1].y-p[2].y,dy2=p[3].y-p[2].y,dy3=p[0].y-p[1].y+p[2].y-p[3].y
        var g=0.0,h=0.0
        if abs(dx3)+abs(dy3)>0.000001{let determinant=dx1*dy2-dx2*dy1;guard abs(determinant)>0.000001 else{return nil};g=(dx3*dy2-dx2*dy3)/determinant;h=(dx1*dy3-dx3*dy1)/determinant}
        let a=p[1].x-p[0].x+g*p[1].x,b=p[3].x-p[0].x+h*p[3].x,c=p[0].x,d=p[1].y-p[0].y+g*p[1].y,e=p[3].y-p[0].y+h*p[3].y,f=p[0].y
        let x=padding/width,y=padding/height
        return [Point(x:-x,y:-y),Point(x:1+x,y:-y),Point(x:1+x,y:1+y),Point(x:-x,y:1+y)].compactMap{point in let divisor=g*point.x+h*point.y+1;guard abs(divisor)>0.000001 else{return nil};return Point(x:(a*point.x+b*point.y+c)/divisor,y:(d*point.x+e*point.y+f)/divisor)}
    }
}
