import Foundation

/// The five edit sliders. Ranges match the Edit screen: 0...100 for effect and grain, -50...50 for the rest.
nonisolated struct PhotoAdjustments: Hashable, Sendable, Codable {
    var intensity = 100
    var grain = 50
    var exposure = 0
    var contrast = 0
    var warmth = 0

    static let neutral = PhotoAdjustments()

    /// What "hold to compare" shows: the photo with no look and no edits.
    static let original = PhotoAdjustments(intensity: 0, grain: 0)
}
