import Foundation

enum TextRanges {
    static func adjusted(_ spans:[TextRun],from old:String,to new:String)->[TextRun] {
        let a=Array(old.utf16),b=Array(new.utf16);var prefix=0,suffix=0
        while prefix<min(a.count,b.count),a[prefix]==b[prefix]{prefix+=1}
        while suffix<min(a.count-prefix,b.count-prefix),a[a.count-1-suffix]==b[b.count-1-suffix]{suffix+=1}
        let oldEnd=a.count-suffix,delta=b.count-a.count
        return spans.compactMap{run in var value=run
            if value.end<=prefix{return value}
            if value.start>=oldEnd{value.start+=delta;value.end+=delta}
            else{value.start=min(value.start,prefix);value.end=max(prefix,value.end+delta)}
            value.start=max(0,min(b.count,value.start));value.end=max(value.start,min(b.count,value.end));return value.end>value.start ? value:nil
        }
    }
}
