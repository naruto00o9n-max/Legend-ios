import Foundation
import SwiftUI

struct StoredColor:Codable,Equatable,Identifiable {
    var hex:String
    var lastUsed:Date
    var favorite=false
    var groups:[UUID]=[]
    var id:String{hex}
}
struct ColorGroup:Codable,Equatable,Identifiable {var id=UUID();var title:String}
struct ColorLibrary:Codable,Equatable {var version=1;var colors:[StoredColor]=[];var groups:[ColorGroup]=[]}

/// One small durable library. No bitmap storage and no disk IO on an editor gesture.
@MainActor final class ColorLibraryStore:ObservableObject {
    static let shared=ColorLibraryStore()
    @Published private(set) var library=ColorLibrary()
    @Published var error:String?
    let directory:URL
    private let writer=DispatchQueue(label:"Cookies.ColorLibrary",qos:.utility)
    private var pending:DispatchWorkItem?
    private var readable=true
    private var choosingDepth=0
    private var replacing=false
    private(set) var revision=0
    var isChoosing:Bool{choosingDepth>0}
    func beginChoice(){choosingDepth+=1}
    func endChoice(){choosingDepth=max(0,choosingDepth-1)}
    init(directory:URL?=nil){self.directory=directory ?? AppStorageManager.root.appendingPathComponent("Colors");reload()}
    var file:URL{directory.appendingPathComponent("colors.json")}
    var recent:[StoredColor]{library.colors.sorted{$0.lastUsed>$1.lastUsed}}
    static func normalized(_ value:String)->String?{
        let hex=value.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"#",with:"").uppercased()
        guard hex.count==6,hex.allSatisfy({$0.isASCII && "0123456789ABCDEF".contains($0)}) else{return nil};return hex
    }
    func reload(){pending?.cancel();pending=nil;writer.sync{};replacing=false;choosingDepth=0;do{try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);library=try RecoveryFile.read(ColorLibrary.self,at:file)?.value ?? ColorLibrary();readable=true;error=nil}catch{readable=false;self.error=error.localizedDescription}}
    func record(_ value:String){
        guard readable,!replacing,let hex=Self.normalized(value) else{return}
        if let index=library.colors.firstIndex(where:{$0.hex==hex}){library.colors[index].lastUsed=Date()}else{library.colors.append(StoredColor(hex:hex,lastUsed:Date()))}
        schedule()
    }
    func favorite(_ hex:String){if !library.colors.contains(where:{$0.hex==hex}){record(hex)};guard let i=library.colors.firstIndex(where:{$0.hex==hex}) else{return};library.colors[i].favorite.toggle();schedule()}
    @discardableResult func createGroup(_ title:String)->UUID?{let title=title.trimmingCharacters(in:.whitespacesAndNewlines);guard readable,!title.isEmpty else{return nil};let group=ColorGroup(title:title);library.groups.append(group);schedule();return group.id}
    func renameGroup(_ id:UUID,_ title:String){guard readable,let i=library.groups.firstIndex(where:{$0.id==id}),!title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return};library.groups[i].title=title.trimmingCharacters(in:.whitespacesAndNewlines);schedule()}
    func removeGroup(_ id:UUID){library.groups.removeAll{$0.id==id};for i in library.colors.indices{library.colors[i].groups.removeAll{$0==id}};schedule()}
    func toggleGroup(_ hex:String,_ id:UUID){guard library.groups.contains(where:{$0.id==id}),let i=library.colors.firstIndex(where:{$0.hex==hex}) else{return};if library.colors[i].groups.contains(id){library.colors[i].groups.removeAll{$0==id}}else{library.colors[i].groups.append(id)};schedule()}
    private func schedule(){guard readable,!replacing else{return};pending?.cancel();let snapshot=library,url=file;let work=DispatchWorkItem{do{try RecoveryFile.write(snapshot,at:url)}catch{let message=error.localizedDescription;Task{@MainActor [weak self] in self?.error=message}}};pending=work;writer.asyncAfter(deadline:.now()+0.3,execute:work)}
    func discardPendingWrites(){revision+=1;replacing=true;pending?.cancel();pending=nil;writer.sync{}}
    func flushIfNeeded()throws{if pending != nil{try flush()}}
    func flush()throws{guard !replacing else{return};guard readable else{throw ImageFailure.message("تعذر قراءة مكتبة الألوان؛ احتُفظ ببياناتها")};pending?.cancel();pending=nil;let snapshot=library,url=file;try writer.sync{try RecoveryFile.write(snapshot,at:url)}}
}
