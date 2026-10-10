import Foundation

enum TextRanges {
    static func replacement(_ source:String,range:NSRange,with value:String,spans:[TextRun])->(String,[TextRun],NSRange){
        let text=source as NSString,start=min(text.length,max(0,range.location)),length=min(max(0,range.length),text.length-start),safe=NSRange(location:start,length:length)
        let next=text.replacingCharacters(in:safe,with:value),inserted=value.utf16.count,end=start+length,delta=inserted-length
        let adjusted=spans.compactMap{run->TextRun? in var result=run
            if run.end<=start{return run}
            if run.start>=end{result.start+=delta;result.end+=delta}
            else if length==inserted{return run}
            else{result.start=run.start<=start ? run.start:start;result.end=run.end>=end ? run.end+delta:start+inserted}
            result.start=max(0,min(next.utf16.count,result.start));result.end=max(result.start,min(next.utf16.count,result.end));return result.end>result.start ? result:nil
        }
        return (next,adjusted,NSRange(location:start+inserted,length:0))
    }
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
