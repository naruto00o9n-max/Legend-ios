import Foundation

struct ReaderViewport:Codable,Equatable {var x:Double;var y:Double;var zoom:Double}
enum ReaderBookmark {
    static func index(chapter:UUID,count:Int)->Int{min(max(0,count-1),max(0,UserDefaults.standard.integer(forKey:"reader-page-"+chapter.uuidString)))}
    static func save(index:Int,chapter:UUID){UserDefaults.standard.set(index,forKey:"reader-page-"+chapter.uuidString)}
    static func viewport(page:UUID)->ReaderViewport?{guard let data=UserDefaults.standard.data(forKey:"reader-viewport-"+page.uuidString) else{return nil};return try? JSONDecoder().decode(ReaderViewport.self,from:data)}
    static func save(_ value:ReaderViewport,page:UUID){guard value.x.isFinite,value.y.isFinite,value.zoom.isFinite,value.zoom>0 else{return};UserDefaults.standard.set(try? JSONEncoder().encode(value),forKey:"reader-viewport-"+page.uuidString)}
}
