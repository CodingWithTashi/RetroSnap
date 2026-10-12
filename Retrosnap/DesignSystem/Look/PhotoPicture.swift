import SwiftUI

/// A picture's own pixels with no look applied, filling whatever frame it is given.
/// Bundled pictures draw at once, library photos appear when their file has been decoded,
/// and a moving picture follows its feed frame by frame.
struct PhotoPicture: View {
    let image: PhotoImage
    var usesThumbnail = false
    @Environment(\.photoImageLoader) private var loader
    @Environment(\.liveFrames) private var feed
    @State private var loaded: (fileName: String, pixels: CGImage)?

    var body: some View {
        switch image {
        case .sample(let sample):
            Image(usesThumbnail ? sample.thumbnail : sample.full)
                .resizable()
                .scaledToFill()
        case .file(let full, let thumbnail):
            let fileName = usesThumbnail ? thumbnail : full
            ZStack {
                if let pixels = pixels(for: fileName) {
                    Image(decorative: pixels, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .task(id: fileName) {
                guard let pixels = await loader?.image(named: fileName) else { return }
                loaded = (fileName, pixels)
            }
        case .live:
            ZStack {
                if let frame = feed?.frame {
                    Image(decorative: frame, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
        }
    }

    /// What this view loaded itself, or what an earlier one already decoded.
    private func pixels(for fileName: String) -> CGImage? {
        if let loaded, loaded.fileName == fileName {
            return loaded.pixels
        }
        return loader?.cached(fileName)
    }
}

private nonisolated struct PhotoImageLoaderKey: EnvironmentKey {
    static let defaultValue: PhotoImageLoader? = nil
}

extension EnvironmentValues {
    /// Decodes library photos for the views below; nil while every picture comes from the asset catalog.
    nonisolated var photoImageLoader: PhotoImageLoader? {
        get { self[PhotoImageLoaderKey.self] }
        set { self[PhotoImageLoaderKey.self] = newValue }
    }
}

private nonisolated struct LiveFramesKey: EnvironmentKey {
    static let defaultValue: FrameFeed? = nil
}

extension EnvironmentValues {
    /// The frames a `.live` picture draws below this point: the camera's, or those of a clip being played.
    nonisolated var liveFrames: FrameFeed? {
        get { self[LiveFramesKey.self] }
        set { self[LiveFramesKey.self] = newValue }
    }
}
