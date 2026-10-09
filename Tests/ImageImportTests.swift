import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import CookiesEditor

final class ImageImportTests:XCTestCase {
    func testJPEGEXIFRotationKeepsFullDimensionsAndTopBottomContent()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:80,height:40),format:format).image{output in UIColor.red.setFill();output.fill(CGRect(x:0,y:0,width:40,height:40));UIColor.blue.setFill();output.fill(CGRect(x:40,y:0,width:40,height:40))}
        let input=root.appendingPathComponent("rotated.jpg"),destination=try XCTUnwrap(CGImageDestinationCreateWithURL(input as CFURL,UTType.jpeg.identifier as CFString,1,nil))
        CGImageDestinationAddImage(destination,try XCTUnwrap(image.cgImage),[kCGImagePropertyOrientation:6,kCGImageDestinationLossyCompressionQuality:1] as CFDictionary);XCTAssertTrue(CGImageDestinationFinalize(destination))
        let page=try ImagePipeline.importImage(input,root:root);XCTAssertEqual(page.width,40);XCTAssertEqual(page.height,80)
        let raw=root.appendingPathComponent(page.id.uuidString).appendingPathComponent(page.raw)
        let top=try ImagePipeline.tile(raw,width:40,height:80,rect:CGRect(x:10,y:10,width:1,height:1)),bottom=try ImagePipeline.tile(raw,width:40,height:80,rect:CGRect(x:10,y:70,width:1,height:1))
        XCTAssertGreaterThan(top[0],235);XCTAssertLessThan(top[2],20);XCTAssertGreaterThan(bottom[2],235);XCTAssertLessThan(bottom[0],20)
    }
    func testTransparentPNGIsCopiedByteForByteAndExportedWithoutReencoding()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
        let original=try PageOperations.blank(title:"alpha",width:24,height:1000,color:"FF0011",transparent:true,root:root),file=root.appendingPathComponent(original.id.uuidString).appendingPathComponent(original.source),before=try Data(contentsOf:file)
        let imported=try ImagePipeline.importImage(file,root:root),directory=root.appendingPathComponent(imported.id.uuidString),exported=try ImagePipeline.exportPNG(imported,directory:directory);defer{try? FileManager.default.removeItem(at:exported)}
        XCTAssertEqual(imported.width,24);XCTAssertEqual(imported.height,1000);XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(imported.source)),before);XCTAssertEqual(try Data(contentsOf:exported),before)
    }
}
