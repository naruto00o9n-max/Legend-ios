import XCTest
import UIKit
@testable import CookiesEditor

final class CanvasGridTests:XCTestCase {
    func testLongImageGridRemainsBoundedAtExtremeZoomOut(){
        var value=CanvasGridSettings();value.enabled=true;value.spacing=1
        let lines=CanvasGridGeometry.lines(settings:value,image:CGRect(x:0,y:0,width:800,height:1_000_000),visible:CGRect(x:0,y:0,width:800,height:1_000_000),zoom:0.002)
        XCTAssertLessThan(lines.count,180);XCTAssertFalse(lines.isEmpty)
        for line in lines{XCTAssertTrue(line.start.x.isFinite && line.start.y.isFinite && line.end.x.isFinite && line.end.y.isFinite)}
    }
    func testSquareGridIsAnchoredToImageWhileVisibleAreaMoves(){
        var value=CanvasGridSettings();value.enabled=true;value.spacing=64
        let image=CGRect(x:0,y:0,width:800,height:15000),area=CGRect(x:129,y:812,width:280,height:360)
        let lines=CanvasGridGeometry.lines(settings:value,image:image,visible:area,zoom:1)
        XCTAssertFalse(lines.isEmpty)
        for line in lines{if line.start.x==line.end.x{XCTAssertEqual(line.start.x.truncatingRemainder(dividingBy:64),0);XCTAssertEqual(line.start.y,area.minY);XCTAssertEqual(line.end.y,area.maxY)}else{XCTAssertEqual(line.start.y.truncatingRemainder(dividingBy:64),0)}}
        XCTAssertTrue(CanvasGridGeometry.lines(settings:value,image:image,visible:area,zoom:.nan).isEmpty)
        value.enabled=false;XCTAssertTrue(CanvasGridGeometry.lines(settings:value,image:image,visible:area,zoom:1).isEmpty)
    }
    func testThirdsAndCenterAreRealImageGuidesAndSettingsSurviveSerialization(){
        var value=CanvasGridSettings();value.enabled=true;value.kind = .thirds;value.color="000000";value.opacity=0.8
        let image=CGRect(x:0,y:0,width:300,height:600),lines=CanvasGridGeometry.lines(settings:value,image:image,visible:image,zoom:1)
        XCTAssertEqual(lines.count,4);XCTAssertTrue(lines.contains{$0.start==CGPoint(x:100,y:0) && $0.end==CGPoint(x:100,y:600)})
        XCTAssertEqual(CanvasGridSettings.decode(value.data),value);value.kind = .center
        XCTAssertEqual(CanvasGridGeometry.lines(settings:value,image:image,visible:image,zoom:1).count,2)
        value.spacing = .infinity;value.width = -100;value.opacity = 100;value.color="broken";let clean=value.normalized
        XCTAssertEqual(clean.spacing,64);XCTAssertEqual(clean.width,0.5);XCTAssertEqual(clean.opacity,1);XCTAssertEqual(clean.color,"FFFFFF")
    }
    @MainActor func testGridUsesOnlyViewportLayersAndDoesNotChangeDocumentOrSource()throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:root)}
        let page=try PageOperations.blank(title:"أصل",width:800,height:15000,color:"FFFFFF",transparent:false,root:root),source=root.appendingPathComponent(page.id.uuidString).appendingPathComponent(page.source),bytes=try Data(contentsOf:source)
        let viewport=UIScrollView(frame:CGRect(x:0,y:0,width:320,height:640)),canvas=UIView(frame:CGRect(x:0,y:0,width:800,height:15000));viewport.addSubview(canvas);viewport.contentSize=canvas.bounds.size
        let overlay=CanvasGridOverlay();var value=CanvasGridSettings();value.enabled=true
        overlay.update(settings:value,canvas:canvas,viewport:viewport);XCTAssertGreaterThan(overlay.visibleLineCount,0);XCTAssertLessThan(overlay.visibleLineCount,100)
        viewport.contentOffset=CGPoint(x:0,y:9000);overlay.update(settings:value,canvas:canvas,viewport:viewport);XCTAssertLessThan(overlay.visibleLineCount,100)
        value.enabled=false;overlay.update(settings:value,canvas:canvas,viewport:viewport);XCTAssertEqual(overlay.visibleLineCount,0);XCTAssertTrue(page.layers.isEmpty);XCTAssertEqual(try Data(contentsOf:source),bytes)
    }
}
