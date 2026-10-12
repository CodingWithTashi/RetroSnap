import Foundation

/// Where a shot was taken, as written into the saved photo's metadata.
nonisolated struct PhotoLocation: Hashable, Sendable, Codable {
    var latitude: Double
    var longitude: Double
    /// Metres above sea level, when the fix has it.
    var altitude: Double?
}
