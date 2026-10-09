import UIKit
import CoreText

enum Fonts {
    static var files:[URL] {Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts") ?? []}
    static func register(){for url in files+(Bundle.main.urls(forResourcesWithExtension:"otf",subdirectory:"Fonts") ?? []){CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil)}}
    static func font(_ style:TextStyle)->UIFont {
        let path=Bundle.main.url(forResource:style.fontPath,deletingExtension: false)
        let url=path ?? Bundle.main.url(forResource:style.fontPath,withExtension:nil,subdirectory:"Fonts")
        var f=UIFont.systemFont(ofSize:CGFloat(style.fontSize))
        if let url,let provider=CGDataProvider(url:url as CFURL),let cg=CGFont(provider),let name=cg.postScriptName,let custom=UIFont(name:name as String,size:CGFloat(style.fontSize)){f=custom}
        var traits=UIFontDescriptor.SymbolicTraits();if style.isBold{traits.insert(.traitBold)};if style.isItalic{traits.insert(.traitItalic)}
        if let d=f.fontDescriptor.withSymbolicTraits(traits){f=UIFont(descriptor:d,size:CGFloat(style.fontSize))};return f
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
            case .image:if let image=UIImage(contentsOfFile:directory.appendingPathComponent(l.imagePath).path){image.draw(in:b)}
            case .shape:
                let path=shapePath(l.shape,rect:b);UIColor(hex:l.style.color).setFill();path.fill();if l.style.strokeWidth>0{UIColor(hex:l.style.strokeColor).setStroke();path.lineWidth=CGFloat(l.style.strokeWidth);path.stroke()}
            case .drawing:
                ctx.beginTransparencyLayer(auxiliaryInfo:nil)
                for s in l.strokes where !s.points.isEmpty {ctx.saveGState();let path=UIBezierPath();path.move(to:s.points[0].cg);for p in s.points.dropFirst(){path.addLine(to:p.cg)};path.lineCapStyle = .round;path.lineJoinStyle = .round;path.lineWidth=CGFloat(s.width);UIColor(hex:s.color).setStroke();if s.erase{ctx.setBlendMode(.clear)};if s.brush=="neon"{ctx.setShadow(offset:.zero,blur:CGFloat(s.width),color:UIColor(hex:s.color).cgColor)};if s.brush=="water"{ctx.setAlpha(0.25)};path.stroke();ctx.restoreGState()}
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
        switch type%20 {
        case 0:return UIBezierPath(roundedRect:rect,cornerRadius:min(rect.width,rect.height)*0.16)
        case 1:return UIBezierPath(ovalIn:rect)
        case 2:return UIBezierPath(rect:rect)
        case 3,4,5,6,7,8,9,10:
            let points=[3,4,5,6,8,10,12,20][max(0,min(7,type-3))];return polygon(points,rect:rect,star:type>7)
        case 11,12,13:
            let p=UIBezierPath(roundedRect:rect.insetBy(dx:0,dy:rect.height*0.1),cornerRadius:rect.height*0.25);p.move(to:CGPoint(x:rect.width*0.5,y:rect.height*0.85));p.addLine(to:CGPoint(x:rect.width*0.45,y:rect.height));p.addLine(to:CGPoint(x:rect.width*0.7,y:rect.height*0.85));p.close();return p
        case 14,15:
            let p=UIBezierPath();for v in [CGPoint(x:0,y:rect.height*0.3),CGPoint(x:rect.width*0.65,y:rect.height*0.3),CGPoint(x:rect.width*0.65,y:0),CGPoint(x:rect.width,y:rect.height/2),CGPoint(x:rect.width*0.65,y:rect.height),CGPoint(x:rect.width*0.65,y:rect.height*0.7),CGPoint(x:0,y:rect.height*0.7)]{if p.isEmpty{p.move(to:v)}else{p.addLine(to:v)}};p.close();return p
        default:return polygon(type==16 ? 4:16,rect:rect,star:type==19)
        }
    }
    static func polygon(_ count:Int,rect:CGRect,star:Bool)->UIBezierPath {
        let p=UIBezierPath();let n=star ? count*2:count
        for i in 0..<n{let angle=Double(i)/Double(n)*2*Double.pi-Double.pi/2;let radius=star&&i%2==1 ? 0.25:0.5;let q=CGPoint(x:rect.midX+cos(angle)*Double(rect.width)*radius,y:rect.midY+sin(angle)*Double(rect.height)*radius);if i==0{p.move(to:q)}else{p.addLine(to:q)}};p.close();return p
    }
}
