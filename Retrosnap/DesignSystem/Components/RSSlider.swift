import SwiftUI

/// A slider drawn to look the same on every iOS version: thin track, amber up to the thumb, white round thumb.
struct RSSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    var valueText: String = ""

    private let thumb: CGFloat = 28
    private let track: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let travel = max(1, proxy.size.width - thumb)
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let center = thumb / 2 + travel * fraction
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RSColor.toggleOff)
                    .frame(height: track)
                Capsule()
                    .fill(RSColor.amber)
                    .frame(width: max(track, center), height: track)
                Circle()
                    .fill(.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.12), radius: 6.5, y: 6)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 0.5)
                    .offset(x: center - thumb / 2)
            }
            .frame(height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let position = min(1, max(0, (drag.location.x - thumb / 2) / travel))
                        value = range.lowerBound + position * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: thumb)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            value = min(range.upperBound, max(range.lowerBound, value + (direction == .increment ? step : -step)))
        }
    }
}
