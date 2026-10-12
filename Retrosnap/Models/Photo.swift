import Foundation

/// A shot in the library: a still, or a clip when it has a duration.
nonisolated struct Photo: Identifiable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    var image: SampleImage
    var camera: CameraStyle
    var capturedAt: Date
    /// Taken in this session; shown as "Just now" instead of its day.
    var isJustCaptured = false
    /// Length in seconds for a video, nil for a photo.
    var videoSeconds: Int?
    var adjustments = PhotoAdjustments.neutral

    var isVideo: Bool {
        videoSeconds != nil
    }

    /// Clip length as shown on thumbnails: "0:12".
    var videoDurationText: String? {
        videoSeconds.map { String(format: "%d:%02d", $0 / 60, $0 % 60) }
    }
}
