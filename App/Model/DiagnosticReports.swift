import Foundation
import MetricKit

struct DiagnosticReport:Identifiable {
    var id:String {url.lastPathComponent}
    var url:URL
    var date:Date
    var crashes:Int
}

/// Store only OS diagnostic payloads, locally. No account, text or project content is added.
struct DiagnosticReports {
    var directory:URL
    init(directory:URL?=nil){self.directory=directory ?? FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Cookies/Diagnostics",isDirectory:true)}
    func record(_ payload:Data)throws {
        guard payload.count<=4*1024*1024,try JSONSerialization.jsonObject(with:payload) is [String:Any] else{throw ImageFailure.message("تقرير التشخيص غير صالح")}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let file=directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        try payload.write(to:file,options:.atomic)
        for old in try reports().dropFirst(15){try FileManager.default.removeItem(at:old.url)}
    }
    func reports()throws->[DiagnosticReport] {
        guard FileManager.default.fileExists(atPath:directory.path) else{return []}
        return try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.creationDateKey,.contentModificationDateKey]).filter{$0.pathExtension=="json"}.map{file in
            let date=try file.resourceValues(forKeys:[.creationDateKey,.contentModificationDateKey])
            let json=(try? JSONSerialization.jsonObject(with:Data(contentsOf:file))) as? [String:Any]
            let diagnostics=json?["crashDiagnostics"] as? [Any] ?? []
            return DiagnosticReport(url:file,date:date.contentModificationDate ?? date.creationDate ?? .distantPast,crashes:diagnostics.count)
        }.sorted{if $0.date==$1.date{return $0.id<$1.id};return $0.date>$1.date}
    }
    func remove(_ report:DiagnosticReport)throws {
        guard report.url.deletingLastPathComponent().standardizedFileURL==directory.standardizedFileURL else{throw ImageFailure.message("مسار التقرير غير صالح")}
        try FileManager.default.removeItem(at:report.url)
    }
}

final class DiagnosticReporter:NSObject,MXMetricManagerSubscriber {
    static let shared=DiagnosticReporter()
    private let worker=DispatchQueue(label:"cookies.diagnostic-reports",qos:.utility)
    func start(){MXMetricManager.shared.add(self)}
    func didReceive(_ payloads:[MXDiagnosticPayload]){
        worker.async{for payload in payloads{try? DiagnosticReports().record(payload.jsonRepresentation())}}
    }
}
