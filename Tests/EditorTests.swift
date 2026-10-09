import XCTest
import UIKit
import ImageIO
import Combine
@testable import CookiesEditor

final class EditorTests:XCTestCase {
    func testAddExportMatchesNativeCanvas() throws {
        var native=[UInt8](repeating:0,count:4)
        let rendered=native.withUnsafeMutableBytes{bytes->Bool in
            guard let context=CGContext(data:bytes.baseAddress,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:ImagePipeline.space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false}
            context.setFillColor(red:0.8,green:0.4,blue:0.2,alpha:1);context.fill(CGRect(x:0,y:0,width:1,height:1))
            context.setBlendMode(Blend.add.cg);context.setFillColor(red:0.8,green:0.2,blue:0,alpha:0.5);context.fill(CGRect(x:0,y:0,width:1,height:1));return true
        }
        XCTAssertTrue(rendered)
        var base:[UInt8]=[204,102,51,255],overlay:[UInt8]=[102,26,0,128]
        LICompositeBlend(&base,&overlay,1,Int32(Blend.allCases.firstIndex(of:.add)!))
        for channel in 0..<4{XCTAssertEqual(Double(base[channel]),Double(native[channel]),accuracy:1,"PNG ADD must match the displayed native layer")}
    }
    func testLongPNGAndProjectRoundTrip() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let page=try ImagePipeline.fixture(root:root),directory=root.appendingPathComponent(page.id.uuidString);XCTAssertEqual(page.width,800);XCTAssertEqual(page.height,15000)
        let exported=try ImagePipeline.exportPNG(page,directory:directory)
        XCTAssertEqual(try Data(contentsOf:exported),try Data(contentsOf:directory.appendingPathComponent(page.source)),"Unedited source is preserved byte for byte")
        var edited=page;var l=EditorLayer(kind:.text,name:"حوار");l.textContent="نص عربي قرب نهاية الصورة";l.frame=Box(x:30,y:14600,width:700,height:100);l.style.boxWidth=700;l.style.fontSize=36;l.style.color="000000";edited.layers=[l]
        let output=try ImagePipeline.exportPNG(edited,directory:directory);var w:Int32=0,h:Int32=0,error=[CChar](repeating:0,count:512);let raw=root.appendingPathComponent("export.rgba")
        XCTAssertEqual(LIImportPNG(output.path,raw.path,&w,&h,&error,error.count),1);XCTAssertEqual(w,800);XCTAssertEqual(h,15000)
        let before=try ImagePipeline.tile(directory.appendingPathComponent(page.raw),width:800,height:15000,rect:CGRect(x:0,y:0,width:800,height:256))
        XCTAssertEqual(before,try ImagePipeline.tile(raw,width:800,height:15000,rect:CGRect(x:0,y:0,width:800,height:256)))
        XCTAssertNotEqual(try ImagePipeline.tile(directory.appendingPathComponent(page.raw),width:800,height:15000,rect:CGRect(x:0,y:14500,width:800,height:400)),try ImagePipeline.tile(raw,width:800,height:15000,rect:CGRect(x:0,y:14500,width:800,height:400)))
        let encoded=try JSONEncoder().encode(edited);XCTAssertEqual(try JSONDecoder().decode(EditorPage.self,from:encoded),edited)
        let i=CGImageSourceCreateWithURL(output as CFURL,nil)!;let properties=CGImageSourceCopyPropertiesAtIndex(i,0,nil)! as NSDictionary;XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int,800);XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int,15000)
    }
    func testOriginalFontsAndNativeCleaner() throws {
        XCTAssertEqual(Fonts.files.count+(Bundle.main.urls(forResourcesWithExtension:"otf",subdirectory:"Fonts") ?? []).count,47)
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let source=UIGraphicsImageRenderer(size:CGSize(width:400,height:400),format:format).image{ctx in UIColor.white.setFill();ctx.fill(CGRect(x:0,y:0,width:400,height:400));("COOKIES" as NSString).draw(at:CGPoint(x:70,y:70),withAttributes:[.font:UIFont.boldSystemFont(ofSize:40),.foregroundColor:UIColor.black])}
        let mask=UIGraphicsImageRenderer(size:CGSize(width:400,height:400),format:format).image{ctx in UIColor.black.setFill();ctx.fill(CGRect(x:0,y:0,width:400,height:400));UIColor.white.setFill();ctx.fill(CGRect(x:55,y:40,width:290,height:120))}
        let patch=try XCTUnwrap(CookiesInpaint(source,mask,3));XCTAssertEqual(patch.size,source.size)
        for (name,image) in [("cleaner-before",source),("cleaner-mask",mask),("cleaner-after",patch)]{let a=XCTAttachment(image:image);a.name=name;a.lifetime = .keepAlways;add(a)}
        let data=try XCTUnwrap(patch.cgImage?.dataProvider?.data) as Data;XCTAssertEqual(data[3],0,"Unmasked patch must stay transparent");XCTAssertEqual(data[(80*400+80)*4+3],255,"Mask must retain top-left orientation");XCTAssertEqual(data[(320*400+80)*4+3],0)
    }
    @MainActor func testUndoAndLayerTransforms() throws {
        let library=LibraryStore(root:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));let page=try ImagePipeline.fixture(root:library.root);library.add(page,parent:nil);let m=EditorModel(page:page,library:library)
        m.add(.text);m.change{$0.textContent="كوكيز"};let id=m.selected;m.checkpoint();m.change{$0.scaleX=2;$0.rotation=25};m.undo();XCTAssertEqual(m.page.layers.first?.scaleX,1);m.redo();XCTAssertEqual(m.page.layers.first?.scaleX,2);m.selected=id;m.duplicate();XCTAssertEqual(m.page.layers.count,2);m.delete();XCTAssertEqual(m.page.layers.count,1)
    }
    func testProjectArchiveJPEGAndPSD() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        var page=try ImagePipeline.fixture(root:root);let directory=root.appendingPathComponent(page.id.uuidString)
        var text=EditorLayer(kind:.text,name:"حوار عربي");text.textContent="أصل الصورة والطبقات";text.frame.y=14800;text.style.textGradient=["D4AF37","FFFFFF"];page.layers=[text]
        let archive=try ProjectArchive.export(page,directory:directory);let restored=try ProjectArchive.importFile(archive,root:root);XCTAssertEqual(restored.layers,page.layers);XCTAssertEqual(restored.width,800);XCTAssertEqual(restored.height,15000)
        let jpeg=try ImagePipeline.exportJPEG(page,directory:directory,quality:0.95),psd=try PSDWriter.export(page,directory:directory)
        for url in [jpeg,psd]{let source=try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL,nil));let props=try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source,0,nil)) as NSDictionary;XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int,800);XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int,15000);XCTAssertNotNil(CGImageSourceCreateImageAtIndex(source,0,nil))}
        let attachment=XCTAttachment(contentsOfFile:psd);attachment.name="layered-800x15000.psd";attachment.lifetime = .keepAlways;add(attachment)
    }
    @MainActor func testUnifiedApplicationIdentity() throws {
        XCTAssertTrue(NetworkPolicy.enabled)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String,"Cookies Editor")
        XCTAssertNotNil(ReferenceService().config)
    }
    func testPhotoProviderFileSurvivesCallbackAndKeepsOriginalBytes() throws {
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png")
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:800,height:15000),format:format).image{$0.cgContext.setFillColor(UIColor.white.cgColor);$0.fill(CGRect(x:0,y:0,width:800,height:15000))}
        let data=try XCTUnwrap(image.pngData());try data.write(to:temporary)
        let owned=try PhotoImport.ownFile(temporary);try FileManager.default.removeItem(at:temporary);defer{try? FileManager.default.removeItem(at:owned)}
        XCTAssertEqual(try Data(contentsOf:owned),data)
    }
    @MainActor func testCanvasKeepsPixelsWhenSelectionOrViewportChanges() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);var page=try ImagePipeline.fixture(root:root)
        page.layers=[EditorLayer(kind:.text)];let directory=library.directory(page.id)
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:15000))
        canvas.update(page:page,directory:directory,selected:nil,zoom:1)
        canvas.refreshVisible(CGRect(x:0,y:0,width:400,height:600))
        let deadline=Date().addingTimeInterval(15)
        while !canvas.visibleTilesReady && Date()<deadline{try await Task.sleep(nanoseconds:50_000_000)}
        XCTAssertTrue(canvas.visibleTilesReady,"Initial source tiles must be ready before measuring cache reuse")
        let reads=canvas.sourceReads,revision=canvas.revision
        canvas.update(page:page,directory:directory,selected:page.layers.first?.id,zoom:1)
        canvas.refreshVisible(CGRect(x:2,y:5,width:400,height:600))
        try await Task.sleep(nanoseconds:500_000_000)
        XCTAssertGreaterThan(reads,0);XCTAssertEqual(canvas.sourceReads,reads);XCTAssertEqual(canvas.revision,revision)
        page.layers[0].textContent="نص عربي";canvas.update(page:page,directory:directory,selected:page.layers[0].id,zoom:1)
        try await Task.sleep(nanoseconds:1_000_000_000)
        XCTAssertEqual(canvas.sourceReads,reads,"Editing reuses immutable source tiles")
        let paragraph=LayerRenderer.attributed(page.layers[0]).attribute(.paragraphStyle,at:0,effectiveRange:nil) as? NSParagraphStyle
        XCTAssertEqual(paragraph?.baseWritingDirection,.rightToLeft)
    }
    @MainActor func testSmallCanvasIsCenteredWhileZoomedOut() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let model=EditorModel(page:EditorPage(title:"صورة متوسطة",width:800,height:600),library:LibraryStore(root:root))
        let coordinator=CanvasHost.Coordinator(model),scroll=UIScrollView(frame:CGRect(x:0,y:0,width:375,height:500)),canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:600))
        coordinator.canvas=canvas;coordinator.scroll=scroll;scroll.addSubview(canvas);scroll.contentSize=canvas.bounds.size;scroll.delegate=coordinator;scroll.minimumZoomScale=0.01;scroll.maximumZoomScale=128;scroll.setZoomScale(0.3,animated:false);coordinator.updateCenter()
        // UIScrollView rounds offsets to physical display pixels. Measure the
        // converted document center within one display pixel at this zoom.
        let pixelInDocument=1/(max(1,scroll.traitCollection.displayScale)*scroll.zoomScale)
        XCTAssertEqual(scroll.contentInset.left,67.5,accuracy:0.1);XCTAssertEqual(scroll.contentInset.top,160,accuracy:0.1);XCTAssertEqual(model.visibleCenter.x,400,accuracy:pixelInDocument);XCTAssertEqual(model.visibleCenter.y,300,accuracy:pixelInDocument)
        let savedCenter=model.visibleCenter,savedZoom=model.zoom;coordinator.readOnly=true;scroll.setZoomScale(2,animated:false);coordinator.updateCenter();XCTAssertEqual(model.visibleCenter,savedCenter,"Reading has its own viewport");XCTAssertEqual(model.zoom,savedZoom,"Reading must not overwrite editor zoom")
    }
    @MainActor func testGalleryRefreshesAfterEditedThumbnailIsSaved() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root),page=try ImagePipeline.fixture(root:root);library.add(page,parent:nil)
        let thumbnail=library.directory(page.id).appendingPathComponent("thumbnail.png"),original=try Data(contentsOf:thumbnail),model=EditorModel(page:page,library:library),refreshed=expectation(description:"Gallery observes the completed preview")
        let subscription=library.objectWillChange.sink{refreshed.fulfill()};defer{subscription.cancel()}
        model.add(.text);model.change{$0.textContent="كوكيز"};await fulfillment(of:[refreshed],timeout:10);XCTAssertNotEqual(try Data(contentsOf:thumbnail),original)
    }
    @MainActor func testComplexBlendEraserShowsActualCompositeBeforeFingerRelease()async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        var page=try PageOperations.blank(title:"محو حي",width:128,height:128,color:"FFFFFF",transparent:false,root:root)
        var drawing=EditorLayer(kind:.drawing);drawing.frame=Box(x:0,y:0,width:128,height:128);drawing.blend = .multiply;drawing.strokes=[Stroke(points:[Point(x:20,y:64),Point(x:108,y:64)],width:40,color:"FF0000")];page.layers=[drawing]
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:128,height:128));canvas.update(page:page,directory:root.appendingPathComponent(page.id.uuidString),selected:drawing.id,zoom:1);canvas.refreshVisible(CGRect(x:0,y:0,width:128,height:128))
        canvas.showStroke(Stroke(points:[Point(x:64,y:50),Point(x:64,y:78)],width:30,color:"FFFFFF",erase:true),on:page,selected:drawing.id)
        for _ in 0..<100{if canvas.liveCompositeImage != nil{break};try await Task.sleep(nanoseconds:20_000_000)}
        let image=try XCTUnwrap(canvas.liveCompositeImage),cg=try XCTUnwrap(image.cgImage);var pixel=[UInt8](repeating:0,count:4)
        pixel.withUnsafeMutableBytes{buffer in let c=CGContext(data:buffer.baseAddress,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:ImagePipeline.space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;c.draw(cg,in:CGRect(x:-64,y:-64,width:128,height:128))}
        XCTAssertGreaterThan(pixel[1],240,"Erasure must reveal white beneath the red drawing while the touch is still active")
        canvas.showStroke(nil,on:page,selected:drawing.id);XCTAssertNil(canvas.liveCompositeImage)
    }

}
