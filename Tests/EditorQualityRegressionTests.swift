import XCTest
import SwiftUI
import UniformTypeIdentifiers
import CoreText
@testable import CookiesEditor

final class EditorQualityRegressionTests:XCTestCase {
    private func pixels(_ image:CGImage)->[UInt8] {
        var bytes=[UInt8](repeating:0,count:image.width*image.height*4)
        bytes.withUnsafeMutableBytes { b in
            let c=CGContext(data:b.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
        };return bytes
    }
    private func textImage(_ layer:EditorLayer,scale:CGFloat)->UIImage {
        let f=UIGraphicsImageRendererFormat();f.scale=scale
        return UIGraphicsImageRenderer(size:CGSize(width:360,height:180),format:f).image { r in
            r.cgContext.translateBy(x:30,y:30)
            LayerRenderer.drawText(layer,rect:LayerRenderer.bounds(layer),context:r.cgContext,directory:FileManager.default.temporaryDirectory)
        }
    }
    func testWideWhiteOutlinePreservesGradientGlyphInterior()throws {
        var text=EditorLayer(kind:.text);text.textContent="كوكيز OO";text.style.fontSize=64;text.style.boxWidth=300;text.style.textGradient=["AA0033","3300AA"];text.style.strokeColor="FFFFFF"
        let bare=try XCTUnwrap(textImage(text,scale:2).cgImage),original=pixels(bare)
        text.style.strokeWidth=12
        let outlined=pixels(try XCTUnwrap(textImage(text,scale:2).cgImage))
        var interior=0,changed=0,outer=0
        for i in stride(from:0,to:original.count,by:4) {
            if original[i+3]==255 { interior+=1;if (0..<3).contains(where:{abs(Int(original[i+$0])-Int(outlined[i+$0]))>3}){changed+=1} }
            if original[i+3]==0 && outlined[i+3]>200 { outer+=1 }
        }
        XCTAssertGreaterThan(interior,1000);XCTAssertLessThan(changed,max(20,interior/100));XCTAssertGreaterThan(outer,1000)
    }
    func testEffectsRasterResolutionTracksContextScale()throws {
        TextRaster.cache.removeAllObjects()
        var text=EditorLayer(kind:.text);text.textContent="حروف OO";text.style.textGradient=["FF0000","0000FF"]
        let low=textImage(text,scale:1),high=textImage(text,scale:4)
        XCTAssertEqual(high.cgImage!.width,low.cgImage!.width*4)
        // A high resolution draw creates its own raster rather than stretching
        // the cached one-point-per-pixel gradient texture.
        XCTAssertEqual(high.scale,4)
        let f=UIGraphicsImageRendererFormat();f.scale=4
        let enlarged=UIGraphicsImageRenderer(size:low.size,format:f).image{_ in low.draw(in:CGRect(origin:.zero,size:low.size))}
        let a=pixels(high.cgImage!),b=pixels(enlarged.cgImage!)
        let changed=a.indices.filter{abs(Int(a[$0])-Int(b[$0]))>20}.count
        XCTAssertGreaterThan(changed,500,"Zoom redraws edges from shaped glyphs rather than enlarging a low-resolution effect bitmap")
    }
    @MainActor func testFilesPickerUsesImportCopyModeAndDeliversAllURLsAfterDismissal()async throws {
        var shown=true,delivered:[URL]=[]
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let files=["sample.ttf","chapter.txt"].map{root.appendingPathComponent($0)}
        for url in files{try Data("local provider copy".utf8).write(to:url)}
        let result=expectation(description:"Files callback")
        let view=DocumentFilePicker(types:[.data],multiple:true,presented:Binding(get:{shown},set:{shown=$0})) { selection in
            XCTAssertFalse(shown);delivered=(try? selection.get()) ?? [];result.fulfill()
        }
        let coordinator=DocumentFilePicker.Coordinator(view),controller=UIDocumentPickerViewController(forOpeningContentTypes:[.data],asCopy:true)
        coordinator.documentPicker(controller,didPickDocumentsAt:files)
        XCTAssertFalse(shown);await fulfillment(of:[result],timeout:2);XCTAssertEqual(delivered,files)
        for url in delivered{XCTAssertEqual(try Data(contentsOf:url),Data("local provider copy".utf8))}
    }
    @MainActor func testSelectedFontCopyIsInstalledAndReadableAfterPickerCloses()async throws {
        let original=try XCTUnwrap(Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts")?.first)
        let file=FileManager.default.temporaryDirectory.appendingPathComponent("picker-font-\(UUID()).ttf")
        let installed=Fonts.userDirectory.appendingPathComponent(file.lastPathComponent)
        defer{try? FileManager.default.removeItem(at:file);CTFontManagerUnregisterFontsForURL(installed as CFURL,.process,nil);try? FileManager.default.removeItem(at:installed);Fonts.register()}
        try FileManager.default.copyItem(at:original,to:file)
        var shown=true
        let done=expectation(description:"Real font import from selected sandbox copy")
        let view=DocumentFilePicker(types:[.data],multiple:false,presented:Binding(get:{shown},set:{shown=$0})) { result in
            XCTAssertFalse(shown)
            do { let url=try XCTUnwrap(result.get().first);_ = try FontPackage.importArchive(url) }
            catch{XCTFail(error.localizedDescription)}
            done.fulfill()
        }
        let coordinator=DocumentFilePicker.Coordinator(view),controller=UIDocumentPickerViewController(forOpeningContentTypes:[.data],asCopy:true)
        coordinator.documentPicker(controller,didPickDocumentsAt:[file]);await fulfillment(of:[done],timeout:5)
        XCTAssertEqual(try Data(contentsOf:installed),try Data(contentsOf:original));XCTAssertTrue(Fonts.userFiles.contains(installed))
    }
    @MainActor func testEraserRingFollowsTouchAndActualDiameter()throws {
        let viewport=CanvasViewport(frame:CGRect(x:0,y:0,width:320,height:400))
        viewport.showEraser(at:CGPoint(x:90,y:120),diameter:48)
        let ring=try XCTUnwrap(viewport.layer.sublayers?.compactMap{$0 as? CAShapeLayer}.first{$0.path != nil})
        XCTAssertEqual(ring.path!.boundingBox,CGRect(x:66,y:96,width:48,height:48));XCTAssertEqual(ring.fillColor,UIColor.clear.cgColor)
        viewport.showEraser(at:CGPoint(x:140,y:180),diameter:80);XCTAssertEqual(ring.path!.boundingBox.width,80)
        viewport.showEraser(at:nil,diameter:80);XCTAssertNil(ring.path)
    }
    func testLongSpeechTailDoesNotPullTypesettingOutOfBubbleBody()throws {
        let outline=[Point(x:0,y:0),Point(x:200,y:0),Point(x:200,y:140),Point(x:110,y:140),Point(x:105,y:230),Point(x:100,y:140),Point(x:0,y:140)]
        let target=SniperTarget(bounds:Box(x:20,y:23,width:160,height:184),outline:outline,point:Point(x:80,y:70))
        var text=EditorLayer(kind:.text);text.textContent="عندما نستقر في هذا المكان سوف نتابع الرحلة إلى الجبال البعيدة ونحمي أصدقاءنا"
        let result=try ContourTypesetter.fit(text,to:target)
        XCTAssertLessThan(result.frame.y+result.frame.height/2,95)
        XCTAssertEqual(result.textContent.split(whereSeparator:{$0.isWhitespace}),text.textContent.split(whereSeparator:{$0.isWhitespace}))
    }
    func testContourFitReservesSpaceForAdditionalOutlineAndShadow()throws {
        let outline=(0..<80).map{i -> Point in let a=Double(i)*Double.pi*2/80;return Point(x:200+170*cos(a),y:180+130*sin(a))}
        let target=SniperTarget(bounds:Box(x:64,y:76,width:272,height:208),outline:outline,point:Point(x:200,y:180))
        var text=EditorLayer(kind:.text);text.textContent="سوف نتابع الرحلة إلى الجبال البعيدة ونحمي أصدقاءنا في هذا المكان";text.style.extraStrokes=[ExtraOutline(width:14,color:"FFFFFF")];text.style.shadowRadius=2;text.style.shadowDx=4;text.style.shadowAlpha=255
        let fitted=try ContourTypesetter.fit(text,to:target),lines=fitted.textContent.components(separatedBy:"\n"),height=Double(LayerRenderer.bounds(fitted).height),step=height/Double(lines.count)
        let interior=BubbleInterior(target:target)
        for (row,line) in lines.enumerated() {
            let width=Double((line as NSString).size(withAttributes:[.font:Fonts.font(fitted.style),.kern:fitted.style.letterSpacing]).width)
            XCTAssertLessThanOrEqual(width,interior.width(at:fitted.frame.y+Double(row)*step,height:step,margin:22)+0.01)
        }
        XCTAssertEqual(fitted.textContent.split(whereSeparator:{$0.isWhitespace}),text.textContent.split(whereSeparator:{$0.isWhitespace}))
        XCTAssertEqual(fitted.style.extraStrokes,text.style.extraStrokes)
    }
    func testPartialOCRDoesNotLeaveSecondLineInFourWhiteBubbles()throws {
        for offset in [0,4,8,12] {
            let f=UIGraphicsImageRendererFormat();f.scale=1;f.opaque=true
            let image=UIGraphicsImageRenderer(size:CGSize(width:240,height:220),format:f).image { c in
                UIColor.white.setFill();c.fill(CGRect(x:0,y:0,width:240,height:220));UIColor.black.setStroke()
                let frame=UIBezierPath(ovalIn:CGRect(x:10,y:10,width:220,height:200));frame.lineWidth=3;frame.stroke()
                for y in [85,125] {for x in [65,90,115,140] { UIColor.gray.setFill();c.fill(CGRect(x:x-2,y:y-2,width:16,height:25));UIColor.black.setFill();c.fill(CGRect(x:x,y:y,width:12,height:21)) }}
                // Detached dots on the undetected line must also disappear.
                UIColor.black.setFill();c.fill(CGRect(x:92,y:118,width:4,height:3))
                // Separate decoration: must not be mistaken for a missed line.
                UIColor.black.setFill();c.fill(CGRect(x:180,y:45,width:6,height:6))
            }
            let outline=(0..<80).map{i -> NSValue in let a=Double(i)*Double.pi*2/80;return NSValue(cgPoint:CGPoint(x:120+110*cos(a),y:110+100*sin(a)))}
            let result=try XCTUnwrap(CookiesWhitenBubble(image,outline,[NSValue(cgRect:CGRect(x:63+offset,y:83,width:94-offset,height:25))]))
            let patch=pixels(try XCTUnwrap((result["patch"] as? UIImage)?.cgImage))
            for y in [85,125] {for x in [65,90,115,140] {let i=(y*240+x)*4;XCTAssertEqual(patch[i+3],255);XCTAssertGreaterThan(patch[i],245)}}
            XCTAssertEqual(patch[(119*240+94)*4+3],255);XCTAssertEqual(patch[(48*240+183)*4+3],0);XCTAssertEqual(patch[(110*240+10)*4+3],0)
        }
    }
}
