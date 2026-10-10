import UIKit

enum BubbleShape:String,CaseIterable,Identifiable {
    case oval, scream, box, system
    var id:String{rawValue}
    var title:String{switch self{case .oval:return "بيضاوية";case .scream:return "صراخ";case .box:return "مستطيلة";case .system:return "نظام"}}
}
struct BubbleLayoutRequest {var bounds:CGRect;var shape:BubbleShape;var margin:Double=0.10}

/// Measure shaped words, then minimize deviation from a symmetric width profile.
/// No spaces or Kashida are inserted: Arabic shaping and word order remain intact.
enum BubbleLayout {
    static func lines(_ text:String,count:Int,width:Double,shape:BubbleShape,measure:(String)->Double)->[String]? {
        let words=text.split(whereSeparator:{$0.isWhitespace}).map(String.init),n=words.count
        guard count>0,count<=n,n<=256 else{return nil}
        var costs=Array(repeating:Array(repeating:Double.infinity,count:n+1),count:count+1)
        var previous=Array(repeating:Array(repeating:-1,count:n+1),count:count+1)
        var widths:[String:Double]=[:]
        func metric(_ value:String)->Double{if let v=widths[value]{return v};let v=measure(value);widths[value]=v;return v}
        costs[0][0]=0
        for row in 0..<count {
            let distance=abs(Double(row)-Double(count-1)/2)/max(1,Double(count-1)/2)
            let ratio=(shape == .box || shape == .system) ? 1:1-0.32*distance*distance
            let target=width*ratio
            for start in 0..<n where costs[row][start].isFinite {
                var line=""
                for end in start..<n {
                    line += (line.isEmpty ? "":" ")+words[end]
                    let w=metric(line)
                    if w>target{break}
                    if n-(end+1)<count-(row+1){continue}
                    let difference=(target-w)/max(1,target)
                    let orphan=(end==start && n>count && count>1) ? 0.3:0
                    let cost=costs[row][start]+difference*difference+orphan
                    if cost<costs[row+1][end+1]{costs[row+1][end+1]=cost;previous[row+1][end+1]=start}
                }
            }
        }
        guard costs[count][n].isFinite else{return nil}
        var output:[String]=[],end=n
        for row in stride(from:count,through:1,by:-1){let start=previous[row][end];guard start>=0 else{return nil};output.insert(words[start..<end].joined(separator:" "),at:0);end=start}
        return output
    }
    static func fit(_ input:EditorLayer,request:BubbleLayoutRequest)throws->EditorLayer {
        let area=request.bounds.standardized
        guard area.width>=24,area.height>=24,!input.textContent.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw ImageFailure.message("ارسم مساحة أكبر داخل الفقاعة")}
        let inset=max(2,min(0.25,max(0,request.margin))*Double(min(area.width,area.height)))
        let content=area.insetBy(dx:inset,dy:inset),words=input.textContent.split(whereSeparator:{$0.isWhitespace})
        guard words.count<=256 else{throw ImageFailure.message("قسّم هذا النص الطويل إلى أكثر من فقاعة")}
        var best:EditorLayer?,bestSize=0.0
        // Keep explicit system paragraphs (such as headings) rather than flattening them.
        let paragraphs=request.shape == .system ? input.textContent.components(separatedBy:"\n").filter{!$0.isEmpty}:[]
        for count in 1...min(16,max(1,words.count)) {
            var low=6.0,high=min(256,max(input.style.fontSize,Double(content.height)))
            var candidate:EditorLayer?
            for _ in 0..<11 {
                let size=(low+high)/2
                var layer=input;layer.scaleX=1;layer.scaleY=1;layer.rotation=0;layer.style.fontSize=size;layer.style.boxWidth=Double(content.width);layer.style.alignment=1
                let font=Fonts.font(layer.style)
                let measure:(String)->Double={Double(($0 as NSString).size(withAttributes:[.font:font,.kern:layer.style.letterSpacing]).width)}
                let balanced=paragraphs.count>1 ? paragraphs:lines(input.textContent,count:count,width:Double(content.width),shape:request.shape,measure:measure)
                if let balanced,!balanced.isEmpty{layer.textContent=balanced.joined(separator:"\n");let actual=LayerRenderer.bounds(layer)
                    if actual.height<=content.height && balanced.allSatisfy({measure($0)<=Double(content.width)}){candidate=layer;low=size}else{high=size}
                }else{high=size}
            }
            if let candidate,candidate.style.fontSize>bestSize{best=candidate;bestSize=candidate.style.fontSize}
            if paragraphs.count>1{break}
        }
        guard var result=best,bestSize>=6 else{throw ImageFailure.message("المساحة لا تكفي لهذا النص؛ وسّع التحديد")}
        let measured=LayerRenderer.bounds(result);result.frame=Box(x:content.minX,y:content.midY-measured.height/2,width:content.width,height:measured.height)
        return result
    }
}
