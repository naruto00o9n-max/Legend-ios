import Foundation

enum DialogueSequence {
    /// Resume after the latest use, then wrap around to skipped dialogue.
    static func resume(_ chapter:DialogueChapter,cursor:UUID?=nil)->DialogueBubble?{
        if let cursor,let bubble=chapter.bubbles.first(where:{$0.id==cursor && !$0.noPaste && !$0.used}){return bubble}
        let last=chapter.bubbles.enumerated().filter{!$0.element.noPaste && $0.element.used}.max{($0.element.usedAt ?? .distantPast)<($1.element.usedAt ?? .distantPast)}?.offset
        if let last,let next=chapter.bubbles.dropFirst(last+1).first(where:{!$0.noPaste && !$0.used}){return next}
        return chapter.pasteable.first{!$0.used}
    }
    static func scrollDestination(_ chapter:DialogueChapter,preferences:TyperPanelPreferences)->UUID?{
        if let next=resume(chapter,cursor:preferences.cursor(in:chapter.id)),preferences.matches(next){return next.id}
        let visible=chapter.bubbles.filter{!$0.noPaste && preferences.matches($0)}
        if preferences.filter == .used{return visible.max{($0.usedAt ?? .distantPast)<($1.usedAt ?? .distantPast)}?.id}
        return visible.first?.id ?? chapter.bubbles.first(where:preferences.matches)?.id
    }
    static func next(_ chapter:DialogueChapter,from cursor:UUID?,count:Int)->[DialogueBubble]{
        let start=cursor.flatMap{id in chapter.bubbles.firstIndex{$0.id==id}} ?? 0
        return Array(chapter.bubbles.dropFirst(start).filter{!$0.noPaste && !$0.used}.prefix(max(0,count)))
    }
}
