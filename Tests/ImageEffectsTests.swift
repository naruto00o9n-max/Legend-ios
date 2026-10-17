import XCTest
import UIKit
import CoreImage
@testable import CookiesEditor

final class ImageEffectsTests:XCTestCase {
    private let context=CIContext(options:[.cacheIntermediates:false,.workingColorSpace:CGColorSpace(name:CGColorSpace.sRGB)!])
    private func pixels(_ image:CIImage,_ rect:CGRect)->[UInt8]{
        var result=[UInt8](repeating:0,count:Int(rect.width*rect.height)*4)
        context.render(image,toBitmap:&result,rowBytes:Int(rect.width)*4,bounds:rect,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!);return result
    }
    private func fixture(width:Int=96,height:Int=180)throws->(EditorPage,URL,URL,[UInt8]){
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var page=EditorPage(title:"اختبار التأثيرات",width:width,height:height)
        let directory=root.appendingPathComponent(page.id.uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        var raw=[UInt8](repeating:0,count:width*height*4)
        for y in 0..<height{for x in 0..<width{let i=(y*width+x)*4;raw[i]=UInt8((x*17+y*3)%256);raw[i+1]=UInt8((x*3+y*7)%256);raw[i+2]=UInt8((x*11+y*13)%256);raw[i+3]=(x<8 || y<8 || x>=width-8 || y>=height-8) ? 0:255}}
        try Data(raw).write(to:directory.appendingPathComponent(page.raw))
        let cg=try XCTUnwrap(ImagePipeline.image(raw,width:width,height:height))
        try XCTUnwrap(UIImage(cgImage:cg).pngData()).write(to:directory.appendingPathComponent(page.source))
        page.modified=Date();return(page,directory,root,raw)
    }
    func testAllThirteenEffectsRenderAndSurviveSerialization()throws{
        XCTAssertTrue(ImageEffectGraph.kernelsAvailable,"Every custom kernel must compile on iOS")
        let (page,dir,root,raw)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let source=CIImage(cgImage:try XCTUnwrap(ImagePipeline.image(raw,width:page.width,height:page.height))),size=CGSize(width:page.width,height:page.height),rect=CGRect(origin:.zero,size:size),original=pixels(source,rect)
        XCTAssertEqual(ImageEffectKind.allCases.count,13)
        for kind in ImageEffectKind.allCases{
            let effect=ImageEffect(kind),result=ImageEffectGraph.apply(source,effects:[effect],size:size)
            XCTAssertNotEqual(pixels(result,rect),original,kind.rawValue)
            var layer=EditorLayer(kind:.image);layer.imagePath=page.source;layer.imageEffects=[effect]
            let reopened=try JSONDecoder().decode(EditorLayer.self,from:JSONEncoder().encode(layer))
            XCTAssertEqual(reopened,layer);XCTAssertEqual(pixels(ImageEffectGraph.apply(source,effects:reopened.effectiveImageEffects,size:size),rect),pixels(result,rect))
            var disabled=effect;disabled.enabled=false;XCTAssertEqual(pixels(ImageEffectGraph.apply(source,effects:[disabled],size:size),rect),original)
            disabled.enabled=true;disabled.opacity=0;XCTAssertEqual(pixels(ImageEffectGraph.apply(source,effects:[disabled],size:size),rect),original)
        }
        XCTAssertEqual(try Data(contentsOf:dir.appendingPathComponent(page.raw)),Data(raw))
    }
    func testProviderOrientationAndTiledGraphMatchWholeImage()throws{
        let (page,dir,root,raw)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let provider=ImagePixelProvider(url:dir.appendingPathComponent(page.raw),width:page.width,height:page.height,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
        let source=CIImage(cgImage:try XCTUnwrap(ImagePipeline.image(raw,width:page.width,height:page.height))),size=CGSize(width:page.width,height:page.height),rect=CGRect(origin:.zero,size:size)
        XCTAssertEqual(pixels(provider.image,rect),pixels(source,rect),"Provider rows must preserve source orientation")
        for kind in ImageEffectKind.allCases{
            let graph=ImageEffectGraph.apply(provider.image,effects:[ImageEffect(kind)],size:size),whole=pixels(graph,rect)
            var tiled=[UInt8]()
            // CI bounds use bottom-left coordinates; bitmap rows are top-down.
            for y in Array(stride(from:0,to:page.height,by:30)).reversed(){tiled += pixels(graph,CGRect(x:0,y:y,width:page.width,height:min(30,page.height-y)))}
            let delta=zip(tiled,whole).map{abs(Int($0)-Int($1))}.max() ?? 0
            XCTAssertEqual(tiled.count,whole.count)
            // Native GPU fusion may round an 8-bit channel by one unit between
            // whole and regional renders. Source/no-effect tests remain exact.
            XCTAssertLessThanOrEqual(delta,1,"Global coordinates and halo reads must cross tile boundaries: \(kind.rawValue)")
        }
        XCTAssertNil(provider.error);XCTAssertLessThanOrEqual(provider.largestRequestPixels,256*256)
    }
    func testBlurModesAndEffectSpecificParametersActuallyChangePixels()throws{
        let (page,_,root,raw)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let source=CIImage(cgImage:try XCTUnwrap(ImagePipeline.image(raw,width:page.width,height:page.height))),size=CGSize(width:page.width,height:page.height),rect=CGRect(origin:.zero,size:size),original=pixels(source,rect)
        for mode in 0...4{var effect=ImageEffect(.blur);effect.parameter1=Double(mode);XCTAssertNotEqual(pixels(ImageEffectGraph.apply(source,effects:[effect],size:size),rect),original,"Blur mode \(mode)")}
        for kind in [ImageEffectKind.chromatic,.slice,.fade,.halftone,.mirror,.vignette,.grain]{
            var effect=ImageEffect(kind);let first=pixels(ImageEffectGraph.apply(source,effects:[effect],size:size),rect)
            switch kind{case .mirror:effect.parameter1=1;case .vignette:effect.parameter1=0;case .grain:effect.parameter1=8;default:effect.angle=67}
            XCTAssertNotEqual(pixels(ImageEffectGraph.apply(source,effects:[effect],size:size),rect),first,kind.rawValue)
        }
        var fade=ImageEffect(.fade);let first=pixels(ImageEffectGraph.apply(source,effects:[fade],size:size),rect);fade.parameter2=20
        XCTAssertNotEqual(pixels(ImageEffectGraph.apply(source,effects:[fade],size:size),rect),first)
    }

    func testProviderMatchesNativePartialTransparencyAndKeepsSourceBytes()throws{
        let (page,dir,root,initial)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        var raw=initial;for i in stride(from:0,to:raw.count,by:4){raw[i+3]=UInt8((i/4)%256)}
        try Data(raw).write(to:dir.appendingPathComponent(page.raw))
        let provider=ImagePixelProvider(url:dir.appendingPathComponent(page.raw),width:page.width,height:page.height,colorSpace:ImagePipeline.space)
        let expected=CIImage(cgImage:try XCTUnwrap(ImagePipeline.image(raw,width:page.width,height:page.height))),rect=CGRect(x:0,y:0,width:page.width,height:page.height)
        let a=pixels(provider.image,rect),b=pixels(expected,rect),delta=zip(a,b).map{abs(Int($0)-Int($1))}.max() ?? 0
        XCTAssertLessThanOrEqual(delta,1,"Provider alpha conversion must agree with native Core Image precision")
        XCTAssertEqual(try Data(contentsOf:dir.appendingPathComponent(page.raw)),Data(raw))
    }

    func testStackOrderAndGlitchColorsAreActualRenderingInputs()throws{
        let (page,_,root,raw)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let source=CIImage(cgImage:try XCTUnwrap(ImagePipeline.image(raw,width:page.width,height:page.height))),size=CGSize(width:page.width,height:page.height),rect=CGRect(origin:.zero,size:size)
        let duo=ImageEffect(.duotone),grain=ImageEffect(.grain)
        XCTAssertNotEqual(pixels(ImageEffectGraph.apply(source,effects:[duo,grain],size:size),rect),pixels(ImageEffectGraph.apply(source,effects:[grain,duo],size:size),rect))
        var glitch=ImageEffect(.glitch);let original=pixels(ImageEffectGraph.apply(source,effects:[glitch],size:size),rect);glitch.color="FFFF00";glitch.color2="0011FF"
        XCTAssertNotEqual(pixels(ImageEffectGraph.apply(source,effects:[glitch],size:size),rect),original)
    }
    @MainActor func testSourceEffectsUndoResetArchiveAndOriginalBytes()async throws{
        let (page,dir,root,raw)=try fixture();defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);library.add(page,parent:nil);let model=EditorModel(page:page,library:library)
        let original=try Data(contentsOf:dir.appendingPathComponent(page.source))
        await model.openImageEffects();XCTAssertNil(model.error);XCTAssertEqual(model.page.layers.count,1);XCTAssertTrue(model.page.baseHidden==true);XCTAssertEqual(model.logicalLayerCount,1);XCTAssertEqual(model.active?.imagePath,page.source)
        let layerID=try XCTUnwrap(model.selected),duo=try XCTUnwrap(model.addImageEffect(.duotone)),grain=try XCTUnwrap(model.addImageEffect(.grain))
        model.moveImageEffect(grain,by:-1);XCTAssertEqual(model.active?.imageEffects?.first?.id,grain)
        model.undo();model.selected=layerID;XCTAssertEqual(model.active?.imageEffects?.first?.id,duo)
        model.redo();model.selected=layerID;XCTAssertEqual(model.active?.imageEffects?.first?.id,grain)
        let archive=try ProjectArchive.export(model.page,directory:dir);defer{try? FileManager.default.removeItem(at:archive)}
        let restored=try ProjectArchive.importFile(archive,root:root);XCTAssertEqual(restored.layers,model.page.layers)
        let a=try ImagePipeline.compositeRegion(model.page,directory:dir,rect:CGRect(x:0,y:0,width:page.width,height:page.height))
        let b=try ImagePipeline.compositeRegion(restored,directory:root.appendingPathComponent(restored.id.uuidString),rect:CGRect(x:0,y:0,width:page.width,height:page.height))
        XCTAssertEqual(a.dataProvider?.data as Data?,b.dataProvider?.data as Data?)
        model.clearImageEffects();let exported=try ImagePipeline.exportPNG(model.page,directory:dir);defer{try? FileManager.default.removeItem(at:exported)}
        XCTAssertEqual(try Data(contentsOf:exported),original,"Restore original must preserve every original PNG byte")
        XCTAssertEqual(try Data(contentsOf:dir.appendingPathComponent(page.raw)),Data(raw));model.save()
        let reopened=try JSONDecoder().decode(EditorPage.self,from:Data(contentsOf:dir.appendingPathComponent("page.json")));XCTAssertEqual(reopened.layers,model.page.layers)
    }
    func testEveryEffectExportsAllBandsAndRetainsOriginalDimensions()throws{
        var (page,dir,root,_)=try fixture(width:96,height:540);defer{try? FileManager.default.removeItem(at:root)}
        let original=try Data(contentsOf:dir.appendingPathComponent(page.source))
        var layer=EditorLayer(kind:.image);layer.imagePath=page.source;layer.isWorkingImage=true;layer.imagePixelFile=page.raw;layer.imagePixelWidth=page.width;layer.imagePixelHeight=page.height;layer.frame=Box(x:0,y:0,width:Double(page.width),height:Double(page.height));page.baseHidden=true
        for kind in ImageEffectKind.allCases{
            layer.imageEffects=[ImageEffect(kind)];page.layers=[layer]
            let whole=try ImagePipeline.compositeRegion(page,directory:dir,rect:CGRect(x:0,y:0,width:page.width,height:page.height))
            let expected=try XCTUnwrap(whole.dataProvider?.data) as Data
            let output=try ImagePipeline.exportPNG(page,directory:dir),decoded=dir.appendingPathComponent("effect-export.rgba");defer{try? FileManager.default.removeItem(at:output)}
            var w:Int32=0,h:Int32=0,error=[CChar](repeating:0,count:512)
            XCTAssertEqual(LIImportPNG(output.path,decoded.path,&w,&h,&error,error.count),1);XCTAssertEqual(Int(w),page.width);XCTAssertEqual(Int(h),page.height)
            let actual=try Data(contentsOf:decoded)
            XCTAssertEqual(actual.count,expected.count)
            var delta=0
            if actual.count==expected.count{for offset in stride(from:0,to:actual.count,by:4){delta=max(delta,abs(Int(actual[offset+3])-Int(expected[offset+3])));for c in 0..<3{let a=(Int(actual[offset+c])*Int(actual[offset+3])+127)/255,b=(Int(expected[offset+c])*Int(expected[offset+3])+127)/255;delta=max(delta,abs(a-b))}}}
            XCTAssertLessThanOrEqual(delta,1,"PNG bands must equal the full-resolution visible compositor within native 8-bit rounding: \(kind.rawValue)")
        }
        XCTAssertEqual(try Data(contentsOf:dir.appendingPathComponent(page.source)),original)
    }
    @MainActor func testImageEffectsRemainEditableAfterSplitAndBackgroundReplacement()async throws{
        let (page,dir,root,_)=try fixture(width:96,height:540);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);library.add(page,parent:nil);let model=EditorModel(page:page,library:library);await model.openImageEffects();let id=try XCTUnwrap(model.addImageEffect(.vignette))
        let cropped=try PageOperations.cropped(model.page,rect:CGRect(x:0,y:200,width:96,height:200),root:root)
        XCTAssertEqual(cropped.layers.first?.imageEffects?.first?.id,id)
        let before=try ImagePipeline.compositeRegion(model.page,directory:dir,rect:CGRect(x:0,y:200,width:96,height:200))
        let after=try ImagePipeline.compositeRegion(cropped,directory:root.appendingPathComponent(cropped.id.uuidString),rect:CGRect(x:0,y:0,width:96,height:200))
        XCTAssertEqual(before.dataProvider?.data as Data?,after.dataProvider?.data as Data?,"Cropping must preserve global effect coordinates")
        let oldPath=try XCTUnwrap(model.active?.imagePath);await model.replaceBackground(dir.appendingPathComponent(page.source));XCTAssertNil(model.error)
        XCTAssertNotEqual(model.page.layers.first?.imagePath,oldPath);XCTAssertEqual(model.page.layers.first?.imageEffects?.first?.id,id);XCTAssertTrue(model.page.baseHidden==true)
    }

    func testWorkingImagePreservesWideGamutProfileWithoutEffects()throws{
        var (page,dir,root,raw)=try fixture(width:64,height:64);defer{try? FileManager.default.removeItem(at:root)}
        let space=try XCTUnwrap(CGColorSpace(name:CGColorSpace.displayP3))
        let source=try XCTUnwrap(ImagePipeline.image(raw,width:64,height:64,colorSpace:space))
        try XCTUnwrap(UIImage(cgImage:source).pngData()).write(to:dir.appendingPathComponent(page.source))
        var layer=EditorLayer(kind:.image);layer.imagePath=page.source;layer.isWorkingImage=true;layer.imagePixelFile=page.raw;layer.imagePixelWidth=64;layer.imagePixelHeight=64;layer.frame=Box(x:0,y:0,width:64,height:64);page.layers=[layer];page.baseHidden=true
        let rendered=try ImagePipeline.compositeRegion(page,directory:dir,rect:CGRect(x:0,y:0,width:64,height:64))
        XCTAssertTrue(CFEqual(rendered.colorSpace,ImagePipeline.colorSpace(dir.appendingPathComponent(page.source))))
        let output=try XCTUnwrap(rendered.dataProvider?.data) as Data
        for y in 16..<48{for x in 16..<48{let index=(y*64+x)*4;for c in 0..<3{XCTAssertEqual(Double(output[index+c]),Double(raw[index+c]),accuracy:2,"Unchanged wide-gamut image must retain its RGB values")}}}
    }

    func testLongSourceUsesBoundedProviderRequests()throws{
        let (page,dir,root,raw)=try fixture(width:800,height:15000);defer{try? FileManager.default.removeItem(at:root)}
        let provider=ImagePixelProvider(url:dir.appendingPathComponent(page.raw),width:800,height:15000,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
        let graph=ImageEffectGraph.apply(provider.image,effects:[ImageEffect(.mirror),ImageEffect(.grain)],size:CGSize(width:800,height:15000))
        for y in [0,7420,14872]{XCTAssertFalse(pixels(graph,CGRect(x:20,y:y,width:128,height:128)).isEmpty)}
        XCTAssertNil(provider.error);XCTAssertLessThanOrEqual(provider.largestRequestPixels,65_536)
        XCTAssertEqual(try Data(contentsOf:dir.appendingPathComponent(page.raw)),Data(raw));XCTAssertEqual(page.width,800);XCTAssertEqual(page.height,15000)
    }
    @MainActor func testLiveImageSettingsPublishDuringContinuousChangesWithoutInvalidatingSource()async throws{
        let (page,dir,root,_)=try fixture(width:800,height:2000);defer{try? FileManager.default.removeItem(at:root)}
        let library=LibraryStore(root:root);library.add(page,parent:nil);let model=EditorModel(page:page,library:library);await model.openImageEffects();let id=try XCTUnwrap(model.addImageEffect(.grain))
        let canvas=DocumentCanvas(frame:CGRect(x:0,y:0,width:800,height:2000));canvas.update(page:model.page,directory:dir,selected:model.selected,zoom:1);canvas.refreshVisible(CGRect(x:0,y:0,width:800,height:600))
        let revision=canvas.revision,start=Date();model.setContinuousEditing(true)
        for i in 0..<50{model.editImageEffect(id){$0.intensity=Double(i+20)};canvas.previewImageSettings(page:model.page,directory:dir,selected:model.selected,zoom:1);try await Task.sleep(nanoseconds:30_000_000)}
        print("IMAGE_LIVE frames=\(canvas.imagePresentedFrames) duration=\(Date().timeIntervalSince(start))")
        XCTAssertGreaterThan(canvas.imagePresentedFrames,0,"Publish intermediate image frames before input stops")
        XCTAssertEqual(canvas.revision,revision,"Knob changes must not enqueue detail tiles for every update")
        model.setContinuousEditing(false);canvas.finishImageSettings();XCTAssertGreaterThan(canvas.revision,revision)
        let deadline=Date().addingTimeInterval(10)
        while !canvas.visibleTilesReady && Date()<deadline{try await Task.sleep(nanoseconds:30_000_000)}
        XCTAssertTrue(canvas.visibleTilesReady,"Closing image tools must resume any deferred detail tiles")
    }
}
