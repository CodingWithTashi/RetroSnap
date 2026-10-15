import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Where the library lives on disk: one folder holding the index and every photo's files side by side.
nonisolated struct PhotoLibraryFolder: Hashable, Sendable {
    static let indexFileName = "library.json"
    /// The longest side of a grid thumbnail, in pixels: three grid columns at 3x with room to spare.
    static let thumbnailPixelSize = 640

    let url: URL

    var indexURL: URL {
        url(for: Self.indexFileName)
    }

    func url(for fileName: String) -> URL {
        url.appendingPathComponent(fileName)
    }

    /// Files a shot: the original exactly as it was captured, and a small upright copy beside it for the grid.
    @discardableResult
    func store(original: Data, id: Photo.ID, fileExtension: String) throws -> PhotoImage {
        let full = "\(id).\(fileExtension)"
        let thumbnail = "\(id)-thumb.jpg"
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try original.write(to: url(for: full), options: .atomic)
        do {
            try Self.thumbnail(of: original).write(to: url(for: thumbnail), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: url(for: full))
            throw error
        }
        return .file(full: full, thumbnail: thumbnail)
    }

    /// `store`, away from the main actor: writing the original and decoding it for the thumbnail take a moment.
    @concurrent
    func storeConcurrently(original: Data, id: Photo.ID, fileExtension: String) async throws -> PhotoImage {
        try store(original: original, id: id, fileExtension: fileExtension)
    }

    /// Files a recording: the movie itself, and its first frame as the picture shown for it, with a thumbnail.
    /// The recording is moved, not copied.
    @concurrent
    @discardableResult
    func storeClip(movieAt recording: URL, id: Photo.ID) async throws -> (poster: PhotoImage, videoFile: String) {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: recording))
        generator.appliesPreferredTrackTransform = true
        let firstFrame = try await generator.image(at: .zero).image
        let poster = try store(original: Self.jpeg(firstFrame, quality: 0.9), id: id, fileExtension: "jpg")

        let videoFile = "\(id).mov"
        do {
            try FileManager.default.moveItem(at: recording, to: url(for: videoFile))
        } catch {
            removeFiles(named: poster.fileNames)
            throw error
        }
        return (poster, videoFile)
    }

    /// Deletes these files from the folder; one that is already gone is skipped.
    func removeFiles(named names: some Sequence<String>) {
        for name in names {
            try? FileManager.default.removeItem(at: url(for: name))
        }
    }

    private static func thumbnail(of original: Data) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailPixelSize,
        ]
        guard let source = CGImageSourceCreateWithData(original as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { throw CocoaError(.fileReadCorruptFile) }
        return try jpeg(image, quality: 0.8)
    }

    private static func jpeg(_ image: CGImage, quality: Double) throws -> Data {
        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return encoded as Data
    }

    /// The app's own library, inside Application Support.
    static var standard: PhotoLibraryFolder {
        PhotoLibraryFolder(url: URL.applicationSupportDirectory.appendingPathComponent("Library", isDirectory: true))
    }
}
