import Foundation

/// A picture in the asset catalog: the full-size asset and its grid thumbnail.
nonisolated struct SampleImage: Hashable, Sendable, Codable {
    let full: String
    let thumbnail: String

    /// One of the 3:4 stock photos, by its picsum id.
    static func photo(_ id: Int) -> SampleImage {
        SampleImage(full: "photo-\(id)", thumbnail: "photo-\(id)-thumb")
    }

    static let welcomeHero = SampleImage(full: "hero-welcome", thumbnail: "hero-welcome")

    /// Square crops used by the "How it works" cards.
    static func tile(_ id: Int) -> SampleImage {
        SampleImage(full: "tile-\(id)", thumbnail: "tile-\(id)")
    }
}
