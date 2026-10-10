import SwiftUI

struct GeometryInspector:View {
    @ObservedObject var model:EditorModel
    var mesh:Bool {guard let style=model.active?.style else{return false};return style.isMeshMode && MeshGeometry.valid(style)}
    var points:[Point] {let s=model.active?.style ?? TextStyle();if mesh {return s.meshPoints};return s.perspectivePoints.count==4 ? s.perspectivePoints:[Point(x:0,y:0),Point(x:1,y:0),Point(x:1,y:1),Point(x:0,y:1)]}
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            Toggle("شبكة التشويه",isOn:Binding(get:{mesh},set:{value in model.change{l in l.style.isMeshMode=value;if value{l.style.meshRows=3;l.style.meshCols=3;l.style.meshPoints=MeshGeometry.grid(rows:3,cols:3)}}}))
            if mesh{Stepper("صفوف الشبكة: \(model.active?.style.meshRows ?? 3)",value:Binding(get:{model.active?.style.meshRows ?? 3},set:{v in resizeGrid(rows:v,cols:model.active?.style.meshCols ?? 3)}),in:1...8);Stepper("أعمدة الشبكة: \(model.active?.style.meshCols ?? 3)",value:Binding(get:{model.active?.style.meshCols ?? 3},set:{v in resizeGrid(rows:model.active?.style.meshRows ?? 3,cols:v)}),in:1...8)}
            Text("اسحب المقابض حول النص داخل اللوحة. هذه المعاينة تعرض النص نفسه.").font(.system(size:12)).foregroundStyle(Palette.quiet)
            GeometryReader{g in
                let inset:CGFloat=16,size=CGSize(width:g.size.width-32,height:g.size.height-32)
                ZStack(alignment:.topLeading){
                    if let preview=preview(size){Image(uiImage:preview).resizable().scaledToFit().padding(inset)}
                    Path{path in
                        let values=points,rows=model.active?.style.meshRows ?? 3,cols=model.active?.style.meshCols ?? 3
                        if mesh{for row in 0...rows{for col in 0...cols{let p=values[row*(cols+1)+col].cg;if col==0{path.move(to:CGPoint(x:inset+p.x*size.width,y:inset+p.y*size.height))}else{path.addLine(to:CGPoint(x:inset+p.x*size.width,y:inset+p.y*size.height))}}};for col in 0...cols{for row in 0...rows{let p=values[row*(cols+1)+col].cg;if row==0{path.move(to:CGPoint(x:inset+p.x*size.width,y:inset+p.y*size.height))}else{path.addLine(to:CGPoint(x:inset+p.x*size.width,y:inset+p.y*size.height))}}}}
                        else{for (i,p) in values.enumerated(){let q=CGPoint(x:inset+CGFloat(p.x)*size.width,y:inset+CGFloat(p.y)*size.height);if i==0{path.move(to:q)}else{path.addLine(to:q)}};path.closeSubpath()}
                    }.stroke(Palette.gold.opacity(0.7),lineWidth:1)
                    ForEach(Array(points.enumerated()),id:\.offset){index,point in
                        Circle().fill(Palette.ink).overlay(Circle().stroke(Palette.gold,lineWidth:2)).frame(width:18,height:18).position(x:inset+CGFloat(point.x)*size.width,y:inset+CGFloat(point.y)*size.height)
                            .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("geometry")).onChanged{gesture in let value=Point(x:min(1,max(0,Double((gesture.location.x-inset)/size.width))),y:min(1,max(0,Double((gesture.location.y-inset)/size.height))));let isMesh=mesh;var list=points;list[index]=value;model.change{l in if isMesh{l.style.meshPoints=list}else{l.style.perspectivePoints=list}}})
                    }
                }.coordinateSpace(name:"geometry")
            }.frame(height:180).glass(16)
            Button("إعادة الضبط"){model.change{$0.style.perspectivePoints=[];$0.style.isMeshMode=false;$0.style.meshPoints=[]}}.font(.system(size:13))
        }
    }
    private func resizeGrid(rows:Int,cols:Int){let old=model.active?.style ?? TextStyle();let next=MeshGeometry.grid(rows:rows,cols:cols).map{MeshGeometry.target(x:$0.x,y:$0.y,style:old)};model.change{$0.style.meshRows=rows;$0.style.meshCols=cols;$0.style.meshPoints=next}}
    private func preview(_ size:CGSize)->UIImage? {
        guard var layer=model.active,size.width>0,size.height>0 else{return nil}
        layer.frame.x=0;layer.frame.y=0;layer.rotation=0;layer.scaleX=1;layer.scaleY=1
        let bounds=LayerRenderer.bounds(layer),scale=min(size.width/max(1,bounds.width),size.height/max(1,bounds.height))*0.75
        let format=UIGraphicsImageRendererFormat();format.scale=1
        return UIGraphicsImageRenderer(size:size,format:format).image{output in
            let c=output.cgContext;c.translateBy(x:(size.width-bounds.width*scale)/2,y:(size.height-bounds.height*scale)/2);c.scaleBy(x:scale,y:scale)
            LayerRenderer.drawText(layer,rect:bounds,context:c,directory:model.directory)
        }
    }
}
