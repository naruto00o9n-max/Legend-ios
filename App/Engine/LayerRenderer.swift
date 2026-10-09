import UIKit
import CoreText

enum Fonts {
    private static let cache=NSCache<NSString,UIFont>()
    static var userDirectory:URL {FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Cookies/Fonts",isDirectory:true)}
    static var userFiles:[URL] {(try? FileManager.default.contentsOfDirectory(at:userDirectory,includingPropertiesForKeys:nil)) ?? []}
    static var files:[URL] {(Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts") ?? [])+userFiles.filter{$0.pathExtension.lowercased()=="ttf"}}
    static var otf:[URL] {(Bundle.main.urls(forResourcesWithExtension:"otf",subdirectory:"Fonts") ?? [])+userFiles.filter{$0.pathExtension.lowercased()=="otf"}}
    static func register(){cache.removeAllObjects();for url in files+otf{CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil)}}
    static func font(_ style:TextStyle)->UIFont {
        let key="\(style.fontPath)|\(style.fontSize)|\(style.isBold)|\(style.isItalic)" as NSString
        if let cached=cache.object(forKey:key){return cached}
        let path=Bundle.main.url(forResource:style.fontPath,deletingExtension: false)
        let url=path ?? userFiles.first{$0.lastPathComponent==style.fontPath}
        var f=UIFont.systemFont(ofSize:CGFloat(style.fontSize)),loaded=false
        if let url,let provider=CGDataProvider(url:url as CFURL),let cg=CGFont(provider),let name=cg.postScriptName,let custom=UIFont(name:name as String,size:CGFloat(style.fontSize)){f=custom;loaded=true}
        var traits=UIFontDescriptor.SymbolicTraits();if style.isBold{traits.insert(.traitBold)};if style.isItalic{traits.insert(.traitItalic)}
        if let d=f.fontDescriptor.withSymbolicTraits(traits){f=UIFont(descriptor:d,size:CGFloat(style.fontSize))};if loaded{cache.countLimit=256;cache.setObject(f,forKey:key)};return f
    }
}
extension Bundle {func url(forResource name:String,deletingExtension:Bool)->URL?{url(forResource:name,withExtension:nil,subdirectory:"Fonts")}}
enum LayerRenderer {
    static func attributed(_ l:EditorLayer,color:UIColor?=nil)->NSAttributedString {
        let s=l.style,p=NSMutableParagraphStyle();p.alignment=[NSTextAlignment.left,.center,.right,.justified][max(0,min(3,s.alignment))];p.lineSpacing=CGFloat(s.lineSpacing);p.lineBreakMode = .byWordWrapping
        var attributes:[NSAttributedString.Key:Any]=[.font:Fonts.font(s),.foregroundColor:color ?? UIColor(hex:s.color),.paragraphStyle:p,.kern:s.letterSpacing]
        if s.isUnderline{attributes[.underlineStyle]=NSUnderlineStyle.single.rawValue};if s.isStrikeThrough{attributes[.strikethroughStyle]=NSUnderlineStyle.single.rawValue}
        let result=NSMutableAttributedString(string:l.textContent,attributes:attributes)
        for run in s.spans {let range=NSRange(location:max(0,run.start),length:max(0,min(result.length,run.end)-max(0,run.start)));guard range.location+range.length<=result.length else{continue};if let color=run.color{result.addAttribute(.foregroundColor,value:UIColor(hex:color),range:range)};if let size=run.fontSize{var fontStyle=s;fontStyle.fontSize=size;result.addAttribute(.font,value:Fonts.font(fontStyle),range:range)}}
        return result
    }
    static func bounds(_ l:EditorLayer)->CGRect {
        if l.kind == .text {let b=attributed(l).boundingRect(with:CGSize(width:max(20,l.style.boxWidth),height:100000),options:[.usesLineFragmentOrigin,.usesFontLeading],context:nil);return CGRect(x:0,y:0,width:max(20,l.style.boxWidth),height:max(24,ceil(b.height)))}
        return CGRect(x:0,y:0,width:l.frame.width,height:l.frame.height)
    }
    static func transform(_ l:EditorLayer)->CGAffineTransform {
        let b=bounds(l)
        return CGAffineTransform(translationX:CGFloat(l.frame.x)+b.width/2,y:CGFloat(l.frame.y)+b.height/2).rotated(by:CGFloat(l.rotation)*CGFloat.pi/180).scaledBy(x:CGFloat(l.scaleX),y:CGFloat(l.scaleY)).translatedBy(x:-b.width/2,y:-b.height/2)
    }
    static func draw(_ layers:[EditorLayer],in ctx:CGContext,directory:URL) {
        UIGraphicsPushContext(ctx);defer{UIGraphicsPopContext()}
        for l in layers where l.isVisible {
            ctx.saveGState();ctx.setAlpha(CGFloat(l.opacity));ctx.setBlendMode(l.blend.cg)
            let b=bounds(l);ctx.concatenate(transform(l))
            if l.isMaskEnabled{ctx.addEllipse(in:CGRect(x:l.maskX-l.maskRadius,y:l.maskY-l.maskRadius,width:l.maskRadius*2,height:l.maskRadius*2));ctx.clip()}
            switch l.kind {
            case .text:drawText(l,rect:b,context:ctx,directory:directory)
            case .image:if let image=ImagePipeline.asset(directory.appendingPathComponent(l.imagePath)){image.draw(in:b)}
            case .shape:
                let path=shapePath(l.shape,rect:b);UIColor(hex:l.style.color).setFill();path.fill();if l.style.strokeWidth>0{UIColor(hex:l.style.strokeColor).setStroke();path.lineWidth=CGFloat(l.style.strokeWidth);path.stroke()}
            case .drawing:
                ctx.beginTransparencyLayer(auxiliaryInfo:nil)
                for s in l.strokes where !s.points.isEmpty {ctx.saveGState();let path=UIBezierPath();path.move(to:s.points[0].cg);for p in s.points.dropFirst(){path.addLine(to:p.cg)};path.lineCapStyle = .round;path.lineJoinStyle = .round;path.lineWidth=CGFloat(s.width);UIColor(hex:s.color).setStroke();if s.erase{ctx.setBlendMode(.clear)};if s.brush=="neon"{ctx.setShadow(offset:.zero,blur:CGFloat(s.width),color:UIColor(hex:s.color).cgColor)};if s.brush=="water"{ctx.setAlpha(0.25)};if s.points.count==1{UIColor(hex:s.color).setFill();UIBezierPath(ovalIn:CGRect(x:s.points[0].x-s.width/2,y:s.points[0].y-s.width/2,width:s.width,height:s.width)).fill()}else{path.stroke()};ctx.restoreGState()}
                ctx.endTransparencyLayer()
            }
            ctx.restoreGState()
        }
    }
    static func drawText(_ l:EditorLayer,rect:CGRect,context c:CGContext,directory:URL) {
        let s=l.style;let background=rect.insetBy(dx:-CGFloat(s.backgroundPaddingX),dy:-CGFloat(s.backgroundPaddingY))
        if s.backgroundAlpha>0{UIColor(hex:s.backgroundColor,alpha:CGFloat(s.backgroundAlpha)/255).setFill();UIBezierPath(roundedRect:background,cornerRadius:CGFloat(s.backgroundCornerRadius)).fill()}
        func text(_ color:UIColor?=nil,_ offset:CGPoint = .zero){attributed(l,color:color).draw(with:rect.offsetBy(dx:offset.x,dy:offset.y),options:[.usesLineFragmentOrigin,.usesFontLeading],context:nil)}
        for depth in stride(from:min(64,s.threeDDepth),through:1,by:-1){text(UIColor(hex:s.threeDColor),CGPoint(x:depth,y:depth))}
        if TextRaster.draw(l,rect:rect,in:c,directory:directory){return}
        if s.shadowRadius>0||s.effectType == .shadow||s.effectType == .neon||s.effectType == .blur {c.setShadow(offset:CGSize(width:s.shadowDx,height:s.shadowDy),blur:CGFloat(s.effectType == .none ? s.shadowRadius:s.effectValue),color:UIColor(hex:s.effectType == .neon ? s.effectColor:s.shadowColor,alpha:CGFloat(s.shadowAlpha)/255).cgColor)}
        if s.strokeWidth>0||s.fakeBoldWidth>0 {
            let a=NSMutableAttributedString(attributedString:attributed(l));a.addAttributes([.strokeColor:UIColor(hex:s.strokeColor),.strokeWidth:-max(s.strokeWidth,s.fakeBoldWidth)/max(1,s.fontSize)*100],range:NSRange(location:0,length:a.length));a.draw(with:rect,options:[.usesLineFragmentOrigin,.usesFontLeading],context:nil)
        }
        switch s.effectType {
        case .glitch,.error: text(UIColor(hex:s.effectColor),CGPoint(x:s.effectValue,y:0));text(UIColor(hex:s.strokeColor),CGPoint(x:-s.effectValue,y:0));text()
        case .slice:
            for i in 0..<max(2,min(30,Int(s.effectDetail))) {let count=max(2,min(30,Int(s.effectDetail)));c.saveGState();c.clip(to:CGRect(x:-s.effectValue,y:rect.height*CGFloat(i)/CGFloat(count),width:rect.width+s.effectValue*2,height:rect.height/CGFloat(count)));text(nil,CGPoint(x:i%2==0 ? s.effectValue:-s.effectValue,y:0));c.restoreGState()}
        case .fade:c.saveGState();c.setAlpha(max(0.05,1-CGFloat(s.effectValue)/100));text();c.restoreGState()
        case .warp:c.saveGState();c.concatenate(CGAffineTransform(a:1,b:0,c:CGFloat(s.effectValue)/100,d:1,tx:0,ty:0));text();c.restoreGState()
        default:text()
        }
    }
    static func shapePath(_ type:Int,rect:CGRect)->UIBezierPath {
        let p=UIBezierPath(),w=rect.width/2,h=rect.height/2
        func q(_ x:CGFloat,_ y:CGFloat)->CGPoint{CGPoint(x:x+w+rect.minX,y:y+h+rect.minY)}
        func lines(_ values:[CGPoint]){for (i,v) in values.enumerated(){if i==0{p.move(to:v)}else{p.addLine(to:v)}};p.close()}
        func regular(_ sides:Int,_ inner:CGFloat?=nil){let radius=min(w,h),count=inner==nil ? sides:sides*2;for i in 0..<count{let angle=CGFloat(i)*CGFloat.pi*2/CGFloat(count),r=(inner != nil && i%2==1) ? radius*inner!:radius;let point=q(sin(angle)*r,-cos(angle)*r);if i==0{p.move(to:point)}else{p.addLine(to:point)}};p.close()}
        switch type%20 {
        case 0:p.append(UIBezierPath(rect:rect))
        case 1:p.append(UIBezierPath(roundedRect:rect,byRoundingCorners:.allCorners,cornerRadii:CGSize(width:rect.width*0.15,height:rect.height*0.15)))
        case 2:p.append(UIBezierPath(ovalIn:CGRect(x:rect.midX-min(w,h),y:rect.midY-min(w,h),width:min(w,h)*2,height:min(w,h)*2)))
        case 3:p.append(UIBezierPath(ovalIn:rect))
        case 4:lines([q(0,-h),q(w,h),q(-w,h)])
        case 5:lines([q(-w,-h),q(w,h),q(-w,h)])
        case 6:regular(5)
        case 7:regular(6)
        case 8:regular(8)
        case 9:regular(5,0.4)
        case 10:regular(6,0.5)
        case 11:p.move(to:q(0,h*0.3));p.addCurve(to:q(0,-h*0.5),controlPoint1:q(-w,-h*0.1),controlPoint2:q(-w,-h));p.addCurve(to:q(0,h*0.3),controlPoint1:q(w,-h),controlPoint2:q(w,-h*0.1));p.close()
        case 12:lines([q(0,-h),q(w,0),q(0,h),q(-w,0)])
        case 13,14:
            let r=CGRect(x:rect.minX,y:rect.minY,width:rect.width,height:h*1.6)
            p.append(type==13 ? UIBezierPath(ovalIn:r):UIBezierPath(roundedRect:r,byRoundingCorners:.allCorners,cornerRadii:CGSize(width:w*0.1,height:h*0.1)))
            lines([q(-w*0.3,h*(type==13 ? 0.5:0.6)),q(-w*0.6,h),q(0,h*0.6)])
        case 15:lines([q(-w,-h*0.4),q(w*0.8,-h*0.4),q(w*0.8,-h),q(w,0),q(w*0.8,h),q(w*0.8,h*0.4),q(-w,h*0.4)])
        case 16:lines([q(-w*0.4,h),q(-w*0.4,-h*0.8),q(-w,-h*0.8),q(0,-h),q(w,-h*0.8),q(w*0.4,-h*0.8),q(w*0.4,h)])
        case 17:p.append(UIBezierPath(rect:CGRect(x:rect.midX-w*0.3,y:rect.minY,width:w*0.6,height:rect.height)));p.append(UIBezierPath(rect:CGRect(x:rect.minX,y:rect.midY-h*0.3,width:rect.width,height:h*0.6)))
        case 18:p.append(UIBezierPath(ovalIn:rect));p.append(UIBezierPath(ovalIn:CGRect(x:rect.midX-w*0.3,y:rect.midY-h*0.8,width:w*1.6,height:h*1.6)));p.usesEvenOddFillRule=true
        default:p.move(to:q(0,-h));p.addCurve(to:q(0,h),controlPoint1:q(w,-h*0.2),controlPoint2:q(w,h));p.addCurve(to:q(0,-h),controlPoint1:q(-w,h),controlPoint2:q(-w,-h*0.2));p.close()
        };return p
    }
    static func polygon(_ count:Int,rect:CGRect,star:Bool)->UIBezierPath {
        let p=UIBezierPath();let n=star ? count*2:count
        for i in 0..<n{let angle=Double(i)/Double(n)*2*Double.pi-Double.pi/2;let radius=star&&i%2==1 ? 0.25:0.5;let q=CGPoint(x:rect.midX+cos(angle)*Double(rect.width)*radius,y:rect.midY+sin(angle)*Double(rect.height)*radius);if i==0{p.move(to:q)}else{p.addLine(to:q)}};p.close();return p
    }
}
