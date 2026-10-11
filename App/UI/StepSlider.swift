import SwiftUI

/// Continuous dragging plus exact single increments, using the same binding.
struct StepSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let onEditingChanged: (Bool) -> Void
    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        _value=value; self.range=range; self.step=step; self.onEditingChanged=onEditingChanged
    }
    private var increment: Double {
        if let step { return step }
        return range.upperBound-range.lowerBound <= 1 ? 0.01 : range.upperBound-range.lowerBound <= 8 ? 0.1 : 1
    }
    private func move(_ delta: Double) {
        onEditingChanged(true)
        value=min(range.upperBound,max(range.lowerBound,((value+delta)*1_000_000).rounded()/1_000_000))
        onEditingChanged(false)
    }
    var body: some View {
        HStack(spacing:8) {
            Button { move(-increment) } label: { Image(systemName:"minus").frame(width:30,height:30).background(.white.opacity(0.07),in:Circle()) }
                .buttonStyle(.plain).disabled(value<=range.lowerBound).accessibilityLabel("إنقاص القيمة").accessibilityValue(value.formatted())
            Slider(value:$value,in:range,onEditingChanged:onEditingChanged).tint(Palette.gold)
            Button { move(increment) } label: { Image(systemName:"plus").frame(width:30,height:30).background(.white.opacity(0.07),in:Circle()) }
                .buttonStyle(.plain).disabled(value>=range.upperBound).accessibilityLabel("زيادة القيمة").accessibilityValue(value.formatted())
        }.foregroundStyle(Palette.pale).environment(\.layoutDirection,.leftToRight)
    }
}
