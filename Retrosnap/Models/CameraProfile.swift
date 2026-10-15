import Foundation

/// What the camera chooser shows for one camera: its card, chip and strip entry.
nonisolated struct CameraProfile: Hashable, Sendable {
    let name: String
    let badge: String
    let summary: String
    /// Accent used only on this camera's card bar, badge and chip ring.
    let accentHex: UInt32
    /// `color-mix(in oklab, accent 14%, #1B1916)` from the carousel cards, precomputed.
    let cardTintHex: UInt32
    let sample: SampleImage
}
