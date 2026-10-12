import SwiftUI

/// A CSS `linear-gradient(<angle>, …)`: 0deg points up, angles turn clockwise, and the gradient line is
/// long enough to reach the box's corners.
struct CSSLinearGradient: View {
    let degrees: Double
    let colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let radians = degrees * .pi / 180
            let dx = sin(radians), dy = -cos(radians)
            let length = abs(size.width * dx) + abs(size.height * dy)
            let half = CGSize(width: dx * length / 2, height: dy * length / 2)
            LinearGradient(
                colors: colors,
                startPoint: UnitPoint(x: 0.5 - half.width / max(size.width, 1), y: 0.5 - half.height / max(size.height, 1)),
                endPoint: UnitPoint(x: 0.5 + half.width / max(size.width, 1), y: 0.5 + half.height / max(size.height, 1))
            )
        }
    }
}
