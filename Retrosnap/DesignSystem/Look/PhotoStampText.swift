import Foundation

/// The text burned into a photo: the orange date for film-style cameras, the tape overlay for the camcorder.
nonisolated struct PhotoStampText: Hashable, Sendable {
    let date: String
    let tapeDate: String
    let tapeTime: String
}
