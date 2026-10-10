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
    func testRealManhwaArabicShadowIsRemovedWithoutChangingBubbleBorder()throws{
        let image=try fixture("manhwa-shadow"),polygon=shadowOutline().map{NSValue(cgPoint:$0)}
        // This reference contains one connected Arabic word with an 18-pixel
        // gray shadow. Localization and fallback must both remove the fringe.
        for rectangles in [[],[NSValue(cgRect:CGRect(x:195,y:427,width:680,height:200))]] {
            let result=try XCTUnwrap(CookiesWhitenBubble(image,polygon,rectangles)),patch=try XCTUnwrap((result["patch"] as? UIImage)?.cgImage)
            let input=try pixels(try XCTUnwrap(image.cgImage)),output=try pixels(patch),width=patch.width
            var remnants=0,originalInk=0
            for y in 427..<627{for x in 195..<875{let i=(y*width+x)*4
                if min(input[i],input[i+1],input[i+2])<245{originalInk+=1}
                let r=output[i+3]==255 ? output[i]:input[i],g=output[i+3]==255 ? output[i+1]:input[i+1],b=output[i+3]==255 ? output[i+2]:input[i+2]
                if min(r,g,b)<245{remnants+=1}
            }}
            XCTAssertGreaterThan(originalInk,40_000);XCTAssertEqual(remnants,0,"Outlined/shadowed Arabic must not retain gray letter pixels")
            XCTAssertEqual(output[(325*width+108)*4+3],0,"Original decorative frame is protected")
            XCTAssertEqual(output[(810*width+810)*4+3],0,"Notebook artwork is protected")
            let attachment=XCTAttachment(image:try composite(image,patch));attachment.name="whitening-real-arabic-shadow-after";attachment.lifetime = .keepAlways;add(attachment)
        }
    }
    func testRealScreamBubblePreservesHandlesAndOutsideArt()throws{
        let image=try fixture("manhwa-scream")
        let outline=[CGPoint(x:105,y:100),CGPoint(x:735,y:100),CGPoint(x:735,y:450),CGPoint(x:105,y:450)].map{NSValue(cgPoint:$0)}
        let result=try XCTUnwrap(CookiesWhitenBubble(image,outline,[NSValue(cgRect:CGRect(x:174,y:280,width:500,height:145))])),patch=try XCTUnwrap((result["patch"] as? UIImage)?.cgImage),output=try pixels(patch),input=try pixels(try XCTUnwrap(image.cgImage))
        var residual=0
        for y in 282..<423{for x in 179..<670{let i=(y*patch.width+x)*4;let value=output[i+3]==255 ? output[i]:input[i];if value<230{residual+=1}}}
        XCTAssertEqual(residual,0);XCTAssertEqual(output[(540*patch.width+564)*4+3],0)
    }
    func testRealColoredOutlinedTextIsRemovedWithExplicitReview()throws{
        let original=try fixture("colored-dialogue"),crop=try XCTUnwrap(original.cgImage?.cropping(to:CGRect(x:1980,y:825,width:310,height:610))),image=UIImage(cgImage:crop)
        let points=[CGPoint(x:182,y:58),CGPoint(x:264,y:146),CGPoint(x:295,y:273),CGPoint(x:286,y:427),CGPoint(x:245,y:513),CGPoint(x:175,y:573),CGPoint(x:126,y:578),CGPoint(x:116,y:550),CGPoint(x:90,y:517),CGPoint(x:69,y:458),CGPoint(x:45,y:436),CGPoint(x:38,y:392),CGPoint(x:40,y:256),CGPoint(x:61,y:165),CGPoint(x:98,y:103)].map{NSValue(cgPoint:$0)}
        let result=try XCTUnwrap(CookiesWhitenBubble(image,points,[NSValue(cgRect:CGRect(x:108,y:130,width:130,height:390))])),patch=try XCTUnwrap((result["patch"] as? UIImage)?.cgImage),output=try pixels(patch),input=try pixels(crop)
        XCTAssertFalse(result["flat"] as? Bool ?? true);XCTAssertTrue(result["reviewRequired"] as? Bool ?? false)
        var dark=0,whiteOutline=0
        for y in 150..<510{for x in 130..<230{let i=(y*310+x)*4;let r=output[i+3]==255 ? output[i]:input[i],g=output[i+3]==255 ? output[i+1]:input[i+1],b=output[i+3]==255 ? output[i+2]:input[i+2];if max(r,g,b)<160{dark+=1};if min(r,g,b)>245{whiteOutline+=1}}}
        XCTAssertEqual(dark,0);XCTAssertEqual(whiteOutline,0);XCTAssertEqual(output[(300*310+296)*4+3],0)
        let attachment=XCTAttachment(image:try composite(image,patch));attachment.name="whitening-real-yellow-outlined-after";attachment.lifetime = .keepAlways;add(attachment)
    }
    func testRealMangaVerticalTextLeavesContourUnchanged()throws{
        let original=try fixture("manga-page"),crop=try XCTUnwrap(original.cgImage?.cropping(to:CGRect(x:65,y:70,width:145,height:195))),image=UIImage(cgImage:crop)
        let points=(0..<64).map{i -> NSValue in let angle=Double(i)*2*Double.pi/64;return NSValue(cgPoint:CGPoint(x:64+58*cos(angle),y:92+86*sin(angle)))}
        let result=try XCTUnwrap(CookiesWhitenBubble(image,points,[NSValue(cgRect:CGRect(x:36,y:47,width:63,height:115))])),patch=try XCTUnwrap((result["patch"] as? UIImage)?.cgImage),output=try pixels(patch),input=try pixels(crop)
        var before=0,after=0
        for y in 47..<163{for x in 36..<99{let i=(y*145+x)*4;if input[i]<220{before+=1};if (output[i+3]==255 ? output[i]:input[i])<220{after+=1}}}
        XCTAssertGreaterThan(before,300);XCTAssertEqual(after,0);XCTAssertEqual(output[(90*145+5)*4+3],0)
    }
    func testRGBAImageRejectsIncompatibleGrayProfileWithoutLosingPixels()throws{
        let bytes:[UInt8]=[0,0,0,255,255,255,255,255]
        let image=try XCTUnwrap(ImagePipeline.image(bytes,width:2,height:1,colorSpace:CGColorSpaceCreateDeviceGray()))
        XCTAssertEqual(image.colorSpace?.model,.rgb);XCTAssertNotNil(UIImage(cgImage:image).pngData())
    }
    @MainActor func testRealImportedManhwaWhiteningPipelineAndExport()async throws{
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),image=try fixture("manhwa-shadow"),url=root.appendingPathComponent("shadow.png");try XCTUnwrap(image.pngData()).write(to:url)
        let page=try ImagePipeline.importImage(url,root:root),model=EditorModel(page:page,library:library)
        let target=SniperTarget(bounds:Box(x:220,y:330,width:560,height:390),outline:shadowOutline().map{Point(x:$0.x,y:$0.y)},point:Point(x:500,y:400))
        // Exercise raw-tile decoding, Vision localization, patch persistence,
        // preview, commit and final PNG export rather than only native masks.
        model.sniperTargets=[target];await model.whitenSniperTargets();XCTAssertNil(model.error);XCTAssertEqual(model.cleanCandidates.count,1)
        model.acceptCleaning();XCTAssertEqual(model.page.layers.count,1)
        let output=try ImagePipeline.exportPNG(model.page,directory:model.directory);defer{try? FileManager.default.removeItem(at:output)}
        let exported=try XCTUnwrap(UIImage(contentsOfFile:output.path)?.cgImage),data=try pixels(exported)
        var remnants=0;for y in 427..<627{for x in 195..<875{let i=(y*exported.width+x)*4;if min(data[i],data[i+1],data[i+2])<245{remnants+=1}}}
        XCTAssertEqual(remnants,0);XCTAssertEqual(exported.width,page.width);XCTAssertEqual(exported.height,page.height)
    }
    private func fixture(_ name:String)throws->UIImage{
        let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:name,withExtension:"png",subdirectory:"WhiteningFixtures"))
        return try XCTUnwrap(UIImage(contentsOfFile:url.path))
    }
    private func shadowOutline()->[CGPoint]{[CGPoint(x:108,y:346),CGPoint(x:198,y:324),CGPoint(x:613,y:185),CGPoint(x:648,y:217),CGPoint(x:887,y:186),CGPoint(x:906,y:769),CGPoint(x:777,y:758),CGPoint(x:652,y:785),CGPoint(x:125,y:851)]}
    private func composite(_ image:UIImage,_ patch:CGImage)throws->UIImage{
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:image.size,format:format).image{_ in image.draw(at:.zero);UIImage(cgImage:patch).draw(at:.zero)}
    }
    private func pixels(_ image:CGImage)throws->[UInt8]{
        var bytes=[UInt8](repeating:0,count:image.width*image.height*4)
        try bytes.withUnsafeMutableBytes{pointer in let context=try XCTUnwrap(CGContext(data:pointer.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue));context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))}
        return bytes
    }
}
