import Foundation

enum DialogueSequence {
    static func next(_ chapter:DialogueChapter,from cursor:UUID?,count:Int)->[DialogueBubble]{
        let start=cursor.flatMap{id in chapter.bubbles.firstIndex{$0.id==id}} ?? 0
        return Array(chapter.bubbles.dropFirst(start).filter{!$0.noPaste && !$0.used}.prefix(max(0,count)))
    }
}
