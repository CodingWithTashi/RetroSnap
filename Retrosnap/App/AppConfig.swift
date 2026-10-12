import Foundation

/// How the camera chip lets you pick a camera. The design explored both; the strip is the recommended one.
nonisolated enum CameraSelectorStyle: String, Hashable, Sendable {
    /// The strip that unfolds over the live preview (design 1a).
    case strip = "sheet"
    /// The full-screen card carousel (design 1b).
    case carousel
}

/// When the result screen is shown after a photo.
nonisolated enum CaptureReviewRule: String, Hashable, Sendable {
    /// After the first photo only, to teach where photos go.
    case first
    case always
    case never
}

nonisolated struct AppConfig: Hashable, Sendable {
    var selector = CameraSelectorStyle.strip
    var reviewRule = CaptureReviewRule.first
}
