import XCTest
import UIKit
import ImageIO
@testable import CookiesEditor

final class EditorTests:XCTestCase {
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
        let source=UIGraphicsImageRenderer(size:CGSize(width:400,height:400),format:format).image{ctx in UIColor.white.setFill();ctx.fill(CGRect(x:0,y:0,width:400,height:400));("COOKIES" as NSString).draw(at:CGPoint(x:70,y:170),withAttributes:[.font:UIFont.boldSystemFont(ofSize:40),.foregroundColor:UIColor.black])}
        let mask=UIGraphicsImageRenderer(size:CGSize(width:400,height:400),format:format).image{ctx in UIColor.black.setFill();ctx.fill(CGRect(x:0,y:0,width:400,height:400));UIColor.white.setFill();ctx.fill(CGRect(x:55,y:140,width:290,height:120))}
        let patch=try XCTUnwrap(CookiesInpaint(source,mask,3));XCTAssertEqual(patch.size,source.size)
        for (name,image) in [("cleaner-before",source),("cleaner-mask",mask),("cleaner-after",patch)]{let a=XCTAttachment(image:image);a.name=name;a.lifetime = .keepAlways;add(a)}
        let data=try XCTUnwrap(patch.cgImage?.dataProvider?.data) as Data;XCTAssertEqual(data[3],0,"Unmasked patch must stay transparent")
    }
    @MainActor func testUndoAndLayerTransforms() throws {
        let library=LibraryStore(root:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString));let page=try ImagePipeline.fixture(root:library.root);library.add(page,parent:nil);let m=EditorModel(page:page,library:library)
        m.add(.text);m.change{$0.textContent="كوكيز"};let id=m.selected;m.checkpoint();m.change{$0.scaleX=2;$0.rotation=25};m.undo();XCTAssertEqual(m.page.layers.first?.scaleX,1);m.redo();XCTAssertEqual(m.page.layers.first?.scaleX,2);m.selected=id;m.duplicate();XCTAssertEqual(m.page.layers.count,2);m.delete();XCTAssertEqual(m.page.layers.count,1)
    }
    func testOfflinePolicy(){XCTAssertFalse(NetworkPolicy.enabled)}
}
