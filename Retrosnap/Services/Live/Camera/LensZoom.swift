import Foundation

/// How a camera's own zoom numbers map onto the ones the screen shows. A camera made of several lenses
/// counts from its widest one, so on a phone with an ultra-wide the main lens sits at 2 and is shown as 1×.
nonisolated struct LensZoom: Hashable, Sendable {
    /// The furthest the app zooms in, as shown. Past this the picture is only being enlarged.
    static let furthest = 10.0

    /// A shown number is the camera's own times this.
    let multiplier: Double
    /// What the camera can do, as shown.
    let range: ClosedRange<Double>
    /// One stop where each lens starts, and 2×, as shown.
    let stops: [Double]

    /// - Parameters:
    ///   - limits: The camera's own zoom range.
    ///   - switchOvers: The camera's own numbers at which it changes to its next lens; none for a single lens.
    ///   - mainLens: Which of its lenses, counted from the widest, is the main one.
    init(limits: ClosedRange<Double>, switchOvers: [Double], mainLens: Int) {
        let lensStarts = [limits.lowerBound] + switchOvers
        let mainStart = lensStarts.indices.contains(mainLens) ? lensStarts[mainLens] : limits.lowerBound
        let multiplier = 1 / mainStart
        let nearest = limits.lowerBound * multiplier
        let range = nearest...max(nearest, min(limits.upperBound * multiplier, Self.furthest))

        var stops: [Double] = []
        for stop in (lensStarts.map { $0 * multiplier } + [2]).sorted() where range.contains(stop) {
            // Two stops a hair apart would be one step that seems to do nothing.
            if let last = stops.last, stop - last <= last * CameraZoom.snapTolerance { continue }
            stops.append(stop)
        }
        self.multiplier = multiplier
        self.range = range
        self.stops = stops
    }

    /// The camera's own number for a shown one, kept inside what it can do.
    func cameraFactor(showing factor: Double) -> Double {
        min(max(factor, range.lowerBound), range.upperBound) / multiplier
    }

    /// What the screen is told while the camera sits at its own `cameraFactor`.
    func zoom(atCameraFactor cameraFactor: Double) -> CameraZoom {
        let shown = min(max(cameraFactor * multiplier, range.lowerBound), range.upperBound)
        return CameraZoom(factor: shown, range: range, stops: stops)
    }
}
