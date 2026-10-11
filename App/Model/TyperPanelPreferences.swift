import Foundation

enum TyperBubbleFilter:String,Codable,CaseIterable,Identifiable {
    case all,unused,used
    var id:String{rawValue}
    var title:String{switch self{case .all:"الكل";case .unused:"المتبقية";case .used:"المستخدمة"}}
    func includes(_ bubble:DialogueBubble)->Bool{self == .all || (self == .used ? bubble.used:!bubble.used)}
}

/// Backed up with the Typer directory, independent from chapter content.
struct TyperPanelPreferences:Codable,Equatable {
    var filter=TyperBubbleFilter.all
    var query=""
    var uppercase=false
    var textFormat=""
    var overrideTag:UUID?
    var quickFont:String?
    var expanded=false
    var cursors:[String:UUID]=[:]
    init(){}
    private enum CodingKeys:String,CodingKey{case filter,query,uppercase,textFormat,overrideTag,quickFont,expanded,cursors}
    init(from decoder:Decoder)throws{
        let c=try decoder.container(keyedBy:CodingKeys.self)
        filter=(try? c.decode(TyperBubbleFilter.self,forKey:.filter)) ?? .all
        query=try c.decodeIfPresent(String.self,forKey:.query) ?? ""
        uppercase=try c.decodeIfPresent(Bool.self,forKey:.uppercase) ?? false
        textFormat=try c.decodeIfPresent(String.self,forKey:.textFormat) ?? ""
        overrideTag=try c.decodeIfPresent(UUID.self,forKey:.overrideTag)
        quickFont=try c.decodeIfPresent(String.self,forKey:.quickFont)
        expanded=try c.decodeIfPresent(Bool.self,forKey:.expanded) ?? false
        cursors=try c.decodeIfPresent([String:UUID].self,forKey:.cursors) ?? [:]
    }
    func cursor(in chapter:UUID)->UUID?{cursors[chapter.uuidString]}
    func matches(_ bubble:DialogueBubble)->Bool{filter.includes(bubble) && (query.isEmpty || bubble.text.localizedCaseInsensitiveContains(query))}
}
