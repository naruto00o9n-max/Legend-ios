import XCTest
import UIKit
import CoreText
@testable import CookiesEditor

final class ColorAndReferenceEffectsTests:XCTestCase {
    private func root()->URL{FileManager.default.temporaryDirectory.appendingPathComponent("color-tests-"+UUID().uuidString)}
    private func rgba(_ image:CGImage)->[UInt8]{var bytes=[UInt8](repeating:0,count:image.width*image.height*4);bytes.withUnsafeMutableBytes{let c=CGContext(data:$0.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!;c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))};return bytes}
    private func render(_ layer:EditorLayer)->UIImage{let format=UIGraphicsImageRendererFormat();format.scale=2;return UIGraphicsImageRenderer(size:CGSize(width:450,height:230),format:format).image{c in c.cgContext.translateBy(x:70,y:50);LayerRenderer.drawText(layer,rect:LayerRenderer.bounds(layer),context:c.cgContext,directory:FileManager.default.temporaryDirectory)}}
    @MainActor func testColorsDeduplicatePersistFavoritesAndGroupsWithoutDiscardingOlderColors()throws{
        let root=root();defer{try? FileManager.default.removeItem(at:root)};let store=ColorLibraryStore(directory:root)
        store.record("#aabbcc");store.record("AABBCC");store.record("invalid");XCTAssertEqual(store.library.colors.count,1)
        let group=try XCTUnwrap(store.createGroup("الحوار"));store.favorite("AABBCC");store.toggleGroup("AABBCC",group)
        for i in 0..<240{store.record(String(format:"%06X",i))};try store.flush()
        let reopened=ColorLibraryStore(directory:root);XCTAssertEqual(reopened.library.colors.count,241);XCTAssertTrue(try XCTUnwrap(reopened.library.colors.first{$0.hex=="AABBCC"}).favorite);XCTAssertEqual(reopened.library.groups.first?.id,group);XCTAssertEqual(reopened.library.colors.first{$0.hex=="AABBCC"}?.groups,[group])
    }
    @MainActor func testSelectiveColorBackupRestoresOnlyColorsAndRetainsUnrelatedData()throws{
        let source=root(),destination=root();defer{try? FileManager.default.removeItem(at:source);try? FileManager.default.removeItem(at:destination)}
        let store=ColorLibraryStore(directory:source.appendingPathComponent("Colors"));store.record("112233");store.favorite("112233");try store.flush()
        let archive=try AppStorageManager.createBackup(selected:["Colors"],at:source);defer{try? FileManager.default.removeItem(at:archive)}
        try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true);try Data("keep".utf8).write(to:destination.appendingPathComponent("untouched.txt"))
        _ = try AppStorageManager.restore(archive,selected:["Colors"],at:destination);XCTAssertEqual(ColorLibraryStore(directory:destination.appendingPathComponent("Colors")).library,store.library);XCTAssertEqual(try String(contentsOf:destination.appendingPathComponent("untouched.txt")),"keep")
    }
    func baselineAdvance(_ layer:EditorLayer)throws->CGFloat{
        let attributed=LayerRenderer.attributed(layer),path=CGPath(rect:CGRect(x:0,y:0,width:300,height:1000),transform:nil),frame=CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attributed),CFRange(location:0,length:0),path,nil)
        let lines=CTFrameGetLines(frame) as! [CTLine];XCTAssertGreaterThanOrEqual(lines.count,2);var origins=[CGPoint](repeating:.zero,count:lines.count);CTFrameGetLineOrigins(frame,CFRange(location:0,length:0),&origins);return abs(origins[0].y-origins[1].y)
    }
    func testNegativeLineSpacingActuallyReducesBaselineAdvanceAndSurvivesCoding()throws{
        var layer=EditorLayer(kind:.text);layer.textContent="حوار واضح\nوسطر ثانٍ";layer.style=TextStyle.plainText(fontSize:40,boxWidth:300)
        let standard=try baselineAdvance(layer);layer.style.lineSpacing = -12;let tighter=try baselineAdvance(layer);XCTAssertLessThan(tighter,standard-6);XCTAssertGreaterThan(tighter,0);XCTAssertGreaterThan(render(layer).size.height,0)
        layer.style.lineSpacing = -60;XCTAssertGreaterThan(try baselineAdvance(layer),0);XCTAssertEqual(try JSONDecoder().decode(EditorLayer.self,from:JSONEncoder().encode(layer)).style.lineSpacing,-60)
    }
    func testRGBAndGlitchRemainEditableDeterministicAndVisibleWithGradientAndOutline()throws{
        var layer=EditorLayer(kind:.text);layer.textContent="زيوس";layer.style=TextStyle.plainText(fontSize:72,boxWidth:260);layer.style.textGradient=["201040","AA32CC"];layer.style.strokeWidth=2;layer.style.strokeColor="FFFFFF"
        let plain=rgba(render(layer).cgImage!);layer.style.effectType = .chromatic;layer.style.art=TextArtSettings(distance:12,angle:0,order:0,bandHeight:18,strength:12,colorShift:4,seed:7)
        let rgb=rgba(render(layer).cgImage!);XCTAssertNotEqual(rgb,plain);XCTAssertEqual(layer.textContent,"زيوس");XCTAssertEqual(layer.style.textGradient,["201040","AA32CC"])
        layer.style.effectType = .glitch;let a=rgba(render(layer).cgImage!),b=rgba(render(layer).cgImage!);XCTAssertEqual(a,b);XCTAssertNotEqual(a,rgb);layer.style.art?.seed=8;XCTAssertNotEqual(rgba(render(layer).cgImage!),a)
        let reopened=try JSONDecoder().decode(EditorLayer.self,from:JSONEncoder().encode(layer));XCTAssertEqual(reopened,layer)
        layer.style.effectType = .none;XCTAssertEqual(rgba(render(layer).cgImage!),plain)
    }
    @MainActor func testStyleDesignerPreservesEffectsTransformsFoldersFavoritesAndPackageRoundTrip()throws{
        let root=root(),destination=self.root();defer{try? FileManager.default.removeItem(at:root);try? FileManager.default.removeItem(at:destination)}
        let store=StyleStore(directory:root);var layer=EditorLayer(kind:.text);layer.style=TextStyle.plainText();layer.style.effectType = .chromatic;layer.style.art=TextArtSettings(distance:14);layer.style.lineSpacing = -7;layer.scaleX=1.2;layer.rotation=10
        let id=try store.save(title:"RGB",group:"حوار/صراخ",layer:layer,from:root);try store.createFolder("فارغ");try store.toggleFavorite(id);try store.updateKeywords(id,"حدود, صراخ")
        let package=try store.export();defer{try? FileManager.default.removeItem(at:package)};let other=StyleStore(directory:destination);_ = try other.importPackage(package)
        XCTAssertTrue(other.groups.contains("فارغ"));let style=try XCTUnwrap(other.styles.first);XCTAssertEqual(style.style,layer.style);XCTAssertEqual(style.transform,TextLayerTransform(layer));XCTAssertTrue(style.favorite==true);XCTAssertEqual(style.keywords,["حدود","صراخ"])
        let reopened=StyleStore(directory:root);XCTAssertEqual(reopened.styles.first?.transform,TextLayerTransform(layer));XCTAssertEqual(reopened.groups,store.groups)
    }
    func testColoredGradientAndOrnamentBubbleUsesExteriorInsteadOfInteriorDecoration()throws{
        for decorated in [false,true]{let f=UIGraphicsImageRendererFormat();f.scale=1;let image=UIGraphicsImageRenderer(size:CGSize(width:600,height:600),format:f).image{c in UIColor.darkGray.setFill();c.fill(CGRect(x:0,y:0,width:600,height:600));let path=UIBezierPath(ovalIn:CGRect(x:120,y:100,width:320,height:300));c.cgContext.saveGState();path.addClip();let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[UIColor.systemPink.cgColor,UIColor.systemYellow.cgColor,UIColor.systemPurple.cgColor] as CFArray,locations:[0,0.5,1])!;c.cgContext.drawLinearGradient(g,start:CGPoint(x:120,y:100),end:CGPoint(x:440,y:400),options:[]);if decorated{UIColor.black.setStroke();let decoration=UIBezierPath(ovalIn:CGRect(x:230,y:200,width:100,height:80));decoration.lineWidth=3;decoration.stroke()};c.cgContext.restoreGState();UIColor.black.setStroke();path.lineWidth=3;path.stroke()}
            let result=try XCTUnwrap(CookiesDetectBubble(image,CGPoint(x:280,y:240)) as? [String:Any]);XCTAssertEqual(result["pin"] as? Bool,false);XCTAssertGreaterThan((result["width"] as? NSNumber)?.doubleValue ?? 0,240);XCTAssertEqual((result["y"] as? NSNumber)?.doubleValue ?? 0,130,accuracy:15)
            let outside=try XCTUnwrap(CookiesDetectBubble(image,CGPoint(x:25,y:25)) as? [String:Any]);XCTAssertEqual(outside["pin"] as? Bool,true)
        }
    }
    func testUniformColoredWhiteningCanRecoverOCRMissedLineAndProtectDecoration()throws{
        let f=UIGraphicsImageRendererFormat();f.scale=1;let image=UIGraphicsImageRenderer(size:CGSize(width:240,height:220),format:f).image{c in UIColor.white.setFill();c.fill(CGRect(x:0,y:0,width:240,height:220));UIColor(red:1,green:0.9,blue:0.6,alpha:1).setFill();UIBezierPath(ovalIn:CGRect(x:10,y:10,width:220,height:200)).fill();UIColor.black.setFill();for y in [85,125]{for x in [65,90,115,140]{c.fill(CGRect(x:x,y:y,width:12,height:14))}};c.fill(CGRect(x:180,y:45,width:6,height:6))}
        let outline=(0..<80).map{i -> NSValue in let a=Double(i)*Double.pi*2/80;return NSValue(cgPoint:CGPoint(x:120+110*cos(a),y:110+100*sin(a)))}
        let result=try XCTUnwrap(CookiesWhitenBubble(image,outline,[NSValue(cgRect:CGRect(x:63,y:83,width:94,height:25))]));let patch=rgba(try XCTUnwrap((result["patch"] as? UIImage)?.cgImage));for y in [85,125]{for x in [65,90,115,140]{XCTAssertEqual(patch[(y*240+x)*4+3],255)}};XCTAssertEqual(patch[(48*240+183)*4+3],0);XCTAssertEqual(patch[(110*240+10)*4+3],0);XCTAssertEqual(result["reviewRequired"] as? Bool,true)
    }
}
