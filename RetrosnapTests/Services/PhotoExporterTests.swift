import AVFoundation
import CoreImage
import Foundation
import ImageIO
import Testing
@testable import Retrosnap

@MainActor
final class PhotoExporterTests {
    private let folder = PhotoLibraryFolder(
        url: FileManager.default.temporaryDirectory.appendingPathComponent("PhotoExporterTests-\(UUID().uuidString)")
    )
    private let clock = FixedClock.design
    private let renderer: LookRenderer
    private let exporter: PhotoExporter

    init() throws {
        renderer = try LookRenderer()
        exporter = PhotoExporter(folder: folder, renderer: renderer, clock: clock)
    }

    deinit {
        try? FileManager.default.removeItem(at: folder.url)
    }

    /// A shot filed in the library from a flat orange original.
    private func shot(
        _ camera: CameraStyle, width: Int = 300, height: Int = 400, orientation: CGImagePropertyOrientation = .up
    ) throws -> Photo {
        let id = UUID().uuidString
        let original = makeJPEG(width: width, height: height, orientation: orientation)
        let image = try folder.store(original: original, id: id, fileExtension: "jpg")
        return Photo(id: id, image: image, camera: camera, capturedAt: clock.now)
    }

    private func centre(of data: Data) throws -> Pixel {
        let image = try #require(CIImage(data: data))
        return renderer.context.pixel(of: image, x: Int(image.extent.width) / 2, y: Int(image.extent.height) / 2)
    }

    @Test func aBakedPhotoIsTheSizeOfItsOriginal() async throws {
        let baked = try #require(await exporter.bake(try shot(.film)))
        let picture = try #require(describe(baked))
        #expect(picture.width == 300)
        #expect(picture.height == 400)
    }

    @Test func theLookIsDrawnIntoTheFile() async throws {
        var photo = try shot(.film)
        photo.adjustments = PhotoAdjustments(intensity: 100, grain: 0)
        let baked = try #require(await exporter.bake(photo))
        // The film chain and tint on the fixtures' orange; JPEG costs a level or two.
        #expect(try centre(of: baked).isClose(to: Pixel(red: 237, green: 135, blue: 47), tolerance: 4))
    }

    @Test func editsAreBakedInToo() async throws {
        var photo = try shot(.film)
        photo.adjustments = .original
        let plain = try #require(await exporter.bake(photo))
        let untouched = try centre(of: plain)
        #expect(untouched.isClose(to: Pixel(red: 200, green: 120, blue: 40), tolerance: 4))

        photo.adjustments = PhotoAdjustments(intensity: 0, grain: 0, exposure: 20)
        let edited = try #require(await exporter.bake(photo))
        #expect(try centre(of: edited).red > untouched.red + 20)
    }

    @Test func aSidewaysOriginalIsBakedUprightAndSaysSo() async throws {
        let baked = try #require(await exporter.bake(try shot(.film, width: 400, height: 300, orientation: .right)))
        let picture = try #require(describe(baked))
        #expect(picture.width == 300)
        #expect(picture.height == 400)
        #expect((picture.properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
    }

    @Test func theDateItWasTakenIsWrittenIntoTheFile() async throws {
        let baked = try #require(await exporter.bake(try shot(.digicam)))
        let exif = try #require(describe(baked)?.properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:10:11 16:12:00")
    }

    @Test func thePlaceItWasTakenIsWrittenIntoTheFile() async throws {
        var photo = try shot(.film)
        photo.location = PhotoLocation(latitude: 27.7172, longitude: 85.324, altitude: 1400)
        let baked = try #require(await exporter.bake(photo))
        let gps = try #require(describe(baked)?.properties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        let latitude = try #require(gps[kCGImagePropertyGPSLatitude] as? Double)
        let longitude = try #require(gps[kCGImagePropertyGPSLongitude] as? Double)
        let altitude = try #require(gps[kCGImagePropertyGPSAltitude] as? Double)
        #expect(isClose(latitude, 27.7172, tolerance: 1e-6))
        #expect(gps[kCGImagePropertyGPSLatitudeRef] as? String == "N")
        #expect(isClose(longitude, 85.324, tolerance: 1e-6))
        #expect(gps[kCGImagePropertyGPSLongitudeRef] as? String == "E")
        #expect(isClose(altitude, 1400, tolerance: 1e-3))
    }

    @Test func southAndWestAreWrittenAsReferencesNotSigns() async throws {
        var photo = try shot(.film)
        photo.location = PhotoLocation(latitude: -33.8688, longitude: -70.6693, altitude: nil)
        let baked = try #require(await exporter.bake(photo))
        let gps = try #require(describe(baked)?.properties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        let latitude = try #require(gps[kCGImagePropertyGPSLatitude] as? Double)
        #expect(isClose(latitude, 33.8688, tolerance: 1e-6))
        #expect(gps[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        #expect(gps[kCGImagePropertyGPSLongitudeRef] as? String == "W")
        #expect(gps[kCGImagePropertyGPSAltitude] == nil)
    }

    @Test func aPhotoWithoutAPlaceCarriesNoGPS() async throws {
        let baked = try #require(await exporter.bake(try shot(.film)))
        #expect(describe(baked)?.properties[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func anInstantPhotoIsBakedAsAFramedPrint() async throws {
        let baked = try #require(await exporter.bake(try shot(.instant)))
        let picture = try #require(describe(baked))
        #expect(isClose(Double(picture.height) / Double(picture.width), 107.0 / 88, tolerance: 0.01))
        #expect(picture.width > 300)

        let image = try #require(CIImage(data: baked))
        let corner = renderer.context.pixel(of: image, x: 3, y: 3)
        #expect(corner.isClose(to: Pixel(red: 0xF7, green: 0xF3, blue: 0xEC), tolerance: 3))
    }

    @Test func aDateStampedCameraLeavesItsStampInTheCorner() async throws {
        // A dark grey photo 390 points wide at two pixels per point, so the orange date stands out.
        let id = UUID().uuidString
        let image = try folder.store(original: makeJPEG(width: 780, height: 1040, grey: 0.15), id: id, fileExtension: "jpg")
        var photo = Photo(id: id, image: image, camera: .digicam, capturedAt: clock.now)
        photo.adjustments = PhotoAdjustments(intensity: 100, grain: 0)
        let file = try #require(await exporter.bake(photo))
        let baked = try #require(CIImage(data: file))

        // The date sits 6% in from the right and 5% up from the bottom; nothing is written bottom left.
        func orangePixels(in region: CGRect) -> Int {
            renderer.context.pixels(of: baked, in: region).filter { $0.red > 200 && $0.red - $0.blue > 100 }.count
        }
        #expect(orangePixels(in: CGRect(x: 480, y: 40, width: 260, height: 90)) > 300)
        #expect(orangePixels(in: CGRect(x: 40, y: 40, width: 260, height: 90)) == 0)
    }

    // MARK: Collages

    /// Three flat originals in the library, shown as they are so their colours can be read back exactly.
    private func collage(_ template: CollageTemplate = .feature, border: CollageBorder = .cream) throws -> Collage {
        let photos = try (0..<template.photoCount).map { _ in
            var photo = try shot(.film)
            photo.adjustments = .original
            return photo
        }
        return Collage(template: template, border: border, photos: photos)
    }

    @Test func aCollageIsOneFlatPictureInTheFramesShapeAndColour() async throws {
        let data = try #require(await exporter.collagePicture(try collage()))
        let image = try #require(CIImage(data: data))
        #expect(isClose(image.extent.width / image.extent.height, 300.0 / 400, tolerance: 0.005))
        let scale = image.extent.width / 300
        func pixel(_ x: CGFloat, _ y: CGFloat) -> Pixel {
            renderer.context.pixel(of: image, x: Int(x * scale), y: Int(y * scale))
        }
        let cream = Pixel(red: 0xF4, green: 0xEE, blue: 0xE6)
        let orange = Pixel(red: 200, green: 120, blue: 40)
        // The frame's edge, the gutter between the top photo and the two below, and the middle of each photo.
        #expect(pixel(3, 3).isClose(to: cream, tolerance: 3))
        #expect(pixel(150, 242).isClose(to: cream, tolerance: 3))
        #expect(pixel(150, 100).isClose(to: orange, tolerance: 4))
        #expect(pixel(80, 320).isClose(to: orange, tolerance: 4))
        #expect(pixel(220, 320).isClose(to: orange, tolerance: 4))
    }

    @Test func eachPhotoInACollageKeepsItsOwnLookAndEdits() async throws {
        var arrangement = try collage(.sideBySide, border: .none)
        arrangement.photos[1].adjustments = PhotoAdjustments(intensity: 100, grain: 0)
        let data = try #require(await exporter.collagePicture(arrangement))
        let image = try #require(CIImage(data: data))
        let y = Int(image.extent.height) / 2
        let left = renderer.context.pixel(of: image, x: Int(image.extent.width) / 4, y: y)
        let right = renderer.context.pixel(of: image, x: Int(image.extent.width) * 3 / 4, y: y)
        #expect(left.isClose(to: Pixel(red: 200, green: 120, blue: 40), tolerance: 4))
        #expect(right.isClose(to: Pixel(red: 237, green: 135, blue: 47), tolerance: 5))
    }

    @Test func aSavedCollageIsFiledAsAPhotoWithNoLookOnTop() async throws {
        let made = try #require(await exporter.collagePhoto(try collage(.grid, border: .black)))
        #expect(made.isCollage)
        #expect(made.adjustments == .original)
        #expect(made.capturedAt == clock.now)
        #expect(!made.isVideo)
        guard case .file(let full, let thumbnail) = made.image else {
            Issue.record("A collage is filed in the library")
            return
        }
        #expect(FileManager.default.fileExists(atPath: folder.url(for: full).path))
        #expect(FileManager.default.fileExists(atPath: folder.url(for: thumbnail).path))

        // Baking it for Photos changes nothing but the wrapping: no look, no stamp.
        let baked = try #require(await exporter.bake(made))
        let image = try #require(CIImage(data: baked))
        #expect(renderer.context.pixel(of: image, x: 5, y: 5).isClose(to: Pixel(red: 0x0A, green: 0x09, blue: 0x08), tolerance: 4))
    }

    @Test func aCollageWithAPhotoMissingCannotBeMade() async throws {
        var arrangement = try collage()
        arrangement.photos[1].image = .file(full: "gone.jpg", thumbnail: "gone-thumb.jpg")
        #expect(await exporter.collagePicture(arrangement) == nil)
    }

    // MARK: Prints

    @Test func aPrintIsThePhotoOnWhitePaperInThePapersShape() async throws {
        var photo = try shot(.film, width: 600, height: 800)
        photo.adjustments = PhotoAdjustments(intensity: 100, grain: 0)
        let job = PrintJob(photo: photo, size: .fourBySix, hasBorder: true, copies: 1)
        let file = try #require(await exporter.printFile(for: job))
        defer { try? FileManager.default.removeItem(at: file) }
        let image = try #require(CIImage(contentsOf: file))
        #expect(isClose(image.extent.width / image.extent.height, 240.0 / 360, tolerance: 0.01))
        #expect(renderer.context.pixel(of: image, x: 3, y: 3).isClose(to: Pixel(red: 255, green: 255, blue: 255), tolerance: 2))
        let centre = renderer.context.pixel(of: image, x: Int(image.extent.width) / 2, y: Int(image.extent.height) / 2)
        #expect(centre.isClose(to: Pixel(red: 237, green: 135, blue: 47), tolerance: 5))
    }

    @Test func withoutABorderThePhotoFillsThePaper() async throws {
        let job = PrintJob(photo: try shot(.film, width: 600, height: 800), size: .square, hasBorder: false, copies: 2)
        let file = try #require(await exporter.printFile(for: job))
        defer { try? FileManager.default.removeItem(at: file) }
        let image = try #require(CIImage(contentsOf: file))
        #expect(image.extent.width == image.extent.height)
        let corner = renderer.context.pixel(of: image, x: 3, y: 3)
        #expect(!corner.isClose(to: Pixel(red: 255, green: 255, blue: 255), tolerance: 20))
    }

    // MARK: A file to hand out

    @Test func aPhotoIsHandedOutAsABakedJPEGNamedForWhenItWasTaken() async throws {
        let photo = try shot(.instant)
        let file = try #require(await exporter.file(for: photo))
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(file.lastPathComponent == "RetroSnap 2026-10-11 16.12.00.jpg")
        let picture = try #require(describe(try Data(contentsOf: file)))
        #expect(picture.width > 300)
    }

    @Test func aClipIsHandedOutAsABakedMovie() async throws {
        let file = try #require(await exporter.file(for: try await clip(.film)))
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(file.lastPathComponent == "RetroSnap 2026-10-11 16.12.00.mov")
        let seconds = try await AVURLAsset(url: file).load(.duration).seconds
        #expect(abs(seconds - 1) < 0.2)
    }

    @Test func nothingIsHandedOutForAShotThatCannotBeBaked() async {
        let missing = Photo(
            id: "x", image: .file(full: "x.jpg", thumbnail: "x-thumb.jpg"), camera: .film, capturedAt: clock.now
        )
        #expect(await exporter.file(for: missing) == nil)
    }

    // MARK: Clips

    /// A clip filed in the library from a one-second flat orange recording, held upright.
    private func clip(_ camera: CameraStyle) async throws -> Photo {
        let id = UUID().uuidString
        let recording = FileManager.default.temporaryDirectory.appendingPathComponent("\(id)-recording.mov")
        try await makeMovie(at: recording, isPortrait: true)
        let filed = try await folder.storeClip(movieAt: recording, id: id)
        return Photo(
            id: id, image: filed.poster, camera: camera, capturedAt: clock.now, videoSeconds: 1,
            videoFile: filed.videoFile, adjustments: PhotoAdjustments(intensity: 100, grain: 0)
        )
    }

    @Test func aClipIsBakedUprightAtItsOwnSizeAndLength() async throws {
        let baked = try #require(await exporter.bakeClip(try await clip(.film)))
        defer { try? FileManager.default.removeItem(at: baked) }
        let asset = AVURLAsset(url: baked)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
        let upright = CGRect(origin: .zero, size: size).applying(transform).size
        #expect(abs(upright.width - 240) < 1)
        #expect(abs(upright.height - 320) < 1)
        let seconds = try await asset.load(.duration).seconds
        #expect(abs(seconds - 1) < 0.2)
    }

    @Test func theLookIsDrawnIntoEveryFrameOfAClip() async throws {
        let baked = try #require(await exporter.bakeClip(try await clip(.film)))
        defer { try? FileManager.default.removeItem(at: baked) }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: baked))
        generator.appliesPreferredTrackTransform = true
        for second in [0.1, 0.8] {
            let frame = try await generator.image(at: CMTime(seconds: second, preferredTimescale: 600)).image
            let image = CIImage(cgImage: frame)
            let centre = renderer.context.pixel(of: image, x: frame.width / 2, y: frame.height / 2)
            // The film chain and tint on the fixtures' orange; video compression costs a few levels.
            #expect(centre.isClose(to: Pixel(red: 237, green: 135, blue: 47), tolerance: 12))
        }
    }

    @Test func whenAndWhereAClipWasTakenTravelWithIt() async throws {
        var photo = try await clip(.camcorder)
        photo.location = PhotoLocation(latitude: 27.7172, longitude: 85.324, altitude: 1400)
        let baked = try #require(await exporter.bakeClip(photo))
        defer { try? FileManager.default.removeItem(at: baked) }
        let metadata = try await AVURLAsset(url: baked).load(.metadata)
        let place = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .quickTimeMetadataLocationISO6709).first
        let coordinates = try await place?.load(.stringValue)
        #expect(coordinates == "+27.7172+085.3240+1400.000/")
        let date = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .quickTimeMetadataCreationDate).first
        let created = try await date?.load(.dateValue)
        #expect(created == clock.now)
    }

    @Test func progressIsReportedOnlyWhileAClipIsBeingBaked() async throws {
        let photo = try await clip(.film)
        #expect(exporter.progress[photo.id] == nil)
        let baked = try #require(await exporter.bakeClip(photo))
        try? FileManager.default.removeItem(at: baked)
        #expect(exporter.progress[photo.id] == nil)
    }

    @Test func aClipWithoutItsMovieBakesNothing() async {
        let sample = Photo(id: "s", image: .photo(1039), camera: .camcorder, capturedAt: clock.now, videoSeconds: 24)
        #expect(await exporter.bakeClip(sample) == nil)
    }

    @Test func aPhotoWhoseFileIsGoneBakesNothing() async {
        let missing = Photo(
            id: "x", image: .file(full: "x.jpg", thumbnail: "x-thumb.jpg"), camera: .film, capturedAt: clock.now
        )
        #expect(await exporter.bake(missing) == nil)
    }

    @Test func aBundledPictureBakesToo() async throws {
        let sample = Photo(id: "s", image: .photo(1011), camera: .camcorder, capturedAt: clock.now)
        let baked = try #require(await exporter.bake(sample))
        let picture = try #require(describe(baked))
        #expect(picture.width * 4 == picture.height * 3)
    }
}
