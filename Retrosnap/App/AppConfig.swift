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

/// Where the Settings rows that leave the app lead. A row with nowhere to go is not shown.
nonisolated struct AppLinks: Hashable, Sendable {
    /// The privacy policy, on the web.
    var privacyPolicy: URL?
    /// A support page, or a `mailto:` address.
    var support: URL?

    /// What the released app opens: the privacy policy on the web, and a new email to support.
    static let released = AppLinks(
        privacyPolicy: URL(string: "https://kharagedition.github.io/privacy-policy/retro-snap.html"),
        support: URL(string: "mailto:tashi@kharagedition.com?subject=RetroSnap")
    )
}

nonisolated struct AppConfig: Hashable, Sendable {
    var selector = CameraSelectorStyle.strip
    var reviewRule = CaptureReviewRule.first
    var links = AppLinks.released
}
