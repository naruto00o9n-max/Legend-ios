import Foundation

/// UUIDs isolate temporary work in directories; the user-visible leaf keeps
/// the project's name in Share, Files, Photos and Drive.
enum ExportNames {
    static let extensions:Set<String>=["png","jpg","jpeg","webp","gif","tif","tiff","heic","heif","avif","psd","cookies"]
    static func stem(_ title:String)->String {
        var name=String(title.unicodeScalars.filter{!CharacterSet.controlCharacters.contains($0)})
            .replacingOccurrences(of:"/",with:"-").replacingOccurrences(of:"\\",with:"-").replacingOccurrences(of:":",with:"-")
            .trimmingCharacters(in:.whitespacesAndNewlines)
        let suffix=(name as NSString).pathExtension
        if extensions.contains(suffix.lowercased()){name=(name as NSString).deletingPathExtension}
        name=name.trimmingCharacters(in:CharacterSet(charactersIn:". "))
        while name.utf8.count>210{name.removeLast()}
        return name.isEmpty ? "صورة":name
    }
    static func temporary(_ title:String,extension suffix:String)throws->URL {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("Cookies-Exports",isDirectory:true).appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        return folder.appendingPathComponent(stem(title)).appendingPathExtension(suffix)
    }
    static func unique(_ title:String,extension suffix:String,in folder:URL,used:inout Set<String>)->URL {
        let name=stem(title);var candidate=name+"."+suffix,index=2
        while !used.insert(candidate.precomposedStringWithCanonicalMapping.lowercased()).inserted{candidate="\(name) (\(index)).\(suffix)";index+=1}
        return folder.appendingPathComponent(candidate)
    }
}
