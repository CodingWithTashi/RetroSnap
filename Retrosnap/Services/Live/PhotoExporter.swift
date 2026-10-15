import AVFoundation
import CoreImage
import CoreLocation
import Foundation
import ImageIO
import Observation
import os
import Photos
import SwiftUI

/// Bakes photos and clips for leaving the app: the original through the look, with its stamp and edits,
/// as a full-size JPEG or movie.
@Observable
final class PhotoExporter: PhotoExporting {
    private static let log = Logger.retroSnap("export")
    private nonisolated static let quality = 0.92

    private(set) var progress: [Photo.ID: Double] = [:]

    @ObservationIgnored private let folder: PhotoLibraryFolder
    @ObservationIgnored private let renderer: LookRenderer?
    @ObservationIgnored private let clock: any DateProviding
    @ObservationIgnored private let dayLabeler: DayLabeler

    /// - Parameter renderer: Nil when the look's shaders could not be loaded; nothing can be baked then.
    init(folder: PhotoLibraryFolder, renderer: LookRenderer?, clock: any DateProviding) {
        self.folder = folder
        self.renderer = renderer
        self.clock = clock
        dayLabeler = DayLabeler(clock: clock)
    }

    // MARK: Photos library

    func saveToPhotos(_ photo: Photo, completion: @escaping @MainActor (Bool) -> Void) {
        Task {
            completion(await addToPhotos(photo))
        }
    }

    /// Whether the baked photo or clip is now in the Photos library.
    private func addToPhotos(_ photo: Photo) async -> Bool {
        do {
            if photo.isVideo {
                guard let movie = await bakeClip(photo) else { return false }
                // Photos moves the movie into the library; if it does not, the bake is not left behind.
                defer { try? FileManager.default.removeItem(at: movie) }
                let location = photo.location.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    request.addResource(with: .video, fileURL: movie, options: options)
                    request.creationDate = photo.capturedAt
                    request.location = location
                }
            } else {
                guard let picture = await bake(photo) else { return false }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: picture, options: nil)
                }
            }
            return true
        } catch {
            Self.log.error("A shot could not be added to Photos: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Files to hand out

    func export(_ photo: Photo, completion: @escaping @MainActor (URL?) -> Void) {
        Task {
            completion(await file(for: photo))
        }
    }

    /// The baked photo or clip as a file in the temporary folder, named for when it was taken.
    func file(for photo: Photo) async -> URL? {
        let name = "RetroSnap \(Self.fileDate.string(from: photo.capturedAt))"
        guard photo.isVideo else {
            guard let picture = await bake(photo) else { return nil }
            return temporaryFile(named: "\(name).jpg", holding: picture)
        }
        guard let movie = await bakeClip(photo) else { return nil }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).mov")
        do {
            try? FileManager.default.removeItem(at: file)
            try FileManager.default.moveItem(at: movie, to: file)
            return file
        } catch {
            Self.log.error("A clip could not be written out: \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes a baked picture into the temporary folder under this name, for the share sheet or the printer.
    private func temporaryFile(named name: String, holding picture: Data) -> URL? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try picture.write(to: file, options: .atomic)
            return file
        } catch {
            Self.log.error("A picture could not be written out: \(error.localizedDescription)")
            return nil
        }
    }

    /// "2026-10-11 16.12.00": readable in a file name, and it sorts by time.
    private static let fileDate = PhotoMetadata.formatter("yyyy-MM-dd HH.mm.ss")

    // MARK: Collages

    func makeCollage(_ collage: Collage, completion: @escaping @MainActor (Photo?) -> Void) {
        Task {
            completion(await collagePhoto(collage))
        }
    }

    func exportCollage(_ collage: Collage, completion: @escaping @MainActor (URL?) -> Void) {
        Task {
            completion(await collageFile(collage))
        }
    }

    /// The collage as a JPEG in the temporary folder, for sharing without saving it.
    private func collageFile(_ collage: Collage) async -> URL? {
        guard let picture = await collagePicture(collage) else { return nil }
        return temporaryFile(named: "RetroSnap collage \(Self.fileDate.string(from: clock.now)).jpg", holding: picture)
    }

    /// The collage filed in the library as a finished picture: shown as it is, with no look on top.
    func collagePhoto(_ collage: Collage) async -> Photo? {
        guard let picture = await collagePicture(collage) else { return nil }
        let id = UUID().uuidString
        do {
            let image = try await folder.storeConcurrently(original: picture, id: id, fileExtension: "jpg")
            // A collage has no camera of its own; with the effect at zero none is drawn.
            return Photo(
                id: id, image: image, camera: .film, capturedAt: clock.now, isJustCaptured: true,
                adjustments: .original, isCollage: true
            )
        } catch {
            Self.log.error("A collage could not be filed: \(error.localizedDescription)")
            return nil
        }
    }

    /// The collage as one JPEG: every photo with its own look and edits in its cell, on the frame's colour.
    func collagePicture(_ collage: Collage) async -> Data? {
        guard let renderer else { return nil }
        let layout = CollageLayout(template: collage.template, border: collage.border)
        var cells: [CollageCell] = []
        for (photo, cell) in zip(collage.photos, layout.photoCells) {
            guard let original = await original(of: photo.image) else { return nil }
            let model = LookRenderModel(camera: photo.camera, adjustments: photo.adjustments, framed: false, stampEnabled: false)
            cells.append(CollageCell(original: original, model: model, frame: cell))
        }
        guard cells.count == collage.template.photoCount else { return nil }
        return await Self.encodeCollage(cells, frameSize: layout.frameSize, paper: CIColor(hex: collage.border.hex), with: renderer)
    }

    /// One photo's place in a collage: its picture, its look, and its cell in points from the top-left corner.
    private nonisolated struct CollageCell: Sendable {
        let original: CIImage
        let model: LookRenderModel
        let frame: CGRect
    }

    @concurrent
    private nonisolated static func encodeCollage(
        _ cells: [CollageCell], frameSize: CGSize, paper: CIColor, with renderer: LookRenderer
    ) async -> Data? {
        let scale = CollageLayout.pixelsPerPoint
        let canvas = CGRect(x: 0, y: 0, width: (frameSize.width * scale).rounded(), height: (frameSize.height * scale).rounded())
        var picture = CIImage(color: paper).cropped(to: canvas)
        for cell in cells {
            // The cell in pixels, counted from the bottom as Core Image does.
            let box = CGRect(
                x: (cell.frame.minX * scale).rounded(), y: (canvas.height - cell.frame.maxY * scale).rounded(),
                width: (cell.frame.width * scale).rounded(), height: (cell.frame.height * scale).rounded()
            )
            // The photo fills its cell from the centre, as `scaledToFill` does on screen.
            let source = cell.original.extent
            let fill = max(box.width / source.width, box.height / source.height)
            let filled = cell.original
                .transformed(by: CGAffineTransform(translationX: -source.midX, y: -source.midY))
                .transformed(by: CGAffineTransform(scaleX: fill, y: fill))
                .transformed(by: CGAffineTransform(translationX: box.width / 2, y: box.height / 2))
                .cropped(to: CGRect(origin: .zero, size: box.size))
            let looked = renderer.render(filled, model: cell.model, scale: scale)
                .transformed(by: CGAffineTransform(translationX: box.minX, y: box.minY))
            picture = looked.composited(over: picture)
        }
        return renderer.jpeg(picture.cropped(to: canvas), quality: quality)
    }

    // MARK: Prints

    func exportPrint(_ job: PrintJob, completion: @escaping @MainActor (URL?) -> Void) {
        Task {
            completion(await printFile(for: job))
        }
    }

    /// The print as a JPEG in the temporary folder: what the Print screen previews, on white paper.
    func printFile(for job: PrintJob) async -> URL? {
        let photo = job.photo
        guard let renderer, let original = await original(of: photo.image) else { return nil }
        let model = LookRenderModel(camera: photo.camera, adjustments: photo.adjustments, framed: false, stampEnabled: true)
        let layout = BakeLayout(
            source: original.extent.size, paper: job.size.paperSize, border: job.hasBorder ? job.size.borderWidth : 0
        )
        let stamp = BakeArtwork.stamp(dayLabeler.stamp(for: photo.stampDate), kind: model.stamp, layout: layout)
        guard let picture = await Self.encodePicture(
            original, model: model, layout: layout, stamp: stamp, artwork: nil, paper: .white, metadata: [:], with: renderer
        ) else { return nil }
        return temporaryFile(named: "RetroSnap print \(photo.id).jpg", holding: picture)
    }

    // MARK: Baking

    /// The photo as it leaves the app, or nil when its original cannot be read.
    func bake(_ photo: Photo) async -> Data? {
        guard let renderer, let original = await original(of: photo.image) else { return nil }
        let model = LookRenderModel(camera: photo.camera, adjustments: photo.adjustments, framed: true, stampEnabled: true)
        let layout = BakeLayout(source: original.extent.size, frame: model.frame)
        let stamp = BakeArtwork.stamp(dayLabeler.stamp(for: photo.stampDate), kind: model.stamp, layout: layout)
        let artwork = BakeArtwork.frame(
            model.frame, layout: layout, photoAspect: original.extent.width / original.extent.height,
            design: FrameDesign.forPhoto(id: photo.id)
        )
        let metadata = PhotoMetadata.properties(
            original: original.properties, capturedAt: photo.capturedAt, location: photo.location
        )
        return await Self.encodePicture(
            original, model: model, layout: layout, stamp: stamp, artwork: artwork,
            paper: CIColor(hex: model.paperHex), metadata: metadata, with: renderer
        )
    }

    /// The clip as it leaves the app: every frame through the look and on its camera's canvas, as a photo is
    /// baked, in a movie in the temporary folder.
    /// Nil when it has no movie or the movie cannot be read. `progress` follows the bake while it runs.
    func bakeClip(_ photo: Photo) async -> URL? {
        guard let renderer, let videoFile = photo.videoFile else { return nil }
        let asset = AVURLAsset(url: folder.url(for: videoFile))
        let model = LookRenderModel(camera: photo.camera, adjustments: photo.adjustments, framed: true, stampEnabled: true)
        progress[photo.id] = 0
        defer { progress[photo.id] = nil }
        do {
            guard let recorded = try await asset.uprightVideoSize() else { return nil }
            // The canvas gets no more pixels than the clip has, so the movie bakes about as fast and is about as big as
            // the recording: a slide mount keeping every pixel of a 1080p clip would be 11 megapixels, more than H.264
            // takes. The frames are made smaller first, then laid out as a photo is.
            let shrink = Self.clipShrink(recorded, frame: model.frame)
            let size = CGSize(width: (recorded.width * shrink).rounded(), height: (recorded.height * shrink).rounded())
            let layout = BakeLayout(source: size, frame: model.frame)
            let stamp = BakeArtwork.stamp(dayLabeler.stamp(for: photo.stampDate), kind: model.stamp, layout: layout)
            let artwork = BakeArtwork.frame(
                model.frame, layout: layout, photoAspect: size.width / size.height,
                design: FrameDesign.forPhoto(id: photo.id)
            )
            let paper = CIColor(hex: model.paperHex)
            // Video is encoded in pairs of pixels: a canvas an odd number of pixels across loses its last column or row.
            let movieFrame = CGRect(
                x: 0, y: 0,
                width: (layout.canvas.width / 2).rounded(.down) * 2, height: (layout.canvas.height / 2).rounded(.down) * 2
            )

            let composition = try await AVMutableVideoComposition.videoComposition(with: asset) { request in
                var frame = request.sourceImage
                if shrink < 1 {
                    let scale = size.height / recorded.height
                    frame = frame.clampedToExtent()
                        .applyingFilter("CILanczosScaleTransform", parameters: [
                            kCIInputScaleKey: scale, kCIInputAspectRatioKey: size.width / recorded.width / scale,
                        ])
                        .cropped(to: CGRect(origin: .zero, size: size))
                }
                let picture = renderer.picture(
                    from: frame, model: model, layout: layout, stamp: stamp, paper: paper, artwork: artwork
                )
                request.finish(with: picture.cropped(to: movieFrame), context: renderer.context)
            }
            composition.renderSize = movieFrame.size
            // A file of its own for every bake: the same clip can be baked for Photos and for sharing at once.
            let movie = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-baked.mov")
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                return nil
            }
            session.videoComposition = composition
            session.outputURL = movie
            session.outputFileType = .mov
            session.metadata = PhotoMetadata.items(capturedAt: photo.capturedAt, location: photo.location)

            let watcher = Task { [weak self] in
                while !Task.isCancelled {
                    self?.progress[photo.id] = Double(session.progress)
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            defer { watcher.cancel() }
            await session.export()
            guard session.status == .completed else {
                Self.log.error("A clip could not be baked: \(session.error?.localizedDescription ?? "unknown")")
                try? FileManager.default.removeItem(at: movie)
                return nil
            }
            return movie
        } catch {
            Self.log.error("A clip could not be baked: \(error.localizedDescription)")
            return nil
        }
    }

    /// How much smaller a clip's frames are made so that its canvas has no more pixels than the clip, but for
    /// rounding: 1 when it fits.
    nonisolated static func clipShrink(_ size: CGSize, frame: LookFrame?) -> CGFloat {
        let canvas = BakeLayout(source: size, frame: frame).canvas
        return min(1, (size.width * size.height / (canvas.width * canvas.height)).squareRoot())
    }

    /// The untouched picture, upright.
    private func original(of image: PhotoImage) async -> CIImage? {
        switch image {
        case .sample(let sample):
            return UIImage(named: sample.full)?.cgImage.map { CIImage(cgImage: $0) }
        case .file(let full, _):
            return await Self.picture(at: folder.url(for: full))
        case .live:
            return nil
        }
    }

    /// Opening a photo's file reads and decodes part of it: some 30ms on a phone, so not on the main actor.
    @concurrent
    private nonisolated static func picture(at url: URL) async -> CIImage? {
        CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
    }

    @concurrent
    private nonisolated static func encodePicture(
        _ original: CIImage, model: LookRenderModel, layout: BakeLayout, stamp: CIImage?, artwork: CIImage?,
        paper: CIColor, metadata: [String: Any], with renderer: LookRenderer
    ) async -> Data? {
        let picture = renderer.picture(from: original, model: model, layout: layout, stamp: stamp, paper: paper, artwork: artwork)
        return renderer.jpeg(picture.settingProperties(metadata), quality: quality)
    }
}
