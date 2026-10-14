import XCTest
import UIKit
import ImageIO
import CoreML
import Darwin
@testable import LaMaProbe

final class ProbeTests:XCTestCase {
    @MainActor func testActualBigLaMaOnRealComicCrops()async throws {
        let assets=BigLaMaAssets(),started=Date(),compiled=try await assets.install()
        let preparation=Date().timeIntervalSince(started)
        let directory=try XCTUnwrap(Bundle.main.url(forResource:"lama-probe-fixtures",withExtension:nil))
        let outcomes=try await BackgroundWork.run{()throws->[Outcome] in
            let model=try BigLaMaSession(compiled:compiled)
            var results:[Outcome]=[]
            for name in ["colored-hatched-dialogue","real-manhwa-white-shadow"] {
                let source=try Self.read(directory.appendingPathComponent(name+".png")),mask=try Self.read(directory.appendingPathComponent(name+"-mask.png"))
                let before=Date(),patch=try model.repair(source:source,mask:mask),elapsed=Date().timeIntervalSince(before)
                let original=try BigLaMaSession.rgba(source),ink=try BigLaMaSession.rgba(mask),after=try BigLaMaSession.rgba(patch)
                var outside=0,count=0,difference=0.0,sum=0.0,white=0,composite=original
                for i in 0..<(source.width*source.height){let p=i*4
                    if ink[p]==0{if after[p+3] != 0{outside+=1};continue}
                    count+=1;for c in 0..<3{difference+=abs(Double(after[p+c])-Double(original[p+c]));sum+=Double(after[p+c]);composite[p+c]=after[p+c]}
                    if after[p]>240 && after[p+1]>240 && after[p+2]>240{white+=1}
                }
                var usage=rusage();getrusage(RUSAGE_SELF,&usage)
                let metric:[String:Any]=["name":name,"width":source.width,"height":source.height,"seconds":elapsed,"masked_pixels":count,"outside_mask_patch_pixels":outside,"mean_masked_change":difference/Double(max(1,count)*3),"mean_repaired_channel":sum/Double(max(1,count)*3),"white_fraction":Double(white)/Double(max(1,count)),"peak_process_resident_bytes":Int64(usage.ru_maxrss),"platform":"iOS simulator; not physical iPad performance"]
                results.append(Outcome(name:name,source:source,mask:mask,composite:try Self.image(composite,width:source.width,height:source.height),metric:metric))
            }
            return results
        }
        for result in outcomes{
            XCTAssertEqual(result.metric["outside_mask_patch_pixels"] as? Int,0)
            XCTAssertGreaterThan(result.metric["mean_masked_change"] as? Double ?? 0,5,"Real text must change; a copied input is not inference")
            if result.name=="real-manhwa-white-shadow"{XCTAssertGreaterThan(result.metric["mean_repaired_channel"] as? Double ?? 0,235)}else{XCTAssertLessThan(result.metric["white_fraction"] as? Double ?? 1,0.85,"Colored reconstruction must not be a white rectangle")}
            for (suffix,image) in [("source",result.source),("mask",result.mask),("repaired",result.composite)]{let attachment=XCTAttachment(image:UIImage(cgImage:image),quality:.original);attachment.name=result.name+"-"+suffix;attachment.lifetime = .keepAlways;add(attachment)}
            let data=try JSONSerialization.data(withJSONObject:result.metric,options:[.sortedKeys,.prettyPrinted]);let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");attachment.name=result.name+"-metrics.json";attachment.lifetime = .keepAlways;add(attachment)
            print("BIG_LAMA "+String(data:data,encoding:.utf8)!.replacingOccurrences(of:"\n",with:" "))
        }
        print("BIG_LAMA setup_seconds=\(preparation) pinned_weight_bytes=215544960")
    }
    private struct Outcome {let name:String;let source:CGImage;let mask:CGImage;let composite:CGImage;let metric:[String:Any]}
    private static func read(_ url:URL)throws->CGImage{guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else{throw LaMaFailure.message("Missing real fixture")};return image}
    private static func image(_ bytes:[UInt8],width:Int,height:Int)throws->CGImage{guard let provider=CGDataProvider(data:Data(bytes) as CFData),let image=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent) else{throw LaMaFailure.message("Cannot encode probe output")};return image}
}
