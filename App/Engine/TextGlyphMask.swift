import UIKit

/// Shape only when typography changes. Colors, gradients, filters and perspective
/// reuse this unpadded alpha mask; export and screen resolution remain distinct.
enum TextGlyphMask {
    static let cache=NSCache<TextRenderKey,UIImage>()
    private static let lock=NSLock()
    private static var builds=0
    static var buildCount:Int{lock.lock();defer{lock.unlock()};return builds}
    static func padding(_ style:TextStyle)->CGFloat{min(128,max(8,ceil(CGFloat(style.fontSize)/2+CGFloat(abs(style.tashkeelOffset ?? 0))))) }
    static func image(_ layer:EditorLayer,rect:CGRect,resolution:CGFloat,directory:URL)->UIImage {
        var mask=layer
        let s=layer.style
        var typography=TextStyle.plainText(fontSize:s.fontSize,boxWidth:s.boxWidth)
        typography.fontPath=s.fontPath;typography.isBold=s.isBold;typography.isItalic=s.isItalic
        typography.isUnderline=s.isUnderline;typography.isStrikeThrough=s.isStrikeThrough
        typography.alignment=s.alignment;typography.letterSpacing=s.letterSpacing
        typography.lineSpacing=s.lineSpacing;typography.lineHeightMultiple=s.lineHeightMultiple
        typography.tashkeelOffset=s.tashkeelOffset
        typography.spans=s.spans.map{var run=$0;run.color=nil;return run}
        mask.style=typography;mask.textMask=nil
        let key=TextRenderKey(mask,directory:directory,resolution:resolution,size:rect.size)
        if let value=cache.object(forKey:key){return value}
        let format=UIGraphicsImageRendererFormat();format.scale=resolution
        format.opaque=false;format.preferredRange = .standard
        let pad=padding(layer.style),size=CGSize(width:rect.width+pad*2,height:rect.height+pad*2)
        let image=UIGraphicsImageRenderer(size:size,format:format).image{_ in
            LayerRenderer.attributed(mask,color:.white).draw(with:CGRect(x:pad,y:pad,width:rect.width,height:rect.height),options:[.usesLineFragmentOrigin,.usesFontLeading],context:nil)
        }
        lock.lock();builds+=1;lock.unlock()
        cache.totalCostLimit=RenderBudget.textCacheBytes/2
        cache.setObject(image,forKey:key,cost:Int(ceil(size.width*resolution)*ceil(size.height*resolution))*4)
        return image
    }
}
