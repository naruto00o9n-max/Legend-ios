import Foundation

/// Atomic current document plus one independently validated last good version.
enum RecoveryFile {
    struct Result<Value>{var value:Value;var recovered:Bool}
    static func backup(_ file:URL)->URL{file.deletingPathExtension().appendingPathExtension("previous.json")}
    static func read<Value:Codable>(_ type:Value.Type,at file:URL)throws->Result<Value>? {
        guard FileManager.default.fileExists(atPath:file.path) else{return nil}
        do{return Result(value:try JSONDecoder().decode(type,from:Data(contentsOf:file)),recovered:false)}
        catch {
            let original=error
            let damaged=file.deletingPathExtension().appendingPathExtension("damaged-\(UUID()).json")
            try FileManager.default.copyItem(at:file,to:damaged)
            guard let bytes=try? Data(contentsOf:backup(file)),let restored=try? JSONDecoder().decode(type,from:bytes) else{throw original}
            try bytes.write(to:file,options:.atomic)
            return Result(value:restored,recovered:true)
        }
    }
    static func write<Value:Codable>(_ value:Value,at file:URL)throws {
        let bytes=try JSONEncoder().encode(value)
        if let old=try? Data(contentsOf:file), (try? JSONDecoder().decode(Value.self,from:old)) != nil {
            try old.write(to:backup(file),options:.atomic)
        }
        try bytes.write(to:file,options:.atomic)
    }
}
