import XCTest
import UIKit
@testable import CookiesEditor

final class SniperWorkflowTests:XCTestCase {
    private func ellipse()->SniperTarget{
        let outline=(0..<80).map{i -> Point in let angle=Double(i)*2*Double.pi/80;return Point(x:200+160*cos(angle),y:180+120*sin(angle))}
        return SniperTarget(bounds:Box(x:72,y:84,width:256,height:192),outline:outline,point:Point(x:200,y:180))
    }
    func testEveryFormattedArabicLineFitsItsActualContourBand()throws{
        let target=ellipse(),interior=BubbleInterior(target:target)
        var layer=EditorLayer(kind:.text);layer.textContent="عندما نستقر في هذا المكان سوف نتابع الرحلة إلى الجبال البعيدة ونحمي أصدقاءنا";layer.style.color="000000";layer.style.strokeWidth=0
        let result=try ContourTypesetter.fit(layer,to:target),lines=result.textContent.components(separatedBy:"\n"),height=Double(LayerRenderer.bounds(result).height),step=height/Double(lines.count)
        XCTAssertEqual(result.textContent.split(whereSeparator:{$0.isWhitespace}),layer.textContent.split(whereSeparator:{$0.isWhitespace}))
        XCTAssertEqual(result.style.color,layer.style.color);XCTAssertEqual(result.style.fontPath,layer.style.fontPath)
        for (index,line) in lines.enumerated(){let width=Double((line as NSString).size(withAttributes:[.font:Fonts.font(result.style),.kern:result.style.letterSpacing]).width);XCTAssertLessThanOrEqual(width,interior.width(at:result.frame.y+Double(index)*step,height:step,margin:3)+0.01)}
        XCTAssertGreaterThan(result.style.fontSize,8)
    }
    func testConcaveOutlineCannotPutTextAcrossGapOrBorder(){
        let points=[Point(x:0,y:0),Point(x:100,y:0),Point(x:100,y:40),Point(x:60,y:40),Point(x:60,y:60),Point(x:100,y:60),Point(x:100,y:100),Point(x:0,y:100)]
        let target=SniperTarget(bounds:Box(x:10,y:10,width:80,height:80),outline:points,point:Point(x:50,y:50)),interior=BubbleInterior(target:target)
        XCTAssertEqual(interior.width(at:20,height:60,margin:3),14,accuracy:0.1)
        XCTAssertEqual(interior.width(at:-10,height:20,margin:3),0)
    }
    func testTextOnlyWhiteningLeavesBorderAndDecorationTransparent()throws{
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:200,height:160),format:format).image{context in
            UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:200,height:160));UIColor.black.setStroke();let edge=UIBezierPath(rect:CGRect(x:10,y:10,width:180,height:140));edge.lineWidth=4;edge.stroke()
            UIColor.black.setFill();for x in [60,80,100,120]{context.fill(CGRect(x:x,y:70,width:8,height:16))};context.fill(CGRect(x:160,y:30,width:8,height:8))
        }
        let points=[CGPoint(x:10,y:10),CGPoint(x:190,y:10),CGPoint(x:190,y:150),CGPoint(x:10,y:150)].map{NSValue(cgPoint:$0)}
        let result=try XCTUnwrap(CookiesWhitenBubble(image,points,[NSValue(cgRect:CGRect(x:58,y:68,width:72,height:20))]) as? [String:Any]),patch=try XCTUnwrap((result["patch"] as? UIImage)?.cgImage)
        let bytes=try pixels(patch)
        func alpha(_ x:Int,_ y:Int)->UInt8{bytes[(y*200+x)*4+3]}
        XCTAssertEqual(alpha(64,76),255);XCTAssertEqual(alpha(10,80),0);XCTAssertEqual(alpha(164,34),0);XCTAssertEqual(alpha(40,40),0)
        XCTAssertTrue(result["flat"] as? Bool ?? false);XCTAssertTrue(result["localized"] as? Bool ?? false)
    }
    func testDecoratedColoredBubbleWithoutLocalizedTextIsRejected(){
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:120,height:120),format:format).image{c in UIColor.red.setFill();c.fill(CGRect(x:0,y:0,width:120,height:120));UIColor.blue.setFill();for x in stride(from:0,to:120,by:10){c.fill(CGRect(x:x,y:0,width:5,height:120))}}
        let polygon=[CGPoint(x:5,y:5),CGPoint(x:115,y:5),CGPoint(x:115,y:115),CGPoint(x:5,y:115)].map{NSValue(cgPoint:$0)}
        XCTAssertNil(CookiesWhitenBubble(image,polygon,[]))
    }
    func testGradientTextIsInpaintedWithoutFillingWholeBubble()throws{
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:220,height:180),format:format).image{c in
            for y in 0..<180{UIColor(red:CGFloat(0.3+Double(y)/450),green:0.6,blue:0.9,alpha:1).setFill();c.fill(CGRect(x:0,y:y,width:220,height:1))}
            UIColor.black.setFill();for x in [60,85,110,135]{c.fill(CGRect(x:x,y:75,width:10,height:22))}
        }
        let polygon=[CGPoint(x:10,y:10),CGPoint(x:210,y:10),CGPoint(x:210,y:170),CGPoint(x:10,y:170)].map{NSValue(cgPoint:$0)}
        let result=try XCTUnwrap(CookiesWhitenBubble(image,polygon,[NSValue(cgRect:CGRect(x:58,y:73,width:90,height:26))]) as? [String:Any])
        XCTAssertFalse(result["flat"] as? Bool ?? true);XCTAssertTrue(result["reviewRequired"] as? Bool ?? false)
        let patch=try XCTUnwrap((result["patch"] as? UIImage)?.cgImage),bytes=try pixels(patch)
        XCTAssertGreaterThan((result["removedPixels"] as? NSNumber)?.intValue ?? 0,20)
        XCTAssertEqual(bytes[(40*220+40)*4+3],0);XCTAssertEqual(bytes[(10*220+100)*4+3],0)
    }
    @MainActor func testMultiBubblePreviewDoesNotCommitUntilAcceptedAndUndoRestoresAll()throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let page=try PageOperations.blank(title:"preview",width:100,height:100,color:"FFFFFF",transparent:false,root:root),model=EditorModel(page:page,library:LibraryStore(root:root))
        var a=EditorLayer(kind:.image),b=EditorLayer(kind:.image);a.imagePath="a.png";b.imagePath="b.png"
        let candidate=CleaningCandidate(title:"two",layer:a,additionalLayers:[b],underlays:true,baseline:page)
        model.cleanCandidates=[candidate];model.cleanPreviewID=candidate.id
        XCTAssertTrue(model.page.layers.isEmpty);XCTAssertEqual(model.canvasPage.layers.count,2)
        model.acceptCleaning();XCTAssertEqual(model.page.layers.count,2);XCTAssertEqual(model.undoStack.count,1);model.undo();XCTAssertTrue(model.page.layers.isEmpty);model.redo();XCTAssertEqual(model.page.layers.count,2)
    }
    @MainActor func testWhiteningReadsOriginalPixelsAndUndoExportsOriginalFile()async throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:240,height:200),format:format).image{c in UIColor.white.setFill();c.fill(CGRect(x:0,y:0,width:240,height:200));UIColor.black.setStroke();let path=UIBezierPath(rect:CGRect(x:10,y:10,width:220,height:180));path.lineWidth=3;path.stroke();UIColor.black.setFill();for x in [60,90,120,150]{c.fill(CGRect(x:x,y:85,width:12,height:24))}}
        let url=root.appendingPathComponent("input.png");try XCTUnwrap(image.pngData()).write(to:url)
        let page=try ImagePipeline.importImage(url,root:root),library=LibraryStore(root:root),model=EditorModel(page:page,library:library),original=try Data(contentsOf:library.directory(page.id).appendingPathComponent(page.source))
        model.sniperTargets=[SniperTarget(bounds:Box(x:32,y:28,width:176,height:144),outline:[Point(x:10,y:10),Point(x:230,y:10),Point(x:230,y:190),Point(x:10,y:190)],point:Point(x:120,y:120))]
        await model.whitenSniperTargets()
        XCTAssertNil(model.error);XCTAssertEqual(model.cleanCandidates.count,1);XCTAssertTrue(model.page.layers.isEmpty)
        model.acceptCleaning();XCTAssertEqual(model.page.layers.count,1);XCTAssertTrue(model.sniperTargets.isEmpty)
        XCTAssertEqual(try Data(contentsOf:library.directory(page.id).appendingPathComponent(page.source)),original)
        model.undo();let exported=try ImagePipeline.exportPNG(model.page,directory:model.directory);defer{try? FileManager.default.removeItem(at:exported)}
        XCTAssertEqual(try Data(contentsOf:exported),original)
    }
    private func pixels(_ image:CGImage)throws->[UInt8]{
        var bytes=[UInt8](repeating:0,count:image.width*image.height*4)
        try bytes.withUnsafeMutableBytes{pointer in let context=try XCTUnwrap(CGContext(data:pointer.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue));context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))}
        return bytes
    }
}
