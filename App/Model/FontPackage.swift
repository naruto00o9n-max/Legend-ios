import Foundation
import CoreText
import UIKit
import ZIPFoundation

enum FontPackage {
    static func importFiles(_ candidates:[URL],directory:URL=Fonts.userDirectory)throws {
        guard !candidates.isEmpty,candidates.count<=200 else{throw ImageFailure.message("الحزمة يجب أن تحتوي من خط واحد إلى 200 خط")}
        for file in candidates{let size=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0;guard size>0,size<=16*1024*1024,let provider=CGDataProvider(url:file as CFURL),CGFont(provider) != nil else{throw ImageFailure.message("خط غير صالح: "+file.lastPathComponent)}}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let bundled=(Bundle.main.urls(forResourcesWithExtension:"ttf",subdirectory:"Fonts") ?? [])+(Bundle.main.urls(forResourcesWithExtension:"otf",subdirectory:"Fonts") ?? [])
        var added:[URL]=[]
        do{for file in candidates{
            if let installed=bundled.first(where:{$0.lastPathComponent==file.lastPathComponent}){guard try Data(contentsOf:installed)==Data(contentsOf:file) else{throw ImageFailure.message("اسم الخط يتعارض مع خط مثبت: "+file.lastPathComponent)};continue}
            let target=directory.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath:target.path){guard try Data(contentsOf:target)==Data(contentsOf:file) else{throw ImageFailure.message("اسم الخط يتعارض مع خط مستورد: "+file.lastPathComponent)};continue}
            try FileManager.default.copyItem(at:file,to:target);added.append(target)
            var registrationError:Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(target as CFURL,.process,&registrationError){
                let error=registrationError?.takeRetainedValue()
                guard error.map({CFErrorGetCode($0)==CTFontManagerError.alreadyRegistered.rawValue})==true else{throw ImageFailure.message("تعذر تسجيل "+file.lastPathComponent)}
            }
        }}catch{for file in added{CTFontManagerUnregisterFontsForURL(file as CFURL,.process,nil);try? FileManager.default.removeItem(at:file)};Fonts.register();throw error}
        Fonts.register()
    }
}
