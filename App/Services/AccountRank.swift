import Foundation

/// Original RankManager's logarithmic progression, based only on real bubble
/// counts. Rank presentation does not grant membership, points, or privileges.
enum AccountRank {
    static let levels=["F-","F","F+","E-","E","E+","D-","D","D+","C-","C","C+","B-","B","B+","A-","A","A+","S-","S","S+","SS-","SS","SS+","SSS-","SSS","SSS+"]
    private static func index(_ bubbles:Int)->Int{max(0,min(26,Int(floor(log10(Double(max(100,bubbles))/100)*26/4))))}
    static func title(_ bubbles:Int)->String{bubbles<100 ? "متدرب":levels[index(bubbles)]}
    static func progress(_ bubbles:Int)->Int{
        if bubbles<100{return max(0,bubbles)}
        let i=index(bubbles);if i==26{return 100}
        let low=pow(10,Double(i)*4/26)*100,high=pow(10,Double(i+1)*4/26)*100
        return max(0,min(100,Int(floor((Double(bubbles)-low)/(high-low)*100))))
    }
}
