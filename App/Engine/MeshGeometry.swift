import CoreGraphics

enum MeshGeometry {
    static func target(x:Double,y:Double,style:TextStyle)->Point {
        let rows=max(1,style.meshRows),cols=max(1,style.meshCols)
        guard style.meshPoints.count==(rows+1)*(cols+1) else{return Point(x:x,y:y)}
        let col=min(cols-1,max(0,Int(floor(x*Double(cols))))),row=min(rows-1,max(0,Int(floor(y*Double(rows)))))
        let u=x*Double(cols)-Double(col),v=y*Double(rows)-Double(row)
        let a=style.meshPoints[row*(cols+1)+col],b=style.meshPoints[row*(cols+1)+col+1],c=style.meshPoints[(row+1)*(cols+1)+col],d=style.meshPoints[(row+1)*(cols+1)+col+1]
        return Point(x:a.x*(1-u)*(1-v)+b.x*u*(1-v)+c.x*(1-u)*v+d.x*u*v,y:a.y*(1-u)*(1-v)+b.y*u*(1-v)+c.y*(1-u)*v+d.y*u*v)
    }
    static func grid(rows:Int,cols:Int)->[Point]{(0...rows).flatMap{row in (0...cols).map{col in Point(x:Double(col)/Double(cols),y:Double(row)/Double(rows))}}}
}
