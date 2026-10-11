import UIKit

/// Screen-space loupe; it renders only a small pixel region on one serial worker.
/// New touches coalesce while rendering, so drawing never waits for image decoding.
final class BrushLoupe:UIView {
    private let image=UIImageView(),crosshair=CAShapeLayer()
    private let worker=DispatchQueue(label:"cookies.brush.loupe",qos:.utility,autoreleaseFrequency:.workItem)
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

/// Coalesces pixel reads on a serial worker. A long press never rasterizes text
/// or reads the image file on the touch-handling thread.
final class EyedropperSampler {
    private let worker=DispatchQueue(label:"cookies.eyedropper",qos:.userInitiated,autoreleaseFrequency:.workItem)
    private var rendering=false
    private var pending:(EditorPage,URL,CGPoint,(UIColor?)->Void)?
    func sample(page:EditorPage,directory:URL,point:CGPoint,completion:@escaping(UIColor?)->Void){
        pending=(page,directory,point,completion);render()
    }
    private func render(){
        guard !rendering,let input=pending else{return};pending=nil;rendering=true
        worker.async{[weak self] in
            let rect=CGRect(x:floor(input.2.x),y:floor(input.2.y),width:1,height:1)
            var color:UIColor?
            if rect.minX>=0,rect.minY>=0,rect.maxX<=CGFloat(input.0.width),rect.maxY<=CGFloat(input.0.height),let image=try? ImagePipeline.compositeRegion(input.0,directory:input.1,rect:rect){
                // Normalize byte layout explicitly; a CGImage's provider is not
                // guaranteed to use RGBA byte order on every iOS device.
                var pixel=[UInt8](repeating:0,count:4)
                let ok=pixel.withUnsafeMutableBytes{buffer->Bool in
                    guard let context=CGContext(data:buffer.baseAddress,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue) else{return false}
                    context.draw(image,in:CGRect(x:0,y:0,width:1,height:1));return true
                }
                if ok{let alpha=max(1,Int(pixel[3]));color=UIColor(red:CGFloat(pixel[0])/CGFloat(alpha),green:CGFloat(pixel[1])/CGFloat(alpha),blue:CGFloat(pixel[2])/CGFloat(alpha),alpha:1)}
            }
            DispatchQueue.main.async{[weak self] in guard let self else{return};self.rendering=false;input.3(color);self.render()}
        }
    }
}

final class EyedropperFeedback:UIView {
    private let disc=UIView(),label=UILabel(),tip=CAShapeLayer()
    override init(frame:CGRect){super.init(frame:frame);isUserInteractionEnabled=false;isHidden=true;isAccessibilityElement=true;accessibilityIdentifier="eyedropper-feedback";accessibilityLabel="اللون الملتقط";disc.layer.cornerRadius=30;disc.layer.borderWidth=3;disc.layer.borderColor=UIColor.white.cgColor;disc.layer.shadowColor=UIColor.black.cgColor;disc.layer.shadowOpacity=0.7;disc.layer.shadowRadius=3;disc.layer.shadowOffset=CGSize(width:0,height:1);addSubview(disc);label.font=UIFont.monospacedSystemFont(ofSize:10,weight:.semibold);label.textColor = .white;label.textAlignment = .center;label.backgroundColor=UIColor(white:0.06,alpha:0.94);label.layer.cornerRadius=7;label.clipsToBounds=true;addSubview(label);tip.fillColor=UIColor.white.cgColor;layer.addSublayer(tip)}
    required init?(coder:NSCoder){fatalError()}
    static func origin(touch:CGPoint,in viewport:CGRect)->CGPoint{
        let width:CGFloat=84,height:CGFloat=96
        return CGPoint(x:max(viewport.minX+6,min(viewport.maxX-width-6,touch.x-width/2)),y:max(viewport.minY+6,min(viewport.maxY-height-6,touch.y-height-24)))
    }
    func show(at point:CGPoint,in viewport:CGRect,color:UIColor?){
        frame=CGRect(origin:Self.origin(touch:point,in:viewport),size:CGSize(width:84,height:96));isHidden=false
        if let color{disc.backgroundColor=color;label.text="#"+color.hex;accessibilityValue=color.hex}else if label.text==nil{disc.backgroundColor=UIColor(white:0.18,alpha:1);label.text="التقاط اللون…"}
        setNeedsLayout()
    }
    override func layoutSubviews(){super.layoutSubviews();disc.frame=CGRect(x:12,y:0,width:60,height:60);label.frame=CGRect(x:0,y:65,width:84,height:20);let p=UIBezierPath();p.move(to:CGPoint(x:37,y:88));p.addLine(to:CGPoint(x:42,y:94));p.addLine(to:CGPoint(x:47,y:88));p.close();tip.path=p.cgPath}
    func hide(){isHidden=true;label.text=nil;accessibilityValue=nil}
}
