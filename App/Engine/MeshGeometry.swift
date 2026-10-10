import CoreGraphics

enum MeshGeometry {
    static func valid(_ style:TextStyle)->Bool{(1...8).contains(style.meshRows) && (1...8).contains(style.meshCols) && style.meshPoints.count==(style.meshRows+1)*(style.meshCols+1) && style.meshPoints.allSatisfy{$0.x.isFinite && $0.y.isFinite}}
    static func target(x:Double,y:Double,style:TextStyle)->Point {
        guard valid(style),x.isFinite,y.isFinite else{return Point(x:x,y:y)}
        let rows=style.meshRows,cols=style.meshCols
        let col=min(cols-1,max(0,Int(floor(min(1,max(0,x))*Double(cols))))),row=min(rows-1,max(0,Int(floor(min(1,max(0,y))*Double(rows)))))
        let u=x*Double(cols)-Double(col),v=y*Double(rows)-Double(row)
        let a=style.meshPoints[row*(cols+1)+col],b=style.meshPoints[row*(cols+1)+col+1],c=style.meshPoints[(row+1)*(cols+1)+col],d=style.meshPoints[(row+1)*(cols+1)+col+1]
        return Point(x:a.x*(1-u)*(1-v)+b.x*u*(1-v)+c.x*(1-u)*v+d.x*u*v,y:a.y*(1-u)*(1-v)+b.y*u*(1-v)+c.y*(1-u)*v+d.y*u*v)
    }
    static func grid(rows:Int,cols:Int)->[Point]{let rows=min(8,max(1,rows)),cols=min(8,max(1,cols));return (0...rows).flatMap{row in (0...cols).map{col in Point(x:Double(col)/Double(cols),y:Double(row)/Double(rows))}}}
}
