import CoreGraphics
import Foundation
import ImageIO

/// Turns the library's files into pixels for the screen: decoded off the main actor, scaled down to what
/// a screen can show, and kept while memory allows.
final class PhotoImageLoader {
    /// The longest side of a decoded photo, in pixels.
    nonisolated static let maxPixelSize = 2048

    /// How much decoded picture the cache keeps: some sixteen full photos, or a long gallery of thumbnails.
    private nonisolated static let cacheLimit = 200 * 1024 * 1024

    private let folder: PhotoLibraryFolder
    private let cache = NSCache<NSString, CGImage>()
    /// Decodes under way. One photo is drawn by several views at once, and they share its decode.
    private var decoding: [String: Task<CGImage?, Never>] = [:]

    init(folder: PhotoLibraryFolder) {
        self.folder = folder
        cache.totalCostLimit = Self.cacheLimit
    }

    /// The picture if it has been decoded already, without waiting.
    func cached(_ fileName: String) -> CGImage? {
        cache.object(forKey: fileName as NSString)
    }

    func image(named fileName: String) async -> CGImage? {
        if let cached = cached(fileName) { return cached }
        if let underway = decoding[fileName] { return await underway.value }
        let url = folder.url(for: fileName)
        let decode = Task { await Self.decode(url) }
        decoding[fileName] = decode
        let image = await decode.value
        decoding[fileName] = nil
        if let image {
            cache.setObject(image, forKey: fileName as NSString, cost: image.bytesPerRow * image.height)
        }
        return image
    }

    /// Decodes a shot's thumbnail ahead of the view that will draw it, so that it appears with no empty moment.
    func prepareThumbnail(of image: PhotoImage) async {
        guard case .file(_, let thumbnail) = image else { return }
        _ = await self.image(named: thumbnail)
    }

    /// Upright, and no larger than `maxPixelSize` on its longest side.
    @concurrent
    private nonisolated static func decode(_ url: URL) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
