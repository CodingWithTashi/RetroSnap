import Foundation

/// How far a lens can zoom and where it is now, in the numbers a camera shows:
/// 1 is the main lens, 0.5 the ultra-wide beside it.
nonisolated struct CameraZoom: Hashable, Sendable {
    /// How close to a stop, as a fraction of it, a pinch must come to land on it exactly.
    static let snapTolerance = 0.04

    /// A lens that cannot zoom.
    static let fixed = CameraZoom(factor: 1, range: 1...1, stops: [1])

    var factor: Double
    var range: ClosedRange<Double>
    /// The steps the zoom button goes through, lowest first: one for each lens, and 2×.
    var stops: [Double]

    /// "1×", "0.5×", "2.4×".
    var title: String {
        let tenths = (factor * 10).rounded() / 10
        return tenths == tenths.rounded() ? "\(Int(tenths))×" : String(format: "%.1f×", tenths)
    }

    /// The main lens's own view, with nothing cropped away and nothing added.
    var isAtRest: Bool {
        factor == 1
    }

    /// Where a tap on the zoom button goes: the next stop up, and from the last one round to the first.
    var nextStop: Double {
        stops.first { $0 > factor * (1 + Self.snapTolerance) } ?? stops.first ?? factor
    }

    func clamped(_ factor: Double) -> Double {
        min(max(factor, range.lowerBound), range.upperBound)
    }

    /// Where a pinch asking for `factor` ends up: inside the range, and on a stop it is all but on.
    func settled(_ factor: Double) -> Double {
        let factor = clamped(factor)
        return stops.first { abs(factor - $0) <= $0 * Self.snapTolerance } ?? factor
    }

    /// Whether zooming to `factor` from here reaches or passes a stop.
    func passesStop(goingTo factor: Double) -> Bool {
        let low = min(self.factor, factor)
        let high = max(self.factor, factor)
        return stops.contains { $0 != self.factor && low <= $0 && $0 <= high }
    }
}
