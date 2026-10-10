import UIKit

/// Screen-space loupe; it renders only a small pixel region on one serial worker.
/// New touches coalesce while rendering, so drawing never waits for image decoding.
final class BrushLoupe:UIView {
    private let image=UIImageView(),crosshair=CAShapeLayer()
    private let worker=DispatchQueue(label:"cookies.brush.loupe",qos:.utility)
    private var pending:(EditorPage,URL,CGPoint)?
    private var rendering=false
    private var lastSample:CFTimeInterval=0
    var shouldSample:Bool{!rendering && CACurrentMediaTime()-lastSample >= 1.0/20.0}
    private var generation=UUID()
    private var focus=CGPoint(x:0.5,y:0.5)
    override init(frame:CGRect){super.init(frame:frame);isUserInteractionEnabled=false;backgroundColor=UIColor(white:0.08,alpha:0.96);layer.cornerRadius=16;layer.borderWidth=1;layer.borderColor=UIColor(hex:"D4AF37").withAlphaComponent(0.6).cgColor;clipsToBounds=true;image.contentMode = .scaleAspectFit;image.layer.magnificationFilter = .nearest;addSubview(image);layer.addSublayer(crosshair);crosshair.strokeColor=UIColor.white.cgColor;crosshair.lineWidth=1;accessibilityIdentifier="brush-loupe";isHidden=true}
    required init?(coder:NSCoder){fatalError()}
    override func layoutSubviews(){super.layoutSubviews();image.frame=bounds.insetBy(dx:6,dy:6);let path=UIBezierPath(),center=CGPoint(x:image.frame.minX+image.frame.width*focus.x,y:image.frame.minY+image.frame.height*focus.y);path.move(to:CGPoint(x:center.x-10,y:center.y));path.addLine(to:CGPoint(x:center.x+10,y:center.y));path.move(to:CGPoint(x:center.x,y:center.y-10));path.addLine(to:CGPoint(x:center.x,y:center.y+10));crosshair.path=path.cgPath}
    func show(page:EditorPage,directory:URL,point:CGPoint){lastSample=CACurrentMediaTime();isHidden=false;pending=(page,directory,point);render()}
    func hide(){isHidden=true;pending=nil;generation=UUID();image.image=nil}
    private func render(){guard !rendering,let input=pending else{return};pending=nil;rendering=true;let token=generation
        worker.async{[weak self] in let page=input.0,point=input.2;let edge=72;let rect=CGRect(x:max(0,min(page.width-edge,Int(point.x)-edge/2)),y:max(0,min(page.height-edge,Int(point.y)-edge/2)),width:min(edge,page.width),height:min(edge,page.height));let rendered=(try? ImagePipeline.compositeRegion(page,directory:input.1,rect:rect)).map{UIImage(cgImage:$0)}
            DispatchQueue.main.async{[weak self] in guard let self else{return};self.rendering=false;if self.generation==token,!self.isHidden{self.image.image=rendered;self.focus=CGPoint(x:(point.x-rect.minX)/max(1,rect.width),y:(point.y-rect.minY)/max(1,rect.height));self.setNeedsLayout()};self.render()}
        }
    }
}
