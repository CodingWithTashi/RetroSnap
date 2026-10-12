import Foundation

/// Where a picture's pixels come from.
nonisolated enum PhotoImage: Hashable, Sendable, Codable {
    /// A picture shipped with the app.
    case sample(SampleImage)
    /// A shot in the library: its original and its grid thumbnail, by file name inside the library folder.
    case file(full: String, thumbnail: String)
    /// A moving picture, drawn frame by frame: what the camera sees right now, or a clip being played.
    case live

    /// The library files this picture owns.
    var fileNames: [String] {
        switch self {
        case .sample, .live: []
        case .file(let full, let thumbnail): [full, thumbnail]
        }
    }
}
