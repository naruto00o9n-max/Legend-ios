import Foundation
import CoreText
import CoreGraphics

/// Android's reference TextPaint uses whole-pixel glyph advances. CoreText's
/// default fractional advances change padding and Kashida counts. This applies
/// the document pixel grid per glyph, not just to the final line width.
/// Hinting, fallback fonts and platform shaping may still differ; compare fixtures.
struct CoreTextMeasure {
    var font: CTFont

    func width(_ text: String, pixelAligned: Bool = true) -> Double {
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font
        ])
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        if !pixelAligned { return CTLineGetTypographicBounds(line, nil, nil, nil) }
        var width = 0.0
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            var advances = [CGSize](repeating: .zero, count: CTRunGetGlyphCount(run))
            CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
            width += advances.reduce(0.0) { $0 + Double($1.width.rounded()) }
        }
        return width
    }
}
