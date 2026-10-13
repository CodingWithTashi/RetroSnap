import AVFoundation
import Foundation
import ImageIO
import Observation
import os
import PhotosUI
import UniformTypeIdentifiers

/// The system photo picker, with the pick copied into the library folder the way a shot is filed.
/// The picker needs no permission of its own: it runs out of process and hands over only what was chosen.
@Observable
final class PhotoImporter: NSObject, PhotoImporting, PHPickerViewControllerDelegate {
    private static let log = Logger.retroSnap("import")

    private(set) var isImporting = false

    @ObservationIgnored private let folder: PhotoLibraryFolder
    @ObservationIgnored private let loader: PhotoImageLoader
    @ObservationIgnored private let clock: any DateProviding
    @ObservationIgnored private var completion: (@MainActor (ImportOutcome) -> Void)?

    init(folder: PhotoLibraryFolder, loader: PhotoImageLoader, clock: any DateProviding) {
        self.folder = folder
        self.loader = loader
        self.clock = clock
    }

    func pick(completion: @escaping @MainActor (ImportOutcome) -> Void) {
        guard self.completion == nil, let presenter = UIApplication.shared.topViewController else {
            completion(.failed)
            return
        }
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 1
        // The picture as it is in Photos, edits included, in its own format: no transcoding to wait for.
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.completion = completion
        presenter.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else {
            finish(.cancelled)
            return
        }
        isImporting = true
        let id = UUID().uuidString
        let now = clock.now
        Task { [folder, loader] in
            let outcome = await Self.file(provider, in: folder, id: id, at: now)
            if case .imported(let draft) = outcome {
                // Decoded ahead of the screen that shows it, so the pick appears with no empty moment.
                await loader.prepareThumbnail(of: draft.image)
                if case .file(let full, _) = draft.image {
                    _ = await loader.image(named: full)
                }
            }
            isImporting = false
            finish(outcome)
        }
    }

    private func finish(_ outcome: ImportOutcome) {
        let completion = completion
        self.completion = nil
        completion?(outcome)
    }

    func discard(_ draft: Photo) {
        let urls = draft.fileNames.map(folder.url(for:))
        Task.detached {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: Filing the pick

    /// The pick copied into the library folder: a picture as it is with a thumbnail beside it, or a movie with
    /// its first frame as the picture shown for it. Off the main actor: the copy and the decode take a moment.
    @concurrent
    private nonisolated static func file(
        _ provider: NSItemProvider, in folder: PhotoLibraryFolder, id: Photo.ID, at now: Date
    ) async -> ImportOutcome {
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return await fileMovie(from: provider, in: folder, id: id, at: now)
        }
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
              let copy = await copy(from: provider, type: .image)
        else { return .failed }
        defer { try? FileManager.default.removeItem(at: copy) }
        do {
            let original = try Data(contentsOf: copy)
            let fileExtension = copy.pathExtension.isEmpty ? "jpg" : copy.pathExtension.lowercased()
            let image = try folder.store(original: original, id: id, fileExtension: fileExtension)
            return .imported(Photo(
                id: id, image: image, camera: .film, capturedAt: now, isJustCaptured: true,
                pixelSize: pixelSize(of: original)
            ))
        } catch {
            log.error("A picture could not be brought in: \(error.localizedDescription)")
            return .failed
        }
    }

    private nonisolated static func fileMovie(
        from provider: NSItemProvider, in folder: PhotoLibraryFolder, id: Photo.ID, at now: Date
    ) async -> ImportOutcome {
        guard let copy = await copy(from: provider, type: .movie) else { return .failed }
        do {
            let asset = AVURLAsset(url: copy)
            let seconds = try await asset.load(.duration).seconds
            var pixelSize: PixelSize?
            if let track = try await asset.loadTracks(withMediaType: .video).first {
                let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
                let upright = CGRect(origin: .zero, size: size).applying(transform).size
                pixelSize = PixelSize(width: Int(abs(upright.width).rounded()), height: Int(abs(upright.height).rounded()))
            }
            let filed = try await folder.storeClip(movieAt: copy, id: id)
            return .imported(Photo(
                id: id, image: filed.poster, camera: .film, capturedAt: now, isJustCaptured: true,
                videoSeconds: max(1, Int(seconds.rounded())), videoFile: filed.videoFile, pixelSize: pixelSize
            ))
        } catch {
            log.error("A clip could not be brought in: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: copy)
            return .failed
        }
    }

    /// The pick as a file of the app's own in the temporary folder. The picker's copy lives only inside its handler.
    private nonisolated static func copy(from provider: NSItemProvider, type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                guard let url else {
                    log.error("A pick could not be read: \(error?.localizedDescription ?? "no file")")
                    continuation.resume(returning: nil)
                    return
                }
                let copy = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(UUID().uuidString)-import.\(url.pathExtension)")
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    continuation.resume(returning: copy)
                } catch {
                    log.error("A pick could not be copied: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// The picture's size the way up it is shown, from its header alone.
    private nonisolated static func pixelSize(of picture: Data) -> PixelSize? {
        guard let source = CGImageSourceCreateWithData(picture as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
        let isSideways = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
        return isSideways ? PixelSize(width: height, height: width) : PixelSize(width: width, height: height)
    }
}
